{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

/// <summary>
///   Delphi and Free Pascal import wrapper for Markup.dll. Provides
///   complete access to the Markup document authoring and template
///   rendering pipeline through opaque handles and flat function calls
///   with no dependencies on Markup internals.
/// </summary>
/// <remarks>
///   All interaction is through opaque typed-pointer handles (TMuEngine,
///   TMuDoc, TMuCtx, TMuArgs, PMuResult) and null-terminated UTF-8 strings
///   (PAnsiChar). No Markup source units are required to compile against
///   this unit.
///   <para>
///   <b>String contract:</b> All strings crossing the DLL boundary are
///   null-terminated UTF-8. Strings <i>returned</i> by the DLL are
///   heap-allocated and the caller <b>must</b> free them with markup_free
///   when no longer needed. Failing to call markup_free on returned strings
///   will leak memory. Strings passed <i>to</i> callback procedures
///   (TMuApiErrorHandler, TMuApiStatusHandler) point into stack-local
///   buffers and are valid only for the duration of that callback
///   invocation — copy immediately with UTF8ToString() if you need the
///   value to persist.
///   </para>
///   <para>
///   <b>Pipeline overview:</b> The Markup pipeline decomposes document
///   processing into two discrete phases: markup_parse (tokenize and parse
///   a Markup source string into a reusable TMuDoc handle) and markup_render
///   (interpret the parsed document tree and produce an HTML output string).
///   A parsed TMuDoc may be rendered multiple times with different data
///   payloads without re-parsing. The convenience function markup_convert
///   combines both phases into a single call for one-shot usage.
///   markup_convert_to_file extends this further by writing the rendered
///   HTML directly to disk with optional browser launch.
///   </para>
///   <para>
///   <b>Template data binding:</b> Both markup_render and markup_convert
///   accept an optional AData parameter — a JSON string that is parsed
///   internally and bound into the template environment as the variable
///   'data'. The JSON must represent an object (map); if nil or empty, the
///   template renders without external data.
///   </para>
///   <para>
///   <b>One-shot conversion:</b>
///   </para>
///   <code>
///   var
///     LEngine: TMuEngine;
///     LHtml: PAnsiChar;
///   begin
///     LEngine := markup_create();
///     try
///       LHtml := markup_convert(LEngine,
///         PAnsiChar(UTF8Encode('{h1}Hello, World!{/h1}')), nil);
///       try
///         WriteLn(UTF8ToString(LHtml));
///       finally
///         markup_free(LHtml);
///       end;
///     finally
///       markup_destroy(LEngine);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Parse-then-render with data binding:</b>
///   </para>
///   <code>
///   var
///     LEngine: TMuEngine;
///     LDoc: TMuDoc;
///     LHtml: PAnsiChar;
///     LJson: PAnsiChar;
///   begin
///     LEngine := markup_create();
///     try
///       LDoc := markup_parse(LEngine,
///         PAnsiChar(UTF8Encode('{h1}{= data.title}{/h1}')));
///       try
///         LJson := PAnsiChar(UTF8Encode('{"title":"Greetings"}'));
///         LHtml := markup_render(LEngine, LDoc, LJson);
///         try
///           WriteLn(UTF8ToString(LHtml));  // <h1>Greetings</h1>
///         finally
///           markup_free(LHtml);
///         end;
///       finally
///         markup_doc_destroy(LDoc);
///       end;
///     finally
///       markup_destroy(LEngine);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Convert to file with browser launch:</b>
///   </para>
///   <code>
///   var
///     LEngine: TMuEngine;
///   begin
///     LEngine := markup_create();
///     try
///       markup_convert_to_file(LEngine,
///         PAnsiChar(UTF8Encode('{h1}Report{/h1}{p}Generated.{/p}')),
///         nil,
///         PAnsiChar(UTF8Encode('output\report')),
///         True);  // opens in browser
///     finally
///       markup_destroy(LEngine);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Engine options:</b> The engine exposes several configurable options
///   via the markup_set_* functions. These include markup_set_pretty_print
///   (formatted HTML output with indentation), markup_set_strict_mode
///   (errors on undefined variables and unknown tags),
///   markup_set_allow_html (control raw HTML passthrough for security),
///   markup_set_unknown_tag_behavior (escape vs span-wrap unknown tags),
///   and safety limits (markup_set_max_iterations,
///   markup_set_max_recursion, markup_set_max_output_size).
///   </para>
///   <code>
///   var
///     LEngine: TMuEngine;
///   begin
///     LEngine := markup_create();
///     try
///       markup_set_pretty_print(LEngine, True);
///       markup_set_strict_mode(LEngine, True);
///       markup_set_allow_html(LEngine, False);
///       // ... convert or render ...
///     finally
///       markup_destroy(LEngine);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Custom tag handler:</b> Register a handler with markup_register_tag,
///   then use the markup_ctx_* functions inside the callback to query
///   attributes, emit output, and walk child nodes. The context handle
///   (TMuCtx) is valid only for the duration of the callback invocation.
///   </para>
///   <code>
///   procedure MyAlertHandler(const ACtx: TMuCtx;
///     const AUserData: Pointer);
///   var
///     LLevel: PAnsiChar;
///   begin
///     LLevel := markup_ctx_attr(ACtx,
///       PAnsiChar(UTF8Encode('level')));
///     try
///       markup_ctx_emit(ACtx,
///         PAnsiChar(UTF8Encode('&lt;div class="alert-')));
///       markup_ctx_emit(ACtx, LLevel);
///       markup_ctx_emit(ACtx,
///         PAnsiChar(UTF8Encode('"&gt;')));
///       markup_ctx_emit_children(ACtx);
///       markup_ctx_emit(ACtx,
///         PAnsiChar(UTF8Encode('&lt;/div&gt;')));
///     finally
///       markup_free(LLevel);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Custom function handler:</b> Register a function with
///   markup_register_function, then use markup_arg_* to read typed
///   arguments and return a PMuResult via the markup_result_* constructors.
///   The returned PMuResult is owned by the engine — do not free it.
///   </para>
///   <code>
///   function MyUpperFunc(const AArgCount: Integer;
///     const AArgs: TMuArgs; const AUserData: Pointer): PMuResult;
///   var
///     LStr: PAnsiChar;
///     LUpper: string;
///   begin
///     LStr := markup_arg_as_string(AArgs, 0);
///     try
///       LUpper := UpperCase(UTF8ToString(LStr));
///       Result := markup_result_string(
///         PAnsiChar(UTF8Encode(LUpper)));
///     finally
///       markup_free(LStr);
///     end;
///   end;
///   </code>
///   <para>
///   <b>Validation and error reporting:</b> markup_validate parses the
///   source, collects all diagnostics, and returns them as a JSON array.
///   markup_last_errors returns the diagnostics from the most recent
///   operation. Both return heap-allocated strings that must be freed with
///   markup_free. The JSON schema is:
///   </para>
///   <code>
///   [
///     {
///       "severity": "error",
///       "code": "MS-T007",
///       "message": "Include file not found: 'header.mu'"
///     }
///   ]
///   </code>
///   <para>
///   <b>Error severity ordinals:</b> When using TMuApiErrorHandler, the
///   ASeverity parameter is an integer ordinal: 0 = Hint, 1 = Warning,
///   2 = Error, 3 = Fatal.
///   </para>
///   <para>
///   <b>Thread safety:</b> Each TMuEngine is an independent instance with
///   its own lexer, parser, interpreter, environment, and error list. No
///   shared mutable state exists between instances. Multiple engine handles
///   may be used concurrently from different threads. A single engine
///   handle must not be accessed from multiple threads simultaneously.
///   TMuDoc handles are likewise independent objects; a TMuDoc obtained
///   from one engine must only be rendered by that same engine.
///   </para>
///   <para>
///   <b>Compatibility:</b> This unit compiles with Delphi and Free Pascal.
///   It uses only standard types: Pointer, PAnsiChar, Integer, Int64,
///   UInt64, Double, Boolean. Under FPC, the DELPHIUNICODE mode is
///   activated automatically so that string types match modern Delphi
///   behavior.
///   </para>
/// </remarks>
unit Markup;

{$Z4}
{$A8}

{$WARN SYMBOL_DEPRECATED OFF}
{$WARN SYMBOL_PLATFORM OFF}

{$WARN UNIT_PLATFORM OFF}
{$WARN UNIT_DEPRECATED OFF}

{$INLINE AUTO}

{$IFNDEF WIN64}
  {$MESSAGE Error 'Unsupported platform'}
{$ENDIF}

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}

