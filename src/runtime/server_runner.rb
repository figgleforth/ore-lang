require 'webrick'
require 'cgi'

module Ore
	class Server_Runner
		attr_accessor :server_instance, :interpreter, :port, :routes, :webrick_server, :server_thread

		def initialize server_instance, interpreter, routes = {}
			@server_instance = server_instance
			@interpreter     = interpreter
			@port            = extract_port
			@routes          = routes
		end

		def extract_port
			port_value = server_instance[:port] || server_instance.declarations['port']
			port_value.is_a?(Integer) ? port_value : 8080
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

			# Cookies! request.cookies gives us an array of WEBrick::Cookie
			# note: The cookie is set below somewhere in a javascript snippet using the same key BROWSER_VIEW_SIZE. We read it here to then declare it in the global scope for Dom elements to use
			if cookie = request.cookies.find { _1.name == BROWSER_VIEW_SIZE }
				parts = cookie.value.split 'x'
				size  = {
					width:  parts[0].to_i,
					height: parts[1].to_i
				}
				interpreter.runtime.stack.first.declare BROWSER_VIEW_SIZE, size
			end

			target_route = match_route http_method, path_parts, routes

			if target_route
				url_params   = extract_url_params path_parts, target_route
				query_params = parse_query_string query_string

				req = Ore::Request.new
				interpreter.link_instance_to_type req, 'Request'

				body_hash    = URI.decode_www_form(request.body || "").to_h
				headers_hash = request.header.to_h
				body_dict    = Ore::Dictionary.new body_hash
				query_dict   = Ore::Dictionary.new query_params
				params_dict  = Ore::Dictionary.new url_params
				headers_dict = Ore::Dictionary.new headers_hash
				interpreter.link_instance_to_type body_dict, 'Dictionary'
				interpreter.link_instance_to_type query_dict, 'Dictionary'
				interpreter.link_instance_to_type params_dict, 'Dictionary'
				interpreter.link_instance_to_type headers_dict, 'Dictionary'

				req.path              = path_string
				req.method            = http_method
				req.query             = query_dict
				req.params            = params_dict
				req.headers           = headers_dict
				req.body              = body_dict
				req.body.declarations = body_hash

				# Update declarations
				req.declarations['path']    = req.path
				req.declarations['method']  = req.method
				req.declarations['query']   = req.query
				req.declarations['params']  = req.params
				req.declarations['headers'] = req.headers
				req.declarations['body']    = req.body

				begin
					res = Ore::Response.new response
					interpreter.link_instance_to_type res, 'Response'

					# The route handler could return Html|Dom, Body|Dom etc, or even just a string. Sounds like I have to make sure the format of the final Html is correct
					result = interpreter.interp_route_handler target_route, req, res, url_params, server_instance: @server_instance

					# Apply response object's configuration to WEBrick response
					response.status = res.declarations['status'] || res.status
					headers_hash    = res.declarations['headers'] || res.headers
					headers_hash.each { |k, v| response.header[k] = v }
					response.body = res.declarations['body'] || res.body_content.to_s
					# todo: append or prepend javascript that will capture the window size, set a cookie for it, then reload or just change url location so WEBrick can read the cookie for window size
					# This window size to be available to all Dom elements as an alternate to media queries which I'm unable to reproduce yet.
					# Inject JavaScript here - modify response.body
					if response.body.to_s =~ /<html|<body|<head/i
						# todo: Move this to a .js file and load it
						window_size_js = <<~JSCODE
						    <script>
						    (function() {
						        var size = window.innerWidth + 'x' + window.innerHeight;
						        if (document.cookie.indexOf('#{BROWSER_VIEW_SIZE}=' + size) === -1) {
						            document.cookie = '#{BROWSER_VIEW_SIZE}=' + size + '; path=/';
									console.log('Set cookie for window size!!!', size);
						            window.location = '';
						        }
						    })();
						    </script>
						JSCODE

						# Insert after <head> or <body> tag, or prepend
						body_str = response.body.to_s
						if body_str.include?('<head>')
							response.body = body_str.sub('<head>', '<head>' + window_size_js)
						elsif body_str.include?('<body>')
							response.body = body_str.sub('<body>', '<body>' + window_size_js)
						else
							response.body = window_size_js + body_str
						end
					end

					result

				rescue WEBrick::HTTPStatus::Status
					raise # note: Must propagate the WEBrick status exceptions as this is how it handles redirects, and such,

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
			@webrick_server = WEBrick::HTTPServer.new Port: port

			webrick_server.mount_proc '' do |req, res|
				handle_request req, res, @routes
			end

			@server_thread = Thread.new do
				webrick_server.start
			end

			puts "---> Ore Server Started at http://localhost:#{port}"

			server_thread
		end

		def stop
			webrick_server&.shutdown
			Thread.kill server_thread if server_thread
		end
	end
end
