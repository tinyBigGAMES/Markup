{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Demo.Formatting;

{$I Markup.Defines.inc}

interface

procedure Demo_Fmt_TextInline();
procedure Demo_Fmt_Headings();
procedure Demo_Fmt_LinksMedia();
procedure Demo_Fmt_Lists();
procedure Demo_Fmt_Tables();
procedure Demo_Fmt_CodeBlocks();
procedure Demo_Fmt_Sections();
procedure Demo_Fmt_Quotes();
procedure Demo_Fmt_Callouts();
procedure Demo_Fmt_Details();
procedure Demo_Fmt_VoidTags();
procedure Demo_Fmt_Forms();
procedure Demo_Fmt_Layout();

implementation

uses
  System.SysUtils,
  Markup.Utils,
  Markup,
  UTest.Demo;

// =========================================================================
// §3.1 — Text Formatting (Inline)
// =========================================================================
procedure Demo_Fmt_TextInline();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Text Inline');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Inline Formatting Tags"}' +
         '{p "{b "bold"}, {i "italic"}, {u "underline"}, {s "strikethrough"}"}' +
         '{p "H{sub "2"}O and x{sup "2"} + y{sup "2"} = z{sup "2"}"}' +
         '{p "{mark "highlighted"} and {small "small text"}"}' +
         '{p "{abbr title="HyperText Markup Language" "HTML"} is the standard."}' +
         '{p "Use {code "print()"} to output. Press {kbd "Ctrl+S"} to save."}' +
         '{p "She said {q "hello"} — from {cite "The Book of Greetings"}."}' +
         '{p "Published on {time datetime=2026-01-15 "January 15, 2026"}."}'),
      nil, OutputFile('Fmt_TextInline'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.2 — Headings (h1–h6 with id/class)
// =========================================================================
procedure Demo_Fmt_Headings();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Headings');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h1 "Heading 1"}' +
         '{h2 id=features "Heading 2 with id"}' +
         '{h3 class=subtitle "Heading 3 with class"}' +
         '{h4 "Heading 4"}{h5 "Heading 5"}{h6 "Heading 6"}'),
      nil, OutputFile('Fmt_Headings'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.3 — Links and Media
// =========================================================================
procedure Demo_Fmt_LinksMedia();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Links & Media');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Links"}' +
         '{p "{link "https://example.com" "External link"}"}' +
         '{p "{link title="About us" "/about" "About"}"}' +
         '{h2 "Images"}' +
         '{img "https://placehold.co/400x200" "Placeholder image"}' +
         '{h2 "Figure with Caption"}' +
         '{fig' +
         '  {img "https://placehold.co/600x300" "Diagram"}' +
         '  {caption "System architecture as of v2.3"}' +
         '}' +
         '{h2 "Audio & Video"}' +
         '{audio controls "demo.mp3"}' +
         '{video controls width=640 "demo.mp4"}'),
      nil, OutputFile('Fmt_LinksMedia'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.4 — Lists (unordered, ordered, nested, description)
// =========================================================================
procedure Demo_Fmt_Lists();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Lists');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Unordered"}{list {item "First"}{item "Second with {b "bold"}"}{item "Third"}}' +
         '{h2 "Ordered"}{olist {item "Step one"}{item "Step two"}{item "Step three"}}' +
         '{h2 "Nested"}{list {item "Parent A" {list {item "Child A.1"}{item "Child A.2"}}}{item "Parent B"}}' +
         '{h2 "Description"}{dlist {term "Markup"}{desc "A document authoring language."}{term "HTML"}{desc "The output format."}}'),
      nil, OutputFile('Fmt_Lists'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.5 — Tables (structured + pipe shorthand)
// =========================================================================
procedure Demo_Fmt_Tables();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Tables');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Structured Table"}' +
         '{table' +
         '  {thead {row {hcol "Name"}{hcol "Role"}{hcol "Status"}}}' +
         '  {tbody' +
         '    {row {col "Alice"}{col "Engineer"}{col "Active"}}' +
         '    {row {col "Bob"}{col "Designer"}{col "On Leave"}}' +
         '  }' +
         '}' +
         '{h2 "Pipe Shorthand Table"}' +
         '{table caption="Team Roster"' +
         '| Name  | Role     | Location |' +
         '| Alice | Engineer | NYC      |' +
         '| Bob   | Designer | London   |' +
         '| Carol | PM       | Tokyo    |' +
         '}'),
      nil, OutputFile('Fmt_Tables'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.6 — Code Blocks (inline + block with language)
// =========================================================================
procedure Demo_Fmt_CodeBlocks();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Code Blocks');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Inline Code"}' +
         '{p "Use the {code "print()"} function to output text."}' +
         '{h2 "Block Code with Language"}' +
         '{code lang=delphi' +
         'procedure TFoo.Bar();' + #10 +
         'begin' + #10 +
         '  WriteLn(''hello'');' + #10 +
         'end;' +
         '}'),
      nil, OutputFile('Fmt_CodeBlocks'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.7 — Semantic Sections
// =========================================================================
procedure Demo_Fmt_Sections();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Sections');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{header {h1 "Site Title"}{nav {p "Home | About"}}}' +
         '{main' +
         '  {section id=intro {h2 "Introduction"}{p "Welcome."}}' +
         '  {article {h2 "Article"}{p "Body content."}}' +
         '  {aside {p "Sidebar."}}' +
         '}' +
         '{footer {p "Copyright 2026"}}' +
         '{box class=wrapper {span class=tag "A div with a span."}}'),
      nil, OutputFile('Fmt_Sections'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.8 — Block Quotation
// =========================================================================
procedure Demo_Fmt_Quotes();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Quotes');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{quote "To be or not to be, that is the question."' +
         '  {footer {cite "William Shakespeare"}}' +
         '}' +
         '{quote "The only way to do great work is to love what you do."' +
         '  {footer {cite "Steve Jobs"}}' +
         '}'),
      nil, OutputFile('Fmt_Quotes'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.10 — Callouts / Admonitions
// =========================================================================
procedure Demo_Fmt_Callouts();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Callouts');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Callout Types"}' +
         '{note "This is an informational note."}' +
         '{tip "A helpful suggestion for the reader."}' +
         '{warning "Be careful — this action cannot be undone."}' +
         '{danger "Critical: data loss may occur!"}'),
      nil, OutputFile('Fmt_Callouts'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.9 — Details / Disclosure
// =========================================================================
procedure Demo_Fmt_Details();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Details');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Collapsible Sections"}' +
         '{details summary="Click to expand"' +
         '  "Hidden content here. Supports {b "any"} Markup constructs."' +
         '}' +
         '{details summary="System Requirements"' +
         '  {list {item "Windows 10 or later"}{item "4 GB RAM"}{item "100 MB disk"}}' +
         '}'),
      nil, OutputFile('Fmt_Details'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.11 — Void Tags (line, br, img, input)
// =========================================================================
procedure Demo_Fmt_VoidTags();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Void Tags');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Void Tags"}' +
         '{p "Line one{br}Line two after break."}' +
         '{line}' +
         '{p "Horizontal rule above."}' +
         '{img "https://placehold.co/200x100" "A placeholder"}' +
         '{input type=text placeholder="Type here..."}'),
      nil, OutputFile('Fmt_VoidTags'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.12 — Forms
// =========================================================================
procedure Demo_Fmt_Forms();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Forms');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Contact Form"}' +
         '{form method=post "/submit"' +
         '  {label for=username "Username:"}' +
         '  {input type=text id=username placeholder="Enter name"}' +
         '  {label for=bio "Bio:"}' +
         '  {textarea id=bio "Default text here"}' +
         '  {select id=role' +
         '    {option value=dev "Developer"}' +
         '    {option value=mgr "Manager"}' +
         '    {option value=qa selected "QA"}' +
         '  }' +
         '  {button type=submit "Submit"}' +
         '}'),
      nil, OutputFile('Fmt_Forms'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §3.13 — Layout Helpers (grid, cell, columns, column, card)
// =========================================================================
procedure Demo_Fmt_Layout();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Fmt: Layout');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Grid Layout"}' +
         '{grid cols=3 gap=16 {cell "Cell A"}{cell "Cell B"}{cell "Cell C"}}' +
         '{h2 "Columns"}' +
         '{columns {column "Left content."}{column "Right content."}}' +
         '{h2 "Card"}' +
         '{card {h3 "Card Title"}{p "Card body with {b "formatting"}."}}'),
      nil, OutputFile('Fmt_Layout'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

end.
