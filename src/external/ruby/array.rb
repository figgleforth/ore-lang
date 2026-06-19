module Ore
	# note: Be sure to prefix with Ore:: whenever referencing this Array type to prevent ambiguity with Ruby's ::Array!
	class Array < Instance
		extend Ruby_Proxies
		attr_accessor :values

		def initialize values = []
			super 'Array'
			@values                 = values || []
			@declarations['values'] = self
		end

		proxy_delegate 'values'
		proxy :push
		proxy :pop
		proxy :shift
		proxy :unshift
		proxy :length
		proxy :length, as: :count
		proxy :first
		proxy :last
		proxy :slice
		proxy :reverse
		proxy :join
		proxy :sort
		proxy :uniq
		proxy :include?
		proxy :empty?

		def proxy_get index
			get index
		end

		def proxy_random
			values.sample
		end

		def proxy_concat other_array
			values.concat other_array.values
		end

		def proxy_flatten depth = -1
			ruby_array = values.map { |v| v.is_a?(Ore::Array) ? v.values : v }
			Ore::Array.new ruby_array.flatten depth
		end

		def get key
			# note: This is required because Instance extends Scope whose [] method reads from @declarations
			key.is_a?(Integer) ? values[key] : super
		end

		def == other
			# I think there's more to this than a simple evaluation. Tbd...
			values == other&.values
		end
	end

	class Tuple < Ore::Array
		def initialize values = []
			super values
		end

		def inspect
			"(#{values.map(&:inspect).join(', ')})"
		end
	end
end