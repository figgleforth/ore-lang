module Ore
	class Type_Checker < Stage
		def output
			errors = [].tap do |array|
				input.each do |expr|
					result = check(expr)
					array << result
				end
			end.compact

			if errors.any? { _1 != true }
				raise Type_Checking_Failed.new
			end

			errors
		end

		# @param expr [Ore::Number_Expr]
		def check_number expr
			expr.value.is_a? ::Numeric
		end

		# @param expr [Ore::Symbol_Expr]
		def check_symbol expr
			expr.value.is_a? ::Symbol
		end

		# @param expr [Ore::String_Expr]
		def check_string expr
			expr.value.is_a? ::String
		end

		def check_infix expr
			# Type-specific checks (e.g., can't add String + Number)
			check(expr.left) && check(expr.right)
		end

		# When type checking fails, it returns an error. Otherwise returns nil.
		# @param expr [Ore::Expession]
		# @return type check result [true | error ]
		def check expr
			case expr
			when Ore::Number_Expr
				check_number expr
			when Ore::Symbol_Expr
				check_symbol expr
			when Ore::Infix_Expr
				check_infix expr
			when Ore::String_Expr
				check_string expr
				# when Ore::Identifier_Expr
				# when Ore::Type_Expr
				# when Ore::Html_Element_Expr
				# when Ore::Route_Expr
				# when Ore::Func_Expr
				# when Ore::Composition_Expr
				# when Ore::Prefix_Expr
				# when Ore::Postfix_Expr
				# when Ore::Circumfix_Expr
				# when Ore::Call_Expr
				# when Ore::For_Loop_Expr
				# when Ore::Conditional_Expr
				# when Ore::Array_Index_Expr
				# when Ore::Subscript_Expr
				# when Ore::Directive_Expr
				# when Ore::Comment_Expr, Ore::Fence_Expr
				# when Ore::Operator_Expr
				# when nil
			else
				raise
			end
		end
	end
end
