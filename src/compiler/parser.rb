module Ore
	class Parser < Stage
		attr_accessor :i

		def initialize input = []
			super input
			@i = 0 # index of current lexeme
		end

		def copy_location expr, from_lexeme_or_expr
			return expr unless from_lexeme_or_expr

			expr.l0 = from_lexeme_or_expr.l0
			expr.c0 = from_lexeme_or_expr.c0
			expr.l1 = from_lexeme_or_expr.l1
			expr.c1 = from_lexeme_or_expr.c1

			expr
		end

		def output
			expressions = []
			while lexemes?
				expressions << parse_expression
			end
			expressions.compact
		end

		# Array of precedences and symbols for that precedence. if the lexeme provided matches one of the operator symbols then its precedence is returned. Nice reference: https://rosettacode.org/wiki/Operator_precedence
		def precedence_for operator
			PRECEDENCES[operator] || STARTING_PRECEDENCE
		end

		# input[i - 1]
		def prev_lexeme
			input[[i - 1, 0].max]
		end

		# input[i]
		def curr_lexeme
			input[i]
		end

		# input[i..]
		def remainder
			input[i..]
		end

		def lexemes?
			i < input.length
		end

		def reduce lexeme = %W(\n \r)
			eat while lexemes? && curr?(lexeme)
		end

		def reduce_newlines
			eat while lexemes? && curr?(:delimiter) && %W(\n \r).include?(curr_lexeme.value)
		end

		def curr? * sequence
			return false unless remainder && lexemes?
			return false if sequence.count > remainder.count

			slice = remainder.slice(0, sequence.count)
			slice.each_with_index.all? do |lexeme, index|
				expected = sequence[index]

				if expected.is_a?(Ore::Array)
					expected.any? do |alt|
						lexeme.is(alt)
					end
				else
					lexeme.is(expected)
				end
			end
		end

		def peek ahead = 1
			raise 'Parser.input is nil' unless input

			index = ahead.clamp(0, input.count)
			input[i + index]
		end

		def peek_until lexeme = nil
			return remainder unless lexeme

			remainder.slice_before do |t|
				if lexeme.is_a? Ore::Lexeme
					t.is lexeme
				else
					t.value == lexeme
				end
			end.to_a.first
		end

		def peek_contains? contains, stop_at_lexeme = nil
			peek_until(stop_at_lexeme).any? do |t|
				t.is contains
			end
		end

		# idea: support sequence of elements where an element can be one of many, like the sequence [IdentifierToken, [:=, =]]
		def eat * sequence
			raise "tried to eat #{sequence} but out of lexemes" unless lexemes?

			if sequence.nil? || sequence.empty? || sequence.one?
				eaten = curr_lexeme
				if sequence&.one? && !eaten.is(sequence[0])
					raise "Parser#eat ate #{eaten.value.inspect} but expected #{sequence[0].inspect}"
				end
				@i    += 1
				return eaten
			end
		end

		# Currently `stride` doesn't support option to overlap elements
		#
		#   for <collection> [map/select/reject] [by <stride>]
		#   end
		#
		#   for items map by 2
		#       it #[items.0, items.1], [items.2, items.3], ...
		#   end
		#
		def parse_for_loop_expr
			it            = Ore::For_Loop_Expr.new
			it.lexeme     = eat 'for'
			it.collection = parse_expression

			if curr? Ore::FOR_VERBS and verb = eat
				it.type   = verb
				it.lexeme = verb
			end

			if curr? 'by' and eat 'by'
				it.stride = begin_expression
				# todo: Should I check that it's a number here?
			end

			reduce_newlines

			it.body = []
			until curr? 'end'
				it.body << parse_expression
				reduce_newlines
			end
			it.body = it.body.compact

			eat 'end'
			it
		end

		def parse_conditional_expr
			it            = Ore::Conditional_Expr.new
			it.type       = eat # One of %w(if while unless until)
			it.condition  = parse_expression
			it.when_true  = []
			it.when_false = []
			reduce_newlines

			# @clean

			until curr? %w(end else elif elwhile)
				expr = parse_expression
				it.when_true << expr if expr
				reduce_newlines
			end

			if curr? %w(elif elwhile)
				it.when_false = parse_conditional_expr

			elsif curr? %w(else) and eat
				until curr? 'end'
					expr = parse_expression
					it.when_false << expr if expr
					reduce_newlines
				end
				eat 'end'

			elsif curr? %w(} end)
				eat

			else
				# todo: errors.rb
				raise "\n\nYou messed your if/elif/else up\n"
			end
			it
		end

		def parse_circumfix_expr opening: '('
			start = curr_lexeme
			it    = Ore::Circumfix_Expr.new
			it.grouping = CIRCUMFIX_GROUPINGS[opening] or raise "parse_circumfix_expr unknown opening #{opening}"
			eat opening
			reduce_newlines
			closing = it.grouping[1]

			it.expressions = []
			until curr? closing
				it.expressions << parse_expression
				break if curr? closing

				eat if curr? ','
				reduce_newlines
			end

			eat closing
			it.expressions = it.expressions.compact
			it
			copy_location it, start
		end

		def parse_func precedence = STARTING_PRECEDENCE, named: false
			start            = curr_lexeme
			func             = Ore::Func_Expr.new
			func.expressions = []

			if curr?(:identifier) || curr?(SCOPE_OPERATORS)
				func.name = parse_identifier_expr

				if curr? ':' and eat ':'
					func.type = eat(:Identifier)
				end
			end

			func.lexeme = func.name
			eat '{'
			reduce_newlines

			until curr? Ore::FUNCTION_DELIMITER
				param        = Ore::Param_Expr.new

				if curr? Ore::RUNTIME_SCOPE_OPERATOR and eat Ore::RUNTIME_SCOPE_OPERATOR
					param.unpack = true
				end

				if curr? :identifier, :identifier
					param.label = eat(:identifier)
					param.name  = eat(:identifier)
				else
					param.name = eat(:identifier)
				end
				param.lexeme = param.name

				if curr? ':' and eat ':'
					param.type = eat(:Identifier)
				end

				if curr? '=' and eat '='
					param.default = parse_expression
				end

				func.expressions << param
				eat if curr? ','
				reduce_newlines
			end

			eat Ore::FUNCTION_DELIMITER if curr? Ore::FUNCTION_DELIMITER
			reduce_newlines

			until curr? '}'
				func.expressions << parse_expression
				reduce_newlines
			end

			# func.expressions = func.expressions #.compact #.uniq # bug, The first Param is twice in the array, with the same object_id. Dedupe it for now. Figure out the real issue later.
			eat '}'

			func
			copy_location func, start
		end

		def parse_type_decl
			# bug, When parsing `Identifier {->}`. :Identifier_function
			# todo, The | TYPE_COMPOSITION_OPERATOR is currently only working in #parse_type_decl. I can peek until end of line, if I see another | then it's a circumfix. However if there are more |s then maybe we can presume the expression type like this:
			#
			#   1 | = composition
			#   2 | = circumfix
			#   3+ odd probably  = composition
			#   3+ even probably = circumfix
			#
			#   :absolute_value_circumfix
			#

			start          = curr_lexeme
			valid_idents   = %I(Identifier IDENTIFIER)
			it             = Ore::Type_Expr.new
			it.name        = eat
			it.expressions = []

			until curr? '{'
				if curr?(TYPE_COMPOSITION_OPERATORS, ANY_IDENTIFIER)
					it.expressions << parse_composition_expr
				end
			end

			eat '{'
			reduce_newlines

			until curr?(:delimiter) && curr?('}') # note: Added explicit check for delimiter because there was a bug where a comment whose value is simply "}" was evaluating to true in this condition, leaving the parser with an unhandled } todo: Maybe #curr? should always return false if it detects a comment?
				it.expressions << parse_expression
				reduce_newlines
			end

			it.expressions = it.expressions.compact

			eat '}' and Ore.assert !curr?('}')

			it
			copy_location it, start
		end

		def parse_comment
			lexeme   = eat
			it       = Ore::Comment_Expr.new lexeme.value
			it.value = Ore::String_Expr.new lexeme.value
			it.body  = Ore::String_Expr.new lexeme
			it.type  = lexeme.type
			it
		end

		def parse_fence_expr
			lexeme   = eat
			it       = Ore::Fence_Expr.new lexeme.value
			it.value = Ore::String_Expr.new lexeme.value
			it.type  = lexeme.type # :fence by default
			it
		end

		def parse_html_expr
			# TODO: :html_vs_type_expr
			start      = curr_lexeme
			it         = Ore::Html_Fence_Expr.new eat
			it.body    = Ore::String_Expr.new start
			it.value   = it.body
			it.element = it.lexeme
			copy_location it, start
		end

		def parse_composition_expr
			start           = curr_lexeme
			expr            = Ore::Composition_Expr.new
			expr.operator   = eat(:operator)
			expr.identifier = parse_identifier_expr
			expr
			copy_location expr, start
		end

		def parse_identifier_expr
			start = curr_lexeme

			expr = Ore::Identifier_Expr.new

			if curr? RUNTIME_SCOPE_OPERATOR and eat RUNTIME_SCOPE_OPERATOR
				expr.directive = true
			elsif curr? SCOPE_OPERATORS
				expr.scope_operator = parse_scope_operator
			end

			expr.lexeme  = eat
			expr.privacy = Ore.privacy_of_ident expr.value

			# 7/20/25, I'm storing the type as well, even though I haven't written any code to support types yet.

			if curr?(':', :Identifier)
				eat ':'
				expr.type = eat(:Identifier)
			end

			expr.kind = Ore.type_of_identifier expr.value
			copy_location expr, start
		end

		def parse_scope_operator
			scope = eat

			if curr? SCOPE_OPERATORS
				# There should not be any more scope operators at this point. We've implicitly handled . and ..
				raise Ore::Invalid_Scope_Syntax.new curr_lexeme
			end

			scope
		end

		def parse_symbol_expr
			start = curr_lexeme
			eat ':'
			it       = Ore::Symbol_Expr.new eat
			it.value = it.value.to_sym
			copy_location it, start
		end

		def parse_route_expr
			start       = curr_lexeme
			route_token = eat :route

			# Split "get://users/:id" => ["get", "users/:id"]
			parts       = route_token.value.split HTTP_VERB_SEPARATOR
			http_method = parts[0]
			path_string = parts[1] || ''

			# Extract parameter names from dynamic path segments. ":id/:action" => ["id", "action"]
			path_segments = path_string.split '/'
			param_names   = path_segments
			                .select { |segment| segment.start_with?(':') }
			                .map { |segment| segment[1..-1] } # Remove ':' prefix

			# Parse handler function (must follow route declaration).
			# todo: Consider being able to use an existing identifier in place of a function expression
			reduce_newlines
			expr = parse_expression

			# Validate: handler params must include all route params
			handler_params = if expr.is_a? Ore::Func_Expr
				expr.expressions
				.select { |expr| expr.is_a?(Ore::Param_Expr) }
				.map(&:name)
				.map(&:value)
			else
				[]
			end

			missing_params = param_names - handler_params
			unless missing_params.empty?
				# todo: Add this error to src/runtime/errors.rb
				warn "Route parameters #{missing_params.inspect} not found in handler parameters. Handler #{expr} params: #{handler_params}"
			end

			route             = Ore::Route_Expr.new
			route.http_method = Ore::Identifier_Expr.new.tap do |expr|
				expr.value = http_method
				expr.kind  = :identifier
			end
			route.path        = path_string
			route.expression  = expr
			route.param_names = param_names

			route
			copy_location route, start
		end

		def parse_operator_expr
			start = curr_lexeme
			# A method just for this might seem silly, but I thought the same when I decided #make_expr should be a giant method. This will help in the long run, and consistency is key to keeping this maintainable.

			operator_lexeme = eat(:operator)

			# Scope operators can't be followed by literals like numbers or strings
			if SCOPE_OPERATORS.include? operator_lexeme.value
				if curr? :number
					raise Ore::Invalid_Scope_Syntax.new
				elsif curr? :string
					raise Ore::Invalid_Scope_Syntax.new
				end
			end

			it = Ore::Operator_Expr.new operator_lexeme
			copy_location it, start
		end

		def parse_number_expr
			start       = curr_lexeme
			expr        = Ore::Number_Expr.new
			expr.lexeme = eat(:number)
			if expr.value.count('.') > 1
				expr                  = Ore::Array_Index_Expr.new expr
				expr.indices_in_order = expr.lexeme.value.split '.'
				expr.indices_in_order = expr.indices_in_order.map &:to_i
				# It's important not to convert number.value here to anything to preserve the variant number of dots in the string. I think this'll be cool syntax, 2d_array.1.2 would be the equivalent of 2d_array[1][2].
			elsif expr.value.include? '.'
				expr.type  = :float
				expr.value = expr.value.to_f
			else
				expr.type  = :integer
				expr.value = expr.value.to_i
			end
			expr
			copy_location expr, start
		end

		def parse_nil_init_expr
			start = curr_lexeme

			expr          = Ore::Nil_Init_Expr.new
			expr.lexeme   = start
			expr.left     = parse_identifier_expr
			expr.operator = Lexeme.new(:operator, '=')

			nil_expr         = Ore::Identifier_Expr.new
			nil_expr.value   = 'nil'
			nil_expr.kind    = :identifier
			nil_expr.privacy = Ore.privacy_of_ident 'nil'
			expr.right       = nil_expr

			copy_location expr, start
		end

		def begin_expression precedence = STARTING_PRECEDENCE
			raise Ore::Out_Of_Tokens.new unless lexemes?

			if curr? :route
				parse_route_expr

			elsif curr?(ANY_IDENTIFIER, Ore::NIL_INIT_POSTFIX) || curr?(SCOPE_OPERATORS, ANY_IDENTIFIER, Ore::NIL_INIT_POSTFIX)
				parse_nil_init_expr

			elsif (curr?('{') || curr?(:identifier, '{') || curr?(:identifier, ':', :Identifier, '{') || curr?(SCOPE_OPERATORS, :identifier, '{')) && peek_contains?(Ore::FUNCTION_DELIMITER, '}')
				parse_func precedence, named: curr?(:identifier)

			elsif curr?(:Identifier, '{') || curr?(:Identifier, TYPE_COMPOSITION_OPERATORS) || curr?(:IDENTIFIER, TYPE_COMPOSITION_OPERATORS) || curr?(:IDENTIFIER, '{')
				parse_type_decl

			elsif curr?(TYPE_COMPOSITION_OPERATORS) && peek.is(:Identifier)
				parse_composition_expr

			elsif curr? 'for'
				parse_for_loop_expr

			elsif curr? %w(if while unless until)
				parse_conditional_expr

			elsif curr?(:identifier, ':', :Identifier) || curr?(ANY_IDENTIFIER) || curr?(Ore::RUNTIME_SCOPE_OPERATOR, :identifier) || curr?(SCOPE_OPERATORS, ANY_IDENTIFIER) || curr?(RUNTIME_SCOPE_OPERATOR, :identifier)
				parse_identifier_expr

			elsif curr?(%w( [ \( { |)) && curr?(:delimiter)
				# :absolute_value_circumfix
				parse_circumfix_expr opening: curr_lexeme.value

			elsif curr?(':', :identifier) || curr?(':', :Identifier) || curr?(':', :IDENTIFIER)
				parse_symbol_expr

			elsif curr? :operator
				parse_operator_expr

			elsif curr? :number
				parse_number_expr

			elsif curr? :string
				start = curr_lexeme
				expr  = Ore::String_Expr.new eat(:string)
				copy_location expr, start

				# elsif curr? SCOPE_OPERATORS
				# 	parse_operator_expr

			elsif curr? [',', '->']
				# todo: Don't just discard the comma, make tuples implied when commas are found in #complete_expression
				eat and nil

			elsif curr? ';'
				# This is reserved for function declarations
				raise "; is reserverd as function header and body delimiter"

			elsif curr? :delimiter
				reduce_newlines and nil

			elsif curr? :html # This is a subtype of Ore::Fence_Expr
				parse_html_expr

			elsif curr? :fence
				parse_fence_expr

			elsif curr? :comment
				parse_comment

			else
				raise "Unhandled lexeme: #{curr_lexeme.inspect}"
			end
		end

		def parse_expression precedence = STARTING_PRECEDENCE
			# 7/20/25, Unforunately, some other code depends on this being coupled with #complete_expression. That's okay for now, but lesson learned.
			#
			# 7/26/25, It's decoupled now but still kind of ugly. This is fine though, because it will allow me to handle any partial expressions. An example of a partial expression would be the code prior to an inline conditional:
			#
			#   /————\           <~ partial expression
			#   <code> if true
			#   \————————————/   <~ complete expression
			#

			expression = begin_expression precedence
			complete_expression expression, precedence
		end

		# todo: Factor out the various branches of code in here?
		def complete_expression expr, precedence = STARTING_PRECEDENCE
			return expr unless expr && lexemes?

			if expr.is_a?(Ore::Identifier_Expr) && expr.directive && expr.value != 'super'
				# note: I'm intentionally skipping `super` here because a Directive_Expr assumes an expression will follow it. But in the case of @super, I want it to be a standalone expression. Maybe this warrants rewriting how directives work? Or maybe this can just stay as an implementation detail. For now it's fine.
				directive            = Ore::Directive_Expr.new
				directive.name       = expr
				directive.expression = parse_expression

				copy_location directive, expr
				return complete_expression directive, precedence
			end

			scope_prefix = SCOPE_OPERATORS.find do |it|
				expr.is it
			end

			if scope_prefix
				next_expr = begin_expression precedence
				if next_expr.is_a? Ore::Infix_Expr
					expr            = Ore::Prefix_Expr.new
					expr.operator   = scope_prefix
					expr.expression = next_expr
				end
				return complete_expression next_expr, precedence
			end

			prefix    = PREFIX.include?(expr.value)
			infix     = INFIX.include?(curr_lexeme.value)
			postfix   = POSTFIX.include?(curr_lexeme.value)
			circumfix = CIRCUMFIX.include?(curr_lexeme.value)

			if prefix
				expr = Ore::Prefix_Expr.new.tap do |it|
					it.operator   = expr
					it.expression = parse_expression precedence_for(it.operator.value)
				end

				unless expr.expression
					raise "Ore::Prefix_Expr expected an expression after `#{expr.operator.value}`"
				end

				return complete_expression expr, precedence
			elsif infix
				if COMPOUND_OPERATORS.include? curr_lexeme.value
					### note: I seem to have forgotten this important check for precedence here. I'm sure there are other places todo
					curr_operator_prec = precedence_for curr_lexeme.value
					return expr if curr_operator_prec <= precedence
					###

					it          = Ore::Infix_Expr.new
					it.left     = expr
					it.operator = eat
					it.right    = parse_expression precedence_for it.operator.value

					copy_location it, expr
					return complete_expression it, precedence
				elsif RANGE_OPERATORS.include? curr_lexeme.value
					it          = Ore::Infix_Expr.new
					it.left     = expr
					it.operator = eat
					it.right    = parse_expression

					copy_location it, expr
					return complete_expression it, precedence
				else
					while INFIX.include?(curr_lexeme.value) && curr?(:operator)
						# It's very important that the curr?(:operator) check here remains because otherwise it breaks Ore::Call_Expr when the receiver is an Ore::Infix_Expr.
						curr_operator      = curr_lexeme.value
						curr_operator_prec = precedence_for curr_operator

						if curr_operator_prec <= precedence
							return expr
						end

						left          = expr
						expr          = Ore::Infix_Expr.new
						expr.left     = left
						expr.operator = eat(curr_lexeme.value)
						expr.right    = parse_expression curr_operator_prec
						copy_location expr, left

						if expr.left.is(Ore::Identifier_Expr) && expr.operator.value == '.' && expr.right.is(Ore::Number_Expr) && expr.right.type == :float
							# @copypaste from above #parse_expression when :number.
							number                  = Ore::Array_Index_Expr.new expr.right
							number.indices_in_order = expr.right.value.to_s.split '.'
							number.indices_in_order = number.indices_in_order.map &:to_i
							expr.right              = number
						end

						return complete_expression expr, precedence
					end
				end

			elsif postfix
				expr = Ore::Postfix_Expr.new.tap do |it|
					it.expression = expr
					it.operator   = eat(:operator)
				end
			end

			call_expr = curr?('(') && curr?(:delimiter)
			subscript = curr? '['
			if call_expr && (precedence_for(curr_lexeme.value) > precedence)
				receiver       = expr
				fix            = parse_circumfix_expr opening: curr_lexeme.value
				expr           = Ore::Call_Expr.new
				expr.receiver  = receiver
				expr.arguments = fix.expressions

				copy_location expr, receiver
				return complete_expression expr, precedence
			elsif subscript
				it            = Ore::Subscript_Expr.new
				it.receiver   = expr
				it.expression = parse_circumfix_expr opening: curr_lexeme.value
				it

				copy_location expr, left
				return complete_expression it, precedence
			end

			if curr?(%w(if while unless until))
				if precedence_for(curr_lexeme.value) <= precedence
					return expr
				end

				it            = Ore::Conditional_Expr.new
				it.when_true  = []
				it.when_false = []
				it.type       = eat # One of %w(if while unless until)
				it_prec       = precedence_for it.type.value
				it.condition  = parse_expression
				if %w(unless until).include? it.type.value
					it.when_false = [expr]
				else
					it.when_true = [expr]
				end
				return complete_expression it, precedence
			end

			expr
		end

	end
end
