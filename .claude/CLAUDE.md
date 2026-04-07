# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About Ore

Ore is an educational programming language for web development, implemented in Ruby. It features:

- Naming conventions that replace keywords (Capitalized classes, lowercase functions/variables, UPPERCASE constants)
- Class composition operators instead of inheritance (|, &, ~, ^)
- Dot notation for accessing nested structures and scopes (., ..)
- First-class functions and classes
- Built-in web server support with routing
- When writing .ore source, use `#` for single-line comments (with a space after), and triple backtick ` ``` ` fences for multi-line/block comments

## Common Commands

### Testing

```bash
# Run all tests (default task also runs cloc)
bundle exec rake test

# Run specific test file
ruby test/lexer_test.rb

# Run all tests and cloc
bundle exec rake
```

### Running Ore Programs

```bash
# Run Ore file with hot reload (watches for changes)
bin/ore <file.ore>

# Debug/inspect compilation stages
bin/ore lex "4 + 8"              # Show lexer tokens for code string
bin/ore parse "4 + 8"            # Show AST for code string
bin/ore interp "4 + 8"           # Execute code string

bin/ore lexf <file.ore>          # Tokenize file
bin/ore parsef <file.ore>        # Parse file to AST
bin/ore interpf <file.ore>       # Execute file
```

### Setup

```bash
# Install dependencies (requires Ruby 3.4.1 and Bundler)
bundle install
```

## Architecture

Four phases: **Lexer → Parser → Type Checker → Interpreter**

`Interpreter` is the main entry point. It owns a `Lexer` and `Parser`, and exposes `run(source_code)` which drives all phases. `Lexer` and `Parser` are plain transformation classes you can also call directly.

### Compile-time (src/compiler/)

Source code is tokenized, parsed into an AST, and statically type checked:

- `lexer.rb` - Tokenizes source code into lexemes (tokens)
- `parser.rb` - Parses lexemes into an AST of expression objects
- `lexeme.rb` - Token representation
- `expressions.rb` - AST node definitions
- `type_checker.rb` - Static type checker; runs on the AST before interpretation

### Runtime (src/runtime/)

The AST is executed to produce output:

- `interpreter.rb` - The running program; owns `@lexer`, `@parser`, and all execution state (`stack`, `routes`, `servers`, `loaded_files`, etc.); `run(source)` is the entry point; handles file loading via `load_file_into_scope`
- `scopes.rb` - All scope types and built-in types:
	- `Global < Scope` - The global scope; pushed as the bottom of the stack on first `run`; standard library declarations live here
	- `Type`, `Instance`, `Func`, `Route`, `Return` - Scope hierarchy
	- `String`, `Array`, `Number`, `Dictionary`, `Server`, `Record`, `Database`, etc. - Built-in types
- `errors.rb` - Runtime error definitions

### Systems (src/systems/)

- `server_runner.rb` - HTTP server implementation using WEBrick (routing, URL params, query strings)
- `dom_renderer.rb` - HTML rendering for `Dom` composition

### Shared (src/shared/)

- `constants.rb` - Language constants, operators, precedence table, reserved words
- `helpers.rb` - Utility functions for identifier classification (constant_identifier?, type_identifier?, member_identifier?)

### Entry Point

- `src/ore.rb` - Requires all components; exposes convenience methods:
	- `Ore.lex(source)` / `Ore.lex_file(filepath)` - Tokenize only
	- `Ore.parse(source)` / `Ore.parse_file(filepath)` - Parse to AST
	- `Ore.interp(source)` / `Ore.interp_file(filepath)` - Full execution

### Standard Library

- `ore/preload.ore` - Auto-loaded into the global scope when `load_standard_library` is `true` (default)
- Standard library path defined in `Ore::STANDARD_LIBRARY_PATH`

## Type Checker

The type checker (`src/compiler/type_checker.rb`) runs between the parser and interpreter. It is invoked from `Interpreter#output` before the execution loop, so it also runs on files loaded via `@use`.

