<div align="center">

![Markup](../media/markup.png)

</div>

# Markup API Reference

This document covers every exported function, type, and callback in the Markup DLL API. For the language syntax, see [Specs.md](Specs.md). For practical usage patterns, see [User.md](User.md).

## String Contract

All strings crossing the DLL boundary are null-terminated UTF-8 (`PAnsiChar`).

Strings **returned** by the DLL are heap-allocated. The caller **must** free them with `markup_free` when no longer needed. Failing to do so leaks memory.

Strings **passed to** the DLL are read-only. The DLL copies what it needs internally. The caller retains ownership and may free them after the call returns.

**Exception:** `markup_version` returns a pointer to a static internal buffer. Do **not** free it with `markup_free`.

## Types and Handles

### TMuEngine

```delphi
TMuEngine = type Pointer;
```

Opaque handle to a Markup engine instance. Returned by `markup_create` and accepted by all API functions that operate on an engine. One engine can parse and render multiple documents. Destroy with `markup_destroy`.

### TMuDoc

```delphi
TMuDoc = type Pointer;
```

Opaque handle to a parsed Markup document. Returned by `markup_parse` and accepted by `markup_render`. Parsing is expensive; rendering is cheap. Parse once, render many times with different data. Destroy with `markup_doc_destroy`.

### TMuCtx

```delphi
TMuCtx = type Pointer;
```

Opaque handle to a render context, passed to custom tag handler callbacks. Valid only during the callback invocation. Use the `markup_ctx_*` functions to inspect attributes and emit output.

### TMuArgs

```delphi
TMuArgs = type Pointer;
```

Opaque handle to a function argument array, passed to custom function handler callbacks. Use the `markup_arg_*` functions to read individual arguments by index.

### PMuResult

```delphi
PMuResult = type Pointer;
```

Opaque handle to a function return value. Constructed using the `markup_result_*` functions and returned from custom function handler callbacks. The engine takes ownership; do not free it yourself.

## Callbacks

### TMuApiTagHandler

```delphi
TMuApiTagHandler = procedure(const ACtx: TMuCtx; const AUserData: Pointer);
```

Callback signature for custom tag handlers registered via `markup_register_tag`. When the interpreter encounters the registered tag, it calls this procedure with a render context and the user data pointer supplied at registration.

`ACtx` is valid only for the duration of the callback. Do not store it.

### TMuApiFuncHandler

```delphi
TMuApiFuncHandler = function(const AArgCount: Integer;
  const AArgs: TMuArgs; const AUserData: Pointer): PMuResult;
```

Callback signature for custom function handlers registered via `markup_register_function`. When the interpreter evaluates a call to the registered function, it calls this function with the argument count, an argument handle, and the user data pointer.

Return a `PMuResult` constructed via one of the `markup_result_*` functions. The engine takes ownership of the result.

### TMuApiErrorHandler

```delphi
TMuApiErrorHandler = procedure(const ASeverity: Integer;
  const ACode: PAnsiChar; const AMessage: PAnsiChar;
  const AUserData: Pointer);
```

Callback for real-time error reporting during parsing and rendering. `ASeverity` ordinals: 0 = Hint, 1 = Warning, 2 = Error, 3 = Fatal.

`ACode` and `AMessage` are stack-local. Copy them immediately if you need to retain them beyond the callback.

### TMuApiStatusHandler

```delphi
TMuApiStatusHandler = procedure(const AText: PAnsiChar;
  const AUserData: Pointer);
```

Callback for pipeline status messages emitted during parsing and rendering. `AText` is stack-local. Copy immediately if needed.

## Lifecycle

### markup_create

```delphi
function markup_create(): TMuEngine;
```

Creates a new Markup engine instance. Returns an opaque engine handle. The caller must eventually call `markup_destroy` to release resources.

### markup_destroy

```delphi
procedure markup_destroy(const AEngine: TMuEngine);
```

Destroys an engine instance and frees all associated memory, including registered tag handlers, function handlers, and include paths. Safe to call with `nil`.

### markup_version

```delphi
function markup_version(): PAnsiChar;
```

