{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Demo.Builtins;

{$I Markup.Defines.inc}

interface

procedure Demo_Fn_String();
procedure Demo_Fn_Math();
procedure Demo_Fn_Collection();
procedure Demo_Fn_Type();
procedure Demo_Fn_Html();
procedure Demo_Fn_Comparison();

implementation

uses
  System.SysUtils,
  Markup.Utils,
  Markup,
  UTest.Demo;

// =========================================================================
// String Functions
// =========================================================================
procedure Demo_Fn_String();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Builtins: String');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{let text "  Hello, World!  "}' +
         '{h2 "String Functions"}' +
         '{p "Original: [{=text}]"}' +
         '{p "upper: {=text | trim | upper}"}' +
         '{p "lower: {=text | trim | lower}"}' +
         '{p "trim: [{=text | trim}]"}' +
         '{p "len: {=text | trim | len}"}' +
         '{p "substr(0,5): {eval substr({get text | trim}, 0, 5)}"}' +
         '{p "replace: {eval replace({get text | trim}, \"World\", \"Markup\")}"}' +
         '{p "startsWith: {eval startsWith({get text | trim}, \"Hello\")}"}' +
         '{p "endsWith: {eval endsWith({get text | trim}, \"!\")}"}' +
         '{p "contains: {eval contains({get text | trim}, \"World\")}"}'),
      nil, OutputFile('Fn_String'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// Math Functions
// =========================================================================
procedure Demo_Fn_Math();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Builtins: Math');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Math Functions"}' +
         '{p "round(3.7): {eval round(3.7)}"}' +
         '{p "round(3.2): {eval round(3.2)}"}' +
         '{p "floor(3.9): {eval floor(3.9)}"}' +
         '{p "ceil(3.1): {eval ceil(3.1)}"}' +
         '{p "abs(-42): {eval abs(-42)}"}' +
         '{p "min(10, 3): {eval min(10, 3)}"}' +
         '{p "max(10, 3): {eval max(10, 3)}"}'),
      nil, OutputFile('Fn_Math'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// Collection Functions
// =========================================================================
procedure Demo_Fn_Collection();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Builtins: Collection');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Collection Functions"}' +
         '{p "count: {eval count(data.items)}"}' +
         '{p "first: {eval first(data.items)}"}' +
         '{p "last: {eval last(data.items)}"}' +
         '{p "index(1): {eval index(data.items, 1)}"}' +
         '{h3 "range(1, 5)"}' +
         '{each {eval range(1, 5)} n {span "{=n} "}}' +
         '{h3 "sort"}' +
         '{each {eval sort(data.items)} item {span "{=item} "}}' +
         '{h3 "reverse"}' +
         '{each {eval reverse(data.items)} item {span "{=item} "}}' +
         '{h3 "keys / values"}' +
         '{p "keys: {eval join(keys(data.config), '', '')}"}' +
         '{p "values: {eval join(values(data.config), '', '')}"}'),
      Mu('{"items":["Cherry","Apple","Banana","Date"],' +
         '"config":{"host":"localhost","port":"8080","debug":"true"}}'),
      OutputFile('Fn_Collection'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// Type Functions
// =========================================================================
procedure Demo_Fn_Type();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Builtins: Type');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Type Functions"}' +
         '{p "typeof string: {eval typeof(\"hello\")}"}' +
         '{p "typeof int: {eval typeof(42)}"}' +
         '{p "typeof float: {eval typeof(3.14)}"}' +
         '{p "typeof bool: {eval typeof(true)}"}' +
         '{p "typeof list: {eval typeof({get data.items})}"}' +
         '{p "toStr(42): [{eval toStr(42)}]"}' +
         '{p "toInt(\"99\"): {eval toInt(\"99\") + 1}"}' +
         '{p "toFloat(\"3.14\"): {eval toFloat(\"3.14\") * 2}"}'),
      Mu('{"items":[1,2,3]}'),
      OutputFile('Fn_Type'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// HTML Functions
// =========================================================================
procedure Demo_Fn_Html();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Builtins: HTML');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "HTML Functions"}' +
         '{let markup "<b>bold</b> & <i>italic</i>"}' +
         '{p "escape: {eval escape({get markup})}"}' +
         '{p "raw: {eval raw({get markup})}"}' +
         '{let multiline "Line one' + #10 + 'Line two' + #10 + 'Line three"}' +
         '{p "nl2br:"}{p "{eval nl2br({get multiline})}"}'),
      nil, OutputFile('Fn_Html'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// Comparison Functions (as pipe filters)
// =========================================================================
procedure Demo_Fn_Comparison();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Builtins: Comparison');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Comparison Functions"}' +
         '{let age 25}' +
         '{p "age eq(25): {=age | eq(25)}"}' +
         '{p "age neq(30): {=age | neq(30)}"}' +
         '{p "age gt(18): {=age | gt(18)}"}' +
         '{p "age lt(30): {=age | lt(30)}"}' +
         '{p "age gte(25): {=age | gte(25)}"}' +
         '{p "age lte(24): {=age | lte(24)}"}' +
         '{h3 "In Conditionals"}' +
         '{if {=age | gte(21)}' +
         '  {p "Age {=age} is 21 or over."}' +
         '{else}' +
         '  {p "Age {=age} is under 21."}' +
         '}'),
      nil, OutputFile('Fn_Comparison'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

end.
