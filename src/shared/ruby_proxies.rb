module Ruby_Proxies
	def self.extended base
		base.instance_variable_set :@proxy_methods, []
	end

	def proxy_methods
		@proxy_methods ||= []
	end

	def proxy_delegate object_name
		define_method "_proxy_delegate_" do |*args|
			send object_name
		end
	end

	def proxy method_name, as: method_name
		@proxy_methods ||= []
		@proxy_methods << { ore_name: as, ruby_method: method_name }
		define_method "proxy_#{as}" do |*args|
			_proxy_delegate_.send method_name, *args
		end
	end
end