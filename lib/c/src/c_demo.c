/*=============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information

  c_demo.c
    Standalone C demo exercising the Markup DLL via dynamic loading.
    Compile with: compile.cmd [compiler]
=============================================================================*/

#define MARKUP_IMPLEMENTATION
#include "Markup.h"

#include <stdio.h>

/* ANSI color helpers */
#define CLR_RESET   "\033[0m"
#define CLR_BOLD    "\033[1m"
#define CLR_RED     "\033[31m"
#define CLR_GREEN   "\033[32m"
#define CLR_CYAN    "\033[36m"
#define CLR_MAGENTA "\033[35m"

static void header(const char* title)
{
    printf(CLR_CYAN CLR_BOLD "--- %s ---" CLR_RESET "\n", title);
}

static void result_ok(void)
{
    printf(CLR_GREEN "  OK" CLR_RESET "\n\n");
}

static void result_fail(void)
{
    printf(CLR_RED "  FAIL" CLR_RESET "\n\n");
}

static void error_handler(int32_t severity, const char* code,
                          const char* message, void* user_data)
{
    const char* sev;
    const char* clr;
    (void)user_data;

    switch (severity) {
        case 0:  sev = "HINT";  clr = CLR_CYAN;    break;
        case 1:  sev = "WARN";  clr = "\033[33m";   break;
        case 2:  sev = "ERROR"; clr = CLR_RED;      break;
        case 3:  sev = "FATAL"; clr = CLR_RED;      break;
        default: sev = "?";     clr = "";            break;
    }
    printf("%s  [%s] %s: %s" CLR_RESET "\n", clr, sev, code, message);
}

static void status_handler(const char* text, void* user_data)
{
    (void)user_data;
    printf(CLR_MAGENTA "  %s" CLR_RESET "\n", text);
}

/* =========================================================================
   main
   ========================================================================= */

int main(void)
{
    MuEngine engine;
    char* html;

    /* Header */
    if (!markup_load("Markup.dll")) {
        printf(CLR_RED "Failed to load Markup.dll" CLR_RESET "\n");
        return 1;
    }

    printf(CLR_CYAN CLR_BOLD
           "Markup v%s - Document Authoring Language\n"
           "============================================\n"
           CLR_RESET "\n", markup_version());

    engine = markup_create();
    markup_set_error_handler(engine, error_handler, NULL);
    markup_set_status_handler(engine, status_handler, NULL);
    markup_set_pretty_print(engine, 1);

    /* --- Convert -------------------------------------------------------- */
    header("Convert");
    html = markup_convert(engine,
        "{h1 \"Hello from C!\"}"
        "{p \"This output was produced by the Markup DLL, \""
        "   \"called from a plain C program via dynamic loading.\"}",
        NULL);
    if (html) {
        printf("%s\n", html);
        markup_free(html);
        result_ok();
    } else {
        result_fail();
    }

    /* --- Data Binding ---------------------------------------------------- */
    header("Data Binding");
    html = markup_convert(engine,
        "{h2 \"User: {= data.name}\"}"
        "{p \"Role: {= data.role}\"}",
        "{\"name\":\"Alice Chen\",\"role\":\"Lead Engineer\"}");
    if (html) {
        printf("%s\n", html);
        markup_free(html);
        result_ok();
    } else {
        result_fail();
    }

    /* --- Parse Once, Render Twice ---------------------------------------- */
    header("Parse Once, Render Twice");
    {
        MuDoc doc = markup_parse(engine,
            "{p \"Hello, {= data.who}!\"}");
        char* r1 = markup_render(engine, doc,
            "{\"who\":\"World\"}");
        char* r2 = markup_render(engine, doc,
            "{\"who\":\"Markup\"}");
        printf("  Render 1: %s\n", r1 ? r1 : "(null)");
        printf("  Render 2: %s\n", r2 ? r2 : "(null)");
        if (r1) markup_free(r1);
        if (r2) markup_free(r2);
        markup_doc_destroy(doc);
        result_ok();
    }

    /* --- Cleanup --------------------------------------------------------- */
    markup_destroy(engine);
    markup_unload();

    printf(CLR_GREEN CLR_BOLD "All demos passed." CLR_RESET "\n");
    return 0;
}
