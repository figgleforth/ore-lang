require_relative 'shared/constants'
require_relative 'shared/helpers'
require_relative 'shared/ascii'
require_relative 'shared/super_proxies'
require_relative 'shared/stage'
require_relative 'shared/pipeline'

require_relative 'systems/server_runner'
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
require_relative 'runtime/runtime'
require_relative 'runtime/interpreter'

module Ore
	ROOT_PATH             = File.expand_path('../', __dir__)
	STANDARD_LIBRARY_PATH = File.join(ROOT_PATH, 'ore', 'preload.ore')

	extend Helpers

	def self.interp_file filepath, with_std: true
		source_code  = File.read filepath
		filepath     = File.expand_path filepath
		global_scope = with_std ? Global.with_standard_library : Global.new
		runtime      = Ore::Runtime.new global_scope
		runtime.register_source filepath, source_code

		interpreter = Interpreter.new [], runtime
		Pipeline.new(Lexer, Parser, interpreter).run source_code
	end

	def self.interp_file_with_hot_reload filepath, with_std: true
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

				code  = File.read filepath
				scope = if with_std
					Ore::Global.with_standard_library
				else
					Ore::Global.new
				end

				runtime = Ore::Runtime.new scope
				runtime.register_source filepath, code
				interpreter = Ore::Interpreter.new [], runtime
				result      = Pipeline.new(Lexer, Parser, interpreter).run code

				if interpreter.runtime.servers.any?
					current_servers = interpreter.runtime.servers

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

	def self.interp source_code
		Pipeline.default.run source_code
	end

	def self.parse_file filepath
		Pipeline.new(Lexer, Parser).run File.read(filepath)
	end

	def self.parse source_code
		Pipeline.new(Lexer, Parser).run source_code
	end

	def self.lex_file filepath
		Pipeline.new(Lexer).run File.read(filepath)
	end

	def self.lex source_code
		Pipeline.new(Lexer).run source_code
	end
end
