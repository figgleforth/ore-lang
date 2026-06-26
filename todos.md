Options for better type checking
1. Runtime-first — already implemented
2. Two-pass — same structure as now, just split the walk in two
3. Dataflow / reaching definitions — requires tracking assignment chains through the walk
4. Hindley-Milner — full constraint-solving inference; most complex by far

Two-pass type checker might be the best next improvement:
Type_Checker currently does a single AST walk, so call sites above their function definition are never checked. Fix: first pass collects all Func_Expr signatures and typed variable declarations into @type_by_identifier, second pass does the existing error-checking walk. Same structure, just split output into two loops over @input.
---
Error handling
No way to catch runtime errors in Ore code — unhandled errors crash the program. Need a try/catch construct (or equivalent). Ore errors are Ruby exceptions under the hood, so the interpreter just needs to catch them and hand control to a user-defined handler block. Important for web routes, file I/O, and DB calls where failure is expected.
---
Varargs
---
Nil-safe access
`x.?method` should return nil if x is nil instead of raising
---
Tuple destructuring
Tuples exist but there's no destructuring assignment. Need `a, b = some_tuple` to unpack values into separate variables.
---
[bug] A tuple within a tuple has infinite members?
```ore
((), true).0.1
#<Ore::Tuple name="Array" declarations=["values"]>
((), true).0.2
#<Ore::Tuple name="Array" declarations=["values"]>
((), true).0.3
#<Ore::Tuple name="Array" declarations=["values"]>
((), true).0.4
#<Ore::Tuple name="Array" declarations=["values"]>
```