interface

const
  /// <summary>
  ///   The filename of the Markup shared library that all imports in this
  ///   unit bind to at load time.
  /// </summary>
  MARKUP_DLL = 'Markup.dll';

type
  /// <summary>
  ///   Opaque handle to a Markup engine instance. Returned by markup_create
  ///   and accepted by all API functions that operate on an engine. Must be
  ///   freed with markup_destroy when no longer needed.
  /// </summary>
  /// <remarks>
  ///   Each engine owns its own lexer, parser, interpreter, built-in
  ///   function registry, custom tag registry, include path list, options,
  ///   and error list. Creating multiple engines is safe — they share no
  ///   mutable state.
  /// </remarks>
  TMuEngine = type Pointer;

  /// <summary>
  ///   Opaque handle to a parsed Markup document. Returned by markup_parse
  ///   and accepted by markup_render. Represents a fully parsed AST ready
  ///   for one or more render passes.
  /// </summary>
  /// <remarks>
  ///   Must be freed with markup_doc_destroy when no longer needed. A
  ///   TMuDoc obtained from one engine should only be rendered by that
  ///   same engine, as interpreter state (custom tags, functions, include
  ///   paths) is held on the engine.
  /// </remarks>
  TMuDoc = type Pointer;

  /// <summary>
  ///   Opaque handle to a render context, passed to custom tag handler
  ///   callbacks registered via markup_register_tag. Provides access to
  ///   the current tag's name, attributes, output buffer, and child-node
  ///   traversal.
  /// </summary>
  /// <remarks>
  ///   Valid only for the duration of the tag handler callback invocation.
  ///   Do not store this handle beyond the callback scope. Use the
  ///   markup_ctx_* functions to interact with it.
  /// </remarks>
  TMuCtx = type Pointer;

  /// <summary>
  ///   Opaque handle to a function argument array, passed to custom
  ///   function handler callbacks registered via markup_register_function.
  /// </summary>
  /// <remarks>
  ///   Valid only during the callback invocation. Use markup_arg_count to
  ///   determine the number of arguments, and markup_arg_as_* to read
  ///   individual arguments by zero-based index.
  /// </remarks>
  TMuArgs = type Pointer;

  /// <summary>
  ///   Opaque handle to a function return value, returned from custom
  ///   function handler callbacks. Constructed using the markup_result_*
  ///   factory functions. The engine takes ownership — do not free it.
  /// </summary>
  PMuResult = type Pointer;

  /// <summary>
  ///   Callback for custom tag handlers registered via markup_register_tag.
  /// </summary>
  /// <remarks>
  ///   ACtx is valid only during the callback. Use markup_ctx_tag_name to
  ///   retrieve the tag name, markup_ctx_attr / markup_ctx_has_attr to
  ///   query attributes, markup_ctx_emit to write output, and
  ///   markup_ctx_emit_children to recursively render child nodes.
  ///   Strings returned by markup_ctx_tag_name and markup_ctx_attr are
  ///   heap-allocated and must be freed with markup_free.
  /// </remarks>
  /// <param name="ACtx">
  ///   Opaque render context handle. Valid only during the callback.
  /// </param>
  /// <param name="AUserData">
  ///   The user data pointer passed to markup_register_tag. May be nil.
  /// </param>
  TMuApiTagHandler = procedure(const ACtx: TMuCtx;
    const AUserData: Pointer);

  /// <summary>
  ///   Callback for custom function handlers registered via
  ///   markup_register_function. Return a PMuResult via the
  ///   markup_result_* constructors. The engine takes ownership.
  /// </summary>
  /// <remarks>
  ///   AArgs is valid only during the callback. Use markup_arg_count and
  ///   markup_arg_as_* to read arguments. Strings returned by
  ///   markup_arg_as_string must be freed with markup_free inside the
  ///   callback. Return markup_result_nil() for no return value.
  /// </remarks>
  /// <param name="AArgCount">
  ///   Number of arguments. Matches markup_arg_count(AArgs).
  /// </param>
  /// <param name="AArgs">
  ///   Opaque argument array handle. Valid only during the callback.
  /// </param>
  /// <param name="AUserData">
  ///   The user data pointer passed to markup_register_function.
  /// </param>
  /// <returns>
  ///   An opaque PMuResult handle. The engine takes ownership.
  /// </returns>
  TMuApiFuncHandler = function(const AArgCount: Integer;
    const AArgs: TMuArgs; const AUserData: Pointer): PMuResult;

  /// <summary>
  ///   Callback for real-time error reporting during parsing, rendering,
  ///   or validation.
  /// </summary>
  /// <remarks>
  ///   ACode and AMessage are stack-local UTF-8 buffers valid only for
  ///   the duration of this callback. Copy immediately with
  ///   UTF8ToString() if you need the values to persist. Register with
  ///   markup_set_error_handler. Pass nil to unregister.
  /// </remarks>
  /// <param name="ASeverity">
  ///   Integer ordinal: 0 = Hint, 1 = Warning, 2 = Error, 3 = Fatal.
  /// </param>
  /// <param name="ACode">
  ///   Null-terminated UTF-8 error code (e.g. 'MS-T001'). Stack-local.
  /// </param>
  /// <param name="AMessage">
  ///   Null-terminated UTF-8 diagnostic message. Stack-local.
  /// </param>
  /// <param name="AUserData">
  ///   The user data pointer passed to markup_set_error_handler.
  /// </param>
  TMuApiErrorHandler = procedure(const ASeverity: Integer;
    const ACode: PAnsiChar; const AMessage: PAnsiChar;
    const AUserData: Pointer);

  /// <summary>
  ///   Callback for pipeline status messages during parsing, rendering,
  ///   include resolution, or other engine operations.
  /// </summary>
  /// <remarks>
  ///   AText is a stack-local UTF-8 buffer valid only during this
  ///   callback. Copy with UTF8ToString() if needed. Register with
  ///   markup_set_status_handler. Pass nil to unregister.
  /// </remarks>
  /// <param name="AText">
  ///   Null-terminated UTF-8 status message. Stack-local.
  /// </param>
  /// <param name="AUserData">
  ///   The user data pointer passed to markup_set_status_handler.
  /// </param>
  TMuApiStatusHandler = procedure(const AText: PAnsiChar;
    const AUserData: Pointer);

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// <summary>
///   Creates a new Markup engine instance and returns its opaque handle.
/// </summary>
/// <remarks>
///   The engine is fully independent, owning its own lexer, parser,
///   interpreter, built-in registry, custom tag registry, include path
///   list, and error list. Multiple engines may coexist. Free with
///   markup_destroy when no longer needed.
/// </remarks>
/// <returns>
///   An opaque TMuEngine handle. Must be freed with markup_destroy.
/// </returns>
function  markup_create(): TMuEngine; external MARKUP_DLL;

