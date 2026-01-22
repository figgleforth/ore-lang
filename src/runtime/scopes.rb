module Ore
	class Scope
		attr_accessor :enclosing_scope, :sibling_scopes, :declarations, :name

		def initialize name = nil
			@name           = name
			@declarations   = {}
			@sibling_scopes = []
		end

		def declare identifier, value
			self[identifier] = value
		end

		def get key
			key_str = key&.to_s

			# todo: Currently there is no clear rule on multiple unpacks. :double_unpack
			@sibling_scopes.reverse_each do |sibling|
				return sibling[key_str] if sibling.has? key_str
			end

			@declarations[key_str]
		end

		def [] key
			get key
		end

		def []= key, value
			@declarations[key.to_s] = value
		end

		def is compare
			@name == compare
		end

		def has? identifier
			id_str = identifier.to_s

			# todo: Currently there is no clear rule on multiple unpacks. :double_unpack
			return true if @sibling_scopes.any? do |sibling|
				sibling.has? id_str
			end

			@declarations.key? id_str
		end

		def delete key
			return nil unless key
			@declarations.delete(key.to_s)
		end

		def self.with_standard_library
			global = new
			global.load_standard_library
			global
		end

		def load_standard_library
			load_file STANDARD_LIBRARY_PATH
		end

		# Convenience method for loading files into this scope without a runtime
		# Creates a temporary Context to handle file loading
		def load_file filepath
			temp_runtime = Ore::Runtime.new
			temp_runtime.load_file_into_scope filepath, self
			self
		end

		def inspect
			filtered = instance_variables.reject { |v| v == :@enclosing_scope }
			vars     = filtered.map { |v| "#{v}=#{instance_variable_get(v).inspect}" }
			"#<#{self.class.name} #{vars.join(', ')}>"
		end

		def to_s
			"#<#{self.class.name} name=#{@name.inspect} declarations=#{@declarations.keys.inspect}>"
		end
	end

	class Global < Scope
	end

	class Type < Scope
		attr_accessor :expressions, :types, :routes, :static_declarations

		def initialize name = nil
			super name
			@types               = Set[name]
			@static_declarations = Set.new
			@expressions         = [] # note: Fancy subclasses of this like Ore::Array don't have @expressions therefore fail in places I assume @expressions is an array with some elements. Therefore giving it a default value here.
		end

		def has? identifier
			super(identifier) || @static_declarations.include?(identifier)
		end
	end

	class Instance < Type
		def initialize name = 'Instance'
			super name
		end
	end

	class Func < Scope
		attr_accessor :expressions, :static, :arguments
	end

	class Route < Func
		attr_accessor :http_method, :path, :handler, :parts, :param_names
	end

	class Return < Scope
		attr_accessor :value

		def initialize value
			super 'Return'
			@value = value
		end
	end

	class String < Instance
		require 'digest/md5'
		extend Super_Proxies

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
		proxy :strip, as: :trim
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

	# note: Be sure to prefix with Ore:: whenever referencing this Array type to prevent ambiguity with Ruby's ::Array!
	class Array < Instance
		extend Super_Proxies
		attr_accessor :values

		def initialize values = []
			super 'Array'
			@values                 = values
			@declarations['values'] = self
		end

		proxy_delegate 'values'
		proxy :push
		proxy :pop
		proxy :shift
		proxy :unshift
		proxy :length
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
			# Convert Ore::Array objects to Ruby arrays for flattening
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

	class Dictionary < Instance
		extend Super_Proxies
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
			dict[key] || declarations[key]
		end

		def []= key, value
			dict[key]         = value
			declarations[key] = value
		end

		def == other
			dict == other&.dict
		end

		def to_s
			dict.inspect
		end
	end

	class Tuple < Ore::Array
		def initialize values = []
			super values
		end
	end

	class Number < Instance
		extend Super_Proxies
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
	end

	class Nil < Scope # Like Ruby's NilClass, this represents the absence of a value.
		NIL = new()

		def self.shared
			NIL
		end

		private_class_method :new # prevent external instantiation

		def initialize
			super 'nil'
		end
	end

	class Bool < Instance
		TRUE  = new(true)
		FALSE = new(false)

		attr_accessor :truthiness

		def !
			!@truthiness
		end

		def self.truthy
			TRUE
		end

		def self.falsy
			FALSE
		end

		# private_class_method :new # prevent external instantiation

		def initialize truthiness = true
			super((!!truthiness).to_s.capitalize) # Scope class only needs @name
			@truthiness = !!truthiness
		end
	end

	class Range < ::Range
	end

	class Server < Instance
		attr_accessor :port, :routes

		def initialize
			super 'Server'

			@routes                 = {}
			@declarations['port']   = nil
			@declarations['routes'] = @routes
		end
	end

	class Request < Scope
		attr_accessor :path, :method, :query, :params, :headers, :body

		def initialize
			super 'Request'
			@path    = nil
			@method  = nil
			@query   = Ore::Dictionary.new
			@params  = Ore::Dictionary.new
			@headers = Ore::Dictionary.new
			@body    = nil

			@declarations['path']    = @path
			@declarations['method']  = @method
			@declarations['query']   = @query
			@declarations['params']  = @params
			@declarations['headers'] = @headers
			@declarations['body']    = @body
		end
	end

	class Response < Scope
		attr_accessor :status, :headers, :body_content, :webrick_response

		def initialize webrick_response
			super 'Response'
			@webrick_response = webrick_response
			@status           = 200
			@headers          = { 'Content-Type' => 'text/html; charset=utf-8' }
			@body_content     = ''

			@declarations['status']  = @status
			@declarations['headers'] = @headers
			@declarations['body']    = @body_content
		end

		def proxy_redirect to
			webrick_response.set_redirect WEBrick::HTTPStatus::SeeOther, to
		end
	end

	class Record < Instance
		extend Super_Proxies

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

		# @return [Sequal::SQLite::Dataset]
		def table
			raise Ore::Database_Not_Set_For_Record_Instance unless database

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

		def proxy_create ore_dict
			# todo: Return self, or a hash of the inserted row. By default, table#insert returns the id of the inserted row
			table.insert ore_dict.dict
		end

		def proxy_delete id
			table.where(id: id).delete
		end
	end

	class Database < Instance
		require 'sequel'

		# @return [Sequel::SQLite::Database]
		attr_accessor :connection

		# Calls Sequel.sqlite with the `url` declaration on this database, and returns the resulting database instance. Caches the database in @database.
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
					else
						raise "Metaprogram the rest of these"
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

	class Inout < Instance # I don't want to name it File because ::File
		# todo: Improve read and write, these are just naive implementations to make IO possible.
		def proxy_read_file_to_string filepath
			Ore::String.new File.read filepath
		end

		def proxy_write_string_to_file filepath, string
			File.write filepath, string
		end
	end
end
