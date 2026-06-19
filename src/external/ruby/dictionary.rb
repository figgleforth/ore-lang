module Ore
	class Dictionary < Instance
		extend Ruby_Proxies
		attr_accessor :dict

		def initialize dict = nil
			super 'Dictionary'
			@dict         = dict || {}
			@declarations = {}
		end

		proxy_delegate 'dict'
		proxy :has_key?
		proxy :delete
		proxy :count
		proxy :keys
		proxy :values
		proxy :empty?
		proxy :clear
		proxy :fetch

		def proxy_merge other_dict
			dict.merge other_dict.dict
		end

		def [] key
			dict[key.to_sym] || declarations[key.to_sym]
		end

		def []= key, value
			dict[key.to_sym]         = value
			declarations[key.to_sym] = value
		end

		def == other
			dict == other&.dict
		end

		def to_s
			dict.inspect
		end
	end
end