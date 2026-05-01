/*=============================================================================
  Markup(TM) - Document Authoring Language
  C/C++ Single-Header Dynamic Loader

  Copyright (c) 2026-present tinyBigGAMES(TM) LLC
  All Rights Reserved.

  See LICENSE for license information
=============================================================================*/

/**
 * \file Markup.h
 *
 * \brief
 *   C/C++ single-header dynamic loader for Markup.dll. Provides complete
 *   access to the Markup document authoring and template rendering pipeline
 *   through opaque handles and flat function calls with no dependencies on
 *   Markup internals.
 *
 * \par String contract
 *   All strings crossing the DLL boundary are null-terminated UTF-8. Strings
 *   \e returned by the DLL are heap-allocated and the caller \b must free
 *   them with markup_free() when no longer needed. Failing to call
 *   markup_free() on returned strings will leak memory. Strings passed
 *   \e to callback functions (MuErrorHandler, MuStatusHandler) point into
 *   stack-local buffers and are valid only for the duration of that callback
 *   invocation -- copy immediately if you need the value to persist.
 *
 * \par Pipeline overview
 *   The Markup pipeline decomposes document processing into two discrete
 *   phases: markup_parse() (tokenize and parse a Markup source string into
 *   a reusable MuDoc handle) and markup_render() (interpret the parsed
 *   document tree and produce an HTML output string). A parsed MuDoc may be
 *   rendered multiple times with different data payloads without re-parsing.
 *   The convenience function markup_convert() combines both phases into a
 *   single call for one-shot usage. markup_convert_to_file() extends this
 *   further by writing the rendered HTML directly to disk with optional
 *   browser launch.
 *
 * \par Template data binding
 *   Both markup_render() and markup_convert() accept an optional \c data
 *   parameter -- a JSON string that is parsed internally and bound into the
 *   template environment as the variable \c data. The JSON must represent an
 *   object (map); if NULL or empty, the template renders without external
 *   data.
 *
 * \par One-shot conversion example
 * \code{.c}
 *   #define MARKUP_IMPLEMENTATION
 *   #include "Markup.h"
 *
 *   int main(void) {
 *       if (!markup_load("Markup.dll")) return 1;
 *
 *       MuEngine engine = markup_create();
 *       char* html = markup_convert(engine, "{h1}Hello, World!{/h1}", NULL);
 *       printf("%s\n", html);
 *       markup_free(html);
 *       markup_destroy(engine);
 *
 *       markup_unload();
 *       return 0;
 *   }
 * \endcode
 *
 * \par Parse-then-render with data binding
 * \code{.c}
 *   MuEngine engine = markup_create();
 *   MuDoc doc = markup_parse(engine, "{h1}{= data.title}{/h1}");
 *   char* html = markup_render(engine, doc, "{\"title\":\"Greetings\"}");
 *   printf("%s\n", html);   // <h1>Greetings</h1>
 *   markup_free(html);
 *   markup_doc_destroy(doc);
 *   markup_destroy(engine);
 * \endcode
 *
 * \par Convert to file with browser launch
 * \code{.c}
 *   MuEngine engine = markup_create();
 *   markup_convert_to_file(engine,
 *       "{h1}Report{/h1}{p}Generated.{/p}",
 *       NULL, "output\\report", 1);  // opens in browser
 *   markup_destroy(engine);
 * \endcode
 *
 * \par Engine options
 *   The engine exposes several configurable options via the markup_set_*
 *   functions. These include markup_set_pretty_print() (formatted HTML output
 *   with indentation), markup_set_strict_mode() (errors on undefined
 *   variables and unknown tags), markup_set_allow_html() (control raw HTML
 *   passthrough for security), markup_set_unknown_tag_behavior() (escape vs
 *   span-wrap unknown tags), and safety limits (markup_set_max_iterations(),
 *   markup_set_max_recursion(), markup_set_max_output_size()).
 *
 * \code{.c}
 *   MuEngine engine = markup_create();
 *   markup_set_pretty_print(engine, 1);
 *   markup_set_strict_mode(engine, 1);
 *   markup_set_allow_html(engine, 0);
 *   // ... convert or render ...
 *   markup_destroy(engine);
 * \endcode
 *
 * \par Custom tag handler
 *   Register a handler with markup_register_tag(), then use the
 *   markup_ctx_* functions inside the callback to query attributes, emit
 *   output, and walk child nodes. The context handle (MuCtx) is valid only
 *   for the duration of the callback invocation.
 *
 * \code{.c}
 *   void my_alert_handler(MuCtx ctx, void* user_data) {
 *       char* level = markup_ctx_attr(ctx, "level");
 *       markup_ctx_emit(ctx, "<div class=\"alert-");
 *       markup_ctx_emit(ctx, level);
 *       markup_ctx_emit(ctx, "\">");
 *       markup_ctx_emit_children(ctx);
 *       markup_ctx_emit(ctx, "</div>");
 *       markup_free(level);
 *   }
 * \endcode
 *
 * \par Custom function handler
 *   Register a function with markup_register_function(), then use
 *   markup_arg_* to read typed arguments and return a MuResult via the
 *   markup_result_* constructors. The returned MuResult is owned by the
 *   engine -- do not free it.
 *
 * \code{.c}
 *   MuResult my_upper_func(int32_t arg_count, MuArgs args,
 *                          void* user_data) {
 *       char* str = markup_arg_as_string(args, 0);
 *       // ... convert str to uppercase ...
 *       MuResult r = markup_result_string(upper);
 *       markup_free(str);
 *       return r;
 *   }
 * \endcode
 *
 * \par Validation and error reporting
 *   markup_validate() parses the source, collects all diagnostics, and
 *   returns them as a JSON array. markup_last_errors() returns the
 *   diagnostics from the most recent operation. Both return heap-allocated
 *   strings that must be freed with markup_free(). The JSON schema is:
 *
 * \code{.json}
 *   [
 *     {
 *       "severity": "error",
 *       "code": "MS-T007",
 *       "message": "Include file not found: 'header.mu'"
 *     }
 *   ]
 * \endcode
 *
 * \par Error severity ordinals
 *   When using MuErrorHandler, the \c severity parameter is an integer
 *   ordinal: 0 = Hint, 1 = Warning, 2 = Error, 3 = Fatal.
 *
 * \par Thread safety
 *   Each MuEngine is an independent instance with its own lexer, parser,
 *   interpreter, environment, and error list. No shared mutable state exists
 *   between instances. Multiple engine handles may be used concurrently from
 *   different threads. A single engine handle must not be accessed from
 *   multiple threads simultaneously. MuDoc handles are likewise independent
 *   objects; a MuDoc obtained from one engine must only be rendered by that
 *   same engine.
 *
 * \par Platform
 *   Windows 64-bit only.
 *
 * \par Usage
 *   In \b one .c or .cpp file, before including this header:
 *   \code{.c}
 *     #define MARKUP_IMPLEMENTATION
 *     #include "Markup.h"
 *   \endcode
 *   In all other files, just include normally:
 *   \code{.c}
 *     #include "Markup.h"
 *   \endcode
 *   Then at runtime, call markup_load() to load the DLL and resolve all
 *   function pointers. Call markup_unload() when finished.
 */