/// <summary>
///   Destroys a Markup engine instance and releases all associated memory.
///   The handle becomes invalid after this call.
/// </summary>
/// <remarks>
///   Safe to call with nil. Any TMuDoc handles previously obtained via
///   markup_parse remain valid and must be freed separately with
///   markup_doc_destroy, but should not be rendered after the engine is
///   destroyed.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create, or nil.
/// </param>
procedure markup_destroy(const AEngine: TMuEngine); external MARKUP_DLL;

/// <summary>
///   Returns the version string of the Markup library (e.g. '1.0.0').
/// </summary>
/// <remarks>
///   The returned PAnsiChar points to a static internal buffer that is
///   valid for the lifetime of the DLL. Do not free it with markup_free.
///   The version is read from the DLL's embedded PE version resource.
/// </remarks>
/// <returns>
///   Null-terminated UTF-8 version string. Do not free.
/// </returns>
function  markup_version(): PAnsiChar; external MARKUP_DLL;

/// <summary>
///   Frees a heap-allocated PAnsiChar string returned by a Markup API
///   function (markup_render, markup_convert, markup_validate,
///   markup_last_errors, markup_ctx_tag_name, markup_ctx_attr,
///   markup_arg_as_string).
/// </summary>
/// <remarks>
///   Safe to call with nil. Do not call on strings not allocated by the
///   Markup DLL. Do not call on callback parameter strings (they are
///   stack-local).
/// </remarks>
/// <param name="APtr">
///   The heap-allocated PAnsiChar to free, or nil.
/// </param>
procedure markup_free(const APtr: PAnsiChar); external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Parsing and rendering
// ---------------------------------------------------------------------------