### What it checks

- **Typed variable assignments** — `x: String = 123` raises `Type_Mismatch` (literal RHS only)
- **Typed function parameter defaults** — `go { x: Number = 'bad'; x }` raises at the param default
- **Call site argument types** — `add(1, 'oops')` raises if `add` has typed params and the arg is a known literal

Annotations whose RHS is non-literal (an identifier, a function call, etc.) are silently skipped — only literal mismatches are caught statically.

### How it works

`Type_Checker` has two core methods:

- `infer_type(expr)` — maps an expression to an Ore type name string (`'String'`, `'Number'`, `'Symbol'`), or looks up `Identifier_Expr` values in `@types_by_identifier`. Returns `nil` if unknown.
- `check(expr)` — recursive dispatcher; returns `nil` (no error) or a `Type_Mismatch` error. Recurses into all child-bearing expression types.

`@types_by_identifier` is a hash built during the walk:
- Typed assignments (`x: String = ...`) register `'x' => 'String'`
- Named functions with typed params (`add { a: Number; ... }`) register `'add' => ['Number', 'Number']` via `register_func`

Call site checking happens in `check_call` — it looks up the receiver name in `@types_by_identifier`, retrieves the param type array, and compares each literal argument's inferred type against the expected type.

### Important gotcha

`Type_Checker` lives inside `module Ore`. Bare `Array` inside the module resolves to `Ore::Array` (the built-in scope type), not Ruby's `::Array`. Always use `::Array` when checking Ruby array types (e.g. `signature.is_a? ::Array`).

### Known limitation

Call sites that appear before the function definition are not checked — the signature isn't registered yet when the call is encountered. This is a known limitation; a two-pass approach would fix it.

### Errors

- `Ore::Type_Mismatch < Ore::Type_Checking_Failed` — carries `expression`, `declared`, and `inferred`
- `Ore::Type_Checking_Failed` — raised by `output` if any errors were collected

## Scope System

Ore uses a scope hierarchy, all defined in `src/runtime/scopes.rb`:

- **Global** - The global scope; pushed as the bottom of `Interpreter#stack` on first `run`; standard library declarations live here; execution state (routes, servers, loaded files, etc.) lives directly on `Interpreter`
- **Type** - Class definitions (tracks `@types`, `@expressions`)
- **Instance** - Class instances
- **Func** - Function scopes (tracks `@expressions`)
- **Route** - HTTP route handlers (extends Func, adds `@http_method`, `@path`, `@handler`, `@parts`, `@param_names`)
- **Html_Element** - HTML element scopes (tracks `@expressions`, `@attributes`, `@types`)
- **Return** - Return value wrapper (tracks `@value`)

Each scope can have **sibling scopes
** - additional scopes checked first during identifier lookup, used by the unpack feature.

### Scope Operators

Ore provides three scope operators for explicit scope access:

- `../identifier` - Access global scope
- `.identifier` - Access current instance scope only
- `./identifier` - Access current type scope only

**Identifier Search Behavior:**

- `identifier` (no operator) - Searches through all scopes in the stack from current to global, including checking for proxies methods
- `.identifier` - Only searches the current instance scope (does not fall back to global)
- `./identifier` - Only searches the current type scope
- `../identifier` - Only searches the global scope

**Privacy Convention:**

Identifiers starting with `_` are considered private by convention (e.g., `_private_var`, `_helper_function`).

**Validation:**

- Scope operators cannot be followed by literals (e.g., `..123` is a parse error)
- Using `.` outside an instance context raises `Cannot_Use_Instance_Scope_Operator_Outside_Instance`
- Using `./` outside a type context raises `Cannot_Use_Type_Scope_Operator_Outside_Type`

## Static Declarations

Type-level (static) members are declared using the `..` scope operator:

