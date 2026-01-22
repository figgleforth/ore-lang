module Helpers
	extend self

	def assert condition, message = "Expected condition to be truthy."
		raise "---\n#{message}\n---" unless condition
	end

	def constant_identifier? ident
		# ALL UPPER LIKE_THIS
		test = ident&.gsub('_', '')&.gsub('%', '')
		test&.chars&.all? { |c| c.upcase == c }
	end

	def type_identifier? ident
		return false unless ident
		# Capitalized Like_This or This
		ident[0] && ident[0].upcase == ident[0] && !constant_identifier?(ident)
	end

	def member_identifier? ident
		return false unless ident
		# lowercased_FIRST_LETTER, lIKE_THIS or thIS or this
		ident[0] && ident[0].downcase == ident[0]
	end

	def type_of_identifier ident
		ident = ident&.to_s
		return :operator if %w(and or not unless return).include? ident

		without_leading__ = ident&.gsub(/^_+/, '')

		if constant_identifier? without_leading__
			:IDENTIFIER
		elsif type_identifier? without_leading__
			:Identifier
		elsif member_identifier? without_leading__
			:identifier
		else
			raise "unknown identifier type #{ident.inspect}"
		end
	end

	def type_of_number_expr expr
		if expr.to_s.count('.') > 1
			:array_index
		elsif expr.to_s.include? '.'
			:float
		else
			:integer
		end
	end

	def privacy_of_ident ident
		ident               = ident&.to_s
		leading_underscores = ident.match(/^_*/)[0].length

		case leading_underscores
		when 0
			:public
		else
			:private
		end
	end

	def binding_of_ident scope, ident
		ident = ident&.to_s
		return :static if %i(IDENTIFIER Identifier).include? type_of_identifier ident

		return nil unless scope.has? ident

		if scope.is_a?(Ore::Type) && scope.static_declarations&.include?(ident)
			:static
		else
			:instance
		end
	end
end
