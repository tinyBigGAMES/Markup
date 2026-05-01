<div align="center">

![Markup](../media/markup.png)

</div>

# Markup Language Specification v1.0

## 1. Overview

**Markup** is a document authoring language designed to replace writing HTML by
hand. It provides the expressiveness of HTML with a single, unified syntax. A
Markup document is converted to HTML by a conforming implementation.

### 1.1 Design Philosophy

- **One syntax, one rule.** Every construct — formatting, structure, and
  computation — follows the same `{tag ...}` pattern. There are no mode
  switches, no ambiguous parsing contexts, no special cases.
- **HTML-level expressiveness.** If you can build it in HTML, you can express
  it in Markup without writing HTML.
- **Turing-complete by design.** Variables, conditionals, iteration, and
  component definitions are first-class constructs using the same tag syntax.
  A single Markup document can be a static page, a data-driven template, or
  a reusable component library.
- **Unambiguous by design.** The grammar is strict and context-free. There is
  exactly one way to parse any valid Markup document.
- **HTML passthrough.** When raw HTML is genuinely needed, a clean escape
  hatch exists. The goal is that you rarely need it.

### 1.2 Goals and Non-Goals

**Goals:**
- Cover 95%+ of common HTML authoring needs without HTML
- Unify document formatting and template logic in one syntax
- Be trivially parseable with a single-pass recursive descent parser
- Produce clean, semantic HTML output
- Support external data binding for template use cases

**Non-Goals:**
- Replacing Markdown for ultra-simple plain-text notes
- Pixel-perfect layout control (that is CSS's job)
- Being a general-purpose programming language


## 2. Syntax

### 2.1 Core Rule

Every Markup construct follows one pattern:

```
{tag "content"}
```

Where:
- `{` opens a construct
- `tag` is a tag name (lowercase alphanumeric plus hyphen: `[a-z][a-z0-9-]*`)
- `"content"` is a quoted string containing the tag's text content
- `}` closes the construct
- Content may contain nested `{tag "..."}` constructs
- Whitespace outside of quoted strings is formatting — the lexer discards it

A construct with no content is valid: `{line}`, `{br}`.

**Content quoting rules:**
- Content strings are delimited by `"..."` 
- Nested tags inside content are recognized: `{p "Hello, {b "world"}!"}`
- `\"` produces a literal quote inside content
- Tags with only nested tags and no text need no quotes:
  `{list {item "One"} {item "Two"}}`
- Whitespace between tag name, attributes, and content is just token
  separation — the lexer discards it entirely

### 2.2 Attributes

Tags may have key-value attributes between the tag name and the content.

```
{tag attr1=value attr2="value with spaces" "content goes here"}
```

**Attribute rules:**
- Attribute names: `[a-z][a-z0-9-]*`
- Unquoted values: no spaces, no `}`, no `"`
- Quoted values: enclosed in `"..."`, supports `\"` for literal quote
- A bare `=` with no value is invalid
- Boolean attributes (no value): `{audio controls "song.mp3"}`
- Attributes end and content begins at the first `"` that is not part
  of a `key=value` pair

### 2.3 Inline vs Block Behavior

A tag is **inline** if its content string contains no newlines:
```
{p "This has {b "bold"} text."}
```

A tag is **block** if its content spans multiple lines:
```
{note "This is a block-level callout.
It spans multiple lines."}
```

The content determines the rendering context. However, certain tags
(`table`, `section`, `grid`, `list`, `olist`, `dlist`, `form`) are
**always block-level** regardless of content.

### 2.4 Escaping

- `\{` produces a literal `{`
- `\}` produces a literal `}`
- `\\` produces a literal `\`
- Inside `{code ...}` and `{html ...}` blocks, no escaping is performed.
  Content is consumed verbatim until the matching closing `}`. The parser
  tracks brace depth to find the true closing brace.

### 2.5 Content and Line Breaks

- Content inside quoted strings is preserved exactly as written
- A `{br}` tag forces a hard line break (`<br>`)
- Newlines within a content string are preserved in the output
- Whitespace outside of quoted strings and tag constructs is
  formatting and is discarded by the lexer

### 2.6 Text Escaping

Content inside quoted strings is HTML-escaped in output (`<`, `>`,
`&`, `"` are converted to entities). The `\"` escape produces a
literal quote within a content string.

