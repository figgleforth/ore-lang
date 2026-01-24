module Ore
	class Error_Formatter
		attr_reader :error, :expression, :runtime

		def initialize error, runtime
			@error      = error
			@expression = error.expression
			@runtime    = runtime
		end

		def error_name
			error.class.name.split('::').last
		end

		def error_name_styled
			Ore::Ascii.bold(Ore::Ascii.red(error.class.name.split('::').last))
		end

		def format
			parts  = []
			indent = "    "

			parts << error_name_styled

			if location_available?
				parts << ""
				parts << source_snippet if source_available?
				parts << ""
			end

			parts << Ore::Ascii.cyan(location_line)
			parts.join "\n"
		end

		def location_available?
			expression&.respond_to? :l0
		end

		def source_available?
			runtime && location_available?
		end

		def location_line
			# todo bug: Does not display source code properly
			if expression.is_a?(Ore::Expression) && expression.l0
				"#{expression.source_file}:#{expression.l0}:#{expression.c0}"
			else
				# todo: How do I get the source string here?
				source_snippet
			end
		end

		# Simplified version of source_snippet
		def source_snippet
			# Initial checks and coordinate fetching remain the same
			l0, c0, l1, c1 = get_location_coords
			return nil unless l0
			return nil unless runtime

			source_file = get_source_file
			lines       = runtime.source_files[source_file] || []
			return nil if lines.empty?

			# Determine snippet boundaries
			surrounding_lines = 3
			start_line        = [l0 - surrounding_lines, 1].max
			end_line          = [l1 + surrounding_lines, lines.length].min

			snippet_lines = []

			(start_line..end_line).each do |line_num|
				line_index   = line_num - 1
				line_content = lines[line_index] || ""

				# Expand tabs once per line for consistent display
				visual_content = line_content.gsub("\t", "    ")
				prefix         = Ore::Ascii.cyan("#{line_num.to_s.rjust(5)} │ ")

				is_error_line = (line_num >= l0 && line_num <= l1)

				if is_error_line
					# Calculate the start and end character positions for the error span on this specific line
					start_char = (line_num == l0) ? (c0 - 1) : 0
					end_char   = (line_num == l1) ? c1 : visual_content.length

					# Convert character indices to visual (space-expanded) indices
					visual_start            = line_content[0...start_char].gsub("\t", "    ")
					visual_end              = line_content[0...end_char].gsub("\t", "    ")
					visual_start_char_count = visual_start.length
					visual_end_char_count   = visual_end.length

					before     = visual_content[0...visual_start_char_count]
					error_span = visual_content[visual_start_char_count...visual_end_char_count]
					after      = visual_content[visual_end_char_count..-1] || ""

					# Apply color/style to the error span
					styled_span = Ore::Ascii.bold(Ore::Ascii.red(error_span))

					# Use Colors.make only for the single-line case where we want a different style
					if l0 == l1 && line_num == l0
						styled_span = Ore::Ascii.bold(Ore::Ascii.make(error_span))
					end

					snippet_lines << prefix + before + styled_span + after
					spaces      = " " * visual_start_char_count
					error_label = error_name.gsub '_', ' '

					prefix     = Ore::Ascii.cyan("#{' '.rjust(5)} │ ")
					error_line = spaces + Ore::Ascii.bold(Ore::Ascii.red("╰── " + error_label))
					snippet_lines << prefix + error_line
				else
					# Regular surrounding line
					snippet_lines << prefix + visual_content
				end
			end

			snippet_lines.join "\n"
		end

		private

		def get_location_coords
			if expression.is_a?(Ore::Expression) && expression.l0
				[expression.l0, expression.c0, expression.l1 || expression.l0, expression.c1 || expression.c0]
			else
				[nil, nil, nil, nil]
			end
		end

		def get_source_file
			expression&.source_file
		end
	end
end
