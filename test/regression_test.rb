require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Regression_Test < Base_Test
	def test_greater_equals_regression
		out = Ore.interp '2+1 >= 1'
		assert out
	end

	def test_precedence_operation_regression
		src = Ore.interp '1 + 2 / 3 - 4 * 5'
		ref = Ore.interp '(1 + (2 / 3)) - (4 * 5)'
		assert_equal ref, src
		assert_equal -19, src
	end

	def test_infixes_regression
		Ore::COMPOUND_OPERATORS.each do |operator|
			code = "left #{operator} right"
			out  = Ore.parse(code)
			assert_kind_of Ore::Infix_Expr, out.first
		end
	end

	def test_dot_slashes_regression
		ds  = Ore.parse '.abc'
		dds = Ore.parse './def'
		assert_kind_of Ore::Identifier_Expr, ds.first
		assert_kind_of Ore::Identifier_Expr, dds.first

		ds = Ore.parse '.abc'
		assert_kind_of Ore::Identifier_Expr, ds.last
		assert_equal '.', ds.last.scope_operator.value
		assert_equal 'abc', ds.last.value
	end

	def test_dot_slash_regression
		out = Ore.interp '.x = 123'
		assert_equal 123, out
	end

	def test_look_up_tilde_slash_without_dot_slash_regression
		out = Ore.interp '../x = 456
		x'
		assert_equal 456, out
	end

	def test_look_up_tilde_slash_with_dot_slash_regression
		out = Ore.interp '../y = 789
		../y'
		assert_equal 789, out
	end

	def test_dot_slash_within_infix_regression
		out = Ore.parse '.x? = 123'
		assert_kind_of Ore::Infix_Expr, out.first
		assert_equal '=', out.first.operator.value
		assert_equal 'x?', out.first.left.value
		assert_kind_of Ore::Identifier_Expr, out.first.left
		assert_equal '.', out.first.left.scope_operator.value
	end

	def test_scope_operators_regression
		out = Ore.parse '.this_instance'
		assert_kind_of Ore::Identifier_Expr, out.first
		assert_equal 1, out.count

		out = Ore.parse './class_scope'
		assert_kind_of Ore::Identifier_Expr, out.first
		assert_equal 1, out.count
	end

	def test_assigning_false_value_regression
		out = Ore.interp 'how = false
		how'
		assert_equal false, out
	end

	def test_identifier_lookup_regression
		out = Ore.interp 'Ore {}, Ore'
		assert_instance_of Type, out
	end

	def test_instance_does_not_have_new_function_regression
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

	def test_dot_new_initializer_regression
		out = Ore.interp 'Number {
			numerator = 8

			new { num ->
				.numerator = num
			}
		}
		x = Number.new(15)
		x.numerator'
		assert_equal 15, out
	end

	def test_calling_member_functions
		out = Ore.interp '
		Number {
			numerator = -100

			new { num ->
				.numerator = num
			}
		}
		x = Number(4)
		x.numerator'
		assert_equal 4, out
	end

	def test_dot_slash_regression
		out = Ore.interp '
		Box {
			kind = "NONE"

			new { new_kind ->
				.kind = new_kind
			}

			to_s { ->
				"|kind|-box"
			}
		}

		b1 = Box("Big")
		s1 = b1.to_s()
		b2 = Box("Small")
		s2 = b2.to_s()
		(b1, s1, b2, s2)
		'
		assert_instance_of Ore::Instance, out.values[0]
		assert_equal "Big-box", out.values[1]
		assert_equal "Small-box", out.values[3]
	end

	def test_identifier_lookup_regression
		out = Ore.interp "x = 123
		funk { ->
			../x + 2
		}
		funk()"
		assert_equal 125, out

		out = Ore.interp "y = 0
		add { amount_to_add = 1 ->
			../y + amount_to_add
		}
		(a = add(4))

		(a, add(a * 2))"
		assert_equal [4, 8], out.values

		out = Ore.interp "y = 0
		add { amount_to_add = 1 ->
			y += amount_to_add
		}
		a = add(4)

		(y, a)"
		assert_equal [4, 4], out.values

		refute_raises Ore::Undeclared_Identifier do
			out = Ore.interp "
			Thing {
				id,
				name = 'Thingy'

				new { new_name = '', id = 123 ->
					.name = new_name
					.id = id
				}
			}

			t1 = Thing()
			t2 = Thing('Thingus', 456)

			(t1.id, t1.name, t2.id, t2.name)"
			assert_equal [123, "", 456, "Thingus"], out.values
		end

		assert_raises Ore::Missing_Argument do
			out = Ore.interp "
			Thing {
				id,
				name = 'Thingy',

				new { new_name, id ->
					.name = new_name
					.id = id
				}
			}

			t = Thing() # This will raise
			(t.id, t.name)"
			assert_equal [456, "Thingus"], out.values
		end

		assert_raises Ore::Missing_Argument do
			Ore.interp "
	        funk { it ->
				it == true
			}
			funk() # This will raise
			"
		end

		refute_raises Ore::Undeclared_Identifier do
			Ore.interp "
			funk { it ->
				it == true
			}
			funk(true), funk(false)
			"
		end

		refute_raises Ore::Undeclared_Identifier do
			Ore.interp "
			funk { it = \"true\" ->
				it == true
			}
			funk(true), funk()
			"
		end

		refute_raises Ore::Undeclared_Identifier do
			Ore.interp "
			funk { it = \"false\" ->
				it == true
			}
			funk(true), funk()
			"
		end

		refute_raises Ore::Undeclared_Identifier do
			Ore.interp "
			funk { it = true ->
				it == true
			}
			funk(true), funk()
			"
		end

		refute_raises Ore::Undeclared_Identifier do
			Ore.interp "
			funk { funkit = false ->
				funkit == true
			}
			funk(true), funk()
			"
		end

		refute_raises Ore::Undeclared_Identifier do
			Ore.interp "
			funk { it = nil ->
				it == true
			}
			funk(true), funk()
			"
		end
	end

	def test_lexer_operator_quote_regression
		# #lex_operator was consuming quotes as symbols, creating invalid operators like ="
		# This caused { b="two" } to fail lexing when = was immediately followed by "
		out = Ore.interp '{ a=1, b="two", c: :three }.values()'
		assert_equal [1, "two", :three], out

		out = Ore.interp '{ a=1, b:"two", c: :three }.values()'
		assert_equal [1, "two", :three], out
	end

	def test_nested_type_declaration_shadowing_regression
		# When creating an instance of an inner Type (like Title) inside an outer Type's render function (like Layout), declarations in the inner Type's body (like `title,`) were incorrectly being assigned to the outer Type's instance if it had the same identifier name. This test ensures each Type/Instance has its own namespace.
		out = Ore.interp <<~CODE
		    Outer {
		    	name,

		    	new { name ->
		    		.name = name
		    	}

		    	make_inner { ->
		    		Inner("inner_value")
		    	}
		    }

		    Inner {
		    	name,

		    	new { name ->
		    		.name = name
		    	}

		    	get_name { ->
		    		name
		    	}
		    }

		    outer = Outer("outer_value")
		    inner = outer.make_inner()
		    (outer.name, inner.get_name())
		CODE
		assert_equal "outer_value", out.values[0]
		assert_equal "inner_value", out.values[1]
	end

	def test_dot_slash_inside_for_loop
		# note: Composing Array with itself allows extending or overriding behavior of Array. Notice how `values` is accessible despite being declared on the original Array type.
		without_prefix = <<~CODE
		    Array | Array {
		        each { func ->
		        	for values
		        		func(it)
		        	end
		        }
		    }
		CODE

		with_prefix = <<~CODE
		    Array | Array {
		        each { func ->
		        	for .values
		        		func(it)
		        	end
		        }
		    }
		CODE

		out = Ore.interp <<~CODE
		    values = Array([1,2,3])
		    #{without_prefix}
		    values2 = []
		    values.each({it ->
		    	values2.push(it)
		    })
		    values2
		CODE
		assert_equal [1, 2, 3], out.values

		out = Ore.interp <<~CODE
		    values = Array([1,2,3])
		    #{with_prefix}
		    values2 = []
		    values.each({it ->
		    	values2.push(it)
		    })
		    values2
		CODE
		assert_equal [1, 2, 3], out.values
	end

	def test_broken_static_declarations
		refute_raises Ore::Missing_Super_Proxy_Declaration do
			Ore.interp <<~ORE
			    Thing {
			    	./abc,
			    	./def {->}
			    }

			    	Thing.abc
			ORE
		end

		assert_raises Ore::Database_Not_Set_For_Record_Instance do
			Ore.interp <<~ORE
			    @use 'ore/record.ore'

			    Record.find(1)
			ORE
		end
	end

	def test_commented_closing_brace_causing_infinite_loop
		Ore.interp <<~ORE
		    Thing {
		    #}
		    }
		ORE
	end

	def test_accessing_dictionary_keys_with_dot
		# todo: I plan to make the x inside {x} to set x to whatever x happens to evaluate to. When that happens, {x}.x should return 123!
		out = Ore.interp <<~ORE
		    x = 123
		    {x}.x
		ORE
		assert_nil out
	end

	# https://github.com/figgleforth/ore-lang/issues/80
	def test_parsing_bug_from_issue_80
		assert_instance_of Ore::String_Expr, Ore.parse("'{'").first
		assert_instance_of Ore::String_Expr, Ore.parse("'('").first
		assert_instance_of Ore::String_Expr, Ore.parse("'['").first
	end

	def test_ranges_with_expression
		assert_instance_of Ore::Range, Ore.interp("x=1, 0..x")
		assert_instance_of Ore::Range, Ore.interp("x=1, y=2, 0..(x + y)")
	end
end
