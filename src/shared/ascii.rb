module Ore
	module Ascii
		STYLES = {
			         reset:     "\e[0m",
			         red:       "\e[31m",
			         green:     "\e[32m",
			         yellow:    "\e[33m",
			         blue:      "\e[34m",
			         magenta:   "\e[35m",
			         cyan:      "\e[36m",
			         white:     "\e[37m",
			         black:     "\e[30m",
			         default:   "\e[39m",
			         bold:      "\e[1m",
			         dim:       "\e[2m",
			         italic:    "\e[3m",
			         underline: "\e[4m",
		         }.freeze

		STYLES.each do |name, code|
			const_set name.upcase, code

			define_singleton_method name do |str = nil|
				return (enabled? ? code : "") if str.nil?
				enabled? ? "#{code}#{str}#{RESET}" : str
			end
		end

		def self.make str, foreground = "31", background = "31"
			enabled? ? "\x1b[#{foreground};#{background}m#{str}#{RESET}" : str
		end

		def self.enabled?
			$stdout.tty? && ENV['TERM'] != 'dumb' && !ENV['NO_COLOR']
		end
	end
end
