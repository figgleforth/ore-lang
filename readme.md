![Version](https://img.shields.io/badge/version-0.0.0-2B7FFF.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-2B7FFF.svg)
[![justforfunnoreally.dev badge](https://img.shields.io/badge/justforfunnoreally-dev-2B7FFF)](https://justforfunnoreally.dev)
![Status of project Ruby tests](https://github.com/figgleforth/ore-lang/actions/workflows/tests.yml/badge.svg)

Learn about the language below, or *[click here to get started using it](getting_started.md)*.

---

## Variables

1. Must start with a lowercase letter or `_`
2. Can be followed by comma as shorthand for `= nil`

```ore
nothing = nil
something = 123
empty,  # equivalent to `empty = nil`
```

## Functions

1. Must start with a lowercase letter or `_`
2. The function body is surrounded with `{}` braces
3. The arguments are declared before the arguments/body delimiter `;`
4. The body comes after the arguments/body delimiter `;`
5. The last expression is the return value
6. Return early using `return` keyword

```ore
# func_name { [args]; [body] }

func_with_args { arg1, arg2 = 1, etc = true;
    # body
}

without_args {;
    # body
}

add { a, b;
    a + b
}
add(4, 8)  #=> 12
```

## Classes

1. Must start with an uppercase character
2. Can have an initializer `new`

```ore
My_Class {
    input,
    
    new { input;
        .input = input  # .input is equivalent to this.input or self.input
        @puts 'Initted with "`input`"'
    }
}

instance = My_Class('some input')  #=> Initted with "some input"
```

## Constants

1. Must be UPPERCASE
2. Cannot be reassigned after initial declaration

```ore
PI = 3.14159
MAX_SIZE = 100
APP_NAME = 'My App'
```

## Comments

1. Single-line comments use `#`
2. Multiline comments use triple backticks

````ore
# This is a single-line comment

```
This is a
multiline comment
```
````

## String Interpolation

1. Use backticks inside strings to interpolate expressions
2. Escape with backslash to prevent interpolation

```ore
name = 'World'
greeting = "Hello, `name`!"  #=> "Hello, World!"
math = "2 + 2 = `2 + 2`"    #=> "2 + 2 = 4"
escaped = "Literal \`backticks\`"
```

## Scope Operators

1. `.` accesses current instance scope only
2. `./` accesses current type/class scope only
3. `../` accesses global scope

```ore
My_Class {
    ./count = 0      # Type-level (static) variable
    value,

    new { value;
        .value = value   # Instance variable (like this.value)
        ./count += 1     # Access static from instance
    }

    get_global {;
        ../PI  # Access global scope constants
    }
}
```

## Static Declarations

1. Use `./` to declare type-level (static) members
2. Shared across all instances
3. Accessed on the type itself: `Type.member`

```ore
Counter {
    ./count = 0

    ./increment {;
        count += 1
    }

    new {;
        ./count += 1
    }
}

Counter()
Counter()
Counter.count  #=> 2
```

## Type Composition

1. `|` union: merge all members from both types
2. `&` intersection: keep only shared members
3. `~` removal: remove members of right type from left
4. `^` symmetric difference: keep non-shared members

```ore
Movable {
    x = 0
    y = 0
    move { dx, dy;
        x += dx
        y += dy
    }
}

Drawable {
    color = 'black'
    draw {; "Drawing in `color`" }
}

# Combine types
Sprite | Movable | Drawable {
    name = 'sprite'
}

s = Sprite()
s.move(10, 5)
s.draw()
```

## Conditionals

1. `if`/`elif`/`else`/`end`
2. `unless` is the negation of `if`
3. Can be used as inline modifiers

```ore
if x > 10
    'big'
elif x > 5
    'medium'
else
    'small'
end

unless logged_in
    redirect('/login')
end

# Inline conditionals
@puts 'yes' if condition
@puts 'no' unless condition
```

## While & Until Loops

1. `while` loops while condition is true
2. `until` loops until condition becomes true
3. `elwhile` chains another loop when prior condition becomes false

```ore
i = 0
while i < 5
    @puts i
    i += 1
end

j = 0
until j == 5
    @puts j
    j += 1
end

# Chained loops with elwhile
x = 0
y = 0
while x < 4
    x += 1
elwhile y > -8
    y -= 1
else
    @puts 'done'
end
```

## For Loops

1. Iterate over arrays, ranges, or any iterable
2. `it` is the current element
3. `at` is the current index

```ore
for [1, 2, 3]
    @puts it      # Current element
    @puts at      # Current index
end

for 1..5
    @puts it      # 1, 2, 3, 4, 5
end

# With stride (chunks)
for [1, 2, 3, 4, 5, 6] by 2
    @puts it      # [1,2], [3,4], [5,6]
end
```

## For Loop Verbs

1. `map` transforms each element
2. `select` filters where body is truthy
3. `reject` filters where body is falsy
4. `count` counts where body is truthy

```ore
doubled = for [1, 2, 3] map
    it * 2
end  #=> [2, 4, 6]

evens = for [1, 2, 3, 4, 5] select
    it % 2 == 0
end  #=> [2, 4]

odds = for [1, 2, 3, 4, 5] reject
    it % 2 == 0
end  #=> [1, 3, 5]

even_count = for [1, 2, 3, 4, 5, 6] count
    it % 2 == 0
end  #=> 3
```

## Loop Control

1. `skip` continues to next iteration
2. `stop` breaks out of loop
3. `return` exits the function (propagates through loops)

```ore
for items
    skip if it.invalid    # Continue to next
    stop if it.last       # Break out
end

find_first { predicate;
    for items
        return it if predicate(it)
    end
    nil
}
```

## Sibling Scopes

Sibling scopes are checked before the current scope during identifier lookup, making an instance's members accessible without an `instance.` prefix.

1. `@param` in a function signature adds the argument to a sibling scope, making its members directly accessible in the function body
2. `@ += instance` and `@ -= instance` manually add and remove instances from sibling scopes in any scope

```ore
Vector {
    x = 0
    y = 0
}

# Auto-unpack in parameters
magnitude { @vec;
    (x ** 2 + y ** 2).sqrt()  # Access x, y directly
}

v = Vector()
v.x = 3
v.y = 4
magnitude(v)  #=> 5

# Manual sibling scope control
@ += some_instance   # Add members to scope
@ -= some_instance   # Remove from scope
```

## Arrays

1. Created with `[]` brackets
2. Access elements with subscript or dot notation

```ore
arr = [1, 2, 3, 4, 5]
arr[0]              #=> 1
arr.0               #=> 1 (dot notation)

arr.push(6)         # Add to end
arr.pop()           # Remove from end
arr.length()        #=> 5
arr.first(2)        #=> [1, 2]
arr.last(2)         #=> [4, 5]
arr.reverse()
arr.include?(3)     #=> true
arr.empty?()        #=> false

arr.map({ x; x * 2 })
arr.filter({ x; x > 2 })
```

## Dictionaries

1. Created with `{}` braces and key-value pairs
2. Keys can be symbols, strings, or identifiers
3. Access with subscript `dict[:key]`

```ore
dict = {x: 10, y: 20}
dict[:x]            #=> 10
dict[:z] = 30       # Assignment

dict.keys()         #=> [:x, :y, :z]
dict.values()       #=> [10, 20, 30]
dict.has_key?(:x)   #=> true
dict.count()        #=> 3
dict.empty?()       #=> false
dict.delete(:z)
dict.merge({a: 1})
dict.fetch(:missing, 'default')
```

## Strings

```ore
s = 'Hello, World!'
s.length            #=> 13
s.upcase()          #=> 'HELLO, WORLD!'
s.downcase()        #=> 'hello, world!'
s.split(', ')       #=> ['Hello', 'World!']
s.trim()            # Remove whitespace
s.chars()           #=> ['H', 'e', 'l', ...]
s.reverse()
s.include?('World') #=> true
s.start_with?('He') #=> true
s.end_with?('!')    #=> true
s.gsub('World', 'Ore')
s.to_i()            # Convert to integer
s.empty?()          #=> false
```

## Numbers

```ore
n = 42
n.abs()             # Absolute value
n.floor()           # Round down
n.ceil()            # Round up
n.round()           # Round to nearest
n.sqrt()            # Square root
n.even?()           #=> true
n.odd?()            #=> false
n.to_s()            #=> '42'
n.clamp(0, 100)     # Clamp to range
```

## Ranges

1. `..` inclusive range
2. `.<` exclusive end
3. `>.` exclusive start
4. `><` exclusive both

```ore
1..5        #=> 1, 2, 3, 4, 5  (inclusive)
1.< 5       #=> 1, 2, 3, 4     (exclusive end)
>. 1 5      #=> 2, 3, 4, 5     (exclusive start)
>< 1 5      #=> 2, 3, 4        (exclusive both)

for 1..10
    @puts it
end
```

## File I/O

```ore
@use 'ore/file_system.ore'

content = File_System.read('./file.txt')
File_System.write_string_to_file('./out.txt', 'Hello!')
```

## @use Directive

1. Imports another Ore file
2. Files are only loaded once

```ore
@use 'ore/string.ore'
@use 'ore/array.ore'
@use './my_module.ore'
```

## @puts Directive

```ore
@puts 'Hello, World!'
@puts variable
@puts "Value: `expression`"
```

## Web Server

1. Compose with `Server` type
2. Define routes with HTTP method syntax
3. Start with `@start` directive

```ore
@use 'ore/server.ore'

App | Server {
    new {;
        .port = 3000
    }

    get:// {;
        'Hello, World!'
    }

    get://about {;
        'About page'
    }
}

@start App()
```

## Routes

1. HTTP methods: `get://`, `post://`, `put://`, `delete://`, `patch://`
2. URL parameters with `:param` syntax
3. Query params via `request.query`

```ore
App | Server {
    # Static route
    get://users {;
        'All users'
    }

    # URL parameter
    get://users/:id { id;
        "User `id`"
    }

    # Multiple params
    get://posts/:post_id/comments/:id { post_id, id;
        "Comment `id` on post `post_id`"
    }

    # Query strings: /search?q=term
    get://search {;
        query = request.query[:q]
        "Searching for `query`"
    }
}
```

## Request & Response

```ore
post://login {;
    username = request.body[:username]
    password = request.body[:password]

    if authenticate(username, password)
        response.redirect('/dashboard')
    else
        response.status = 401
        'Unauthorized'
    end
}

get://api/data {;
    response.headers['Content-Type'] = 'application/json'
    '{"status": "ok"}'
}
```

## Database

1. Use `Sqlite` for SQLite databases
2. Connect with `@connect` directive

```ore
@use 'ore/database.ore'

db = Sqlite('./data/app.db')
@connect db

db.create_table('users', {
    id: 'primary_key',
    name: 'String',
    email: 'String'
})

db.table_exists?('users')  #=> true
db.tables()                #=> ['users']
db.delete_table('users')
```

## Record ORM

1. Compose with `Record` type
2. Set static `./database` and instance `table_name`

```ore
@use 'ore/record.ore'

User | Record {
    ./database = ../db
    table_name = 'users'
}

# CRUD operations
User.create({name: 'Alice', email: 'alice@example.com'})
users = User.all()        #=> Array of Dictionaries
user = User.find(1)       #=> Dictionary
User.delete(1)
```

## HTML Elements

1. Compose with HTML element types from `ore/html.ore`
2. `css_*` prefix sets inline CSS properties
3. `html_*` prefix sets HTML attributes

```ore
@use 'ore/html.ore'

Card | Div {
    css_padding = '1rem'
    css_border_radius = '8px'
    css_background_color = '#fff'

    html_class = 'card'
    html_data_value = 42
    html_aria_label,
}

Link | A {
    html_href = '#'
    html_target = '_blank'
}

page = Html([
    Head(Title('My Page'))
    Body([
        H1('Welcome')
        Card([
            P('Hello!')
            Link('Click me')
        ])
    ])
])
```

## Operators

### Arithmetic

```ore
+ - * / %     # Basic math
**            # Exponentiation
<< >>         # Bitwise shift / Array append
```

### Comparison

```ore
== !=         # Equality
=== !==       # Strict equality
< <= > >=     # Relational
<=>           # Spaceship (three-way)
=~ !~         # Regex match
```

### Logical

```ore
&& and        # Logical AND
|| or         # Logical OR
! not         # Logical NOT
```

### Assignment

```ore
=             # Basic assignment
+= -= *= /=   # Compound assignment
&&= ||=       # Logical compound
<<= >>=       # Shift compound
```

## Nil Initialization

1. Trailing comma declares variable as nil if undefined
2. Returns existing value if already defined

```ore
undefined_var,    #=> nil
undefined_var     #=> nil

existing = 42
existing,         #=> 42 (unchanged)
```
