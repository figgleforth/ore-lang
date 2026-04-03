module Ore
	class Runtime
		require 'securerandom'

		attr_accessor :stack, :routes, :servers, :onclick_handlers, :input_elements, :loaded_files, :source_files, :cd_scopes

		def initialize
			@stack            = []
			@servers          = []
			@routes           = {} # {route: Ore::Route}
			@loaded_files     = {} # {filename: Ore::Expression}
			@source_files     = {} # {filepath: String} for error reporting
			@onclick_handlers = {} # {handler_hash: Ore::Func}
			@input_elements   = {} # {element_hash: Ore::Instance} for inputs/textareas
			@cd_scopes        = Set.new # Scopes pushed via @cd directive
		end

		def inspect
			{
				# routes:  routes,
				# servers: servers,
				# onclick_handlers: onclick_handlers
				stack: stack
			}
		end

		def add_onclick_handler handler
			key                   = handler.hash
			onclick_handlers[key] = handler
			key
		end

		def add_input_element instance
			key                 = instance.hash
			input_elements[key] = instance
			key
		end

		def push_scope scope
			scope ||= stack.last
			stack << scope
		end

		def pop_scope
			if stack.length == 1
				stack.last
			else
				stack.pop
			end
		end

		def push_then_pop scope
			raise "Attempting to push `nil` value as scope" if scope == nil

			push_scope scope
			if block_given?
				yield scope
			end
			pop_scope
		end

		def register_source filepath, source_code
			resolved                = filepath ? File.expand_path(filepath) : '<inline>'
			@source_files[resolved] = source_code.lines.map(&:chomp)
		end
	end
end