#ifndef MARKUP_H
#define MARKUP_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---------------------------------------------------------------------------
   Opaque handle types
   --------------------------------------------------------------------------- */

/**
 * \brief Boolean type used by the Markup API (0 = false, non-zero = true).
 */
typedef int32_t MuBool;

/**
 * \brief Opaque handle to a Markup engine instance.
 *
 * Returned by markup_create() and accepted by all API functions that
 * operate on an engine. Must be freed with markup_destroy() when no
 * longer needed.
 *
 * \remarks
 *   Each engine owns its own lexer, parser, interpreter, built-in
 *   function registry, custom tag registry, include path list, options,
 *   and error list. Creating multiple engines is safe -- they share no
 *   mutable state.
 */
typedef void* MuEngine;

/**
 * \brief Opaque handle to a parsed Markup document.
 *
 * Returned by markup_parse() and accepted by markup_render(). Represents
 * a fully parsed AST ready for one or more render passes.
 *
 * \remarks
 *   Must be freed with markup_doc_destroy() when no longer needed. A
 *   MuDoc obtained from one engine should only be rendered by that same
 *   engine, as interpreter state (custom tags, functions, include paths)
 *   is held on the engine.
 */
typedef void* MuDoc;

/**
 * \brief Opaque handle to a render context, passed to custom tag handler
 *        callbacks registered via markup_register_tag().
 *
 * Provides access to the current tag's name, attributes, output buffer,
 * and child-node traversal.
 *
 * \remarks
 *   Valid only for the duration of the tag handler callback invocation.
 *   Do not store this handle beyond the callback scope. Use the
 *   markup_ctx_* functions to interact with it.
 */
typedef void* MuCtx;

/**
 * \brief Opaque handle to a function argument array, passed to custom
 *        function handler callbacks registered via
 *        markup_register_function().
 *
 * \remarks
 *   Valid only during the callback invocation. Use markup_arg_count()
 *   to determine the number of arguments, and markup_arg_as_* to read
 *   individual arguments by zero-based index.
 */
typedef void* MuArgs;

/**
 * \brief Opaque handle to a function return value.
 *
 * Returned from MuFuncHandler callbacks. Constructed using the
 * markup_result_* factory functions. The engine takes ownership --
 * do not free it.
 *
 * \remarks
 *   A nil value evaluates as falsy in expressions and renders as empty
 *   string.
 */
typedef void* MuResult;

/* ---------------------------------------------------------------------------
   Callback types
   --------------------------------------------------------------------------- */

/**
 * \brief Callback for custom tag handlers registered via
 *        markup_register_tag().
 *
 * \remarks
 *   \p ctx is valid only during the callback. Use markup_ctx_tag_name() to
 *   retrieve the tag name, markup_ctx_attr() / markup_ctx_has_attr() to
 *   query attributes, markup_ctx_emit() to write output, and
 *   markup_ctx_emit_children() to recursively render child nodes.
 *   Strings returned by markup_ctx_tag_name() and markup_ctx_attr() are
 *   heap-allocated and must be freed with markup_free().
 *
 * \param ctx        Opaque render context handle. Valid only during the
 *                   callback.
 * \param user_data  The user data pointer passed to markup_register_tag().
 *                   May be NULL.
 */
typedef void      (*MuTagHandler)(MuCtx ctx, void* user_data);

/**
 * \brief Callback for custom function handlers registered via
 *        markup_register_function().
 *
 * Return a MuResult via the markup_result_* constructors. The engine takes
 * ownership of the returned handle -- do not free it.
 *
 * \remarks
 *   \p args is valid only during the callback. Use markup_arg_count() and
 *   markup_arg_as_*() to read arguments. Strings returned by
 *   markup_arg_as_string() must be freed with markup_free() inside the
 *   callback. Return markup_result_nil() for no return value.
 *
 * \param arg_count  Number of arguments. Matches markup_arg_count(\p args).
 * \param args       Opaque argument array handle. Valid only during the
 *                   callback.
 * \param user_data  The user data pointer passed to
 *                   markup_register_function().
 *
 * \return An opaque MuResult handle. The engine takes ownership.
 */
typedef MuResult  (*MuFuncHandler)(int32_t arg_count, MuArgs args,
                                   void* user_data);

/**
 * \brief Callback for real-time error reporting during parsing, rendering,
 *        or validation.
 *
 * \remarks
 *   \p code and \p message are stack-local UTF-8 buffers valid only for the
 *   duration of this callback. Copy immediately if you need the values to
 *   persist. Register with markup_set_error_handler(). Pass NULL to
 *   unregister.
 *
 * \param severity   Integer ordinal: 0 = Hint, 1 = Warning, 2 = Error,
 *                   3 = Fatal.
 * \param code       Null-terminated UTF-8 error code (e.g. "MS-T001").
 *                   Stack-local.
 * \param message    Null-terminated UTF-8 diagnostic message. Stack-local.
 * \param user_data  The user data pointer passed to
 *                   markup_set_error_handler().
 */
typedef void      (*MuErrorHandler)(int32_t severity, const char* code,
                                    const char* message, void* user_data);

/**
 * \brief Callback for pipeline status messages during parsing, rendering,
 *        include resolution, or other engine operations.
 *
 * \remarks
 *   \p text is a stack-local UTF-8 buffer valid only during this callback.
 *   Copy immediately if needed. Register with markup_set_status_handler().
 *   Pass NULL to unregister.
 *
 * \param text       Null-terminated UTF-8 status message. Stack-local.
 * \param user_data  The user data pointer passed to
 *                   markup_set_status_handler().
 */
typedef void      (*MuStatusHandler)(const char* text, void* user_data);

/* ---------------------------------------------------------------------------
   Function pointer types
   --------------------------------------------------------------------------- */

/* Lifecycle */
/** \brief Type for markup_create(). */
typedef MuEngine    (*pfn_markup_create)(void);
/** \brief Type for markup_destroy(). */
typedef void        (*pfn_markup_destroy)(MuEngine engine);
/** \brief Type for markup_version(). */
typedef const char* (*pfn_markup_version)(void);
/** \brief Type for markup_free(). */
typedef void        (*pfn_markup_free)(const char* ptr);

/* Parsing and rendering */
/** \brief Type for markup_parse(). */
typedef MuDoc       (*pfn_markup_parse)(MuEngine engine, const char* source);
/** \brief Type for markup_doc_destroy(). */
typedef void        (*pfn_markup_doc_destroy)(MuDoc doc);
/** \brief Type for markup_render(). */
typedef char*       (*pfn_markup_render)(MuEngine engine, MuDoc doc,
                                         const char* data);
