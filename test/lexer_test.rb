require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Lexer_Test < Base_Test
	def test_single_linecomment
		out = Ore.lex '# single line comment'
		assert_equal :comment, out.first.type
		assert_equal 'single line comment', out.first.value
		assert_kind_of Ore::Lexeme, out.first
	end

	def test_fence_blocks
		out = Ore.lex '```single line fence block```'
		assert_equal :fence, out.first.type
		assert_equal 'single line fence block', out.first.value
		assert_kind_of Ore::Lexeme, out.first

		out = Ore.lex '```multi
		line
		fence
		block```'
		assert_equal :fence, out.first.type
		assert out.first.value.start_with? 'multi'
		assert_kind_of Ore::Lexeme, out.first
	end

	def test_identifiers
		tests = %w(lowercase UPPERCASE Capitalized).zip %I(identifier IDENTIFIER Identifier)
		tests.all? do |code, type|
			out = Ore.lex code
			assert_equal type, out.first.type
			assert_kind_of Ore::Lexeme, out.first
		end
	end

	def test_numbers
		assert_equal :number, Ore.lex('4').first.type
		assert_equal :number, Ore.lex('8.0').first.type
	end

	def test_prefixed_numbers
		out = Ore.lex '-15'
		assert_equal %I(number), out.map(&:type)
		assert_equal '-15', out.last.value # These are converted to numerical values once they become Number_Exprs
		assert_equal 1, out.count

		out = Ore.lex '+1.6'
		assert_equal %I(operator number), out.map(&:type)
		assert_equal '1.6', out.last.value
		assert_equal 2, out.count
	end

	def test_unusual_number_situations
		out = Ore.lex '20three'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = Ore.lex '40__two'
		assert_equal %I(number identifier), out.map(&:type)
		assert_equal 2, out.count

		out = Ore.lex '4_15_6_3_4'
		assert_equal :number, out.first.type
		assert_equal 1, out.count

		out = Ore.lex 'abc123'
		assert_equal :identifier, out.first.type
		assert_equal 1, out.count
	end

	def test_strings
		out = Ore.lex '"A string"'
		assert_equal :string, out.first.type

		out = Ore.lex "'Another string'"
		assert_equal :string, out.first.type

	end

	def test_interpolated_strings
		out = Ore.lex '"An |interpolated| string"'
		assert_equal :string, out.first.type

		out = Ore.lex "'Another |interpolated| string'"
		assert_equal :string, out.first.type
	end

	def test_unterminated_string_literal
		assert_raises Ore::Unterminated_String_Literal do
			Ore.lex '"test\\'
		end

		assert_raises Ore::Unterminated_String_Literal do
			Ore.lex "'test\\"
		end
	end

	def test_operators
		# todo Should this be such a long test?
		out = Ore.lex 'numbers += 4815162342'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex 'ENABLED = true'
		assert_equal %I(IDENTIFIER operator identifier), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex 'Type = {}'
		assert_equal %I(Identifier operator delimiter delimiter), out.map(&:type)
		assert_equal 4, out.count

		out = Ore.lex 'numbers =;'
		assert_equal %I(identifier operator), out.map(&:type)
		assert_equal 2, out.count

		out = Ore.lex 'number: Number = 1'
		assert_equal %I(identifier operator Identifier operator number), out.map(&:type)
		assert_equal 5, out.count

		out = Ore.lex '1 + 2 * 3 / 4'
		assert_equal %I(number operator number operator number operator number), out.map(&:type)
		assert_equal 7, out.count

		out = Ore.lex '1 <=> 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '1 == 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '1 != 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '1 > 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '1 <= 2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '1..2'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '3.0..4.0'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '3.<4'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '5>.6'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex '7><8'
		assert_equal %I(number operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex 'a, B, 5, "cool"'
		assert_equal %I(identifier delimiter IDENTIFIER delimiter number delimiter string), out.map(&:type)
		assert_equal 7, out.count

		out = Ore.lex '1..2, 3.<4, 5>.6, 7><8'
		assert_equal %I(number operator number delimiter number operator number delimiter number operator number delimiter number operator number), out.map(&:type)
		assert_equal 15, out.count

		out = Ore.lex '.this_instance'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count

		out = Ore.lex './class_scope'
		assert_equal %I(operator identifier), out.map(&:type)
		assert_equal 2, out.count
	end

	def test_declaration_operators
		out = Ore.lex 'numbers := 4815162342' # This parses but I'm not using this any longer. Maybe I'll repurpose it.
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count

		out = Ore.lex 'numbers = 123'
		assert_equal %I(identifier operator number), out.map(&:type)
		assert_equal 3, out.count
	end

	def test_functions
		out = Ore.lex '{;}'
		assert_equal [:delimiter, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex 'named_function {;}'
		assert_equal [:identifier, :delimiter, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex '{ input; }'
		assert_equal [:delimiter, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex '{ labeled input; }'
		assert_equal [:delimiter, :identifier, :identifier, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex '{ value = 123; }'
		assert_equal [:delimiter, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex '{ labeled value = 123; }'
		assert_equal [:delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex '{ mixed, labeled value = 456; }'
		assert_equal [:delimiter, :identifier, :delimiter, :identifier, :identifier, :operator, :number, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex 'square { input;
		 		input * input
		 	 }'
		assert_equal [
			             :identifier, :delimiter, :identifier, :delimiter, :delimiter,
			             :identifier, :operator, :identifier, :delimiter, :delimiter
		             ], out.map(&:type)

		out = Ore.lex 'wrap { number, limit;
		 		if number > limit
		 			number = 0
		 		end
		 	 }'
		assert_equal [
			             :identifier, :delimiter, :identifier, :delimiter, :identifier, :delimiter, :delimiter,
			             :identifier, :identifier, :operator, :identifier, :delimiter,
			             :identifier, :operator, :number, :delimiter,
			             :identifier, :delimiter, :delimiter
		             ], out.map(&:type)
	end

	def test_types
		out = Ore.lex 'String {}'
		assert_equal [:Identifier, :delimiter, :delimiter], out.map(&:type)

		out = Ore.lex 'Transform {
		 	position =;
		 	rotation =;
		 }'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :identifier, :operator, :delimiter,
			             :identifier, :operator, :delimiter,
			             :delimiter
		             ], out.map(&:type)

		out = Ore.lex 'Entity {
		 	|Transform
		}'
		assert_equal [
			             :Identifier, :delimiter, :delimiter,
			             :operator, :Identifier, :delimiter,
			             :delimiter
		             ], out.map(&:type)
	end

	def test_control_flow
		out = Ore.lex 'if true
			celebrate()
		end'
		assert_equal [
			             :identifier, :identifier, :delimiter,
			             :identifier, :delimiter, :delimiter, :delimiter,
			             :identifier
		             ], out.map(&:type)

		out = Ore.lex 'if 1 + 2 * 3 == 7
			"This one!"
		elif 1 + 2 * 3 == 9
			\'No, this one!\'
		else
			\'🤯\'
		end'
		assert_equal [
			             :identifier, :number, :operator, :number, :operator, :number, :operator, :number, :delimiter,
			             :string, :delimiter,
			             :identifier, :number, :operator, :number, :operator, :number, :operator, :number, :delimiter,
			             :string, :delimiter,
			             :identifier, :delimiter,
			             :string, :delimiter,
			             :identifier
		             ], out.map(&:type)

		out = Ore.lex 'for [1, 2, 3, 4, 5]
			remove it if randf() > 0.5
			skip
			stop
		end'
		assert_equal [
			             :operator, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :number, :delimiter, :delimiter,
			             :identifier, :identifier, :identifier, :identifier, :delimiter, :delimiter, :operator, :number, :delimiter,
			             :operator, :delimiter,
			             :operator, :delimiter,
			             :identifier
		             ], out.map(&:type)
	end

	def test_compound_operators
		Ore::COMPOUND_OPERATORS.each do |operator|
			out = Ore.lex operator
			assert_equal operator, out.first.value
		end
	end

	def test_conditional_keywords
		out = Ore.lex 'and or'
		assert_equal :operator, out.first.type
		assert_equal :operator, out.last.type
	end

	def test_return_is_an_operator
		out = Ore.lex 'return 1 + 2'
		assert_equal :operator, out.first.type
	end

	def test_skip_and_stop_are_operators
		out = Ore.lex 'skip'
		assert_equal :operator, out.first.type

		out = Ore.lex 'stop'
		assert_equal :operator, out.first.type
	end

	def test_identifier_dot_integer
		out = Ore.lex 'array.0'
		assert_equal :identifier, out.first.type
		assert_equal 'array', out.first.value
		assert_equal :operator, out[1].type
		assert_equal '.', out[1].value
		assert_equal :number, out.last.type
		assert_equal '0', out.last.value
		# :lexeme_type_helper
	end

	def test_identifier_dot_float
		out = Ore.lex 'array.2.0'
		assert_equal :identifier, out.first.type
		assert_equal 'array', out.first.value
		assert_equal :operator, out[1].type
		assert_equal '.', out[1].value
		assert_equal :number, out.last.type
		assert_equal '2.0', out.last.value
		# :lexeme_type_helper
	end

	def test_number_with_multiple_decimal_points
		out = Ore.lex '1.2.3'
		assert_equal 1, out.count
		assert_equal :number, out.first.type
	end

	def test_double_less_than_is_operator
		out = Ore.lex '<<'
		assert_equal :operator, out.first.type
	end

	def test_at_at_prefix
		out = Ore.lex '@count'
		assert_equal :operator, out.first.type
	end

	def test_allowed_identifier_special_chars
		out = Ore.lex 'what?,'
		assert_equal :identifier, out.first.type
		assert_equal 'what?', out.first.value

		out = Ore.lex 'okay!,'
		assert_equal :identifier, out.first.type
		assert_equal 'okay!', out.first.value
	end

	def test_unpack_prefix
		out = Ore.lex '@instance_to_unpack'
		assert_equal :operator, out.first.type
		assert_equal Ore::RUNTIME_SCOPE_OPERATOR, out.first.value
		assert_equal :identifier, out.last.type
		assert_equal 'instance_to_unpack', out.last.value
	end

	def test_for_keyword
		out = Ore.lex 'for'
		assert_equal :operator, out.last.type
	end

	def test_single_line_code_location
		out = Ore.lex 'abracadabra'
		assert_equal 1, out.last.l0
		assert_equal 1, out.last.c0
		assert_equal 1, out.last.l1
		assert_equal 11, out.last.c1

		out = Ore.lex 'abracadabra = whatever'
		assert_equal 1, out.last.l0
		assert_equal 1, out.last.l1
		assert_equal 15, out.last.c0
		assert_equal 22, out.last.c1
	end

	def test_multiline_code_location
		out = Ore.lex <<~LEX
		    Thing {
		    	id,
		    	name,
		    }

		    for 1..2
		    	while true
		    		false until true
		    	end
		    end
		LEX
		assert_equal "1:1..1:5", out[0].line_col # Thing
		assert_equal "1:7..1:7", out[1].line_col # {
		assert_equal "1:8..2:1", out[2].line_col # \n
		assert_equal "2:2..2:3", out[3].line_col # id, Starts at column 2 because of indentation.
		assert_equal "2:4..2:4", out[4].line_col #;
		assert_equal "2:5..3:1", out[5].line_col # \n
		assert_equal "3:2..3:5", out[6].line_col # name
		assert_equal "3:6..3:6", out[7].line_col #;
		assert_equal "3:7..4:1", out[8].line_col # \n
		assert_equal "4:1..4:1", out[9].line_col # }

		assert_equal "4:2..5:1", out[10].line_col # \n
		assert_equal "5:1..6:1", out[11].line_col # \n

		assert_equal "6:1..6:3", out[12].line_col # \tfor
		assert_equal "6:5..6:5", out[13].line_col # 1
		assert_equal "6:6..6:7", out[14].line_col # ..
		assert_equal "6:8..6:8", out[15].line_col # 2
		assert_equal "6:9..7:1", out[16].line_col # \n
		assert_equal "7:2..7:6", out[17].line_col # \twhile
		assert_equal "7:8..7:11", out[18].line_col # true
		assert_equal "7:12..8:1", out[19].line_col # \n
		assert_equal "8:3..8:7", out[20].line_col # \t\tfalse
		assert_equal "8:9..8:13", out[21].line_col # until
		assert_equal "8:15..8:18", out[22].line_col # true
		assert_equal "8:19..9:1", out[23].line_col # \n
		assert_equal "9:2..9:4", out[24].line_col # end
		assert_equal "9:5..10:1", out[25].line_col # \n
		assert_equal "10:1..10:3", out[26].line_col # end
	end

	def test_debug
		Ore.lex '{ a=1, b="two", c=three }'
	end
end
