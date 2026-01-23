require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'
require 'net/http'
require 'uri'

class Server_Test < Base_Test
	def test_server_instance_creation
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = 3000;
		    		.port = port
		    	}
		    }

		    server = Server()
		ORE

		result = Ore.interp code
		assert_instance_of Ore::Server, result
		assert_equal 3000, result[:port]
	end

	def test_web_app_with_server_composition
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = 3001;
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get:// {;
		    		"Hello World"
		    	}
		    }

		    app = Web_App()
		ORE

		result = Ore.interp code
		assert_instance_of Ore::Server, result
		assert_equal 3001, result[:port]
	end

	def test_route_defined_in_server_type
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = 3002;
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get://hello {;
		    		"Hi there!"
		    	}

		    	get://users/:id { id;
		    		"User: |id|"
		    	}
		    }

		    app = Web_App()
		ORE

		interpreter = Ore::Interpreter.new Ore.parse(code)
		result      = interpreter.output

		assert_instance_of Ore::Server, result

		# Check that routes were registered
		assert_equal 2, interpreter.runtime.routes.count
	end

	def test_server_runner_initialization
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = 8888;
		    		.port = port
		    	}
		    }
		    app = Server()
		ORE

		interpreter     = Ore::Interpreter.new Ore.parse(code)
		server_instance = interpreter.output

		server_runner = Ore::Server_Runner.new server_instance, interpreter

		assert_equal 8888, server_runner.port
		assert_equal server_instance, server_runner.server_instance
		assert_equal interpreter, server_runner.interpreter
	end

	def test_route_collection
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = 3003;
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get:// {;
		    		"Home"
		    	}

		    	post://submit {;
		    		"Submitted"
		    	}
		    }

		    app = Web_App()
		ORE

		interpreter     = Ore::Interpreter.new Ore.parse(code)
		server_instance = interpreter.output

		server_runner = Ore::Server_Runner.new server_instance, interpreter
		routes        = server_runner.interpreter.runtime.routes

		assert_equal 2, routes.count
	end

	def test_route_matching
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = 3004;
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get://users/:id { id;
		    		"User |id|"
		    	}

		    	get://posts/:post_id/comments/:comment_id { post_id, comment_id;
		    		"Post |post_id| Comment |comment_id|"
		    	}
		    }

		    app = Web_App()
		ORE

		interpreter     = Ore::Interpreter.new Ore.parse(code)
		server_instance = interpreter.output

		server_runner = Ore::Server_Runner.new server_instance, interpreter
		routes        = server_runner.interpreter.runtime.routes

		# Test matching simple parameterized route
		matched = server_runner.match_route 'get', ['users', '123'], routes
		assert matched
		assert_equal 'get', matched.http_method.value

		# Test matching nested parameterized route
		matched = server_runner.match_route 'get', ['posts', '456', 'comments', '789'], routes
		assert matched
		assert_equal 'get', matched.http_method.value

		# Test non-matching route
		matched = server_runner.match_route 'post', ['users', '123'], routes
		assert_nil matched
	end

	def test_url_param_extraction
		code = <<~ORE
		    Server {
		    	port,
		    	new { port = 3005;
		    		.port = port
		    	}
		    }

		    Web_App | Server {
		    	get://users/:user_id/posts/:post_id { user_id, post_id;
		    		"User |user_id| Post |post_id|"
		    	}
		    }

		    app = Web_App()
		ORE

		interpreter     = Ore::Interpreter.new Ore.parse(code)
		server_instance = interpreter.output

		server_runner = Ore::Server_Runner.new server_instance, interpreter
		routes        = server_runner.interpreter.runtime.routes
		route         = routes.values.first

		path_parts = ['users', '42', 'posts', '99']
		url_params = server_runner.extract_url_params path_parts, route

		assert_equal '42', url_params['user_id']
		assert_equal '99', url_params['post_id']
	end

	def test_query_string_parsing
		server_instance = Ore::Instance.new 'Server'
		interpreter     = Ore::Interpreter.new []
		server_runner   = Ore::Server_Runner.new server_instance, interpreter

		query_params = server_runner.parse_query_string 'name=John&age=30&city=NYC'

		assert_equal 'John', query_params['name']
		assert_equal '30', query_params['age']
		assert_equal 'NYC', query_params['city']
	end

	def test_query_string_with_url_encoding
		server_instance = Ore::Instance.new 'Server'
		interpreter     = Ore::Interpreter.new []
		server_runner   = Ore::Server_Runner.new server_instance, interpreter

		query_params = server_runner.parse_query_string 'message=Hello%20World&special=%21%40%23'

		assert_equal 'Hello World', query_params['message']
		assert_equal '!@#', query_params['special']
	end
end