/** \brief Type for markup_convert(). */
typedef char*       (*pfn_markup_convert)(MuEngine engine, const char* source,
                                          const char* data);
/** \brief Type for markup_convert_to_file(). */
typedef MuBool      (*pfn_markup_convert_to_file)(MuEngine engine,
                                                  const char* source,
                                                  const char* data,
                                                  const char* filename,
                                                  MuBool open_in_browser);

/* Validation and error reporting */
/** \brief Type for markup_validate(). */
typedef char*       (*pfn_markup_validate)(MuEngine engine,
                                           const char* source);
/** \brief Type for markup_last_errors(). */
typedef char*       (*pfn_markup_last_errors)(MuEngine engine);

/* Include paths */
/** \brief Type for markup_add_include_path(). */
typedef void        (*pfn_markup_add_include_path)(MuEngine engine,
                                                   const char* path);

/* Options */
/** \brief Type for markup_set_pretty_print(). */
typedef void        (*pfn_markup_set_pretty_print)(MuEngine engine,
                                                   MuBool enabled);
/** \brief Type for markup_set_strict_mode(). */
typedef void        (*pfn_markup_set_strict_mode)(MuEngine engine,
                                                  MuBool enabled);
/** \brief Type for markup_set_allow_html(). */
typedef void        (*pfn_markup_set_allow_html)(MuEngine engine,
                                                 MuBool enabled);
/** \brief Type for markup_set_unknown_tag_behavior(). */
typedef void        (*pfn_markup_set_unknown_tag_behavior)(MuEngine engine,
                                                          int32_t behavior);
/** \brief Type for markup_set_max_iterations(). */
typedef void        (*pfn_markup_set_max_iterations)(MuEngine engine,
                                                     int32_t max_val);
/** \brief Type for markup_set_max_recursion(). */
typedef void        (*pfn_markup_set_max_recursion)(MuEngine engine,
                                                    int32_t max_val);
/** \brief Type for markup_set_max_output_size(). */
typedef void        (*pfn_markup_set_max_output_size)(MuEngine engine,
                                                      int32_t max_val);

/* Custom tag extensibility */
/** \brief Type for markup_register_tag(). */
typedef void        (*pfn_markup_register_tag)(MuEngine engine,
                                               const char* tag_name,
                                               MuTagHandler handler,
                                               void* user_data);
/** \brief Type for markup_ctx_tag_name(). */
typedef char*       (*pfn_markup_ctx_tag_name)(MuCtx ctx);
/** \brief Type for markup_ctx_attr(). */
typedef char*       (*pfn_markup_ctx_attr)(MuCtx ctx, const char* attr_name);
/** \brief Type for markup_ctx_has_attr(). */
typedef MuBool      (*pfn_markup_ctx_has_attr)(MuCtx ctx,
                                               const char* attr_name);
/** \brief Type for markup_ctx_emit(). */
typedef void        (*pfn_markup_ctx_emit)(MuCtx ctx, const char* text);
/** \brief Type for markup_ctx_emit_children(). */
typedef void        (*pfn_markup_ctx_emit_children)(MuCtx ctx);

/* Custom function extensibility */
/** \brief Type for markup_register_function(). */
typedef void        (*pfn_markup_register_function)(MuEngine engine,
                                                    const char* func_name,
                                                    MuFuncHandler handler,
                                                    void* user_data);

/* Function argument accessors */
/** \brief Type for markup_arg_as_string(). */
typedef char*       (*pfn_markup_arg_as_string)(MuArgs args, int32_t index);
/** \brief Type for markup_arg_as_integer(). */
typedef int64_t     (*pfn_markup_arg_as_integer)(MuArgs args, int32_t index);
/** \brief Type for markup_arg_as_float(). */
typedef double      (*pfn_markup_arg_as_float)(MuArgs args, int32_t index);
/** \brief Type for markup_arg_as_boolean(). */
typedef MuBool      (*pfn_markup_arg_as_boolean)(MuArgs args, int32_t index);
/** \brief Type for markup_arg_as_uint64(). */
typedef uint64_t    (*pfn_markup_arg_as_uint64)(MuArgs args, int32_t index);
/** \brief Type for markup_arg_count(). */
typedef int32_t     (*pfn_markup_arg_count_t)(MuArgs args);

/* Function result constructors */
/** \brief Type for markup_result_string(). */
typedef MuResult    (*pfn_markup_result_string)(const char* value);
/** \brief Type for markup_result_integer(). */
typedef MuResult    (*pfn_markup_result_integer)(int64_t value);
/** \brief Type for markup_result_float(). */
typedef MuResult    (*pfn_markup_result_float)(double value);
/** \brief Type for markup_result_boolean(). */
typedef MuResult    (*pfn_markup_result_boolean)(MuBool value);
/** \brief Type for markup_result_uint64(). */
typedef MuResult    (*pfn_markup_result_uint64)(uint64_t value);
/** \brief Type for markup_result_nil(). */
typedef MuResult    (*pfn_markup_result_nil)(void);

/* Error and status handler registration */
/** \brief Type for markup_set_error_handler(). */
typedef void        (*pfn_markup_set_error_handler)(MuEngine engine,
                                                    MuErrorHandler handler,
                                                    void* user_data);
/** \brief Type for markup_set_status_handler(). */
typedef void        (*pfn_markup_set_status_handler)(MuEngine engine,
                                                     MuStatusHandler handler,
                                                     void* user_data);

/* ---------------------------------------------------------------------------
   Global function pointers -- set by markup_load(), cleared by markup_unload()
   --------------------------------------------------------------------------- */

/* Lifecycle */

/**
 * \brief Creates a new Markup engine instance and returns its opaque handle.
 *
 * The engine is fully independent, owning its own lexer, parser,
 * interpreter, built-in registry, custom tag registry, include path
 * list, and error list. Multiple engines may coexist.
 *
 * \remarks
 *   Free with markup_destroy() when no longer needed.
 *
 * \return An opaque MuEngine handle. Must be freed with markup_destroy().
 */
extern pfn_markup_create                    markup_create;

/**
 * \brief Destroys a Markup engine instance and releases all associated
 *        memory. The handle becomes invalid after this call.
 *
 * \remarks
 *   Safe to call with NULL. Any MuDoc handles previously obtained via
 *   markup_parse() remain valid and must be freed separately with
 *   markup_doc_destroy(), but should not be rendered after the engine
 *   is destroyed.
 *
 * \param engine  The engine handle returned by markup_create(), or NULL.
 */
extern pfn_markup_destroy                   markup_destroy;

/**
 * \brief Returns the version string of the Markup library (e.g. "1.0.0").
 *
 * \remarks
 *   The returned pointer refers to a static internal buffer that is valid
 *   for the lifetime of the DLL. Do \b not free it with markup_free().
 *   The version is read from the DLL's embedded PE version resource.
 *
 * \return Null-terminated UTF-8 version string. Do not free.
 */
