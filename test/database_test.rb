require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'
require 'net/http'
require 'uri'
require 'sequel'
require 'securerandom'

class Database_Test < Base_Test
	DATABASE = "@use 'ore/database.ore'"
	RECORD   = "@use 'ore/record.ore'"

	def before_setup
		@filepath = "./temp#{SecureRandom.hex}.db"
		File.delete(@filepath) if File.exist? @filepath
	end

	def after_teardown
		File.delete(@filepath) if File.exist? @filepath
	end

	def test_database_instance
		out = Ore.interp <<~ORE
		    #{DATABASE}
			db = Database()
		    sq = Sqlite('#{@filepath}')
			(db, sq)
		ORE
		assert_instance_of Ore::Database, out.values.first
		assert_instance_of Ore::Database, out.values.last

		assert_nil out.values.first.get 'adapter'
		assert_nil out.values.first.get 'url'
		assert_nil out.values.first.get 'connection'
		assert_nil out.values.last.get 'connection'

		# These are set in Sqlite.new{;}
		refute_nil out.values.last.get 'adapter'
		refute_nil out.values.last.get 'url'
	end

	def test_database_connection_instance
		out = Ore.interp <<~ORE
		    #{DATABASE}
		    db = Sqlite('#{@filepath}')
		    @connect db
			db.connection
		ORE
		refute_nil out
		assert_instance_of Sequel::SQLite::Database, out
	end

	def test_database_connection_is_cached
		out = Ore.interp <<~ORE
		    #{DATABASE}
		    db = Sqlite('#{@filepath}')
		    c1 = @connect db
		    c2 = @connect db
		    (c1, c2)
		ORE
		assert_equal out.values[0].object_id, out.values[1].object_id
	end

	def test_inferring_record_table_name
		out = Ore.interp <<~ORE
		    #{RECORD}
			r = Record()
			r.table_name

			Thing | Record {}
			t = Thing()
			t.infer_table_name_from_class!()
			(r, t)
		ORE
		assert_nil out.values.first.get 'table_name'
		assert_equal 'things', out.values.last.get('table_name')
	end

	def test_connect_directive_creates_database_connection
		out = Ore.interp <<~ORE
		    #{DATABASE}
		    db = Sqlite('#{@filepath}')
			db.connection
		ORE
		assert_nil out

		out = Ore.interp <<~ORE
		    #{DATABASE}
		    db = Sqlite('#{@filepath}')
			@connect db
			db.connection
		ORE
		assert_instance_of Sequel::SQLite::Database, out
	end

	def test_creating_table
		out = Ore.interp <<~ORE
		    #{DATABASE}
		    db = Sqlite('#{@filepath}')
			@connect db

			pre_tables = db.tables()
			db.create_table('users' { id: 'primary_key' })
			post_tables = db.tables()

			(pre_tables, post_tables)
		ORE
		assert_equal [[], [:users]], out.values.map { |ore_array| ore_array.get('values').values }
	end

	def test_record_database_reference
		out = Ore.interp <<~ORE
		    #{DATABASE}, #{RECORD}
		    db = @connect Sqlite('#{@filepath}')

			db.create_table('users' { id: 'primary_key', name: 'String' })

			User | Record {
				./database = db
				table_name = 'users'
			}

			none = User.all()
			cooper_id = User.create({name: 'Cooper'})
			cooper = User.find(cooper_id)

			luna_id = User.create({name: 'Luna'})
			luna = User.find(luna_id)

			users = User.all()
			(none, users, cooper, luna, db.table_exists?('users'))
		ORE
		assert_equal 0, out.values[0].values.count
		assert_equal 2, out.values[1].values.count
		assert_equal [{ id: 1, name: 'Cooper' }, { id: 2, name: 'Luna' }], out.values[1].values.map(&:dict)
		assert_equal({ id: 1, name: 'Cooper' }, out.values[2].dict)
		assert_equal({ id: 2, name: 'Luna' }, out.values[3].dict)
		assert out.values.last
	end
end
