{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Parser;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markup.Utils,
  Markup.Resources,
  Markup.AST,
  Markup.Lexer;

const
  MU_ERROR_PARSER_UNEXPECTED_TOKEN = 'MS-P001';
  MU_ERROR_PARSER_UNCLOSED_TAG     = 'MS-P002';
  MU_ERROR_PARSER_ELSE_OUTSIDE_IF  = 'MS-P003';
  MU_ERROR_PARSER_MISSING_CONDITION= 'MS-P004';
  MU_ERROR_PARSER_MISSING_BINDING  = 'MS-P005';
  MU_ERROR_PARSER_MISSING_NAME     = 'MS-P006';

type
  { TMuParser }
  TMuParser = class(TMuBaseObject)
  private
    FTokens: TArray<TMuToken>;
    FPos: Integer;
    FAST: TMuAST;

    // Token navigation
    function Current(): TMuToken;
    function Peek(const AOffset: Integer = 0): TMuToken;
    function IsAtEnd(): Boolean;
    function Check(const AKind: TMuTokenKind): Boolean;
    function Match(const AKind: TMuTokenKind): Boolean;
    procedure Advance();

    // Core parsing
    function ParseDocument(): TMuNodeIndex;
    procedure ParseContent(const AParent: TMuNodeIndex;
      const AStopAtElse: Boolean = False);
    function ParseTag(const AParent: TMuNodeIndex): TMuNodeIndex;
    function ParseInterpolation(): TMuNodeIndex;

    // Tag-specific parsing
    procedure ParseIfBody(const AIfNode: TMuNodeIndex);
    procedure ParseEachBody(const AEachNode: TMuNodeIndex);
    procedure ParseLetSetBody(const ANode: TMuNodeIndex);
    procedure ParseDefBody(const ANode: TMuNodeIndex);
    procedure ParseCallBody(const ANode: TMuNodeIndex);

    // Attribute parsing
    procedure ParseAttributes(const ANode: TMuNodeIndex);

    // Helpers
    function IsVoidTag(const ATagName: string): Boolean;
    function ExtractFirstWord(const AText: string;
      var ARest: string): string;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Parse(const ATokens: TArray<TMuToken>): TMuAST;
  end;

implementation

{ TMuParser }

constructor TMuParser.Create();
begin
  inherited;
end;

destructor TMuParser.Destroy();
begin
  inherited;
end;

{ Token navigation }

function TMuParser.Current(): TMuToken;
begin
  if FPos < Length(FTokens) then
    Result := FTokens[FPos]
  else
  begin
    Result.Kind := tkEOF;
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TMuParser.Peek(const AOffset: Integer): TMuToken;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx >= 0) and (LIdx < Length(FTokens)) then
    Result := FTokens[LIdx]
  else
  begin
    Result.Kind := tkEOF;
    Result.Text := '';
    Result.Line := 0;
    Result.Col := 0;
  end;
end;

function TMuParser.IsAtEnd(): Boolean;
begin
  Result := (FPos >= Length(FTokens)) or (Current().Kind = tkEOF);
end;

function TMuParser.Check(const AKind: TMuTokenKind): Boolean;
begin
  Result := Current().Kind = AKind;
end;

function TMuParser.Match(const AKind: TMuTokenKind): Boolean;
begin
  if Check(AKind) then
  begin
    Advance();
    Result := True;
  end
  else
    Result := False;
end;

procedure TMuParser.Advance();
begin
  if FPos < Length(FTokens) then
    Inc(FPos);
end;

{ Helpers }

function TMuParser.IsVoidTag(const ATagName: string): Boolean;
begin
  Result := (ATagName = 'line') or (ATagName = 'br') or
            (ATagName = 'img') or (ATagName = 'input') or
            (ATagName = 'meta');
end;

function TMuParser.ExtractFirstWord(const AText: string;
  var ARest: string): string;
var
  LI: Integer;
  LTrimmed: string;
