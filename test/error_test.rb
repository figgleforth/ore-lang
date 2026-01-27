require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Error_Test < Base_Test
	def test_undeclared_identifier
		error = assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'does_not_exist'
		end
	end

	def test_undeclared_identifier_in_file
		error = assert_raises Ore::Undeclared_Identifier do
			Ore.interp_file 'test/fixtures/undeclared_identifier.ore'
		end
	end

	def test_cannot_reassign_constant
		error = assert_raises Ore::Cannot_Reassign_Constant do
			Ore.interp 'CONST = 5, CONST = 10'
		end
	end

	def test_cannot_assign_incompatible_type
		error = assert_raises Ore::Cannot_Assign_Incompatible_Type do
			Ore.interp 'Person { name, }, Person = 5'
		end
	end

	def test_cannot_initialize_non_type_identifier
		assert_raises Ore::Cannot_Initialize_Non_Type_Identifier do
			Ore.interp 'x = 5, x()'
		end
	end

	def test_invalid_dictionary_key
		error = assert_raises Ore::Invalid_Dictionary_Key do
			Ore.interp '{5: "value"}'
		end
	end

	def test_invalid_dictionary_infix_operator
		error = assert_raises Ore::Invalid_Dictionary_Infix_Operator do
			Ore.interp '{x + 5}'
		end
	end

	def test_invalid_unpack_infix_operator
		error = assert_raises Ore::Invalid_Unpack_Infix_Operator do
			Ore.interp 'Point { x, y, }, p = Point(), @ * p'
		end
	end

	def test_invalid_unpack_infix_right_operand
		error = assert_raises Ore::Invalid_Unpack_Infix_Right_Operand do
			Ore.interp '@ += 5'
		end
	end

	def test_missing_argument
		# todo: Doesn't display code and location
		assert_raises Ore::Missing_Argument do
			Ore.interp 'add = { a, b; a + b }, add(5)'
		end
	end

	def test_invalid_start_directive_argument
		# todo: Doesn't display code and location
		assert_raises Ore::Invalid_Start_Directive_Argument do
			Ore.interp '@start 5'
		end
	end

	def test_invalid_directive_usage
		# todo: Doesn't display code and location
		assert_raises Ore::Invalid_Directive_Usage do
			Ore.interp '@unknown 123'
		end
	end

	def test_unterminated_string_literal
		# todo: Doesn't display code and location
		assert_raises Ore::Unterminated_String_Literal do
			Ore.interp '"unterminated'
		end
	end

	def test_too_many_subscript_expressions
		error = assert_raises Ore::Too_Many_Subscript_Expressions do
			Ore.interp 'arr = [1, 2, 3], arr[0, 1]'
		end
	end

	def test_error_location_tracking_inline
		error = assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'x = 5, y = undefined_var, z = 10'
		end
	end

	def test_error_location_tracking_file
		error = assert_raises Ore::Undeclared_Identifier do
			Ore.interp_file 'test/fixtures/undeclared_identifier.ore'
		end
	end

	def test_error_with_infix_expression_has_location
		error = assert_raises Ore::Cannot_Reassign_Constant do
			Ore.interp 'CONST = 5, CONST = 10'
		end
	end

	def test_error_formatting_includes_source_snippet
		error = assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'x = 5, y = undefined_var'
		end
	end
end
