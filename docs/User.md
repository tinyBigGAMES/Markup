<div align="center">

![Markup](../media/markup.png)

</div>

# Markup User Guide

This guide covers how to use the Markup DLL API in your applications. For the language syntax, see [Specs.md](Specs.md). For the complete function reference, see [API.md](API.md).

## Table of Contents

- [UTF-8 Helpers](#utf-8-helpers)
- [Quick Start](#quick-start)
- [One-Shot Conversion](#one-shot-conversion)
- [Parse Once, Render Many](#parse-once-render-many)
- [Convert to File](#convert-to-file)
- [Data Binding](#data-binding)
- [Engine Options](#engine-options)
- [Custom Tags](#custom-tags)
- [Custom Functions](#custom-functions)
- [Error Handling](#error-handling)
- [Include Paths](#include-paths)
- [Memory Management](#memory-management)
- [String Contract](#string-contract)
- [Thread Safety](#thread-safety)
- [C/C++ Quick Start](#cc-quick-start)

---

## UTF-8 Helpers

All strings crossing the DLL boundary are null-terminated UTF-8. Two small helpers make this painless:

```delphi
function Utf8(const AStr: string): PAnsiChar; inline;
begin
  Result := PAnsiChar(UTF8Encode(AStr));
end;

function FromUtf8(const APtr: PAnsiChar): string; inline;
begin
  if APtr = nil then
    Result := ''
  else
    Result := string(UTF8String(APtr));
end;
```

Use `Utf8()` when passing strings to the DLL. Use `FromUtf8()` when reading strings back.

## Quick Start

The simplest possible usage: create an engine, convert Markup source to HTML, use the result, free everything.

```delphi
var
  LEngine: TMuEngine;
  LHtml: PAnsiChar;
begin
  LEngine := markup_create();
  try
    LHtml := markup_convert(LEngine,
      Utf8('{h1 "Hello, Markup!"}{p "This is rendered HTML."}'),
      nil);
    try
      WriteLn(FromUtf8(LHtml));
    finally
      markup_free(LHtml);
    end;
  finally
    markup_destroy(LEngine);
  end;
end;
```

Output:

```html
<h1>Hello, Markup!</h1><p>This is rendered HTML.</p>
```

## One-Shot Conversion

`markup_convert` parses and renders in a single call. Pass the Markup source as the second argument and optional JSON data as the third. Pass `nil` for the data argument when no data binding is needed.

```delphi
LHtml := markup_convert(LEngine,
  Utf8('{p "Welcome, {=data.name}!"}'),
  Utf8('{"name": "Alice"}'));
try
  WriteLn(FromUtf8(LHtml));
finally
  markup_free(LHtml);
end;
```

This is the right choice for simple, fire-and-forget conversions. For templates rendered repeatedly with different data, use the parse-once pattern below.

## Parse Once, Render Many

When the same template is rendered multiple times with different data, parse it once and render it as many times as needed. This avoids re-parsing the source each time.

```delphi
var
  LEngine: TMuEngine;
  LDoc: TMuDoc;
  LHtml: PAnsiChar;
begin
  LEngine := markup_create();
  try
    LDoc := markup_parse(LEngine,
      Utf8('{p "Dear {=data.name}, your plan is {=data.plan}."}'));
    try
      // Render with first dataset
      LHtml := markup_render(LEngine, LDoc,
        Utf8('{"name": "Bob", "plan": "Pro"}'));
      try
        WriteLn(FromUtf8(LHtml));
      finally
        markup_free(LHtml);
      end;

      // Render with second dataset
      LHtml := markup_render(LEngine, LDoc,
        Utf8('{"name": "Carol", "plan": "Starter"}'));
      try
        WriteLn(FromUtf8(LHtml));
      finally
        markup_free(LHtml);
      end;
    finally
      markup_doc_destroy(LDoc);
    end;
  finally
    markup_destroy(LEngine);
  end;
end;
```

## Convert to File

`markup_convert_to_file` renders Markup source directly to an `.html` file on disk. The output filename is forced to a `.html` extension, and parent directories are created automatically if they do not exist. Pass `True` for the last argument to open the file in the default browser after writing.

```delphi
var
  LEngine: TMuEngine;
  LSuccess: Boolean;
begin
  LEngine := markup_create();
  try
    LSuccess := markup_convert_to_file(LEngine,
      Utf8('{h1 "Report"}{p "Generated on {=data.date}."}'),
      Utf8('{"date": "2026-01-15"}'),
      Utf8('output\report'),
      True);  // opens in default browser

    if not LSuccess then
      WriteLn('Failed to write file.');
  finally
    markup_destroy(LEngine);
  end;
end;
```

This is useful for generating reports, previewing templates during development, or producing static HTML deliverables.

## Data Binding

Pass a JSON string as the data argument to `markup_convert` or `markup_render`. Inside Markup source, access data values through the `data.*` path using the `{=...}` interpolation syntax.

**Scalar values:**

```
{p "Name: {=data.name}"}
{p "Age: {=data.age}"}
```

**Nested objects:**

```
{p "{=data.user.address.city}"}
```

**Arrays with `{each}`:**

```
{each {get data.items} item
  {p "{=item.name}: ${=item.price}"}
}
```

Inside an `{each}` loop, `loop.count` gives the 1-based iteration index.

## Engine Options

The engine exposes several configurable options via the `markup_set_*` functions. Set these after creating the engine and before parsing or rendering.

### Pretty Print

Enables formatted HTML output with newlines and 2-space indentation for block-level elements (`div`, `p`, `section`, `h1`–`h6`, `table`, `ul`, `ol`, etc.). Inline tags remain on the same line. Disabled by default.

```delphi
markup_set_pretty_print(LEngine, True);

LHtml := markup_convert(LEngine,
  Utf8('{div {p "Hello"}{p "World"}}'), nil);
// Output (with pretty print):
//   <div>
//     <p>Hello</p>
//     <p>World</p>
//   </div>
```

### Strict Mode

When enabled, the interpreter reports errors for undefined variables (via `{get}`) and unknown tags instead of silently producing empty values or escaping. Useful during development to catch typos and missing data. Disabled by default.

```delphi
markup_set_strict_mode(LEngine, True);

// This will now produce an error instead of empty output:
LHtml := markup_convert(LEngine,
  Utf8('{p "{=data.missingField}"}'), nil);
```

### Allow HTML

Controls whether the `{html}` tag passes content through raw or HTML-escapes it. Set to `False` in security-sensitive contexts where untrusted input may contain malicious HTML or script injection. Enabled by default.

```delphi
// Disable raw HTML passthrough for user-generated content
markup_set_allow_html(LEngine, False);

// {html "<script>alert('xss')</script>"} now outputs escaped text
// instead of a live script tag
```

### Unknown Tag Behavior

Controls how tags that are neither built-in Markup tags nor standard HTML elements are handled. The default behavior (0) escapes unknown tags as text. Setting it to 1 wraps them in a `<span class="mu-unknown">` element instead.

```delphi
// 0 = escape (default): unknown tags render as escaped text
// 1 = passthrough: unknown tags wrap in <span class="mu-unknown">
markup_set_unknown_tag_behavior(LEngine, 1);
```

### Safety Limits

Three safety limits prevent runaway templates from exhausting system resources:

**Maximum iterations** — caps the total number of loop iterations per render pass. Defaults to 10,000.

```delphi
markup_set_max_iterations(LEngine, 5000);
```

**Maximum recursion** — caps the recursion depth for component calls and nested rendering. Defaults to 100.

```delphi
markup_set_max_recursion(LEngine, 50);
```

**Maximum output size** — caps the output buffer size in bytes. Defaults to 10 MB.

```delphi
markup_set_max_output_size(LEngine, 1024 * 1024); // 1 MB limit
```

When any limit is exceeded, the interpreter adds an error and stops the offending operation. Use `markup_last_errors` or the error handler callback to inspect the diagnostic.

### Combined Example

A typical production setup applying several options at once:

```delphi
LEngine := markup_create();
try
  markup_set_pretty_print(LEngine, True);
  markup_set_strict_mode(LEngine, True);
  markup_set_allow_html(LEngine, False);
  markup_set_max_iterations(LEngine, 5000);
  markup_set_max_recursion(LEngine, 50);
  markup_set_max_output_size(LEngine, 2 * 1024 * 1024);

  LHtml := markup_convert(LEngine, Utf8(LSource), Utf8(LJson));
  try
    // Use LHtml...
  finally
    markup_free(LHtml);
  end;
finally
  markup_destroy(LEngine);
end;
```

## Custom Tags

Register a tag handler to intercept any tag name and emit custom HTML. The handler receives a render context with access to the tag's attributes and children.

```delphi
procedure MyAlertHandler(const ACtx: TMuCtx; const AUserData: Pointer);
var
  LLevel: PAnsiChar;
begin
  markup_ctx_emit(ACtx, Utf8('<div class="alert'));

  if markup_ctx_has_attr(ACtx, Utf8('level')) then
  begin
    LLevel := markup_ctx_attr(ACtx, Utf8('level'));
    try
      markup_ctx_emit(ACtx, Utf8(' alert-'));
      markup_ctx_emit(ACtx, LLevel);
    finally
      markup_free(LLevel);
    end;
  end;

  markup_ctx_emit(ACtx, Utf8('">'));
  markup_ctx_emit_children(ACtx);
  markup_ctx_emit(ACtx, Utf8('</div>'));
end;
```

Register the handler before parsing or converting:

```delphi
markup_register_tag(LEngine, Utf8('alert'), MyAlertHandler, nil);
```

Now use it in Markup source:

```
{alert level=warning "{b "Warning:"} Check your configuration."}
```

Key points:

- Call `markup_ctx_emit` to write raw text to the output stream.
- Call `markup_ctx_emit_children` to render and emit the tag's inner content. If you skip this call, the tag's children are silently discarded.
- Call `markup_ctx_attr` to read an attribute value. The returned string must be freed with `markup_free`.
- Call `markup_ctx_has_attr` to check if an attribute exists before reading it.
- Call `markup_ctx_tag_name` to retrieve the tag name. The returned string must be freed with `markup_free`.
- The `ACtx` handle is valid only during the callback. Do not store it.
- Tag names are case-insensitive, stored internally as lowercase.
- Custom tags take priority over built-in tag processing.

## Custom Functions

Register a function handler to make custom logic callable from Markup expressions.

```delphi
function FormatPriceFunc(const AArgCount: Integer;
  const AArgs: TMuArgs; const AUserData: Pointer): PMuResult;
var
  LPrice: Double;
  LCurrency: PAnsiChar;
  LCurrStr: string;
begin
  LPrice := markup_arg_as_float(AArgs, 0);

  if AArgCount >= 2 then
  begin
    LCurrency := markup_arg_as_string(AArgs, 1);
    try
      LCurrStr := FromUtf8(LCurrency);
    finally
      markup_free(LCurrency);
    end;
  end
  else
    LCurrStr := '$';

  Result := markup_result_string(
    Utf8(LCurrStr + FormatFloat('#,##0.00', LPrice)));
end;
```

Register and use:

```delphi
markup_register_function(LEngine, Utf8('format_price'),
  FormatPriceFunc, nil);

LHtml := markup_convert(LEngine,
  Utf8('{p "Total: {=format_price(data.total)}"}'),
  Utf8('{"total": 12.75}'));
```

Key points:

- Use `markup_arg_count` to check how many arguments were passed.
- Read arguments by zero-based index using the `markup_arg_as_*` functions (`markup_arg_as_string`, `markup_arg_as_integer`, `markup_arg_as_float`, `markup_arg_as_boolean`, `markup_arg_as_uint64`).
- Strings returned by `markup_arg_as_string` must be freed with `markup_free`.
- Return a `PMuResult` constructed with one of the `markup_result_*` functions (`markup_result_string`, `markup_result_integer`, `markup_result_float`, `markup_result_boolean`, `markup_result_uint64`, `markup_result_nil`). The engine takes ownership.
- Function names are case-insensitive, stored as lowercase.

## Error Handling

Markup provides two complementary error reporting mechanisms.

**Real-time error callback.** Register an error handler to receive errors as they occur:

```delphi
procedure MyErrorHandler(const ASeverity: Integer;
  const ACode: PAnsiChar; const AMessage: PAnsiChar;
  const AUserData: Pointer);
begin
  case ASeverity of
    0: Write('[HINT] ');
    1: Write('[WARN] ');
    2: Write('[ERROR] ');
    3: Write('[FATAL] ');
  end;
  WriteLn(FromUtf8(ACode), ': ', FromUtf8(AMessage));
end;

markup_set_error_handler(LEngine, MyErrorHandler, nil);
```

`ACode` and `AMessage` are stack-local inside the callback. Copy them immediately with `FromUtf8()` if you need to retain them.

**Post-hoc error retrieval.** After any parse or render call, retrieve accumulated errors as JSON:

```delphi
var
  LErrors: PAnsiChar;
begin
  LErrors := markup_last_errors(LEngine);
  try
    WriteLn(FromUtf8(LErrors));
  finally
    markup_free(LErrors);
  end;
end;
```

The JSON format for both `markup_last_errors` and `markup_validate` is:

```json
[
  {
    "severity": "error",
    "code": "MS-T007",
    "message": "Include file not found: 'header.mu'"
  }
]
```

**Validation without rendering.** Use `markup_validate` to check source for errors without producing output:

```delphi
var
  LDiagnostics: PAnsiChar;
begin
  LDiagnostics := markup_validate(LEngine,
    Utf8('{include "missing_file.mu"}'));
  try
    WriteLn(FromUtf8(LDiagnostics)); // JSON array of diagnostics
  finally
    markup_free(LDiagnostics);
  end;
end;
```

**Status messages.** Register a status handler to receive pipeline progress messages:

```delphi
procedure MyStatusHandler(const AText: PAnsiChar;
  const AUserData: Pointer);
begin
  WriteLn('[STATUS] ', FromUtf8(AText));
end;

markup_set_status_handler(LEngine, MyStatusHandler, nil);
```

Pass `nil` to either `markup_set_error_handler` or `markup_set_status_handler` to unregister.

## Include Paths

The `{include "filename.mu"}` tag inserts another Markup file at the point of reference. Register directories for the engine to search:

```delphi
markup_add_include_path(LEngine, Utf8('C:\Templates'));
markup_add_include_path(LEngine, Utf8('C:\Shared\Partials'));
```

Paths are searched in registration order. The first match wins. The engine first checks whether the include path is an absolute path that exists directly; if not, it searches each registered include directory in order. Duplicate paths are silently ignored.

Included files can pass data to the included template via attributes:

```
{include "card.mu" title="Welcome" subtitle="Get started"}
```

Circular includes are detected and reported as errors.

## Memory Management

The ownership rules are straightforward:

- **You create, you destroy.** Call `markup_destroy` for every `markup_create`. Call `markup_doc_destroy` for every `markup_parse`.
- **DLL returns a string, you free it.** Every `PAnsiChar` returned by a DLL function must be freed with `markup_free`. This includes results from `markup_render`, `markup_convert`, `markup_validate`, `markup_last_errors`, `markup_ctx_tag_name`, `markup_ctx_attr`, and `markup_arg_as_string`.
- **Exception: `markup_version`.** The pointer returned by `markup_version` refers to a static internal buffer. Do **not** free it with `markup_free`.
- **You pass a string, you keep it.** Strings you pass to the DLL are read-only from the DLL's perspective. The DLL copies what it needs. You retain ownership.
- **Result values are owned by the engine.** The `PMuResult` returned from a custom function callback is taken over by the engine. Do not free it.

A typical lifecycle pattern:

```delphi
LEngine := markup_create();
try
  // Register handlers, add include paths, set options...
  LDoc := markup_parse(LEngine, Utf8(LSource));
  try
    LHtml := markup_render(LEngine, LDoc, Utf8(LJson));
    try
      // Use LHtml...
    finally
      markup_free(LHtml);      // Free rendered string
    end;
  finally
    markup_doc_destroy(LDoc);   // Free parsed document
  end;
finally
  markup_destroy(LEngine);      // Free engine and all registrations
end;
```

## String Contract

All strings crossing the DLL boundary are null-terminated UTF-8 encoded as `PAnsiChar`. Delphi's native `string` type is UTF-16, so conversion is required at the boundary.

The `Utf8()` and `FromUtf8()` helpers shown at the top of this guide handle this conversion. Use them consistently at every DLL call site and you will never encounter encoding issues.

Strings passed to callbacks (`TMuApiErrorHandler`, `TMuApiStatusHandler`) point into stack-local buffers and are valid only for the duration of that callback invocation. Copy immediately with `FromUtf8()` if you need the value to persist.

## Thread Safety

Each `TMuEngine` is an independent instance with its own lexer, parser, interpreter, environment, and error list. No shared mutable state exists between instances. Multiple engine handles may be used concurrently from different threads without synchronization.

A single engine handle must not be accessed from multiple threads simultaneously. If you need concurrent rendering, create one engine per thread.

`TMuDoc` handles are likewise independent objects. A `TMuDoc` obtained from one engine must only be rendered by that same engine, as interpreter state (custom tags, functions, include paths) is held on the engine.

## C/C++ Quick Start

The C/C++ header `Markup.h` provides identical functionality through a single-header dynamic loader. All function signatures, handle types, and callbacks mirror the Delphi API.

**Setup:** In exactly one `.c` or `.cpp` file, define `MARKUP_IMPLEMENTATION` before including the header. In all other files, include normally.

```c
// main.c
#define MARKUP_IMPLEMENTATION
#include "Markup.h"

int main(void) {
    if (!markup_load("Markup.dll")) return 1;

    MuEngine engine = markup_create();

    // Set options
    markup_set_pretty_print(engine, 1);
    markup_set_strict_mode(engine, 1);

    // One-shot conversion
    char* html = markup_convert(engine,
        "{h1 \"Hello from C\"}{p \"Markup works everywhere.\"}",
        NULL);
    printf("%s\n", html);
    markup_free(html);

    // Convert to file
    markup_convert_to_file(engine,
        "{h1 \"Report\"}{p \"Generated.\"}",
        NULL, "output\\report", 1);

    markup_destroy(engine);
    markup_unload();
    return 0;
}
```

Key differences from the Delphi API:

- Call `markup_load("Markup.dll")` before using any functions and `markup_unload()` at shutdown.
- Use `markup_is_loaded()` to check whether the DLL is loaded.
- Boolean parameters use `MuBool` (`int32_t`): 0 = false, non-zero = true.
- Handle types are `MuEngine`, `MuDoc`, `MuCtx`, `MuArgs`, `MuResult` (no `T`/`P` prefix).
- All string parameters are `const char*` (UTF-8). Returned strings are `char*` and must be freed with `markup_free()`.
- The memory management and ownership rules are identical to Delphi.
