require_relative 'shared/constants'
require_relative 'shared/helpers'
require_relative 'shared/super_proxies'

# Compile-time (source to AST)
require_relative 'compiler/lexeme'
require_relative 'compiler/expressions'
require_relative 'compiler/lexer'
require_relative 'compiler/parser'

# Runtime (AST to execution)
require_relative 'runtime/errors'
require_relative 'runtime/scopes'
require_relative 'runtime/runtime'
require_relative 'runtime/server_runner'
require_relative 'runtime/dom_renderer'
require_relative 'runtime/interpreter'

def assert(args) = Ore.assert(*args)

module Ore
	extend Helpers

	def self.interp_file filepath, with_std: true
		interp File.read(filepath), with_std: with_std, filepath: File.expand_path(filepath)
	end

	def self.interp_file_with_hot_reload filepath
		require 'listen'

		reload          = true
		listener        = nil
		current_servers = []
		shutdown        = false

		Signal.trap 'INT' do
			puts "\nShutting down..."
			shutdown = true
			Thread.main.raise Interrupt
		end

		Signal.trap 'TERM' do
			puts "\nShutting down..."
			shutdown = true
			Thread.main.raise Interrupt
		end

		begin
			while reload && !shutdown
				reload = false

				code    = File.read filepath
				global  = Ore::Global.with_standard_library
				runtime = Ore::Runtime.new global
				runtime.register_source filepath, code
				expressions = Ore.parse(code, filepath: filepath)
				interpreter = Ore::Interpreter.new expressions, runtime
				result      = interpreter.output

				if interpreter.runtime.servers.any?
					current_servers = interpreter.runtime.servers

					unless listener
						listener = Listen.to('.', only: /\.(ore|rb)$/) do |modified, added, removed|
							puts "\nReloading..."
							reload = true
							current_servers.each(&:stop)
						end
						listener.start

						puts "Server(s) running. Press Ctrl+C to stop."
						puts "Watching for .ore and .rb file changes..."
					end

					current_servers.each do |server|
						server.server_thread&.join
					end
				end
			end
		rescue Interrupt
		ensure
			listener&.stop if listener
			current_servers.each &:stop
		end

		result
	end

	def self.interp source_code, with_std: true, filepath: nil
		global_scope = with_std ? Global.with_standard_library : Global.new
		runtime      = Ore::Runtime.new global_scope
		runtime.register_source filepath, source_code

		lexemes     = Lexer.new(source_code, filepath: filepath).output
		expressions = Parser.new(lexemes, source_file: filepath).output
		interpreter = Interpreter.new expressions, runtime

		interpreter.output
	end

	def self.parse_file filepath
		parse File.read(filepath), filepath: filepath
	end

	def self.parse source_code, filepath: nil
		lexemes = Lexer.new(source_code, filepath: filepath).output
		Parser.new(lexemes, source_file: filepath).output
	end

	def self.lex_file filepath
		lex File.read(filepath)
	end

	def self.lex source_code
		Lexer.new(source_code).output
	end
end
