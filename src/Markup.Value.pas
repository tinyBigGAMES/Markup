{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Value;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Rtti,
  System.Generics.Collections,
  System.Generics.Defaults,
  Markup.Utils;

type
  // Forward declarations
  TMuList = class;
  TMuMap  = class;

  { TMuValueKind }
  TMuValueKind = (
    vkNil,
    vkString,
    vkInteger,
    vkUInt64,
    vkFloat,
    vkBoolean,
    vkList,
    vkMap
  );

  { PMuValue }
  PMuValue = ^TMuValue;

  { TMuValue - Tagged value record wrapping TValue }
  TMuValue = record
    Kind: TMuValueKind;
    Value: TValue;

    // Conversion
    function AsString(): string;
    function AsInteger(): Int64;
    function AsUInt64(): UInt64;
    function AsFloat(): Double;
    function AsBoolean(): Boolean;
    function AsList(): TMuList;
    function AsMap(): TMuMap;

    // Queries
    function IsTruthy(): Boolean;
    function IsNil(): Boolean;
    function TypeNameStr(): string;

    // Factory functions
    class function FromString(const AValue: string): TMuValue; static;
    class function FromInteger(const AValue: Int64): TMuValue; static;
    class function FromUInt64(const AValue: UInt64): TMuValue; static;
    class function FromFloat(const AValue: Double): TMuValue; static;
    class function FromBoolean(const AValue: Boolean): TMuValue; static;
    class function FromList(const AValue: TMuList): TMuValue; static;
    class function FromMap(const AValue: TMuMap): TMuValue; static;
    class function CreateNil(): TMuValue; static;
  end;

  { TMuList - Plain ordered list of TMuValue }
  TMuList = class(TMuBaseObject)
  private
    FItems: TList<TMuValue>;
  public
    constructor Create(); override;
    destructor Destroy(); override;

    function GetCount(): Integer;
    function GetItem(const AIndex: Integer): TMuValue;
    procedure SetItem(const AIndex: Integer; const AValue: TMuValue);

    procedure Add(const AValue: TMuValue);
    procedure Insert(const AIndex: Integer; const AValue: TMuValue);
    procedure Delete(const AIndex: Integer);
    procedure Clear();

    procedure SortList();
    procedure Reverse();

    property Count: Integer read GetCount;
    property Items[const AIndex: Integer]: TMuValue read GetItem write SetItem; default;
  end;

  { TMuMap - Plain string-keyed map of TMuValue }
  TMuMap = class(TMuBaseObject)
  private
    FItems: TDictionary<string, TMuValue>;
    FOrder: TList<string>;
  public
    constructor Create(); override;
    destructor Destroy(); override;

    function GetCount(): Integer;

    function Has(const AKey: string): Boolean;
    function Get(const AKey: string): TMuValue;
    procedure Put(const AKey: string; const AValue: TMuValue);
    procedure Remove(const AKey: string);
    procedure Clear();

    function GetKeys(): TArray<string>;
    function GetValues(): TArray<TMuValue>;

    // Resolve dotted paths like "user.name" or "items[0].title"
    function Resolve(const APath: string): TMuValue;

    property Count: Integer read GetCount;
  end;

implementation

{ TMuValue }

function TMuValue.AsString(): string;
begin
  case Kind of
    vkString:  Result := Value.AsString();
    vkInteger: Result := IntToStr(Value.AsInt64());
    vkUInt64:  Result := UIntToStr(Value.AsType<UInt64>());
    vkFloat:   Result := FloatToStr(Value.AsExtended());
    vkBoolean:
      if Value.AsBoolean() then
        Result := 'true'
      else
        Result := 'false';
    vkNil:     Result := '';
    vkList:    Result := '[List]';
    vkMap:     Result := '[Map]';
  else
    Result := '';
  end;
end;

function TMuValue.AsInteger(): Int64;
begin
  case Kind of
    vkInteger: Result := Value.AsInt64();
    vkUInt64:  Result := Int64(Value.AsType<UInt64>());
    vkFloat:   Result := Round(Value.AsExtended());
    vkString:
      if not TryStrToInt64(Value.AsString(), Result) then
        Result := 0;
    vkBoolean:
      if Value.AsBoolean() then
        Result := 1
      else
        Result := 0;
  else
    Result := 0;
  end;
end;

function TMuValue.AsUInt64(): UInt64;
begin
  case Kind of
    vkUInt64:  Result := Value.AsType<UInt64>();
    vkInteger: Result := UInt64(Value.AsInt64());
    vkFloat:   Result := Round(Value.AsExtended());
    vkString:
      if not TryStrToUInt64(Value.AsString(), Result) then
        Result := 0;
    vkBoolean:
      if Value.AsBoolean() then
        Result := 1
      else
        Result := 0;
  else
    Result := 0;
  end;
end;

function TMuValue.AsFloat(): Double;
var
  LTemp: Double;
begin
  case Kind of
    vkFloat:   Result := Value.AsExtended();
    vkInteger: Result := Value.AsInt64();
    vkUInt64:  Result := Value.AsType<UInt64>();
    vkString:
      if not TryStrToFloat(Value.AsString(), LTemp) then
        Result := 0.0
      else
        Result := LTemp;
    vkBoolean:
      if Value.AsBoolean() then
        Result := 1.0
      else
        Result := 0.0;
  else
    Result := 0.0;
  end;
end;

function TMuValue.AsBoolean(): Boolean;
begin
  Result := IsTruthy();
end;

function TMuValue.AsList(): TMuList;
begin
  if Kind = vkList then
    Result := TMuList(Value.AsObject())
  else
    Result := nil;
end;

function TMuValue.AsMap(): TMuMap;
begin
  if Kind = vkMap then
    Result := TMuMap(Value.AsObject())
  else
    Result := nil;
end;

function TMuValue.IsTruthy(): Boolean;
begin
  // Spec §4.4: falsy = empty string, 0, 0.0, false, nil, empty list, empty map
  case Kind of
    vkNil:     Result := False;
    vkBoolean: Result := Value.AsBoolean();
    vkInteger: Result := Value.AsInt64() <> 0;
    vkUInt64:  Result := Value.AsType<UInt64>() <> 0;
    vkFloat:   Result := Value.AsExtended() <> 0.0;
    vkString:  Result := Value.AsString() <> '';
    vkList:    Result := (Value.AsObject() <> nil) and (TMuList(Value.AsObject()).Count > 0);
    vkMap:     Result := (Value.AsObject() <> nil) and (TMuMap(Value.AsObject()).Count > 0);
  else
    Result := False;
  end;
end;

function TMuValue.IsNil(): Boolean;
begin
  Result := (Kind = vkNil);
end;

function TMuValue.TypeNameStr(): string;
begin
  case Kind of
    vkNil:     Result := 'nil';
    vkString:  Result := 'string';
    vkInteger: Result := 'integer';
    vkUInt64:  Result := 'uint64';
    vkFloat:   Result := 'float';
    vkBoolean: Result := 'boolean';
    vkList:    Result := 'list';
    vkMap:     Result := 'map';
  else
    Result := 'unknown';
  end;
end;

class function TMuValue.FromString(const AValue: string): TMuValue;
begin
  Result.Kind := vkString;
  Result.Value := TValue.From<string>(AValue);
end;

class function TMuValue.FromInteger(const AValue: Int64): TMuValue;
begin
  Result.Kind := vkInteger;
  Result.Value := TValue.From<Int64>(AValue);
end;

class function TMuValue.FromUInt64(const AValue: UInt64): TMuValue;
begin
  Result.Kind := vkUInt64;
  Result.Value := TValue.From<UInt64>(AValue);
end;

class function TMuValue.FromFloat(const AValue: Double): TMuValue;
begin
  Result.Kind := vkFloat;
  Result.Value := TValue.From<Double>(AValue);
end;

class function TMuValue.FromBoolean(const AValue: Boolean): TMuValue;
begin
  Result.Kind := vkBoolean;
  Result.Value := TValue.From<Boolean>(AValue);
end;

class function TMuValue.FromList(const AValue: TMuList): TMuValue;
begin
  Result.Kind := vkList;
  Result.Value := TValue.From<TObject>(AValue);
end;

class function TMuValue.FromMap(const AValue: TMuMap): TMuValue;
begin
  Result.Kind := vkMap;
  Result.Value := TValue.From<TObject>(AValue);
end;

class function TMuValue.CreateNil(): TMuValue;
begin
  Result.Kind := vkNil;
  Result.Value := TValue.Empty;
end;

{ TMuList }

constructor TMuList.Create();
begin
  inherited;
  FItems := TList<TMuValue>.Create();
end;

destructor TMuList.Destroy();
var
  LI: Integer;
  LVal: TMuValue;
begin
  for LI := 0 to FItems.Count - 1 do
  begin
    LVal := FItems[LI];
    if LVal.Kind = vkList then
      LVal.AsList().Free()
    else if LVal.Kind = vkMap then
      LVal.AsMap().Free();
  end;
  FreeAndNil(FItems);
  inherited;
end;

function TMuList.GetCount(): Integer;
begin
  Result := FItems.Count;
end;

function TMuList.GetItem(const AIndex: Integer): TMuValue;
begin
  Result := FItems[AIndex];
end;

procedure TMuList.SetItem(const AIndex: Integer; const AValue: TMuValue);
begin
  FItems[AIndex] := AValue;
end;

procedure TMuList.Add(const AValue: TMuValue);
begin
  FItems.Add(AValue);
end;

procedure TMuList.Insert(const AIndex: Integer; const AValue: TMuValue);
begin
  FItems.Insert(AIndex, AValue);
end;

procedure TMuList.Delete(const AIndex: Integer);
begin
  FItems.Delete(AIndex);
end;

procedure TMuList.Clear();
begin
  FItems.Clear();
end;

procedure TMuList.SortList();
begin
  FItems.Sort(
    TComparer<TMuValue>.Construct(
      function(const ALeft, ARight: TMuValue): Integer
      begin
        Result := CompareStr(ALeft.AsString(), ARight.AsString());
      end
    )
  );
end;

procedure TMuList.Reverse();
var
  LI: Integer;
  LJ: Integer;
  LTemp: TMuValue;
begin
  LI := 0;
  LJ := FItems.Count - 1;
  while LI < LJ do
  begin
    LTemp := FItems[LI];
    FItems[LI] := FItems[LJ];
    FItems[LJ] := LTemp;
    Inc(LI);
    Dec(LJ);
  end;
end;

{ TMuMap }

constructor TMuMap.Create();
begin
  inherited;
  FItems := TDictionary<string, TMuValue>.Create();
  FOrder := TList<string>.Create();
end;

destructor TMuMap.Destroy();
var
  LPair: TPair<string, TMuValue>;
begin
  for LPair in FItems do
  begin
    if LPair.Value.Kind = vkList then
      LPair.Value.AsList().Free()
    else if LPair.Value.Kind = vkMap then
      LPair.Value.AsMap().Free();
  end;
  FreeAndNil(FOrder);
  FreeAndNil(FItems);
  inherited;
end;

function TMuMap.GetCount(): Integer;
begin
  Result := FItems.Count;
end;

function TMuMap.Has(const AKey: string): Boolean;
begin
  Result := FItems.ContainsKey(AKey);
end;

function TMuMap.Get(const AKey: string): TMuValue;
begin
  if not FItems.TryGetValue(AKey, Result) then
    Result := TMuValue.CreateNil();
end;

procedure TMuMap.Put(const AKey: string; const AValue: TMuValue);
begin
  if not FItems.ContainsKey(AKey) then
    FOrder.Add(AKey);
  FItems.AddOrSetValue(AKey, AValue);
end;

procedure TMuMap.Remove(const AKey: string);
begin
  FItems.Remove(AKey);
  FOrder.Remove(AKey);
end;

procedure TMuMap.Clear();
begin
  FItems.Clear();
  FOrder.Clear();
end;

function TMuMap.GetKeys(): TArray<string>;
begin
  Result := FOrder.ToArray();
end;

function TMuMap.GetValues(): TArray<TMuValue>;
var
  LI: Integer;
begin
  SetLength(Result, FOrder.Count);
  for LI := 0 to FOrder.Count - 1 do
    Result[LI] := FItems[FOrder[LI]];
end;

function TMuMap.Resolve(const APath: string): TMuValue;
var
  LParts: TArray<string>;
  LI: Integer;
  LCurrent: TMuValue;
  LKey: string;
  LBracketPos: Integer;
  LIndexStr: string;
  LIndex: Integer;
begin
  // Split on dots: "user.name" -> ["user", "name"]
  // Also handle bracket notation: "items[0].title"
  LParts := APath.Split(['.']);
  LCurrent := TMuValue.FromMap(Self);

  for LI := 0 to Length(LParts) - 1 do
  begin
    LKey := LParts[LI];

    // Check for bracket notation: "items[0]"
    LBracketPos := Pos('[', LKey);
    if LBracketPos > 0 then
    begin
      // Extract the key part before the bracket
      LIndexStr := Copy(LKey, LBracketPos + 1, Length(LKey) - LBracketPos - 1);
      LKey := Copy(LKey, 1, LBracketPos - 1);

      // Resolve the key part first (if non-empty)
      if LKey <> '' then
      begin
        if LCurrent.Kind <> vkMap then
          Exit(TMuValue.CreateNil());
        LCurrent := LCurrent.AsMap().Get(LKey);
      end;

      // Now resolve the bracket index
      if LCurrent.Kind <> vkList then
        Exit(TMuValue.CreateNil());
      if not TryStrToInt(LIndexStr, LIndex) then
        Exit(TMuValue.CreateNil());
      if (LIndex < 0) or (LIndex >= LCurrent.AsList().Count) then
        Exit(TMuValue.CreateNil());
      LCurrent := LCurrent.AsList()[LIndex];
    end
    else
    begin
      // Simple key lookup
      if LCurrent.Kind <> vkMap then
        Exit(TMuValue.CreateNil());
      LCurrent := LCurrent.AsMap().Get(LKey);
    end;
  end;

  Result := LCurrent;
end;

end.
