module Ore
	class String < Instance
		require 'digest/md5'
		extend Ruby_Proxies

		attr_accessor :value

		def initialize value = ""
			super self.class.name
			@value        = value
			self['value'] = value
		end

		proxy_delegate 'value'
		proxy :length
		proxy :ord
		proxy :upcase
		proxy :downcase
		proxy :split
		proxy :slice!, as: :slice
		proxy :strip,  as: :trim
		proxy :lstrip, as: :trim_left
		proxy :rstrip, as: :trim_right
		proxy :chars
		proxy :index
		proxy :to_i
		proxy :to_f
		proxy :empty?
		proxy :include?
		proxy :reverse
		proxy :replace
		proxy :start_with?
		proxy :end_with?
		proxy :gsub

		def proxy_to_md5_hash
			Digest::MD5.hexdigest value
		end

		def + other
			value + other.value
		end

		def * other
			value * other
		end
	end

	class Fence < String
	end
end