extern pfn_markup_version                   markup_version;

/**
 * \brief Frees a heap-allocated string returned by a Markup API function.
 *
 * Applicable to strings returned by markup_render(), markup_convert(),
 * markup_validate(), markup_last_errors(), markup_ctx_tag_name(),
 * markup_ctx_attr(), and markup_arg_as_string().
 *
 * \remarks
 *   Safe to call with NULL. Do not call on strings not allocated by the
 *   Markup DLL. Do not call on callback parameter strings (they are
 *   stack-local).
 *
 * \param ptr  The heap-allocated string to free, or NULL.
 */
extern pfn_markup_free                      markup_free;

/* Parsing and rendering */

/**
 * \brief Tokenizes and parses a Markup source string into a reusable
 *        document handle.
 *
 * The document can be rendered multiple times with different data payloads
 * without re-parsing.
 *
 * \remarks
 *   Parsing errors are accumulated on the engine's internal error list
 *   and can be retrieved with markup_last_errors() or received in real
 *   time via MuErrorHandler. The returned MuDoc must be freed with
 *   markup_doc_destroy().
 *
 * \param engine  The engine handle returned by markup_create().
 * \param source  Null-terminated UTF-8 Markup template source string.
 *
 * \return An opaque MuDoc handle. Must be freed with markup_doc_destroy().
 */
extern pfn_markup_parse                     markup_parse;

/**
 * \brief Destroys a parsed document handle and releases all associated
 *        memory. The handle becomes invalid after this call.
 *
 * \remarks
 *   Safe to call with NULL. Each MuDoc must be freed exactly once.
 *
 * \param doc  The document handle returned by markup_parse(), or NULL.
 */
extern pfn_markup_doc_destroy               markup_doc_destroy;

/**
 * \brief Renders a previously parsed document into an HTML output string,
 *        optionally binding external JSON data into the template
 *        environment.
 *
 * \remarks
 *   \p data is an optional JSON object string. When provided, it is parsed
 *   and bound as the variable \c data in the template environment,
 *   accessible via expressions like \c {=\ data.title}. If NULL or empty,
 *   the template renders without external data. The returned string is
 *   heap-allocated and must be freed with markup_free().
 *
 * \param engine  The engine handle. Must be the same engine that produced
 *                \p doc.
 * \param doc     The document handle returned by markup_parse().
 * \param data    Null-terminated UTF-8 JSON object string, or NULL for
 *                no data.
 *
 * \return Null-terminated UTF-8 rendered HTML. Caller must free with
 *         markup_free().
 */
extern pfn_markup_render                    markup_render;

/**
 * \brief One-shot convenience: parses a Markup source string and renders
 *        it to HTML in a single call, optionally binding external JSON data.
 *
 * \remarks
 *   Equivalent to markup_parse() + markup_render() + markup_doc_destroy()
 *   without exposing the intermediate document handle. For templates
 *   rendered multiple times with different data, use the two-phase
 *   approach instead. The returned string is heap-allocated and must be
 *   freed with markup_free().
 *
 * \param engine  The engine handle returned by markup_create().
 * \param source  Null-terminated UTF-8 Markup template source string.
 * \param data    Null-terminated UTF-8 JSON object string, or NULL for
 *                no data.
 *
 * \return Null-terminated UTF-8 rendered HTML. Caller must free with
 *         markup_free().
 */
extern pfn_markup_convert                   markup_convert;

/**
 * \brief One-shot conversion that writes the rendered HTML directly to a
 *        file, optionally opening it in the default browser.
 *
 * \remarks
 *   The output filename is forced to a .html extension. Parent directories
 *   are created automatically if they do not exist. If \p open_in_browser
 *   is non-zero, the file is opened via ShellExecute after writing.
 *
 * \param engine           The engine handle returned by markup_create().
 * \param source           Null-terminated UTF-8 Markup template source.
 * \param data             Null-terminated UTF-8 JSON object string, or
 *                         NULL for no data.
 * \param filename         Null-terminated UTF-8 output file path.
 *                         Extension is forced to .html.
 * \param open_in_browser  Non-zero to open the written file in the
 *                         default browser.
 *
 * \return Non-zero if the file was written successfully; 0 on error.
 */
extern pfn_markup_convert_to_file           markup_convert_to_file;

/* Validation and error reporting */

/**
 * \brief Validates a Markup source string by parsing it and collecting all
 *        diagnostics without rendering. Returns diagnostics as a JSON array.
 *
 * \remarks
 *   The returned JSON is an array of objects with "severity", "code", and
 *   "message" fields. An empty array "[]" indicates clean validation. The
 *   returned string is heap-allocated and must be freed with markup_free().
 *
 * \param engine  The engine handle returned by markup_create().
 * \param source  Null-terminated UTF-8 Markup template source string.
 *
 * \return Null-terminated UTF-8 JSON array of diagnostics. Caller must
 *         free with markup_free().
 */
extern pfn_markup_validate                  markup_validate;

/**
 * \brief Returns all diagnostics accumulated since the last error-clearing
 *        operation as a JSON array string.
 *
 * \remarks
 *   Same JSON format as markup_validate(). Call after markup_parse(),
 *   markup_render(), or markup_convert() to inspect diagnostics. Does not
 *   clear the error list. The returned string is heap-allocated and must
 *   be freed with markup_free().
 *
 * \param engine  The engine handle returned by markup_create().
 *
 * \return Null-terminated UTF-8 JSON array of diagnostics. Caller must
 *         free with markup_free().
 */
extern pfn_markup_last_errors               markup_last_errors;

/* Include paths */

/**
 * \brief Adds a directory to the engine's include search path list.
 *
 * When a template uses \c {include}, the engine searches these directories
 * in the order they were added to locate the included file.
 *
 * \remarks
 *   The engine first checks whether the include path is an absolute path
 *   that exists directly; if not, it searches each registered include
 *   directory in order. Duplicate paths are silently ignored. Circular
 *   includes are detected and reported as errors.
 *
 * \param engine  The engine handle returned by markup_create().
 * \param path    Null-terminated UTF-8 directory path to add to the
 *                search list.
 */
extern pfn_markup_add_include_path          markup_add_include_path;

/* Options */

/**
 * \brief Enables or disables pretty-printed HTML output with newlines and
 *        indentation for block-level elements.
 *
 * \remarks
 *   When enabled, block-level tags (div, p, section, h1-h6, table, ul,
 *   ol, etc.) receive newlines and 2-space indentation in the output.
 *   Inline tags remain on the same line. Code and raw HTML content is
 *   never reformatted. Defaults to false (0).
 *
 * \param engine   The engine handle returned by markup_create().
 * \param enabled  Non-zero to enable pretty-printing; 0 to disable.
 */