begin
  LTrimmed := AText.TrimLeft();
  LI := 1;
  while (LI <= Length(LTrimmed)) and (LTrimmed[LI] <> ' ') and
        (LTrimmed[LI] <> #9) and (LTrimmed[LI] <> #10) do
    Inc(LI);

  Result := Copy(LTrimmed, 1, LI - 1);
  ARest := Copy(LTrimmed, LI, MaxInt).TrimLeft();
end;

{ Attribute and interpolation parsing }

procedure TMuParser.ParseAttributes(const ANode: TMuNodeIndex);
var
  LNode: PMuNode;
  LAttrIdx: Integer;
  LAttrName: string;
  LAttrValue: string;
begin
  LNode := FAST.GetNode(ANode);
  if LNode = nil then
    Exit;

  while Check(tkAttrName) do
  begin
    LAttrName := Current().Text;
    LAttrValue := '';
    Advance();

    if Match(tkAttrEquals) then
    begin
      if Check(tkAttrValue) then
      begin
        LAttrValue := Current().Text;
        Advance();
      end;
    end;

    LAttrIdx := FAST.AddAttr(LAttrName, LAttrValue);

    if LNode^.AttrCount = 0 then
      LNode^.AttrStart := LAttrIdx;
    Inc(LNode^.AttrCount);
  end;
end;

function TMuParser.ParseInterpolation(): TMuNodeIndex;
var
  LToken: TMuToken;
  LNode: PMuNode;
begin
  LToken := Current();
  Result := FAST.NewNode(nkTag, LToken.Line, LToken.Col);
  LNode := FAST.GetNode(Result);
  LNode^.TagName := '=';
  Advance();

  if Check(tkExprText) then
  begin
    LNode := FAST.GetNode(Result);
    LNode^.Text := Current().Text;
    Advance();
  end;

  if not Match(tkTagClose) then
    FErrors.Add('', LToken.Line, LToken.Col, esError,
      MU_ERROR_PARSER_UNCLOSED_TAG, RSParserUnclosedTag, ['interpolation']);
end;

{ Content parsing }

procedure TMuParser.ParseContent(const AParent: TMuNodeIndex;
  const AStopAtElse: Boolean);
var
  LToken: TMuToken;
  LChild: TMuNodeIndex;
  LTextNode: PMuNode;
  LTagName: string;
begin
  while not IsAtEnd() do
  begin
    if FErrors.ReachedMaxErrors() then
      Exit;

    LToken := Current();

    // Stop at closing brace
    if LToken.Kind = tkTagClose then
      Exit;

    // Check for else/elseif branch delimiters inside {if}
    if AStopAtElse and (LToken.Kind = tkTagOpen) then
    begin
      LTagName := Peek(1).Text;
      if (Peek(1).Kind = tkTagName) and
         ((LTagName = 'else') or (LTagName = 'elseif')) then
        Exit;
    end;

    case LToken.Kind of
      tkText:
      begin
        LChild := FAST.NewNode(nkText, LToken.Line, LToken.Col);
        LTextNode := FAST.GetNode(LChild);
        LTextNode^.Text := LToken.Text;
        FAST.AddChild(AParent, LChild);
        Advance();
      end;

      tkEscape:
      begin
        LChild := FAST.NewNode(nkText, LToken.Line, LToken.Col);
        LTextNode := FAST.GetNode(LChild);
        LTextNode^.Text := LToken.Text;
        FAST.AddChild(AParent, LChild);
        Advance();
      end;

      tkTagOpen:
      begin
        LChild := ParseTag(AParent);
        if LChild <> MU_NO_NODE then
          FAST.AddChild(AParent, LChild);
      end;

      tkInterpolation:
      begin
        LChild := ParseInterpolation();
        if LChild <> MU_NO_NODE then
          FAST.AddChild(AParent, LChild);
      end;

    else
      Advance();
    end;
  end;
end;

{ Tag parsing }

function TMuParser.ParseTag(const AParent: TMuNodeIndex): TMuNodeIndex;
var
  LOpenToken: TMuToken;
  LTagName: string;
  LNode: PMuNode;
begin
  Result := MU_NO_NODE;
  LOpenToken := Current();

  if not Match(tkTagOpen) then
    Exit;

  // Expect tag name
  if not Check(tkTagName) then
  begin
    FErrors.Add('', LOpenToken.Line, LOpenToken.Col, esError,
      MU_ERROR_PARSER_UNEXPECTED_TOKEN, RSParserUnexpectedToken,
      [LOpenToken.Line, LOpenToken.Col]);
    Exit;
  end;

  LTagName := Current().Text;
  Advance();

  // Create the node
  Result := FAST.NewNode(nkTag, LOpenToken.Line, LOpenToken.Col);
  LNode := FAST.GetNode(Result);
  LNode^.TagName := LTagName;

  // Parse attributes
  ParseAttributes(Result);

  // Verbatim tags — content already tokenized as flat text by lexer
  if (LTagName = 'code') or (LTagName = 'html') then
  begin
    LNode := FAST.GetNode(Result);
    LNode^.Kind := nkVerbatim;

    if Check(tkText) then
    begin
      LNode := FAST.GetNode(Result);
      LNode^.Text := Current().Text;
      Advance();
    end;

    if not Match(tkTagClose) then
      FErrors.Add('', LOpenToken.Line, LOpenToken.Col, esError,
        MU_ERROR_PARSER_UNCLOSED_TAG, RSParserUnclosedTag, [LTagName]);
    Exit;
  end;

  // Void tags — no content body
  if IsVoidTag(LTagName) then
  begin
    if Check(tkTagClose) then
      Advance();
    Exit;
  end;

  // Immediate close (empty tag)
  if Check(tkTagClose) then
  begin
    Advance();
    Exit;
  end;

  // Computation tags
  if LTagName = 'if' then
  begin
    ParseIfBody(Result);
    Exit;
  end;

  if LTagName = 'each' then
  begin
    ParseEachBody(Result);
    Exit;
  end;

  if (LTagName = 'let') or (LTagName = 'set') then
  begin
    ParseLetSetBody(Result);
    Exit;
  end;

  if LTagName = 'def' then
  begin
    ParseDefBody(Result);
    Exit;
  end;

  if LTagName = 'call' then
  begin
    ParseCallBody(Result);
    Exit;
  end;

  // All other tags: parse content recursively
  ParseContent(Result);

  if not Match(tkTagClose) then
    FErrors.Add('', LOpenToken.Line, LOpenToken.Col, esError,
      MU_ERROR_PARSER_UNCLOSED_TAG, RSParserUnclosedTag, [LTagName]);
end;

{ Computation tag bodies }

procedure TMuParser.ParseIfBody(const AIfNode: TMuNodeIndex);
var
  LToken: TMuToken;
  LElseNode: TMuNodeIndex;
  LNode: PMuNode;
  LTagName: string;
begin
  // Parse true branch content (stops at {else}, {elseif}, or })
  ParseContent(AIfNode, True);

  // Handle {else} and {elseif} branches
  while Check(tkTagOpen) do
  begin
    LTagName := Peek(1).Text;
    if (Peek(1).Kind <> tkTagName) or
       ((LTagName <> 'else') and (LTagName <> 'elseif')) then
      Break;

    LToken := Current();
    Advance(); // skip tkTagOpen
    Advance(); // skip else/elseif tag name

    // Create branch node
    LElseNode := FAST.NewNode(nkTag, LToken.Line, LToken.Col);
    LNode := FAST.GetNode(LElseNode);
    LNode^.TagName := LTagName;
    FAST.AddChild(AIfNode, LElseNode);

    if LTagName = 'elseif' then
    begin
      // {elseif} may contain condition content (e.g. {=expr}) before
      // its closing }. Parse that content as children of the elseif
      // node, then consume the closing }.
      ParseContent(LElseNode, False);
      if Check(tkTagClose) then
        Advance();
    end
    else
    begin
      // {else} is a simple delimiter — skip its closing }
      if Check(tkTagClose) then
        Advance();
    end;

    // Parse branch body content
    ParseContent(LElseNode, True);
  end;

  // Consume final closing brace
  if not Match(tkTagClose) then
  begin
    LToken := Current();
    FErrors.Add('', LToken.Line, LToken.Col, esError,
      MU_ERROR_PARSER_UNCLOSED_TAG, RSParserUnclosedTag, ['if']);
  end;
end;

procedure TMuParser.ParseEachBody(const AEachNode: TMuNodeIndex);
var
  LToken: TMuToken;
begin
  ParseContent(AEachNode);

  LToken := Current();
  if not Match(tkTagClose) then
    FErrors.Add('', LToken.Line, LToken.Col, esError,
      MU_ERROR_PARSER_UNCLOSED_TAG, RSParserUnclosedTag, ['each']);
end;

procedure TMuParser.ParseLetSetBody(const ANode: TMuNodeIndex);
var
  LToken: TMuToken;
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LFirstWord: string;
  LRest: string;
begin
  if Check(tkText) then
  begin
    LFirstWord := ExtractFirstWord(Current().Text, LRest);
    LNode := FAST.GetNode(ANode);
    LNode^.Text := LFirstWord;

    if LRest <> '' then
    begin
      Advance();
      LChild := FAST.NewNode(nkText,
        FAST.GetNode(ANode)^.Line, FAST.GetNode(ANode)^.Col);
      FAST.GetNode(LChild)^.Text := LRest;
      FAST.AddChild(ANode, LChild);
    end
    else
      Advance();
  end;

  ParseContent(ANode);

  LToken := Current();
  if not Match(tkTagClose) then
    FErrors.Add('', LToken.Line, LToken.Col, esError,
      MU_ERROR_PARSER_UNCLOSED_TAG,
      RSParserUnclosedTag, [FAST.GetNode(ANode)^.TagName]);
end;

procedure TMuParser.ParseDefBody(const ANode: TMuNodeIndex);
var
  LToken: TMuToken;
  LNode: PMuNode;
  LFirstWord: string;
  LRest: string;
  LParamName: string;
begin
  if Check(tkText) then
  begin
    LFirstWord := ExtractFirstWord(Current().Text, LRest);
    LNode := FAST.GetNode(ANode);
    LNode^.Text := LFirstWord;

    while LRest <> '' do
    begin
      LParamName := ExtractFirstWord(LRest, LRest);
      if LParamName = '' then
        Break;

      if Pos('=', LParamName) > 0 then
      begin
        LFirstWord := Copy(LParamName, Pos('=', LParamName) + 1, MaxInt);
        if (Length(LFirstWord) >= 2) and
           (LFirstWord[1] = '"') and
           (LFirstWord[Length(LFirstWord)] = '"') then
          LFirstWord := Copy(LFirstWord, 2, Length(LFirstWord) - 2);
        FAST.AddAttr(
          Copy(LParamName, 1, Pos('=', LParamName) - 1),
          LFirstWord);
      end
      else
        FAST.AddAttr(LParamName, '');

      LNode := FAST.GetNode(ANode);
      if LNode^.AttrCount = 0 then
        LNode^.AttrStart := FAST.AttrCount() - 1;
      Inc(LNode^.AttrCount);
    end;

    Advance();
  end;

  ParseContent(ANode);

  LToken := Current();
  if not Match(tkTagClose) then
    FErrors.Add('', LToken.Line, LToken.Col, esError,
      MU_ERROR_PARSER_UNCLOSED_TAG, RSParserUnclosedTag, ['def']);
end;

procedure TMuParser.ParseCallBody(const ANode: TMuNodeIndex);
var
  LToken: TMuToken;
  LNode: PMuNode;
  LFirstWord: string;
  LRest: string;
  LParamName: string;
  LParamValue: string;
  LEqPos: Integer;
begin
  if Check(tkText) then
  begin
    LFirstWord := ExtractFirstWord(Current().Text, LRest);
    LNode := FAST.GetNode(ANode);
    LNode^.Text := LFirstWord;

    while LRest <> '' do
    begin
      LParamName := ExtractFirstWord(LRest, LRest);
      if LParamName = '' then
        Break;

      LEqPos := Pos('=', LParamName);
      if LEqPos > 0 then
      begin
        LParamValue := Copy(LParamName, LEqPos + 1, MaxInt);
        LParamName := Copy(LParamName, 1, LEqPos - 1);

        if (Length(LParamValue) >= 2) and
           (LParamValue[1] = '"') and
           (LParamValue[Length(LParamValue)] = '"') then
          LParamValue := Copy(LParamValue, 2, Length(LParamValue) - 2);

        FAST.AddAttr(LParamName, LParamValue);

        LNode := FAST.GetNode(ANode);
        if LNode^.AttrCount = 0 then
          LNode^.AttrStart := FAST.AttrCount() - 1;
        Inc(LNode^.AttrCount);
      end
      else
        Break;
    end;

    Advance();
  end;

  ParseContent(ANode);

  LToken := Current();
  if not Match(tkTagClose) then
    FErrors.Add('', LToken.Line, LToken.Col, esError,
      MU_ERROR_PARSER_UNCLOSED_TAG, RSParserUnclosedTag, ['call']);
end;

{ Document }

function TMuParser.ParseDocument(): TMuNodeIndex;
begin
  Result := FAST.NewNode(nkTag, 1, 1);
  FAST.GetNode(Result)^.TagName := '__root__';
  FAST.Root := Result;

  ParseContent(Result);
end;

function TMuParser.Parse(const ATokens: TArray<TMuToken>): TMuAST;
begin
  FTokens := ATokens;
  FPos := 0;
  FAST := TMuAST.Create();
  FAST.SetErrors(FErrors);

  Status(RSParserStatusStart, [Length(ATokens)]);

  ParseDocument();

  Status(RSParserStatusComplete, [FAST.NodeCount(), FErrors.ErrorCount()]);

  Result := FAST;
end;

end.
