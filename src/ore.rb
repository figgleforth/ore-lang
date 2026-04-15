require_relative 'shared/constants'
require_relative 'shared/helpers'
require_relative 'shared/ascii'
require_relative 'shared/super_proxies'

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
require_relative 'runtime/repl'

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

	def self.type_check_file filepath
		self.type_check File.read(filepath)
	end

	def self.type_check source
		expressions = Ore.parse source
		checker     = Ore::Type_Checker.new expressions
		if checker.output
			raise checker.output
		end
	end
end
