{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Environment;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markup.Utils,
  Markup.Resources,
  Markup.Value;

const
  MU_ERROR_ENV_POP_GLOBAL = 'MS-N001';

type
  { TMuScope }
  TMuScope = TDictionary<string, TMuValue>;

  { TMuEnvironment }
  TMuEnvironment = class(TMuBaseObject)
  private
    FScopeStack: TObjectList<TMuScope>;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Push();
    procedure Pop();

    procedure Bind(const AName: string; const AValue: TMuValue);
    procedure Update(const AName: string; const AValue: TMuValue);
    function Resolve(const AName: string): TMuValue;
    function HasVar(const AName: string): Boolean;

    function Depth(): Integer;
    procedure Clear();
  end;

implementation

{ TMuEnvironment }

constructor TMuEnvironment.Create();
begin
  inherited;
  FScopeStack := TObjectList<TMuScope>.Create(True);
  Push(); // global scope
end;

destructor TMuEnvironment.Destroy();
begin
  FreeAndNil(FScopeStack);
  inherited;
end;

procedure TMuEnvironment.Push();
var
  LScope: TMuScope;
begin
  LScope := TMuScope.Create();
  FScopeStack.Add(LScope);
end;

procedure TMuEnvironment.Pop();
begin
  if FScopeStack.Count <= 1 then
  begin
    FErrors.Add(esError, MU_ERROR_ENV_POP_GLOBAL, RSEnvPopGlobal);
    Exit;
  end;
  FScopeStack.Delete(FScopeStack.Count - 1);
end;

procedure TMuEnvironment.Bind(const AName: string; const AValue: TMuValue);
var
  LScope: TMuScope;
begin
  LScope := FScopeStack[FScopeStack.Count - 1];
  LScope.AddOrSetValue(AName, AValue);
end;

procedure TMuEnvironment.Update(const AName: string; const AValue: TMuValue);
var
  LI: Integer;
  LScope: TMuScope;
begin
  // Walk scope chain from top to find nearest definition
  for LI := FScopeStack.Count - 1 downto 0 do
  begin
    LScope := FScopeStack[LI];
    if LScope.ContainsKey(AName) then
    begin
      LScope.AddOrSetValue(AName, AValue);
      Exit;
    end;
  end;

  // Not found — create in current scope (spec §4.1: implementation SHOULD create)
  FScopeStack[FScopeStack.Count - 1].AddOrSetValue(AName, AValue);
end;

function TMuEnvironment.Resolve(const AName: string): TMuValue;
var
  LI: Integer;
  LScope: TMuScope;
begin
  // Walk scope chain from top
  for LI := FScopeStack.Count - 1 downto 0 do
  begin
    LScope := FScopeStack[LI];
    if LScope.TryGetValue(AName, Result) then
      Exit;
  end;

  // Not found — return nil (spec §4.1: empty string / no error)
  Result := TMuValue.CreateNil();
end;

function TMuEnvironment.HasVar(const AName: string): Boolean;
var
  LI: Integer;
  LScope: TMuScope;
begin
  for LI := FScopeStack.Count - 1 downto 0 do
  begin
    LScope := FScopeStack[LI];
    if LScope.ContainsKey(AName) then
      Exit(True);
  end;
  Result := False;
end;

function TMuEnvironment.Depth(): Integer;
begin
  Result := FScopeStack.Count;
end;

procedure TMuEnvironment.Clear();
begin
  FScopeStack.Clear();
  Push(); // restore global scope
end;

end.
