{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTestbed;

interface

procedure RunTestbed();

implementation

uses
  System.SysUtils,
  Markup.Utils,
  Markup.TestCase,
  Markup,
  UTest.Demo,
  UTest.Demo.API,
  UTest.Demo.Formatting,
  UTest.Demo.Logic,
  UTest.Demo.Builtins,
  UTest.Demo.Extensibility;

procedure RunTestbed();
var
  LIndex: Integer;
  LParam: string;

  procedure InvalidParam();
  begin
    TMuUtils.PrintLn(COLOR_RED + 'Invalid parameter "%s". Must be 0-36.', [LParam]);
  end;

begin
  try
    TMuUtils.PrintLn(COLOR_CYAN + COLOR_BOLD +
      'Markup™ v' + MuStr(markup_version()) +
      ' — Document Authoring Language');
    TMuUtils.PrintLn('============================================');
    TMuUtils.PrintLn('');

    {$IFDEF RELEASE}
    LIndex := -1;
    {$ELSE}
    LIndex := 4;
    {$ENDIF}

    LParam := ParamStr(1);
    if LParam <> '' then
    begin
      if (not TryStrToInt(LParam, LIndex)) or (LIndex < 0) or (LIndex > 36) then
      begin
        InvalidParam();
        Exit;
      end;
    end;

    // Single test opens browser for debugging; run-all does not
    OpenInBrowser := (LIndex > 0);

    case LIndex of
      // API
      01: Demo_API_ConvertToFile();
      02: Demo_API_ParseRenderMany();
      03: Demo_API_Validate();
      04: Demo_API_LastErrors();
      05: Demo_API_IncludePaths();

      // Formatting
      06: Demo_Fmt_TextInline();
      07: Demo_Fmt_Headings();
      08: Demo_Fmt_LinksMedia();
      09: Demo_Fmt_Lists();
      10: Demo_Fmt_Tables();
      11: Demo_Fmt_CodeBlocks();
      12: Demo_Fmt_Sections();
      13: Demo_Fmt_Quotes();
      14: Demo_Fmt_Callouts();
      15: Demo_Fmt_Details();
      16: Demo_Fmt_VoidTags();
      17: Demo_Fmt_Forms();
      18: Demo_Fmt_Layout();

      // Logic
      19: Demo_Logic_Variables();
      20: Demo_Logic_Eval();
      21: Demo_Logic_Pipes();
      22: Demo_Logic_Conditionals();
      23: Demo_Logic_Iteration();
      24: Demo_Logic_Components();
      25: Demo_Logic_Meta();
      26: Demo_Logic_RawHtml();

      // Builtins
      27: Demo_Fn_String();
      28: Demo_Fn_Math();
      29: Demo_Fn_Collection();
      30: Demo_Fn_Type();
      31: Demo_Fn_Html();
      32: Demo_Fn_Comparison();

      // Extensibility
      33: Demo_Ext_CustomTag();
      34: Demo_Ext_CustomFunction();
      35: Demo_Ext_ErrorHandler();
      36: Demo_Ext_StatusHandler();
      00: begin
        // Run all
        Demo_API_ConvertToFile();
        Demo_API_ParseRenderMany();
        Demo_API_Validate();
        Demo_API_LastErrors();
        Demo_API_IncludePaths();

        Demo_Fmt_TextInline();
        Demo_Fmt_Headings();
        Demo_Fmt_LinksMedia();
        Demo_Fmt_Lists();
        Demo_Fmt_Tables();
        Demo_Fmt_CodeBlocks();
        Demo_Fmt_Sections();
        Demo_Fmt_Quotes();
        Demo_Fmt_Callouts();
        Demo_Fmt_Details();
        Demo_Fmt_VoidTags();
        Demo_Fmt_Forms();
        Demo_Fmt_Layout();

        Demo_Logic_Variables();
        Demo_Logic_Eval();
        Demo_Logic_Pipes();
        Demo_Logic_Conditionals();
        Demo_Logic_Iteration();
        Demo_Logic_Components();
        Demo_Logic_Meta();
        Demo_Logic_RawHtml();

        Demo_Fn_String();
        Demo_Fn_Math();
        Demo_Fn_Collection();
        Demo_Fn_Type();
        Demo_Fn_Html();
        Demo_Fn_Comparison();

        Demo_Ext_CustomTag();
        Demo_Ext_CustomFunction();
        Demo_Ext_ErrorHandler();
        Demo_Ext_StatusHandler();
      end;
      else
        InvalidParam();
    end;
  except
    on E: Exception do
    begin
      TMuUtils.PrintLn('');
      TMuUtils.PrintLn(COLOR_RED + 'EXCEPTION: %s', [E.Message]);
    end;
  end;

  if TMuUtils.RunFromIDE() then
    TMuUtils.Pause();
end;

end.