{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Builtins;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  Markup.Utils,
  Markup.Resources,
  Markup.Value;

const
  MU_ERROR_BUILTIN_UNKNOWN   = 'MS-B001';
  MU_ERROR_BUILTIN_ARG_COUNT = 'MS-B002';
  MU_ERROR_BUILTIN_TYPE      = 'MS-B003';

type
  { TMuBuiltinFunc }
  TMuBuiltinFunc = reference to function(
    const AArgs: TArray<TMuValue>): TMuValue;

  { TMuBuiltins }
  TMuBuiltins = class(TMuBaseObject)
  private
    FFuncs: TDictionary<string, TMuBuiltinFunc>;
    FAllocations: TObjectList<TObject>;

    procedure RegisterAll();

    // String functions
    function FnUpper(const AArgs: TArray<TMuValue>): TMuValue;
    function FnLower(const AArgs: TArray<TMuValue>): TMuValue;
    function FnTrim(const AArgs: TArray<TMuValue>): TMuValue;
    function FnLen(const AArgs: TArray<TMuValue>): TMuValue;
    function FnSubstr(const AArgs: TArray<TMuValue>): TMuValue;
    function FnReplace(const AArgs: TArray<TMuValue>): TMuValue;
    function FnSplit(const AArgs: TArray<TMuValue>): TMuValue;
    function FnJoin(const AArgs: TArray<TMuValue>): TMuValue;
    function FnStartsWith(const AArgs: TArray<TMuValue>): TMuValue;
    function FnEndsWith(const AArgs: TArray<TMuValue>): TMuValue;
    function FnContains(const AArgs: TArray<TMuValue>): TMuValue;

    // Math functions
    function FnRound(const AArgs: TArray<TMuValue>): TMuValue;
    function FnFloor(const AArgs: TArray<TMuValue>): TMuValue;
    function FnCeil(const AArgs: TArray<TMuValue>): TMuValue;
    function FnAbs(const AArgs: TArray<TMuValue>): TMuValue;
    function FnMin(const AArgs: TArray<TMuValue>): TMuValue;
    function FnMax(const AArgs: TArray<TMuValue>): TMuValue;

    // Collection functions
    function FnCount(const AArgs: TArray<TMuValue>): TMuValue;
    function FnFirst(const AArgs: TArray<TMuValue>): TMuValue;
    function FnLast(const AArgs: TArray<TMuValue>): TMuValue;
    function FnIndex(const AArgs: TArray<TMuValue>): TMuValue;
    function FnRange(const AArgs: TArray<TMuValue>): TMuValue;
    function FnSort(const AArgs: TArray<TMuValue>): TMuValue;
    function FnReverse(const AArgs: TArray<TMuValue>): TMuValue;
    function FnKeys(const AArgs: TArray<TMuValue>): TMuValue;
    function FnValues(const AArgs: TArray<TMuValue>): TMuValue;

    // Type functions
    function FnTypeof(const AArgs: TArray<TMuValue>): TMuValue;
    function FnToStr(const AArgs: TArray<TMuValue>): TMuValue;
    function FnToInt(const AArgs: TArray<TMuValue>): TMuValue;
    function FnToFloat(const AArgs: TArray<TMuValue>): TMuValue;

    // HTML functions
    function FnEscape(const AArgs: TArray<TMuValue>): TMuValue;
    function FnRaw(const AArgs: TArray<TMuValue>): TMuValue;
    function FnNl2br(const AArgs: TArray<TMuValue>): TMuValue;

    // Comparison functions
    function FnEq(const AArgs: TArray<TMuValue>): TMuValue;
    function FnNeq(const AArgs: TArray<TMuValue>): TMuValue;
    function FnGt(const AArgs: TArray<TMuValue>): TMuValue;
    function FnLt(const AArgs: TArray<TMuValue>): TMuValue;
    function FnGte(const AArgs: TArray<TMuValue>): TMuValue;
    function FnLte(const AArgs: TArray<TMuValue>): TMuValue;

    // Date functions
    function FnNow(const AArgs: TArray<TMuValue>): TMuValue;
    function FnFormatDate(const AArgs: TArray<TMuValue>): TMuValue;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Call(const AName: string;
      const AArgs: TArray<TMuValue>): TMuValue;
    function HasFunction(const AName: string): Boolean;
    procedure RegisterFunc(const AName: string;
      const AFunc: TMuBuiltinFunc);
    function TrackObject(const AObj: TObject): TObject;
    procedure FreeAllocations();
  end;

implementation

{ TMuBuiltins }

constructor TMuBuiltins.Create();
begin
  inherited;
  FFuncs := TDictionary<string, TMuBuiltinFunc>.Create();
  FAllocations := TObjectList<TObject>.Create(False);
  RegisterAll();
end;

destructor TMuBuiltins.Destroy();
begin
  FreeAllocations();
  FreeAndNil(FAllocations);
  FreeAndNil(FFuncs);
  inherited;
end;

procedure TMuBuiltins.RegisterAll();
begin
  // String
  FFuncs.Add('upper', FnUpper);
  FFuncs.Add('lower', FnLower);
  FFuncs.Add('trim', FnTrim);
  FFuncs.Add('len', FnLen);
  FFuncs.Add('substr', FnSubstr);
  FFuncs.Add('replace', FnReplace);
  FFuncs.Add('split', FnSplit);
  FFuncs.Add('join', FnJoin);
  FFuncs.Add('startsWith', FnStartsWith);
  FFuncs.Add('endsWith', FnEndsWith);
  FFuncs.Add('contains', FnContains);

  // Math
  FFuncs.Add('round', FnRound);
  FFuncs.Add('floor', FnFloor);
  FFuncs.Add('ceil', FnCeil);
  FFuncs.Add('abs', FnAbs);
  FFuncs.Add('min', FnMin);
  FFuncs.Add('max', FnMax);

  // Collection
  FFuncs.Add('count', FnCount);
  FFuncs.Add('first', FnFirst);
  FFuncs.Add('last', FnLast);
  FFuncs.Add('index', FnIndex);
  FFuncs.Add('range', FnRange);
  FFuncs.Add('sort', FnSort);
  FFuncs.Add('reverse', FnReverse);
  FFuncs.Add('keys', FnKeys);
  FFuncs.Add('values', FnValues);

  // Type
  FFuncs.Add('typeof', FnTypeof);
  FFuncs.Add('toStr', FnToStr);
  FFuncs.Add('toInt', FnToInt);
  FFuncs.Add('toFloat', FnToFloat);

  // HTML
  FFuncs.Add('escape', FnEscape);
  FFuncs.Add('raw', FnRaw);
  FFuncs.Add('nl2br', FnNl2br);

  // Comparison
  FFuncs.Add('eq', FnEq);
  FFuncs.Add('neq', FnNeq);
  FFuncs.Add('gt', FnGt);
  FFuncs.Add('lt', FnLt);
  FFuncs.Add('gte', FnGte);
  FFuncs.Add('lte', FnLte);

  // Date
  FFuncs.Add('now', FnNow);
  FFuncs.Add('formatDate', FnFormatDate);
end;

function TMuBuiltins.Call(const AName: string;
  const AArgs: TArray<TMuValue>): TMuValue;
var
  LFunc: TMuBuiltinFunc;
begin
  if not FFuncs.TryGetValue(AName, LFunc) then
  begin
    FErrors.Add(esError, MU_ERROR_BUILTIN_UNKNOWN,
      RSBuiltinUnknown, [AName]);
    Result := TMuValue.CreateNil();
    Exit;
  end;
  Result := LFunc(AArgs);
end;

function TMuBuiltins.HasFunction(const AName: string): Boolean;
begin
  Result := FFuncs.ContainsKey(AName);
end;

procedure TMuBuiltins.RegisterFunc(const AName: string;
  const AFunc: TMuBuiltinFunc);
begin
  FFuncs.AddOrSetValue(AName, AFunc);
end;

function TMuBuiltins.TrackObject(const AObj: TObject): TObject;
begin
  FAllocations.Add(AObj);
  Result := AObj;
end;

procedure TMuBuiltins.FreeAllocations();
var
  LI: Integer;
begin
  // Clear items first to prevent cascade freeing of shared children,
  // then free the empty container objects
  for LI := FAllocations.Count - 1 downto 0 do
  begin
    if FAllocations[LI] is TMuList then
      TMuList(FAllocations[LI]).Clear()
    else if FAllocations[LI] is TMuMap then
      TMuMap(FAllocations[LI]).Clear();
    FAllocations[LI].Free();
  end;
  FAllocations.Clear();
end;

{ String Functions }

function TMuBuiltins.FnUpper(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromString(AArgs[0].AsString().ToUpper());
end;

function TMuBuiltins.FnLower(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromString(AArgs[0].AsString().ToLower());
end;

function TMuBuiltins.FnTrim(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromString(AArgs[0].AsString().Trim());
end;

function TMuBuiltins.FnLen(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  if AArgs[0].Kind = vkList then
    Result := TMuValue.FromInteger(AArgs[0].AsList().Count)
  else if AArgs[0].Kind = vkMap then
    Result := TMuValue.FromInteger(AArgs[0].AsMap().Count)
  else
    Result := TMuValue.FromInteger(Length(AArgs[0].AsString()));
end;

function TMuBuiltins.FnSubstr(const AArgs: TArray<TMuValue>): TMuValue;
var
  LS: string;
  LStart: Integer;
  LLen: Integer;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  LS := AArgs[0].AsString();
  LStart := AArgs[1].AsInteger();
  if Length(AArgs) >= 3 then
    LLen := AArgs[2].AsInteger()
  else
    LLen := Length(LS) - LStart;
  // Spec: zero-based start
  Result := TMuValue.FromString(Copy(LS, LStart + 1, LLen));
end;

function TMuBuiltins.FnReplace(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 3 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromString(
    AArgs[0].AsString().Replace(AArgs[1].AsString(), AArgs[2].AsString(),
      [rfReplaceAll]));
end;

function TMuBuiltins.FnSplit(const AArgs: TArray<TMuValue>): TMuValue;
var
  LParts: TArray<string>;
  LList: TMuList;
  LI: Integer;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  LParts := AArgs[0].AsString().Split([AArgs[1].AsString()]);
  LList := TMuList.Create();
  LList.SetErrors(FErrors);
  TrackObject(LList);
  for LI := 0 to Length(LParts) - 1 do
    LList.Add(TMuValue.FromString(LParts[LI]));
  Result := TMuValue.FromList(LList);
end;

function TMuBuiltins.FnJoin(const AArgs: TArray<TMuValue>): TMuValue;
var
  LList: TMuList;
  LDelim: string;
  LResult: string;
  LI: Integer;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  if AArgs[0].Kind <> vkList then
    Exit(TMuValue.CreateNil());
  LList := AArgs[0].AsList();
  LDelim := AArgs[1].AsString();
  LResult := '';
  for LI := 0 to LList.Count - 1 do
  begin
    if LI > 0 then
      LResult := LResult + LDelim;
    LResult := LResult + LList[LI].AsString();
  end;
  Result := TMuValue.FromString(LResult);
end;

function TMuBuiltins.FnStartsWith(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromBoolean(
    AArgs[0].AsString().StartsWith(AArgs[1].AsString()));
end;

function TMuBuiltins.FnEndsWith(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromBoolean(
    AArgs[0].AsString().EndsWith(AArgs[1].AsString()));
end;

function TMuBuiltins.FnContains(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromBoolean(
    AArgs[0].AsString().Contains(AArgs[1].AsString()));
end;

{ Math Functions }

function TMuBuiltins.FnRound(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromInteger(Round(AArgs[0].AsFloat()));
end;

function TMuBuiltins.FnFloor(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromInteger(Floor(AArgs[0].AsFloat()));
end;

function TMuBuiltins.FnCeil(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  Result := TMuValue.FromInteger(Ceil(AArgs[0].AsFloat()));
end;

function TMuBuiltins.FnAbs(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.CreateNil());
  if AArgs[0].Kind = vkFloat then
    Result := TMuValue.FromFloat(System.Abs(AArgs[0].AsFloat()))
  else
    Result := TMuValue.FromInteger(System.Abs(AArgs[0].AsInteger()));
end;

function TMuBuiltins.FnMin(const AArgs: TArray<TMuValue>): TMuValue;
var
  LA: Double;
  LB: Double;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  LA := AArgs[0].AsFloat();
  LB := AArgs[1].AsFloat();
  if LA <= LB then
    Result := AArgs[0]
  else
    Result := AArgs[1];
end;

function TMuBuiltins.FnMax(const AArgs: TArray<TMuValue>): TMuValue;
var
  LA: Double;
  LB: Double;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  LA := AArgs[0].AsFloat();
  LB := AArgs[1].AsFloat();
  if LA >= LB then
    Result := AArgs[0]
  else
    Result := AArgs[1];
end;

{ Collection Functions }

function TMuBuiltins.FnCount(const AArgs: TArray<TMuValue>): TMuValue;
begin
  Result := FnLen(AArgs); // alias per spec
end;

function TMuBuiltins.FnFirst(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if (Length(AArgs) < 1) or (AArgs[0].Kind <> vkList) then
    Exit(TMuValue.CreateNil());
  if AArgs[0].AsList().Count = 0 then
    Exit(TMuValue.CreateNil());
  Result := AArgs[0].AsList()[0];
end;

function TMuBuiltins.FnLast(const AArgs: TArray<TMuValue>): TMuValue;
var
  LList: TMuList;
begin
  if (Length(AArgs) < 1) or (AArgs[0].Kind <> vkList) then
    Exit(TMuValue.CreateNil());
  LList := AArgs[0].AsList();
  if LList.Count = 0 then
    Exit(TMuValue.CreateNil());
  Result := LList[LList.Count - 1];
end;

function TMuBuiltins.FnIndex(const AArgs: TArray<TMuValue>): TMuValue;
var
  LList: TMuList;
  LIdx: Integer;
begin
  if (Length(AArgs) < 2) or (AArgs[0].Kind <> vkList) then
    Exit(TMuValue.CreateNil());
  LList := AArgs[0].AsList();
  LIdx := AArgs[1].AsInteger();
  if (LIdx < 0) or (LIdx >= LList.Count) then
    Exit(TMuValue.CreateNil());
  Result := LList[LIdx];
end;

function TMuBuiltins.FnRange(const AArgs: TArray<TMuValue>): TMuValue;
var
  LStart: Int64;
  LEnd: Int64;
  LList: TMuList;
  LI: Int64;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  LStart := AArgs[0].AsInteger();
  LEnd := AArgs[1].AsInteger();
  LList := TMuList.Create();
  LList.SetErrors(FErrors);
  TrackObject(LList);
  LI := LStart;
  while LI < LEnd do
  begin
    LList.Add(TMuValue.FromInteger(LI));
    Inc(LI);
  end;
  Result := TMuValue.FromList(LList);
end;

function TMuBuiltins.FnSort(const AArgs: TArray<TMuValue>): TMuValue;
var
  LList: TMuList;
begin
  if (Length(AArgs) < 1) or (AArgs[0].Kind <> vkList) then
    Exit(TMuValue.CreateNil());
  LList := AArgs[0].AsList();
  LList.SortList();
  Result := AArgs[0]; // sort in place, return same list
end;

function TMuBuiltins.FnReverse(const AArgs: TArray<TMuValue>): TMuValue;
var
  LList: TMuList;
begin
  if (Length(AArgs) < 1) or (AArgs[0].Kind <> vkList) then
    Exit(TMuValue.CreateNil());
  LList := AArgs[0].AsList();
  LList.Reverse();
  Result := AArgs[0];
end;

function TMuBuiltins.FnKeys(const AArgs: TArray<TMuValue>): TMuValue;
var
  LMap: TMuMap;
  LList: TMuList;
  LKeyArr: TArray<string>;
  LI: Integer;
begin
  if (Length(AArgs) < 1) or (AArgs[0].Kind <> vkMap) then
    Exit(TMuValue.CreateNil());
  LMap := AArgs[0].AsMap();
  LKeyArr := LMap.GetKeys();
  LList := TMuList.Create();
  LList.SetErrors(FErrors);
  TrackObject(LList);
  for LI := 0 to Length(LKeyArr) - 1 do
    LList.Add(TMuValue.FromString(LKeyArr[LI]));
  Result := TMuValue.FromList(LList);
end;

function TMuBuiltins.FnValues(const AArgs: TArray<TMuValue>): TMuValue;
var
  LMap: TMuMap;
  LList: TMuList;
  LValArr: TArray<TMuValue>;
  LI: Integer;
begin
  if (Length(AArgs) < 1) or (AArgs[0].Kind <> vkMap) then
    Exit(TMuValue.CreateNil());
  LMap := AArgs[0].AsMap();
  LValArr := LMap.GetValues();
  LList := TMuList.Create();
  LList.SetErrors(FErrors);
  TrackObject(LList);
  for LI := 0 to Length(LValArr) - 1 do
    LList.Add(LValArr[LI]);
  Result := TMuValue.FromList(LList);
end;

{ Type Functions }

function TMuBuiltins.FnTypeof(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.FromString('nil'));
  Result := TMuValue.FromString(AArgs[0].TypeNameStr());
end;

function TMuBuiltins.FnToStr(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.FromString(''));
  Result := TMuValue.FromString(AArgs[0].AsString());
end;

function TMuBuiltins.FnToInt(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.FromInteger(0));
  Result := TMuValue.FromInteger(AArgs[0].AsInteger());
end;

function TMuBuiltins.FnToFloat(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.FromFloat(0.0));
  Result := TMuValue.FromFloat(AArgs[0].AsFloat());
end;

{ HTML Functions }

function TMuBuiltins.FnEscape(const AArgs: TArray<TMuValue>): TMuValue;
var
  LS: string;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.FromString(''));
  LS := AArgs[0].AsString();
  LS := LS.Replace('&', '&amp;', [rfReplaceAll]);
  LS := LS.Replace('<', '&lt;', [rfReplaceAll]);
  LS := LS.Replace('>', '&gt;', [rfReplaceAll]);
  LS := LS.Replace('"', '&quot;', [rfReplaceAll]);
  Result := TMuValue.FromString(LS);
end;

function TMuBuiltins.FnRaw(const AArgs: TArray<TMuValue>): TMuValue;
begin
  // raw() marks a string as safe — no escaping applied
  // The interpreter checks for this when emitting
  if Length(AArgs) < 1 then
    Exit(TMuValue.FromString(''));
  Result := AArgs[0]; // pass through unchanged
end;

function TMuBuiltins.FnNl2br(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 1 then
    Exit(TMuValue.FromString(''));
  Result := TMuValue.FromString(
    AArgs[0].AsString().Replace(#10, '<br />', [rfReplaceAll]));
end;

{ Comparison Functions }

function TMuBuiltins.FnEq(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.FromBoolean(False));
  Result := TMuValue.FromBoolean(
    AArgs[0].AsString() = AArgs[1].AsString());
end;

function TMuBuiltins.FnNeq(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.FromBoolean(True));
  Result := TMuValue.FromBoolean(
    AArgs[0].AsString() <> AArgs[1].AsString());
end;

function TMuBuiltins.FnGt(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.FromBoolean(False));
  Result := TMuValue.FromBoolean(
    AArgs[0].AsFloat() > AArgs[1].AsFloat());
end;

function TMuBuiltins.FnLt(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.FromBoolean(False));
  Result := TMuValue.FromBoolean(
    AArgs[0].AsFloat() < AArgs[1].AsFloat());
end;

function TMuBuiltins.FnGte(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.FromBoolean(False));
  Result := TMuValue.FromBoolean(
    AArgs[0].AsFloat() >= AArgs[1].AsFloat());
end;

function TMuBuiltins.FnLte(const AArgs: TArray<TMuValue>): TMuValue;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.FromBoolean(False));
  Result := TMuValue.FromBoolean(
    AArgs[0].AsFloat() <= AArgs[1].AsFloat());
end;

{ Date Functions }

function TMuBuiltins.FnNow(const AArgs: TArray<TMuValue>): TMuValue;
begin
  Result := TMuValue.FromString(FormatDateTime('yyyy-mm-dd hh:nn:ss', Now()));
end;

function TMuBuiltins.FnFormatDate(const AArgs: TArray<TMuValue>): TMuValue;
var
  LDate: TDateTime;
  LFmt: string;
begin
  if Length(AArgs) < 2 then
    Exit(TMuValue.CreateNil());
  if not TryStrToDateTime(AArgs[0].AsString(), LDate) then
    Exit(TMuValue.CreateNil());
  LFmt := AArgs[1].AsString();
  Result := TMuValue.FromString(FormatDateTime(LFmt, LDate));
end;

end.