### 2.7 String Interpolation

Inside content strings, `{=expr}` evaluates an expression and inserts
the result as text.

```
{let name "Alice"}
{p "Hello, {=name}! You have {=count({get items})} items."}
```

**Interpolation supports:**
- Simple variable references: `{=name}`
- Path expressions: `{=data.user.email}`
- Function calls: `{=upper(name)}`
- Expressions: `{=price * qty}`
- Pipes (see Section 4.3): `{=name | upper}`

`{=expr}` is syntactic sugar. The parser expands it to `{eval expr}`
before evaluation. Inside `{code}` and `{html}` blocks, interpolation
is NOT processed (content is verbatim).

### 2.8 Whitespace Rules

Whitespace outside of quoted strings is **formatting** — the lexer
discards it. This means indentation, blank lines between tags, and
newlines after closing braces produce no output.

Only text inside `"..."` content strings is preserved in the output.
This eliminates the need for trim markers or whitespace hacks.

### 2.9 Comments

```
{-- This is a comment and produces no output --}
```

Comments may span multiple lines. They do not nest.


## 3. Formatting Tags

Markup uses short, purpose-driven tag names. The compiler maps them
to semantic HTML elements during rendering.

### 3.1 Text Formatting (Inline)

| Markup Tag | HTML Output                          | Description   |
|------------|--------------------------------------|---------------|
| `b`        | `<strong>text</strong>`              | Bold          |
| `i`        | `<em>text</em>`                      | Italic        |
| `u`        | `<u>text</u>`                        | Underline     |
| `s`        | `<s>text</s>`                        | Strikethrough |
| `sub`      | `<sub>text</sub>`                    | Subscript     |
| `sup`      | `<sup>text</sup>`                    | Superscript   |
| `mark`     | `<mark>text</mark>`                  | Highlight     |
| `small`    | `<small>text</small>`                | Small text    |
| `abbr`     | `<abbr title="...">text</abbr>`     | Abbreviation  |
| `code`     | `<code>text</code>`                  | Inline code   |
| `kbd`      | `<kbd>text</kbd>`                    | Keyboard input|
| `q`        | `<q>text</q>`                        | Inline quote  |
| `cite`     | `<cite>text</cite>`                  | Citation      |
| `time`     | `<time datetime="...">text</time>`   | Date/time     |

### 3.2 Headings

```
{h1 "Main Title"}
{h2 "Section Title"}
{h3 "Subsection"}
{h4 "Sub-subsection"}
{h5 "Minor heading"}
{h6 "Smallest heading"}
```

Headings support `id` and `class` attributes:
```
{h2 id=features "Features"}
```

### 3.3 Links and Media

**Links:**
```
{link "https://example.com" "Link text here"}
{link title="About us" "/about" "About"}
{link "#section" "Jump to section"}
```

**Images (void tag — no content):**
```
{img "photo.jpg" "A description"}
{img width=800 height=600 "photo.jpg" "Description"}
```

**Figure with caption:**
```
{fig
  {img "diagram.png" "Architecture"}
  {caption "System architecture as of v2.3"}
}
```

**Audio and video:**
```
{audio controls "song.mp3"}
{video controls width=640 "demo.mp4"}
```

### 3.4 Lists

**Unordered list:**
```
{list
  {item "First item"}
  {item "Second item"}
  {item "Third with {b "bold"} text"}
}
```

**Ordered list:**
```
{olist
  {item "Step one"}
  {item "Step two"}
}
```

**Nested lists:**
```
{list
  {item "Item one"}
  {item "Item two"
    {list
      {item "Nested A"}
      {item "Nested B"}
    }
  }
}
```

**Description list:**
```
{dlist
  {term "Term"}
  {desc "Definition of the term."}
}
```

### 3.5 Tables

**Full structured syntax:**
```
{table
  {thead
    {row
      {hcol "Name"}
      {hcol "Role"}
    }
  }
  {tbody
    {row
      {col "Alice"}
      {col "Engineer"}
    }
  }
}
```