extern pfn_markup_set_pretty_print          markup_set_pretty_print;

/**
 * \brief Enables or disables strict mode, which reports errors for
 *        undefined variables and unknown tags instead of silently
 *        producing empty values.
 *
 * \remarks
 *   When enabled, \c {get} on an undefined variable produces an error,
 *   and unrecognized tags produce errors rather than being silently
 *   escaped or passed through. Defaults to false (0).
 *
 * \param engine   The engine handle returned by markup_create().
 * \param enabled  Non-zero to enable strict mode; 0 to disable.
 */
extern pfn_markup_set_strict_mode           markup_set_strict_mode;

/**
 * \brief Enables or disables raw HTML passthrough via the \c {html} tag.
 *
 * When disabled, \c {html} content is HTML-escaped instead of emitted raw.
 *
 * \remarks
 *   Set to 0 for security-sensitive contexts where untrusted input may
 *   contain malicious HTML or scripts. Defaults to true (non-zero).
 *
 * \param engine   The engine handle returned by markup_create().
 * \param enabled  Non-zero to allow raw HTML; 0 to escape it.
 */
extern pfn_markup_set_allow_html            markup_set_allow_html;

/**
 * \brief Sets the behavior for tags not recognized as built-in Markup tags
 *        or standard HTML elements.
 *
 * \remarks
 *   \p behavior values: 0 = escape (show as escaped text, the default),
 *   1 = passthrough (wrap in \c &lt;span\ class="mu-unknown"&gt;).
 *
 * \param engine    The engine handle returned by markup_create().
 * \param behavior  Integer ordinal: 0 = escape, 1 = passthrough.
 */
extern pfn_markup_set_unknown_tag_behavior  markup_set_unknown_tag_behavior;

/**
 * \brief Sets the maximum number of loop iterations allowed during a
 *        single render pass. Prevents infinite loops from exhausting
 *        resources.
 *
 * \remarks
 *   Defaults to 10000. When exceeded, the interpreter adds an error
 *   and stops iteration.
 *
 * \param engine   The engine handle returned by markup_create().
 * \param max_val  Maximum iteration count.
 */
extern pfn_markup_set_max_iterations        markup_set_max_iterations;

/**
 * \brief Sets the maximum recursion depth for component calls and nested
 *        rendering. Prevents stack overflow from deeply recursive
 *        templates.
 *
 * \remarks
 *   Defaults to 100. When exceeded, the interpreter adds an error and
 *   stops recursion.
 *
 * \param engine   The engine handle returned by markup_create().
 * \param max_val  Maximum recursion depth.
 */
extern pfn_markup_set_max_recursion         markup_set_max_recursion;

/**
 * \brief Sets the maximum output buffer size in bytes. Prevents runaway
 *        templates from consuming excessive memory.
 *
 * \remarks
 *   Defaults to 10 MB (10 * 1024 * 1024). When exceeded, the interpreter
 *   adds an error and stops emitting output.
 *
 * \param engine   The engine handle returned by markup_create().
 * \param max_val  Maximum output size in bytes.
 */
extern pfn_markup_set_max_output_size       markup_set_max_output_size;

/* Custom tag extensibility */

/**
 * \brief Registers a custom tag handler for the specified tag name.
 *
 * When the interpreter encounters a matching tag during rendering, it
 * invokes \p handler instead of the default built-in processing.
 *
 * \remarks
 *   Tag names are case-insensitive, stored internally as lowercase.
 *   Custom tags take priority over built-in tag processing. Register
 *   before calling markup_render() or markup_convert().
 *
 * \param engine     The engine handle returned by markup_create().
 * \param tag_name   Null-terminated UTF-8 tag name (case-insensitive).
 * \param handler    The callback to invoke when the tag is encountered.
 * \param user_data  An arbitrary pointer passed to every invocation of
 *                   \p handler.
 */
extern pfn_markup_register_tag              markup_register_tag;

/**
 * \brief Returns the tag name of the node currently being rendered, from
 *        within a custom tag handler callback.
 *
 * \remarks
 *   The returned string is heap-allocated and must be freed with
 *   markup_free(). Only valid inside a MuTagHandler callback.
 *
 * \param ctx  The render context handle received by the tag handler
 *             callback.
 *
 * \return Null-terminated UTF-8 tag name. Caller must free with
 *         markup_free().
 */
extern pfn_markup_ctx_tag_name              markup_ctx_tag_name;

/**
 * \brief Returns the value of a named attribute on the tag currently being
 *        rendered, from within a custom tag handler callback.
 *
 * \remarks
 *   Returns an empty string if the attribute does not exist. The returned
 *   string is heap-allocated and must be freed with markup_free().
 *
 * \param ctx        The render context handle received by the tag handler
 *                   callback.
 * \param attr_name  Null-terminated UTF-8 attribute name to look up.
 *
 * \return Null-terminated UTF-8 attribute value, or empty string. Caller
 *         must free with markup_free().
 */
extern pfn_markup_ctx_attr                  markup_ctx_attr;

/**
 * \brief Tests whether a named attribute exists on the tag currently being
 *        rendered, from within a custom tag handler callback.
 *
 * \param ctx        The render context handle received by the tag handler
 *                   callback.
 * \param attr_name  Null-terminated UTF-8 attribute name to test for.
 *
 * \return Non-zero if the attribute exists; 0 otherwise.
 */
extern pfn_markup_ctx_has_attr              markup_ctx_has_attr;

/**
 * \brief Appends a UTF-8 text string to the current render output buffer
 *        from within a custom tag handler callback.
 *
 * \remarks
 *   Multiple calls within a single handler are concatenated in order.
 *   The \p text string is consumed immediately and does not need to
 *   persist after the call returns.
 *
 * \param ctx   The render context handle received by the tag handler
 *              callback.
 * \param text  Null-terminated UTF-8 text to append to the output buffer.
 */
extern pfn_markup_ctx_emit                  markup_ctx_emit;

/**
 * \brief Recursively renders all child nodes of the tag currently being
 *        handled, appending their output to the render buffer.
 *
 * \remarks
 *   If not called, the tag's child content is silently discarded. If
 *   called multiple times, the children are rendered multiple times.
 *   A typical pattern: emit opening element, call emit_children, emit
 *   closing element.
 *
 * \param ctx  The render context handle received by the tag handler
 *             callback.
 */
extern pfn_markup_ctx_emit_children         markup_ctx_emit_children;

/* Custom function extensibility */

/**
 * \brief Registers a custom function handler callable from template
 *        expressions.
 *
 * When the interpreter encounters a matching function call, it invokes
 * \p handler with the evaluated arguments.
 *
 * \remarks
 *   Function names are case-insensitive, stored as lowercase. Custom
 *   functions are called from templates using standard syntax, e.g.
 *   \c {=\ my_func(arg1,\ arg2)}. Register before calling
 *   markup_render() or markup_convert().
 *
 * \param engine     The engine handle returned by markup_create().
 * \param func_name  Null-terminated UTF-8 function name
 *                   (case-insensitive).
 * \param handler    The callback to invoke when the function is called.
 * \param user_data  An arbitrary pointer passed to every invocation of
 *                   \p handler.
 */
