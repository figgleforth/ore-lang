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
		if @server_runner && @interpreter
			@interpreter.stop_server @server_runner
			sleep 0.1
		end
	end

	def test_server_starts_and_responds
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = #{@port};
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get:// {;
		    		"Hello from Ore!"
		    	}

		    	get://hello/:name { name;
		    		"<h1>Hello, `name`!</h1>"
		    	}
		    }

		    app = Web_App()
		ORE

		@interpreter    = Ore::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner                 = Ore::Server.new
		@server_runner.server_instance = server_instance
		@server_runner.port            = Integer(server_instance.get(:port) || Ore::Server::DEFAULT_PORT)
		@server_runner.routes          = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

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
		    	new { port = #{@port};
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get://search {;
		    		"Query: `request.query`"
		    	}
		    }

		    app = Web_App()
		ORE

		@interpreter    = Ore::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner                 = Ore::Server.new
		@server_runner.server_instance = server_instance
		@server_runner.port            = Integer(server_instance.get(:port) || Ore::Server::DEFAULT_PORT)
		@server_runner.routes          = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

		response = Net::HTTP.get_response URI("http://localhost:#{@port}/search?q=test&page=1")
		assert_equal '200', response.code
		# The response should contain the query params
		assert_includes response.body, 'q'
	end

	def test_post_route
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = #{@port};
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	post://submit {;
		    		"Form submitted"
		    	}
		    }

		    app = Web_App()
		ORE

		@interpreter    = Ore::Interpreter.new
		server_instance = @interpreter.run code

		@server_runner                 = Ore::Server.new
		@server_runner.server_instance = server_instance
		@server_runner.port            = Integer(server_instance.get(:port) || Ore::Server::DEFAULT_PORT)
		@server_runner.routes          = @interpreter.collect_routes_from_instance server_instance
		@interpreter.start_server @server_runner

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
		    	new { port;
		    		.port = port
		    	}
		    }

		    Server_A | Server {
		    	get://a {;
		    		"Response from Server A"
		    	}
		    }

		    Server_B | Server {
		    	get://b {;
		    		"Response from Server B"
		    	}
		    }

		    a = Server_A(#{port_a})
		    b = Server_B(#{port_b})
		ORE

		interpreter = Ore::Interpreter.new
		interpreter.run code

		a_instance = interpreter.stack.first['a']
		b_instance = interpreter.stack.first['b']

		routes_a = interpreter.collect_routes_from_instance a_instance
		routes_b = interpreter.collect_routes_from_instance b_instance

		@server_runner_a                 = Ore::Server.new
		@server_runner_a.server_instance = a_instance
		@server_runner_a.port            = Integer(a_instance.get(:port) || Ore::Server::DEFAULT_PORT)
		@server_runner_a.routes          = routes_a

		@server_runner_b                 = Ore::Server.new
		@server_runner_b.server_instance = b_instance
		@server_runner_b.port            = Integer(b_instance.get(:port) || Ore::Server::DEFAULT_PORT)
		@server_runner_b.routes          = routes_b

		interpreter.start_server @server_runner_a
		interpreter.start_server @server_runner_b

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

		interpreter.stop_server @server_runner_a
		interpreter.stop_server @server_runner_b
		@server_runner = nil
	end
end