**Shorthand pipe syntax:**
```
{table caption="Team Roster"
| Name  | Role     |
| Alice | Engineer |
| Bob   | Designer |
}
```

In shorthand mode, the first row becomes `<thead>`, remaining rows become
`<tbody>`. The parser activates shorthand mode when the tag content begins
with `|`.

Table-level attributes: `caption`, `id`, `class`.

### 3.6 Code Blocks

**Inline code:**
```
{p "Use the {code print()} function."}
```

**Block code with language hint:**
```
{code lang=delphi
procedure TFoo.Bar();
begin
  WriteLn('hello');
end;
}
```

Output: `<pre><code class="language-delphi">...</code></pre>`

Inside `{code ...}`, content is **verbatim** — no tag parsing, no escaping.
The parser tracks brace nesting depth to find the true closing `}`.

### 3.7 Semantic Sections

| Markup Tag   | HTML Output                |
|--------------|----------------------------|
| `section`    | `<section>...</section>`   |
| `article`    | `<article>...</article>`   |
| `aside`      | `<aside>...</aside>`       |
| `header`     | `<header>...</header>`     |
| `footer`     | `<footer>...</footer>`     |
| `nav`        | `<nav>...</nav>`           |
| `main`       | `<main>...</main>`         |
| `box`        | `<div>...</div>`           |
| `span`       | `<span>...</span>`         |

All support `id` and `class` attributes.

### 3.8 Block Quotation

```
{quote
  "To be or not to be, that is the question."
  {footer {cite "William Shakespeare"}}
}
```

### 3.9 Interactive / Disclosure

```
{details summary="Click to expand"
  "Hidden content here. Supports {b "any"} Markup constructs."
}
```

### 3.10 Callouts / Admonitions

```
{note "This is informational."}
{tip "A helpful suggestion."}
{warning "Be careful with this."}
{danger "This is critical."}
```

### 3.11 Void Tags

| Markup Tag | HTML Output  |
|------------|--------------|
| `line`     | `<hr />`     |
| `br`       | `<br />`     |
| `img`      | `<img ... />`|
| `input`    | `<input .../>`|

### 3.12 Forms

```
{form method=post "/submit"
  {label for=username "Username:"}
  {input type=text id=username placeholder="Enter name"}

  {label for=bio "Bio:"}
  {textarea id=bio "Default text here"}

  {select id=role
    {option value=dev "Developer"}
    {option value=mgr "Manager"}
    {option value=qa selected "QA"}
  }

  {button type=submit "Submit"}
}
```

### 3.13 Layout Helpers

These produce `<div>`-based structures with semantic classes:

**Grid:**
```
{grid cols=3 gap=16
  {cell "Content A"}
  {cell "Content B"}
  {cell "Content C"}
}
```

**Card:**
```
{card
  {h3 "Title"}
  "Body text here."
}
```

**Columns:**
```
{columns
  {column "Left content"}
  {column "Right content"}
}
```

Layout helpers are syntactic sugar. Implementations MUST document the exact
HTML and CSS class names they produce.


## 4. Computation Tags

Computation tags use the same `{tag ...}` syntax as formatting tags. They
evaluate expressions, bind variables, control flow, and define reusable
components. A conforming implementation MUST support all computation tags
defined in this section.

### 4.1 Variables

**Binding:**
```
{let name "value"}
{let version "2.1.0"}
{let greeting "Hello, world"}
{let count {eval 5 + 3}}
```

`{let}` binds a name to a value in the current scope. If the value
is a quoted string, it is stored as-is. If the value is a single
`{eval ...}` expression, it is evaluated.

**Reference:**
```
{get name}
{get data.user.email}
{get items[0].title}
```

`{get}` resolves a name from the current scope, walking up parent scopes
if not found locally. Dot notation accesses map fields. Bracket notation
accesses list indices. If the path cannot be resolved, the result is an
empty string (no error).

**Assignment:**
```
{set name "newvalue"}
{set count {eval {get count} + 1}}
```

`{set}` updates an existing variable in the nearest enclosing scope where
it is defined. If the variable does not exist, behavior is implementation-
defined (implementations SHOULD create it in the current scope).

