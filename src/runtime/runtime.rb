module Ore
	class Runtime
		attr_accessor :stack, :routes, :servers, :onclick_handlers, :input_elements, :loaded_files, :source_files, :cd_scopes

		def initialize
			@stack            = []
			@servers          = []
			@routes           = {} # {route: Ore::Route}
			@loaded_files     = {} # {filename: Ore::Expression}
			@source_files     = {} # {filepath: String} for error reporting
			@onclick_handlers = {} # {handler_hash: Ore::Func}
			@input_elements   = {} # {element_hash: Ore::Instance} for inputs/textareas
			@cd_scopes        = Set.new # Scopes pushed via @cd directive
		end
	end
end