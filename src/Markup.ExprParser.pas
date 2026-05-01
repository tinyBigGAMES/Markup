{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.ExprParser;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markup.Utils,
  Markup.Resources;

const
  MU_ERROR_EXPR_UNEXPECTED_TOKEN = 'MS-E001';
  MU_ERROR_EXPR_UNCLOSED_PAREN  = 'MS-E002';
  MU_ERROR_EXPR_EMPTY            = 'MS-E003';
  MU_ERROR_EXPR_UNTERMINATED_STR = 'MS-E004';

type
  { TMuExprTokenKind }
  TMuExprTokenKind = (
    xkNumber,
    xkString,
    xkIdent,
    xkTrue,
    xkFalse,
    xkNil,
    xkPlus,
    xkMinus,
    xkStar,
    xkSlash,
    xkPercent,
    xkEq,
    xkNe,
    xkLt,
    xkGt,
    xkLe,
    xkGe,
    xkAnd,
    xkOr,
    xkNot,
    xkPipe,
    xkLParen,
    xkRParen,
    xkComma,
    xkDot,
    xkLBracket,
    xkRBracket,
    xkEOF
  );

  { TMuExprToken }
  TMuExprToken = record
    Kind: TMuExprTokenKind;
    Text: string;
  end;

  { TMuExprNodeKind }
  TMuExprNodeKind = (
    ekLiteral,
    ekIdent,
    ekPath,
    ekBinary,
    ekUnary,
    ekCall,
    ekPipe
  );

  { TMuExprNodeIndex }
  TMuExprNodeIndex = Integer;

const
  MU_NO_EXPR = -1;

type
  { PMuExprNode }
  PMuExprNode = ^TMuExprNode;

  { TMuExprNode }
  TMuExprNode = record
    Kind: TMuExprNodeKind;
    Op: string;
    Text: string;
    Left: TMuExprNodeIndex;
    Right: TMuExprNodeIndex;
    FirstChild: TMuExprNodeIndex;
    NextSibling: TMuExprNodeIndex;
  end;

  { TMuExprParser }
  TMuExprParser = class(TMuBaseObject)
  private
    FSource: string;
    FTokens: TList<TMuExprToken>;
    FNodes: TList<TMuExprNode>;
    FPos: Integer;
    FRoot: TMuExprNodeIndex;

    // Expression tokenizer
    procedure Tokenize();
    procedure AddExprToken(const AKind: TMuExprTokenKind;
      const AText: string);

    // Token navigation
    function Current(): TMuExprToken;
    {$HINTS OFF}
    function Peek(const AOffset: Integer = 0): TMuExprToken;
    {$HINTS ON}
    function IsAtEnd(): Boolean;
    function Check(const AKind: TMuExprTokenKind): Boolean;
    function Match(const AKind: TMuExprTokenKind): Boolean;
    procedure Advance();

    // Node creation
    function NewNode(const AKind: TMuExprNodeKind): TMuExprNodeIndex;
    function GetNode(const AIndex: TMuExprNodeIndex): PMuExprNode;
    procedure AddArg(const ACallNode: TMuExprNodeIndex;
      const AArgNode: TMuExprNodeIndex);

    // Pratt parser
    function ParseExpr(const AMinPower: Integer): TMuExprNodeIndex;
    function ParsePrefix(): TMuExprNodeIndex;
    function ParseCallArgs(const ACallee: TMuExprNodeIndex): TMuExprNodeIndex;
    function GetInfixPower(const AKind: TMuExprTokenKind;
      out ALeftPower: Integer; out ARightPower: Integer): Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Parse(const AText: string): TMuExprNodeIndex;

    function NodeCount(): Integer;
    function GetExprNode(const AIndex: TMuExprNodeIndex): PMuExprNode;
    property Root: TMuExprNodeIndex read FRoot;
  end;

implementation

{ TMuExprParser }

constructor TMuExprParser.Create();
begin
  inherited;
  FTokens := TList<TMuExprToken>.Create();
  FNodes := TList<TMuExprNode>.Create();
end;

destructor TMuExprParser.Destroy();
begin
  FreeAndNil(FNodes);
  FreeAndNil(FTokens);
  inherited;
end;

procedure TMuExprParser.AddExprToken(const AKind: TMuExprTokenKind;
  const AText: string);
var
  LToken: TMuExprToken;
begin
  LToken.Kind := AKind;
  LToken.Text := AText;
  FTokens.Add(LToken);
end;

function TMuExprParser.Current(): TMuExprToken;
begin
  if FPos < FTokens.Count then
    Result := FTokens[FPos]
  else
  begin
    Result.Kind := xkEOF;
    Result.Text := '';
  end;
end;

function TMuExprParser.Peek(const AOffset: Integer): TMuExprToken;
var
  LIdx: Integer;
begin
  LIdx := FPos + AOffset;
  if (LIdx >= 0) and (LIdx < FTokens.Count) then
    Result := FTokens[LIdx]
  else
  begin
    Result.Kind := xkEOF;
    Result.Text := '';
  end;
end;

function TMuExprParser.IsAtEnd(): Boolean;
begin
  Result := (FPos >= FTokens.Count) or (Current().Kind = xkEOF);
end;

function TMuExprParser.Check(const AKind: TMuExprTokenKind): Boolean;
begin
  Result := Current().Kind = AKind;
end;

function TMuExprParser.Match(const AKind: TMuExprTokenKind): Boolean;
begin
  if Check(AKind) then
  begin
    Advance();
    Result := True;
  end
  else
    Result := False;
end;

procedure TMuExprParser.Advance();
begin
  if FPos < FTokens.Count then
    Inc(FPos);
end;

function TMuExprParser.NewNode(const AKind: TMuExprNodeKind): TMuExprNodeIndex;
var
  LNode: TMuExprNode;
begin
  LNode.Kind := AKind;
  LNode.Op := '';
  LNode.Text := '';
  LNode.Left := MU_NO_EXPR;
  LNode.Right := MU_NO_EXPR;
  LNode.FirstChild := MU_NO_EXPR;
  LNode.NextSibling := MU_NO_EXPR;
  Result := FNodes.Count;
  FNodes.Add(LNode);
end;

function TMuExprParser.GetNode(const AIndex: TMuExprNodeIndex): PMuExprNode;
begin
  if (AIndex < 0) or (AIndex >= FNodes.Count) then
    Result := nil
  else
    Result := @FNodes.List[AIndex];
end;

function TMuExprParser.GetExprNode(const AIndex: TMuExprNodeIndex): PMuExprNode;
begin
  Result := GetNode(AIndex);
end;

function TMuExprParser.NodeCount(): Integer;
begin
  Result := FNodes.Count;
end;

procedure TMuExprParser.AddArg(const ACallNode: TMuExprNodeIndex;
  const AArgNode: TMuExprNodeIndex);
var
  LCall: PMuExprNode;
  LSibling: TMuExprNodeIndex;
begin
  LCall := GetNode(ACallNode);
  if LCall = nil then
    Exit;

  if LCall^.FirstChild = MU_NO_EXPR then
  begin
    LCall^.FirstChild := AArgNode;
  end
  else
  begin
    LSibling := LCall^.FirstChild;
    while FNodes.List[LSibling].NextSibling <> MU_NO_EXPR do
      LSibling := FNodes.List[LSibling].NextSibling;
    FNodes.List[LSibling].NextSibling := AArgNode;
  end;
end;

procedure TMuExprParser.Tokenize();
var
  LI: Integer;
  LLen: Integer;
  LCh: Char;
  LStart: Integer;
  LText: string;

  function PeekChar(const AOffset: Integer = 0): Char;
  var
    LIdx: Integer;
  begin
    LIdx := LI + AOffset;
    if (LIdx >= 1) and (LIdx <= LLen) then
      Result := FSource[LIdx]
    else
      Result := #0;
  end;

begin
  FTokens.Clear();
  LLen := Length(FSource);
  LI := 1;

  while LI <= LLen do
  begin
    LCh := FSource[LI];

    // Skip whitespace
    if (LCh = ' ') or (LCh = #9) or (LCh = #10) or (LCh = #13) then
    begin
      Inc(LI);
      Continue;
    end;

    // Numbers
    if (LCh >= '0') and (LCh <= '9') then
    begin
      LStart := LI;
      while (LI <= LLen) and (FSource[LI] >= '0') and (FSource[LI] <= '9') do
        Inc(LI);
      // Check for decimal
      if (LI <= LLen) and (FSource[LI] = '.') and
         (LI + 1 <= LLen) and (FSource[LI + 1] >= '0') and (FSource[LI + 1] <= '9') then
      begin
        Inc(LI); // skip dot
        while (LI <= LLen) and (FSource[LI] >= '0') and (FSource[LI] <= '9') do
          Inc(LI);
      end;
      AddExprToken(xkNumber, Copy(FSource, LStart, LI - LStart));
      Continue;
    end;

    // Strings (double or single quoted)
    if (LCh = '"') or (LCh = '''') then
    begin
      LStart := LI;
      Inc(LI); // skip opening quote
      while (LI <= LLen) and (FSource[LI] <> LCh) do
      begin
        if FSource[LI] = '\' then
          Inc(LI); // skip escaped char
        Inc(LI);
      end;
      if LI <= LLen then
        Inc(LI) // skip closing quote
      else
      begin
        FErrors.Add(esError, MU_ERROR_EXPR_UNTERMINATED_STR,
          RSExprUnterminatedStr);
        Exit;
      end;
      // Strip quotes, unescape
      LText := Copy(FSource, LStart + 1, LI - LStart - 2);
      LText := LText.Replace('\"', '"').Replace('\''', '''').Replace('\\', '\');
      AddExprToken(xkString, LText);
      Continue;
    end;

    // Identifiers and keywords
    if ((LCh >= 'a') and (LCh <= 'z')) or ((LCh >= 'A') and (LCh <= 'Z')) or
       (LCh = '_') then
    begin
      LStart := LI;
      while (LI <= LLen) and
            (((FSource[LI] >= 'a') and (FSource[LI] <= 'z')) or
             ((FSource[LI] >= 'A') and (FSource[LI] <= 'Z')) or
             ((FSource[LI] >= '0') and (FSource[LI] <= '9')) or
             (FSource[LI] = '_')) do
        Inc(LI);
      LText := Copy(FSource, LStart, LI - LStart);

      // Check keywords
      if LText = 'and' then
        AddExprToken(xkAnd, LText)
      else if LText = 'or' then
        AddExprToken(xkOr, LText)
      else if LText = 'not' then
        AddExprToken(xkNot, LText)
      else if LText = 'true' then
        AddExprToken(xkTrue, LText)
      else if LText = 'false' then
        AddExprToken(xkFalse, LText)
      else if LText = 'nil' then
        AddExprToken(xkNil, LText)
      else
        AddExprToken(xkIdent, LText);
      Continue;
    end;

    // Two-char operators (check before single-char)
    if LCh = '=' then
    begin
      if PeekChar(1) = '=' then
      begin
        AddExprToken(xkEq, '==');
        Inc(LI, 2);
        Continue;
      end;
    end;

    if LCh = '!' then
    begin
      if PeekChar(1) = '=' then
      begin
        AddExprToken(xkNe, '!=');
        Inc(LI, 2);
        Continue;
      end;
    end;

    if LCh = '<' then
    begin
      if PeekChar(1) = '=' then
      begin
        AddExprToken(xkLe, '<=');
        Inc(LI, 2);
        Continue;
      end;
      AddExprToken(xkLt, '<');
      Inc(LI);
      Continue;
    end;

    if LCh = '>' then
    begin
      if PeekChar(1) = '=' then
      begin
        AddExprToken(xkGe, '>=');
        Inc(LI, 2);
        Continue;
      end;
      AddExprToken(xkGt, '>');
      Inc(LI);
      Continue;
    end;

    // Single-char operators and delimiters
    case LCh of
      '+': AddExprToken(xkPlus, '+');
      '-': AddExprToken(xkMinus, '-');
      '*': AddExprToken(xkStar, '*');
      '/': AddExprToken(xkSlash, '/');
      '%': AddExprToken(xkPercent, '%');
      '|': AddExprToken(xkPipe, '|');
      '(': AddExprToken(xkLParen, '(');
      ')': AddExprToken(xkRParen, ')');
      ',': AddExprToken(xkComma, ',');
      '.': AddExprToken(xkDot, '.');
      '[': AddExprToken(xkLBracket, '[');
      ']': AddExprToken(xkRBracket, ']');
    else
      // Unknown character — skip with error
      FErrors.Add(esError, MU_ERROR_EXPR_UNEXPECTED_TOKEN,
        RSExprUnexpectedToken, [LCh]);
      Exit;
    end;

    Inc(LI);
  end;

  AddExprToken(xkEOF, '');
end;

function TMuExprParser.GetInfixPower(const AKind: TMuExprTokenKind;
  out ALeftPower: Integer; out ARightPower: Integer): Boolean;
begin
  // Spec §11.2 — binding powers (higher = tighter)
  // Left-assoc: right power = left power + 1
  Result := True;
  if AKind = xkPipe then
  begin
    ALeftPower := 2;
    ARightPower := 3;
  end
  else if AKind = xkOr then
  begin
    ALeftPower := 4;
    ARightPower := 5;
  end
  else if AKind = xkAnd then
  begin
    ALeftPower := 6;
    ARightPower := 7;
  end
  else if (AKind = xkEq) or (AKind = xkNe) then
  begin
    ALeftPower := 8;
    ARightPower := 9;
  end
  else if (AKind = xkLt) or (AKind = xkGt) or
          (AKind = xkLe) or (AKind = xkGe) then
  begin
    ALeftPower := 10;
    ARightPower := 11;
  end
  else if (AKind = xkPlus) or (AKind = xkMinus) then
  begin
    ALeftPower := 12;
    ARightPower := 13;
  end
  else if (AKind = xkStar) or (AKind = xkSlash) or (AKind = xkPercent) then
  begin
    ALeftPower := 14;
    ARightPower := 15;
  end
  else
    Result := False;
end;

function TMuExprParser.ParsePrefix(): TMuExprNodeIndex;
var
  LToken: TMuExprToken;
  LNode: PMuExprNode;
  LIdent: string;
begin
  LToken := Current();

  // Number literal
  if LToken.Kind = xkNumber then
  begin
    Result := NewNode(ekLiteral);
    GetNode(Result)^.Text := LToken.Text;
    Advance();
    Exit;
  end;

  // String literal
  if LToken.Kind = xkString then
  begin
    Result := NewNode(ekLiteral);
    GetNode(Result)^.Text := LToken.Text;
    GetNode(Result)^.Op := 'string';
    Advance();
    Exit;
  end;

  // Boolean/nil literals
  if (LToken.Kind = xkTrue) or (LToken.Kind = xkFalse) or
     (LToken.Kind = xkNil) then
  begin
    Result := NewNode(ekLiteral);
    GetNode(Result)^.Text := LToken.Text;
    Advance();
    Exit;
  end;

  // Unary not
  if LToken.Kind = xkNot then
  begin
    Advance();
    Result := NewNode(ekUnary);
    LNode := GetNode(Result);
    LNode^.Op := 'not';
    LNode^.Left := ParseExpr(16); // right-assoc prefix power
    Exit;
  end;

  // Unary minus
  if LToken.Kind = xkMinus then
  begin
    Advance();
    Result := NewNode(ekUnary);
    LNode := GetNode(Result);
    LNode^.Op := '-';
    LNode^.Left := ParseExpr(16);
    Exit;
  end;

  // Grouping: ( expr )
  if LToken.Kind = xkLParen then
  begin
    Advance(); // skip (
    Result := ParseExpr(0);
    if not Match(xkRParen) then
    begin
      FErrors.Add(esError, MU_ERROR_EXPR_UNCLOSED_PAREN,
        RSExprUnclosedParen);
      Exit;
    end;
    Exit;
  end;

  // Identifier (possibly followed by dot path or function call)
  if LToken.Kind = xkIdent then
  begin
    LIdent := LToken.Text;
    Advance();

    // Check for function call: ident(
    if Check(xkLParen) then
    begin
      Result := NewNode(ekCall);
      GetNode(Result)^.Op := LIdent;
      Result := ParseCallArgs(Result);
      Exit;
    end;

    // Check for dotted path: ident.ident.ident
    if Check(xkDot) then
    begin
      Result := NewNode(ekPath);
      GetNode(Result)^.Text := LIdent;
      while Match(xkDot) do
      begin
        if Check(xkIdent) then
        begin
          GetNode(Result)^.Text := GetNode(Result)^.Text + '.' + Current().Text;
          Advance();
        end
        else
          Break;
      end;
      Exit;
    end;

    // Simple identifier
    Result := NewNode(ekIdent);
    GetNode(Result)^.Text := LIdent;
    Exit;
  end;

  // Unexpected token
  FErrors.Add(esError, MU_ERROR_EXPR_UNEXPECTED_TOKEN,
    RSExprUnexpectedToken, [LToken.Text]);
  Result := MU_NO_EXPR;
end;

function TMuExprParser.ParseCallArgs(
  const ACallee: TMuExprNodeIndex): TMuExprNodeIndex;
var
  LArg: TMuExprNodeIndex;
begin
  Result := ACallee;
  Advance(); // skip (

  // Empty args: func()
  if Check(xkRParen) then
  begin
    Advance();
    Exit;
  end;

  // First argument
  LArg := ParseExpr(0);
  if LArg <> MU_NO_EXPR then
    AddArg(Result, LArg);

  // Remaining arguments
  while Match(xkComma) do
  begin
    LArg := ParseExpr(0);
    if LArg <> MU_NO_EXPR then
      AddArg(Result, LArg);
  end;

  if not Match(xkRParen) then
  begin
    FErrors.Add(esError, MU_ERROR_EXPR_UNCLOSED_PAREN,
      RSExprUnclosedParen);
    Exit;
  end;
end;

function TMuExprParser.ParseExpr(const AMinPower: Integer): TMuExprNodeIndex;
var
  LLeft: TMuExprNodeIndex;
  LRight: TMuExprNodeIndex;
  LBinNode: TMuExprNodeIndex;
  LNode: PMuExprNode;
  LToken: TMuExprToken;
  LLeftPower: Integer;
  LRightPower: Integer;
  LIdent: string;
begin
  LLeft := ParsePrefix();
  if LLeft = MU_NO_EXPR then
    Exit(MU_NO_EXPR);

  while not IsAtEnd() do
  begin
    LToken := Current();

    // Pipe operator — creates pipe node
    if (LToken.Kind = xkPipe) and (2 >= AMinPower) then
    begin
      Advance(); // skip |

      // After pipe: function name with optional args
      if Check(xkIdent) then
      begin
        LIdent := Current().Text;
        Advance();

        LBinNode := NewNode(ekPipe);
        LNode := GetNode(LBinNode);
        LNode^.Op := LIdent;
        LNode^.Left := LLeft;

        // Check for args: | func(arg1, arg2)
        if Check(xkLParen) then
        begin
          Advance(); // skip (
          while (not IsAtEnd()) and (not Check(xkRParen)) do
          begin
            LRight := ParseExpr(0);
            if LRight <> MU_NO_EXPR then
              AddArg(LBinNode, LRight);
            if not Match(xkComma) then
              Break;
          end;
          if not Match(xkRParen) then
          begin
            FErrors.Add(esError, MU_ERROR_EXPR_UNCLOSED_PAREN,
              RSExprUnclosedParen);
            Exit(MU_NO_EXPR);
          end;
        end;

        LLeft := LBinNode;
        Continue;
      end
      else
      begin
        FErrors.Add(esError, MU_ERROR_EXPR_UNEXPECTED_TOKEN,
          RSExprUnexpectedToken, ['|']);
        Exit(MU_NO_EXPR);
      end;
    end;

    // Infix binary operators
    if not GetInfixPower(LToken.Kind, LLeftPower, LRightPower) then
      Break;
    if LLeftPower < AMinPower then
      Break;

    Advance(); // skip operator

    LRight := ParseExpr(LRightPower);

    LBinNode := NewNode(ekBinary);
    LNode := GetNode(LBinNode);
    LNode^.Op := LToken.Text;
    LNode^.Left := LLeft;
    LNode^.Right := LRight;

    LLeft := LBinNode;
  end;

  Result := LLeft;
end;

function TMuExprParser.Parse(const AText: string): TMuExprNodeIndex;
var
  LErrorsBefore: Integer;
begin
  FSource := AText.Trim();
  FPos := 0;
  FNodes.Clear();
  FRoot := MU_NO_EXPR;

  if FSource = '' then
  begin
    FErrors.Add(esWarning, MU_ERROR_EXPR_EMPTY, RSExprEmpty);
    Exit(MU_NO_EXPR);
  end;

  Status(RSExprStatusStart, [Length(FSource)]);

  // Track error count before tokenizing — only bail on NEW errors,
  // not pre-existing ones from earlier pipeline stages.
  LErrorsBefore := FErrors.ErrorCount();
  Tokenize();
  if FErrors.ErrorCount() > LErrorsBefore then
    Exit(MU_NO_EXPR);

  FPos := 0;
  FRoot := ParseExpr(0);

  Status(RSExprStatusComplete, [FNodes.Count, FErrors.ErrorCount()]);

  Result := FRoot;
end;

end.