### 4.2 Expressions

The `{eval ...}` tag evaluates an expression and produces its result as
a string. Expressions support:

**Arithmetic:** `+`, `-`, `*`, `/`, `%`
**Comparison:** `==`, `!=`, `<`, `>`, `<=`, `>=`
**Logical:** `and`, `or`, `not`
**Grouping:** `(`, `)`
**String concatenation:** `+` when either operand is a string

```
{eval 5 + 3}                    → 8
{eval {get price} * {get qty}}  → computed value
{eval {get name} + " Jr."}     → string concatenation
```

Values referenced inside `{eval}` via `{get}` resolve normally through
the scope chain.

### 4.3 Filters (Pipe Syntax)

Filters transform values using a pipe (`|`) operator. Pipes chain
left-to-right, passing the result of each step as the first argument
to the next function.

```
{=name | upper}
{=name | lower | trim}
{=price | round | toStr}
{=items | sort | reverse}
{=data.bio | escape | nl2br}
```

**Pipe with arguments:**
```
{=name | substr(0, 10)}
{=items | join(", ")}
{=price | toStr | replace(".", ",")}
```

When a piped function takes additional arguments, the piped value is
always the first argument. `{=x | substr(0, 10)}` is equivalent to
`{eval substr({get x}, 0, 10)}`.

**Pipes in `{eval}`:**
```
{eval {get name} | upper}
{eval {get price} * {get qty} | round}
```

Pipes bind with lowest precedence. `{eval a * b | round}` means
`round(a * b)`, not `a * round(b)`.

**Pipes in `{if}` and `{each}`:**
```
{if {get name} | len | gt(0)
  "Name is not empty."
}
{each {get items} | sort item
  {p "{=item}"}
}
```

Filters are syntactic sugar for function calls. Any built-in function
or registered custom function can be used as a filter. Implementations
MUST support pipes in `{eval}`, `{=}`, `{if}`, and `{each}` contexts.

### 4.4 Conditionals

```
{if {expr}
  "Content when true."
}

{if {expr}
  "Content when true."
{else}
  "Content when false."
}

{if {expr1}
  "First branch."
{elseif {expr2}}
  "Second branch."
{else}
  "Default branch."
}
```

The condition expression is any value. The following are **falsy**: empty
string, integer `0`, float `0.0`, boolean `false`, nil, empty list, empty
map. Everything else is **truthy**.

**Parsing rule for `{else}` and `{elseif}`:** These are **branch
delimiters** recognized by the parser ONLY inside an `{if}` body. They
are not independent tags. When the parser is collecting content inside
an `{if}` block, encountering `{else}` or `{elseif` at the current
brace depth signals a branch boundary. The parser splits the `{if}`
node's children into branch groups accordingly. Outside of an `{if}`
body, `{else}` and `{elseif}` are parse errors.

### 4.5 Iteration

**Iterating over a list:**
```
{each {get items} item
  {p "{get item.name} — {get item.role}"}
}
```

`{each}` takes a list expression, a binding name, and a body. For each
element in the list, it binds the element to the given name in a new child
scope, then evaluates the body.

**Loop variables:** Inside an `{each}` body, the following implicit
variables are available:

| Variable     | Description                          |
|--------------|--------------------------------------|
| `loop.index` | Zero-based index of current item     |
| `loop.count` | One-based index of current item      |
| `loop.first` | `true` if this is the first item     |
| `loop.last`  | `true` if this is the last item      |
| `loop.length`| Total number of items in the list    |

**Iterating over a map:**
```
{each {get headers} key value
  {p "{=key}: {=value}"}
}
```

When two binding names are provided and the source is a map, the first
binds to the key and the second to the value.

### 4.6 Component Definitions

Components allow defining reusable document fragments.

**Defining a component:**
```
{def card icon title body
  {box class=card
    {box class=card-header
      {span class=icon "{=icon}"} {h3 "{=title}"}
    }
    {box class=card-body "{=body}"}
  }
}
```

`{def}` takes a name, a parameter list, and a body. Parameters become
local variables within the component body when it is invoked.