/// <summary>
///   Tokenizes and parses a Markup source string into a reusable document
///   handle. The document can be rendered multiple times with different
///   data payloads without re-parsing.
/// </summary>
/// <remarks>
///   Parsing errors are accumulated on the engine's internal error list
///   and can be retrieved with markup_last_errors or received in real
///   time via TMuApiErrorHandler. The returned TMuDoc must be freed with
///   markup_doc_destroy.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="ASource">
///   Null-terminated UTF-8 Markup template source string.
/// </param>
/// <returns>
///   An opaque TMuDoc handle. Must be freed with markup_doc_destroy.
/// </returns>
function  markup_parse(const AEngine: TMuEngine;
  const ASource: PAnsiChar): TMuDoc; external MARKUP_DLL;

/// <summary>
///   Destroys a parsed document handle and releases all associated memory.
///   The handle becomes invalid after this call.
/// </summary>
/// <remarks>
///   Safe to call with nil. Each TMuDoc must be freed exactly once.
/// </remarks>
/// <param name="ADoc">
///   The document handle returned by markup_parse, or nil.
/// </param>
procedure markup_doc_destroy(const ADoc: TMuDoc); external MARKUP_DLL;

/// <summary>
///   Renders a previously parsed document into an HTML output string,
///   optionally binding external JSON data into the template environment.
/// </summary>
/// <remarks>
///   AData is an optional JSON object string. When provided, it is parsed
///   and bound as the variable 'data' in the template environment,
///   accessible via expressions like {= data.title}. If nil or empty,
///   the template renders without external data. The returned PAnsiChar
///   is heap-allocated and must be freed with markup_free.
/// </remarks>
/// <param name="AEngine">
///   The engine handle. Must be the same engine that produced ADoc.
/// </param>
/// <param name="ADoc">
///   The document handle returned by markup_parse.
/// </param>
/// <param name="AData">
///   Null-terminated UTF-8 JSON object string, or nil for no data.
/// </param>
/// <returns>
///   Null-terminated UTF-8 rendered HTML. Caller must free with
///   markup_free.
/// </returns>
function  markup_render(const AEngine: TMuEngine;
  const ADoc: TMuDoc;
  const AData: PAnsiChar): PAnsiChar; external MARKUP_DLL;

/// <summary>
///   One-shot convenience: parses a Markup source string and renders it
///   to HTML in a single call, optionally binding external JSON data.
/// </summary>
/// <remarks>
///   Equivalent to markup_parse + markup_render + markup_doc_destroy
///   without exposing the intermediate document handle. For templates
///   rendered multiple times with different data, use the two-phase
///   approach instead. The returned PAnsiChar is heap-allocated and must
///   be freed with markup_free.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="ASource">
///   Null-terminated UTF-8 Markup template source string.
/// </param>
/// <param name="AData">
///   Null-terminated UTF-8 JSON object string, or nil for no data.
/// </param>
/// <returns>
///   Null-terminated UTF-8 rendered HTML. Caller must free with
///   markup_free.
/// </returns>
function  markup_convert(const AEngine: TMuEngine;
  const ASource: PAnsiChar;
  const AData: PAnsiChar): PAnsiChar; external MARKUP_DLL;

