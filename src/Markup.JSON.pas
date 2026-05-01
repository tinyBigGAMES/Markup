{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.JSON;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  Markup.Utils,
  Markup.Resources,
  Markup.Value;

const
  MU_ERROR_JSON_UNEXPECTED  = 'MS-J001';
  MU_ERROR_JSON_UNTERMINATED = 'MS-J002';

type
  { TMuJSON }
  TMuJSON = class(TMuBaseObject)
  private
    FSource: string;
    FPos: Integer;

    // Parser helpers
    function Peek(): Char;
    function IsAtEnd(): Boolean;
    function Advance(): Char;
    procedure SkipWhitespace();
    procedure Expect(const ACh: Char);

    // Recursive descent
    function ParseValue(): TMuValue;
    function ParseString(): string;
    function ParseNumber(): TMuValue;
    function ParseObject(): TMuValue;
    function ParseArray(): TMuValue;
    function ParseKeyword(const AWord: string): Boolean;

    // Stringify helpers
    procedure StringifyValue(const AValue: TMuValue;
      const ABuilder: TStringBuilder);
    procedure StringifyString(const AText: string;
      const ABuilder: TStringBuilder);

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Parse(const ASource: string): TMuValue;
    function Stringify(const AValue: TMuValue): string;
  end;

implementation

{ TMuJSON }

constructor TMuJSON.Create();
begin
  inherited;
end;

destructor TMuJSON.Destroy();
begin
  inherited;
end;

function TMuJSON.Peek(): Char;
begin
  if FPos <= Length(FSource) then
    Result := FSource[FPos]
  else
    Result := #0;
end;

function TMuJSON.IsAtEnd(): Boolean;
begin
  Result := FPos > Length(FSource);
end;

function TMuJSON.Advance(): Char;
begin
  Result := FSource[FPos];
  Inc(FPos);
end;

procedure TMuJSON.SkipWhitespace();
begin
  while (not IsAtEnd()) and
        ((Peek() = ' ') or (Peek() = #9) or (Peek() = #10) or (Peek() = #13)) do
    Advance();
end;

procedure TMuJSON.Expect(const ACh: Char);
begin
  SkipWhitespace();
  if IsAtEnd() or (Peek() <> ACh) then
  begin
    FErrors.Add(esError, MU_ERROR_JSON_UNEXPECTED,
      RSJsonUnexpected, [ACh, Peek()]);
    Exit;
  end;
  Advance();
end;

function TMuJSON.ParseKeyword(const AWord: string): Boolean;
var
  LI: Integer;
begin
  Result := False;
  if FPos + Length(AWord) - 1 > Length(FSource) then
    Exit;
  for LI := 1 to Length(AWord) do
  begin
    if FSource[FPos + LI - 1] <> AWord[LI] then
      Exit;
  end;
  Inc(FPos, Length(AWord));
  Result := True;
end;

function TMuJSON.ParseString(): string;
var
  LCh: Char;
  LResult: TStringBuilder;
begin
  Result := '';
  if Peek() <> '"' then
    Exit;
  Advance(); // skip opening "

  LResult := TStringBuilder.Create();
  try
    while not IsAtEnd() do
    begin
      LCh := Advance();
      if LCh = '"' then
      begin
        Result := LResult.ToString();
        Exit;
      end;
      if LCh = '\' then
      begin
        if IsAtEnd() then
          Break;
        LCh := Advance();
        if LCh = '"' then
          LResult.Append('"')
        else if LCh = '\' then
          LResult.Append('\')
        else if LCh = '/' then
          LResult.Append('/')
        else if LCh = 'n' then
          LResult.Append(#10)
        else if LCh = 'r' then
          LResult.Append(#13)
        else if LCh = 't' then
          LResult.Append(#9)
        else if LCh = 'b' then
          LResult.Append(#8)
        else if LCh = 'f' then
          LResult.Append(#12)
        else
          LResult.Append(LCh);
      end
      else
        LResult.Append(LCh);
    end;

    FErrors.Add(esError, MU_ERROR_JSON_UNTERMINATED,
      RSJsonUnterminated);
    Result := LResult.ToString();
    Exit;
  finally
    LResult.Free();
  end;
end;

function TMuJSON.ParseNumber(): TMuValue;
var
  LStart: Integer;
  LText: string;
  LIsFloat: Boolean;
  LInt: Int64;
  LFloat: Double;
begin
  LStart := FPos;
  LIsFloat := False;

  // Optional negative
  if Peek() = '-' then
    Advance();

  // Digits
  while (not IsAtEnd()) and (Peek() >= '0') and (Peek() <= '9') do
    Advance();

  // Decimal
  if (not IsAtEnd()) and (Peek() = '.') then
  begin
    LIsFloat := True;
    Advance();
    while (not IsAtEnd()) and (Peek() >= '0') and (Peek() <= '9') do
      Advance();
  end;

  // Exponent
  if (not IsAtEnd()) and ((Peek() = 'e') or (Peek() = 'E')) then
  begin
    LIsFloat := True;
    Advance();
    if (not IsAtEnd()) and ((Peek() = '+') or (Peek() = '-')) then
      Advance();
    while (not IsAtEnd()) and (Peek() >= '0') and (Peek() <= '9') do
      Advance();
  end;

  LText := Copy(FSource, LStart, FPos - LStart);

  if LIsFloat then
  begin
    if TryStrToFloat(LText, LFloat) then
      Result := TMuValue.FromFloat(LFloat)
    else
      Result := TMuValue.FromFloat(0.0);
  end
  else
  begin
    if TryStrToInt64(LText, LInt) then
      Result := TMuValue.FromInteger(LInt)
    else
      Result := TMuValue.FromInteger(0);
  end;
end;

function TMuJSON.ParseObject(): TMuValue;
var
  LMap: TMuMap;
  LKey: string;
  LVal: TMuValue;
begin
  LMap := TMuMap.Create();
  LMap.SetErrors(FErrors);
  Advance(); // skip {

  SkipWhitespace();
  if (not IsAtEnd()) and (Peek() = '}') then
  begin
    Advance();
    Exit(TMuValue.FromMap(LMap));
  end;

  while not IsAtEnd() do
  begin
    SkipWhitespace();
    LKey := ParseString();

    SkipWhitespace();
    Expect(':');

    SkipWhitespace();
    LVal := ParseValue();
    LMap.Put(LKey, LVal);

    SkipWhitespace();
    if (not IsAtEnd()) and (Peek() = ',') then
    begin
      Advance();
      Continue;
    end;
    Break;
  end;

  Expect('}');
  Result := TMuValue.FromMap(LMap);
end;

function TMuJSON.ParseArray(): TMuValue;
var
  LList: TMuList;
  LVal: TMuValue;
begin
  LList := TMuList.Create();
  LList.SetErrors(FErrors);
  Advance(); // skip [

  SkipWhitespace();
  if (not IsAtEnd()) and (Peek() = ']') then
  begin
    Advance();
    Exit(TMuValue.FromList(LList));
  end;

  while not IsAtEnd() do
  begin
    SkipWhitespace();
    LVal := ParseValue();
    LList.Add(LVal);

    SkipWhitespace();
    if (not IsAtEnd()) and (Peek() = ',') then
    begin
      Advance();
      Continue;
    end;
    Break;
  end;

  Expect(']');
  Result := TMuValue.FromList(LList);
end;

function TMuJSON.ParseValue(): TMuValue;
var
  LCh: Char;
begin
  SkipWhitespace();
  if IsAtEnd() then
    Exit(TMuValue.CreateNil());

  LCh := Peek();

  if LCh = '"' then
    Exit(TMuValue.FromString(ParseString()));

  if (LCh = '-') or ((LCh >= '0') and (LCh <= '9')) then
    Exit(ParseNumber());

  if LCh = '{' then
    Exit(ParseObject());

  if LCh = '[' then
    Exit(ParseArray());

  if ParseKeyword('true') then
    Exit(TMuValue.FromBoolean(True));

  if ParseKeyword('false') then
    Exit(TMuValue.FromBoolean(False));

  if ParseKeyword('null') then
    Exit(TMuValue.CreateNil());

  FErrors.Add(esError, MU_ERROR_JSON_UNEXPECTED,
    RSJsonUnexpected, ['value', LCh]);
  Advance();
  Result := TMuValue.CreateNil();
  Exit;
end;

{ Stringify }

procedure TMuJSON.StringifyString(const AText: string;
  const ABuilder: TStringBuilder);
var
  LI: Integer;
  LCh: Char;
begin
  ABuilder.Append('"');
  for LI := 1 to Length(AText) do
  begin
    LCh := AText[LI];
    if LCh = '"' then
      ABuilder.Append('\"')
    else if LCh = '\' then
      ABuilder.Append('\\')
    else if LCh = #10 then
      ABuilder.Append('\n')
    else if LCh = #13 then
      ABuilder.Append('\r')
    else if LCh = #9 then
      ABuilder.Append('\t')
    else if LCh < #32 then
      ABuilder.Append('\u' + IntToHex(Ord(LCh), 4))
    else
      ABuilder.Append(LCh);
  end;
  ABuilder.Append('"');
end;

procedure TMuJSON.StringifyValue(const AValue: TMuValue;
  const ABuilder: TStringBuilder);
var
  LList: TMuList;
  LMap: TMuMap;
  LKeys: TArray<string>;
  LI: Integer;
begin
  if AValue.Kind = vkNil then
  begin
    ABuilder.Append('null');
    Exit;
  end;

  if AValue.Kind = vkBoolean then
  begin
    if AValue.AsBoolean() then
      ABuilder.Append('true')
    else
      ABuilder.Append('false');
    Exit;
  end;

  if AValue.Kind = vkInteger then
  begin
    ABuilder.Append(IntToStr(AValue.AsInteger()));
    Exit;
  end;

  if AValue.Kind = vkFloat then
  begin
    ABuilder.Append(FloatToStr(AValue.AsFloat()));
    Exit;
  end;

  if AValue.Kind = vkString then
  begin
    StringifyString(AValue.AsString(), ABuilder);
    Exit;
  end;

  if AValue.Kind = vkList then
  begin
    LList := AValue.AsList();
    ABuilder.Append('[');
    if LList <> nil then
    begin
      for LI := 0 to LList.Count - 1 do
      begin
        if LI > 0 then
          ABuilder.Append(',');
        StringifyValue(LList[LI], ABuilder);
      end;
    end;
    ABuilder.Append(']');
    Exit;
  end;

  if AValue.Kind = vkMap then
  begin
    LMap := AValue.AsMap();
    ABuilder.Append('{');
    if LMap <> nil then
    begin
      LKeys := LMap.GetKeys();
      for LI := 0 to Length(LKeys) - 1 do
      begin
        if LI > 0 then
          ABuilder.Append(',');
        StringifyString(LKeys[LI], ABuilder);
        ABuilder.Append(':');
        StringifyValue(LMap.Get(LKeys[LI]), ABuilder);
      end;
    end;
    ABuilder.Append('}');
    Exit;
  end;

  ABuilder.Append('null');
end;

{ Entry Points }

function TMuJSON.Parse(const ASource: string): TMuValue;
begin
  FSource := ASource;
  FPos := 1;

  Status(RSJsonStatusStart, [Length(ASource)]);

  Result := ParseValue();

  Status(RSJsonStatusComplete, [FErrors.ErrorCount()]);
end;

function TMuJSON.Stringify(const AValue: TMuValue): string;
var
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create();
  try
    StringifyValue(AValue, LBuilder);
    Result := LBuilder.ToString();
  finally
    LBuilder.Free();
  end;
end;

end.
