{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Demo.Extensibility;

{$I Markup.Defines.inc}

interface

procedure Demo_Ext_CustomTag();
procedure Demo_Ext_CustomFunction();
procedure Demo_Ext_ErrorHandler();
procedure Demo_Ext_StatusHandler();

implementation

uses
  System.SysUtils,
  Markup.Utils,
  Markup,
  UTest.Demo;

// =========================================================================
// Custom Tag Handler — {alert level=info/warning/danger "..."}
// =========================================================================
procedure AlertTagHandler(const ACtx: TMuCtx;
  const AUserData: Pointer);
var
  LLevel: PAnsiChar;
begin
  markup_ctx_emit(ACtx, Mu('<div class="alert'));
  if markup_ctx_has_attr(ACtx, Mu('level')) then
  begin
    LLevel := markup_ctx_attr(ACtx, Mu('level'));
    try
      markup_ctx_emit(ACtx, Mu(' alert-'));
      markup_ctx_emit(ACtx, LLevel);
    finally
      markup_free(LLevel);
    end;
  end;
  markup_ctx_emit(ACtx, Mu('" role="alert">'));
  markup_ctx_emit_children(ACtx);
  markup_ctx_emit(ACtx, Mu('</div>'));
end;

procedure Demo_Ext_CustomTag();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Ext: Custom Tag');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    markup_register_tag(LEngine, Mu('alert'), AlertTagHandler, nil);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Custom Tag: alert"}' +
         '{alert level=info "This is an informational message."}' +
         '{alert level=warning "{b "Warning:"} Check your config."}' +
         '{alert level=danger "Critical failure — action required!"}'),
      nil, OutputFile('Ext_CustomTag'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// Custom Function — format_price(amount, currency?)
// =========================================================================
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
      LCurrStr := MuStr(LCurrency);
    finally
      markup_free(LCurrency);
    end;
  end
  else
    LCurrStr := '$';

  Result := markup_result_string(
    Mu(LCurrStr + FormatFloat('#,##0.00', LPrice)));
end;

procedure Demo_Ext_CustomFunction();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Ext: Custom Function');
  LEngine := markup_create();
  try
    DemoSetHandlers(LEngine);
    markup_register_function(LEngine, Mu('format_price'),
      FormatPriceFunc, nil);
    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h2 "Custom Function: format_price"}' +
         '{each {get data.items} item' +
         '  {p "{=item.name}: {=format_price(item.price)}"}' +
         '}' +
         '{p class=total "{b "Total: {=format_price(data.total)}"}"}'),
      Mu('{"items":[' +
         '{"name":"Espresso","price":4.50},' +
         '{"name":"Croissant","price":3.25},' +
         '{"name":"Orange Juice","price":5.00}' +
         '],"total":12.75}'),
      OutputFile('Ext_CustomFunction'), OpenInBrowser));
  finally
    markup_destroy(LEngine);
  end;
end;

// =========================================================================
// Error Handler — demonstrates custom error callback
// =========================================================================
procedure ExtErrorCallback(const ASeverity: Integer;
  const ACode: PAnsiChar; const AMessage: PAnsiChar;
  const AUserData: Pointer);
var
  LSevLabel: string;
begin
  case ASeverity of
    0: LSevLabel := 'HINT';
    1: LSevLabel := 'WARN';
    2: LSevLabel := 'ERROR';
    3: LSevLabel := 'FATAL';
  else
    LSevLabel := '?';
  end;
  TMuUtils.PrintLn(COLOR_YELLOW + '    [%s] %s: %s' + COLOR_RESET,
    [LSevLabel, MuStr(ACode), MuStr(AMessage)]);
end;

procedure Demo_Ext_ErrorHandler();
var
  LEngine: TMuEngine;
  LErrors: PAnsiChar;
begin
  DemoHeader('Ext: Error Handler');
  LEngine := markup_create();
  try
    markup_set_error_handler(LEngine, ExtErrorCallback, nil);

    TMuUtils.PrintLn('  Validating broken source:');
    LErrors := markup_validate(LEngine,
      Mu('{include "missing_file.mu"}'));
    try
      TMuUtils.PrintLn('  Diagnostics: ' + MuStr(LErrors));
    finally
      markup_free(LErrors);
    end;

    markup_set_error_handler(LEngine, nil, nil);
  finally
    markup_destroy(LEngine);
  end;
  TMuUtils.PrintLn('');
end;

// =========================================================================
// Status Handler — demonstrates pipeline status callback
// =========================================================================
procedure ExtStatusCallback(const AText: PAnsiChar;
  const AUserData: Pointer);
begin
  TMuUtils.PrintLn(COLOR_MAGENTA + '    [STATUS] %s' + COLOR_RESET,
    [MuStr(AText)]);
end;

procedure Demo_Ext_StatusHandler();
var
  LEngine: TMuEngine;
begin
  DemoHeader('Ext: Status Handler');
  LEngine := markup_create();
  try
    markup_set_status_handler(LEngine, ExtStatusCallback, nil);

    DemoResult(markup_convert_to_file(LEngine,
      Mu('{h1 "Status Demo"}' +
         '{p "Watch the console for pipeline status messages."}'),
      nil, OutputFile('Ext_StatusHandler'), OpenInBrowser));

    markup_set_status_handler(LEngine, nil, nil);
  finally
    markup_destroy(LEngine);
  end;
end;

end.