/// <summary>
///   One-shot conversion that writes the rendered HTML directly to a
///   file, optionally opening it in the default browser.
/// </summary>
/// <remarks>
///   The output filename is forced to a .html extension via
///   TPath.ChangeExtension. Parent directories are created automatically
///   if they do not exist. If AOpenInBrowser is True, the file is opened
///   via ShellExecute after writing.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="ASource">
///   Null-terminated UTF-8 Markup template source string.
/// </param>
/// <param name="AData">
///   Null-terminated UTF-8 JSON object string, or nil for no data.
/// </param>
/// <param name="AFilename">
///   Null-terminated UTF-8 output file path. Extension is forced to
///   .html.
/// </param>
/// <param name="AOpenInBrowser">
///   If True, opens the written file in the default browser.
/// </param>
/// <returns>
///   True if the file was written successfully; False on error.
/// </returns>
function  markup_convert_to_file(const AEngine: TMuEngine;
  const ASource: PAnsiChar;
  const AData: PAnsiChar;
  const AFilename: PAnsiChar;
  const AOpenInBrowser: Boolean): Boolean; external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Validation and error reporting
// ---------------------------------------------------------------------------

/// <summary>
///   Validates a Markup source string by parsing it and collecting all
///   diagnostics without rendering. Returns diagnostics as a JSON array.
/// </summary>
/// <remarks>
///   The returned JSON is an array of objects with "severity", "code",
///   and "message" fields. An empty array "[]" indicates clean
///   validation. The returned PAnsiChar is heap-allocated and must be
///   freed with markup_free.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="ASource">
///   Null-terminated UTF-8 Markup template source string.
/// </param>
/// <returns>
///   Null-terminated UTF-8 JSON array of diagnostics. Caller must free
///   with markup_free.
/// </returns>
function  markup_validate(const AEngine: TMuEngine;
  const ASource: PAnsiChar): PAnsiChar; external MARKUP_DLL;

/// <summary>
///   Returns all diagnostics accumulated since the last error-clearing
///   operation as a JSON array string.
/// </summary>
/// <remarks>
///   Same JSON format as markup_validate. Call after markup_parse,
///   markup_render, or markup_convert to inspect diagnostics. Does not
///   clear the error list. The returned PAnsiChar is heap-allocated and
///   must be freed with markup_free.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <returns>
///   Null-terminated UTF-8 JSON array of diagnostics. Caller must free
///   with markup_free.
/// </returns>
function  markup_last_errors(
  const AEngine: TMuEngine): PAnsiChar; external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Include path management
// ---------------------------------------------------------------------------

/// <summary>
///   Adds a directory to the engine's include search path list. When
///   a template uses {include}, the engine searches these directories in
///   the order they were added to locate the included file.
/// </summary>
/// <remarks>
///   The engine first checks whether the include path is an absolute
///   path that exists directly; if not, it searches each registered
///   include directory in order. Duplicate paths are silently ignored.
///   Circular includes are detected and reported as errors.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="APath">
///   Null-terminated UTF-8 directory path to add to the search list.
/// </param>
procedure markup_add_include_path(const AEngine: TMuEngine;
  const APath: PAnsiChar); external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Options configuration
// ---------------------------------------------------------------------------

/// <summary>
///   Enables or disables pretty-printed HTML output with newlines and
///   indentation for block-level elements.
/// </summary>
/// <remarks>
///   When enabled, block-level tags (div, p, section, h1-h6, table, ul,
///   ol, etc.) receive newlines and 2-space indentation in the output.
///   Inline tags remain on the same line. Code and raw HTML content is
///   never reformatted. Defaults to False.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AEnabled">
///   True to enable pretty-printing; False to disable.
/// </param>
procedure markup_set_pretty_print(const AEngine: TMuEngine;
  const AEnabled: Boolean); external MARKUP_DLL;

/// <summary>
///   Enables or disables strict mode, which reports errors for undefined
///   variables and unknown tags instead of silently producing empty
///   values.
/// </summary>
/// <remarks>
///   When enabled, {get} on an undefined variable produces an error,
///   and unrecognized tags produce errors rather than being silently
///   escaped or passed through. Defaults to False.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AEnabled">
///   True to enable strict mode; False to disable.
/// </param>
procedure markup_set_strict_mode(const AEngine: TMuEngine;
  const AEnabled: Boolean); external MARKUP_DLL;

/// <summary>
///   Enables or disables raw HTML passthrough via the {html} tag. When
///   disabled, {html} content is HTML-escaped instead of emitted raw.
/// </summary>
/// <remarks>
///   Set to False for security-sensitive contexts where untrusted input
///   may contain malicious HTML or scripts. Defaults to True.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AEnabled">
///   True to allow raw HTML; False to escape it.
/// </param>
procedure markup_set_allow_html(const AEngine: TMuEngine;
  const AEnabled: Boolean); external MARKUP_DLL;