Returns the Markup library version string (e.g. `'1.0.0'`). The returned pointer refers to a static internal buffer that is valid for the lifetime of the DLL. Do **not** free it with `markup_free`.

### markup_free

```delphi
procedure markup_free(const APtr: PAnsiChar);
```

Frees a heap-allocated string returned by any DLL function. Every `PAnsiChar` returned by `markup_render`, `markup_convert`, `markup_validate`, `markup_last_errors`, `markup_ctx_tag_name`, `markup_ctx_attr`, and `markup_arg_as_string` must be freed with this function. Safe to call with `nil`.

Do **not** call on the pointer returned by `markup_version` (static buffer). Do **not** call on strings passed to callbacks (stack-local).

## Parsing and Rendering

### markup_parse

```delphi
function markup_parse(const AEngine: TMuEngine;
  const ASource: PAnsiChar): TMuDoc;
```

Parses a Markup source string into a reusable document handle. Returns `nil` on failure (check `markup_last_errors` for diagnostics).

The returned `TMuDoc` can be rendered multiple times with different data via `markup_render`. Destroy with `markup_doc_destroy` when done.

**Parameters:**
- `AEngine` -- engine instance
- `ASource` -- null-terminated UTF-8 Markup source

### markup_doc_destroy

```delphi
procedure markup_doc_destroy(const ADoc: TMuDoc);
```

Destroys a parsed document handle and frees its AST memory. Safe to call with `nil`.

### markup_render

```delphi
function markup_render(const AEngine: TMuEngine;
  const ADoc: TMuDoc; const AData: PAnsiChar): PAnsiChar;
```

Renders a previously parsed document with optional JSON data. Returns heap-allocated HTML that must be freed with `markup_free`.

**Parameters:**
- `AEngine` -- engine instance (must be the same engine that produced `ADoc`)
- `ADoc` -- parsed document from `markup_parse`
- `AData` -- null-terminated UTF-8 JSON string, or `nil` for no data binding

### markup_convert

```delphi
function markup_convert(const AEngine: TMuEngine;
  const ASource: PAnsiChar; const AData: PAnsiChar): PAnsiChar;
```

One-shot convenience function: parses and renders in a single call. Equivalent to calling `markup_parse`, `markup_render`, then `markup_doc_destroy`. Returns heap-allocated HTML that must be freed with `markup_free`.

**Parameters:**
- `AEngine` -- engine instance
- `ASource` -- null-terminated UTF-8 Markup source
- `AData` -- null-terminated UTF-8 JSON string, or `nil` for no data binding

### markup_convert_to_file

```delphi
function markup_convert_to_file(const AEngine: TMuEngine;
  const ASource: PAnsiChar;
  const AData: PAnsiChar;
  const AFilename: PAnsiChar;
  const AOpenInBrowser: Boolean): Boolean;
```

One-shot conversion that writes the rendered HTML directly to a file, optionally opening it in the default browser. The output filename is forced to a `.html` extension. Parent directories are created automatically if they do not exist.

Returns `True` if the file was written successfully; `False` on error.

**Parameters:**
- `AEngine` -- engine instance
- `ASource` -- null-terminated UTF-8 Markup source
- `AData` -- null-terminated UTF-8 JSON string, or `nil` for no data binding
- `AFilename` -- null-terminated UTF-8 output file path (extension forced to `.html`)
- `AOpenInBrowser` -- if `True`, opens the written file in the default browser

## Validation and Errors

### markup_validate

```delphi
function markup_validate(const AEngine: TMuEngine;
  const ASource: PAnsiChar): PAnsiChar;
```

Parses the source and returns a JSON array of diagnostics without rendering. Returns heap-allocated JSON that must be freed with `markup_free`. Returns an empty array `[]` if the source is valid.

**Parameters:**
- `AEngine` -- engine instance
- `ASource` -- null-terminated UTF-8 Markup source

### markup_last_errors

```delphi
function markup_last_errors(const AEngine: TMuEngine): PAnsiChar;
```

Returns a JSON array of errors from the most recent parse or render operation. Returns heap-allocated JSON that must be freed with `markup_free`. Returns `[]` if there were no errors.

