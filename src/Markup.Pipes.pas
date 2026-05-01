{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Pipes;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  Markup.Utils,
  Markup.Resources,
  Markup.Value,
  Markup.Builtins,
  Markup.ExprParser;

const
  MU_ERROR_PIPE_UNKNOWN_FUNC = 'MS-I001';

type
  { TMuPipeChain }
  TMuPipeChain = class(TMuBaseObject)
  private
    FBuiltins: TMuBuiltins;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure SetBuiltins(const ABuiltins: TMuBuiltins);

    // Evaluate a pipe chain: input | func1 | func2(arg1, arg2)
    // AInput is the starting value, APipes is a list of pipe steps
    function Evaluate(const AInput: TMuValue;
      const AFuncName: string;
      const AArgs: TArray<TMuValue>): TMuValue;
  end;

implementation

{ TMuPipeChain }

constructor TMuPipeChain.Create();
begin
  inherited;
  FBuiltins := nil;
end;

destructor TMuPipeChain.Destroy();
begin
  inherited;
end;

procedure TMuPipeChain.SetBuiltins(const ABuiltins: TMuBuiltins);
begin
  FBuiltins := ABuiltins;
end;

function TMuPipeChain.Evaluate(const AInput: TMuValue;
  const AFuncName: string;
  const AArgs: TArray<TMuValue>): TMuValue;
var
  LFullArgs: TArray<TMuValue>;
  LI: Integer;
begin
  if FBuiltins = nil then
  begin
    Result := TMuValue.CreateNil();
    Exit;
  end;

  if not FBuiltins.HasFunction(AFuncName) then
  begin
    FErrors.Add(esError, MU_ERROR_PIPE_UNKNOWN_FUNC,
      RSPipeUnknownFunc, [AFuncName]);
    Result := TMuValue.CreateNil();
    Exit;
  end;

  // Build args: piped value is always the first argument
  SetLength(LFullArgs, Length(AArgs) + 1);
  LFullArgs[0] := AInput;
  for LI := 0 to Length(AArgs) - 1 do
    LFullArgs[LI + 1] := AArgs[LI];

  Result := FBuiltins.Call(AFuncName, LFullArgs);
end;

end.