/// <summary>
///   Sets the behavior for tags not recognized as built-in Markup tags
///   or standard HTML elements.
/// </summary>
/// <remarks>
///   ABehavior values: 0 = utEscape (show as escaped text, the default),
///   1 = utPassthrough (wrap in &lt;span class="mu-unknown"&gt;).
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="ABehavior">
///   Integer ordinal: 0 = escape, 1 = passthrough.
/// </param>
procedure markup_set_unknown_tag_behavior(const AEngine: TMuEngine;
  const ABehavior: Integer); external MARKUP_DLL;

/// <summary>
///   Sets the maximum number of loop iterations allowed during a single
///   render pass. Prevents infinite loops from exhausting resources.
/// </summary>
/// <remarks>
///   Defaults to 10000. When exceeded, the interpreter adds an error
///   and stops iteration.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AMax">
///   Maximum iteration count.
/// </param>
procedure markup_set_max_iterations(const AEngine: TMuEngine;
  const AMax: Integer); external MARKUP_DLL;

/// <summary>
///   Sets the maximum recursion depth for component calls and nested
///   rendering. Prevents stack overflow from deeply recursive templates.
/// </summary>
/// <remarks>
///   Defaults to 100. When exceeded, the interpreter adds an error and
///   stops recursion.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AMax">
///   Maximum recursion depth.
/// </param>
procedure markup_set_max_recursion(const AEngine: TMuEngine;
  const AMax: Integer); external MARKUP_DLL;

/// <summary>
///   Sets the maximum output buffer size in bytes. Prevents runaway
///   templates from consuming excessive memory.
/// </summary>
/// <remarks>
///   Defaults to 10 MB (10 * 1024 * 1024). When exceeded, the
///   interpreter adds an error and stops emitting output.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AMax">
///   Maximum output size in bytes.
/// </param>
procedure markup_set_max_output_size(const AEngine: TMuEngine;
  const AMax: Integer); external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Custom tag extensibility
// ---------------------------------------------------------------------------

/// <summary>
///   Registers a custom tag handler for the specified tag name. When the
///   interpreter encounters a matching tag during rendering, it invokes
///   AHandler instead of the default built-in processing.
/// </summary>
/// <remarks>
///   Tag names are case-insensitive, stored internally as lowercase.
///   Custom tags take priority over built-in tag processing. Register
///   before calling markup_render or markup_convert.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="ATagName">
///   Null-terminated UTF-8 tag name (case-insensitive).
/// </param>
/// <param name="AHandler">
///   The callback to invoke when the tag is encountered.
/// </param>
/// <param name="AUserData">
///   An arbitrary pointer passed to every invocation of AHandler.
/// </param>
procedure markup_register_tag(const AEngine: TMuEngine;
  const ATagName: PAnsiChar; const AHandler: TMuApiTagHandler;
  const AUserData: Pointer); external MARKUP_DLL;

/// <summary>
///   Returns the tag name of the node currently being rendered, from
///   within a custom tag handler callback.
/// </summary>
/// <remarks>
///   The returned PAnsiChar is heap-allocated and must be freed with
///   markup_free. Only valid inside a TMuApiTagHandler callback.
/// </remarks>
/// <param name="ACtx">
///   The render context handle received by the tag handler callback.
/// </param>
/// <returns>
///   Null-terminated UTF-8 tag name. Caller must free with markup_free.
/// </returns>
function  markup_ctx_tag_name(
  const ACtx: TMuCtx): PAnsiChar; external MARKUP_DLL;

/// <summary>
///   Returns the value of a named attribute on the tag currently being
///   rendered, from within a custom tag handler callback.
/// </summary>
/// <remarks>
///   Returns an empty string if the attribute does not exist. The
///   returned PAnsiChar is heap-allocated and must be freed with
///   markup_free.
/// </remarks>
/// <param name="ACtx">
///   The render context handle received by the tag handler callback.
/// </param>
/// <param name="AAttrName">
///   Null-terminated UTF-8 attribute name to look up.
/// </param>
/// <returns>
///   Null-terminated UTF-8 attribute value, or empty string. Caller
///   must free with markup_free.
/// </returns>
function  markup_ctx_attr(const ACtx: TMuCtx;
  const AAttrName: PAnsiChar): PAnsiChar; external MARKUP_DLL;

/// <summary>
///   Tests whether a named attribute exists on the tag currently being
///   rendered, from within a custom tag handler callback.
/// </summary>
/// <param name="ACtx">
///   The render context handle received by the tag handler callback.
/// </param>
/// <param name="AAttrName">
///   Null-terminated UTF-8 attribute name to test for.
/// </param>
/// <returns>
///   True if the attribute exists; False otherwise.
/// </returns>
function  markup_ctx_has_attr(const ACtx: TMuCtx;
  const AAttrName: PAnsiChar): Boolean; external MARKUP_DLL;

