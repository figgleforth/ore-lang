module Ore
	class Expression
		attr_accessor :value, :type, :l0, :c0, :l1, :c1, :source_file
		attr_reader :lexeme

		def initialize lexeme = nil
			self.lexeme = lexeme
			# todo: Uncomment this to continue tracking down.
			# if lexeme && !lexeme.is_a?(Lexeme)
			# warn "#{self} init'd with nil non-Lexeme (#{lexeme})"
			# end
		end

		def lexeme= lexeme
			@lexeme = lexeme
			@value  = if lexeme && lexeme.is_a?(Ore::Lexeme)
				lexeme.value
			else
				lexeme
			end
		end

		def is compare
			if compare.is_a? Symbol
				compare == type
			elsif compare.is_a? ::String
				compare == value
			elsif compare.is_a? Class
				self.is_a? compare
			else
				compare == self
			end
		end

		def isnt compare
			is(compare) == false
		end

		def location
			return nil unless l0 && c0
			"#{source_file}:#{l0}:#{c0}" if source_file
			"#{l0}:#{c0}"
		end

		def line_col
			"#{l0}:#{c0}..#{l1}:#{c1}" if l0
		end
	end

	class Param_Expr < Expression
		attr_accessor :name, :label, :type, :default, :unpack
	end

	class Func_Expr < Expression
		attr_accessor :name, :expressions, :signature

		def signature
			sig         = name&.value || ''
			sig         += '{'
			param_decls = expressions.select do |expr|
				expr.is_a? Param_Expr
			end
			sig         += param_decls.map do |param|
				label   = param.label ? "#{param.label.value}:" : ''
				default = param.default ? "=#{param.default.value}" : ''
				"#{label}#{param.name.value}#{default}"
			end.join(',')
			sig         += Ore::FUNCTION_DELIMITER
			sig         += '}'
			sig
			# todo, Maybe bring back extra signature details.
			# if expressions.any?
			# 	n << '['
			# 	n << expressions.join(',')
			# 	n << ']'
			# end
		end
	end

	# get:// {;}
	# put://whatever/:id {id;}
	# post://book/:id/publish {id;}
	class Route_Expr < Func_Expr
		attr_accessor :http_method, :path, :expression, :param_names # The expression can be a function or an identifier
	end

	class Directive_Expr < Expression
		attr_accessor :name, :expression
	end

	class Type_Expr < Expression
		attr_accessor :name, :expressions
	end

	# Useful reading.
	# https://stackoverflow.com/a/18533211/1426880
	# https://stackoverflow.com/a/1235891/1426880
	class Number_Expr < Expression
	end

	class Symbol_Expr < Expression
	end

	class String_Expr < Expression
		attr_accessor :interpolated

		def initialize lexeme
			super lexeme
			@interpolated = value.include? INTERPOLATE_CHAR
			# todo, This is a naive check. What if there is only one | char? Then it can't be a valid interpolation.
		end
	end

	class Prefix_Expr < Expression
		attr_accessor :operator, :expression
	end

	class Postfix_Expr < Expression
		attr_accessor :operator, :expression
	end

	class Infix_Expr < Expression
		attr_accessor :operator, :left, :right
	end

	class Circumfix_Expr < Expression
		attr_accessor :grouping, :expressions
	end

	class Nil_Init_Expr < Infix_Expr
	end

	class Operator_Expr < Expression
		attr_accessor :custom, :precedence
	end

	class Identifier_Expr < Expression
		attr_accessor :kind, :unpack, :scope_operator, :directive, :privacy, :binding
	end

	class Composition_Expr < Expression
		attr_accessor :operator, :identifier
	end

	class Conditional_Expr < Expression
		attr_accessor :condition, :when_true, :when_false
	end

	class Return_Expr < Prefix_Expr
		attr_accessor :expression
	end

	class Call_Expr < Expression
		attr_accessor :receiver, :arguments
	end

	class Subscript_Expr < Expression
		attr_accessor :receiver, :expression
	end

	class Array_Index_Expr < Expression
		attr_accessor :indices_in_order
	end

	class For_Loop_Expr < Expression
		attr_accessor :collection, :stride, :body
	end

	class Fence_Expr < Expression
	end

	class Comment_Expr < Expression
		attr_accessor :body
	end

	class Html_Fence_Expr < Expression
		# ```html
		# ```
		attr_accessor :body, :element
	end
end
