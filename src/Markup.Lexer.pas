{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Lexer;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markup.Utils,
  Markup.Resources;

const
  MU_ERROR_UNTERMINATED_COMMENT       = 'MS-L001';
  MU_ERROR_UNTERMINATED_INTERPOLATION = 'MS-L002';
  MU_ERROR_UNTERMINATED_VERBATIM      = 'MS-L003';
  MU_ERROR_UNTERMINATED_ATTR_VALUE    = 'MS-L004';
  MU_ERROR_EXPECTED_TAG_NAME          = 'MS-L005';
  MU_ERROR_INVALID_ESCAPE             = 'MS-L006';
  MU_ERROR_EMPTY_INTERPOLATION        = 'MS-L007';
  MU_ERROR_EMPTY_ATTR_VALUE           = 'MS-L008';
  MU_ERROR_UNCLOSED_BRACE             = 'MS-L009';
  MU_ERROR_UNTERMINATED_STRING        = 'MS-L010';

type
  { TMuTokenKind }
  TMuTokenKind = (
    tkText,
    tkTagOpen,
    tkTagClose,
    tkTagName,
    tkAttrName,
    tkAttrEquals,
    tkAttrValue,
    tkInterpolation,
    tkExprText,
    tkEscape,
    tkEOF
  );

  { TMuToken }
  TMuToken = record
    Kind: TMuTokenKind;
    Text: string;
    Line: Integer;
    Col: Integer;
  end;

  { TMuLexer }
  TMuLexer = class(TMuBaseObject)
  private
    FSource: string;
    FPos: Integer;
    FLine: Integer;
    FCol: Integer;
    FTokens: TList<TMuToken>;
    FBraceDepth: Integer;

    // Character-level operations
    function Peek(const AOffset: Integer = 0): Char;
    function IsAtEnd(): Boolean;
    function Advance(): Char;
    procedure Skip(const ACount: Integer = 1);
    procedure AddToken(const AKind: TMuTokenKind; const AText: string;
      const ALine: Integer; const ACol: Integer);

    // Character classification
    function IsWhitespace(const ACh: Char): Boolean;
    function IsTagNameStart(const ACh: Char): Boolean;
    function IsTagNameChar(const ACh: Char): Boolean;
    {$HINTS OFF}
    function IsAttrNameChar(const ACh: Char): Boolean;
    {$HINTS ON}

    // Reading helpers
    function ReadTagName(): string;
    function ReadAttrValue(): string;

    // Whitespace and comment skipping
    procedure SkipIgnored();
    procedure SkipComment();

    // Scanning
    procedure ScanTag();
    procedure ScanAttributes();
    procedure ScanTagBody();
    procedure ScanString();
    procedure ScanBareContent();
    procedure ScanInterpolation();
    procedure ScanVerbatim();

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Tokenize(const ASource: string): TArray<TMuToken>;
  end;

implementation

{ TMuLexer }

constructor TMuLexer.Create();
begin
  inherited;
  FTokens := TList<TMuToken>.Create();
end;

destructor TMuLexer.Destroy();
begin
  FreeAndNil(FTokens);
  inherited;
end;

{ Character-level operations }

function TMuLexer.Peek(const AOffset: Integer): Char;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx >= 1) and (LIdx <= Length(FSource)) then
    Result := FSource[LIdx]
  else
    Result := #0;
end;

function TMuLexer.IsAtEnd(): Boolean;
begin
  Result := FPos > Length(FSource);
end;

function TMuLexer.Advance(): Char;
begin
  Result := FSource[FPos];
  if Result = #10 then
  begin
    Inc(FLine);
    FCol := 1;
  end
  else
    Inc(FCol);
  Inc(FPos);
end;

procedure TMuLexer.Skip(const ACount: Integer);
var
  LI: Integer;
begin
  for LI := 1 to ACount do
  begin
    if not IsAtEnd() then
      Advance();
  end;
end;

procedure TMuLexer.AddToken(const AKind: TMuTokenKind; const AText: string;
  const ALine: Integer; const ACol: Integer);
var
  LToken: TMuToken;
