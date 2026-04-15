require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Pipeline_Test < Base_Test
	def test_interp
		assert_equal 42, Ore::Interpreter.new.run("42")
	end

	def test_lex
		result = Ore::Lexer.new("42").output
		assert_instance_of ::Array, result
		assert_instance_of Ore::Lexeme, result.first
	end

	def test_parse
		lexemes = Ore::Lexer.new("42").output
		result  = Ore::Parser.new(lexemes).output
		assert_instance_of ::Array, result
		assert_instance_of Ore::Number_Expr, result.first
	end

	def test_documenter
		code = <<~CODE
		    # a comment
		    1 + 1 # another comment
		    ```a fence!```
		CODE
		lexemes     = Ore::Lexer.new(code).output
		expressions = Ore::Parser.new(lexemes).output
		result      = Ore::Documenter.new(expressions).output
		assert_equal ['a comment', 'another comment', 'a fence!'], result.map(&:value)
	end

	def test_type_checker
		lexemes     = Ore::Lexer.new("42").output
		expressions = Ore::Parser.new(lexemes).output
		assert_nil Ore::Type_Checker.new(expressions).output
	end
end
