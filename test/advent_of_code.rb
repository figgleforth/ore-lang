require 'minitest/autorun'
require_relative '../src/ore'
require_relative 'base_test'

class Advent_Of_Code < Base_Test
	def test_2015_01
		assert Ore.interp_file 'examples/aoc/2015/01/part1.ore'
		assert Ore.interp_file 'examples/aoc/2015/01/part2.ore'
	end

	def test_2015_02
		assert Ore.interp_file 'examples/aoc/2015/02/part1.ore'
		assert Ore.interp_file 'examples/aoc/2015/02/part2.ore'
	end

	def test_2015_03
		assert Ore.interp_file 'examples/aoc/2015/03/part1.ore'
		assert Ore.interp_file 'examples/aoc/2015/03/part2.ore'
	end

	# Skipping these because they are computationally expensive and take several minutes

	# def test_2015_04
	# assert Ore.interp_file 'examples/aoc/2015/04/part1.ore'
	# assert Ore.interp_file 'examples/aoc/2015/04/part2.ore'
	# end

	# def test_2015_05
	# 	assert Ore.interp_file 'examples/aoc/2015/05/part1.ore'
	# 	assert Ore.interp_file 'examples/aoc/2015/05/part2.ore'
	# end

end
