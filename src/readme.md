### What's here?

This [`src`](/src) folder contains the implementation of Ore in Ruby. The codebase is organized into three phases:

**Compile-time** (`src/compiler/`) Source code to AST

- [`lexeme.rb`](compiler/lexeme.rb) - Token representation
- [`expressions.rb`](compiler/expressions.rb) - AST node definitions
- [`lexer.rb`](compiler/lexer.rb) - Tokenizes source code into lexemes
- [`parser.rb`](compiler/parser.rb) - Parses lexemes into an AST

**Runtime** (`src/runtime/`) AST to Execution

- [`interpreter.rb`](runtime/interpreter.rb) - The running program; owns a Lexer, Parser, and Runtime; `run(source)` is the entry point
- [`scopes.rb`](runtime/scopes.rb) - All scope types (Runtime, Type, Instance, Func, Route, …) and built-in types (String, Array, Number, …)
- [`errors.rb`](runtime/errors.rb) - Runtime error definitions

**Shared** (`src/shared/`)

- [`constants.rb`](shared/constants.rb) - Language constants and operator definitions
- [`helpers.rb`](shared/helpers.rb) - Utility functions added to Ore module

**Entry point**

- [`ore.rb`](ore.rb) - Requires all components; exposes `Ore.lex`, `Ore.parse`, `Ore.interp` convenience methods

---

### Running Your Own Programs With Ruby

`Interpreter` is the entry point. Call `run` with source code and it handles lexing, parsing, and execution:

```ruby
require './src/ore'

interpreter = Ore::Interpreter.new
result      = interpreter.run "'Hello, World!'" # => Hello, World!
```

You can also step through each phase manually:

```ruby
require './src/ore'

lexer       = Ore::Lexer.new "'Hello, World!'"
lexemes     = lexer.output       # => array of Lexemes

parser      = Ore::Parser.new lexemes
expressions = parser.output      # => array of Expressions

interpreter       = Ore::Interpreter.new
interpreter.input = expressions
result            = interpreter.output # => Hello, World!
```

Or use the `Ore` module convenience methods:

```ruby
require './src/ore'

source      = '"Hello, Again!"'
lexemes     = Ore.lex source        # => array of Lexemes
expressions = Ore.parse source      # => array of Expressions
result      = Ore.interp source     # => Hello, Again!

source_file = './my_program.ore'
lexemes     = Ore.lex_file source_file
expressions = Ore.parse_file source_file
result      = Ore.interp_file source_file
```

### Running Your Own Programs By Command Line

This is the quickest way to run code:

```bash
bundle exec bin/ore file.ore
```

You can also use `bin/ore interp` for direct source as string evaluation:

```bash
bundle exec bin/ore interp "4 + 8"
```
