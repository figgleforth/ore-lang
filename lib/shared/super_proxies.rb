module Super_Proxies
	def proxy_delegate object_name
		define_method "_proxy_delegate_" do |*args|
			send object_name
		end
	end

	def proxy method_name, as: method_name
		define_method "proxy_#{as}" do |*args|
			_proxy_delegate_.send method_name, *args
		end
	end
end