**Parameter defaults:**
```
{def card icon="star" title="Untitled" body
  ...
}
```

Parameters with `=value` are optional and use the specified default when
not provided by the caller. Parameters without defaults are required.
Required parameters MUST appear before optional parameters in the
definition (the last parameter may be required as it receives block content).

**Invoking a component:**
```
{call card icon=rocket title="Fast" body="Built for speed."}
{call card title="Simple"}
```

`{call}` looks up the named component, creates a new scope, binds
the provided attributes to the parameter names (using defaults for
any omitted optional parameters), and evaluates the body.

**Block content passing:**
```
{call card icon=star title="Fast"
  "This entire block is passed as the {b "body"} parameter."
}
```

When a `{call}` has content after the attributes, that content is
bound to the last declared parameter of the component.

**Nested component definitions:**
Components may define local sub-components:
```
{def page title
  {def sidebar
    {nav "{=links}"}
  }
  {h1 "{=title}"}
  {call sidebar}
}
```

Sub-components are scoped to their parent — they are not visible outside.

### 4.7 Includes

The `{include}` tag inserts the contents of another Markup file at the
point of inclusion. This enables composing documents from reusable
partials.

```
{include "header.mu"}

{h1 "Page Title"}
{p "Page content here."}

{include "footer.mu"}
```

**Include with data:**
```
{include "user-card.mu" user={get data.currentUser}}
```

Attributes on `{include}` are bound as local variables in the included
file's scope. This allows partials to receive parameters without relying
on global state.

**Include resolution:** File paths are relative to the including
document's location. Implementations MUST support relative paths and
SHOULD support configurable search paths. Implementations MUST detect
and report circular includes as errors.

**Include vs component:** `{include}` loads an external file.
`{def}`/`{call}` defines and invokes inline components within the same
document. Both create isolated scopes. Use `{include}` for shared
partials across documents; use `{def}`/`{call}` for reuse within a
single document.

### 4.8 Built-in Functions

Built-in functions are invoked within `{eval}` expressions or as
filters in pipe chains:

```
{eval upper({get name})}
{eval len({get items})}
```

**String functions:**

| Function                    | Description                       |
|-----------------------------|-----------------------------------|
| `upper(s)`                  | Uppercase                         |
| `lower(s)`                  | Lowercase                         |
| `trim(s)`                   | Strip leading/trailing whitespace |
| `len(s)`                    | String length (or list length)    |
| `substr(s, start, length)`  | Substring (zero-based)            |
| `replace(s, find, repl)`    | Replace all occurrences           |
| `split(s, delimiter)`       | Split string into list            |
| `join(list, delimiter)`     | Join list into string             |
| `startsWith(s, prefix)`     | Test prefix                       |
| `endsWith(s, suffix)`       | Test suffix                       |
| `contains(s, sub)`          | Test containment                  |

**Math functions:**

| Function       | Description     |
|----------------|-----------------|
| `round(n)`     | Round to nearest integer |
| `floor(n)`     | Round down      |
| `ceil(n)`      | Round up        |
| `abs(n)`       | Absolute value  |
| `min(a, b)`    | Minimum         |
| `max(a, b)`    | Maximum         |

**Collection functions:**

| Function            | Description                          |
|---------------------|--------------------------------------|
| `count(list)`       | Number of items (alias for `len`)    |
| `first(list)`       | First item                           |
| `last(list)`        | Last item                            |
| `index(list, n)`    | Item at index n                      |
| `range(start, end)` | Generate list of integers            |
| `sort(list)`        | Sort (natural order)                 |
| `reverse(list)`     | Reverse a list                       |
| `keys(map)`         | List of map keys                     |
| `values(map)`       | List of map values                   |

**Type functions:**

| Function      | Description                          |
|---------------|--------------------------------------|
| `typeof(v)`   | Returns type name as string          |
| `toStr(v)`    | Convert to string                    |
| `toInt(s)`    | Parse integer from string            |
| `toFloat(s)`  | Parse float from string              |

**HTML functions:**

| Function      | Description                          |
|---------------|--------------------------------------|
| `escape(s)`   | HTML-escape a string                 |
| `raw(s)`      | Mark string as safe (no escaping)    |
| `nl2br(s)`    | Convert newlines to `<br>` tags      |

