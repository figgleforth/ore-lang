module Ore
	class Type_Checker
		attr_accessor :input

		def initialize input
			@input = input
		end

		def output
			errors = input.filter_map { check _1 }.flatten.compact
			if errors.any?
				raise Type_Checking_Failed.new errors
			end
		end

		# Maps an expression to its Ore type name. Returns nil if unknown.
		def infer_type expr
			case expr
			when Ore::String_Expr then 'String'
			when Ore::Number_Expr then 'Number'
			when Ore::Symbol_Expr then 'Symbol'
			else nil
			end
		end

		def check_infix expr
			return nil unless expr.operator.value == '='
			return nil unless expr.left.respond_to?(:type) && expr.left.type
			declared = expr.left.type.value # e.g. "String"
			inferred = infer_type expr.right # e.g. "Number" or nil
			return nil if inferred.nil?
			return nil if declared == inferred

			Type_Mismatch.new expr, declared, inferred
		end

		def check_param expr
			return nil unless expr.type && expr.default
			declared = expr.type.value
			inferred = infer_type expr.default
			return nil if inferred.nil?
			return nil if declared == inferred

			Type_Mismatch.new expr, declared, inferred
		end

		# `nil` means there is no error with the expression.
		# @return nil, Error, or Array of Errors.
		def check expr
			# the pattern for most of the cases is just: recurse into child expressions and collect errors.
			case expr
			when Ore::Infix_Expr
				check_infix expr

			when Ore::Directive_Expr,
				Ore::Prefix_Expr,
				Ore::Postfix_Expr,
				Ore::Route_Expr,
				Ore::Return_Expr
				check expr.expression

			when Ore::Subscript_Expr
				[check(expr.receiver), check(expr.expression)]

			when Ore::Circumfix_Expr,
				Ore::Func_Expr,
				Ore::Type_Expr
				check expr.expressions

			when Ore::Conditional_Expr
				[
					check(expr.condition),
					check(expr.when_true),
					check(expr.when_false),
				]

			when Ore::Param_Expr
				check_param expr

			when Ore::For_Loop_Expr
				[check(expr.collection), check(expr.body)]

			when ::Array
				expr.filter_map { check _1 }

				# when Ore::Call_Expr # todo
			else
				nil
			end
		end
	end
end
