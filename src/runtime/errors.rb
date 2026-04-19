require_relative 'error_formatter'

module Ore
	class Error < StandardError
		attr_accessor :expression, :runtime

		def initialize expression = nil, runtime = nil
			@expression = expression
			@runtime    = runtime
			super format_error
		end

		def format_error
			Error_Formatter.new(self, runtime).format
		end
	end

	class Undeclared_Identifier < Error
	end

	class Cannot_Reassign_Constant < Error
	end

	class Cannot_Assign_Incompatible_Type < Error
	end

	class Cannot_Initialize_Non_Type_Identifier < Error
	end

	class Invalid_Dictionary_Key < Error
	end

	class Invalid_Dictionary_Infix_Operator < Error
	end

	class Invalid_Dot_Infix_Left_Operand < Error
	end

	class Invalid_Dot_Infix_Right_Operand < Error
	end

	class Invalid_Unpack_Infix_Operator < Error
	end

	class Invalid_Unpack_Infix_Right_Operand < Error
	end

	class Unhandled_Prefix < Error
	end

	class Unhandled_Postfix < Error
	end

	class Missing_Argument < Error
	end

	class Assert_Triggered < Error
	end

	class Invalid_Http_Directive_Handler < Error
	end

	class Invalid_Start_Directive_Argument < Error
	end

	class Interpret_Expr_Not_Implemented < Error
	end

	class Out_Of_Tokens < Error
	end

	class Invalid_Scope_Syntax < Error
	end

	class Cannot_Use_Instance_Scope_Operator_Outside_Instance < Error
	end

	class Cannot_Use_Type_Scope_Operator_Outside_Type < Error
	end

	class Too_Many_Subscript_Expressions < Error
	end

	class Invalid_Subscript_Receiver < Error
	end

	class Cannot_Call_Private_Instance_Member < Error
	end

	class Cannot_Call_Instance_Member_On_Type < Error
	end

	class Cannot_Call_Private_Static_Member_On_Type < Error
	end

	class Invalid_Directive_Usage < Error
		# todo: This is not printing anything to stdouts
	end

	class Missing_Super_Proxy_Declaration < Error
	end

	class Invalid_Super_Proxy_Directive_Usage < Error
		# @super directive only supports function and variable declarations in the body of a Type declaration
	end

	class Invalid_Static_Directive_Declaration < Error
		# @static directive only supports function and variable declarations in the body of a Type declaration
	end

	class Unterminated_String_Literal < Error
	end

	class Lexed_Unexpected_Char < Error
	end

	class Lex_Char_Not_Implemented < Error
	end

	class Url_Not_Set_For_Database_Instance < Error
	end

	class Database_Not_Set_For_Record_Instance < Error
	end

	class Type_Checking_Failed < Error
		attr_accessor :errors

		def inintialize errors
			super
			@errors = errors
		end
	end

	class Type_Mismatch < Type_Checking_Failed
		attr_accessor :declared, :inferred

		def initialize expression, declared, inferred
			@declared = declared
			@inferred = inferred
			super expression, nil
		end
	end

	class Reserved_Function_Delimiter < Error
	end

	class Type_Contract_Violation < Error
		attr_accessor :contract, :actual

		def initialize expression, contract, actual, interpreter
			@contract = contract
			@actual   = actual
			super expression, interpreter
		end

		def message
			"Type contract violation: expected #{@contract}, got #{@actual || 'unknown'}"
		end
	end

	class Operator_Overload_Fixity_Must_Be_One_Of < Error
	end

	class Operator_Overload_Precedence_Must_Be_Integer < Error
	end
end