```ore
Person {
    ./count = 0       # Static variable shared across all instances

    ./increment {;  # Static method
        count += 1
    }

    init {;
        ./count += 1  # Access static from instance method
    }
}

Person().init()
Person().init()
Person.increment()   # Call static method on type => 2
```

**Implementation Details:**

- Static declarations are tracked in `type.static_declarations` set
- Instance methods can access type-level variables via `..` operator
- When calling instance methods, the interpreter pushes both the type scope and instance scope onto the stack
- Instances are linked to their types via `instance.enclosing_scope = type`
- Static functions and variables are declared on the Type scope

## Class Composition Operators

Ore uses composition operators instead of inheritance. Applied as `Class | Other { body }`:

- `|` **Union** - merge all declarations; left side wins conflicts
- `&` **Intersection** - keep only declarations shared by both sides
- `~` **Difference** - remove right side's declarations from left side
- `^` **Symmetric Difference** - keep only unique declarations (discard shared ones)

Multiple operators can be chained: `Admin | Read_Permissions | Write_Permissions { }`.

Built-in types like `Server`, `Record`, and `Dom` are composed this way:

```ore
Web_App | Server { get:// {; "Hello" } }
Post | Record { ./database = ../db; table_name = 'posts' }
Layout | Dom { render {; Html([Body("Hello")]) } }
```

## Identifier Naming Conventions

The language enforces naming conventions through the helper functions:

- **UPPERCASE** (constant_identifier?) - Constants
- **Capitalized** (type_identifier?) - Classes/types
- **lowercase** (member_identifier?) - Variables and functions

## Function Conventions

Lowercase identifier, followed by a `{}` grouped block which contains `;` which separates the params and body.

```ore
<identifier> { <args>; <body> }
```

## Class Conventions

A capitalized identifier followed by a `{}` grouped block

```ore
<Identifier> { <body> }
```

The `new` method is the constructor and is called when instantiating a class:

```ore
Point {
    x,
    y,

    new { x, y;
        .x = x
        .y = y
    }
}

p = Point(3, 4)  # Calls new
```

## Unpack Feature

The `@` operator allows unpacking instance members into sibling scopes for cleaner access in two ways:

### Auto-unpack in Function Parameters

`@` behaes as a prefix operator here.

```ore
add { @vec;
    x + y  "# Access vec.x and vec.y directly
}

v = Vector(3, 4)
add(v)  "# Returns 7
```

### Manual Sibling Scope Control

`@` behaves as a standalone left hand operand operator

```ore
Island {
	name;
}

island = Island()
@ += island  # Add island's members to sibling scope
x = island_member  # Access members directly

@ -= island  # Remove island from sibling scope

thingy { @island;
	# use island.name here unpacked
}
```

**Implementation details:**

- `@param` in function signature automatically unpacks parameter into sibling scope
- `@ += instance` and `@ -= instance` provide manual control in any scope
- Sibling scopes are checked first during identifier lookup (before current scope declarations)
- Only works with Instance types; errors with `Invalid_Unpack_Infix_Right_Operand` for non-instances
- Only `+=` and `-=` operators supported; other operators error with `Invalid_Unpack_Infix_Operator`

## Built-in Types and Intrinsic Methods

Ore's built-in types (String, Array, Dictionary, Number) have ruby methods that delegate to Ruby's native implementations. These methods are declared using a `proxy_` prefix (see src/shared/super_proxies.rb)

### Intrinsic Method Implementation Pattern

**In Ore** (`.ore` files):

```ore
String {
    upcase {; @super }
    downcase {; @super }
}
```

**In Ruby** (`scopes.rb`):

```ruby

class String < Instance
	extend Super_Proxies

	proxy_delegate 'value' # Delegate to @value
	proxy :upcase # Calls @value.upcase
	proxy :downcase # Calls @value.downcase
end
```

**Custom ruby handlers** for methods that need special logic:

```ruby

def proxy_concat other_array
	values.concat other_array.values # Extract Ruby array first
end
```