## Include Paths

### markup_add_include_path

```delphi
procedure markup_add_include_path(const AEngine: TMuEngine;
  const APath: PAnsiChar);
```

Adds a directory to the engine's include search path. When the interpreter encounters an `{include "file.mu"}` tag, it searches the registered paths in order. Multiple paths can be added; they are searched in registration order. Duplicate paths are silently ignored. Circular includes are detected and reported as errors.

**Parameters:**
- `AEngine` -- engine instance
- `APath` -- null-terminated UTF-8 directory path

## Options Configuration

### markup_set_pretty_print

```delphi
procedure markup_set_pretty_print(const AEngine: TMuEngine;
  const AEnabled: Boolean);
```

Enables or disables pretty-printed HTML output with newlines and indentation for block-level elements. When enabled, block-level tags (`div`, `p`, `section`, `h1`–`h6`, `table`, `ul`, `ol`, etc.) receive newlines and 2-space indentation in the output. Inline tags remain on the same line. Code and raw HTML content is never reformatted. Defaults to `False`.

**Parameters:**
- `AEngine` -- engine instance
- `AEnabled` -- `True` to enable pretty-printing; `False` to disable

### markup_set_strict_mode

```delphi
procedure markup_set_strict_mode(const AEngine: TMuEngine;
  const AEnabled: Boolean);
```

Enables or disables strict mode. When enabled, `{get}` on an undefined variable produces an error, and unrecognized tags produce errors rather than being silently escaped or passed through. Defaults to `False`.

**Parameters:**
- `AEngine` -- engine instance
- `AEnabled` -- `True` to enable strict mode; `False` to disable

### markup_set_allow_html

```delphi
procedure markup_set_allow_html(const AEngine: TMuEngine;
  const AEnabled: Boolean);
```

Enables or disables raw HTML passthrough via the `{html}` tag. When disabled, `{html}` content is HTML-escaped instead of emitted raw. Set to `False` for security-sensitive contexts where untrusted input may contain malicious HTML or scripts. Defaults to `True`.

**Parameters:**
- `AEngine` -- engine instance
- `AEnabled` -- `True` to allow raw HTML; `False` to escape it

### markup_set_unknown_tag_behavior

```delphi
procedure markup_set_unknown_tag_behavior(const AEngine: TMuEngine;
  const ABehavior: Integer);
```

Sets the behavior for tags not recognized as built-in Markup tags or standard HTML elements.

**Parameters:**
- `AEngine` -- engine instance
- `ABehavior` -- integer ordinal: `0` = escape (show as escaped text, the default), `1` = passthrough (wrap in `<span class="mu-unknown">`)

### markup_set_max_iterations

```delphi
procedure markup_set_max_iterations(const AEngine: TMuEngine;
  const AMax: Integer);
```

Sets the maximum number of loop iterations allowed during a single render pass. Prevents infinite loops from exhausting resources. Defaults to 10000. When exceeded, the interpreter adds an error and stops iteration.

**Parameters:**
- `AEngine` -- engine instance
- `AMax` -- maximum iteration count

### markup_set_max_recursion

```delphi
procedure markup_set_max_recursion(const AEngine: TMuEngine;
  const AMax: Integer);
```

Sets the maximum recursion depth for component calls and nested rendering. Prevents stack overflow from deeply recursive templates. Defaults to 100. When exceeded, the interpreter adds an error and stops recursion.

**Parameters:**
- `AEngine` -- engine instance
- `AMax` -- maximum recursion depth

### markup_set_max_output_size

```delphi
procedure markup_set_max_output_size(const AEngine: TMuEngine;
  const AMax: Integer);
```

Sets the maximum output buffer size in bytes. Prevents runaway templates from consuming excessive memory. Defaults to 10 MB (10 × 1024 × 1024). When exceeded, the interpreter adds an error and stops emitting output.

**Parameters:**
- `AEngine` -- engine instance
- `AMax` -- maximum output size in bytes

## Custom Tags

### markup_register_tag