extern pfn_markup_register_function         markup_register_function;

/* Function argument accessors */

/**
 * \brief Returns the argument at the given index as a UTF-8 string, from
 *        within a custom function handler callback.
 *
 * \remarks
 *   Heap-allocated -- must be freed with markup_free(). Returns empty
 *   string on NULL \p args or out-of-bounds \p index.
 *
 * \param args   The argument array handle received by the function
 *               callback.
 * \param index  Zero-based argument index.
 *
 * \return Null-terminated UTF-8 string. Caller must free with
 *         markup_free().
 */
extern pfn_markup_arg_as_string             markup_arg_as_string;

/**
 * \brief Returns the argument at the given index as a 64-bit signed
 *        integer.
 *
 * \remarks
 *   Returns zero on NULL \p args or out-of-bounds \p index.
 *
 * \param args   The argument array handle received by the function
 *               callback.
 * \param index  Zero-based argument index.
 *
 * \return The argument value as int64_t, or zero on out-of-bounds.
 */
extern pfn_markup_arg_as_integer            markup_arg_as_integer;

/**
 * \brief Returns the argument at the given index as a double-precision
 *        float.
 *
 * \remarks
 *   Returns 0.0 on NULL \p args or out-of-bounds \p index.
 *
 * \param args   The argument array handle received by the function
 *               callback.
 * \param index  Zero-based argument index.
 *
 * \return The argument value as double, or 0.0 on out-of-bounds.
 */
extern pfn_markup_arg_as_float              markup_arg_as_float;

/**
 * \brief Returns the argument at the given index as a boolean.
 *
 * \remarks
 *   Returns 0 (false) on NULL \p args or out-of-bounds \p index.
 *
 * \param args   The argument array handle received by the function
 *               callback.
 * \param index  Zero-based argument index.
 *
 * \return The argument value as MuBool, or 0 on out-of-bounds.
 */
extern pfn_markup_arg_as_boolean            markup_arg_as_boolean;

/**
 * \brief Returns the argument at the given index as a 64-bit unsigned
 *        integer.
 *
 * \remarks
 *   Returns zero on NULL \p args or out-of-bounds \p index.
 *
 * \param args   The argument array handle received by the function
 *               callback.
 * \param index  Zero-based argument index.
 *
 * \return The argument value as uint64_t, or zero on out-of-bounds.
 */
extern pfn_markup_arg_as_uint64             markup_arg_as_uint64;

/**
 * \brief Returns the number of arguments in the argument array, from
 *        within a custom function handler callback.
 *
 * \remarks
 *   Returns zero if \p args is NULL. Valid indices are
 *   0..markup_arg_count()-1.
 *
 * \param args  The argument array handle received by the function
 *              callback.
 *
 * \return The number of arguments (zero or more).
 */
extern pfn_markup_arg_count_t               markup_arg_count;

/* Function result constructors */

/**
 * \brief Constructs a string-typed return value for a custom function
 *        handler.
 *
 * \remarks
 *   The engine takes ownership -- do not free the returned handle. The
 *   \p value string is copied during construction.
 *
 * \param value  Null-terminated UTF-8 string value.
 *
 * \return An opaque MuResult handle. The engine takes ownership.
 */
extern pfn_markup_result_string             markup_result_string;

/**
 * \brief Constructs an integer-typed return value for a custom function
 *        handler.
 *
 * \remarks
 *   The engine takes ownership -- do not free the returned handle.
 *
 * \param value  The 64-bit signed integer value.
 *
 * \return An opaque MuResult handle. The engine takes ownership.
 */
extern pfn_markup_result_integer            markup_result_integer;

/**
 * \brief Constructs a float-typed return value for a custom function
 *        handler.
 *
 * \remarks
 *   The engine takes ownership -- do not free the returned handle.
 *
 * \param value  The double-precision floating-point value.
 *
 * \return An opaque MuResult handle. The engine takes ownership.
 */
extern pfn_markup_result_float              markup_result_float;

/**
 * \brief Constructs a boolean-typed return value for a custom function
 *        handler.
 *
 * \remarks
 *   The engine takes ownership -- do not free the returned handle.
 *
 * \param value  The boolean value (0 = false, non-zero = true).
 *
 * \return An opaque MuResult handle. The engine takes ownership.
 */
extern pfn_markup_result_boolean            markup_result_boolean;

/**
 * \brief Constructs a 64-bit unsigned integer-typed return value for a
 *        custom function handler.
 *
 * \remarks
 *   The engine takes ownership -- do not free the returned handle.
 *
 * \param value  The 64-bit unsigned integer value.
 *
 * \return An opaque MuResult handle. The engine takes ownership.
 */
extern pfn_markup_result_uint64             markup_result_uint64;

/**
 * \brief Constructs a nil-typed return value for a custom function
 *        handler. Use when the function has no meaningful return value.
 *
 * \remarks
 *   The engine takes ownership -- do not free the returned handle. A nil
 *   value evaluates as falsy in expressions and renders as empty string.
 *
 * \return An opaque MuResult handle representing nil. The engine takes
 *         ownership.
 */
extern pfn_markup_result_nil                markup_result_nil;

/* Error and status handler registration */

/**
 * \brief Registers a callback that receives diagnostic notifications in
 *        real time during parsing, rendering, validation, or include
 *        resolution. Pass NULL for \p handler to unregister.
 *
 * \remarks
 *   The callback is invoked synchronously. Registering a handler does not
 *   suppress accumulation of diagnostics on the engine's internal error
 *   list. Only one handler at a time -- a new registration replaces the
 *   previous one.
 *
 * \param engine     The engine handle returned by markup_create().
 * \param handler    The callback for each diagnostic, or NULL to
 *                   unregister.
 * \param user_data  An arbitrary pointer passed to every invocation of
 *                   \p handler.
 */
extern pfn_markup_set_error_handler         markup_set_error_handler;

/**
 * \brief Registers a callback that receives pipeline status messages
 *        during engine operations. Pass NULL for \p handler to unregister.
 *
 * \remarks
 *   The callback is invoked synchronously. Only one handler at a time --
 *   a new registration replaces the previous one.
 *
 * \param engine     The engine handle returned by markup_create().
 * \param handler    The callback for status messages, or NULL to
 *                   unregister.
 * \param user_data  An arbitrary pointer passed to every invocation of
 *                   \p handler.
 */
extern pfn_markup_set_status_handler        markup_set_status_handler;

/* ---------------------------------------------------------------------------
   Loader API
   --------------------------------------------------------------------------- */