**Methods implemented in Ore** (not as Ruby proxies):
Some methods like `find`, `any?`, and `all?` are implemented directly in Ore using for loops rather than Ruby proxies, as they need to execute Ore functions.

### String

Properties: `length`, `ord`

Methods: `upcase()`, `downcase()`, `split(delimiter)`, `slice(substr)`, `trim()`, `trim_left()`, `trim_right()`, `chars()`, `index(substr)`, `to_i()`, `to_f()`, `empty?()`, `include?(substr)`, `reverse()`, `replace(new)`, `start_with?(prefix)`, `end_with?(suffix)`, `gsub(pattern, replacement)`

Defined in: `ore/string.ore`, implemented in `scopes.rb` as `Ore::String`

### Array

Properties: `values`

Methods: `push(item)`, `pop()`, `shift()`, `unshift(item)`, `length()`, `first(count)`, `last(count)`, `slice(from, to)`, `reverse()`, `join(separator)`, `map(func)`, `filter(func)`, `reduce(func, init)`, `concat(other)`,`flatten()`, `sort()`, `uniq()`, `include?(item)`, `empty?()`, `find(func)` *(Ore)*, `any?(func)` *(Ore)*, `all?(func)`*(Ore)*, `each(func)`

Defined in: `ore/array.ore`, implemented in `scopes.rb` as `Ore::Array`

**Note:** Methods marked *(Ore)* are implemented in Ore using for loops, not as Ruby proxies.

### Dictionary

Methods: `keys()`, `values()`, `has_key?(key)`, `delete(key)`, `merge(other)`, `count()`, `empty?()`, `clear()`, `fetch(key, default)`

```ore
dict = {x: 4, y: 8}
dict[:x]           # Access by key => 4
dict[:z] = 15      # Assignment
dict.keys()        # [:x, :y, :z]
dict.values()      # [4, 8, 15]
dict.empty?()      # false
dict.count()       # 3
```

**Features:**

- Symbol, string, or identifier keys
- Subscript access via `dict[key]`
- Defined in: `ore/dictionary.ore`, implemented in `scopes.rb` as `Ore::Dictionary`

### Number

Properties: `numerator`, `denominator`, `type`

Methods: `to_s()`, `abs()`, `floor()`, `ceil()`, `round()`, `sqrt()`, `even?()`, `odd?()`, `to_i()`, `to_f()`, `clamp(min, max)`

Defined in: `ore/number.ore`, implemented in `scopes.rb` as `Ore::Number`

### File_System (File I/O)

Static methods for reading and writing files:

```ore
content = File_System.read('./path/to/file.txt')  # Read file contents as string
File_System.write_string_to_file('./path/to/file.txt', 'Hello, World!')  # Write string to file
```

Defined in: `ore/file_system.ore`, implemented in `scopes.rb` as `Ore::File_System`

## Loop Control Flow

### For Loops

```ore
for [1, 2, 3, 4, 5]
    result << it
end

for 1..10  # Range support
    sum += it
end

for items by 2  # Stride support
    process it  # it contains chunks of 2 items
end
```

**Intrinsic variables:**

- `it` - Current iteration value
- `at` - Current iteration index

### For Loop Verbs

For loops support transformation verbs that return values: `map`, `select`, `reject`, `count`.

```ore
`Transform each element
doubled = for [1, 2, 3, 4, 5] map
    it * 2
end  # => [2, 4, 6, 8, 10]

`Filter elements where body is truthy
evens = for [1, 2, 3, 4, 5, 6] select
    it % 2 == 0
end  # => [2, 4, 6]

`Filter elements where body is falsy
odds = for [1, 2, 3, 4, 5, 6] reject
    it % 2 == 0
end  # => [1, 3, 5]

`Count elements where body is truthy
count = for [1, 2, 3, 4, 5, 6] count
    it % 2 == 0
end  # => 3
```

**With stride:**

```ore
`Map chunks of 2
sums = for [1, 2, 3, 4, 5, 6] map by 2
    it.0 + it.1