```delphi
procedure markup_register_tag(const AEngine: TMuEngine;
  const ATagName: PAnsiChar; const AHandler: TMuApiTagHandler;
  const AUserData: Pointer);
```

Registers a custom tag handler. When the interpreter encounters `{ATagName ...}`, it calls `AHandler` instead of emitting default HTML. Tag names are case-insensitive, stored internally as lowercase. Custom tags take priority over built-in tag processing. Register before calling `markup_render` or `markup_convert`.

**Parameters:**
- `AEngine` -- engine instance
- `ATagName` -- tag name to intercept (e.g., `alert`, `chart`)
- `AHandler` -- callback procedure
- `AUserData` -- arbitrary pointer passed through to the callback

### markup_ctx_tag_name

```delphi
function markup_ctx_tag_name(const ACtx: TMuCtx): PAnsiChar;
```

Returns the name of the tag being rendered. The returned string must be freed with `markup_free`. Only valid inside a `TMuApiTagHandler` callback.

### markup_ctx_attr

```delphi
function markup_ctx_attr(const ACtx: TMuCtx;
  const AAttrName: PAnsiChar): PAnsiChar;
```

Returns the value of the named attribute on the current tag, or an empty string if the attribute is not present. The returned string must be freed with `markup_free`.

### markup_ctx_has_attr

```delphi
function markup_ctx_has_attr(const ACtx: TMuCtx;
  const AAttrName: PAnsiChar): Boolean;
```

Returns `True` if the current tag has the named attribute.

### markup_ctx_emit

```delphi
procedure markup_ctx_emit(const ACtx: TMuCtx; const AText: PAnsiChar);
```

Emits raw text into the output stream. Use this inside a tag handler to write HTML or any other text to the rendered output. Multiple calls within a single handler are concatenated in order.

### markup_ctx_emit_children

```delphi
procedure markup_ctx_emit_children(const ACtx: TMuCtx);
```

Renders and emits the children of the current tag. Call this in a tag handler to include the tag's inner content in the output. If omitted, the tag's children are discarded. If called multiple times, the children are rendered multiple times.

## Custom Functions

### markup_register_function

```delphi
procedure markup_register_function(const AEngine: TMuEngine;
  const AFuncName: PAnsiChar; const AHandler: TMuApiFuncHandler;
  const AUserData: Pointer);
```

Registers a custom function callable from Markup expressions as `{=func_name(args)}`. Function names are case-insensitive, stored as lowercase. Register before calling `markup_render` or `markup_convert`.

**Parameters:**
- `AEngine` -- engine instance
- `AFuncName` -- function name (e.g., `format_price`)
- `AHandler` -- callback function
- `AUserData` -- arbitrary pointer passed through to the callback

## Argument Accessors

These functions read arguments by zero-based index from the `TMuArgs` handle passed to custom function callbacks.

### markup_arg_as_string

```delphi
function markup_arg_as_string(const AArgs: TMuArgs;
  const AIndex: Integer): PAnsiChar;
```

Returns the argument at `AIndex` as a UTF-8 string. The returned string must be freed with `markup_free`. Returns an empty string on `nil` `AArgs` or out-of-bounds index.

### markup_arg_as_integer

```delphi
function markup_arg_as_integer(const AArgs: TMuArgs;
  const AIndex: Integer): Int64;
```

Returns the argument at `AIndex` as a 64-bit signed integer. Returns zero on `nil` `AArgs` or out-of-bounds index.

### markup_arg_as_float

```delphi
function markup_arg_as_float(const AArgs: TMuArgs;
  const AIndex: Integer): Double;
```

Returns the argument at `AIndex` as a double-precision float. Returns 0.0 on `nil` `AArgs` or out-of-bounds index.

### markup_arg_as_boolean

```delphi
function markup_arg_as_boolean(const AArgs: TMuArgs;
  const AIndex: Integer): Boolean;
```

Returns the argument at `AIndex` as a boolean. Returns `False` on `nil` `AArgs` or out-of-bounds index.

### markup_arg_as_uint64

```delphi
function markup_arg_as_uint64(const AArgs: TMuArgs;
  const AIndex: Integer): UInt64;
```

