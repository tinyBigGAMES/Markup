{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.TestCase;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markup.Utils;

type

  { TMuTestCase }
  TMuTestCase = class(TMuBaseObject)
  private
    FTitle: string;
    FAllPassed: Boolean;
    FSectionIndex: Integer;
  protected
    // Subclasses implement the actual test body here. Called by
    // Execute between banner and summary. Inside Run the subclass calls
    // Section / Check / FlushErrors freely.
    procedure Run(); virtual; abstract;
  public
    constructor Create(); override;

    // One-shot entry point: prints the banner, invokes Run, prints the
    // pass/fail summary. Resets FAllPassed / FSectionIndex up front so
    // the same instance can be re-executed if the caller wants.
    procedure Execute();

    // Prints a dim, auto-numbered sub-section header. Each call
    // increments FSectionIndex, so the caller never writes numbers.
    procedure Section(const ATitle: string);

    // Records one assertion. Prints [PASS] green / [FAIL] red and
    // flips FAllPassed to False on any failure. The test's overall
    // result is the AND of every Check call in Run.
    procedure Check(const ACondition: Boolean; const ALabel: string);

    // Prints every entry in AErrors with color-coded severity
    // (HINT / WARN / ERROR / FATAL). Nil-safe, empty-safe.
    procedure PrintErrors(const AErrors: TMuErrors);

    // PrintErrors followed by AErrors.Clear — use this at the end of
    // each object's lifetime in a test so subsequent checks aren't
    // polluted by stale entries from a prior operation.
    procedure FlushErrors(const AErrors: TMuErrors);

    property Title: string read FTitle write FTitle;
    property AllPassed: Boolean read FAllPassed;
  end;

  { TMuTestCaseClass }
  // Metaclass reference — lets MuRunTestCase accept the subclass
  // type (e.g. TVirtualBufferTest) without needing an instance.
  TMuTestCaseClass = class of TMuTestCase;

// Instantiates ATestClass, runs its Execute, frees it. Returns the
// test's overall pass flag so a caller can chain or aggregate
// multiple test runs. Safe to call repeatedly.
function MuRunTestCase(const ATestClass: TMuTestCaseClass): Boolean;

implementation

{ TMuTestCase }

constructor TMuTestCase.Create();
begin
  inherited;
  FTitle := '';
  FAllPassed := True;
  FSectionIndex := 0;
end;

procedure TMuTestCase.Execute();
begin
  // Reset so the same instance can be Execute'd multiple times.
  FAllPassed := True;
  FSectionIndex := 0;

  // Banner
  TMuUtils.PrintLn('');
  TMuUtils.PrintLn(COLOR_CYAN + COLOR_BOLD + '--- %s ---' + COLOR_RESET,
    [FTitle]);

  Run();

  // Summary
  if FAllPassed then
    TMuUtils.PrintLn(COLOR_GREEN + COLOR_BOLD +
      '=== %s: ALL PASSED ===' + COLOR_RESET, [FTitle])
  else
    TMuUtils.PrintLn(COLOR_RED + COLOR_BOLD +
      '=== %s: FAILED ===' + COLOR_RESET, [FTitle]);
end;

procedure TMuTestCase.Section(const ATitle: string);
begin
  Inc(FSectionIndex);
  TMuUtils.PrintLn('');
  TMuUtils.PrintLn(COLOR_BLUE + '  [ %d. %s ]' + COLOR_RESET,
    [FSectionIndex, ATitle]);
end;

procedure TMuTestCase.Check(const ACondition: Boolean; const ALabel: string);
begin
  if ACondition then
    TMuUtils.PrintLn(COLOR_GREEN + '  [PASS] ' + COLOR_RESET + '%s',
      [ALabel])
  else
  begin
    TMuUtils.PrintLn(COLOR_RED + '  [FAIL] ' + COLOR_RESET + '%s',
      [ALabel]);
    FAllPassed := False;
  end;
end;

procedure TMuTestCase.PrintErrors(const AErrors: TMuErrors);
var
  LItems: TList<TMuError>;
  LI: Integer;
  LErr: TMuError;
  LColor: string;
  LLabel: string;
begin
  if AErrors = nil then
    Exit;
  LItems := AErrors.GetItems();
  if LItems.Count = 0 then
    Exit;

  TMuUtils.PrintLn('');
  for LI := 0 to LItems.Count - 1 do
  begin
    LErr := LItems[LI];
    case LErr.Severity of
      esHint:
      begin
        LColor := COLOR_CYAN;
        LLabel := 'HINT';
      end;
      esWarning:
      begin
        LColor := COLOR_YELLOW;
        LLabel := 'WARN';
      end;
      esError:
      begin
        LColor := COLOR_RED;
        LLabel := 'ERROR';
      end;
      esFatal:
      begin
        LColor := COLOR_MAGENTA;
        LLabel := 'FATAL';
      end;
    else
      LColor := COLOR_WHITE;
      LLabel := '?';
    end;

    if LErr.Code <> '' then
      TMuUtils.PrintLn(LColor + '[%s] %s: %s',
        [LLabel, LErr.Code, LErr.Message])
    else
      TMuUtils.PrintLn(LColor + '[%s] %s', [LLabel, LErr.Message]);
  end;
end;

procedure TMuTestCase.FlushErrors(const AErrors: TMuErrors);
begin
  PrintErrors(AErrors);
  if AErrors <> nil then
    AErrors.Clear();
end;

{ MuRunTestCase }

function MuRunTestCase(const ATestClass: TMuTestCaseClass): Boolean;
var
  LTest: TMuTestCase;
begin
  Result := False;
  if ATestClass = nil then
    Exit;

  // Virtual constructor dispatch — ATestClass.Create() runs the
  // most-derived override, so we actually get a fully-initialized
  // subclass instance even though LTest is declared as the base.
  LTest := ATestClass.Create();
  try
    LTest.Execute();
    Result := LTest.AllPassed;
  finally
    LTest.Free();
  end;
end;

end.
