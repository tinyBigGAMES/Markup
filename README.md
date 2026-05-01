<div align="center">

![Markup](media/markup.png)

<br>

[![Discord](https://img.shields.io/discord/1457450179254026250?style=for-the-badge&logo=discord&label=Discord)](https://discord.gg/Wb6z8Wam7p) [![Follow on Bluesky](https://img.shields.io/badge/Bluesky-tinyBigGAMES-blue?style=for-the-badge&logo=bluesky)](https://bsky.app/profile/tinybiggames.com) 

</div>

## What is Markup?

**Markup** is a document authoring language that replaces writing HTML by hand. Every construct follows the same `{tag "content"}` pattern. Variables, conditionals, iteration, and component definitions use the same syntax. A Markup document compiles to clean, semantic HTML.

```
{h1 "Getting Started with Markup"}
{p "Markup is a document authoring language. Every construct follows
the same {code "{tag content}"} pattern."}
{list
  {item "{b "One syntax"} for everything"}
  {item "{b "HTML-level power"} without HTML verbosity"}
  {item "{b "Built-in logic"} for variables, loops, and conditionals"}
}
```

**Write Documents, Not HTML.**

## Why Markup?

- **One syntax, one rule.** Every construct follows `{tag "content"}`. No mode switches, no special cases, no ambiguous parsing contexts.
- **Turing complete by design.** Variables, conditionals, iteration, and reusable components are first-class constructs using the same tag syntax.
- **Quoted strings.** Content is delimited by `"..."`, so the parser knows exactly what to preserve. No whitespace ambiguity.
- **HTML output.** Compiles to clean, semantic HTML. If HTML can express it, so can Markup.
- **DLL API.** Ship as a single `Markup.dll` with a flat C-style API. Integrate from Delphi, C, C++, or any language that can call a DLL.
- **Custom tags and functions.** Register your own tag handlers and expression functions to extend the language at runtime.
- **Data binding.** Pass JSON data and access it from templates with `{=data.path}` interpolation.
- **Configurable options.** Pretty-print output, strict mode, HTML sanitization, unknown tag handling, and safety limits — all controllable per engine instance.
- **File output.** Render directly to `.html` files with optional browser launch via `markup_convert_to_file`.

## Source Units

| Unit | Purpose |
|------|---------|
| `Markup.pas` | Delphi import wrapper for Markup.dll. Opaque handles and flat function calls with no dependencies on Markup internals. |
| `Markup.h` | C/C++ single-header dynamic loader for Markup.dll. Define `MARKUP_IMPLEMENTATION` in one translation unit, then include normally everywhere else. |
| `Markup.API.pas` | DLL export layer. Bridges the flat C-style API to the internal engine. |
| `Markup.AST.pas` | Abstract syntax tree node types and arena allocator. |
| `Markup.Builtins.pas` | Built-in functions available in Markup expressions. |
| `Markup.Config.pas` | Engine configuration and feature flags. |
| `Markup.Context.pas` | Render context passed to custom tag handlers. |
| `Markup.Engine.pas` | Top-level engine coordinating lexer, parser, interpreter, and semantics. |
| `Markup.Environment.pas` | Variable environment and scope management. |
| `Markup.ExprParser.pas` | Expression parser for `{=...}` interpolation and function calls. |
| `Markup.Interpreter.pas` | AST interpreter that walks the tree and emits HTML. |
| `Markup.JSON.pas` | JSON parser for data binding. |
| `Markup.Lexer.pas` | Recursive lexer with quoted string support. |
| `Markup.Options.pas` | Render options and output configuration. |
| `Markup.Parser.pas` | Recursive descent parser producing the AST. |
| `Markup.Pipes.pas` | Pipe filter functions (e.g., `upper`, `lower`). |
| `Markup.Resources.pas` | Embedded resource management. |
| `Markup.Semantics.pas` | Semantic analysis: block/void tag classification, validation. |
| `Markup.TestCase.pas` | Test infrastructure for the testbed. |
| `Markup.TOML.pas` | TOML parser for configuration files. |
| `Markup.Utils.pas` | Shared utility routines and console helpers. |
| `Markup.Value.pas` | TMuValue record wrapping TValue for the expression evaluator. |

## System Requirements

| | Requirement |
|---|---|
| **Host OS** | Windows 10/11 x64 |
| **Building from source** | Delphi 12.x or higher |

## Getting Started

### Delphi

1. Clone the repository
2. Copy `Markup.dll` and `lib\pascal\Markup.pas` into your project
3. Add `Markup` to your unit's `uses` clause

```delphi
uses
  Markup;
```

Minimal example:

```delphi
var
  LEngine: TMuEngine;
  LHtml: PAnsiChar;
begin
  LEngine := markup_create();
  try
    LHtml := markup_convert(LEngine,
      PAnsiChar(UTF8Encode(
        '{h1 "Hello, Markup!"}{p "Write Documents, Not HTML."}')),
      nil);
    try
      WriteLn(string(UTF8String(LHtml)));
    finally
      markup_free(LHtml);
    end;
  finally
    markup_destroy(LEngine);
  end;
end;
```

No packages, no components, no third-party dependencies.

### C / C++

1. Copy `Markup.dll` and `lib\c\include\Markup.h` into your project
2. Define `MARKUP_IMPLEMENTATION` in exactly one `.c` or `.cpp` file before including the header
3. In all other files, include `Markup.h` normally

```c
#define MARKUP_IMPLEMENTATION
#include "Markup.h"

int main(void) {
    if (!markup_load("Markup.dll")) return 1;

    MuEngine engine = markup_create();
    char* html = markup_convert(engine,
        "{h1 \"Hello, Markup!\"}{p \"Write Documents, Not HTML.\"}",
        NULL);
    printf("%s\n", html);
    markup_free(html);
    markup_destroy(engine);

    markup_unload();
    return 0;
}
```

No build system integration required — just compile and link.

## Documentation

| Document | Description |
|----------|-------------|
| [Specs.md](docs/Specs.md) | Language specification: syntax, tags, computation, grammar |
| [API.md](docs/API.md) | Complete DLL API reference: every function, type, and callback |
| [User.md](docs/User.md) | Practical usage guide: patterns, examples, memory management |

## Contributing

Markup is an open project. Whether you are fixing a bug, improving documentation, or proposing a feature, contributions are welcome.

- **Report bugs**: Open an issue with a minimal reproduction. The smaller the example, the faster the fix.
- **Suggest features**: Describe the use case first. Features that emerge from real problems get traction fastest.
- **Submit pull requests**: Bug fixes, documentation improvements, and well-scoped features are all welcome. Keep changes focused.

Join the [Discord](https://discord.gg/Wb6z8Wam7p) to discuss development, ask questions, and share what you are building.

## Support the Project

Markup is built in the open. If it saves you time or sparks something useful:

- ⭐ **Star the repo**: it costs nothing and helps others find the project
- 🗣️ **Spread the word**: write a post, mention it in a community you are part of
- 💬 **[Join us on Discord](https://discord.gg/Wb6z8Wam7p)**: share what you are building and help shape what comes next
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)**: sponsorship directly funds development and documentation
- 🦋 **[Follow on Bluesky](https://bsky.app/profile/tinybiggames.com)**: stay in the loop on releases and development

## License

Markup is licensed under the **Apache License 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/Markup?tab=Apache-2.0-1-ov-file#readme) for details.

Apache 2.0 is a permissive open source license that lets you use, modify, and distribute Markup freely in both open source and commercial projects. You are not required to release your own source code. The license includes an explicit patent grant. Attribution is required; keep the copyright notice and license file in place.

## Links

- [Discord](https://discord.gg/Wb6z8Wam7p)
- [Bluesky](https://bsky.app/profile/tinybiggames.com)
- [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**Markup™** - Document Authoring Language

Copyright &copy; 2026-present tinyBigGAMES™ LLC<br/>All Rights Reserved.

</div>