Returns the argument at `AIndex` as a 64-bit unsigned integer. Returns zero on `nil` `AArgs` or out-of-bounds index.

### markup_arg_count

```delphi
function markup_arg_count(const AArgs: TMuArgs): Integer;
```

Returns the number of arguments passed to the custom function. Returns zero if `AArgs` is `nil`.

## Result Constructors

These functions construct return values for custom function callbacks. The engine takes ownership of the returned `PMuResult`. Do not free it yourself.

### markup_result_string

```delphi
function markup_result_string(const AValue: PAnsiChar): PMuResult;
```

Constructs a string result from a null-terminated UTF-8 value. The value string is copied during construction.

### markup_result_integer

```delphi
function markup_result_integer(const AValue: Int64): PMuResult;
```

Constructs a 64-bit signed integer result.

### markup_result_float

```delphi
function markup_result_float(const AValue: Double): PMuResult;
```

Constructs a double-precision float result.

### markup_result_boolean

```delphi
function markup_result_boolean(const AValue: Boolean): PMuResult;
```

Constructs a boolean result.

### markup_result_uint64

```delphi
function markup_result_uint64(const AValue: UInt64): PMuResult;
```

Constructs a 64-bit unsigned integer result.

### markup_result_nil

```delphi
function markup_result_nil(): PMuResult;
```

Constructs a nil (no value) result. Use when a function has no meaningful return value. A nil value evaluates as falsy in expressions and renders as empty string.

## Error and Status Handlers

### markup_set_error_handler

```delphi
procedure markup_set_error_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiErrorHandler; const AUserData: Pointer);
```

Registers a callback for real-time error reporting. Errors are delivered as they occur during parsing, rendering, validation, and include resolution. Pass `nil` as `AHandler` to unregister. The callback is invoked synchronously. Registering a handler does not suppress accumulation of diagnostics on the engine's internal error list. Only one handler at a time — a new registration replaces the previous one.

**Parameters:**
- `AEngine` -- engine instance
- `AHandler` -- error callback, or `nil` to unregister
- `AUserData` -- arbitrary pointer passed through to the callback

The severity integer maps to: 0 = Hint, 1 = Warning, 2 = Error, 3 = Fatal.

### markup_set_status_handler

```delphi
procedure markup_set_status_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiStatusHandler; const AUserData: Pointer);
```

Registers a callback for pipeline status messages. Pass `nil` as `AHandler` to unregister. Only one handler at a time — a new registration replaces the previous one.

**Parameters:**
- `AEngine` -- engine instance
- `AHandler` -- status callback, or `nil` to unregister
- `AUserData` -- arbitrary pointer passed through to the callback

## Thread Safety

Each `TMuEngine` is an independent instance with its own lexer, parser, interpreter, environment, and error list. No shared mutable state exists between instances. Multiple engine handles may be used concurrently from different threads. A single engine handle must not be accessed from multiple threads simultaneously. `TMuDoc` handles are likewise independent objects; a `TMuDoc` obtained from one engine must only be rendered by that same engine.

## C/C++ API

The C/C++ header `Markup.h` provides identical functionality through a single-header dynamic loader. All function signatures, handle types, and callbacks mirror the Delphi API. The C header uses `MuEngine`, `MuDoc`, `MuCtx`, `MuArgs`, `MuResult` (without the `T`/`P` prefix) and `MuBool` (`int32_t`, 0 = false, non-zero = true) instead of Delphi `Boolean`.

Usage:

```c
#define MARKUP_IMPLEMENTATION
#include "Markup.h"

int main(void) {
    if (!markup_load("Markup.dll")) return 1;

    MuEngine engine = markup_create();
    char* html = markup_convert(engine, "{h1 \"Hello\"}", NULL);
    printf("%s\n", html);
    markup_free(html);
    markup_destroy(engine);

    markup_unload();
    return 0;
}
```

Define `MARKUP_IMPLEMENTATION` in exactly one `.c` or `.cpp` file before including the header. In all other files, include normally. Call `markup_load()` at startup and `markup_unload()` at shutdown.