/**
 * \brief Loads Markup.dll and resolves all function pointers.
 *
 * Dynamically loads the Markup shared library from the specified filesystem
 * path using LoadLibraryA() and resolves every exported function into its
 * corresponding global function pointer. If any symbol cannot be resolved,
 * the DLL is unloaded and all pointers are reset to NULL.
 *
 * \remarks
 *   If the DLL is already loaded (from a previous successful call), this
 *   function returns 1 immediately without reloading. On failure, an error
 *   message identifying the missing symbol is printed to stderr.
 *
 * \param dll_path  Null-terminated path to Markup.dll (e.g. "Markup.dll"
 *                  or "lib\\Markup.dll").
 *
 * \return 1 on success, 0 on failure. On failure, all function pointers
 *         remain NULL and an error is printed to stderr.
 */
int markup_load(const char* dll_path);

/**
 * \brief Unloads the DLL and resets all function pointers to NULL.
 *
 * Calls FreeLibrary() on the loaded module handle and sets every global
 * function pointer back to NULL.
 *
 * \remarks
 *   Safe to call even if markup_load() was not called or failed. After
 *   this call, all markup_* function pointers are NULL and must not be
 *   called until markup_load() succeeds again.
 */
void markup_unload(void);

/**
 * \brief Checks whether the DLL is currently loaded.
 *
 * \return 1 if the DLL is loaded and all function pointers are resolved,
 *         0 otherwise.
 */
int markup_is_loaded(void);

#ifdef __cplusplus
}
#endif

#endif /* MARKUP_H */

/* ===========================================================================
   IMPLEMENTATION
   ===========================================================================
   Define MARKUP_IMPLEMENTATION in exactly ONE .c or .cpp file before
   including this header to pull in the implementation.
   =========================================================================== */

#ifdef MARKUP_IMPLEMENTATION

#ifndef WIN32_LEAN_AND_MEAN
  #define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/** \cond INTERNAL */

/** \brief Internal module handle for the loaded Markup DLL. */
static HMODULE mu__dll_handle = NULL;

/* ---------------------------------------------------------------------------
   Function pointer definitions
   --------------------------------------------------------------------------- */

/* Lifecycle */
pfn_markup_create                    markup_create                    = NULL;
pfn_markup_destroy                   markup_destroy                   = NULL;
pfn_markup_version                   markup_version                   = NULL;
pfn_markup_free                      markup_free                      = NULL;

/* Parsing and rendering */
pfn_markup_parse                     markup_parse                     = NULL;
pfn_markup_doc_destroy               markup_doc_destroy               = NULL;
pfn_markup_render                    markup_render                    = NULL;
pfn_markup_convert                   markup_convert                   = NULL;
pfn_markup_convert_to_file           markup_convert_to_file           = NULL;

/* Validation and error reporting */
pfn_markup_validate                  markup_validate                  = NULL;
pfn_markup_last_errors               markup_last_errors               = NULL;

/* Include paths */
pfn_markup_add_include_path          markup_add_include_path          = NULL;

/* Options */
pfn_markup_set_pretty_print          markup_set_pretty_print          = NULL;
pfn_markup_set_strict_mode           markup_set_strict_mode           = NULL;
pfn_markup_set_allow_html            markup_set_allow_html            = NULL;
pfn_markup_set_unknown_tag_behavior  markup_set_unknown_tag_behavior  = NULL;
pfn_markup_set_max_iterations        markup_set_max_iterations        = NULL;
pfn_markup_set_max_recursion         markup_set_max_recursion         = NULL;
pfn_markup_set_max_output_size       markup_set_max_output_size       = NULL;

/* Custom tag extensibility */
pfn_markup_register_tag              markup_register_tag              = NULL;
pfn_markup_ctx_tag_name              markup_ctx_tag_name              = NULL;
pfn_markup_ctx_attr                  markup_ctx_attr                  = NULL;
pfn_markup_ctx_has_attr              markup_ctx_has_attr              = NULL;
pfn_markup_ctx_emit                  markup_ctx_emit                  = NULL;
pfn_markup_ctx_emit_children         markup_ctx_emit_children         = NULL;

/* Custom function extensibility */
pfn_markup_register_function         markup_register_function         = NULL;

/* Function argument accessors */
pfn_markup_arg_as_string             markup_arg_as_string             = NULL;
pfn_markup_arg_as_integer            markup_arg_as_integer            = NULL;
pfn_markup_arg_as_float              markup_arg_as_float              = NULL;
pfn_markup_arg_as_boolean            markup_arg_as_boolean            = NULL;
pfn_markup_arg_as_uint64             markup_arg_as_uint64             = NULL;
pfn_markup_arg_count_t               markup_arg_count                 = NULL;

/* Function result constructors */
pfn_markup_result_string             markup_result_string             = NULL;
pfn_markup_result_integer            markup_result_integer            = NULL;
pfn_markup_result_float              markup_result_float              = NULL;
pfn_markup_result_boolean            markup_result_boolean            = NULL;
pfn_markup_result_uint64             markup_result_uint64             = NULL;
pfn_markup_result_nil                markup_result_nil                = NULL;

/* Error and status handler registration */
pfn_markup_set_error_handler         markup_set_error_handler         = NULL;
pfn_markup_set_status_handler        markup_set_status_handler        = NULL;

/* ---------------------------------------------------------------------------
   Helper: resolve one symbol or fail
   --------------------------------------------------------------------------- */

/**
 * \brief Internal helper macro that resolves a single DLL export.
 *
 * \param var   The global function pointer variable to assign.
 * \param type  The function pointer typedef to cast to.
 * \param name  The null-terminated export name string.
 */
#define MU__LOAD(var, type, name)                                           \
    do {                                                                    \
        var = (type)GetProcAddress(mu__dll_handle, name);                   \
        if (!var) {                                                         \
            fprintf(stderr,                                                 \
                "Markup: failed to load '%s' from '%s'\n", name, dll_path); \
            markup_unload();                                                \
            return 0;                                                       \
        }                                                                   \
    } while (0)

/* ---------------------------------------------------------------------------
   markup_load
   --------------------------------------------------------------------------- */

