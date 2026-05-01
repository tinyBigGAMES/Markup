{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.Demo;

{$I Markup.Defines.inc}

interface

uses
  Markup.Utils,
  Markup;

const
  /// <summary>
  ///   Output folder for all demo HTML files (relative to the executable).
  /// </summary>
  OutputPath = 'output';

var
  /// <summary>
  ///   Whether to open generated HTML files in the default browser.
  ///   Set to True for single tests, False when running all.
  /// </summary>
  OpenInBrowser: Boolean = False;

/// <summary>
///   Short alias for TMuUtils.AsUTF8 — converts a Delphi string to a
///   UTF-8 pointer suitable for passing to Markup DLL API functions.
/// </summary>
function Mu(const AStr: string): Pointer;

/// <summary>
///   Short alias for TMuUtils.FromUtf8 — converts a UTF-8 PAnsiChar
///   returned by the Markup DLL API to a Delphi string.
/// </summary>
function MuStr(const APtr: PAnsiChar): string;

/// <summary>
///   Returns the full output file path as UTF-8 for a given demo name.
///   The engine forces the .html extension and creates directories.
/// </summary>
function OutputFile(const AName: string): Pointer;

/// <summary>
///   Prints a colored demo section header to the console.
/// </summary>
procedure DemoHeader(const ATitle: string);

/// <summary>
///   Wires shared status and error handler callbacks onto an engine
///   so all pipeline stages and errors are printed to the console.
/// </summary>
procedure DemoSetHandlers(const AEngine: TMuEngine);

/// <summary>
///   Prints OK (green) or FAIL (red) followed by a trailing blank line.
/// </summary>
procedure DemoResult(const ASuccess: Boolean);

implementation

uses
  System.SysUtils;

{ Short aliases }

function Mu(const AStr: string): Pointer;
begin
  Result := TMuUtils.AsUTF8(AStr);
end;

function MuStr(const APtr: PAnsiChar): string;
begin
  Result := TMuUtils.FromUtf8(APtr);
end;

function OutputFile(const AName: string): Pointer;
begin
  Result := TMuUtils.AsUTF8(OutputPath + '\' + AName);
end;

{ Shared callbacks }

procedure DemoErrorCallback(const ASeverity: Integer;
  const ACode: PAnsiChar; const AMessage: PAnsiChar;
  const AUserData: Pointer);
var
  LSevLabel: string;
  LColor: string;
begin
  case ASeverity of
    0:
    begin
      LSevLabel := 'HINT';
      LColor := COLOR_CYAN;
    end;
    1:
    begin
      LSevLabel := 'WARN';
      LColor := COLOR_YELLOW;
    end;
    2:
    begin
      LSevLabel := 'ERROR';
      LColor := COLOR_RED;
    end;
    3:
    begin
      LSevLabel := 'FATAL';
      LColor := COLOR_RED + COLOR_BOLD;
    end;
  else
    LSevLabel := '?';
    LColor := COLOR_WHITE;
  end;
  TMuUtils.PrintLn(LColor + '  [%s] %s: %s',
    [LSevLabel, TMuUtils.FromUtf8(ACode), TMuUtils.FromUtf8(AMessage)]);
end;

procedure DemoStatusCallback(const AText: PAnsiChar;
  const AUserData: Pointer);
begin
  TMuUtils.PrintLn(COLOR_MAGENTA + '  %s',
    [TMuUtils.FromUtf8(AText)]);
end;

{ Lifecycle helpers }

procedure DemoHeader(const ATitle: string);
begin
  TMuUtils.PrintLn(COLOR_CYAN + COLOR_BOLD +
    '--- ' + ATitle + ' ---');
end;

procedure DemoSetHandlers(const AEngine: TMuEngine);
begin
  markup_set_error_handler(AEngine, DemoErrorCallback, nil);
  markup_set_status_handler(AEngine, DemoStatusCallback, nil);
  markup_set_pretty_print(AEngine, True);
end;

procedure DemoResult(const ASuccess: Boolean);
begin
  if ASuccess then
    TMuUtils.PrintLn(COLOR_GREEN + '  OK')
  else
    TMuUtils.PrintLn(COLOR_RED + '  FAIL');
  TMuUtils.PrintLn('');
end;

end.
