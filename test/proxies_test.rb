require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class ProxiesTest < Base_Test
	def test_invalid_proxy_directive_usage
		assert_raises Ore::Invalid_Super_Proxy_Directive_Usage do
			Ore.interp '@super'
		end
	end

	def test_string_proxies
		assert_equal 12, Ore.interp("'hello, world'.length")
		assert_equal 104, Ore.interp("'hello, world'.ord")

		assert_equal "HELLO", Ore.interp("'hello'.upcase()")
		assert_equal "world", Ore.interp("'WORLD'.downcase()")

		assert_equal ['he', '', 'o'], Ore.interp("'hello'.split('l')")
		assert_equal "ORL", Ore.interp("'WORLD'.slice('ORL')")

		assert_equal "Locke!", Ore.interp("'   Locke!    '.trim()")
		assert_equal "Locke!    ", Ore.interp("'   Locke!    '.trim_left()")
		assert_equal "   Locke!", Ore.interp("'   Locke!    '.trim_right()")

		assert_equal %w(w a l t), Ore.interp("'walt'.chars()")
		assert_equal 6, Ore.interp("'Enter the numbers'.index('the')")

		assert_equal 123, Ore.interp("'123'.to_i()")
		assert_equal 456.0, Ore.interp("'456'.to_f()")

		assert Ore.interp("''.empty?()")
		refute Ore.interp("'cool'.empty?()")

		assert Ore.interp("'island'.include?('and')")
		refute Ore.interp("'island'.include?('or')")

		assert_equal 'edcba', Ore.interp("'abcde'.reverse()")
		assert_equal 'replaced', Ore.interp("'replace_me'.replace('replaced')")

		assert Ore.interp("'hello world'.start_with?('hello')")
		refute Ore.interp("'hello world'.start_with?('world')")

		assert Ore.interp("'hello world'.end_with?('world')")
		refute Ore.interp("'hello world'.end_with?('hello')")

		assert_equal 'hellu wurld', Ore.interp("'hello world'.gsub('o', 'u')")
		assert_equal 'heyo world', Ore.interp("'hello world'.gsub('hell', 'hey')")
	end

	def test_array_proxies
		out = Ore.interp <<~ORE
		    x = [1, 2, 3]
		    y = []
		    x.each({ item;
		        y << item * 2
		    })
		    y
		ORE
		assert_equal [2, 4, 6], out.values

		out = Ore.interp("arr = [1, 2], arr.push(3), arr")
		assert_equal [1, 2, 3], out.values

		out = Ore.interp("arr = [1, 2, 3], arr.pop(), arr")
		assert_equal [1, 2], out.values

		out = Ore.interp("arr = [1, 2, 3], arr.shift(), arr")
		assert_equal [2, 3], out.values

		out = Ore.interp("arr = [2, 3], arr.unshift(1), arr")
		assert_equal [1, 2, 3], out.values

		assert_equal 3, Ore.interp("[1, 2, 3].length()")
		assert_equal 0, Ore.interp("[].length()")

		assert_equal [1, 2], Ore.interp("[1, 2, 3, 4].first(2)")
		assert_equal [3, 4], Ore.interp("[1, 2, 3, 4].last(2)")

		assert_equal [2, 3], Ore.interp("[1, 2, 3, 4].slice(1, 2)")

		assert_equal [3, 2, 1], Ore.interp("[1, 2, 3].reverse()")

		assert_equal "1,2,3", Ore.interp("[1, 2, 3].join(',')")

		assert_equal [2, 4, 6], Ore.interp("[1, 2, 3].map({ x, i; x * 2 })").values
		assert_equal [2, 4], Ore.interp("[1, 2, 3, 4].filter({ x; x % 2 == 0 })").values
		assert_equal 10, Ore.interp("[1, 2, 3, 4].reduce(0, { acc, x; acc + x })")

		assert_equal [1, 2, 3, 4, 5], Ore.interp("[1, 2, 3].concat([4, 5])")
		assert_equal [1, 2, 3, 4], Ore.interp("[[1, 2], [3, 4]].flatten()").values
		assert_equal [1, 2, 3], Ore.interp("[3, 1, 2].sort()")
		assert_equal [1, 2, 3], Ore.interp("[1, 2, 2, 3, 1].uniq()")

		assert Ore.interp("[1, 2, 3].include?(2)")
		refute Ore.interp("[1, 2, 3].include?(5)")

		assert Ore.interp("[].empty?()")
		refute Ore.interp("[1].empty?()")

		assert_equal 2, Ore.interp("[1, 2, 3].find({ x; x > 1 })")
		assert_nil Ore.interp("[1, 2, 3].find({ x; x > 5 })")

		assert Ore.interp("[1, 2, 3].any?({ x; x > 2 })")
		refute Ore.interp("[1, 2, 3].any?({ x; x > 5 })")

		assert Ore.interp("[1, 2, 3].all?({ x; x > 0 })")
		refute Ore.interp("[1, 2, 3].all?({ x; x > 2 })")
	end

	def test_dictionary_proxies
		assert Ore.interp("{}.empty?()")
		refute Ore.interp("{x: 1}.empty?()")

		out = Ore.interp("d = {x: 1, y: 2}, d.clear(), d")
		assert_equal({}, out.dict)

		assert_equal 1, Ore.interp("{x: 1}.fetch(:x, 0)")
		assert_equal 0, Ore.interp("{x: 1}.fetch(:y, 0)")

		assert_equal [:x, :y, :z], Ore.interp("{x: 1, y: 2, z: 3}.keys()")
		assert_equal [1, 2, 3], Ore.interp("{x: 1, y: 2, z: 3}.values()")

		assert Ore.interp("{x: 1, y: 2}.has_key?(:x)")
		refute Ore.interp("{x: 1, y: 2}.has_key?(:z)")

		out = Ore.interp("d = {x: 1, y: 2, z: 3}, d.delete(:y), d")
		assert_equal({ x: 1, z: 3 }, out.dict)

		assert_equal 3, Ore.interp("{x: 1, y: 2, z: 3}.count()")
		assert_equal 0, Ore.interp("{}.count()")

		out = Ore.interp "{x: 1}.merge({y: 2, z: 3})"
		assert_equal({ x: 1, y: 2, z: 3 }, out)
	end

	def test_number_proxies
		assert Ore.interp("4.even?()")
		refute Ore.interp("5.even?()")

		assert Ore.interp("5.odd?()")
		refute Ore.interp("4.odd?()")

		assert_equal 42, Ore.interp("42.5.to_i()")
		assert_equal 42.0, Ore.interp("42.to_f()")

		assert_equal 5, Ore.interp("3.clamp(5, 10)")
		assert_equal 7, Ore.interp("7.clamp(5, 10)")
		assert_equal 10, Ore.interp("15.clamp(5, 10)")

		assert_equal "42", Ore.interp("42.to_s()")
		assert_equal "3.14", Ore.interp("3.14.to_s()")

		assert_equal 5, Ore.interp("5.abs()")
		assert_equal 5, Ore.interp("-5.abs()")

		assert_equal 3, Ore.interp("3.14.floor()")
		assert_equal(-4, Ore.interp("-3.14.floor()"))

		assert_equal 4, Ore.interp("3.14.ceil()")
		assert_equal(-3, Ore.interp("-3.14.ceil()"))

		assert_equal 3, Ore.interp("3.14.round()")
		assert_equal 4, Ore.interp("3.5.round()")

		assert_equal 3, Ore.interp("9.sqrt()")
		assert_equal 5, Ore.interp("25.sqrt()")
	end
end
