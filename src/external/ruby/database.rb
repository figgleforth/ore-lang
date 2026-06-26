module Ore
	class Database < Instance
		require 'sequel'

		# @return [Sequel::SQLite::Database]
		def connection
			@connection ||= create_connection!
		end

		def create_connection!
			return @connection if @connection

			url = get 'url'
			raise Ore::Url_Not_Set_For_Database_Instance unless url

			# Note: As SQLite is a file-based database, the :host and :port options are ignored, and the :database option should be a path to the file — https://sequel.jeremyevans.net/rdoc/files/doc/opening_databases_rdoc.html#label-sqlite
			db = Sequel.sqlite adapter: 'sqlite', database: url

			@declarations['connection'] = @connection = db
		end

		def proxy_create_table name, columns_ore_dict
			return connection[name.to_sym] if proxy_table_exists? name

			connection.create_table name.to_sym do
				columns_ore_dict.dict.each do |col, type|
					col = col.to_sym

					case type
					when 'primary_key'
						primary_key col
					when 'String'
						String col
					when 'Text'
						String col, text: true # text:true changes this from VARCHAR(255) -> TEXT
					when 'Integer'
						Integer col
					when 'Float'
						Float col
					when 'Boolean'
						TrueClass col
					end
				end
			end
		end

		def proxy_delete_table name
			connection.drop_table name.to_sym
		end

		def proxy_table_exists? table_name
			connection.table_exists? table_name.to_sym
		end

		def proxy_tables
			Ore::Array.new connection.tables
		end
	end
end