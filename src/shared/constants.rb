module Ore
	STANDARD_LIBRARY_PATH      = './ore/preload.ore'
	RUNTIME_SCOPE_OPERATOR     = '@'
	NIL_INIT_POSTFIX           = ','
	FUNCTION_DELIMITER         = '->'
	IMPORT_FILE_DIRECTIVE      = 'use'
	FOR_VERBS                  = %w(each map select reject count)
	HTML_ATTRS                 = %w(id class href)
	HTTP_VERBS                 = %w(get put patch post delete head options connect trace)
	VOID_HTML_TAGS             = %w(area base br col command embed hr img input keygen link meta param source track wbr)
	HTTP_VERB_SEPARATOR        = '://'
	INTERPOLATE_CHAR           = '|'
	COMMENT_CHAR               = '#'
	FENCE_CHARS                = '```'
	PREFIX                     = %w(! - + ~ not return)
	INFIX                      = %w(
		+ - ^ * ** / % ~ == === ? . .?
		= : ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		&& || & | << >>
		.. >. .< ><
		!= <= >= < > <=> < >
		and or
	)
	POSTFIX                    = %w() # Be sure not to make ; a postfix operator because it behaves as postfix with a declaration but as a delimiter inside func param declarations.
	CIRCUMFIX                  = %w( \( [ { | )
	CIRCUMFIX_GROUPINGS        = { '(' => '()', '{' => '{}', '[' => '[]', '|' => '||' }.freeze
	LOGICAL_OPERATORS          = %w(&& & || | and or)
	COMPOUND_OPERATORS         = %w(||= &&= **= <<= >>= += -= *= |= /= %= &= ^=)
	COMPARISON_OPERATORS       = %w(<=> == === != !== <= >= < > =~ !~)
	INFIX_ARITHMETIC_OPERATORS = %w(+ - * ** / % << >> ^ & |)
	RANGE_OPERATORS            = %w(.. .< >. ><)
	SCOPE_OPERATORS            = %w(. ./ ../)
	DOT_ACCESS_OPERATORS       = %w(. .?)
	TYPE_COMPOSITION_OPERATORS = %w(| & ~ ^) # Union, Intersection, Removal, Symmetric Difference
	ANY_IDENTIFIER             = %i(identifier Identifier IDENTIFIER)
	GSCOPE                     = :global
	STARTING_PRECEDENCE        = 0
	DELIMITERS                 = %W(, ; -> { } ( ) [ ] \n \r).freeze
	NEWLINES                   = %W(\r\n \n).freeze
	WHITESPACES                = %W(\t \s).freeze
	NUMERIC_REGEX              = /\A\d+\z/
	ALPHA_REGEX                = /\A\p{Alpha}+\z/
	ALPHANUMERIC_REGEX         = /\A\p{Alnum}+\z/
	SYMBOLIC_REGEX             = /\A[^\p{Alnum}\s]+\z/

	# It's been a while, but I believe this RESERVED list must be maintained. The other declarations above are helpers for comparisons while this contains every reserved symbols and identifiers.
	RESERVED = %w(
		[ { ( , _ . .. -> ) } ]
		: ;
		+ - * ** / % ~
		= ||= &&= **= <<= >>= += -= *= |= /= %= &= ^=
		== === != !== <= >= < >
		! ? ?? !! && || & | << >>
		.. >. .< >< <=>
		@ ../ ./
		``` #

		for
		if elif else
		while elwhile
		unless until
		true false nil
		and or return
		skip stop
	)

	PRECEDENCES = {
		              # Member access
		              '.' => 1200, '.?' => 1200,

		              # Subscript/call
		              '[' => 1100, '{' => 1100, '(' => 1100,

		              # Exponentiation
		              '**' => 1000,

		              # Unary
		              '!' => 900, 'not' => 900,

		              # Multiplicative
		              '*' => 800, '/' => 800, '%' => 800,

		              # Additive
		              '+' => 700, '-' => 700,

		              # Bitwise shifts
		              '<<' => 600, '>>' => 600,

		              # Relational
		              '<' => 550, '<=' => 550, '<=>' => 550, '>' => 550, '>=' => 550,

		              # Equality
		              '==' => 500, '!=' => 500, '===' => 500, '!==' => 500,

		              # Bitwise AND
		              '&' => 450,

		              # Bitwise XOR
		              '^' => 425,

		              # Bitwise OR
		              '|' => 410,

		              # Logical AND
		              '&&' => 300, 'and' => 300,

		              # Logical OR
		              '||' => 200, 'or' => 200,

		              # Member/label
		              ':' => 140,

		              # Comma
		              ',' => 100,

		              # Assignment
		              '='   => 90, '+=' => 90, '-=' => 90, '*=' => 90, '/=' => 90,
		              '%='  => 90, '&=' => 90, '&&=' => 90, '|=' => 90, '||=' => 90,
		              '^='  => 90, '<<=' => 90, '>>=' => 90,
		              '**=' => 90,

		              # Ranges
		              '..' => 80, '.<' => 80, '>.' => 80, '><' => 80,

		              # Keywords
		              'return' => 70,
		              'unless' => 60, 'if' => 60, 'while' => 60, 'until' => 60,
	              }.freeze
end
