require_relative 'shared/constants'
require_relative 'shared/helpers'
require_relative 'shared/ascii'
require_relative 'shared/super_proxies'

require_relative 'systems/user_server'
require_relative 'systems/dom_renderer'

# Compile-time (source to AST)
require_relative 'compiler/lexeme'
require_relative 'compiler/expressions'
require_relative 'compiler/lexer'
require_relative 'compiler/parser'
require_relative 'compiler/documenter'
require_relative 'compiler/type_checker'

# Runtime (AST to execution)
require_relative 'runtime/errors'
require_relative 'runtime/scopes'
require_relative 'runtime/return'
require_relative 'runtime/interpreter'

module Ore
	ROOT_PATH             = File.expand_path('../', __dir__)
	STANDARD_LIBRARY_PATH = File.join(ROOT_PATH, 'ore', 'preload.ore')

	extend Helpers

	def self.interp source_code, load_standard_library: true
		interpreter                       = Interpreter.new
		interpreter.load_standard_library = load_standard_library
		interpreter.run source_code
	end

	def self.interp_file filepath, load_standard_library: true
		source_code                       = File.read filepath
		interpreter                       = Interpreter.new
		interpreter.load_standard_library = load_standard_library
		interpreter.register_source filepath, source_code
		interpreter.run source_code
	end

	def self.interp_file_with_hot_reload filepath, load_standard_library: true
		require 'listen'

		reload          = true
		listener        = nil
		current_servers = []
		shutdown        = false

		Signal.trap 'INT' do
			puts Ore::Ascii.dim "░ Shutting down safely"
			shutdown = true
			Thread.main.raise Interrupt
		end

		Signal.trap 'TERM' do
			puts Ore::Ascii.dim "░ Shutting down safely"
			shutdown = true
			Thread.main.raise Interrupt
		end

		begin
			while reload && !shutdown
				reload = false

				code                              = File.read filepath
				interpreter                       = Interpreter.new
				interpreter.load_standard_library = load_standard_library
				interpreter.register_source filepath, code
				result = interpreter.run code

				if interpreter.servers.any?
					current_servers = interpreter.servers

					unless listener
						listener = Listen.to('.', only: /\.(ore|rb)$/) do |modified, added, removed|
							puts Ore::Ascii.dim "▓▒░ Reloading due to rb|ore file changes"
							reload = true
							current_servers.each(&:stop)
						end
						listener.start
					end

					puts Ore::Ascii.dim "▓▒░ Press ctrl+c to shut down"

					current_servers.each do |server|
						puts Ore::Ascii.dim "▓▒░ Ore Server named `#{server.server_instance.name}` started at http://localhost:#{server.port}"
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

	def self.parse source_code
		Parser.new(Lexer.new(source_code).output).output
	end

	def self.parse_file filepath
		Parser.new(Lexer.new(File.read(filepath)).output).output
	end

	def self.lex source_code
		Lexer.new(source_code).output
	end

	def self.lex_file filepath
		Lexer.new(File.read(filepath)).output
	end
end