end  # => [3, 7, 11]
```

**With stop (partial results):**

```ore
`Stop returns partial results for map/select/reject
partial = for [1, 2, 3, 4, 5] map
    stop if it == 4
    it * 2
end  # => [2, 4, 6]
```

### Loop Control Keywords

```ore
for items
    if condition
        skip  # Continue to next iteration
    end
    if other_condition
        stop  # Break out of loop
    end
end
```

- **skip** - Skip remaining loop body and continue to next iteration (like `continue`)
- **stop** - Exit the loop immediately (like `break`)
- Works with `for`, `while`, and `until` loops

### While and Until Loops

```ore
while x < 4
    x += 1
end

until x >= 23
    x += 2
end
```

Both support `elwhile`/`else` chaining (like `elif` for loops):

```ore
while x < 4
    x += 1
elwhile y > -8
    y -= 1
else
    z = 1
end
```

### Unless / Control Flows as Expressions

`unless condition` is equivalent to `if !condition`. All control flows (`if`, `unless`, `while`, `until`) are expressions and return values:

```ore
x = unless condition
    4
else
    -4
end
```

### Return Statement

The `return` keyword exits a function and returns a value. It properly propagates even when used inside loops:

```ore
find { func;
    for values
        if func(it)
            return it  # Exits the function, not just the loop
        end
    end
    nil
}

[1, 2, 3].find({ x;
    x > 1
})  # Returns 2
```

**Implementation:**

- `return value` creates an `Ore::Return` object wrapping the value
- For loops detect `Return` objects and propagate them up to the function
- Functions unwrap the `Return` object and return the inner value
- Without `return`, functions return the last expression evaluated

## Code Style Preferences

### Ruby Code Style

- **Indentation**: Use tabs (equivalent to 4 spaces)
- **Class names**: Use `This_Case` (capitalized with underscores), not `ThisCase`
- **Method definitions**: Omit parentheses - `def something arg` not `def something(arg)`
- **Method calls**: Omit parentheses where possible - `foo.bar arg` not `foo.bar(arg)`
- **Comments**: Only add comments for non-obvious code. Don't comment obvious operations

## Testing

Tests use Minitest and inherit from `Base_Test` (in test/base_test.rb):

- `test/lexer_test.rb` - Lexer tests
- `test/parser_test.rb` - Parser tests
- `test/interpreter_test.rb` - Interpreter tests
- `test/proxies_test.rb` - Super Proxy method tests
- `test/regression_test.rb` - Regression tests
- `test/server_test.rb` - Server and routing tests
- `test/e2e_server_test.rb` - End-to-end server tests
- `test/database_test.rb` - Database and ORM tests

The base test class provides `refute_raises` helper for asserting no exceptions.

## Database and ORM

Ore includes built-in database support with an ActiveRecord-style ORM using Sequel and SQLite.

### Database Connection

```ore
@use 'ore/database.ore'

db = Sqlite('./data/myapp.db')
@connect db  # Establishes connection
```

**Database methods:**
- `create_table(name, columns)` - Create table from schema dictionary
- `delete_table(name)` - Drop table
- `table_exists?(name)` - Check if table exists
- `tables()` - List all tables

```ore
db.create_table('users', {
    id: 'primary_key',
    name: 'String',
    email: 'String'
})

db.table_exists?('users')  # => true
db.tables()                # => ['users']
```

### Record ORM

The `Record` type provides ActiveRecord-style ORM functionality:

```ore
@use 'ore/record.ore'

User | Record {
    ./database = ../db      # Set database (static declaration)
    table_name = 'users'
}
```

**Record class methods (static):**
- `all()` - Fetch all records as Array of Dictionaries
- `find(id)` - Find record by ID, returns Dictionary
- `create(attributes)` - Insert new record, returns ID
- `delete(id)` - Delete record by ID

```ore
`Create records
User.create({name: "Alice", email: "alice@example.com"})
User.create({name: "Bob", email: "bob@example.com"})

