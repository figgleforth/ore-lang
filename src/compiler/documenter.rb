module Ore
	# A proof of concept to see what a documentation stage might look like
	class Documenter < Stage
		def output
			input.map do |expr|
				case expr
				when Ore::Comment_Expr, Ore::Fence_Expr, Ore::String_Expr
					expr.value
				else
					nil
				end
			end.compact
		end
	end
end
