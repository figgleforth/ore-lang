require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Interpreter_Test < Base_Test
	def test_preload_dot_air
		refute_raises RuntimeError do
			Ore.interp_file './ore/preload.ore'
		end
	end

	def test_numeric_literals
		assert_equal 48, Ore.interp('48')
		assert_equal 15.16, Ore.interp('15.16')
		assert_equal 2342, Ore.interp('23_42')
	end

	def test_true_false_nil_literals
		assert_equal true, Ore.interp('true')
		assert_equal false, Ore.interp('false')
		assert_instance_of NilClass, Ore.interp('nil')
	end

	def test_uninterpolated_strings
		assert_equal 'Walt!', Ore.interp('"Walt!"')
		assert_equal 'Vincent!', Ore.interp("'Vincent!'")
	end

	def test_raises_undeclared_identifier_when_reading
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'hatch'
		end
	end

	def test_does_not_raise_undeclared_identifier_when_assigning
		refute_raises Ore::Undeclared_Identifier do
			Ore.interp 'found = true'
		end
	end

	def test_variable_assignment_and_lookup
		out = Ore.interp 'name = "Locke", name'
		assert_equal 'Locke', out
	end

	def test_constant_assignment_and_lookup
		out = Ore.interp 'ENVIRONMENT = :development, ENVIRONMENT'
		assert_equal :development, out
	end

	def test_cannot_assign_incompatible_type
		assert_raises Ore::Cannot_Assign_Incompatible_Type do
			Ore.interp 'My_Type = :anything'
		end

		refute_raises Ore::Cannot_Assign_Incompatible_Type do
			Ore.interp 'My_Type = Other {}'
		end
	end

	def test_nil_assignment_operator
		out = Ore.interp 'nothing,'
		assert_instance_of NilClass, out
	end

	def test_anonymous_func_expr
		out = Ore.interp '{->}'
		assert_instance_of Ore::Func, out
		assert_empty out.expressions
		refute out.name
	end

	def test_empty_func_declaration
		out = Ore.interp 'open {->}'
		assert_instance_of Ore::Func, out
		assert_empty out.expressions
		assert_equal 'open', out.name.value
	end

	def test_basic_func_declaration
		out = Ore.interp 'enter { numbers = "4815162342" -> }'
		assert_equal 1, out.expressions.count
		assert_instance_of Ore::Param_Expr, out.expressions.first
		assert_instance_of Ore::String_Expr, out.expressions.first.default
	end

	def test_advanced_func_declaration
		out = Ore.interp 'add { a, b -> a + b }'
		assert_equal 3, out.expressions.count
		assert_instance_of Ore::Infix_Expr, out.expressions.last
		refute out.expressions.first.default
	end

	def test_complex_func_declaration
		out = Ore.interp 'run { a, labeled b, c = 4, labeled d = 8 ->
			c + d
		}'
		assert_equal 5, out.expressions.count

		a = out.expressions[0]
		assert_equal 'a', a.name.value
		refute a.label
		refute a.default

		b = out.expressions[1]
		assert b.label
		assert_equal 'labeled', b.label.value
		refute b.default

		c = out.expressions[2]
		assert c.default
		refute c.label

		d = out.expressions[3]
		assert d.label
		assert d.default

		assert_instance_of Ore::Infix_Expr, out.expressions.last
	end

	def test_empty_type_declaration
		out = Ore.interp 'Island {}'
		assert_instance_of Ore::Type, out
		assert_empty out.expressions
		assert_equal 'Island', out.name
	end

	def test_basic_type_declaration
		out = Ore.interp 'Hatch {
			computer = nil

			enter { numbers ->
				# do something with the numbers
			}
		}'
		assert_instance_of Ore::Type, out
		assert_instance_of NilClass, out[:computer]
		assert_instance_of Ore::Func, out[:enter]
	end

	def test_inline_type_composition_declaration
		out = Ore.interp 'Number {}
		Integer | Number {}'
		assert_instance_of Ore::Type, out
		assert_equal %w(Integer Number), out.types
	end

	def test_inbody_type_composition_declaration
		out = Ore.interp 'Numeric {
			numerator,
		}
		Number | Numeric {}
		Float {
			| Number
		}'
		assert_instance_of Ore::Type, out
		assert_equal %w(Float Number Numeric), out.types
	end

	def test_invalid_type_declaration
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'Number | Numeric {}'
		end
	end

	def test_potential_colon_ambiguity
		out = Ore.interp 'assign_to_nil,'
		assert_instance_of NilClass, out

		out = Ore.interp 'func { assign_to_nil -> }'
		assert_instance_of Ore::Func, out
		assert_instance_of Ore::Param_Expr, out.expressions.first
		assert_equal 'assign_to_nil', out.expressions.first.name.value
	end

	def test_infix_arithmetic
		assert_equal 12, Ore.interp('4 + 8')
		assert_equal 4, Ore.interp('1 + 2 * 3 / 4 % 5 ^ 6')
		assert_equal 8, Ore.interp('(1 + (2 * 3 / 4) % 5) << 2')
	end

	def test_nested_type_declaration
		out = Ore.interp '
		Computer {
		}

		Island {
			Hatch {
				Commodore_64 | Computer {}
			}
		}

		Island.Hatch.Commodore_64'
		assert_instance_of Ore::Type, out
	end

	def test_constants_cannot_be_reassigned
		assert_raises Ore::Cannot_Reassign_Constant do
			Ore.interp 'ENVIRONMENT = :development
			ENVIRONMENT = :production'
		end
	end

	def test_variable_declarations
		out = Ore.interp 'cool = "Cooper"'
		assert_equal 'Cooper', out

		out = Ore.interp 'delta = 0.017'
		assert_equal 0.017, out
	end

	def test_declared_variable_lookup
		out = Ore.interp 'number = 42
		number'
		assert_equal 42, out
	end

	def test_variable_can_be_reassigned
		out = Ore.interp 'number = 42'
		assert_equal 42, out

		out = Ore.interp 'number = 42
		number = 8'
		assert_equal 8, out
	end

	def test_inclusive_range
		out = Ore.interp '4..42'
		assert_instance_of Ore::Range, out
		assert_equal 4..42, out
		assert out.include? 4
		assert out.include? 23
		assert out.include? 42
	end

	def test_right_exclusive_range
		out = Ore.interp '4.<42'
		assert_instance_of Ore::Range, out
		assert_equal 4...42, out
		assert out.include? 4
		assert out.include? 41
		refute out.include? 42
	end

	def test_left_exclusive_range
		out = Ore.interp '4>.42'
		assert_instance_of Ore::Range, out
		assert_equal 5..42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 42
	end

	def test_left_and_right_exclusive_range
		out = Ore.interp '4><42'
		assert_instance_of Ore::Range, out
		assert_equal 5...42, out
		refute out.include? 4
		assert out.include? 5
		assert out.include? 41
		refute out.include? 42
	end

	def test_empty_left_and_right_exclusive_range
		out = Ore.interp '0><0'
		assert_equal 1...0, out
		refute out.include? -1
		refute out.include? 0
		refute out.include? 1
		refute out.include? 0.5
	end

	def test_simple_comparison_operators
		assert Ore.interp '1 == 1'
		refute Ore.interp '1 != 1'
		assert Ore.interp '1 != 2'
		assert Ore.interp '1 < 2'
		refute Ore.interp '1 > 2'

		# It doesn't make sense to test all these since I'm just calling through to Ruby
	end

	def test_boolean_logic
		assert Ore.interp 'true && true'
		refute Ore.interp 'true && false'
		assert Ore.interp 'true and true'
		refute Ore.interp 'true and false'
	end

	def test_arithmetic_operators
		out = Ore.interp '1 + 2 / 3 - 4 * 5'
		assert_equal -19, out

		# Right now this functions like the Ruby operator, but it could also be the power operator
		out = Ore.interp '2 ^ 3'
		assert_equal 1, out

		out = Ore.interp '1 << 2'
		assert_equal 4, out

		out = Ore.interp '1 << 3'
		assert_equal 8, out
	end

	def test_double_operators
		out = Ore.interp '1 - -9'
		assert_equal 10, out

		out = Ore.interp '4 + -8'
		assert_equal -4, out

		out = Ore.interp '8 - +15'
		assert_equal -7, out
	end

	def test_empty_array
		out = Ore.interp '[]'
		assert_equal [], out.values
		assert_instance_of Ore::Array, out
	end

	def test_non_empty_arrays
		out = Ore.interp '[1]'
		assert_instance_of Ore::Array, out
		assert_equal [1], out.values

		out = Ore.interp '[1, "test", 5]'
		assert_instance_of Ore::Array, out
		assert_equal Ore::Array.new([1, 'test', 5]).values, out.values
	end

	def test_tuples
		out = Ore.interp '(1, 2)'
		assert_kind_of Ore::Tuple, out
		assert_equal [1, 2], out.values

		out = Ore.interp 't = ("Hello", "from" ,"Tuple")
		t_first = t.0
		t2 = (t.0, t.1, t.2)
		(t_first, t == t2, t_first == t2, t2)'
		assert_equal "Hello", out.values.first
		assert out.values[1]
		refute out.values[2]
		assert_equal ["Hello", "from", "Tuple"], out.values.last.values
	end

	def test_empty_dictionary
		out = Ore.interp '{}'
		assert_kind_of Ore::Dictionary, out
		assert_equal out.dict, {}
	end

	def test_create_dictionary_with_identifiers_as_keys_without_commas
		out = Ore.interp '{a b c}'
		assert_equal %i(a b c), out.dict.keys
		out.dict.values.each do |value|
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_identifiers_as_keys_with_commas
		out = Ore.interp '{a, b}'
		out.dict.values.each do |value|
			assert_instance_of NilClass, value
		end
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation
		out = Ore.interp '{ x:0 y=1 z}'
		refute_instance_of NilClass, out.dict.values.first
		refute_instance_of NilClass, out.dict.values[1]
		assert_instance_of NilClass, out.dict.values.last
	end

	def test_create_dictionary_with_keys_and_values_with_mixed_infix_notation_and_commas
		out = Ore.interp '{ x:4, y=8, z}'
		assert_equal 4, out.dict.values.first
		assert_equal 8, out.dict.values[1]
		assert_instance_of NilClass, out.dict.values.last
	end

	def test_create_dictionary_with_local_value
		out = Ore.interp 'x=4, y=2, { x=x, y=y }'
		assert_equal out.dict, { x: 4, y: 2 }
	end

	def test_symbol_as_dictionary_keys
		out = Ore.interp '{ :x = 1 }'
		assert_equal out.dict, { x: 1 }
	end

	def test_string_as_dictionary_keys
		out = Ore.interp '{ "x" = 1 }'
		assert_equal out.dict, { x: 1 }
	end

	def test_colon_as_dictionary_infix_operator
		out = Ore.interp 'x = 123, { x: x }'
		assert_equal out.dict, { x: 123 }
	end

	def test_equals_as_dictionary_infix_operator
		out = Ore.interp 'x = 123, { x = x }'
		assert_equal out.dict, { x: 123 }
	end

	def test_dictionary_keys
		out = Ore.interp '{ a b c }.keys()'
		assert_equal [:a, :b, :c], out
	end

	def test_dictionary_values
		out = Ore.interp '{ a b c }.values()'
		assert_equal [nil, nil, nil], out

		out = Ore.interp '{ a=1, b= "two", c: :three }.values()'
		assert_equal [1, "two", :three], out

		out = Ore.interp '{ a=1, b="two", c: :three }.values()'
		assert_equal [1, "two", :three], out

		out = Ore.interp '{ a=1, b:"two", c: :three }.values()'
		assert_equal [1, "two", :three], out
	end

	def test_dictionary_subscript
		out = Ore.interp "dict = {x}
		original = dict[:x]
		dict[:x] = 4815
		(original, dict[:x])"
		assert_equal [nil, 4815], out.values
	end

	def test_dictionary_subscript_string_and_symbol_are_different
		out = Ore.interp "dict = {x=4815}
		(dict['x'], dict[:x])"
		assert_equal [nil, 4815], out.values
	end

	def test_too_many_dictionary_subscript_arguments
		assert_raises Ore::Too_Many_Subscript_Expressions do
			Ore.interp "dict = {x=4815}
			dict[:x, 123]"
		end

		assert_raises Ore::Too_Many_Subscript_Expressions do
			Ore.interp "dict = {x=4815}
			dict[:x, 123] = 162342"
		end
	end

	def test_nested_dictionary_subscript
		out = Ore.interp '{ a: { b: 42 } }[:a][:b]'
		assert_equal 42, out
	end

	def test_dictionary_subscript_nonexistent_key
		out = Ore.interp '{ a: 1 }[:nonexistent]'
		assert_nil out
	end

	def test_dictionary_subscript_with_variable
		out = Ore.interp 'key = :a, dict = { a: 99 }, dict[key]'
		assert_equal 99, out
	end

	def test_dictionary_subscript_in_expression
		out = Ore.interp '{ x: 10 }[:x] + 5'
		assert_equal 15, out
	end

	def test_empty_dictionary_subscript
		out = Ore.interp '{}[:key]'
		assert_nil out
	end

	def test_invalid_dictionary_infix
		assert_raises Ore::Invalid_Dictionary_Infix_Operator do
			Ore.interp '{ x > x }'
		end
	end

	def test_assigning_function_to_variable
		out = Ore.interp 'funk = { a, b, c -> }'
		assert_equal 3, out.expressions.count
	end

	def test_composed_type_declaration
		out = Ore.interp '
		Transform {}
		Rotation {}
		Entity {
			| Transform
			~ Rotation
		}'
		assert_kind_of Ore::Type, out
		assert_kind_of Ore::Composition_Expr, out.expressions.first
		assert_kind_of Ore::Composition_Expr, out.expressions.last
		assert_equal 'Rotation', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator.value
	end

	def test_composed_type_declaration_before_body
		out = Ore.interp '
		Transform {}, Physics {}
		Entity | Transform ~ Physics {}'
		assert_kind_of Ore::Type, out
		assert_kind_of Ore::Composition_Expr, out.expressions.first
		assert_kind_of Ore::Composition_Expr, out.expressions.last
		assert_equal 'Physics', out.expressions.last.identifier.value
		assert_equal '~', out.expressions.last.operator.value
	end

	def test_complex_type_declaration
		out = Ore.interp 'Transform {
			position,
			rotation,

			x = 0
			y = 0

			to_s { ->
				"Transform!"
			}
		}'
		assert_kind_of Ore::Infix_Expr, out.expressions[0]
		assert_kind_of Ore::Infix_Expr, out.expressions[1]
		assert_kind_of Ore::Infix_Expr, out.expressions[2]
		assert_kind_of Ore::Infix_Expr, out.expressions[3]
		assert_kind_of Ore::Func_Expr, out.expressions[4]
	end

	def test_undeclared_type_init_with_new_keyword
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp 'Type.new'
		end
	end

	def test_raises_non_type_initialization_error
		assert_raises Ore::Cannot_Initialize_Non_Type_Identifier do
			Ore.interp 'x = 1, x.new'
		end
	end

	def test_declared_type_init_with_new_keyword
		out = Ore.interp 'Type {}, Type.new'
		assert_instance_of Ore::Instance, out
		assert_equal 'Type', out.name
	end

	def test_complex_type_init
		out = Ore.interp 'Transform {
			position,
			rotation,

			x = 4
			y = 8

			to_s { ->
				"Transform!"
			}

			new { position -> }
		}, Transform.new'
		assert_kind_of Ore::Instance, out
		assert_equal 'Transform', out.name
		assert_kind_of ::Array, out.expressions
		assert_equal 6, out.expressions.count
		assert_kind_of Ore::Func_Expr, out.expressions.last
	end

	def test_complex_type_with_value_lookup
		out = Ore.interp 'Vector1 { x = 4 }
		Vector1.new.x
		'
		assert_equal 4, out
	end

	def test_instance_complex_value_lookup
		out = Ore.interp 'Vector2 { x = 1, y = 2 }
		Transform {
			position = Vector2.new
		}
		t = Transform.new
		(t.position, t.position.y)
		'
		assert_kind_of Ore::Tuple, out
		assert_kind_of Ore::Instance, out.values.first
		assert_equal 2, out.values.last
	end

	def test_type_declaration_with_parens
		out = Ore.interp 'Vector2 { x = 0, y = 1 }
		pos = Vector2()'
		assert_instance_of Ore::Instance, out
		data = { 'x' => 0, 'y' => 1 }
		assert_equal data, out.declarations
	end

	def test_dot_slash
		assert_raises Ore::Cannot_Use_Instance_Scope_Operator_Outside_Instance do
			Ore.interp '.x = 123'
		end
	end

	def test_look_up_dot_slash_without_dot_slash
		assert_raises Ore::Cannot_Use_Type_Scope_Operator_Outside_Type do
			Ore.interp './x = 123'
		end
	end

	def test_look_up_dot_slash_with_dot_slash
		out = Ore.interp '../y = 543
		../y'
		assert_equal 543, out
	end

	def test_function_call_with_arguments
		out = Ore.interp '
		add { a, b -> a+b }
		add(4, 8)'
		assert_equal 12, out
	end

	def test_compound_operator
		out = Ore.interp 'add { amount = 1, to = 0 ->
			to += amount
		}
		add(5, 37)'
		assert_equal 42, out
	end

	def test_long_dot_chain
		shared_code = '
		A {
			B {
				C {
					d = 4
				}
			}
		}'

		out = Ore.interp "#{shared_code}
		A.B"
		assert_instance_of Ore::Type, out

		out = Ore.interp "#{shared_code}
		A.B.C.new()"
		assert_instance_of Ore::Instance, out

		out = Ore.interp "#{shared_code}
		A.B.C.new().d"
		assert_equal 4, out
	end

	def test_closures_do_capture_values
		out = Ore.interp '
		counter = -1
		increment { count ->
			counter += count
		}
		increment(counter)
		counter
		'
		assert_equal -2, out
	end

	def test_calling_functions
		refute_raises RuntimeError do
			out = Ore.interp '
			square { input ->
				input * input
			}

			result = square(5)
			result'
			assert_equal 25, out
		end
	end

	def test_function_call_as_argument
		out = Ore.interp '
		add { amount = 1, to = 4 ->
			to + amount
		}
		inc = add() # should return 5
		add(inc, 1)'
		assert_equal 6, out
	end

	def test_complex_return_with_simple_conditional
		out = Ore.interp 'return (1+2*3/4) + (1+2*3/4) if 1 + 2 > 2'
		assert_equal 4, out.value
	end

	def test_truthy_falsy_logic
		assert_equal 1, Ore.interp('if true 1 else 0 end')
		assert_equal 0, Ore.interp('if 0 1 else 0 end')
		assert_equal 0, Ore.interp('if nil 1 else 0 end')
	end

	def test_returns_with_end_of_line_conditional
		out = Ore.interp 'return 3 if true'
		assert_equal 3, out.value
	end

	def test_standalone_array_index_expr
		out = Ore.interp '4.8.15.16.23.42'
		assert_equal [4, 8, 15, 16, 23, 42], out.values
	end

	def test_array_access_by_dot_index
		out = Ore.interp 'things = [4, 8, 15]
		things.0'
		assert_equal 4, out
	end

	def test_array_nested_non_array_dot_index
		assert_raises Ore::Invalid_Dot_Infix_Left_Operand do
			Ore.interp 'things = [4, 8, 15]
		things.0.1'
		end
	end

	def test_nested_array_access_by_dot_index
		out = Ore.interp 'things = [4, [8, 15, 16], 23, [42, 108, 418, 3]]
		(things.1.0, things.3.1)'
		assert_instance_of Ore::Tuple, out
		assert_equal 8, out.values.first
		assert_equal 108, out.values.last
	end

	def test_function_scope
		out = Ore.interp 'x = 123
		double { -> x * 2 }
		double()'
		assert_equal 246, out
	end

	def test_function_scope_some_more
		out = Ore.interp 'x = 108

		Doubler {
			double { -> x * 2 }
		}

		Doubler().double()'
		assert_equal 216, out
	end

	def test_returns
		out = Ore.interp 'return 1'
		assert_instance_of Ore::Return, out
		assert_equal 1, out.value

		out = Ore.interp '
		eject { ->
			if true
				return "true!"
			end

			return "should not get here"
		}
		eject()'
		assert_equal "true!", out
	end

	def test_type_does_have_new_function
		out = Ore.interp '
		Atom {
			new {->}
		}'
		assert out.has? :new
	end

	def test_instance_does_not_have_new_function
		out = Ore.interp '
		Atom {
			new {->}
		}
		a = Atom()
		b = Atom.new()
		(a, b)'
		refute out.values.first.has? :new
		refute out.values.last.has? :new
	end

	def test_while_loops
		out = Ore.interp '
		x = 0
		while x < 4
			x += 1
		end
		x'
		assert_equal 4, out
	end

	def test_fancy_while_loops
		out = Ore.interp '
		x = 0
		y = 0
		z = 0
		while x < 4
			x += 1
		elwhile y > -8
			y -= 1
		else
			z = 1_516
		end
		(x, y, z)'
		assert_equal [4, -8, 1516], out.values
	end

	def test_until_loops
		out = Ore.interp '
		x = 1
		until x >= 23
			x += 2
		end
		'
		assert_equal 23, out
	end

	def test_fancy_until_loops
		out = Ore.interp '
		x = 1
		y = 0
		until x >= 23
			x += 2
		else
			y = x
		end
		(x, y)
		'
		assert_equal [23, 23], out.values
	end

	def test_control_flows_as_expressions
		out = Ore.interp '
		condition = false
		x = unless condition # Equivalent to "if !condition"
			4
		else
			-4
		end
		'
		assert_equal 4, out
	end

	def test_if_and_unless_control_flows
		out = Ore.interp '
		a = if true
			4
		end

		b = if false
			8
		end

		c = unless true
			15
		end

		d = if not true
			23
		else
			16
		end

		(a, b, c, d)
		'
		assert_equal [4, nil, nil, 16], out.values
	end

	def test_nil_instances_are_shared
		out = Ore.interp '
		x,
		y,

		equal = x == y
		(x, y, equal)'
		assert_equal out.values[0].object_id, out.values[1].object_id
		assert_equal true, out.values[2]
	end

	def test_accessing_declarations_through_type_composition
		out = Ore.interp "
		Vec2 {
			x = 0, y = 0

			new { x, y ->
				.x = x
				.y = y
			}

			multiply! { times ->
				.x *= times
				.y *= times
			}

		}

		Transform | Vec2 {
			new { position = Vec2() ->
				.x = position.x
				y = position.y
			}

			to_s { ->
				'Transform(|x|,|y|)'
			}

			scale! { value ->
				multiply!(value)
			}
		}

		pos = Vec2(4, 8)
		t = Transform(pos)
		a = t.to_s()
		t.scale!(3)
		b = t.to_s()

		# Let's remove Vec2 from a type that composes with Transform
		Xform | Transform ~ Vec2 {}

		(a, b, t)"

		# Testing in order of the values in the tuple
		assert_equal "Transform(4,8)", out.values[0]
		assert_equal "Transform(12,24)", out.values[1]

		assert_instance_of Ore::Instance, out.values[2]
		assert_equal 12, out.values[2][:x]
		assert_equal 24, out.values[2][:y]
	end

	def test_random_composition_example
		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp "
			Vec2 {
				x = 0, y = 0

				new { x, y ->
					.x = x
					.y = y
				}
			}

			Transform | Vec2 {
				new { position = Vec2() ->
					.x = position.x
					y = position.y
				}
			}

			Xform | Transform ~ Vec2 {}

			Xform(Vec2(23, 42))
			"
			assert_instance_of Ore::Instance, out
			assert_equal ['Xform', 'Transform'], out.types
		end
	end

	def test_union_composition
		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp '
			Aa {
				a = 1
			}
			Bb {
				a = 4, b = 2, unique = 10
			}

			Union | Aa | Bb {}

			u = Union()
			(u.a, u.b, u.unique)
			'
			assert_equal [1, 2, 10], out.values
		end
	end

	def test_difference_composition
		shared_code = "
			Aa {
				a = 8
				common = 15
			}

			Bb {
				b = 42
				common = 16
			}

			AaBb | Aa | Bb {}

			Diff | AaBb ~ Bb {
				common = 23
			}

			d = Diff()".freeze

		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp "#{shared_code}
			a = Aa()
			b = Bb()
			(d.a, a.common, b.common, d.common)"
			assert_equal [8, 15, 16, 23], out.values
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			d.b"
		end
	end

	def test_intersection_composition
		shared_code = "
			Aa { a = 4,  common = 8 }
			Bb { b = 15, common = 16 }

			Intersected | Aa & Bb {}

			i = Intersected()"

		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp "#{shared_code}
			i.common"
			assert_equal 8, out
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			i.a"
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			i.b"
		end
	end

	def test_symmetric_difference_composition
		shared_code = "
			Aa { a = 4, common = 10 }
			Bb { b = 8, common = 10 }

			Sym_Diff | Aa ^ Bb {}
			s = Sym_Diff()\n"

		out = Ore.interp "#{shared_code} (s.a, s.b)"
		assert_equal [4, 8], out.values

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code} s.common"
		end
	end

	def test_union_composition_is_left_biased
		out = Ore.interp "
		Aa { a = 4 }
		Bb { a = 8 }
		Union | Aa | Bb {}
		Union().a"
		assert_equal 4, out
	end

	def test_composition_with_inbody_declarations
		out = Ore.interp "
		Aa { a = 15 }
		Bb { a = 16, b, }
		Union {
			# With or without space is valid
			| Aa
			|Bb
		}
		u = Union()
		(u.a, u.b)"
		assert_equal [15, nil], out.values
	end

	def test_routes
		out = Ore.interp 'get://some/thing/:id { id ->
			do_something()
		}'

		assert_instance_of Ore::Route, out
		assert_equal 'get', out.http_method.value
		assert_equal 'some/thing/:id', out.path
		assert_equal 2, out.handler.expressions.count
	end

	def test_html_element
		out = Ore.interp "My_Div {
			element = 'div'

			id = 'my_div'
			class = 'my_class'
			data_something = 'some data attribute'

			render { ->
				'Text content of this div'
			}
		}

		it = My_Div()
		(My_Div, it, it.render())"
		assert_instance_of Ore::Type, out.values[0]
		assert_instance_of Ore::Instance, out.values[1]
		assert_instance_of String, out.values[2]
		assert_equal 'Text content of this div', out.values[2]
	end

	def test_loading_external_source_files
		out = Ore.interp "@use 'ore/preload.ore', (Bool, Bool())"

		assert_instance_of Ore::Type, out.values[0]
		assert_kind_of Ore::Instance, out.values[1]
		assert_instance_of Ore::Bool, out.values[1]
	end

	def test_standalone_load_into_current_scope
		out = Ore.interp "@use 'test/fixtures/test_module.ore'
		(MODULE_NAME, MODULE_VALUE, module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_equal "Test_Module", out.values[0]
		assert_equal 42, out.values[1]
		assert_equal 20, out.values[2]
	end

	def test_load_assignment_into_variable_identifier
		out = Ore.interp "mod = @use 'test/fixtures/test_module.ore'
		(mod, mod.MODULE_NAME, mod.MODULE_VALUE, mod.module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "mod = @use 'test/fixtures/test_module.ore'
			MODULE_NAME"
		end
	end

	def test_load_assignment_into_class_identifier
		out = Ore.interp "Module = @use 'test/fixtures/test_module.ore'
		(Module, Module.MODULE_NAME, Module.MODULE_VALUE, Module.module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "Module = @use 'test/fixtures/test_module.ore'
			MODULE_NAME"
		end
	end

	def test_load_assignment_into_constant_identifier
		out = Ore.interp "MODULE = @use 'test/fixtures/test_module.ore'
		(MODULE, MODULE.MODULE_NAME, MODULE.MODULE_VALUE, MODULE.module_func(10))"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_equal "Test_Module", out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 20, out.values[3]

		# Verify declarations are NOT in current scope
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "MODULE = @use 'test/fixtures/test_module.ore'
			MODULE_NAME"
		end
	end

	def test_load_same_file_into_multiple_scopes
		out = Ore.interp "
		lib1 = @use 'test/fixtures/test_module.ore'
		lib2 = @use 'test/fixtures/test_module.ore'

		(lib1, lib2, lib1.MODULE_VALUE, lib2.MODULE_VALUE, lib1 != lib2)"

		assert_instance_of Ore::Tuple, out
		assert_instance_of Ore::Scope, out.values[0]
		assert_instance_of Ore::Scope, out.values[1]
		assert_equal 42, out.values[2]
		assert_equal 42, out.values[3]
		assert out.values[4]

		# Scopes are different objects even though loaded from same file
		refute_equal out.values[0].object_id, out.values[1].object_id
	end

	def test_double_loading_file
		assert_raises Ore::Cannot_Reassign_Constant do
			out = Ore.interp "
			@use 'test/fixtures/constants.ore'
			@use 'test/fixtures/constants.ore'"
		end
	end

	def test_for_loop
		out = Ore.interp "
		NUMBERS = [4, 8, 15, 16, 23, 42]
		numbers = []

		for NUMBERS
			numbers << it
		end

		(numbers == NUMBERS, numbers, NUMBERS)"
		assert out.values[0]
	end

	def test_for_loop_with_scopes
		out = Ore.interp <<~ORE
		    Numbers {
		    	numbers = []

				new { numbers ->
					.numbers = numbers
				}

		    	multiply { by ->
					result = []
		    		for .numbers
		    			result.push(it * by)
		    		end
		    		result
		    	}
		    }

		    Numbers([1, 2, 3]).multiply(2)
		ORE
		assert_equal [2, 4, 6], out.values
	end

	def test_for_loop_by_strides
		out = Ore.interp "
		NUMBERS = [4, 8, 15, 16, 23, 42]
		numbers = []

		for NUMBERS by 2
			numbers << it
		end

		numbers"
		assert_equal [[4, 8], [15, 16], [23, 42]], out.values
	end

	def test_for_loop_at_and_it_builtins
		out = Ore.interp "
		indices = []

		for [4, 8, 15, 16, 23, 42]
			indices << '|at|: |it|'
		end

		indices"
		assert_equal ['0: 4', '1: 8', '2: 15', '3: 16', '4: 23', '5: 42'], out.values
	end

	def test_for_loop_with_ranges
		out = Ore.interp "
		zero = []
		one = []
		two = []
		three = []

		for 1..5
			zero << it
		end

		for 1><5
			one << it
		end

		for 1>.5
			two << it
		end

		for 1.<5
			three << it
		end


		(zero, one, two, three)"
		assert_equal [1, 2, 3, 4, 5], out.values[0].values
		assert_equal [2, 3, 4], out.values[1].values
		assert_equal [2, 3, 4, 5], out.values[2].values
		assert_equal [1, 2, 3, 4], out.values[3].values
	end

	def test_for_loop_skip
		out = Ore.interp "
		result = []
		for [1, 2, 3, 4, 5]
			if it == 3
				skip
			end
			result << it
		end
		result"
		assert_equal [1, 2, 4, 5], out.values
	end

	def test_for_loop_stop
		out = Ore.interp "
		result = []
		for [1, 2, 3, 4, 5]
			if it == 3
				stop
			end
			result << it
		end
		result"
		assert_equal [1, 2], out.values
	end

	def test_for_loop_skip_with_index
		out = Ore.interp "
		result = []
		for ['a', 'b', 'c', 'd']
			if at == 1 or at == 2
				skip
			end
			result << it
		end
		result"
		assert_equal ['a', 'd'], out.values
	end

	def test_for_loop_stop_with_index
		out = Ore.interp "
		result = []
		for ['a', 'b', 'c', 'd']
			if at == 2
				stop
			end
			result << it
		end
		result"
		assert_equal ['a', 'b'], out.values
	end

	def test_nested_for_loop_stop
		out = Ore.interp "
		result = []

		for 0..10
			skip if it == 4

			if it % 2 == 0
				result << 'START |it|'
				for 0..10
					result << it
					stop if it == 2
				end
				result << 'STOP |it|'
			end

			if it == 6
				stop
			end
		end

		result
		"
		assert_equal ["START 0", 0, 1, 2, "STOP 0", "START 2", 0, 1, 2, "STOP 2", "START 6", 0, 1, 2, "STOP 6"], out.values
	end

	def test_for_loop_map
		out = Ore.interp "
		for [1, 2, 3, 4, 5] map
			it * 2
		end"
		assert_equal [2, 4, 6, 8, 10], out.values
	end

	def test_for_loop_map_with_index
		out = Ore.interp "
		for ['a', 'b', 'c'] map
			'|at|:|it|'
		end"
		assert_equal ['0:a', '1:b', '2:c'], out.values
	end

	def test_for_loop_map_with_stride
		out = Ore.interp "
		for [1, 2, 3, 4, 5, 6] map by 2
			it.0 + it.1
		end"
		assert_equal [3, 7, 11], out.values
	end

	def test_for_loop_select
		out = Ore.interp "
		for [1, 2, 3, 4, 5, 6] select
			it % 2 == 0
		end"
		assert_equal [2, 4, 6], out.values
	end

	def test_for_loop_select_with_index
		out = Ore.interp "
		for ['a', 'b', 'c', 'd', 'e'] select
			at < 3
		end"
		assert_equal ['a', 'b', 'c'], out.values
	end

	def test_for_loop_select_with_stride
		out = Ore.interp "
		for [1, 2, 3, 4, 5, 6, 7, 8] select by 2
			it.0 + it.1 > 5
		end"
		assert_equal [[3, 4], [5, 6], [7, 8]], out.values
	end

	def test_for_loop_reject
		out = Ore.interp "
		for [1, 2, 3, 4, 5, 6] reject
			it % 2 == 0
		end"
		assert_equal [1, 3, 5], out.values
	end

	def test_for_loop_reject_with_index
		out = Ore.interp "
		for ['a', 'b', 'c', 'd', 'e'] reject
			at < 2
		end"
		assert_equal ['c', 'd', 'e'], out.values
	end

	def test_for_loop_reject_with_stride
		out = Ore.interp "
		for [1, 2, 3, 4, 5, 6, 7, 8] reject by 2
			it.0 + it.1 > 5
		end"
		assert_equal [[1, 2]], out.values
	end

	def test_for_loop_count
		out = Ore.interp "
		for [1, 2, 3, 4, 5, 6] count
			it % 2 == 0
		end"
		assert_equal 3, out
	end

	def test_for_loop_count_with_index
		out = Ore.interp "
		for ['a', 'b', 'c', 'd', 'e'] count
			at >= 2
		end"
		assert_equal 3, out
	end

	def test_for_loop_count_with_stride
		out = Ore.interp "
		for [1, 2, 3, 4, 5, 6, 7, 8] count by 2
			it.0 + it.1 > 5
		end"
		assert_equal 3, out
	end

	def test_for_loop_map_with_skip
		out = Ore.interp "
		for [1, 2, 3, 4, 5] map
			skip if it == 3
			it * 2
		end"
		assert_equal [2, 4, nil, 8, 10], out.values
	end

	def test_for_loop_map_with_stop
		out = Ore.interp "
		for [1, 2, 3, 4, 5] map
			stop if it == 4
			it * 2
		end"
		assert_equal [2, 4, 6], out.values
	end

	def test_for_loop_verbs_do_not_mutate
		out = Ore.interp "
		original = [1, 2, 3, 4, 5]
		doubled = for original map
			it * 2
		end
		original"
		assert_equal [1, 2, 3, 4, 5], out.values
	end

	def test_while_loop_skip
		out = Ore.interp "
		result = []
		x = 0
		while x < 5
			x += 1
			if x == 3
				skip
			end
			result << x
		end
		result"
		assert_equal [1, 2, 4, 5], out.values
	end

	def test_while_loop_stop
		out = Ore.interp "
		result = []
		x = 0
		while x < 10
			x += 1
			if x == 4
				stop
			end
			result << x
		end
		result"
		assert_equal [1, 2, 3], out.values
	end

	def test_until_loop_skip
		out = Ore.interp "
		result = []
		x = 0
		until x >= 5
			x += 1
			if x == 2 or x == 4
				skip
			end
			result << x
		end
		result"
		assert_equal [1, 3, 5], out.values
	end

	def test_until_loop_stop
		out = Ore.interp "
		result = []
		x = 0
		until x >= 10
			x += 1
			if x == 3
				stop
			end
			result << x
		end
		result"
		assert_equal [1, 2], out.values
	end

	def test_unpack_parameter
		out = Ore.interp "
		Vector {
			x = 0
			y = 0

			new { x, y ->
				.x = x
				.y = y
			}
		}

		add { @vec ->
			x + y
		}

		v = Vector(3, 4)
		add(v)"
		assert_equal 7, out
	end

	def test_unpack_identifier
		out = Ore.interp "
		Point {
			a = 0
			b = 0

			new { a, b ->
				.a = a
				.b = b
			}
		}

		calc { ->
			p = Point(10, 20)
			@ += p
			a + b
		}

		calc()"
		assert_equal 30, out
	end

	def test_sibling_stack_manipulation_with_unpack_operator
		out = Ore.interp "
		Point {
			a = 0
			b = 0

			new { a, b ->
				.a = a
				.b = b
			}
		}

		p = Point(4, 8)
		@ += p
		one = a + b
		@ -= p

		@ += Point(15, 16)
		(one, a + b)"
		assert_equal [12, 31], out.values
	end

	def test_unpack_and_nested_functions
		out = Ore.interp "
		Point {
			a = 0
			b = 0

			new { a, b ->
				.a = a
				.b = b
			}
		}

		outer { ->
			p = Point(23, 42)
			@ += p

			inner { ->
				a + b
			}

			inner()
		}
		outer()"
		assert_equal 65, out
	end

	def test_unpack_right_operand
		assert_raises Ore::Invalid_Unpack_Infix_Right_Operand do
			Ore.interp "@ += 4"
		end

		assert_raises Ore::Invalid_Unpack_Infix_Right_Operand do
			Ore.interp "@ -= 'eight'"
		end
	end

	def test_unpack_invalid_operator
		assert_raises Ore::Invalid_Unpack_Infix_Operator do
			Ore.interp "@ *= 4"
		end

		assert_raises Ore::Invalid_Unpack_Infix_Operator do
			Ore.interp "@ + 'eight'"
		end
	end

	def test_privacy_and_binding
		shared_code = <<~CODE
		    Type {
				# Instance declarations
		    	number = 4
		    	_private = 8

				# Static declarations
				./nilled,
		    	./static = 15
		    	./_static_private = 16

				calling_private_through_instance { -> _private }
		    	calling_static_through_instance { -> static }
		    	calling_static_private_through_instance { -> _static_private }

		    	./calling_static_through_static { -> static }
		    	./calling_static_private_througb_static { -> _static_private }
		    }
		CODE

		out = Ore.interp "#{shared_code}
		Type().number"
		assert_equal 4, out

		out = Ore.interp "#{shared_code}
		Type().calling_private_through_instance()"
		assert_equal 8, out

		out = Ore.interp "#{shared_code}
		Type().static"
		assert_equal 15, out

		out = Ore.interp "#{shared_code}
		Type().calling_static_through_instance()"
		assert_equal 15, out

		out = Ore.interp "#{shared_code}
		Type().calling_static_private_through_instance()"
		assert_equal 16, out

		out = Ore.interp "#{shared_code}
		Type.calling_static_through_static()"
		assert_equal 15, out

		out = Ore.interp "#{shared_code}
		Type.calling_static_private_througb_static()"
		assert_equal 16, out

		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "#{shared_code}
			Type()._private"
		end

		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "#{shared_code}
			Type()._static_private"
		end

		assert_raises Ore::Cannot_Call_Private_Static_Member_On_Type do
			Ore.interp "#{shared_code}
			Type._static_private"
		end

		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "
			Inner { _secret = 42 }
		    Outer { inner = Inner() }
            Outer().inner._secret"
		end

		out = Ore.interp "#{shared_code}
		Type.static = 4815
		Type.static"
		assert_equal 4815, out

		out = Ore.interp "#{shared_code}
		Type.nilled"
		assert_nil out

		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "#{shared_code}
			Type()._private = 100"
		end

		assert_raises Ore::Cannot_Call_Private_Static_Member_On_Type do
			Ore.interp "#{shared_code}
		    Type._static_private = 100"
		end

		assert_raises Ore::Cannot_Call_Instance_Member_On_Type do
			Ore.interp "#{shared_code}
			Type.number"
		end

		assert_raises Ore::Cannot_Use_Type_Scope_Operator_Outside_Type do
			Ore.interp "./whatever"
		end

		assert_raises Ore::Invalid_Scope_Syntax do
			Ore.interp "./123"
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "Type { ./whatever }"
		end

		assert_raises Ore::Invalid_Scope_Syntax do
			x Ore.interp "Type { ./123 }"
		end
	end

	def test_proxy_string_members
		out = Ore.interp "String().length"
		assert_equal 0, out

		out = Ore.interp "'hello'.length"
		assert_equal 5, out

		out = Ore.interp "'a'.ord"
		assert_equal 97, out

		out = Ore.interp "'A'.ord"
		assert_equal 65, out

		out = Ore.interp "'walt!'.upcase()"
		assert_equal "WALT!", out

		out = Ore.interp "'WALT!'.downcase()"
		assert_equal "walt!", out

		assert_raises Ore::Invalid_Super_Proxy_Directive_Usage do
			Ore.interp "@super whatever"
		end

		assert_raises Ore::Invalid_Super_Proxy_Directive_Usage do
			Ore.interp "@super 123"
		end

		assert_raises Ore::Invalid_Super_Proxy_Directive_Usage do
			Ore.interp "Type { @super 123 -> }"
		end
	end

	def test_binding_and_privacy_with_composition
		shared_code = <<~CODE
		    Base {
		    	base_instance_public = 1
		    	_base_instance_private = 2

		    	./base_static_public = 10
		    	./_base_static_private = 20
		    }

		    Other {
		    	other_instance = 3
		    	_other_private = 4

		    	./other_static_public = 30
		    	./_other_static_private = 40
		    }
		CODE

		# Union composition - should merge all members
		out = Ore.interp "#{shared_code}
		Merged | Base | Other {}
		m = Merged()
		(m.base_instance_public, m.other_instance)"
		assert_equal [1, 3], out.values

		# Static members accessible from union
		out = Ore.interp "#{shared_code}
		Merged | Base | Other {}
		Merged.base_static_public"
		assert_equal 10, out

		out = Ore.interp "#{shared_code}
		Merged | Base | Other {}
		Merged.other_static_public"
		assert_equal 30, out

		# Instance can access static from union
		out = Ore.interp "#{shared_code}
		Merged | Base | Other {}
		Merged().base_static_public"
		assert_equal 10, out

		# Privacy preserved through union
		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "#{shared_code}
			Merged | Base | Other {}
			Merged()._base_instance_private"
		end

		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "#{shared_code}
			Merged | Base | Other {}
			Merged()._other_private"
		end

		assert_raises Ore::Cannot_Call_Private_Static_Member_On_Type do
			Ore.interp "#{shared_code}
			Merged | Base | Other {}
			Merged._base_static_private"
		end

		# Binding preserved - cannot access instance members on Type
		assert_raises Ore::Cannot_Call_Instance_Member_On_Type do
			Ore.interp "#{shared_code}
			Merged | Base | Other {}
			Merged.base_instance_public"
		end

		assert_raises Ore::Cannot_Call_Instance_Member_On_Type do
			Ore.interp "#{shared_code}
			Merged | Base | Other {}
			Merged.other_instance"
		end

		# Difference composition - static members removed correctly
		out = Ore.interp "#{shared_code}
		Diff | Base ~ Other {}
		Diff().base_instance_public"
		assert_equal 1, out

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Diff | Base ~ Other {}
			Diff().other_instance"
		end

		# Static members also removed
		out = Ore.interp "#{shared_code}
		Diff | Base ~ Other {}
		Diff.base_static_public"
		assert_equal 10, out

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Diff | Base ~ Other {}
			Diff.other_static_public"
		end

		# Privacy maintained after difference
		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "#{shared_code}
			Diff | Base ~ Other {}
			Diff()._base_instance_private"
		end

		# Intersection composition - keeps only shared members
		shared_code = <<~CODE
		    Left {
		    	shared_instance = 1
		    	_shared_private = 2
		    	left_only = 3

		    	./shared_static = 10
		    	./_shared_static_private = 20
		    	./left_static_only = 30
		    }

		    Right {
		    	shared_instance = 4
		    	_shared_private = 5
		    	right_only = 6

		    	./shared_static = 40
		    	./_shared_static_private = 50
		    	./right_static_only = 60
		    }
		CODE

		# Intersection keeps shared instance members
		out = Ore.interp "#{shared_code}
		Inter | Left & Right {}
		Inter().shared_instance"
		assert_equal 1, out

		# Intersection removes non-shared instance members
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Inter | Left & Right {}
			Inter().left_only"
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Inter | Left & Right {}
			Inter().right_only"
		end

		# Intersection keeps shared static members
		out = Ore.interp "#{shared_code}
		Inter | Left & Right {}
		Inter.shared_static"
		assert_equal 10, out

		# Intersection removes non-shared static members
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Inter | Left & Right {}
			Inter.left_static_only"
		end

		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Inter | Left & Right {}
			Inter.right_static_only"
		end

		# Privacy preserved through intersection
		assert_raises Ore::Cannot_Call_Private_Instance_Member do
			Ore.interp "#{shared_code}
			Inter | Left & Right {}
			Inter()._shared_private"
		end

		assert_raises Ore::Cannot_Call_Private_Static_Member_On_Type do
			Ore.interp "#{shared_code}
			Inter | Left & Right {}
			Inter._shared_static_private"
		end

		# Binding preserved through intersection
		assert_raises Ore::Cannot_Call_Instance_Member_On_Type do
			Ore.interp "#{shared_code}
			Inter | Left & Right {}
			Inter.shared_instance"
		end

		# Symmetric difference composition - keeps only non-shared members
		# Symmetric diff keeps unique instance members from Left
		out = Ore.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym().left_only"
		assert_equal 3, out

		# Symmetric diff keeps unique instance members from Right
		out = Ore.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym().right_only"
		assert_equal 6, out

		# Symmetric diff removes shared instance members
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Sym | Left ^ Right {}
			Sym().shared_instance"
		end

		# Symmetric diff keeps unique static members from Left
		out = Ore.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym.left_static_only"
		assert_equal 30, out

		# Symmetric diff keeps unique static members from Right
		out = Ore.interp "#{shared_code}
		Sym | Left ^ Right {}
		Sym.right_static_only"
		assert_equal 60, out

		# Symmetric diff removes shared static members
		assert_raises Ore::Undeclared_Identifier do
			Ore.interp "#{shared_code}
			Sym | Left ^ Right {}
			Sym.shared_static"
		end

		# Binding preserved through symmetric difference
		assert_raises Ore::Cannot_Call_Instance_Member_On_Type do
			Ore.interp "#{shared_code}
			Sym | Left ^ Right {}
			Sym.left_only"
		end
	end

	def test_static_declarations_fixture
		out = Ore.interp_file 'test/fixtures/static_declarations.ore'
		assert_equal true, out
	end

	def test_puts_directive
		output          = StringIO.new
		original_stdout = $stdout
		$stdout         = output

		begin
			result = Ore.interp "@puts 'Walt!'"
			assert_equal 'Walt!', result
			assert_equal "Walt!\n", output.string
		ensure
			$stdout = original_stdout
		end
	end

	def test_multiple_unpacks
		shared_code = <<~ORE
		    Point {
		    	a = 0
		    	b = 0

		    	new { a, b ->
		    		.a = a
		    		.b = b
		    	}
		    }
		ORE

		out = Ore.interp "#{shared_code}
		p = Point(4, 8)
		@ += p
		(a, b)"
		assert_equal [4, 8], out.values

		# note: Unpacks function like a stack, the most recent unpack is the one whose identifier takes precedence.
		out = Ore.interp "#{shared_code}
		p = Point(4, 8)
		p2 = Point(15, 16)
		@ += p
		@ += p2
		(a, b)"
		assert_equal [15, 16], out.values

		out = Ore.interp "#{shared_code}
		p = Point(4, 8)
		p2 = Point(15, 16)
		@ += p
		@ -= p2
		(a, b)"
		assert_equal [4, 8], out.values
	end

	def test_using_pound_proxy_as_expression
		code = <<~CODE
		    String | String {
		        upcase { ->
		        	@super + " (SWIZZLED)"
		        }
		    }
			"test".upcase()
		CODE
		assert_equal "TEST (SWIZZLED)", Ore.interp(code)
	end

	def test_reading_files
		out = Ore.interp "Inout.read_file_to_string('test/fixtures/hello_read.txt')"
		assert_equal "Hello, Read!\n", out.value # note: There is a newline at the end of the file, so it has to be included here
	end

	def test_writing_files
		Ore.interp "Inout.write_string_to_file('test/fixtures/hello_write.txt', 'Hello, Write!')"
		out = Ore.interp "Inout.read_file_to_string('test/fixtures/hello_write.txt')"
		assert_equal "Hello, Write!", out.value
	end

	def test_fence_expr_returns_string_expr
		out = Ore.interp '```
		some content
		```'
		# Fences unless subclassed will always be instances of Ore::Fence. The html example below transforms the fence into a ::String
		assert_instance_of Ore::Fence, out
		assert out.value.value.include?('some content')
	end

	def test_html_fence_with_interpolation
		out = Ore.interp "
		name = 'Cooper'
		```html
		<h1>Welcome |name|</h1>
		```"
		assert_instance_of ::String, out
		assert_equal '<h1>Welcome Cooper</h1>', out.strip
	end

	def test_html_fence_without_interpolation
		out = Ore.interp '```html
		<p>Plain text</p>
		```'
		assert out.include?('<p>Plain text</p>')
	end

	def test_html_fence_in_route_handler
		out = Ore.interp "
		@use 'ore/server.ore'

		App | Server {
			get:// home {->
				title = 'My Page'
				```html
				<h1>|title|</h1>
				```
			}
		}

		app = App()
		app.home()"
		assert out.include?('<h1>My Page</h1>')
	end

	def test_html_fence_multiline_with_interpolation
		out = Ore.interp "
		name = 'Alice'
		count = 42
		```html
		<div>
			<h1>Hello |name|</h1>
			<p>You have |count| messages</p>
		</div>
		```"
		assert out.include?('Hello Alice')
		assert out.include?('You have 42 messages')
	end

	def test_fence_expr_preserves_content
		out = Ore.interp '```
		line 1
		line 2
		```'

		assert_instance_of Ore::Fence, out
		assert out.value.value.include?('line 1')
		assert out.value.value.include?('line 2')
	end

	# note: The idea is, given (abc,1)
	# if abc exists, use that value
	# if not abc exists, declare abc=nil
	def test_new_comma_nil_init
		out = Ore.interp <<~CODE
		    x = (abc,1)    # declares abc = nil
			(x, abc)
		CODE
		# [[nil, 1], nil]
		assert_equal [nil, 1], out.values.first.values

		out = Ore.interp <<~CODE
		    abc=2, (abc,1),
		CODE
		assert_equal [2, 1], out.values
	end
end
