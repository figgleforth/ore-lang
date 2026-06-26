module Ore
	class Number < Instance
		extend Ruby_Proxies
		attr_accessor :numerator, :denominator, :type

		def + other
			numerator + other.numerator
		end

		def - other
			numerator - other.numerator
		end

		def * other
			numerator * other.numerator
		end

		def ** other
			numerator ** other.numerator
		end

		def / other
			numerator / other.numerator
		end

		def % other
			numerator % other.numerator
		end

		def >> other
			numerator >> other.numerator
		end

		def << other
			numerator << other.numerator
		end

		def ^ other
			numerator ^ other.numerator
		end

		def & other
			numerator & other.numerator
		end

		def | other
			numerator | other.numerator
		end

		proxy_delegate 'numerator'
		proxy :to_s
		proxy :abs
		proxy :floor
		proxy :ceil
		proxy :round
		proxy :even?
		proxy :odd?
		proxy :to_i
		proxy :to_f
		proxy :clamp

		def proxy_sqrt
			Math.sqrt numerator
		end

		def proxy_rand max
			max_val = max.respond_to?(:numerator) ? max.numerator : max.to_i
			::Kernel.rand(max_val + 1)
		end
	end
end