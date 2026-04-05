module Ore
	# Data container representing return statements and their value.
	# Example:
	#     `return 1234` code interprets to `Return.new(1234)`
	Return = Data.define :value
end