**Comparison functions (for use in pipes):**

| Function       | Description                         |
|----------------|-------------------------------------|
| `eq(a, b)`     | Equal                               |
| `neq(a, b)`    | Not equal                           |
| `gt(a, b)`     | Greater than                        |
| `lt(a, b)`     | Less than                           |
| `gte(a, b)`    | Greater than or equal               |
| `lte(a, b)`    | Less than or equal                  |

When used as a pipe filter with one argument, the piped value becomes
the first argument: `{=age | gt(18)}` → `gt(age, 18)`.

**Date/time functions:**

| Function             | Description                        |
|----------------------|------------------------------------|
| `now()`              | Current date/time as string        |
| `formatDate(s, fmt)` | Format a date string               |

Implementations MAY provide additional built-in functions but MUST support
all functions listed above.


## 5. Data Binding

A conforming implementation MUST support rendering a parsed document
against an external data source. The data source is a tree of maps, lists,
and scalar values (strings, integers, floats, booleans, nil).

### 5.1 Data Access

External data is accessed through `{get}` with the `data` root:

```
{get data.title}
{get data.user.name}
{get data.items[0].price}
```

The `data` prefix is a reserved root name. When a document is rendered
with external data, `data` is bound in the root scope before evaluation
begins.

### 5.2 Path Resolution

Dot notation traverses map fields: `data.user.name` resolves field `user`
on the data root, then field `name` on the result.

Bracket notation accesses list indices: `data.items[0]` resolves field
`items` on the data root, then index `0` on the resulting list.

If any step in the path fails (missing key, out-of-bounds index, wrong
type), the result is an empty string. No error is raised. This allows
templates to be defensive without explicit conditionals.

### 5.3 Data Types

| Type    | Description                              |
|---------|------------------------------------------|
| String  | UTF-8 text                               |
| Integer | 64-bit signed integer                    |
| Float   | 64-bit IEEE 754 double                   |
| Boolean | `true` or `false`                        |
| Nil     | Absence of value                         |
| List    | Ordered sequence of values               |
| Map     | String-keyed collection of values        |

Implementations that accept external data as JSON MUST map JSON types
to Markup types as follows: JSON string → String, JSON number (integer)
→ Integer, JSON number (fractional) → Float, JSON boolean → Boolean,
JSON null → Nil, JSON array → List, JSON object → Map.


## 6. Metadata

```
{meta title="My Document" author="Alice" lang=en}
```

`{meta}` tags do not produce visible HTML output. They declare document-
level metadata that conforming implementations MUST make available through
their API. Multiple `{meta}` tags are merged; later declarations override
earlier ones for the same key.

A `{meta}` tag MUST appear before any content-producing tags. Implementations
MAY ignore `{meta}` tags that appear after content.


## 7. Raw HTML Passthrough

```
{html
  <canvas id="myCanvas" width="400" height="300"></canvas>
  <script>
    var ctx = document.getElementById('myCanvas').getContext('2d');
  </script>
}
```

Content inside `{html ...}` is passed through verbatim to the output.
No tag parsing or escaping is performed. The parser tracks brace depth
to find the true closing brace.

Implementations MAY provide an option to disable HTML passthrough for
security-sensitive contexts (e.g., processing untrusted input).


## 8. Nesting Rules

### 8.1 Valid Nesting

Any inline tag may nest inside any other inline or block tag:
```
{b {i "bold and italic"}}
{item "Item with {link to="/page" "a link"} in it"}
```

Block tags may nest inside other block tags:
```
{section
  {h2 "Title"}
  {note "This is inside a section."}
}
```

Computation tags may nest inside any context and may contain any tags:
```
{if {get show_header}
  {h1 "{=data.title}"}
}
```

### 8.2 Invalid Nesting

- Headings (`h1`–`h6`) MUST NOT contain block-level tags
- `{code ...}` and `{html ...}` MUST NOT contain Markup tags (verbatim)
- Void tags (`{img}`, `{line}`, `{br}`, `{input}`) have no content body
- `{meta}` MUST NOT contain nested tags

