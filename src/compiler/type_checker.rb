module Ore
	class Type_Checker
		attr_accessor :input, :types_by_identifier

		def initialize input
			@input               = input
			@types_by_identifier = {} # { identifier: (Type, function signature) }
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
			when Ore::Identifier_Expr then types_by_identifier[expr.value]
			else nil
			end
		end

		def register_func expr
			return unless expr.name
			params = expr.expressions.select { _1.is_a? Ore::Param_Expr }
			return unless params.any?(&:type)
			types_by_identifier[expr.name.value] = params.map { _1.type&.value }
		end

		def check_call expr
			return nil unless expr.receiver.is_a? Ore::Identifier_Expr
			signature = types_by_identifier[expr.receiver.value]
			return nil unless signature.is_a? ::Array

			expr.arguments.each_with_index.filter_map do |arg, i|
				expected = signature[i]
				next nil unless expected
				inferred = infer_type arg
				next nil if inferred.nil?
				next nil if expected == inferred
				Type_Mismatch.new arg, expected, inferred
			end
		end

		def check_infix expr
			return nil unless expr.operator.value == '='
			return nil unless expr.left.respond_to?(:type) && expr.left.type

			declared                             = expr.left.type.value # e.g. "String"
			types_by_identifier[expr.left.value] = declared
			inferred                             = infer_type expr.right # e.g. "Number" or nil

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

		# `nil` means there is no error with the expression. The pattern for most of the cases is just: recurse into child expressions and collect errors.
		# @return nil, Error, or Array of Errors.
		def check expr
			case expr
			when Ore::Infix_Expr
				check_infix expr

			when Ore::Param_Expr
				check_param expr

			when Ore::Directive_Expr
				check expr.expression
			when Ore::Prefix_Expr
				check expr.expression
			when Ore::Postfix_Expr
				check expr.expression
			when Ore::Route_Expr
				check expr.expression
			when Ore::Return_Expr
				check expr.expression

			when Ore::Circumfix_Expr
				check expr.expressions
			when Ore::Func_Expr
				register_func expr
				check expr.expressions
			when Ore::Type_Expr
				check expr.expressions

			when Ore::Subscript_Expr
				[check(expr.receiver), check(expr.expression)]
			when Ore::For_Loop_Expr
				[check(expr.collection), check(expr.body)]
			when Ore::Call_Expr
				check_call expr

			when Ore::Conditional_Expr
				[
					check(expr.condition),
					check(expr.when_true),
					check(expr.when_false),
				]

			when ::Array
				expr.filter_map { check _1 }

			else
				nil
			end
		end
	end
end
