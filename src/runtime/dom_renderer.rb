module Ore
	class Dom_Renderer
		HTML_PREFIX  = 'html_'.freeze
		CSS_PREFIX   = 'css_'.freeze
		ELEMENT_ATTR = 'html_element'.freeze

		attr_accessor :dom, :element, :inner_html
		attr_writer :html_attrs, :css_attrs

		def initialize dom_instance, inner_html = ''
			@dom        = dom_instance
			@element    = @dom.declarations[ELEMENT_ATTR]
			@inner_html = inner_html
		end

		def has_inner_html? # aka void tag
			!Ore::VOID_HTML_TAGS.include?(element)
		end

		def html_attrs
			@html_attrs ||= dom.declarations.reject do |key, _|
				key == 'html_element' # This identifier is just used to determine the element to render, so it shouldn't be included as an attribute of the final HTML string.
			end.select do |key, v|
				key.to_s.start_with? HTML_PREFIX
			end.map do |key, value|
				key = key.to_s.gsub HTML_PREFIX, ''
				key = key.gsub '_', '-'
				[key, value]
			end.to_h
		end

		def css_attrs
			@css_attrs ||= dom.declarations.select do |key, v|
				key.to_s.start_with? CSS_PREFIX
			end.map do |key, value|
				key = key.to_s.gsub CSS_PREFIX, ''
				key = key.gsub '_', '-'
				[key, value]
			end.to_h
		end

		def html_attrs_string
			html_attrs.map do |attr, value|
				"#{attr}=\"#{value}\""
			end.join(' ')
		end

		def css_attrs_string
			css_attrs.map do |attr, value|
				"#{attr}:#{value}"
			end.join(';')
		end

		def to_html_string
			"<#{element}".tap do |html|
				unless html_attrs.empty?
					html << " "
					html << html_attrs_string
				end

				unless css_attrs.empty?
					html << " style=\""
					html << css_attrs_string
					html << "\""
				end

				html << ">"
				if has_inner_html?
					html << inner_html
					html << "</#{element}>"
				end
			end
		end
	end
end
