require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Type_Checker_Test < Base_Test
	def assert_type_error & block
		assert_raises Ore::Type_Checking_Failed, &block
	end

	def refute_type_error & block
		refute_raises Ore::Type_Checking_Failed, &block
	end

	# --- Happy paths ---

	def test_string_annotation_with_string_literal
		refute_type_error { Ore.interp "x: String = 'hello'" }
	end

	def test_number_annotation_with_number_literal
		refute_type_error { Ore.interp 'x: Number = 42' }
	end

	def test_symbol_annotation_with_symbol_literal
		refute_type_error { Ore.interp 'x: Symbol = :ok' }
	end

	def test_unannotated_assignment_is_not_checked
		refute_type_error { Ore.interp "x = 123" }
		refute_type_error { Ore.interp "x = 'hello'" }
		refute_type_error { Ore.interp "x = :sym" }
	end

	def test_unknown_rhs_is_skipped
		# Identifier on RHS with unknown type, so no error. todo: Maybe print a warning?
		refute_type_error { Ore.interp "y = 1, x: Number = y" }
	end

	# --- Mismatches at top level ---

	def test_string_annotation_with_number_literal
		assert_type_error { Ore.interp "x: String = 123" }
	end

	def test_string_annotation_with_symbol_literal
		assert_type_error { Ore.interp "x: String = :hello" }
	end

	def test_number_annotation_with_string_literal
		assert_type_error { Ore.interp "x: Number = 'hello'" }
	end

	def test_number_annotation_with_symbol_literal
		assert_type_error { Ore.interp "x: Number = :hello" }
	end

	def test_symbol_annotation_with_string_literal
		assert_type_error { Ore.interp "x: Symbol = 'hello'" }
	end

	def test_symbol_annotation_with_number_literal
		assert_type_error { Ore.interp "x: Symbol = 42" }
	end

	# --- Nested in function body ---

	def test_mismatch_nested_in_func_body
		assert_type_error { Ore.interp "go {; x: Number = 'oops' }" }
	end

	def test_valid_annotation_nested_in_func_body
		refute_type_error { Ore.interp "go {; x: Number = 42 }" }
	end

	def test_mismatch_in_func_param_default_is_caught
		assert_type_error { Ore.interp "go { x: Number = 'bad'; x }" }
	end

	# --- Nested in type body ---

	def test_mismatch_nested_in_type_body
		assert_type_error { Ore.interp "Point { x: Number = 'bad' }" }
	end

	def test_valid_annotation_nested_in_type_body
		refute_type_error { Ore.interp "Point { x: Number = 0 }" }
	end

	# --- Nested in conditional ---

	def test_mismatch_in_if_when_true_branch
		assert_type_error { Ore.interp "if true \n x: String = 99 \n end" }
	end

	def test_mismatch_in_if_when_false_branch
		assert_type_error { Ore.interp "if true \n y = 1 \n else \n x: String = 99 \n end" }
	end

	def test_valid_annotation_in_conditional
		refute_type_error { Ore.interp "if true \n x: String = 'ok' \n end" }
	end

	# --- Nested in for loop ---

	def test_mismatch_in_for_loop_body
		assert_type_error { Ore.interp "for [1, 2, 3] \n x: String = 99 \n end" }
	end

	def test_valid_annotation_in_for_loop_body
		refute_type_error { Ore.interp "for [1, 2, 3] \n x: Number = 1 \n end" }
	end

	# --- Nested in prefix expression ---

	def test_mismatch_inside_prefix_expression
		assert_type_error { Ore.interp "!(x: Number = 'bad')" }
	end

	# --- Call site argument type checking ---

	def test_call_site_string_arg_where_number_expected
		assert_type_error { Ore.interp "add { a: Number, b: Number; a + b }, add(1, 'oops')" }
	end

	def test_call_site_number_arg_where_string_expected
		assert_type_error { Ore.interp "greet { name: String; name }, greet(42)" }
	end

	def test_call_site_symbol_arg_where_number_expected
		assert_type_error { Ore.interp "double { x: Number; x + x }, double(:bad)" }
	end

	def test_call_site_correct_args_passes
		refute_type_error { Ore.interp "add { a: Number, b: Number; a + b }, add(1, 2)" }
	end

	def test_call_site_correct_string_arg_passes
		refute_type_error { Ore.interp "greet { name: String; name }, greet('hello')" }
	end

	def test_call_site_unknown_arg_is_skipped
		# Identifier arg — type unknown statically, no error
		refute_type_error { Ore.interp "x = 'oops', add { a: Number; a }, add(x)" }
	end

	def test_call_site_only_typed_params_are_checked
		# Second param has no type annotation — should not error
		refute_type_error { Ore.interp "add { a: Number, b; a }, add(1, 'anything')" }
	end

	def test_call_site_first_arg_mismatch_caught
		assert_type_error { Ore.interp "add { a: Number, b: Number; a + b }, add('bad', 2)" }
	end

	def test_call_before_func_definition_raises_runtime_error_not_type_error
		# Call appears before definition — type checker can't see the signature yet,
		# so no Type_Checking_Failed. The interpreter raises Undeclared_Identifier instead.
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "add(1, 'oops'), add { a: Number, b: Number; a + b }"
		end
	end
end
