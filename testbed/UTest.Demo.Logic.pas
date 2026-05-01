{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Demo.Logic;

{$I Markup.Defines.inc}

interface

procedure Demo_Logic_Variables();
procedure Demo_Logic_Eval();
procedure Demo_Logic_Pipes();
procedure Demo_Logic_Conditionals();
procedure Demo_Logic_Iteration();
procedure Demo_Logic_Components();
procedure Demo_Logic_Meta();
procedure Demo_Logic_RawHtml();

implementation

uses
  System.SysUtils,
  Markup.Utils,
  Markup,
  UTest.Demo;

// =========================================================================
// §4.1 — Variables (let, set, get)
// =========================================================================
procedure Demo_Logic_Variables();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Variables');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{let greeting "Hello"}' +
         '{let name "World"}' +
         '{p "{=greeting}, {=name}!"}' +
         '{set name "Markup"}' +
         '{p "{=greeting}, {=name}!"}' +
         '{h3 "Data binding with get"}' +
         '{p "User: {get data.user.name}"}' +
         '{p "Email: {get data.user.email}"}'),
      Mu('{"user":{"name":"Alice","email":"alice@example.com"}}'),
      OutputFile('Logic_Variables'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §4.2 — Expressions (eval)
// =========================================================================
procedure Demo_Logic_Eval();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Eval');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Expressions"}' +
         '{let price 25}' +
         '{let qty 4}' +
         '{p "Price: {=price}, Qty: {=qty}"}' +
         '{p "Total: {eval {get price} * {get qty}}"}' +
         '{p "5 + 3 = {eval 5 + 3}"}' +
         '{p "10 % 3 = {eval 10 % 3}"}'),
      nil, OutputFile('Logic_Eval'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §4.3 — Filters / Pipe Syntax
// =========================================================================
procedure Demo_Logic_Pipes();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Pipes');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{let name "  alice chen  "}' +
         '{p "Raw: [{=name}]"}' +
         '{p "Trimmed: [{=name | trim}]"}' +
         '{p "Upper: [{=name | trim | upper}]"}' +
         '{p "Lower: [{=name | trim | lower}]"}' +
         '{p "Length: {=name | trim | len}"}' +
         '{p "Substr: {=name | trim | substr(0, 5)}"}'),
      nil, OutputFile('Logic_Pipes'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §4.4 — Conditionals (if, elseif, else)
// =========================================================================
procedure Demo_Logic_Conditionals();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Conditionals');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "If / ElseIf / Else"}' +
         '{if {=data.role == "admin"}' +
         '  {p class=admin "Welcome, Administrator."}' +
         '{elseif {=data.role == "editor"}}' +
         '  {p class=editor "Welcome, Editor."}' +
         '{else}' +
         '  {p class=guest "Welcome, Guest."}' +
         '}' +
         '{h2 "Truthy / Falsy"}' +
         '{if {=data.active}' +
         '  {p "Account is active."}' +
         '{else}' +
         '  {p "Account is inactive."}' +
         '}'),
      Mu('{"role":"editor","active":true}'),
      OutputFile('Logic_Conditionals'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §4.5 — Iteration (each list, each map, loop variables)
// =========================================================================
procedure Demo_Logic_Iteration();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Iteration');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "List with Loop Variables"}' +
         '{each {get data.fruits} fruit' +
         '  {p "{=loop.count}. {=fruit}' +
         '    {if {=loop.first} {span " (first)"}' +
         '    {elseif {=loop.last}} {span " (last)"}' +
         '    }' +
         '  "}' +
         '}' +
         '{h2 "Map Iteration"}' +
         '{each {get data.headers} key value' +
         '  {p "{=key}: {=value}"}' +
         '}' +
         '{h2 "Nested Iteration"}' +
         '{each {get data.teams} team' +
         '  {h3 "{=team.name}"}' +
         '  {list {each {get team.members} member {item "{=member}"}}}' +
         '}'),
      Mu('{"fruits":["Apple","Banana","Cherry"],' +
         '"headers":{"Content-Type":"text/html","Cache":"no-cache"},' +
         '"teams":[' +
         '  {"name":"Alpha","members":["Alice","Bob"]},' +
         '  {"name":"Beta","members":["Carol","Dave","Eve"]}' +
         ']}'),
      OutputFile('Logic_Iteration'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §4.6 — Component Definitions (def/call, defaults, block content)
// =========================================================================
procedure Demo_Logic_Components();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Components');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Reusable Components"}' +
         '{def card icon="star" title="Untitled" body' +
         '  {box class=card' +
         '    {box class=card-header' +
         '      {span class=icon "{=icon}"} {h3 "{=title}"}' +
         '    }' +
         '    {box class=card-body "{=body}"}' +
         '  }' +
         '}' +
         '{def badge color="gray" label' +
         '  {span class="badge badge-{=color}" "{=label}"}' +
         '}' +
         '{call card icon=rocket title="Performance"' +
         '  "Built for speed. {call badge color=green label=Fast}"' +
         '}' +
         '{call card title="Simplicity"' +
         '  "Easy to use. {call badge label=Simple}"' +
         '}' +
         '{call card "Default card with only body content."}'),
      nil, OutputFile('Logic_Components'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §6 — Metadata
// =========================================================================
procedure Demo_Logic_Meta();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Meta');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{meta title="My Document" author="Alice" lang=en}' +
         '{h1 "Document with Metadata"}' +
         '{p "The {code "{meta}"} tag declares title, author, and lang."}' +
         '{p "It produces no visible output but is available via the API."}'),
      nil, OutputFile('Logic_Meta'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// §7 — Raw HTML Passthrough
// =========================================================================
procedure Demo_Logic_RawHtml();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Logic: Raw HTML');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Raw HTML Passthrough"}' +
         '{p "The following is injected verbatim:"}' +
         '{html' +
         '<div style="border:2px solid #0077cc; padding:16px; border-radius:8px;">' +
         '  <p style="color:#0077cc; font-weight:bold;">This is raw HTML.</p>' +
         '  <canvas id="demo" width="200" height="50"></canvas>' +
         '  <script>var c=document.getElementById("demo");' +
         '  var ctx=c.getContext("2d");ctx.fillStyle="#0077cc";' +
         '  ctx.fillRect(0,0,200,50);</script>' +
         '</div>' +
         '}' +
         '{p "Back to normal Markup content."}'),
      nil, OutputFile('Logic_RawHtml'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

end.
