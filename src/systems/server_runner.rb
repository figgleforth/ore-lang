require 'webrick'
require 'cgi'
require 'json'

module Ore
	class Server_Runner
		DEFAULT_PORT = 8080

		attr_accessor :server_instance, :interpreter, :port, :routes, :webrick_server, :server_thread

		# interpteter:1424 as a result of the @start directive
		# server_runner = Ore::Server_Runner.new server_instance, self, routes
		# server_runner gets added to runtime.servers
		def initialize server_instance, interpreter, routes = {}
			@server_instance = server_instance
			@interpreter     = interpreter
			@routes          = routes
			@port            = Integer(server_instance.get(:port) || DEFAULT_PORT)
		end

		def match_route http_method, path_parts, routes
			routes.values.find do |route|
				next unless route.http_method.value == http_method
				next unless route.parts.count == path_parts.count

				# All segments must match (considering :param placeholders)
				path_parts.zip(route.parts).all? do |req_part, route_part|
					(req_part == route_part) || (route_part.start_with?(':'))
				end
			end
		end

		def extract_url_params path_parts, route
			url_params = {}
			path_parts.zip(route.parts).each do |req_part, route_part|
				if route_part.start_with? ':'
					param_name                    = route_part[1..-1]
					url_params[param_name]        = req_part
					url_params[param_name.to_sym] = req_part
				end
			end
			url_params
		end

		def parse_query_string query_string
			query_params = {}
			if query_string
				query_string.split('&').each do |pair|
					key, value               = pair.split '=', 2
					query_params[key]        = CGI.unescape(value || '')
					query_params[key.to_sym] = CGI.unescape(value || '')
				end
			end
			query_params
		end

		# @param request [WEBrick::HTTPRequest, WEBrick::HTTPResponse]
		def handle_request request, response, routes
			path_string  = request.path
			query_string = request.query_string
			http_method  = request.request_method.downcase
			path_parts   = request.path.split('/').reject { _1.empty? }
			body_hash    = URI.decode_www_form(request.body || "").to_h
			headers_hash = request.header.to_h

			### Print some useful stuff
			req_info = Ascii.dim "▓▒░ "
			unless body_hash.empty?
				req_info = req_info.prepend Ascii.green
			end

			req_info << Ascii.dim(http_method.upcase.rjust(7, ' '))
			req_info << " "
			req_info << Ascii.reset(path_string.gsub("/", "#{Ascii.dim('/')}#{Ascii.reset}"))

			unless body_hash.empty?
				req_info << " #{Ascii.dim body_hash}"
			end
			puts req_info
			### end print

			# This handles the dom.js onclick request, not user code
			if path_string.start_with?("/onclick/")
				object_id = path_parts.last.to_i
				handler   = interpreter.runtime.onclick_handlers[object_id]
				if handler
					begin
						runtime = interpreter.runtime

						# Update input element values from the request body
						if request.body && !request.body.empty?
							json_body = JSON.parse request.body rescue {}
							inputs    = json_body['inputs'] || {}
							inputs.each do |element_id, value|
								input_instance = runtime.input_elements[element_id.to_i]
								input_instance.declare 'value', value if input_instance
							end
						end

						# Push the proper scope chain (instance, type, and function scopes)
						if handler.enclosing_scope.is_a?(Ore::Instance) && handler.enclosing_scope.enclosing_scope
							type = handler.enclosing_scope.enclosing_scope
							runtime.push_scope type.enclosing_scope if type.enclosing_scope
							runtime.push_scope type
						end
						runtime.push_scope handler.enclosing_scope
						runtime.push_scope handler
						result = handler.expressions.map { |e| interpreter.interpret e }.last

						# Pop scopes in reverse order
						runtime.pop_scope # handler
						runtime.pop_scope # enclosing_scope
						if handler.enclosing_scope.is_a?(Ore::Instance) && handler.enclosing_scope.enclosing_scope
							type = handler.enclosing_scope.enclosing_scope
							runtime.pop_scope # type
							runtime.pop_scope if type.enclosing_scope
						end

						# Do something with the result
						component = handler.enclosing_scope
						if component.is_a?(Ore::Instance) && component.declarations['render']
							new_html = interpreter.render_dom_to_html component
							html_id  = component.declarations['html_id']

							response.status             = 200
							response['Content-Type']    = 'text/html'
							response['X-Ore-Target-Id'] = html_id if html_id
							response.body               = new_html
							return
						end
					rescue => e
						warn "\n[Ore Onclick Error] #{e.class}: #{e.message}"
						warn e.backtrace.first(10).map { |line| "  #{line}" }.join("\n")
						warn ""

						plain_message   = e.message.gsub(/\e\[\d+(?:;\d+)*m/, '')
						response.status = 500
						response.body   = "Internal Server Error\n#{plain_message}"
						return
					end
				else
					puts "no handler???"
				end
			end

			# Cookies! request.cookies gives us an array of WEBrick::Cookie
			# note: The cookie is set below somewhere in a javascript snippet using the same key BROWSER_VIEW_SIZE. We read it here to then declare it in the global scope for Dom elements to use
			if cookie = request.cookies.find { _1.name == BROWSER_VIEW_SIZE }
				parts = cookie.value.split 'x'
				size  = {
					  width:  parts[0].to_i,
					  height: parts[1].to_i
				}
				# This declares `browser_view_size` in the current scope, which should be the route handler?
				# todo: A better way to store this information, and make it accessible at runtime. Some
				interpreter.runtime.stack.last.declare BROWSER_VIEW_SIZE, size
			end

			route_function = match_route http_method, path_parts, routes

			if route_function
				url_params   = extract_url_params path_parts, route_function
				query_params = parse_query_string query_string

				req = Ore::Request.new
				interpreter.link_instance_to_type req, 'Request'

				body_dict    = Ore::Dictionary.new body_hash
				query_dict   = Ore::Dictionary.new query_params
				params_dict  = Ore::Dictionary.new url_params
				headers_dict = Ore::Dictionary.new headers_hash
				interpreter.link_instance_to_type body_dict, 'Dictionary'
				interpreter.link_instance_to_type query_dict, 'Dictionary'
				interpreter.link_instance_to_type params_dict, 'Dictionary'
				interpreter.link_instance_to_type headers_dict, 'Dictionary'

				req.declarations['path']              = path_string
				req.declarations['method']            = http_method
				req.declarations['query']             = query_dict
				req.declarations['params']            = params_dict
				req.declarations['headers']           = headers_dict
				req.declarations['body']              = body_dict
				req.declarations['body'].declarations = body_hash

				begin
					res = Ore::Response.new response
					interpreter.link_instance_to_type res, 'Response'

					# The route handler could return Html|Dom, Body|Dom etc, or even just a string. Sounds like I have to make sure the format of the final Html is correct
					result = interpreter.interp_route_handler route_function, req, res, url_params, server_instance: @server_instance

					# Apply response object's configuration to WEBrick response
					response.status = res.declarations['status']
					response.body   = res.declarations['body']
					headers_hash    = res.declarations['headers']
					headers_hash.each { |k, v| response.header[k] = v }
					Time

					# note: WEBrick (or the browser) automatically include html and head elements if the response does not
					if response.body.to_s =~ /<html|<body|<head/i
						response.body.prepend "<!DOCTYPE html>"

						dom_js     = File.read 'src/runtime/dom.js'
						script_tag = "<script>#{dom_js}</script>"

						# Insert after <head> or <body> tag, or prepend
						body_str = response.body.to_s
						if body_str.include?('<head>')
							response.body = body_str.sub('<head>', '<head>' + script_tag)
						elsif body_str.include?('<body>')
							response.body = body_str.sub('<body>', '<body>' + script_tag)
						else
							response.body = script_tag + body_str
						end
					end

					result

				rescue WEBrick::HTTPStatus::Status => e
					raise e # note: Must propagate the WEBrick status exceptions as this is how it handles redirects, and such,

				rescue => e
					warn "\n[Ore Server Error] #{e.class}: #{e.message}"
					warn e.backtrace.first(10).map { |line| "  #{line}" }.join("\n")
					warn ""

					# Strip ANSI color codes for browser display
					plain_message   = e.message.gsub(/\e\[\d+(?:;\d+)*m/, '')
					plain_backtrace = e.backtrace.map { |line| line.gsub(/\e\[\d+(?:;\d+)*m/, '') }

					response.status = 500
					response.body   = <<~HTML
					    <h1>500 Internal Server Error</h1>
					    <h2>#{e.class}</h2>
					    <pre>#{plain_message}</pre>
					    <h3>Backtrace</h3>
					    <pre>#{plain_backtrace.join("\n")}</pre>
					HTML
					response.header['Content-Type'] = 'text/html; charset=utf-8'
				end
			else
				puts "no matching route function"
				# 404 Not Found
				response.status = 404
				response.body   = <<~HTML
				    <h1>404 Not Found</h1>
				    <p>No route matches #{http_method.upcase} #{path_string}</p>
				    <hr>
				    <h3>Available Routes:</h3>
				    <ul>
				    	#{routes.values.map { |r| "<li>#{r.http_method.value.upcase} /#{r.path}</li>" }.join("\n")}
				    </ul>
				HTML
				response.header['Content-Type'] = 'text/html; charset=utf-8'
			end
		end

		def start
			@webrick_server = WEBrick::HTTPServer.new Port:      port,
			                                          Logger:    WEBrick::Log.new("/dev/null"),
			                                          AccessLog: [] # Disables

			# This receives requests from dom.js
			webrick_server.mount_proc '/onclick/' do |req, res|
				puts Ascii.dim "▓▒░ #{'DOM'.rjust(7, ' ')} #{req.path}"
				handle_request req, res, @routes
				# todo: Old handlers accumulate if you navigate away, since they stay in memory, maybe some unmount process
				# todo: A way to deregister handlers when a component is no longer rendered
			end

			# This receives the rest of the requests
			webrick_server.mount_proc '' do |req, res|
				handle_request req, res, @routes
			end

			@server_thread = Thread.new do
				webrick_server.start
			end

			server_thread
		end

		def stop
			webrick_server.shutdown if webrick_server
			Thread.kill server_thread if server_thread
		end

		def prefixed_output output
			req_info = Ascii.dim("▓▒░ ")
			req_info << Ascii.dim(output.rjust(7, ' '))
		end

		def right_aligned output
			output.rjust(7, ' ')
		end
	end
end
