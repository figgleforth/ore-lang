module Ore
	class Table < Instance
		extend Ruby_Proxies

		def proxy_infer_table_name_from_class!
			require 'sequel/extensions/inflector.rb'
			first_type                  = types.to_a.first
			@declarations['table_name'] = first_type.split('::').last.downcase.pluralize
		end

		# @return [Ore::Database]
		def database
			@declarations['database']
		end

		# @return [Symbol]
		def table_name
			@declarations['table_name']&.to_sym
		end

		# @return [Sequel::SQLite::Dataset]
		def table
			raise Ore::Database_Not_Set_For_Table_Instance unless database

			database['connection'][table_name]
		end

		def proxy_all
			records      = table&.all || []
			dictionaries = records.map { |hash| Ore::Dictionary.new hash }
			Ore::Array.new dictionaries
		end

		def proxy_find id
			# todo: Convert this to a Record instance
			record = table.where(id: id).first
			record ? Ore::Dictionary.new(record) : nil
		end

		def proxy_find_by ore_dict
			record = table.where(ore_dict.dict).first
			record ? Ore::Dictionary.new(record) : nil
		end

		def proxy_where ore_dict
			records      = table.where(ore_dict.dict).all
			dictionaries = records.map { |hash| Ore::Dictionary.new hash }
			Ore::Array.new dictionaries
		end

		def proxy_create ore_dict
			# todo: Return self, or a hash of the inserted row. By default, table#insert returns the id of the inserted row
			table.insert ore_dict.dict
		end

		def proxy_update id, ore_dict
			table.where(id: id).update ore_dict.dict
		end

		def proxy_delete id
			table.where(id: id).delete
		end
	end
end