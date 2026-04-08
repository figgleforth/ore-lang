require './src/ore.rb'
require 'readline'

module Ore
	class REPL
		HELP = <<~TEXT
		    exit with \\q, \\x, or exit
		    press enter to interpret an expression
		    use ``` to toggle multi-line block mode
		TEXT

		def initialize
			@interpreter = Interpreter.new
			@block_mode  = false
		end

		def run
			puts Ascii.dim "Ore REPL  \\q to quit"

			Readline.completion_append_character = nil
			Readline.completion_proc             = proc { [] }
			trap('INT') { exit }

			loop do
				input = read_input
				next if input.strip.empty?

				if input.strip.downcase == 'help'
					puts HELP
					next
				end

				begin
					output = @interpreter.run input
					print_output output.to_s
				rescue StandardError => e
					print_error e.message
				end
			end
		end

		private

		def read_input
			input = ''
			loop do
				line = Readline.readline '', true
				exit if line.nil?

				if %w[\q \x exit].include? line.strip.downcase
					exit
				elsif line.strip.end_with? '```'
					@block_mode = !@block_mode
					next if @block_mode
					break
				else
					input += line + "\n"
					break unless @block_mode
				end
			end
			input
		end

		def print_output str
			str.each_line { puts Ascii.bold _1.chomp }
		end

		def print_error msg
			msg.each_line { puts Ascii.red _1.chomp }
		end
	end
end
