require 'minitest/autorun'
require_relative '../src/ore'
require 'net/http'
require 'uri'
require 'timeout'

class E2E_Server_Test < Minitest::Test
	def setup
		@port = 9999 + Random.rand(100) # Random port to avoid conflicts
	end

	def teardown
		# Cleanup any running servers
		if @server_runner
			@server_runner.stop
			sleep 0.1 # Give server time to shutdown
		end
	end

	def test_server_starts_and_responds
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = #{@port} ->
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get:// { ->
		    		"Hello from Ore!"
		    	}

		    	get://hello/:name { name ->
		    		"<h1>Hello, |name|!</h1>"
		    	}
		    }

		    app = Web_App()
		ORE

		# Start server in background
		interpreter     = Ore::Interpreter.new Ore.parse(code)
		server_instance = interpreter.output

		routes         = interpreter.collect_routes_from_instance server_instance
		@server_runner = Ore::Server_Runner.new server_instance, interpreter, routes
		@server_runner.start

		# Give server time to start
		sleep 0.5

		# Test GET /
		response = Net::HTTP.get_response URI("http://localhost:#{@port}/")
		assert_equal '200', response.code
		assert_equal 'Hello from Ore!', response.body

		# Test parameterized route
		response = Net::HTTP.get_response URI("http://localhost:#{@port}/hello/World")
		assert_equal '200', response.code
		assert_includes response.body, 'Hello, World!'

		# Test 404
		response = Net::HTTP.get_response URI("http://localhost:#{@port}/nonexistent")
		assert_equal '404', response.code
		assert_includes response.body, 'Not Found'
	end

	def test_query_parameters
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = #{@port} ->
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get://search { ->
		    		"Query: |request.query|"
		    	}
		    }

		    app = Web_App()
		ORE

		interpreter     = Ore::Interpreter.new Ore.parse(code)
		server_instance = interpreter.output

		routes         = interpreter.collect_routes_from_instance server_instance
		@server_runner = Ore::Server_Runner.new server_instance, interpreter, routes
		@server_runner.start

		sleep 0.5

		response = Net::HTTP.get_response URI("http://localhost:#{@port}/search?q=test&page=1")
		assert_equal '200', response.code
		# The response should contain the query params
		assert_includes response.body, 'q'
	end

	def test_post_route
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = #{@port} ->
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	post://submit { ->
		    		"Form submitted"
		    	}
		    }

		    app = Web_App()
		ORE

		interpreter     = Ore::Interpreter.new Ore.parse(code)
		server_instance = interpreter.output

		routes         = interpreter.collect_routes_from_instance server_instance
		@server_runner = Ore::Server_Runner.new server_instance, interpreter, routes
		@server_runner.start

		sleep 0.5

		uri      = URI("http://localhost:#{@port}/submit")
		response = Net::HTTP.post_form uri, {}
		assert_equal '200', response.code
		assert_equal 'Form submitted', response.body
	end

	def test_multiple_servers_with_different_routes
		port_a = @port
		port_b = @port + 1

		code = <<~ORE
		    Server {
		    	port,
		    	new { port ->
		    		.port = port
		    	}
		    }

		    Server_A | Server {
		    	get://a { ->
		    		"Response from Server A"
		    	}
		    }

		    Server_B | Server {
		    	get://b { ->
		    		"Response from Server B"
		    	}
		    }

		    a = Server_A(#{port_a})
		    b = Server_B(#{port_b})
		ORE

		interpreter = Ore::Interpreter.new Ore.parse(code)
		interpreter.output

		# Collect routes for each server
		server_a_type = interpreter.runtime.stack.first['Server_A']
		server_b_type = interpreter.runtime.stack.first['Server_B']

		# Get server instances from interpreter runtime
		a_instance = interpreter.runtime.stack.first['a']
		b_instance = interpreter.runtime.stack.first['b']

		routes_a = interpreter.collect_routes_from_instance a_instance
		routes_b = interpreter.collect_routes_from_instance b_instance

		# Start both servers
		@server_runner_a = Ore::Server_Runner.new a_instance, interpreter, routes_a
		@server_runner_b = Ore::Server_Runner.new b_instance, interpreter, routes_b

		@server_runner_a.start
		@server_runner_b.start

		sleep 0.5

		# Server A should respond to /a but not /b
		response_a = Net::HTTP.get_response URI("http://localhost:#{port_a}/a")
		assert_equal '200', response_a.code
		assert_equal 'Response from Server A', response_a.body

		response_a_404 = Net::HTTP.get_response URI("http://localhost:#{port_a}/b")
		assert_equal '404', response_a_404.code

		# Server B should respond to /b but not /a
		response_b = Net::HTTP.get_response URI("http://localhost:#{port_b}/b")
		assert_equal '200', response_b.code
		assert_equal 'Response from Server B', response_b.body

		response_b_404 = Net::HTTP.get_response URI("http://localhost:#{port_b}/a")
		assert_equal '404', response_b_404.code

		# Cleanup
		@server_runner_a.stop
		@server_runner_b.stop
		@server_runner = nil # So teardown doesn't try to stop it again
	end
end