### 8.3 Brace Matching

The parser uses a depth counter for brace matching. Every `{` increments
depth; every `}` decrements it. A construct closes when depth returns to
zero. Inside `{code ...}` and `{html ...}`, braces are counted but not
parsed, ensuring `}` characters in code do not prematurely close the block.


## 9. Execution Limits

Because Markup is Turing-complete, conforming implementations MUST enforce
execution limits to prevent runaway computation:

| Limit                | Minimum Default | Description                     |
|----------------------|-----------------|---------------------------------|
| Max iterations       | 10,000          | Per `{each}` loop               |
| Max recursion depth  | 100             | Nested `{call}` invocations     |
| Max output size      | 10 MB           | Total HTML output               |

When a limit is exceeded, the implementation MUST stop execution and
report an error. Implementations SHOULD allow these limits to be
configured.

Implementations MUST terminate computation cleanly on limit violation —
partial output up to the violation point is acceptable, but the
implementation MUST NOT hang or crash.


## 10. Error Handling

### 10.1 Principles

- **Fail gracefully, never silently.** Malformed input should produce
  reasonable output and reportable errors, not garbage.
- **Unrecognized tags** produce implementation-defined output.
  Implementations SHOULD either pass them through as escaped text or
  wrap them in a neutral container (e.g., `<span class="mu-unknown">`).
- **Unclosed braces** at end of input: close all open constructs
  implicitly and report a warning.
- **Empty tags** like `{b}` produce an empty element: `<strong></strong>`.
- **Type errors** in expressions (e.g., adding a string to a list)
  produce an empty value and a reported error.
- **Undefined variables** in `{get}` produce an empty string.

### 10.2 Error Information

Errors MUST include:
- Source position (line and column)
- Error severity (error, warning)
- Human-readable message
- Error code for programmatic handling


## 11. Formal Grammar

```
document       ::= (element | WHITESPACE)*
element        ::= tag | comment | interpolation

tag            ::= '{' TAGNAME attributes? content? '}'
attributes     ::= attribute+
attribute      ::= ATTRNAME '=' ATTRVALUE
                 | ATTRNAME
content        ::= STRING
                 | element+
                 | STRING (element STRING?)*

STRING         ::= '"' string_body '"'
string_body    ::= (string_char | element)*
string_char    ::= [^"\\{] | '\\' . 
                   -- any char except ", \, { OR an escaped char

interpolation  ::= '{=' expression pipe_chain? '}'
pipe_chain     ::= ('|' IDENT ('(' arg_list? ')')? )+
arg_list       ::= expression (',' expression)*

comment        ::= '{--' comment_body '--}'
comment_body   ::= (. - '--}')*

escape         ::= '\{' | '\}' | '\\'

WHITESPACE     ::= [ \t\r\n]+   -- discarded by lexer
TAGNAME        ::= [a-z][a-z0-9-]*
ATTRNAME       ::= [a-z][a-z0-9-]*
ATTRVALUE      ::= QUOTED_STRING | BARE_WORD
BARE_WORD      ::= [^\s}"]+
QUOTED_STRING  ::= '"' ([^"\\] | '\\' .)* '"'
```

### 11.1 Computation Grammar Extensions