`Query records
users = User.all()         # => Array of Dictionary instances
user = User.find(1)        # => Dictionary with {id: 1, name: "Alice", ... }

`Delete records
User.delete(1)
```

### Full Example

```ore
@use 'ore/database.ore'
@use 'ore/record.ore'

db = Sqlite('./temp/blog.db')
@connect db

# Create schema
db.create_table('posts', {
    id: 'primary_key',
    title: 'String',
    body: 'String'
})

# Define model
Post | Record {
    ./database = ../db
    table_name = 'posts'
}

# Use ORM
Post.create({title: "Hello", body: "World"})
posts = Post.all()

for posts
    @puts "`it[:title]`: `it[:body]`"
end
```

**Implementation:**
- Database operations use Ruby's Sequel gem
- Record methods are proxy methods (see `src/runtime/scopes.rb`)
- Records return `Ore::Dictionary` instances
- Static declarations (`..database`) link models to database

## Web Server Features

Ore has built-in web server support:

- **Server class composition** - Create servers by composing with the built-in `Server` class using `|` operator
- **Route syntax** - Routes defined as `method://path` (e.g., `get://`, `post://users/:id`)
- **URL parameters** - Use `:param` syntax in routes, accessed via route function parameters
- **Query strings** - Available via `request.query` dictionary
- **Request/Response objects** - Automatically available in route handlers (from `scopes.rb`)
- **HTTP redirects** - `response.redirect(url)` for POST/Redirect/GET pattern (uses 303 See Other)
- **Form data** - POST body available via `request.body` dictionary
- **`@start` directive** - Non-blocking server startup, allows multiple concurrent servers
- **Graceful shutdown** - Servers stop when program exits
- **WEBrick backend** - HTTP server implementation in `server_runner.rb`

### Response Methods

- `response.redirect(url)` - Redirect to URL (HTTP 303 See Other, changes POST to GET)
- `response.status = code` - Set HTTP status code
- `response.headers[key] = value` - Set response headers
- `response.body = content` - Set response body

```ore
post://login {;
    if authenticate(request.body.username, request.body.password)
        response.redirect("/dashboard")
    else
        response.status = 401
        "Unauthorized"
    end
}
```

## HTML Rendering

Ore supports HTML rendering via the built-in `Dom` type (load `ore/html.ore`). Any class composing with `Dom` that defines a `render` method will auto-render to HTML when returned from a server route.

```ore
@use 'ore/html.ore'

Layout | Dom {
    title,

    new { title = 'My Page';
        .title = title
    }

    render {;
        Html([
            Head(Title(title)),
            Body(H1("Hello!"))
        ])
    }
}
```

**HTML and CSS attributes** use `html_` and `css_` prefixes on declarations:

```ore
Styled_Div | Dom {
    html_element = 'p'
    html_class = 'my_class'
    html_id = 'my_id'
    css_background_color = 'black'
    css_color = 'white'
}
# => <p class='my_class' id='my_id' style='background-color:black;color:white;'></p>
```

**Predefined elements** in `ore/html.ore`: `Html`, `Head`, `Body`, `Title`, `H1`–`H6`, `P`, `Span`, `A`, `Div`, `Form`, `Input`, `Button`, `Ul`, `Ol`, `Li`, `Table`, `Tr`, `Td`, `Th`, and more.

- Routes returning a `Dom` instance automatically render to HTML string
- HTML rendering only works when `render{;}` is called by a Server instance
- `html_element` sets the tag name (default `'div'`)
- Fence blocks starting with `html\n` are treated as raw HTML tokens by the lexer

## File Loading

The `@use` directive allows importing Ore files:

.- Interpreter tracks loaded files in `@loaded_files` to prevent duplicate parsing
- Files are loaded into a specified scope via `Interpreter#load_file_into_scope`
- Expressions are cached in `@loaded_files` keyed by resolved filepath