/// <summary>
///   Appends a UTF-8 text string to the current render output buffer
///   from within a custom tag handler callback.
/// </summary>
/// <remarks>
///   Multiple calls within a single handler are concatenated in order.
///   The AText string is consumed immediately and does not need to
///   persist after the call returns.
/// </remarks>
/// <param name="ACtx">
///   The render context handle received by the tag handler callback.
/// </param>
/// <param name="AText">
///   Null-terminated UTF-8 text to append to the output buffer.
/// </param>
procedure markup_ctx_emit(const ACtx: TMuCtx;
  const AText: PAnsiChar); external MARKUP_DLL;

/// <summary>
///   Recursively renders all child nodes of the tag currently being
///   handled, appending their output to the render buffer.
/// </summary>
/// <remarks>
///   If not called, the tag's child content is silently discarded. If
///   called multiple times, the children are rendered multiple times.
///   A typical pattern: emit opening element, call emit_children, emit
///   closing element.
/// </remarks>
/// <param name="ACtx">
///   The render context handle received by the tag handler callback.
/// </param>
procedure markup_ctx_emit_children(
  const ACtx: TMuCtx); external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Custom function extensibility
// ---------------------------------------------------------------------------

/// <summary>
///   Registers a custom function handler callable from template
///   expressions. When the interpreter encounters a matching function
///   call, it invokes AHandler with the evaluated arguments.
/// </summary>
/// <remarks>
///   Function names are case-insensitive, stored as lowercase. Custom
///   functions are called from templates using standard syntax, e.g.
///   {= my_func(arg1, arg2)}. Register before calling markup_render
///   or markup_convert.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AFuncName">
///   Null-terminated UTF-8 function name (case-insensitive).
/// </param>
/// <param name="AHandler">
///   The callback to invoke when the function is called.
/// </param>
/// <param name="AUserData">
///   An arbitrary pointer passed to every invocation of AHandler.
/// </param>
procedure markup_register_function(const AEngine: TMuEngine;
  const AFuncName: PAnsiChar; const AHandler: TMuApiFuncHandler;
  const AUserData: Pointer); external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Function argument accessors
// ---------------------------------------------------------------------------

/// <summary>
///   Returns the argument at the given index as a UTF-8 string, from
///   within a custom function handler callback.
/// </summary>
/// <remarks>
///   Heap-allocated — must be freed with markup_free. Returns empty
///   string on nil AArgs or out-of-bounds index.
/// </remarks>
/// <param name="AArgs">
///   The argument array handle received by the function callback.
/// </param>
/// <param name="AIndex">
///   Zero-based argument index.
/// </param>
/// <returns>
///   Null-terminated UTF-8 string. Caller must free with markup_free.
/// </returns>
function  markup_arg_as_string(const AArgs: TMuArgs;
  const AIndex: Integer): PAnsiChar; external MARKUP_DLL;

/// <summary>
///   Returns the argument at the given index as a 64-bit signed integer.
/// </summary>
/// <remarks>
///   Returns zero on nil AArgs or out-of-bounds index.
/// </remarks>
/// <param name="AArgs">
///   The argument array handle received by the function callback.
/// </param>
/// <param name="AIndex">
///   Zero-based argument index.
/// </param>
/// <returns>
///   The argument value as Int64, or zero on out-of-bounds.
/// </returns>
function  markup_arg_as_integer(const AArgs: TMuArgs;
  const AIndex: Integer): Int64; external MARKUP_DLL;

/// <summary>
///   Returns the argument at the given index as a double-precision float.
/// </summary>
/// <remarks>
///   Returns 0.0 on nil AArgs or out-of-bounds index.
/// </remarks>
/// <param name="AArgs">
///   The argument array handle received by the function callback.
/// </param>
/// <param name="AIndex">
///   Zero-based argument index.
/// </param>
/// <returns>
///   The argument value as Double, or 0.0 on out-of-bounds.
/// </returns>
function  markup_arg_as_float(const AArgs: TMuArgs;
  const AIndex: Integer): Double; external MARKUP_DLL;

/// <summary>
///   Returns the argument at the given index as a Boolean.
/// </summary>
/// <remarks>
///   Returns False on nil AArgs or out-of-bounds index.
/// </remarks>
/// <param name="AArgs">
///   The argument array handle received by the function callback.
/// </param>
/// <param name="AIndex">
///   Zero-based argument index.
/// </param>
/// <returns>
///   The argument value as Boolean, or False on out-of-bounds.
/// </returns>
function  markup_arg_as_boolean(const AArgs: TMuArgs;
  const AIndex: Integer): Boolean; external MARKUP_DLL;

/// <summary>
///   Returns the argument at the given index as a 64-bit unsigned integer.
/// </summary>
/// <remarks>
///   Returns zero on nil AArgs or out-of-bounds index.
/// </remarks>
/// <param name="AArgs">
///   The argument array handle received by the function callback.
/// </param>
/// <param name="AIndex">
///   Zero-based argument index.
/// </param>
/// <returns>
///   The argument value as UInt64, or zero on out-of-bounds.
/// </returns>
function  markup_arg_as_uint64(const AArgs: TMuArgs;
  const AIndex: Integer): UInt64; external MARKUP_DLL;