```
let_tag        ::= '{let' IDENT (STRING | tag) '}'
get_tag        ::= '{get' PATH pipe_chain? '}'
set_tag        ::= '{set' IDENT (STRING | tag) '}'
eval_tag       ::= '{eval' expression pipe_chain? '}'
if_tag         ::= '{if' tag_expr pipe_chain? content
                    ('{elseif' tag_expr '}' content)*
                    ('{else}' content)?
                    '}'
each_tag       ::= '{each' tag_expr pipe_chain?
                    IDENT IDENT? content '}'
def_tag        ::= '{def' IDENT param_list content '}'
param_list     ::= param+
param          ::= IDENT ('=' ATTRVALUE)?
call_tag       ::= '{call' IDENT attributes? content? '}'
include_tag    ::= '{include' STRING attributes? '}'

tag_expr       ::= tag
expression     ::= expr_pipe
expr_pipe      ::= expr_or pipe_chain?
expr_or        ::= expr_and ('or' expr_and)*
expr_and       ::= expr_cmp ('and' expr_cmp)*
expr_cmp       ::= expr_add (('==' | '!=' | '<' | '>' | '<=' | '>=')
                   expr_add)*
expr_add       ::= expr_mul (('+' | '-') expr_mul)*
expr_mul       ::= expr_unary (('*' | '/' | '%') expr_unary)*
expr_unary     ::= 'not' expr_unary | expr_primary
expr_primary   ::= NUMBER | STRING | 'true' | 'false' | 'nil'
                 | IDENT '(' (expression (',' expression)*)? ')'
                 | get_tag
                 | '(' expression ')'

PATH           ::= IDENT ('.' IDENT | '[' NUMBER ']')*
IDENT          ::= [a-zA-Z_][a-zA-Z0-9_]*
NUMBER         ::= [0-9]+ ('.' [0-9]+)?
STRING         ::= '"' ([^"\\] | '\\' .)* '"'
```

### 11.2 Operator Precedence (lowest to highest)

| Precedence | Operators         | Associativity |
|------------|-------------------|---------------|
| 1          | `\|` (pipe)       | Left          |
| 2          | `or`              | Left          |
| 3          | `and`             | Left          |
| 4          | `==` `!=`         | Left          |
| 5          | `<` `>` `<=` `>=` | Left          |
| 6          | `+` `-`           | Left          |
| 7          | `*` `/` `%`       | Left          |
| 8          | `not` (unary)     | Right         |
| 9          | `()` (call)       | Left          |


## 12. Conformance

A conforming implementation:

1. MUST parse all constructs defined in Sections 2–4
2. MUST produce semantically correct HTML for all formatting tags (Section 3)
3. MUST evaluate all computation tags (Section 4)
4. MUST support string interpolation `{=expr}` (Section 2.7)
5. MUST support filter/pipe syntax (Section 4.3)
6. MUST support component definitions with defaults (Section 4.6)
7. MUST support file includes (Section 4.7)
8. MUST support external data binding (Section 5)
9. MUST enforce execution limits (Section 9)
10. MUST report errors with position information (Section 10)
11. MUST HTML-escape plain text in output
12. MUST support the `{html}` passthrough mechanism (Section 7)
13. SHOULD support whitespace trim markers (Section 2.8)
14. MAY provide additional built-in functions beyond those listed
15. MAY provide additional tags beyond those listed
16. MUST document any extensions or deviations from this specification


## 13. Design Rationale

### 13.1 Why Not Markdown?

- Ambiguous parsing (emphasis, lists, nesting edge cases)
- No standard spec (CommonMark is a retrofit, many flavors remain)
- Limited expressiveness — HTML required for anything non-trivial
- Extensions are incompatible across implementations
- No computation model — separate template engine always needed

### 13.2 Why Not BBCode?

- Closing tags add noise: `[b]text[/b]` vs `{b text}`
- Square brackets conflict with other syntaxes in mixed contexts
- No standardized attribute syntax
- No computation model

### 13.3 Why Not HTML Directly?

- Too verbose for human authoring
- Easy to produce invalid HTML (unclosed tags, bad nesting)
- Not designed for humans to write at scale
- Template engines (Jinja, Handlebars, Liquid) bolt computation on top
  with a second, incompatible syntax

### 13.4 Why Curly Braces?

- Rare in natural language text (unlike `<`, `>`, `[`, `]`, `*`, `#`)
- Visually distinct — easy to spot construct boundaries
- Supported in all text encodings
- No closing tag needed — the brace itself is the delimiter

### 13.5 Why Turing-Complete?

- Eliminates the need for a separate template engine
- A single document can be static, a template, or a component library
- Components (`{def}`/`{call}`) enable reuse without external tooling
- Data binding is a natural extension of the same syntax
- Execution limits prevent the theoretical risks of unbounded computation

The closest prior art is LaTeX (Turing-complete but hostile syntax, targets
PDF), XSLT (Turing-complete but XML verbosity), and Typst (scripting +
typesetting, targets PDF). No existing system unifies HTML document
authoring and computation in a single, clean syntax.

