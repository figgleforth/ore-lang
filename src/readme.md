### What's here?

This [`src`](/src) folder contains the implementation of Ore in Ruby. The codebase is organized into two main phases:

**Compile-time** (`src/compiler/`) Source code to AST

- [`lexeme.rb`](compiler/lexeme.rb) - Token representation
- [`expressions.rb`](compiler/expressions.rb) - AST node definitions
- [`lexer.rb`](compiler/lexer.rb) - Tokenizes source code into lexemes
- [`parser.rb`](compiler/parser.rb) - Parses lexemes into an AST

**Runtime** (`src/runtime/`) AST to Execution

- [`interpreter.rb`](runtime/interpreter.rb) - Executes the AST
- [`errors.rb`](runtime/errors.rb) - Runtime error definitions
- [`scopes.rb`](runtime/scopes.rb) - Runtime scope definitions

**Orchestration**

- [`ore.rb`](ore.rb) - Main entry point, requires all components
- [`constants.rb`](shared/constants.rb) - Language constants and operator definitions
- [`helpers.rb`](shared/helpers.rb) - Utility functions added to Ore module

---

### Running Your Own Programs With Ruby

To run an Ore program, the source code must go through the [Lexer](compiler/lexer.rb), whose output goes through the [Parser](compiler/parser.rb), whose output goes through the [Interpreter](runtime/interpreter.rb), resulting in final program output.

```ruby
require './src/ore'

lexer   = Ore::Lexer.new "'Hello, World!'"
lexemes = lexer.output # => array of Lexemes

parser      = Ore::Parser.new lexemes
expressions = parser.output # => array of Expressions

interpreter = Ore::Interpreter.new expressions
result      = interpreter.output # => Hello, World!
```

Another option is to use one of the [`#Ore.lex*`, `Ore.parse*`,`Ore.interp*`](runtime/helpers.rb) helpers, which saves you three lines if you only need the output.

```ruby
require './src/ore'

source      = '"Hello, Again!"'
lexemes     = Ore.lex source # => array of Lexemes
expressions = Ore.parse source # => array of Expressions
result      = Ore.interp source # => Hello, Again!

source_file = './my_program.ore'
lexemes     = Ore.lex_file source_file # => array of Lexemes
expressions = Ore.parse_file source_file # => array of Expressions
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
