![Version](https://img.shields.io/badge/version-0.0.0-2B7FFF.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-2B7FFF.svg)
[![justforfunnoreally.dev badge](https://img.shields.io/badge/justforfunnoreally-dev-2B7FFF)](https://justforfunnoreally.dev)
![Status of project Ruby tests](https://github.com/figgleforth/ore-lang/actions/workflows/tests.yml/badge.svg)

### Quick Start

> Requires Ruby `3.4.1` or higher, and Bundler

```bash
git clone https://github.com/figgleforth/ore-lang.git
cd ore-lang
bundle install
bundle exec bin/ore examples/hello.ore # => Hello, Ore!
```

Example code from [examples/hello.ore](./examples/hello.ore):

```ore
Greet {
	subject,

	new { subject;
		.subject = subject
	}

	greeting {;
		"Hello, `subject`!"
	}
}

Greet('Ore').greeting()
```

### Table of Contents

- [Features](#features)
- [Code Examples](#code-examples)
    - [Manual Type Contracts](#manual-type-contracts)
    - [Runtime Type Contracts](#runtime-type-contracts)
    - [Variables](#variables)
    - [Functions](#functions)
    - [Classes](#classes)
    - [Loops](#loops)
    - [Instance Unpacking](#instance-unpacking)
    - [File Loading](#file-loading)
    - [Database & ORM](#database--orm)
    - [Web Servers](#web-servers)
    - [HTML Rendering](#html-rendering)
    - [Operator Overloading](#operator-overloading) 
- [Project Structure](#project-structure)

### Features

- Gradual typing — opt in as needed
	- Static type checking at parse time for literal mismatches (`x: String = 99`)
	- Call site argument types checked against typed function signatures (`add(123, 'boo')`, `add { a: Number, b: NUmber }`)
	- Runtime type contracts via `:=` where type is inferred and enforced on future assignments (`x := 123`)
	- Plain `=` behaves dynamic without reassignment restrictions
- Naming conventions replace keywords
	- `Capitalize` classes
	- `lowercase` variables and functions
	- `UPPERCASE` constants
- Class composition replaces inheritance
	- `|` Union - merge classes (left side wins conflicts)
	- `&` Intersection - keep only shared declarations
	- `~` Difference - discard right side declarations
	- `^` Symmetric Difference - discard shared declarations
- Scope operators for explicit access
	- `.identifier` accesses instance scope only, like `self.identifier`
	- `./identifier` accesses type/static scope, like `self.class.identifier`
	- `../identifier` accesses global scope
- First-class functions and classes
- Data containers `Array`, `Tuple`, `Dictionary`
- Loops like `for`, `while`, and `until`
	- Automatic `it` declaration for iteration value
	- Automatic `at` declaration for iteration index
	- `skip` and `stop` keywords for loop control
	- Stride support with `for x by 2` syntax
- Unpacking an instance's declarations with `@` operator
	- Makes declarations accessible without `instance.` prefix
	- Auto-unpack function parameters in function body `funk { @with; }`
	- Manually unpack `@ += instance` and undo `@ -= instance`
- Basic web server with routing
	- Route definitions use `method://path` syntax (e.g., `get://`, `post://users/:id`)
	- URL parameters via `:param` syntax
	- Query string and form data access via `request.query` and `request.body`
	- HTTP redirects with `response.redirect(url)`
	- Non-blocking `@start` directive allows running multiple servers
	- Graceful shutdown handling when program exits
- Database ORM with SQLite
	- Base composable `Record` type with `all()`, `find()`, `create()`, `delete()` methods
	- Database operations via `Database` type
	- Schema definition with dictionaries
	- Static database linking with `./database = ../db`
- HTML rendering with `Dom` composition
	- Compose HTML with built-in HTML DOM elements (`Dom`, `Html`, `Body`, `Div`, `H1`, etc)
	- Declare `html_` prefixed attributes for HTML attributes (`html_href`, `html_class`)
	- Declare `css_` prefixed properties for CSS (`css_color`, `css_background`)
	- Routes returning `Dom` instances automatically render to HTML
	- Standard library provides common HTML elements
- Operator overloading for `infix`, `prefix`, and `postfix` fixities
	- Declare with `@operator <op> @<fixity> <precedence> { params; body }`
	- Operators are regular functions stored in scope — overloads don't leak outside their declaring scope
	- Any symbol sequence or identifier can be an operator (`->`, `!!`, `pm`, `$`)

### Code Examples

#### Manual Type Contracts

Manual Type Contracts are created by using `: Type` syntax on variables and function parameters.

```ore
# Variable annotations
x: String = 'hello'   # ok
y: Number = 42        # ok
z: String = 99        # Type_Checking_Failed — String expected, Number given

# Parameter annotations
add { a: Number, b: Number;
	a + b
}

add(1, 2)      # ok
add(1, 'two')  # Type_Checking_Failed — Number expected for b, String given
```

Annotations on variables whose values aren't known statically (e.g. the result of a function call or another identifier) are not checked at parse time — only literal mismatches are caught.

#### Runtime Type Contracts

`:=` infers a type from the right hand side and locks the variable to that type for future `=` assignments. Plain `=` without a prior `:=` or annotation stays fully dynamic.

```ore
x := 4        # x is now a Number
x = 8         # ok — same type
x = 'hello'   # Type_Contract_Violation — Number expected, got String

x := 'hello'  # re-initialize — x is now a String
x = 'world'   # ok

y = 4
y = 'hello'   # ok — no contract, fully dynamic
```

#### Variables

```
# Comments start with a hash

nothing,            # Syntactic sugar for "nothing = nil"
something = true
okay_too = 42,      # Comma allowed as expression separator

# Strings can be single or double quoted, and interpolated with backticks
LANG_NAME = "ore-lang"
version   = '0.0.0'
lines     = 4_815
header    = "`LANG_NAME` v`version`"   # "ore-lang v0.0.0"
footer    = 'Lines of code: `lines`'   # "Lines of code: 4815"

# Ranges
inclusive_range   = 0..2
exclusive_range   = 2><5
l_exclusive_range = 5>.7
r_exclusive_range = 7.<9

# Data containers
tuples = (header, footer)
arrays = [inclusive_range, exclusive_range]

# Dictionaries can be initialized in multiple ways, commas and values are optional
dict = {}                       # {}
dict = {x y}                    # {x: nil, y: nil}
dict = {u, v}                   # {u: nil, v: nil}
dict = { a:0 b=1 c}             # {a: 0, b: 1, c: nil}
dict = { x:4, y=8, z}           # {x: 4, y: 8, z: nil}
dict = { v=version, l=lines }   # {v: "0.0.0", l: 4815}
```

#### Functions

```
# Syntax: <function_name> { <params, etc>; <body> }, where ";" is the delimiter between params and body.

noop_function {;}

best_show {;
	"Lost"  # Last expression is return value
}

fizz_buzz { n;
	if n % 3 == 0 and n % 5 == 0
		'FizzBuzz'
	elif n % 3 == 0
		'Fizz'
	elif n % 5 == 0
		'Buzz'
	else
		'`n`'
	end           # Control flows close with `end`
}                 # Code blocks close with `}`
```

#### Classes

```
# Syntax: <class_name> { <body> }

Repo {
	user,
	name,

	# "new" is reserved for constructors
	new { user, name;
		.user = user
		.name = name
	}

	to_s {;
		"`user`/`name`"
	}
}

Repo('figgleforth', 'ore-lang').to_s() # "figgleforth/ore-lang"
```

#### Loops

```ore
# For loops iterate over arrays, ranges, and other iterables
result = []
for [1, 2, 3, 4, 5]
	result << it  # it is the current iteration value
end
# result = [1, 2, 3, 4, 5]

# Map, select, reject, etc...
for [1, 2, 3] map
	it * 2
end

# Stride support with "by" keyword
for [1, 2, 3, 4] select by 2
	it # [1, 2] or [2, 4]
end

for [1, 2, 3, 4] reject by 2,1 # the overlap amount
	it # [1, 2] or [2, 3] or [3,4]
end

for [1, 2, 3, 4, 5, 6, 7] each by 3,1
	it # [1,2,3] or [3,4,5] or [5,6,7] ...
end

for [1, 2, 3, 4, 5, 6, 7, 8] each by 4,2
	it # [1,2,3,4] or [3,4,5,6] or [5,6,7,8] ...
end

# Ranges work too
sum = 0
for 1..10
	sum += it
end
# sum = 55

# Access iteration index with `at`
indexed = []
for ['a', 'b', 'c']
	indexed << "`at`: `it`"
end
# indexed = ["0: a", "1: b", "2: c"]

# Loop control with skip and stop
evens = []
for 1..10
	if it % 2 != 0
		skip  # Continue to next iteration
	end
	evens << it
	if it == 6
		stop  # Break out of loop
	end
end
# evens = [2, 4, 6]
```

#### Instance Unpacking

```ore
Vector {
	x,
	y,

	new { x, y;
		.x = x
		.y = y
	}
}

# Auto-unpack in function parameters with @
add { @vec;
	x + y  # Access vec.x and vec.y directly without vec. prefix
}

v = Vector(3, 4)
add(v)  # 7

# Manual sibling scope control
multiply { factor;
	v1 = Vector(5, 10)
	@ += v1  # Add v1's members to sibling scope

	result_x = x * factor  # Access x directly
	result_y = y * factor  # Access y directly

	@ -= v1  # Remove v1 from sibling scope

	Vector(result_x, result_y)
}

multiply(2)  # Vector(10, 20)
```

#### File Loading

```ore
# Load external Ore files with @use directive
@use './some_formatter.ore'
@use './some_dir/users.ore'

# Use loaded classes and functions
user = User('Alice', 'alice@example.com')
formatted = format_name(user.name)
```

#### Database & ORM

```ore
@use 'ore/database.ore'
@use 'ore/record.ore'

# Create and connect to database
db = Sqlite('./temp/blog.db')
@connect db

# Create table with schema
db.create_table('posts', {
	id: 'primary_key',
	title: 'String',
	body: 'String'
})

# Define model by composing with Record
Post | Record {
	./database = ../db     # Link to static ..database declaration
	table_name = 'posts'
}

# Create records
Post.create({title: "Hello Ore", body: "Building web apps is fun!"})
Post.create({title: "Databases", body: "SQLite integration works!"})

# Query records
posts = Post.all()         # Fetch all posts
post = Post.find(1)        # Find by ID

# Access record data (returns Dictionary)
post[:title]               # "Hello Ore"
post[:body]                # "Building web apps is fun!"

# Delete records
Post.delete(2)
```

> For a complete full-stack example, see [todo_app.ore](examples/todo_app.ore) which combines Database, ORM, Server, HTML rendering, and forms into a working CRUD application.

#### Web Servers

```ore
@use 'ore/server.ore'

# Create servers by composing with built-in Server type
Web_App | Server {
	# Define routes using HTTP method and path
	get:// {;
		"<h1>Welcome to Ore!</h1>"
	}

	get://hello/:name { name;
		"<h1>Hello, `name`!</h1>"
	}

	post://submit {;
		"Form submitted"
	}
}

API_Server | Server {
	get://api/users {;
		"[{\"id\": 1, \"name\": \"Alice\"}]"
	}
}

# Both servers run concurrently in background threads
app = Web_App(8080)
api = API_Server(3000)
@start app
@start api
```

#### HTML Rendering

Using built-in `Dom` composition:

```ore
@use 'ore/html.ore'

Layout | Dom {
	title,
	body_content,

	new { title = 'My page', body_content = 'Hello!';
		.title = title
		.body_content = body_content
	}

	render {;
		# Use built-in Html, Head, Title, and Body types
		Html([
			Head(Title(title)),
			Body(body_content)
		])
	}
}
```

Using strings with HTML:

```ore
@use 'ore/html.ore'

Layout | Dom {
	render {;
		"<html><head><title>My page</title></head><body>Hello!</body></html>"
	}
}
```

Both examples will produce an HTML response as long as the class composes with `Dom`:

```
<html>
	<head>
		<title>My page</title>
	</head>
	<body>
		Hello!
	</body>
</html>
```

Adding HTML and CSS attributes:

```ore
@use 'ore/html.ore'

My_Div | Dom {
	html_element = 'p'
	html_class = 'my_class'
	html_id = 'my_id'
	css_background_color = 'black'
	css_color = 'white'
}

# => <p class='my_class' id='my_id' style='background-color:black;color:white;'></p>
```

Note: Rendering HTML only works when `render{;}` is called by a Server instance. See [html.ore](ore/html.ore) for predefined `Dom` elements. See [web1.ore](examples/web1.ore) for Server and HTML usage.

#### Operator Overloading

Operators are declared with `@operator`, a fixity (`@infix`, `@prefix`, `@postfix`), a precedence, and a function body. They are stored as regular functions in the declaring scope and looked up at runtime.

```ore
# Infix: pipe operator — passes left as argument to right function
@operator -> @infix 300 { left, right;
	right(left)
}

double { n; n * 2 }
add_one { n; n + 1 }

5 -> double -> add_one  # => 11

# Prefix: $ constructs a Currency
Currency { amount, name, code, }

@operator $ @prefix 900 { amount;
	c = Currency()
	c.amount = amount
	c.name = 'US Dollar'
	c.code = 'USD'
	c
}

$42  # => Currency(amount: 42, name: 'US Dollar', code: 'USD')

# Postfix: pm annotates a time value
Time { hour, minute, period, }

@operator : @infix 700 { hour, minute;
	t = Time()
	t.hour = hour
	t.minute = minute
	t
}

@operator pm @postfix 600 { left;
	left.period = 'pm'
	left
}

11:22pm  # => Time(hour: 11, minute: 22, period: 'pm')
```

See [operator_overloads.ore](examples/operator_overloads.ore) for more examples.

### Project Structure

- [`src/readme`](src/readme.md) details the architecture and contains instructions for running your own programs
- [`examples`](examples) contains code examples written in Ore
- [`ore`](ore) contains code for the Ore standard library
- [`src`](src) contains code implementing Ore
    - [Lexer](src/compiler/lexer.rb) – Source code to Lexemes
    - [Parser](src/compiler/parser.rb) – Lexemes to Expressions
    - [Type_Checker](src/compiler/type_checker.rb) – Basic type annotation checking
    - [Interpreter](src/runtime/interpreter.rb) – Entry point; `run(source)` lexes, parses, and executes
