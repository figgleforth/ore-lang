require_relative '../ore'

module Ore
	class Interpreter < Stage
		attr_accessor :i, :runtime

		def initialize input = [], runtime = nil
			super input
			@runtime = runtime
		end

		def output & block
			@runtime ||= Ore::Runtime.new(Ore::Global.with_standard_library)

			result = input.each.inject nil do |result, expr|
				interpret expr
			end

			if block_given?
				yield result, runtime
			end

			return result
		end

		def scope_for_identifier expr
			unless expr.is_a? Ore::Identifier_Expr
				return runtime.stack.last
			end

			case expr.scope_operator&.value
			when '../' # global
				runtime.stack.first
			when './' # underlying type within context
				runtime.stack.reverse_each.find do |scope|
					scope.instance_of? Ore::Type
				end
			when '.' # instance within context
				runtime.stack.reverse_each.find do |scope|
					scope.is_a? Ore::Instance
				end
			else
				# If no scope operator, search through all scopes to find the identifier
				found_scope = nil
				runtime.stack.reverse_each do |scope|
					if scope.has?(expr.value) || scope.respond_to?("proxy_#{expr.value}")
						found_scope = scope
						break
					elsif scope.is_a?(Ore::Instance) && scope.enclosing_scope&.has?(expr.value)
						# Method exists on the Type - return the instance as the scope so lookups happen in instance context
						found_scope = scope
						break
					end
				end
				found_scope
			end
		end

		def maybe_instance expr
			# todo, when String and so on, because everything needs to be some type of scope to live inside the runtime. Every object in Ore::Scope.declarations{} is either a primitive like String, Integer, Float, or they're an instanced version like Ore::Number.
			case expr
			when Integer, Float
				# Ore::Number_Expr is already handled in #interpret but this is short-circuiting that for cases like 1.something where we have to make sure the 1 is no longer a numeric literal, but instead a runtime object version of the number 1.
				scope             = Ore::Number.new expr
				scope.type        = Ore.type_of_number_expr expr
				scope.numerator   = expr
				scope.denominator = 1
				scope
			when ::String
				string = Ore::String.new expr
				link_instance_to_type string, 'String'
				string
			when ::Array
				array = Ore::Array.new expr
				link_instance_to_type array, 'Array'
				array
			when ::Hash
				dict = Ore::Dictionary.new expr
				link_instance_to_type dict, 'Dictionary'
				dict
			when nil
				Ore::Nil.shared
			when true
				Ore::Bool.truthy
			when false
				Ore::Bool.falsy
			else
				expr
			end
		end

		def link_instance_to_type instance, type_name
			global_scope = runtime.stack.first
			if global_scope.has? type_name
				instance.enclosing_scope = global_scope[type_name]
			end
		end

		def check_dot_access_permissions scope, ident, expr
			binding = Ore.binding_of_ident scope, ident
			privacy = Ore.privacy_of_ident ident

			case scope
			when Ore::Instance
				if privacy == :private && runtime.stack.last != scope
					raise Ore::Cannot_Call_Private_Instance_Member.new(expr, runtime)
				end
			when Ore::Type
				if binding == :instance
					raise Ore::Cannot_Call_Instance_Member_On_Type.new(expr, runtime)
				elsif privacy == :private
					raise Ore::Cannot_Call_Private_Static_Member_On_Type.new(expr, runtime)
				end
			end
		end

		# todo: Maybe this should go on Ore::Server?
		def collect_routes_from_instance instance
			routes = {}

			instance.types.each do |type_name|
				type_def = runtime.stack.first[type_name]
				next unless type_def && type_def.respond_to?(:routes) && type_def.routes

				# Merge routes from this type
				type_def.routes.each do |key, route|
					routes[key] ||= route
				end
			end

			routes
		end

		def render_dom_to_html dom_instance
			render = dom_instance.declarations['render']

			inner_html = if render
				call_expr           = Ore::Call_Expr.new
				call_expr.receiver  = render
				call_expr.arguments = []

				render_result = interp_func_call render, call_expr

				"".tap do |html|
					if render_result.is_a? ::String
						html << render_result

					elsif render_result.is_a? Ore::Array
						render_result.values.each do |child|
							if child.is_a? ::String
								html << child
							elsif child.is_a?(Ore::Instance) && child.types.include?('Dom')
								html << render_dom_to_html(child)
							end
						end

					elsif render_result.is_a?(Ore::Instance) && render_result.types.include?('Dom')
						html << render_dom_to_html(render_result)

					end
				end
			end

			Ore::Dom_Renderer.new(dom_instance, inner_html).to_html_string
		end

		def interp_identifier expr
			if expr.directive
				# todo: Why is this not handled by Parser#complete_expression?
				dir_expr      = Ore::Directive_Expr.new
				dir_expr.name = expr
				return interp_directive dir_expr
			end

			scope = case expr.value
			when 'nil'
				return nil
			when 'true'
				# todo, return Ore::Bool.truthy
				return true
			when 'false'
				# todo, return Ore::Bool.falsy
				return false
			else
				scope_for_identifier expr
			end

			value = if scope.is_a? ::Array
				found = scope.reverse_each.find do |scope|
					scope.has? expr.value
				end

				if found && found.has?(expr.value)
					found[expr.value]
				else
					raise Ore::Undeclared_Identifier.new(expr, runtime)
				end
			elsif scope
				# note: Delegate ruby calls automatically
				proxy_method = "proxy_#{expr.value}"
				if scope.has?(expr.value) && !scope.respond_to?(proxy_method)
					result = scope.get expr.value
					# If the result is a function, duplicate it and set its enclosing_scope to the current scope. This ensures composed types (like `Thing | Record`) have functions that reference the correct type
					if result.is_a? Ore::Func
						func                 = result.dup
						func.enclosing_scope = scope
						return func
					end
					result
				elsif scope.respond_to? proxy_method
					type_name      = scope.class.name.split('::').last
					type_scope     = runtime.stack.reverse_each.find { |s| s.has?(type_name) }
					type_def       = type_scope[type_name] if type_scope
					declared_value = type_def[expr.value] if type_def

					if declared_value.is_a? Ore::Func
						# Use the actual function from the Type, not an empty wrapper
						func                 = declared_value.dup
						func.enclosing_scope = scope
						return func
					else
						# It's a variable/property
						return scope.send(proxy_method)
					end
				elsif scope.is_a?(Ore::Instance) && scope.enclosing_scope&.is_a?(Ore::Type) && scope.enclosing_scope&.has?(expr.value)
					# todo: This seems like a hack. This currently prevents instances from shadowing it's type's declarations.
					# Method/property exists on the Type, not the instance
					value = scope.enclosing_scope.get expr.value
					if value.is_a? Ore::Func
						func                 = value.dup
						func.enclosing_scope = scope
						return func
					else
						return value
					end
				else
					raise Ore::Undeclared_Identifier.new(expr, runtime)
				end
			else
				# When scope is nil, errors must be raised
				if expr.scope_operator&.value == './'
					raise Ore::Cannot_Use_Type_Scope_Operator_Outside_Type.new(expr, runtime)
				elsif expr.scope_operator&.value == '.'
					raise Ore::Cannot_Use_Instance_Scope_Operator_Outside_Instance.new(expr, runtime)
				else
					raise Ore::Undeclared_Identifier.new(expr, runtime)
				end
			end

			# todo: Currently there is no clear rule on multiple unpacks. :double_unpack
			if expr.unpack && value.is_a?(Ore::Instance)
				runtime.stack.last.sibling_scopes << value
			end

			value
		end

		def interp_string expr
			return expr.value unless expr.interpolated

			interpolation_char_count = expr.value.count INTERPOLATE_CHAR
			if interpolation_char_count == 1
				return expr.value # For now... I think this is still not the correct approach.
			elsif interpolation_char_count > 1
				# todo: Proprely learn regex. For now, here's a description of what the regex below does:
				#
				# String: "Hi, |name|!"
				# Matches: ["name"]
				# Result: Interpolates the `name` variable

				# String: "Hi, \|name\|!"
				# Matches: []
				# Result: No interpolation, backslashes protect the pipes

				# String: "Hi, |first| and \|second\|"
				# Matches: ["first"]
				# Result: Only interpolates `first`, not `second`
				#

				result    = expr.value
				sub_exprs = result.scan(/(?<!\\)\|(.*?)(?<!\\)\|/).flatten

				sub_exprs.each do |sub|
					expression = Ore.parse sub
					value      = interpret expression.first
					result     = result.gsub "|#{sub}|", "#{value}"
				end
				result.gsub('\\', '') # Remove any escapes from the resulting string? Is this okay? I don't know...
			end
		end

		def interp_prefix expr
			# note: See constants.rb PREFIX for exhaustive list of language-defined prefixes
			case expr.operator.value
			when '-'
				-interpret(expr.expression)
			when '+'
				+interpret(expr.expression)
			when '~'
				~interpret(expr.expression)
			when '!', 'not'
				!interpret(expr.expression)
			when 'return'
				returned = interpret expr.expression
				Ore::Return.new returned
			else
				raise Ore::Unhandled_Prefix.new(expr, runtime)
			end
		end

		# @param expr [Ore::Infix_Expr]
		def interp_infix_equals expr
			assignment_scope = scope_for_identifier expr.left

			# If using a scope operator but the scope doesn't exist, raise an error
			if expr.left.is_a?(Ore::Identifier_Expr) && expr.left.scope_operator && assignment_scope.nil?
				case expr.left.scope_operator.value
				when '.'
					raise Ore::Cannot_Use_Instance_Scope_Operator_Outside_Instance.new(expr, runtime)
				when './'
					raise Ore::Cannot_Use_Type_Scope_Operator_Outside_Type.new(expr, runtime)
				else
					raise Ore::Invalid_Scope_Syntax.new(expr, runtime)
				end
			end

			# For plain identifiers (no scope operator) inside an Instance/Type body, new declarations should go to that Instance/Type, not to an enclosing scope that happens to have the same identifier. This fixes a bug that prevented HTML Layout's `title` from capturing Title's `title` declaration in examples/basic_html_page.ore.
			if expr.left.is_a?(Ore::Identifier_Expr) && !expr.left.scope_operator
				current_scope    = runtime.stack.last
				assignment_scope ||= current_scope

				if (current_scope.is_a?(Ore::Instance) || current_scope.is_a?(Ore::Type)) &&
				   assignment_scope != current_scope && !current_scope.has?(expr.left.value)
					# The identifier exists in an enclosing scope but not in the current
					# Instance/Type. Treat this as a new declaration on the current scope.
					assignment_scope = current_scope
				end
			end

			#
			# Special handling for load directive assignment, subscript, and maybe more later.
			#

			if expr.left.is_a? Ore::Subscript_Expr
				if expr.left.expression.expressions.count > 1
					raise Ore::Too_Many_Subscript_Expressions.new(expr.left, runtime)
				end
				# note: I'm interpreting only the first expression of left.expression.expressions as the key because the brackets are a Circumfix_Expr which uses an array to store the values.
				receiver      = interpret expr.left.receiver
				key           = interpret expr.left.expression.expressions.first
				receiver[key] = interpret expr.right
				return receiver[key] # note: Intentionally returning the value here because the code starting with the directive check runs to the end of the method. todo: Imrpove?
			end

			# Handle dot assignment
			if expr.left.is_a?(Ore::Infix_Expr) && expr.left.operator.value == '.'
				receiver = interpret expr.left.left
				property = expr.left.right

				check_dot_access_permissions receiver, property.value, expr

				right_value              = interpret expr.right
				receiver[property.value] = right_value
				return right_value
			end

			if expr.right.is_a?(Ore::Directive_Expr) && expr.right.name.value == Ore::IMPORT_FILE_DIRECTIVE
				filepath  = interpret expr.right.expression
				new_scope = Ore::Scope.new expr.left.value
				runtime.load_file_into_scope filepath, new_scope
				right_value = new_scope
			else
				right_value = interpret expr.right
			end

			case Ore.type_of_identifier expr.left.value
			when :IDENTIFIER
				# It can only be assigned once, so if the declaration exists, fail.
				if assignment_scope.has? expr.left.value
					raise Ore::Cannot_Reassign_Constant.new(expr.left, runtime)
				end
			when :Identifier
				# It can only be assigned `value` of Ore::Scope, which includes Ore::Type
				if !right_value.is_a?(Ore::Scope)
					raise Ore::Cannot_Assign_Incompatible_Type.new(expr, runtime)
				end
			when :identifier
				# It can be assigned and reassigned, so do nothing.
			end

			assignment_scope.declare expr.left.value, right_value

			# Track static declarations
			if expr.left.is_a?(Ore::Identifier_Expr) && expr.left.scope_operator&.value == './'
				assignment_scope.static_declarations ||= Set.new
				assignment_scope.static_declarations.add expr.left.value.to_s
			end

			return right_value
		end

		# @param expr [Ore::Infix_Expr]
		def interp_dot_infix expr
			return interp_dot_new expr if expr.right.is 'new'

			receiver = maybe_instance interpret expr.left

			unless receiver.kind_of?(Ore::Scope) || receiver.kind_of?(Ore::Range)
				raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime)
			end

			case receiver
			when Ore::Array, Ore::Tuple
				interp_dot_array_or_tuple expr
			when Ore::Range
				interp_dot_range expr
			when Ore::Dictionary
				interp_dot_dictionary expr
			else
				# @copypaste from #interp_dot_scope because we already interpreted expr as 'left'. If #interp_dot_scope interprets expr again, we end up with duplicate duplicate isntnatiations

				unless expr.right.instance_of? Ore::Identifier_Expr
					raise Ore::Invalid_Dot_Infix_Right_Operand.new(expr.right, runtime)
				end

				check_dot_access_permissions receiver, expr.right.value, expr

				runtime.push_scope receiver
				result = interpret expr.right
				runtime.pop_scope
				result
			end
		end

		def interp_dot_new expr
			receiver = interpret expr.left
			unless receiver.is_a? Ore::Type
				raise Ore::Cannot_Initialize_Non_Type_Identifier.new(expr.left, runtime)
			end

			instance             = Ore::Instance.new receiver.name # :generalize_me
			instance.expressions = receiver.expressions

			runtime.push_scope instance
			instance.expressions.each do |it|
				interpret it
			end
			runtime.pop_scope

			instance
		end

		def interp_dot_array_or_tuple expr
			scope = maybe_instance interpret expr.left

			case
			when expr.right.is(Ore::Func_Expr) && expr.right.name.value == 'each'
				interp_each_loop scope, expr.right
				scope

			when expr.right.is(Ore::Number_Expr)
				scope.values[expr.right.value]

			when expr.right.is(Ore::Array_Index_Expr)
				expr.right.indices_in_order.reduce(scope) do |current, index|
					raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime) unless current.is_a?(Ore::Array)
					current.get index
				end

			else
				interp_dot_scope expr
			end
		end

		def interp_dot_range expr
			range = interpret expr.left # maybe_instance interpret expr.left
			if expr.right.is(Ore::Func_Expr) && expr.right.name.value == 'each'
				interp_each_loop range, expr.right
			end
			range
		end

		def interp_dot_dictionary expr
			dict = maybe_instance interpret expr.left

			if expr.right.is_a? Ore::Identifier_Expr
				key_sym = expr.right.value.to_sym
				if dict.dict.has_key?(key_sym)
					return dict.dict[key_sym]
				end
			end

			# todo: Handle the case when dictionary keys shadow one of the builtin dictionary functions. Ideally check the dict scope first, then dict.dict, but manually check the scope instead of using #interpret because #interpret will look up the stack so the identifier may be found and evaluated despite not existing in dictionary.dict or dictionary the built-in.
			runtime.push_scope dict
			result = interpret expr.right
			runtime.pop_scope

			result
		end

		def interp_dot_scope expr
			scope = maybe_instance interpret expr.left

			raise Ore::Invalid_Dot_Infix_Left_Operand.new(expr, runtime) if scope.nil?
			raise Ore::Invalid_Dot_Infix_Right_Operand.new(expr.right, runtime) unless expr.right.instance_of? Ore::Identifier_Expr

			check_dot_access_permissions scope, expr.right.value, expr

			runtime.push_scope scope
			result = interpret expr.right
			runtime.pop_scope
			result
		end

		def interp_each_loop collection, func_expr
			collection.each do |it|
				each_scope                 = Ore::Scope.new 'each{->}'
				each_scope.enclosing_scope = runtime.stack.last
				runtime.push_scope each_scope
				each_scope.declare 'it', it
				func_expr.expressions.each { |e| interpret e }
				runtime.pop_scope
			end
		end

		# The values for expr.operator, expr.left, and expr.right should all exist by this point
		# @param expr [Ore::Nil_Init_Expr]
		def interp_nil_init expr
			# attr_accessor :operator, :left, :right
			# puts "here #{expr.inspect}"
			# puts "left: #{expr.left.inspect}"
			begin
				left = interpret expr.left
				return left if left
			rescue # Ore::Undeclared_Identifier is the expected error
				runtime.stack.last.declare expr.left.value, interpret(expr.right)
			end
		end

		# @param expr [Ore::Infix_Expr]
		def interp_infix expr
			case expr.operator.value
			when '='
				interp_infix_equals expr
			when '.'
				interp_dot_infix expr
			when '<<'
				# todo: This was implemented sometime when I first got arrays working, but it shouldn't be special-cased like this. Once operator declarations work then this can be declared on Array as `<< {iten > .values.push(item) }`
				left  = maybe_instance interpret expr.left
				right = interpret expr.right

				if left.is_a?(Ore::Array)
					left.values << right
				else
					begin
						# todo: I don't like generic approach because the type of `left` is unknown at this moment.
						left.send expr.operator.value, right
					rescue
						# todo: Proper error
						raise "Unsupported << operator for #{expr.inspect}"
					end
				end
			else
				if expr.left.value == Ore::RUNTIME_SCOPE_OPERATOR
					case expr.operator.value
					when '+='
						right = interpret expr.right
						raise Ore::Invalid_Unpack_Infix_Right_Operand.new(expr, runtime) unless right.is_a? Ore::Scope
						runtime.stack.last.sibling_scopes << right
					when '-='
						right = interpret expr.right
						raise Ore::Invalid_Unpack_Infix_Right_Operand.new(expr, runtime) if right && !(right.is_a? Ore::Scope)
						runtime.stack.last.sibling_scopes.delete right # todo: Warn or error when trying to -= a scope that isn't a sibling?
					else
						raise Invalid_Unpack_Infix_Operator.new(expr, runtime)
					end
				elsif INFIX_ARITHMETIC_OPERATORS.include? expr.operator.value
					left  = maybe_instance interpret expr.left
					right = maybe_instance interpret expr.right
					left.send expr.operator.value, right

				elsif COMPARISON_OPERATORS.include? expr.operator.value
					left  = interpret expr.left
					right = interpret expr.right
					left.send expr.operator.value, right

				elsif COMPOUND_OPERATORS.include? expr.operator.value
					# (a += b)  ==>  (a = (a + b))
					# Compute the arithmetic operation directly
					base_op = expr.operator.value[..-2] # Trim the = from +=, -=, etc.
					left    = maybe_instance interpret expr.left
					right   = maybe_instance interpret expr.right
					result  = left.send base_op, right

					# Assign back to left side
					assignment_scope = scope_for_identifier expr.left
					assignment_scope.declare expr.left.value, result

				elsif RANGE_OPERATORS.include? expr.operator.value
					start  = interpret expr.left
					finish = interpret expr.right
					case expr.operator.value
					when '..'
						Ore::Range.new start, finish
					when '.<'
						Ore::Range.new start, finish, exclude_end: true
					when '>.'
						Ore::Range.new start + 1, finish
					when '><'
						Ore::Range.new start + 1, finish, exclude_end: true
					end

				elsif LOGICAL_OPERATORS.include? expr.operator.value
					case expr.operator.value
					when '&&', 'and'
						interpret(expr.left) && interpret(expr.right)
					when '||', 'or'
						interpret(expr.left) || interpret(expr.right)
					when '&'
						interpret(expr.left) & interpret(expr.right)
					when '|'
						interpret(expr.left) | interpret(expr.right)
					end
				end
			end
		end

		def interp_postfix expr
			# note: See constants.rb POSTFIX for exhaustive list of language-defined postfixes. Currently there are no built-in postfix operators.
			raise Ore::Unhandled_Postfix.new(expr, runtime)
		end

		def interp_circumfix expr
			case expr.grouping
			when '[]'
				array             = Ore::Array.new
				array.expressions = expr.expressions

				values = []
				expr.expressions.each do |e|
					result = interpret e
					values << result
				end
				link_instance_to_type array, 'Array'

				# Make values accessible as an Ore identifier - point to the array itself so `for values` works
				array.values                 = values
				array.declarations['values'] = array

				array
			when '()'
				if expr.expressions.empty?
					Ore::Tuple.new 'Tuple' # todo: For now, I guess. What else should I do with empty parens?
				elsif expr.expressions.count == 1
					# note: Single expressions should be treated as though they were not inside parentheses so that algebraic expressions can be grouped using parentheses. If I wrap single expressions in a Tuple then I have to also unwrap them later for arithmetic operations.
					interpret expr.expressions.first
				else
					values       = expr.expressions.reduce([]) do |arr, expr|
						arr << interpret(expr)
					end
					tuple        = Ore::Tuple.new 'Tuple'
					tuple.values = values
					tuple
				end
			when '{}'
				expr.expressions.reduce(Ore::Dictionary.new) do |dict, it|
					if it.is_a? Ore::Identifier_Expr
						dict[it.value.to_sym] = nil
					elsif it.is_a? Ore::Infix_Expr
						case it.operator.value
						when ':', '='
							if it.left.is_a?(Ore::Identifier_Expr) || it.left.is_a?(Ore::Symbol_Expr) || it.left.is_a?(Ore::String_Expr)
								dict[it.left.value.to_sym] = interpret it.right
							else
								# The left operand should be allowed to be any hashable object. It's too early in the project to consider hashing but this'll be a good reminder.
								raise Ore::Invalid_Dictionary_Key.new(it, runtime)
							end
						else
							raise Ore::Invalid_Dictionary_Infix_Operator.new(it, runtime)
						end
					end
					# In case I forget, #reduce requires that the injected value be returned to be passed to the next iteration.
					dict
				end
			else
				# todo: Proper error
				raise "Interpreter#interp_circumfix unhandled circumfix #{expr.inspect}"
			end
		end

		def interp_call expr
			receiver = interpret expr.receiver

			case receiver
			when Ore::Route
				interp_func_call receiver.handler, expr

			when Ore::Func
				interp_func_call receiver, expr

			when Ore::Instance, Ore::Type
				interp_type_call receiver, expr

			else
				raise Ore::Cannot_Initialize_Non_Type_Identifier.new expr.receiver, runtime
			end
		end

		def interp_type expr
			type             = Ore::Type.new expr.name.value
			type.expressions = expr.expressions

			ore_name = "Ore::#{expr.name.value}"
			defined  = Object.const_defined? ore_name
			link_instance_to_type type, expr.name.value if defined

			if type.types
				type.types << type.name
			else
				type.types = [type.name]
			end

			# todo: Make @types a set
			type.types = type.types.uniq

			runtime.push_then_pop type do |scope|
				expr.expressions.each do |expr|
					interpret expr
				end
			end

			runtime.stack.last.declare type.name, type
			type
		end

		def interp_type_call type, expr
			#
			# Ore::Type_Expr is converted to Ore::Type in #interp_type.
			# Ore::Instance inherits Ore::Type's @name and @types.
			#
			#     (See types.rb for Ore::Type and Ore::Instance declarations)
			#     (See expressions.rb for Ore::Type_Expr declaration)
			#
			# - Push instance onto runtime.stack
			# - Interpret type.expressions so the declarations are made on the instance
			# - Keep instance on the runtime.stack
			# - For each Ore::Func declared on instance, set `func.enclosing_scope = instance`
			# - Interpret instance[:new], the initializer
			# - Delete :new from instance, no longer needed
			#

			# todo: Clean this up
			ore_name = "Ore::#{type.name}"
			instance = if Object.const_defined?(ore_name)
				konstant = Object.const_get(ore_name)
				# note: Only instantiate if it's a subclass of Instance (but not Instance itself) to exclude core runtime types like Type, Scope, Func, etc.
				if konstant.is_a?(Class) && konstant < Ore::Instance && konstant != Ore::Instance
					if konstant.respond_to?(:new)
						konstant.new
					else
						konstant
					end
				else
					Ore::Instance.new type.name
				end
			else
				types               = type.types.to_a # note: Types is a set, so the #to_a lets me iterate below
				first_composed_with = "Ore::#{types[1] || types[0]}" # note: types[0] is this type's name, fallback to itself

				first_composition = if Object.const_defined? first_composed_with
					Object.const_get first_composed_with
				else
					Ore::Instance
				end

				if first_composition < Ore::Instance && first_composition != Ore::Instance
					first_composition.new
				else
					Ore::Instance.new type.name
				end
			end

			instance.types           = type.types
			instance.enclosing_scope = type

			# note: There was a bug here where I wasn't popping the instance after interpreting the type's expressions. That caused the #new function below (func_new) to not properly interpret arguments passed to it.
			runtime.push_then_pop type do
				runtime.push_then_pop instance do |scope|
					type.expressions.each do |expr|
						# Skip static declarations - they were already executed during type definition and shouldn't be re-executed for each instance
						if expr.is_a?(Ore::Infix_Expr) && expr.operator&.value == '=' &&
						   expr.left.is_a?(Ore::Identifier_Expr) && expr.left.scope_operator&.value == './'
							next
						end

						if expr.is_a?(Ore::Func_Expr) && expr.name.is_a?(Ore::Identifier_Expr) &&
						   expr.name.scope_operator&.value == './'
							next
						end

						interpret expr
					end
				end
			end

			instance.declarations.each do |key, decl|
				next unless decl.is_a? Ore::Func

				cloned                     = decl.dup
				cloned.enclosing_scope     = instance
				instance.declarations[key] = cloned
			end

			func_new = instance[:new]
			if func_new
				interp_func_call func_new, expr
			else
				if expr.arguments.count > 0
					# todo: Proper error
					raise "Given #{expr.arguments.count} arguments, but new{->} was not declared for #{type.name}"
				end
			end

			instance.delete :new
			instance
		end

		def interp_func expr
			func                 = Ore::Func.new expr.lexeme
			func.enclosing_scope = runtime.stack.last
			func.expressions     = expr.expressions

			if func.name&.value
				runtime.stack.last.declare func.name.value, func

				# Track static functions (functions defined with ..)
				# Get the original name expression to check for scope operator
				if expr.name.is_a?(Ore::Identifier_Expr) && expr.name.scope_operator&.value == './'
					runtime.stack.last.static_declarations ||= Set.new
					runtime.stack.last.static_declarations.add func.name.value
				end
			end

			func
		end

		def interp_func_call func, expr
			params = func.expressions.select do |expr|
				expr.is_a? Ore::Param_Expr
			end

			if expr.arguments.count > params.count
				# todo: Proper error
				raise "Arguments given, no params declared #{expr.inspect}"
			end

			# Evaluate arguments in caller's scope (before pushing function scopes)
			arg_values     = expr.arguments.map { |arg| interpret arg }
			func.arguments = arg_values

			# Push type scope if calling an instance method (instance methods need access to type-level declarations)
			if func.enclosing_scope.is_a?(Ore::Instance) && func.enclosing_scope.enclosing_scope
				runtime.push_scope func.enclosing_scope.enclosing_scope # Push the Type
			end
			runtime.push_scope func.enclosing_scope
			runtime.push_scope func

			params.each_with_index do |param, i|
				value = if i < arg_values.length
					arg_values[i]
				elsif param.default
					interpret param.default
				else
					raise Ore::Missing_Argument.new(expr, runtime)
				end

				runtime.stack.last.declare param.name.value, value

				if param.unpack && value.is_a?(Ore::Instance)
					func.sibling_scopes << value
				end
			end

			body = func.expressions - params
			if func.name == 'assert'
				raise Ore::Assert_Triggered.new(expr, runtime) unless interpret(body.first) == true # Just to be explicit.
			end

			result = nil
			body.each do |e|
				next if e.is_a? Ore::Param_Expr

				result = interpret e
				break if result.is_a? Ore::Return
			end

			Ore.assert runtime.pop_scope == func
			Ore.assert runtime.pop_scope == func.enclosing_scope

			if func.enclosing_scope.is_a?(Ore::Instance) && func.enclosing_scope.enclosing_scope
				Ore.assert runtime.pop_scope == func.enclosing_scope.enclosing_scope
			end

			result.is_a?(Ore::Return) ? result.value : result
		end

		# @param route [Ore::Route] The route to execute
		# @param req [Ore::Request] Request object to inject
		# @param res [Ore::Response] Response object to inject
		# @param url_params [Hash] Extracted URL parameters (e.g., {"id" => "123"})
		# @param server_instance [Ore::Instance] The server instance (for accessing instance variables)
		# @return The result of handler execution
		def interp_route_handler route, req, res, url_params = {}, server_instance: nil
			handler = route.handler
			params  = handler.expressions.select { |e| e.is_a? Ore::Param_Expr }

			call_scope = Ore::Scope.new "#{handler.name || 'anonymous'}_route"
			runtime.push_scope handler.enclosing_scope
			runtime.push_scope server_instance if server_instance
			runtime.push_scope call_scope

			# Make request and response available without explicit declaration
			call_scope.declare 'request', req
			call_scope.declare 'response', res

			# Bind URL parameters as function arguments. For example, get://:abc/:def { abc, def -> }
			params.each do |param|
				value = url_params[param.name.value] || url_params[param.name.value.to_sym]

				if value.nil?
					if route.param_names.include? param.name.value
						# todo: I haven't triggered this yet to ensure this works.
						# todo: Proper error
						raise "Route parameter '#{param.name.value}' expected but not found in URL"
					end

					# Use default value or raise
					if param.default
						value = interpret param.default
					else
						# todo: Is this reachable?
						raise Ore::Missing_Argument.new(expr, runtime)
					end
				end

				call_scope.declare param.name.value, value
			end

			body   = handler.expressions - params
			result = nil

			body.compact.each do |expr|
				# bug todo: Sometimes body contains `nil` when that should never be the case
				next if expr.is_a? Ore::Param_Expr # Reminder, param expressions are part of the function body by design. This is redundant because I'm subtracting the params from the handler expressions a few lines above, but just in case!

				result = interpret expr
				break if result.is_a? Ore::Return
			end

			if result.is_a? ::String
				res.body_content         = result
				res.declarations['body'] = result
			elsif result.is_a? Ore::Array
				html = ''
				result.values.each do |it|
					if it.is_a? ::String
						html += it
					elsif it.is_a?(Ore::Instance) && it.types.include?('Dom')
						html += render_dom_to_html it
					end
				end
				res.body_content         = html
				res.declarations['body'] = html
			elsif result.is_a? Ore::Instance
				# todo: Maybe find a better class name than Dom, and add a constant for it.
				if result.types.include? 'Dom'
					html                     = render_dom_to_html result
					res.body_content         = html
					res.declarations['body'] = html
				else
					res.body_content         = result.inspect
					res.declarations['body'] = result.inspect
				end
			end

			# Clean up scopes in reverse order
			popped_call = runtime.pop_scope
			Ore.assert popped_call == call_scope

			if server_instance
				popped_instance = runtime.pop_scope
				Ore.assert popped_instance == server_instance
			end

			popped_enclosing = runtime.pop_scope
			Ore.assert popped_enclosing == handler.enclosing_scope

			result
		end

		# @param expr [Ore::Fence_Expr]
		def interp_fence expr
			Ore::Fence.new expr.value # note: Ore::Fence extends Ore::String
		end

		# @param expr [Ore::Html_Fence_Expr]
		def interp_html_fence expr
			interp_string expr.body
		end

		def interp_route expr
			func = interpret expr.expression

			route                 = Ore::Route.new
			route.name            = func.name
			route.enclosing_scope = runtime.stack.last
			route.handler         = func
			route.http_method     = expr.http_method
			route.path            = expr.path
			route.path            = route.path[1..] if route.path.start_with? '/'
			route.param_names     = expr.param_names || []

			route.parts = route.path.split('/').reject do
				_1.empty?
			end

			route_key = if func.name
				func.name
			else
				# Anonymous route with auto-generated key: "method:path"
				"#{route.http_method.value}:#{route.path}"
			end

			# Store route in the enclosing Type's @routes if it has one (e.g., Server)
			enclosing_type = runtime.stack.reverse.find do |scope|
				scope.is_a?(Ore::Type) || scope.is_a?(Ore::Server)
			end
			if enclosing_type
				enclosing_type.routes            ||= {}
				enclosing_type.routes[route_key] = route
			end

			runtime.routes[route_key] = route
			runtime.stack.last.declare route_key, route

			route
		end

		def interp_composition expr
			# These are interpreted sequentially, so there are no precedence rules. I think that'll be better in the long term because there's no magic behind their evaluation. You can ensure the correct outcome by using these operators to form the types you need.

			right      = maybe_instance interp_identifier expr.identifier
			unless right.is_a? Ore::Scope
				# todo: Proper error
				raise "Expected a scope to compose with, got #{right.inspect}"
			end
			curr_scope = runtime.stack.last

			case expr.operator.value
			when '|'
				# Union with Ore::Type
				right.declarations.each do |key, value|
					curr_scope[key] ||= value
				end

				curr_scope.static_declarations ||= Set.new
				curr_scope.static_declarations.merge right.static_declarations

				curr_scope.types ||= []
				curr_scope.types += right.types
				curr_scope.types = curr_scope.types.uniq
			when '~'
				# Removal of Ore::Type

				operand_keys_to_remove = right.declarations.keys

				# Maybe I'll have other keys to protect in the future.
				operand_keys_to_remove.reject! do |key|
					key.to_s == 'new'
				end

				operand_keys_to_remove.each do |key|
					curr_scope.delete key
				end

				curr_scope.static_declarations.subtract right.static_declarations

				curr_scope.types = curr_scope.types.reject do |type|
					type == expr.identifier.value
				end
			when '&'
				# Intersection of Types, aka what they share.

				shared_keys    = right.declarations.keys.select do |key|
					curr_scope.has? key
				end
				keys_to_delete = curr_scope.declarations.keys - shared_keys

				keys_to_delete.each do |key|
					curr_scope.declarations.delete key
				end

				curr_scope.static_declarations = curr_scope.static_declarations & right.static_declarations

			when '^'
				# Symmetric difference of Types, aka what they don't share.

				shared_keys = curr_scope.declarations.keys.select do |key|
					right.has? key
				end

				current_unique_keys = curr_scope.declarations.keys - shared_keys
				operand_unique_keys = right.declarations.keys - shared_keys
				keys_to_keep        = current_unique_keys + operand_unique_keys

				curr_scope.declarations.delete_if do |key, _|
					!keys_to_keep.include? key
				end

				curr_scope.static_declarations = curr_scope.static_declarations ^ right.static_declarations

				operand_unique_keys.each do |key|
					curr_scope[key] ||= right[key]
				end
			else
				# todo: Proper error
				raise "Unknown composition operator #{expr.operator.value}"
			end
		end

		def truthy? value
			!(value == nil || value == 0 || value == false) # todo? does this need to check truthiness of ore constructs?
		end

		# @param for_loop_expr [Ore::For_Loop_Expr]
		def interp_for_loop for_loop_expr
			collection = interpret for_loop_expr.collection
			stride     = interpret(for_loop_expr.stride) if for_loop_expr.stride

			Ore.assert stride.nil? || stride.is_a?(Integer), "Stride must be an integer" if stride

			loop_type = for_loop_expr.type&.value || 'each' # one of Ore::FOR_VERBS
			result    = nil

			runtime.push_then_pop Scope.new('for_loop') do |scope|
				values = case collection
				when Ore::Range
					collection
				when Ore::Array
					collection.values
				when Ore::String
					collection.value.chars
				else
					collection
				end

				# New for-loop verbs, to be handled with stride and without
				#
				#   for <collection> [verb: map/select/reject] [by <stride>]
				#   end
				#
				iterate_body = -> (element, index) do
					scope.declare 'it', element
					scope.declare 'at', index
					body_result = nil
					catch :skip do
						for_loop_expr.body.each do |e|
							body_result = interpret e
							throw(:stop, body_result) if body_result.is_a? Ore::Return
						end
					end
					body_result
				end

				# Initialize collection variables outside catch block so they persist after stop
				collected = []
				count_val = 0

				stop_value = catch :stop do
					if stride
						slices = values.each_slice(stride).to_a

						case loop_type
						when 'each'
							slices.each_with_index do |elements, index|
								result = iterate_body.call elements, index
							end
						when 'map'
							slices.each_with_index do |elements, index|
								collected << iterate_body.call(elements, index)
							end
						when 'select'
							slices.each_with_index do |elements, index|
								collected << elements if truthy? iterate_body.call(elements, index)
							end
						when 'reject'
							slices.each_with_index do |elements, index|
								collected << elements unless truthy? iterate_body.call(elements, index)
							end
						when 'count'
							slices.each_with_index do |elements, index|
								count_val += 1 if truthy? iterate_body.call(elements, index)
							end
						end
					else
						case loop_type
						when 'each'
							values.each_with_index do |element, index|
								result = iterate_body.call element, index
							end
						when 'map'
							values.each_with_index do |element, index|
								collected << iterate_body.call(element, index)
							end
						when 'select'
							values.each_with_index do |element, index|
								collected << element if truthy? iterate_body.call(element, index)
							end
						when 'reject'
							values.each_with_index do |element, index|
								collected << element unless truthy? iterate_body.call(element, index)
							end
						when 'count'
							values.each_with_index do |element, index|
								count_val += 1 if truthy? iterate_body.call(element, index)
							end
						end
					end
					nil
				end

				# Assign results after catch block so partial results are preserved on stop
				case loop_type
				when 'map', 'select', 'reject'
					result = Ore::Array.new(collected)
				when 'count'
					result = count_val
				end

				result     = stop_value if stop_value.is_a? Ore::Return
			end # of runtime.push_then_pop

			result
		end

		def interp_conditional expr
			# I'm being very explicit with the "== true" checks of the condition. It's easy to misread this to mean that as long as it's not nil. While the distinction in this case may not matter (in Ruby), I still haven't decided how this language will handle truthiness.
			case expr.type.value
			when 'while', 'until', 'elwhile'
				result    = nil
				condition = interpret expr.condition

				index = 0
				if expr.type.value == 'until'
					catch :stop do
						until condition == true
							catch :skip do
								index += 1
								runtime.stack.last.declare 'at', index

								expr.when_true.each do |stmt|
									result = interpret(stmt)
								end
							end
							condition = interpret(expr.condition)
						end
					end
				else
					catch :stop do
						while condition == true
							catch :skip do
								index += 1
								runtime.stack.last.declare 'at', index

								expr.when_true.each do |stmt|
									result = interpret(stmt)
								end
							end
							condition = interpret(expr.condition)
						end
					end
				end

				if expr.when_false.is_a? Ore::Conditional_Expr
					result = interp_conditional expr.when_false
				elsif expr.when_false.is_a? ::Array
					expr.when_false.each do |expr|
						result = interpret expr
					end
				end

				return result
			when 'unless'
				# @Copypaste from the else clause below. This is simple to factor out.
				# The behavior of truthiness is not yet finalized.
				condition = interpret expr.condition
				body      = if condition == false || condition.nil?
					expr.when_true
				else
					expr.when_false
				end

				if body.is_a? Ore::Conditional_Expr
					interp_conditional body
				else
					body.each.inject(nil) do |result, expr|
						interpret expr
					end
				end

			else
				condition = interpret expr.condition
				body      = if condition == true
					expr.when_true
				else
					expr.when_false
				end

				if body.is_a? Ore::Conditional_Expr
					interp_conditional body
				else
					result = body.each.inject(nil) do |result, expr|
						interpret expr
					end

					result || nil
				end
			end
		end

		def interp_directive expr
			case expr.name.value
			when 'puts'
				value = interpret expr.expression
				puts value # note: Don't remove this like I did, it is supposed to print out. todo: Be able to set your own output stream
				value
			when 'super'
				# The @super directive evaluates to the result of calling the ruby Ruby method
				func_scope = runtime.stack.last
				unless func_scope.is_a? Ore::Func
					raise Ore::Invalid_Super_Proxy_Directive_Usage.new func_scope, runtime
				end

				func_name        = func_scope.name
				proxy_method     = "proxy_#{func_name.value}"
				instance_or_type = func_scope.enclosing_scope # An instance or type that should have the ruby method declared

				# note: For static proxies on Types (like Record.find), create a temporary instance of the Ruby class. This allows the proxy method to access the Type's declarations.
				target = if instance_or_type.instance_of?(Ore::Type) && instance_or_type.name
					# Check all types in the composition to find a matching Ruby class
					matching_class = nil
					instance_or_type.types.to_a.reverse.each do |type_name|
						ore_class_name = "Ore::#{type_name}"
						if Object.const_defined?(ore_class_name)
							konstant = Object.const_get ore_class_name
							if konstant.is_a?(Class) && konstant < Ore::Instance
								matching_class = konstant
								break
							end
						end
					end

					if matching_class
						temp_instance              = matching_class.new instance_or_type.name
						temp_instance.declarations = instance_or_type.declarations
						# todo: Do static_declarations need to be copied over?
						temp_instance
					else
						instance_or_type
					end
				else
					instance_or_type
				end

				unless target.respond_to? proxy_method
					raise Ore::Missing_Super_Proxy_Declaration.new expr, runtime
				end

				result = target.send proxy_method, *func_scope.arguments

				# Auto-link instances created by proxy methods to their global types
				if result.is_a?(Ore::Instance) && result.enclosing_scope.nil?
					type_name = result.class.name.split('::').last
					link_instance_to_type result, type_name
				end

				result
			when 'start'
				server_instance = interpret expr.expression
				unless server_instance.is_a? Ore::Instance
					raise Ore::Invalid_Start_Diretive_Argument.new(expr, runtime)
				end

				routes = collect_routes_from_instance server_instance

				server_runner = Ore::Server_Runner.new server_instance, self, routes
				runtime.servers << server_runner

				server_runner.start
				server_runner
			when 'connect'
				database = interpret expr.expression
				database.create_connection!
				database

			when Ore::IMPORT_FILE_DIRECTIVE
				# Standalone load is interpreted into current scope by passing the scope into runtime#load_file
				filepath = interpret expr.expression
				runtime.load_file_into_scope filepath, runtime.stack.last
				# note: #load_file_into_scope returns the output but it's ignored. Assigning the value of a @use directive executres code in #interp_infix_expr
			else
				# todo: Allow builtins to be extended by the user. Requirements would be:
				#   1) Create type in Ore
				#   2) Create equivalent type in scopes.rb or similar
				#   3) Make sure functions which use the @super expression in its body are named in to match the Ore::Type "proxy_#{func_name}"
				# For example, `String { upcase { -> @super } }` maps to `Ore::String@super_upcase`
				raise Ore::Invalid_Directive_Usage.new(expr, runtime)
			end
		end

		def interp_subscript expr
			if expr.expression.expressions.count > 1
				raise Ore::Too_Many_Subscript_Expressions.new(expr.expression, runtime)
			end

			receiver = maybe_instance interpret expr.receiver

			case receiver
			when Ore::Dictionary, Ore::Array
				key = interpret expr.expression.expressions.first
				receiver[key]
			when Ore::Nil
				# todo: What should happen when subscripting nil? A warning of some kind maybe?
				nil
			when Ore::String
				index = interpret expr.expression.expressions.first
				receiver.value[index]
			else
				raise Ore::Invalid_Subscript_Receiver.new(expr.receiver, runtime)
			end
		end

		def interpret expr
			case expr
			when Ore::Number_Expr, Ore::Symbol_Expr
				expr.value

			when Ore::Identifier_Expr
				interp_identifier expr

			when Ore::String_Expr
				interp_string expr

			when Ore::Type_Expr
				interp_type expr

			when Ore::Route_Expr
				interp_route expr

			when Ore::Func_Expr
				interp_func expr

			when Ore::Composition_Expr
				interp_composition expr

			when Ore::Prefix_Expr
				interp_prefix expr

			when Ore::Nil_Init_Expr
				# This is a special infix expression `<ident>,` where left is assigned nil if it doesn't exist, or is returned if it does
				interp_nil_init expr

			when Ore::Infix_Expr
				interp_infix expr

			when Ore::Postfix_Expr
				interp_postfix expr

			when Ore::Circumfix_Expr
				interp_circumfix expr

			when Ore::Call_Expr
				interp_call expr

			when Ore::For_Loop_Expr
				interp_for_loop expr

			when Ore::Conditional_Expr
				interp_conditional expr

			when Ore::Array_Index_Expr
				maybe_instance expr.indices_in_order

			when Ore::Subscript_Expr
				interp_subscript expr

			when Ore::Directive_Expr
				interp_directive expr

			when Ore::Fence_Expr
				interp_fence expr

			when Ore::Html_Fence_Expr
				interp_html_fence expr

			when Ore::Comment_Expr
				expr.value

			when Ore::Operator_Expr
				case expr.value
				when 'skip'
					throw :skip
				when 'stop'
					throw :stop
				end
			when nil
			else
				raise Ore::Interpret_Expr_Not_Implemented.new(expr, runtime)
			end
		end
	end
end