begin
  LToken.Kind := AKind;
  LToken.Text := AText;
  LToken.Line := ALine;
  LToken.Col := ACol;
  FTokens.Add(LToken);
end;

{ Character classification }

function TMuLexer.IsWhitespace(const ACh: Char): Boolean;
begin
  Result := (ACh = ' ') or (ACh = #9) or (ACh = #10) or (ACh = #13);
end;

function TMuLexer.IsTagNameStart(const ACh: Char): Boolean;
begin
  Result := (ACh >= 'a') and (ACh <= 'z');
end;

function TMuLexer.IsTagNameChar(const ACh: Char): Boolean;
begin
  Result := ((ACh >= 'a') and (ACh <= 'z')) or
            ((ACh >= '0') and (ACh <= '9')) or
            (ACh = '-');
end;

function TMuLexer.IsAttrNameChar(const ACh: Char): Boolean;
begin
  Result := ((ACh >= 'a') and (ACh <= 'z')) or
            ((ACh >= '0') and (ACh <= '9')) or
            (ACh = '-');
end;

{ Reading helpers }

function TMuLexer.ReadTagName(): string;
var
  LStart: Integer;
begin
  LStart := FPos;
  while (not IsAtEnd()) and IsTagNameChar(Peek()) do
    Advance();
  Result := Copy(FSource, LStart, FPos - LStart);
end;

function TMuLexer.ReadAttrValue(): string;
var
  LStart: Integer;
  LCh: Char;
begin
  if Peek() = '"' then
  begin
    // Quoted attribute value
    Advance();
    LStart := FPos;
    while not IsAtEnd() do
    begin
      LCh := Peek();
      if LCh = '\' then
      begin
        Advance();
        if not IsAtEnd() then
          Advance();
      end
      else if LCh = '"' then
        Break
      else
        Advance();
    end;
    Result := Copy(FSource, LStart, FPos - LStart);
    Result := StringReplace(Result, '\"', '"', [rfReplaceAll]);
    if Peek() = '"' then
      Advance()
    else
      FErrors.Add('', FLine, FCol, esError, MU_ERROR_UNTERMINATED_ATTR_VALUE,
        RSLexerUnterminatedAttrValue);
  end
  else
  begin
    // Bare value: stops at whitespace, }, or "
    LStart := FPos;
    while not IsAtEnd() do
    begin
      LCh := Peek();
      if IsWhitespace(LCh) or (LCh = '}') or (LCh = '"') then
        Break;
      Advance();
    end;
    Result := Copy(FSource, LStart, FPos - LStart);
    if Result = '' then
      FErrors.Add('', FLine, FCol, esError, MU_ERROR_EMPTY_ATTR_VALUE,
        RSLexerEmptyAttrValue);
  end;
end;

{ Whitespace and comment skipping }

procedure TMuLexer.SkipComment();
var
  LStartLine: Integer;
  LStartCol: Integer;
begin
  LStartLine := FLine;
  LStartCol := FCol;

  // Skip '{--'
  Skip(3);

  // Consume until '--}'
  while not IsAtEnd() do
  begin
    if (Peek() = '-') and (Peek(1) = '-') and (Peek(2) = '}') then
    begin
      Skip(3);
      Exit;
    end;
    Advance();
  end;

  // Unterminated comment
  FErrors.Add('', LStartLine, LStartCol, esError, MU_ERROR_UNTERMINATED_COMMENT,
    RSLexerUnterminatedComment, [LStartLine, LStartCol]);
end;

procedure TMuLexer.SkipIgnored();
var
  LChanged: Boolean;
begin
  repeat
    LChanged := False;

    // Skip whitespace
    while (not IsAtEnd()) and IsWhitespace(Peek()) do
    begin
      Advance();
      LChanged := True;
    end;

    // Skip comments
    if (not IsAtEnd()) and (Peek() = '{') and (Peek(1) = '-') and
       (Peek(2) = '-') then
    begin
      SkipComment();
      LChanged := True;
    end;
  until not LChanged;
end;

{ Scanning }

procedure TMuLexer.ScanInterpolation();
var
  LOpenLine: Integer;
  LOpenCol: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LStart: Integer;
  LDepth: Integer;
  LCh: Char;
begin
  LOpenLine := FLine;
  LOpenCol := FCol;

  // Skip '{='
  Skip(2);
  AddToken(tkInterpolation, '{=', LOpenLine, LOpenCol);

  // Read expression text with brace depth tracking
  LStart := FPos;
  LStartLine := FLine;
  LStartCol := FCol;
  LDepth := 1;

  while (not IsAtEnd()) and (LDepth > 0) do
  begin
    LCh := Peek();
    if LCh = '{' then
      Inc(LDepth)
    else if LCh = '}' then
    begin
      Dec(LDepth);
      if LDepth = 0 then
        Break;
    end;
    Advance();
  end;

  if FPos > LStart then
    AddToken(tkExprText, Copy(FSource, LStart, FPos - LStart),
      LStartLine, LStartCol)
  else
    FErrors.Add('', LOpenLine, LOpenCol, esWarning,
      MU_ERROR_EMPTY_INTERPOLATION, RSLexerEmptyInterpolation);

  // Consume closing '}'
  if (not IsAtEnd()) and (Peek() = '}') then
  begin
    LStartLine := FLine;
    LStartCol := FCol;
    Advance();
    AddToken(tkTagClose, '}', LStartLine, LStartCol);
  end
  else
    FErrors.Add('', LOpenLine, LOpenCol, esError,
      MU_ERROR_UNTERMINATED_INTERPOLATION,
      RSLexerUnterminatedInterpolation, [LOpenLine, LOpenCol]);
end;

procedure TMuLexer.ScanVerbatim();
var
  LStart: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LDepth: Integer;
  LCh: Char;
begin
  // Skip whitespace/newline separator before verbatim content
  while (not IsAtEnd()) and ((Peek() = ' ') or (Peek() = #9)) do
    Advance();
  if (not IsAtEnd()) and (Peek() = #13) then
    Advance();
  if (not IsAtEnd()) and (Peek() = #10) then
    Advance();

  // Read content verbatim with brace depth tracking
  LStart := FPos;
  LStartLine := FLine;
  LStartCol := FCol;
  LDepth := 1;

  while (not IsAtEnd()) and (LDepth > 0) do
  begin
    LCh := Peek();
    if LCh = '{' then
      Inc(LDepth)
    else if LCh = '}' then
    begin
      Dec(LDepth);
      if LDepth = 0 then
        Break;
    end;
    Advance();
  end;

  if FPos > LStart then
    AddToken(tkText, Copy(FSource, LStart, FPos - LStart),
      LStartLine, LStartCol);

  // Consume closing '}'
  if (not IsAtEnd()) and (Peek() = '}') then
  begin
    LStartLine := FLine;
    LStartCol := FCol;
    Advance();
    AddToken(tkTagClose, '}', LStartLine, LStartCol);
  end
  else
    FErrors.Add('', LStartLine, LStartCol, esError,
      MU_ERROR_UNTERMINATED_VERBATIM, RSLexerUnterminatedVerbatim);
end;

procedure TMuLexer.ScanAttributes();
var
  LAttrName: string;
  LStartLine: Integer;
  LStartCol: Integer;
  LSavePos: Integer;
  LSaveLine: Integer;
  LSaveCol: Integer;
begin
  while not IsAtEnd() do
  begin
    SkipIgnored();

    if IsAtEnd() then
      Break;

    // Stop at content or close boundaries
    if (Peek() = '"') or (Peek() = '}') or (Peek() = '{') then
      Break;

    // Must start with a lowercase letter to be an attribute name
    if not IsTagNameStart(Peek()) then
      Break;

    // Save position in case this is not a key=value attribute
    LSavePos := FPos;
    LSaveLine := FLine;
    LSaveCol := FCol;

    LStartLine := FLine;
    LStartCol := FCol;

    // Read candidate attribute name
    LAttrName := ReadTagName();
    if LAttrName = '' then
    begin
      FPos := LSavePos;
      FLine := LSaveLine;
      FCol := LSaveCol;
      Break;
    end;

    if (not IsAtEnd()) and (Peek() = '=') then
    begin
      // key=value attribute
      AddToken(tkAttrName, LAttrName, LStartLine, LStartCol);

      LStartLine := FLine;
      LStartCol := FCol;
      Advance();
      AddToken(tkAttrEquals, '=', LStartLine, LStartCol);

      LStartLine := FLine;
      LStartCol := FCol;
      AddToken(tkAttrValue, ReadAttrValue(), LStartLine, LStartCol);
    end
    else
    begin
      // No '=' — not a key=value attribute.
      // Restore position and stop attribute scanning.
      FPos := LSavePos;
      FLine := LSaveLine;
      FCol := LSaveCol;
      Break;
    end;
  end;
end;

procedure TMuLexer.ScanString();
var
  LOpenLine: Integer;
  LOpenCol: Integer;
  LTextStartLine: Integer;
  LTextStartCol: Integer;
  LAccum: string;
  LCh: Char;
begin
  LOpenLine := FLine;
  LOpenCol := FCol;

  // Skip opening "
  Advance();

  LAccum := '';
  LTextStartLine := FLine;
  LTextStartCol := FCol;

  while not IsAtEnd() do
  begin
    LCh := Peek();

    // Closing quote — end of string
    if LCh = '"' then
    begin
      if LAccum <> '' then
        AddToken(tkText, LAccum, LTextStartLine, LTextStartCol);
      Advance();
      Exit;
    end;

    // Escape sequences inside strings: \" \{ \} \\
    if LCh = '\' then
    begin
      if (Peek(1) = '"') or (Peek(1) = '{') or (Peek(1) = '}') or
         (Peek(1) = '\') then
      begin
        Advance();
        LAccum := LAccum + Advance();
        Continue;
      end;
    end;

    // Nested construct inside string
    if LCh = '{' then
    begin
      // Flush accumulated text
      if LAccum <> '' then
      begin
        AddToken(tkText, LAccum, LTextStartLine, LTextStartCol);
        LAccum := '';
      end;

      // Determine construct type
      if (Peek(1) = '-') and (Peek(2) = '-') then
        SkipComment()
      else if Peek(1) = '=' then
        ScanInterpolation()
      else
        ScanTag();

      // Reset text tracking for next segment
      LTextStartLine := FLine;
      LTextStartCol := FCol;
      Continue;
    end;

    // Regular character — accumulate (including newlines)
    LAccum := LAccum + Advance();
  end;

  // Reached end of input — unterminated string
  if LAccum <> '' then
    AddToken(tkText, LAccum, LTextStartLine, LTextStartCol);
  FErrors.Add('', LOpenLine, LOpenCol, esError,
    MU_ERROR_UNTERMINATED_STRING, RSLexerUnterminatedString,
    [LOpenLine, LOpenCol]);
end;

procedure TMuLexer.ScanBareContent();
var
  LStart: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LCh: Char;
begin
  LStart := FPos;
  LStartLine := FLine;
  LStartCol := FCol;

  // Read until a boundary character
  while not IsAtEnd() do
  begin
    LCh := Peek();
    if (LCh = '{') or (LCh = '}') or (LCh = '"') then
      Break;
    if (LCh = '\') and ((Peek(1) = '{') or (Peek(1) = '}') or
       (Peek(1) = '\') or (Peek(1) = '"')) then
      Break;
    Advance();
  end;

  if FPos > LStart then
    AddToken(tkText, Copy(FSource, LStart, FPos - LStart),
      LStartLine, LStartCol);
end;

procedure TMuLexer.ScanTagBody();
var
  LStartLine: Integer;
  LStartCol: Integer;
begin
  // Process tag body content until matching }
  while not IsAtEnd() do
  begin
    if FErrors.ReachedMaxErrors() then
      Exit;

    SkipIgnored();

    if IsAtEnd() then
      Break;

    // Closing brace — end of tag body
    if Peek() = '}' then
    begin
      LStartLine := FLine;
      LStartCol := FCol;
      Advance();
      AddToken(tkTagClose, '}', LStartLine, LStartCol);
      Exit;
    end;

    // Quoted string content
    if Peek() = '"' then
    begin
      ScanString();
      Continue;
    end;

    // Nested construct
    if Peek() = '{' then
    begin
      if Peek(1) = '=' then
        ScanInterpolation()
      else
        ScanTag();
      Continue;
    end;

    // Escape sequence
    if (Peek() = '\') and ((Peek(1) = '{') or (Peek(1) = '}') or
       (Peek(1) = '\') or (Peek(1) = '"')) then
    begin
      LStartLine := FLine;
      LStartCol := FCol;
      Advance();
      AddToken(tkEscape, string(Advance()), LStartLine, LStartCol);
      Continue;
    end;

    // Bare content (computation tag syntax: variable names, expressions)
    ScanBareContent();
  end;
end;

procedure TMuLexer.ScanTag();
var
  LOpenLine: Integer;
  LOpenCol: Integer;
  LStartLine: Integer;
  LStartCol: Integer;
  LTagName: string;
begin
  LOpenLine := FLine;
  LOpenCol := FCol;

  // Consume '{'
  Advance();
  Inc(FBraceDepth);
  AddToken(tkTagOpen, '{', LOpenLine, LOpenCol);

  SkipIgnored();

  // Read tag name
  if (not IsAtEnd()) and IsTagNameStart(Peek()) then
  begin
    LStartLine := FLine;
    LStartCol := FCol;
    LTagName := ReadTagName();
    AddToken(tkTagName, LTagName, LStartLine, LStartCol);

    SkipIgnored();

    // Read attributes
    ScanAttributes();

    // Verbatim tags: code, html — consume raw content
    if (LTagName = 'code') or (LTagName = 'html') then
    begin
      ScanVerbatim();
      Dec(FBraceDepth);
      Exit;
    end;

    // Check for immediate close (empty tag)
    SkipIgnored();
    if (not IsAtEnd()) and (Peek() = '}') then
    begin
      LStartLine := FLine;
      LStartCol := FCol;
      Advance();
      Dec(FBraceDepth);
      AddToken(tkTagClose, '}', LStartLine, LStartCol);
      Exit;
    end;

    // Scan tag body (content: strings, nested tags, bare content)
    ScanTagBody();
    Dec(FBraceDepth);
  end
  else
  begin
    FErrors.Add('', LOpenLine, LOpenCol, esError,
      MU_ERROR_EXPECTED_TAG_NAME, RSLexerExpectedTagName);
    Dec(FBraceDepth);
  end;
end;

{ Public }

function TMuLexer.Tokenize(const ASource: string): TArray<TMuToken>;
begin
  FSource := ASource;
  FPos := 1;
  FLine := 1;
  FCol := 1;
  FBraceDepth := 0;
  FTokens.Clear();

  Status(RSLexerStatusStart, [Length(ASource)]);

  while not IsAtEnd() do
  begin
    if FErrors.ReachedMaxErrors() then
      Break;

    SkipIgnored();

    if IsAtEnd() then
      Break;

    // Opening brace — tag or interpolation
    if Peek() = '{' then
    begin
      if Peek(1) = '=' then
        ScanInterpolation()
      else
        ScanTag();
      Continue;
    end;

    // Orphan closing brace at top level
    if Peek() = '}' then
    begin
      Advance();
      Continue;
    end;

    // Anything else at top level is discarded
    // (whitespace already handled by SkipIgnored, bare text outside
    // tags/strings produces no output per spec §2.8)
    Advance();
  end;

  // Check for unclosed braces
  if FBraceDepth > 0 then
    FErrors.Add('', FLine, FCol, esWarning, MU_ERROR_UNCLOSED_BRACE,
      RSLexerUnclosedBrace, [FBraceDepth]);

  AddToken(tkEOF, '', FLine, FCol);

  Status(RSLexerStatusComplete, [FTokens.Count, FErrors.ErrorCount()]);

  Result := FTokens.ToArray();
end;

end.