/// <summary>
///   Returns the number of arguments in the argument array, from within
///   a custom function handler callback.
/// </summary>
/// <remarks>
///   Returns zero if AArgs is nil. Valid indices are
///   0..markup_arg_count-1.
/// </remarks>
/// <param name="AArgs">
///   The argument array handle received by the function callback.
/// </param>
/// <returns>
///   The number of arguments (zero or more).
/// </returns>
function  markup_arg_count(
  const AArgs: TMuArgs): Integer; external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Function result constructors
// ---------------------------------------------------------------------------

/// <summary>
///   Constructs a string-typed return value for a custom function handler.
/// </summary>
/// <remarks>
///   The engine takes ownership — do not free the returned handle. The
///   AValue string is copied during construction.
/// </remarks>
/// <param name="AValue">
///   Null-terminated UTF-8 string value.
/// </param>
/// <returns>
///   An opaque PMuResult handle. The engine takes ownership.
/// </returns>
function  markup_result_string(
  const AValue: PAnsiChar): PMuResult; external MARKUP_DLL;

/// <summary>
///   Constructs an integer-typed return value for a custom function handler.
/// </summary>
/// <remarks>
///   The engine takes ownership — do not free the returned handle.
/// </remarks>
/// <param name="AValue">
///   The 64-bit signed integer value.
/// </param>
/// <returns>
///   An opaque PMuResult handle. The engine takes ownership.
/// </returns>
function  markup_result_integer(
  const AValue: Int64): PMuResult; external MARKUP_DLL;

/// <summary>
///   Constructs a float-typed return value for a custom function handler.
/// </summary>
/// <remarks>
///   The engine takes ownership — do not free the returned handle.
/// </remarks>
/// <param name="AValue">
///   The double-precision floating-point value.
/// </param>
/// <returns>
///   An opaque PMuResult handle. The engine takes ownership.
/// </returns>
function  markup_result_float(
  const AValue: Double): PMuResult; external MARKUP_DLL;

/// <summary>
///   Constructs a boolean-typed return value for a custom function handler.
/// </summary>
/// <remarks>
///   The engine takes ownership — do not free the returned handle.
/// </remarks>
/// <param name="AValue">
///   The Boolean value.
/// </param>
/// <returns>
///   An opaque PMuResult handle. The engine takes ownership.
/// </returns>
function  markup_result_boolean(
  const AValue: Boolean): PMuResult; external MARKUP_DLL;

/// <summary>
///   Constructs a 64-bit unsigned integer-typed return value for a
///   custom function handler.
/// </summary>
/// <remarks>
///   The engine takes ownership — do not free the returned handle.
/// </remarks>
/// <param name="AValue">
///   The 64-bit unsigned integer value.
/// </param>
/// <returns>
///   An opaque PMuResult handle. The engine takes ownership.
/// </returns>
function  markup_result_uint64(
  const AValue: UInt64): PMuResult; external MARKUP_DLL;

/// <summary>
///   Constructs a nil-typed return value for a custom function handler.
///   Use when the function has no meaningful return value.
/// </summary>
/// <remarks>
///   The engine takes ownership — do not free the returned handle. A nil
///   value evaluates as falsy in expressions and renders as empty string.
/// </remarks>
/// <returns>
///   An opaque PMuResult handle representing nil. The engine takes
///   ownership.
/// </returns>
function  markup_result_nil(): PMuResult; external MARKUP_DLL;

// ---------------------------------------------------------------------------
// Error and status handler registration
// ---------------------------------------------------------------------------

/// <summary>
///   Registers a callback that receives diagnostic notifications in real
///   time during parsing, rendering, validation, or include resolution.
///   Pass nil for AHandler to unregister.
/// </summary>
/// <remarks>
///   The callback is invoked synchronously. Registering a handler does
///   not suppress accumulation of diagnostics on the engine's internal
///   error list. Only one handler at a time — a new registration
///   replaces the previous one.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AHandler">
///   The callback for each diagnostic, or nil to unregister.
/// </param>
/// <param name="AUserData">
///   An arbitrary pointer passed to every invocation of AHandler.
/// </param>
procedure markup_set_error_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiErrorHandler;
  const AUserData: Pointer); external MARKUP_DLL;

/// <summary>
///   Registers a callback that receives pipeline status messages during
///   engine operations. Pass nil for AHandler to unregister.
/// </summary>
/// <remarks>
///   The callback is invoked synchronously. Only one handler at a time —
///   a new registration replaces the previous one.
/// </remarks>
/// <param name="AEngine">
///   The engine handle returned by markup_create.
/// </param>
/// <param name="AHandler">
///   The callback for status messages, or nil to unregister.
/// </param>
/// <param name="AUserData">
///   An arbitrary pointer passed to every invocation of AHandler.
/// </param>
procedure markup_set_status_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiStatusHandler;
  const AUserData: Pointer); external MARKUP_DLL;

implementation

end.