int markup_load(const char* dll_path)
{
    if (mu__dll_handle) {
        /* Already loaded */
        return 1;
    }

    mu__dll_handle = LoadLibraryA(dll_path);
    if (!mu__dll_handle) {
        fprintf(stderr, "Markup: failed to load DLL '%s' (error %lu)\n",
                dll_path, GetLastError());
        return 0;
    }

    /* Lifecycle */
    MU__LOAD(markup_create,                    pfn_markup_create,                    "markup_create");
    MU__LOAD(markup_destroy,                   pfn_markup_destroy,                   "markup_destroy");
    MU__LOAD(markup_version,                   pfn_markup_version,                   "markup_version");
    MU__LOAD(markup_free,                      pfn_markup_free,                      "markup_free");

    /* Parsing and rendering */
    MU__LOAD(markup_parse,                     pfn_markup_parse,                     "markup_parse");
    MU__LOAD(markup_doc_destroy,               pfn_markup_doc_destroy,               "markup_doc_destroy");
    MU__LOAD(markup_render,                    pfn_markup_render,                    "markup_render");
    MU__LOAD(markup_convert,                   pfn_markup_convert,                   "markup_convert");
    MU__LOAD(markup_convert_to_file,           pfn_markup_convert_to_file,           "markup_convert_to_file");

    /* Validation and error reporting */
    MU__LOAD(markup_validate,                  pfn_markup_validate,                  "markup_validate");
    MU__LOAD(markup_last_errors,               pfn_markup_last_errors,               "markup_last_errors");

    /* Include paths */
    MU__LOAD(markup_add_include_path,          pfn_markup_add_include_path,          "markup_add_include_path");

    /* Options */
    MU__LOAD(markup_set_pretty_print,          pfn_markup_set_pretty_print,          "markup_set_pretty_print");
    MU__LOAD(markup_set_strict_mode,           pfn_markup_set_strict_mode,           "markup_set_strict_mode");
    MU__LOAD(markup_set_allow_html,            pfn_markup_set_allow_html,            "markup_set_allow_html");
    MU__LOAD(markup_set_unknown_tag_behavior,  pfn_markup_set_unknown_tag_behavior,  "markup_set_unknown_tag_behavior");
    MU__LOAD(markup_set_max_iterations,        pfn_markup_set_max_iterations,        "markup_set_max_iterations");
    MU__LOAD(markup_set_max_recursion,         pfn_markup_set_max_recursion,         "markup_set_max_recursion");
    MU__LOAD(markup_set_max_output_size,       pfn_markup_set_max_output_size,       "markup_set_max_output_size");

    /* Custom tag extensibility */
    MU__LOAD(markup_register_tag,              pfn_markup_register_tag,              "markup_register_tag");
    MU__LOAD(markup_ctx_tag_name,              pfn_markup_ctx_tag_name,              "markup_ctx_tag_name");
    MU__LOAD(markup_ctx_attr,                  pfn_markup_ctx_attr,                  "markup_ctx_attr");
    MU__LOAD(markup_ctx_has_attr,              pfn_markup_ctx_has_attr,              "markup_ctx_has_attr");
    MU__LOAD(markup_ctx_emit,                  pfn_markup_ctx_emit,                  "markup_ctx_emit");
    MU__LOAD(markup_ctx_emit_children,         pfn_markup_ctx_emit_children,         "markup_ctx_emit_children");

    /* Custom function extensibility */
    MU__LOAD(markup_register_function,         pfn_markup_register_function,         "markup_register_function");

    /* Function argument accessors */
    MU__LOAD(markup_arg_as_string,             pfn_markup_arg_as_string,             "markup_arg_as_string");
    MU__LOAD(markup_arg_as_integer,            pfn_markup_arg_as_integer,            "markup_arg_as_integer");
    MU__LOAD(markup_arg_as_float,              pfn_markup_arg_as_float,              "markup_arg_as_float");
    MU__LOAD(markup_arg_as_boolean,            pfn_markup_arg_as_boolean,            "markup_arg_as_boolean");
    MU__LOAD(markup_arg_as_uint64,             pfn_markup_arg_as_uint64,             "markup_arg_as_uint64");
    MU__LOAD(markup_arg_count,                 pfn_markup_arg_count_t,               "markup_arg_count");

    /* Function result constructors */
    MU__LOAD(markup_result_string,             pfn_markup_result_string,             "markup_result_string");
    MU__LOAD(markup_result_integer,            pfn_markup_result_integer,            "markup_result_integer");
    MU__LOAD(markup_result_float,              pfn_markup_result_float,              "markup_result_float");
    MU__LOAD(markup_result_boolean,            pfn_markup_result_boolean,            "markup_result_boolean");
    MU__LOAD(markup_result_uint64,             pfn_markup_result_uint64,             "markup_result_uint64");
    MU__LOAD(markup_result_nil,                pfn_markup_result_nil,                "markup_result_nil");

    /* Error and status handler registration */
    MU__LOAD(markup_set_error_handler,         pfn_markup_set_error_handler,         "markup_set_error_handler");
    MU__LOAD(markup_set_status_handler,        pfn_markup_set_status_handler,        "markup_set_status_handler");

    return 1;
}

/* ---------------------------------------------------------------------------
   markup_unload
   --------------------------------------------------------------------------- */

void markup_unload(void)
{
    if (mu__dll_handle) {
        FreeLibrary(mu__dll_handle);
        mu__dll_handle = NULL;
    }

    /* Lifecycle */
    markup_create                    = NULL;
    markup_destroy                   = NULL;
    markup_version                   = NULL;
    markup_free                      = NULL;

    /* Parsing and rendering */
    markup_parse                     = NULL;
    markup_doc_destroy               = NULL;
    markup_render                    = NULL;
    markup_convert                   = NULL;
    markup_convert_to_file           = NULL;

    /* Validation and error reporting */
    markup_validate                  = NULL;
    markup_last_errors               = NULL;

    /* Include paths */
    markup_add_include_path          = NULL;

    /* Options */
    markup_set_pretty_print          = NULL;
    markup_set_strict_mode           = NULL;
    markup_set_allow_html            = NULL;
    markup_set_unknown_tag_behavior  = NULL;
    markup_set_max_iterations        = NULL;
    markup_set_max_recursion         = NULL;
    markup_set_max_output_size       = NULL;

    /* Custom tag extensibility */
    markup_register_tag              = NULL;
    markup_ctx_tag_name              = NULL;
    markup_ctx_attr                  = NULL;
    markup_ctx_has_attr              = NULL;
    markup_ctx_emit                  = NULL;
    markup_ctx_emit_children         = NULL;

    /* Custom function extensibility */
    markup_register_function         = NULL;

    /* Function argument accessors */
    markup_arg_as_string             = NULL;
    markup_arg_as_integer            = NULL;
    markup_arg_as_float              = NULL;
    markup_arg_as_boolean            = NULL;
    markup_arg_as_uint64             = NULL;
    markup_arg_count                 = NULL;

    /* Function result constructors */
    markup_result_string             = NULL;
    markup_result_integer            = NULL;
    markup_result_float              = NULL;
    markup_result_boolean            = NULL;
    markup_result_uint64             = NULL;
    markup_result_nil                = NULL;

    /* Error and status handler registration */
    markup_set_error_handler         = NULL;
    markup_set_status_handler        = NULL;
}

/* ---------------------------------------------------------------------------
   markup_is_loaded
   --------------------------------------------------------------------------- */

int markup_is_loaded(void)
{
    return mu__dll_handle != NULL;
}

#undef MU__LOAD

/** \endcond */

#ifdef __cplusplus
}
#endif

#endif /* MARKUP_IMPLEMENTATION */

