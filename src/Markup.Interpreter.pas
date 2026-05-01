{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Interpreter;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  System.Classes,
  Markup.Utils,
  Markup.Resources,
  Markup.Value,
  Markup.AST,
  Markup.Context,
  Markup.ExprParser,
  Markup.Environment,
  Markup.Builtins,
  Markup.Pipes,
  Markup.Options;

const
  MU_ERROR_INTERP_ITERATION_LIMIT = 'MS-T001';
  MU_ERROR_INTERP_RECURSION_LIMIT = 'MS-T002';
  MU_ERROR_INTERP_OUTPUT_LIMIT    = 'MS-T003';
  MU_ERROR_INTERP_UNKNOWN_TAG     = 'MS-T004';
  MU_ERROR_INTERP_DIV_ZERO        = 'MS-T005';
  MU_ERROR_INTERP_TYPE_ERROR      = 'MS-T006';
  MU_ERROR_INTERP_INCLUDE_FAIL    = 'MS-T007';
  MU_ERROR_INTERP_CIRCULAR_INCLUDE = 'MS-T008';

  DEFAULT_MAX_ITERATIONS     = 10000;
  DEFAULT_MAX_RECURSION      = 100;
  DEFAULT_MAX_OUTPUT_SIZE    = 10 * 1024 * 1024; // 10 MB

type
  { TMuIncludeResolver — callback to resolve include tags; returns parsed AST (caller owns) }
  TMuIncludeResolver = reference to function(const AFilename: string): TMuAST;

  { TMuInterpreter }
  TMuInterpreter = class(TMuBaseObject)
  private
    FAST: TMuAST;
    FEnv: TMuEnvironment;
    FBuiltins: TMuBuiltins;
    FPipes: TMuPipeChain;
    FExprParser: TMuExprParser;
    FComponents: TDictionary<string, TMuNodeIndex>;
    FOutput: TStringBuilder;
    FTagMap: TDictionary<string, string>;
    FCustomTags: TDictionary<string, TMuTagHandler>;
    FIncludeResolver: TMuIncludeResolver;

    FIterationCount: Integer;
    FRecursionDepth: Integer;
    FMaxIterations: Integer;
    FMaxRecursionDepth: Integer;
    FMaxOutputSize: Integer;

    FPrettyPrint: Boolean;
    FStrictMode: Boolean;
    FAllowHTML: Boolean;
    FUnknownTagBehavior: TMuUnknownTagBehavior;
    FIndentLevel: Integer;
    FBlockTags: TDictionary<string, Boolean>;
    FKnownHtmlTags: TDictionary<string, Boolean>;
    FIncludeStack: TStringList;

    FCallBodyNode: TMuNodeIndex;
    FCallBodyParam: string;

    procedure InitTagMap();
    procedure InitBlockTags();
    procedure InitKnownHtmlTags();
    function IsBlockTag(const ATag: string): Boolean;

    // Core rendering
    procedure RenderNode(const AIndex: TMuNodeIndex);
    procedure RenderChildren(const AParent: TMuNodeIndex);
    procedure RenderTag(const AIndex: TMuNodeIndex);

    // HTML emission
    function HtmlEscape(const AText: string): string;
    procedure Emit(const AText: string);
    procedure EmitOpenTag(const AHtmlTag: string;
      const ANodeIndex: TMuNodeIndex);
    procedure EmitCloseTag(const AHtmlTag: string);
    procedure EmitVoidTag(const AHtmlTag: string;
      const ANodeIndex: TMuNodeIndex);
    procedure EmitAttrs(const ANodeIndex: TMuNodeIndex);

    // Formatting tags
    procedure RenderFormatTag(const AIndex: TMuNodeIndex;
      const ATagName: string);
    procedure RenderCallout(const AIndex: TMuNodeIndex;
      const ATagName: string);
    procedure RenderVerbatim(const AIndex: TMuNodeIndex);

    // Computation tags
    procedure HandleLet(const AIndex: TMuNodeIndex);
    procedure HandleSet(const AIndex: TMuNodeIndex);
    procedure HandleGet(const AIndex: TMuNodeIndex);
    procedure HandleEval(const AIndex: TMuNodeIndex);
    procedure HandleInterpolation(const AIndex: TMuNodeIndex);
    procedure HandleIf(const AIndex: TMuNodeIndex);
    procedure HandleEach(const AIndex: TMuNodeIndex);
    procedure HandleCall(const AIndex: TMuNodeIndex);
    procedure HandleInclude(const AIndex: TMuNodeIndex);

    // Expression evaluation
    function EvalExpr(const AText: string): TMuValue;
    function EvalExprNode(const AExprParser: TMuExprParser;
      const AIndex: TMuExprNodeIndex): TMuValue;
    function NodeTextContent(const AIndex: TMuNodeIndex): string;
    function EvalNodeValue(const AIndex: TMuNodeIndex): TMuValue;
    function InterpolateAttrValue(const AValue: string): string;
    function ResolvePath(const APath: string): TMuValue;

    // Limit checks
    function CheckLimits(): Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    function Render(const AAST: TMuAST;
      const AEnv: TMuEnvironment;
      const ABuiltins: TMuBuiltins;
      const AComponents: TDictionary<string, TMuNodeIndex>): string;

    property MaxIterations: Integer read FMaxIterations write FMaxIterations;
    property MaxRecursionDepth: Integer read FMaxRecursionDepth write FMaxRecursionDepth;
    property MaxOutputSize: Integer read FMaxOutputSize write FMaxOutputSize;
    property PrettyPrint: Boolean read FPrettyPrint write FPrettyPrint;
    property StrictMode: Boolean read FStrictMode write FStrictMode;
    property AllowHTML: Boolean read FAllowHTML write FAllowHTML;
    property UnknownTagBehavior: TMuUnknownTagBehavior read FUnknownTagBehavior write FUnknownTagBehavior;

    procedure SetCustomTags(const ATags: TDictionary<string, TMuTagHandler>);
    procedure SetIncludeResolver(const AResolver: TMuIncludeResolver);
    function GetOutput(): TStringBuilder;
  end;

implementation

{ TMuInterpreter }

constructor TMuInterpreter.Create();
begin
  inherited;
  FOutput := TStringBuilder.Create();
  FTagMap := TDictionary<string, string>.Create();
  FExprParser := TMuExprParser.Create();
  FPipes := TMuPipeChain.Create();
  FBlockTags := TDictionary<string, Boolean>.Create();
  FKnownHtmlTags := TDictionary<string, Boolean>.Create();
  FIncludeStack := TStringList.Create();
  FMaxIterations := DEFAULT_MAX_ITERATIONS;
  FMaxRecursionDepth := DEFAULT_MAX_RECURSION;
  FMaxOutputSize := DEFAULT_MAX_OUTPUT_SIZE;
  FPrettyPrint := False;
  FStrictMode := False;
  FAllowHTML := True;
  FUnknownTagBehavior := utEscape;
  FIndentLevel := 0;
  FCustomTags := nil;
  FCallBodyNode := MU_NO_NODE;
  FCallBodyParam := '';
  InitTagMap();
  InitBlockTags();
  InitKnownHtmlTags();
end;

destructor TMuInterpreter.Destroy();
begin
  FreeAndNil(FIncludeStack);
  FreeAndNil(FKnownHtmlTags);
  FreeAndNil(FBlockTags);
  FreeAndNil(FPipes);
  FreeAndNil(FExprParser);
  FreeAndNil(FTagMap);
  FreeAndNil(FOutput);
  inherited;
end;

procedure TMuInterpreter.InitTagMap();
begin
  // Text formatting
  FTagMap.Add('b', 'strong');
  FTagMap.Add('i', 'em');

  // Structure — Markup name → HTML element
  FTagMap.Add('link', 'a');
  FTagMap.Add('quote', 'blockquote');
  FTagMap.Add('list', 'ul');
  FTagMap.Add('olist', 'ol');
  FTagMap.Add('item', 'li');
  FTagMap.Add('dlist', 'dl');
  FTagMap.Add('term', 'dt');
  FTagMap.Add('desc', 'dd');
  FTagMap.Add('box', 'div');
  FTagMap.Add('line', 'hr');
  FTagMap.Add('fig', 'figure');
  FTagMap.Add('caption', 'figcaption');

  // Tables
  FTagMap.Add('row', 'tr');
  FTagMap.Add('col', 'td');
  FTagMap.Add('hcol', 'th');

  // Tags that pass through with same name — no entry needed,
  // RenderFormatTag uses the tag name directly as fallback
end;

procedure TMuInterpreter.InitBlockTags();
begin
  // Block-level HTML tags that receive newlines + indentation in PrettyPrint mode.
  // Uses HTML names (post tag-map), not Markup names.
  FBlockTags.Add('div', True);
  FBlockTags.Add('section', True);
  FBlockTags.Add('article', True);
  FBlockTags.Add('aside', True);
  FBlockTags.Add('header', True);
  FBlockTags.Add('footer', True);
  FBlockTags.Add('nav', True);
  FBlockTags.Add('main', True);
  FBlockTags.Add('table', True);
  FBlockTags.Add('thead', True);
  FBlockTags.Add('tbody', True);
  FBlockTags.Add('tfoot', True);
  FBlockTags.Add('tr', True);
  FBlockTags.Add('ul', True);
  FBlockTags.Add('ol', True);
  FBlockTags.Add('dl', True);
  FBlockTags.Add('form', True);
  FBlockTags.Add('details', True);
  FBlockTags.Add('blockquote', True);
  FBlockTags.Add('figure', True);
  FBlockTags.Add('figcaption', True);
  FBlockTags.Add('pre', True);
  FBlockTags.Add('p', True);
  FBlockTags.Add('h1', True);
  FBlockTags.Add('h2', True);
  FBlockTags.Add('h3', True);
  FBlockTags.Add('h4', True);
  FBlockTags.Add('h5', True);
  FBlockTags.Add('h6', True);
  FBlockTags.Add('li', True);
  FBlockTags.Add('dt', True);
  FBlockTags.Add('dd', True);
  FBlockTags.Add('hr', True);
end;

function TMuInterpreter.IsBlockTag(const ATag: string): Boolean;
begin
  Result := FBlockTags.ContainsKey(ATag);
end;

procedure TMuInterpreter.InitKnownHtmlTags();
begin
  // All standard HTML5 elements that Markup allows as pass-through.
  // Block-level elements
  FKnownHtmlTags.Add('div', True);
  FKnownHtmlTags.Add('p', True);
  FKnownHtmlTags.Add('section', True);
  FKnownHtmlTags.Add('article', True);
  FKnownHtmlTags.Add('aside', True);
  FKnownHtmlTags.Add('header', True);
  FKnownHtmlTags.Add('footer', True);
  FKnownHtmlTags.Add('nav', True);
  FKnownHtmlTags.Add('main', True);
  FKnownHtmlTags.Add('h1', True);
  FKnownHtmlTags.Add('h2', True);
  FKnownHtmlTags.Add('h3', True);
  FKnownHtmlTags.Add('h4', True);
  FKnownHtmlTags.Add('h5', True);
  FKnownHtmlTags.Add('h6', True);
  FKnownHtmlTags.Add('pre', True);
  FKnownHtmlTags.Add('blockquote', True);
  FKnownHtmlTags.Add('figure', True);
  FKnownHtmlTags.Add('figcaption', True);
  FKnownHtmlTags.Add('address', True);
  FKnownHtmlTags.Add('details', True);
  FKnownHtmlTags.Add('summary', True);
  FKnownHtmlTags.Add('dialog', True);
  // Table elements
  FKnownHtmlTags.Add('table', True);
  FKnownHtmlTags.Add('thead', True);
  FKnownHtmlTags.Add('tbody', True);
  FKnownHtmlTags.Add('tfoot', True);
  FKnownHtmlTags.Add('tr', True);
  FKnownHtmlTags.Add('td', True);
  FKnownHtmlTags.Add('th', True);
  FKnownHtmlTags.Add('caption', True);
  FKnownHtmlTags.Add('colgroup', True);
  // List elements
  FKnownHtmlTags.Add('ul', True);
  FKnownHtmlTags.Add('ol', True);
  FKnownHtmlTags.Add('li', True);
  FKnownHtmlTags.Add('dl', True);
  FKnownHtmlTags.Add('dt', True);
  FKnownHtmlTags.Add('dd', True);
  // Inline elements
  FKnownHtmlTags.Add('span', True);
  FKnownHtmlTags.Add('a', True);
  FKnownHtmlTags.Add('strong', True);
  FKnownHtmlTags.Add('em', True);
  FKnownHtmlTags.Add('u', True);
  FKnownHtmlTags.Add('s', True);
  FKnownHtmlTags.Add('sub', True);
  FKnownHtmlTags.Add('sup', True);
  FKnownHtmlTags.Add('mark', True);
  FKnownHtmlTags.Add('small', True);
  FKnownHtmlTags.Add('abbr', True);
  FKnownHtmlTags.Add('code', True);
  FKnownHtmlTags.Add('kbd', True);
  FKnownHtmlTags.Add('q', True);
  FKnownHtmlTags.Add('cite', True);
  FKnownHtmlTags.Add('time', True);
  FKnownHtmlTags.Add('dfn', True);
  FKnownHtmlTags.Add('var', True);
  FKnownHtmlTags.Add('samp', True);
  FKnownHtmlTags.Add('ins', True);
  FKnownHtmlTags.Add('del', True);
  FKnownHtmlTags.Add('data', True);
  FKnownHtmlTags.Add('bdi', True);
  FKnownHtmlTags.Add('bdo', True);
  FKnownHtmlTags.Add('ruby', True);
  FKnownHtmlTags.Add('rt', True);
  FKnownHtmlTags.Add('rp', True);
  // Form elements
  FKnownHtmlTags.Add('form', True);
  FKnownHtmlTags.Add('button', True);
  FKnownHtmlTags.Add('select', True);
  FKnownHtmlTags.Add('option', True);
  FKnownHtmlTags.Add('optgroup', True);
  FKnownHtmlTags.Add('textarea', True);
  FKnownHtmlTags.Add('label', True);
  FKnownHtmlTags.Add('fieldset', True);
  FKnownHtmlTags.Add('legend', True);
  FKnownHtmlTags.Add('output', True);
  FKnownHtmlTags.Add('meter', True);
  FKnownHtmlTags.Add('progress', True);
  // Media elements
  FKnownHtmlTags.Add('video', True);
  FKnownHtmlTags.Add('audio', True);
  FKnownHtmlTags.Add('source', True);
  FKnownHtmlTags.Add('picture', True);
  FKnownHtmlTags.Add('canvas', True);
  FKnownHtmlTags.Add('map', True);
  FKnownHtmlTags.Add('area', True);
end;

function TMuInterpreter.HtmlEscape(const AText: string): string;
begin
  Result := AText;
  Result := Result.Replace('&', '&amp;', [rfReplaceAll]);
  Result := Result.Replace('<', '&lt;', [rfReplaceAll]);
  Result := Result.Replace('>', '&gt;', [rfReplaceAll]);
  Result := Result.Replace('"', '&quot;', [rfReplaceAll]);
end;

procedure TMuInterpreter.Emit(const AText: string);
begin
  FOutput.Append(AText);
end;

procedure TMuInterpreter.EmitAttrs(const ANodeIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LI: Integer;
  LAttr: TMuAttr;
begin
  LNode := FAST.GetNode(ANodeIndex);
  if (LNode = nil) or (LNode^.AttrCount = 0) then
    Exit;

  for LI := 0 to LNode^.AttrCount - 1 do
  begin
    LAttr := FAST.GetAttr(ANodeIndex, LI);
    if LAttr.AttrValue <> '' then
      Emit(' ' + LAttr.AttrName + '="' +
        HtmlEscape(InterpolateAttrValue(LAttr.AttrValue)) + '"')
    else
      Emit(' ' + LAttr.AttrName);
  end;
end;

procedure TMuInterpreter.EmitOpenTag(const AHtmlTag: string;
  const ANodeIndex: TMuNodeIndex);
begin
  if FPrettyPrint and IsBlockTag(AHtmlTag) then
    Emit(sLineBreak + StringOfChar(' ', FIndentLevel * 2));

  Emit('<' + AHtmlTag);
  EmitAttrs(ANodeIndex);
  Emit('>');

  if FPrettyPrint and IsBlockTag(AHtmlTag) then
    Inc(FIndentLevel);
end;

procedure TMuInterpreter.EmitCloseTag(const AHtmlTag: string);
begin
  if FPrettyPrint and IsBlockTag(AHtmlTag) then
  begin
    Dec(FIndentLevel);
    Emit(sLineBreak + StringOfChar(' ', FIndentLevel * 2));
  end;

  Emit('</' + AHtmlTag + '>');
end;

procedure TMuInterpreter.EmitVoidTag(const AHtmlTag: string;
  const ANodeIndex: TMuNodeIndex);
begin
  Emit('<' + AHtmlTag);
  EmitAttrs(ANodeIndex);
  Emit(' />');
end;

function TMuInterpreter.CheckLimits(): Boolean;
begin
  Result := True;
  if FErrors.ReachedMaxErrors() then
    Exit(False);
  if FOutput.Length >= FMaxOutputSize then
  begin
    FErrors.Add(esError, MU_ERROR_INTERP_OUTPUT_LIMIT,
      RSInterpOutputLimit);
    Exit(False);
  end;
end;

{ Core Rendering }

procedure TMuInterpreter.RenderNode(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
begin
  if AIndex = MU_NO_NODE then
    Exit;
  if not CheckLimits() then
    Exit;

  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  case LNode^.Kind of
    nkText:
      Emit(HtmlEscape(LNode^.Text));

    nkTag:
      RenderTag(AIndex);

    nkComment:
      ; // Comments produce no output

    nkVerbatim:
      RenderVerbatim(AIndex);
  end;
end;

procedure TMuInterpreter.RenderChildren(const AParent: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
begin
  LNode := FAST.GetNode(AParent);
  if LNode = nil then
    Exit;

  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    if not CheckLimits() then
      Exit;
    RenderNode(LChild);
    LChild := FAST.GetNode(LChild)^.NextSibling;
  end;
end;

function TMuInterpreter.NodeTextContent(const AIndex: TMuNodeIndex): string;
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LChildNode: PMuNode;
begin
  Result := '';
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // If the node has text, return it
  if LNode^.Text <> '' then
    Exit(LNode^.Text);

  // Otherwise concatenate text from children
  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    LChildNode := FAST.GetNode(LChild);
    if LChildNode^.Kind = nkText then
      Result := Result + LChildNode^.Text;
    LChild := LChildNode^.NextSibling;
  end;
end;

function TMuInterpreter.ResolvePath(const APath: string): TMuValue;
var
  LParts: TArray<string>;
begin
  Result := FEnv.Resolve(APath);
  if Result.IsNil() and (Pos('.', APath) > 0) then
  begin
    LParts := APath.Split(['.']);
    if Length(LParts) > 0 then
    begin
      Result := FEnv.Resolve(LParts[0]);
      if (not Result.IsNil()) and (Result.Kind = vkMap) then
        Result := Result.AsMap().Resolve(
          Copy(APath, Length(LParts[0]) + 2, MaxInt));
    end;
  end;
end;

function TMuInterpreter.EvalNodeValue(const AIndex: TMuNodeIndex): TMuValue;
var
  LNode: PMuNode;
  LPath: string;
begin
  Result := TMuValue.CreateNil();
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // Text node — resolve as a path
  if LNode^.Kind = nkText then
  begin
    LPath := LNode^.Text.Trim();
    if LPath <> '' then
      Result := ResolvePath(LPath);
    Exit;
  end;

  if LNode^.Kind <> nkTag then
    Exit;

  // {get path} — resolve path from child text (use EvalExpr to support pipes)
  if LNode^.TagName = 'get' then
  begin
    LPath := LNode^.Text.Trim();
    if LPath = '' then
      LPath := NodeTextContent(AIndex).Trim();
    if LPath <> '' then
      Result := EvalExpr(LPath);
    Exit;
  end;

  // {= expr} — evaluate expression
  if LNode^.TagName = '=' then
  begin
    if LNode^.Text <> '' then
      Result := EvalExpr(LNode^.Text);
    Exit;
  end;

  // {eval expr} — evaluate expression from children
  if LNode^.TagName = 'eval' then
  begin
    LPath := NodeTextContent(AIndex).Trim();
    if LPath <> '' then
      Result := EvalExpr(LPath);
    Exit;
  end;
end;

function TMuInterpreter.InterpolateAttrValue(const AValue: string): string;
var
  LI: Integer;
  LLen: Integer;
  LResult: TStringBuilder;
  LExpr: string;
  LDepth: Integer;
  LValue: TMuValue;
begin
  LLen := Length(AValue);

  // Fast path: no interpolation markers
  if (LLen = 0) or (Pos('{=', AValue) = 0) then
  begin
    Result := AValue;
    Exit;
  end;

  LResult := TStringBuilder.Create();
  try
    LI := 1;
    while LI <= LLen do
    begin
      // Check for {= interpolation start
      if (AValue[LI] = '{') and (LI + 1 <= LLen) and
         (AValue[LI + 1] = '=') then
      begin
        Inc(LI, 2); // skip {=

        // Skip optional space after =
        if (LI <= LLen) and (AValue[LI] = ' ') then
          Inc(LI);

        // Collect expression until matching }
        LExpr := '';
        LDepth := 1;
        while LI <= LLen do
        begin
          if AValue[LI] = '{' then
            Inc(LDepth)
          else if AValue[LI] = '}' then
          begin
            Dec(LDepth);
            if LDepth = 0 then
            begin
              Inc(LI); // skip closing }
              Break;
            end;
          end;
          LExpr := LExpr + AValue[LI];
          Inc(LI);
        end;

        // Evaluate and append
        LValue := EvalExpr(LExpr);
        LResult.Append(LValue.AsString());
      end
      else
      begin
        LResult.Append(AValue[LI]);
        Inc(LI);
      end;
    end;
    Result := LResult.ToString();
  finally
    LResult.Free();
  end;
end;

procedure TMuInterpreter.RenderTag(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LTagName: string;
  LHtmlTag: string;
  LHandler: TMuTagHandler;
  LCtx: TMuRenderContext;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  LTagName := LNode^.TagName;

  // Root node — just render children
  if LTagName = '__root__' then
  begin
    RenderChildren(AIndex);
    Exit;
  end;

  // Custom tag handlers take priority over built-in processing
  if (FCustomTags <> nil) and FCustomTags.TryGetValue(LowerCase(LTagName), LHandler) then
  begin
    LCtx := TMuRenderContext.Create();
    try
      LCtx.Init(FAST, AIndex, FOutput,
        procedure(const AParent: TMuNodeIndex)
        begin
          RenderChildren(AParent);
        end);
      LHandler(LCtx);
    finally
      FreeAndNil(LCtx);
    end;
    Exit;
  end;

  // Computation tags — no HTML output, just logic
  if LTagName = 'let' then
  begin
    HandleLet(AIndex);
    Exit;
  end;

  if LTagName = 'set' then
  begin
    HandleSet(AIndex);
    Exit;
  end;

  if LTagName = 'get' then
  begin
    HandleGet(AIndex);
    Exit;
  end;

  if LTagName = 'eval' then
  begin
    HandleEval(AIndex);
    Exit;
  end;

  if LTagName = '=' then
  begin
    HandleInterpolation(AIndex);
    Exit;
  end;

  if LTagName = 'if' then
  begin
    HandleIf(AIndex);
    Exit;
  end;

  if LTagName = 'each' then
  begin
    HandleEach(AIndex);
    Exit;
  end;

  if LTagName = 'call' then
  begin
    HandleCall(AIndex);
    Exit;
  end;

  // def — already registered by semantics, skip at render time
  if LTagName = 'def' then
    Exit;

  // meta — no visible output
  if LTagName = 'meta' then
    Exit;

  // include — resolve and render external file
  if LTagName = 'include' then
  begin
    HandleInclude(AIndex);
    Exit;
  end;

  // Void tags
  if (LTagName = 'line') or (LTagName = 'br') then
  begin
    if FTagMap.TryGetValue(LTagName, LHtmlTag) then
      EmitVoidTag(LHtmlTag, AIndex)
    else
      EmitVoidTag(LTagName, AIndex);
    Exit;
  end;

  if (LTagName = 'img') or (LTagName = 'input') then
  begin
    EmitVoidTag(LTagName, AIndex);
    Exit;
  end;

  // Callouts — spec §3.10
  if (LTagName = 'note') or (LTagName = 'tip') or
     (LTagName = 'warning') or (LTagName = 'danger') then
  begin
    RenderCallout(AIndex, LTagName);
    Exit;
  end;

  // Grid layout — spec §3.13
  if LTagName = 'grid' then
  begin
    Emit('<div class="grid"');
    EmitAttrs(AIndex);
    Emit('>');
    RenderChildren(AIndex);
    Emit('</div>');
    Exit;
  end;

  if LTagName = 'cell' then
  begin
    Emit('<div class="cell">');
    RenderChildren(AIndex);
    Emit('</div>');
    Exit;
  end;

  if LTagName = 'columns' then
  begin
    Emit('<div class="columns">');
    RenderChildren(AIndex);
    Emit('</div>');
    Exit;
  end;

  if LTagName = 'column' then
  begin
    Emit('<div class="col">');
    RenderChildren(AIndex);
    Emit('</div>');
    Exit;
  end;

  if LTagName = 'card' then
  begin
    Emit('<div class="card">');
    RenderChildren(AIndex);
    Emit('</div>');
    Exit;
  end;

  // Details/summary — spec §3.9
  if LTagName = 'details' then
  begin
    Emit('<details');
    EmitAttrs(AIndex);
    Emit('>');
    if FAST.HasAttr(AIndex, 'summary') then
      Emit('<summary>' + HtmlEscape(FAST.GetAttrValue(AIndex, 'summary')) + '</summary>');
    RenderChildren(AIndex);
    Emit('</details>');
    Exit;
  end;

  // All other tags — check if known, then format; otherwise handle as unknown
  if FTagMap.ContainsKey(LTagName) or FKnownHtmlTags.ContainsKey(LTagName) then
  begin
    RenderFormatTag(AIndex, LTagName);
    Exit;
  end;

  // Unknown tag — report error in strict mode
  if FStrictMode then
    FErrors.Add(esError, MU_ERROR_INTERP_UNKNOWN_TAG,
      RSInterpUnknownTag, [LTagName]);

  // Apply unknown tag behavior
  if FUnknownTagBehavior = utPassthrough then
  begin
    Emit('<span class="mu-unknown">');
    RenderChildren(AIndex);
    Emit('</span>');
  end
  else
  begin
    // utEscape — show as escaped text
    Emit(HtmlEscape('{' + LTagName + '}'));
    RenderChildren(AIndex);
    Emit(HtmlEscape('{/' + LTagName + '}'));
  end;
end;

procedure TMuInterpreter.RenderFormatTag(const AIndex: TMuNodeIndex;
  const ATagName: string);
var
  LHtmlTag: string;
begin
  // Check tag map for remapped names (b→strong, i→em)
  if not FTagMap.TryGetValue(ATagName, LHtmlTag) then
    LHtmlTag := ATagName; // Pass through as-is

  EmitOpenTag(LHtmlTag, AIndex);
  RenderChildren(AIndex);
  EmitCloseTag(LHtmlTag);
end;

procedure TMuInterpreter.RenderCallout(const AIndex: TMuNodeIndex;
  const ATagName: string);
begin
  Emit('<div class="callout callout-' + ATagName + '" role="note">');
  RenderChildren(AIndex);
  Emit('</div>');
end;

procedure TMuInterpreter.RenderVerbatim(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LLang: string;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  if LNode^.TagName = 'html' then
  begin
    // Raw HTML passthrough — escape if AllowHTML is disabled
    if FAllowHTML then
      Emit(LNode^.Text)
    else
      Emit(HtmlEscape(LNode^.Text));
  end
  else if LNode^.TagName = 'code' then
  begin
    // Code block — check for lang attribute
    LLang := FAST.GetAttrValue(AIndex, 'lang');
    if (LLang = '') and (not LNode^.Text.Contains(#10)) then
    begin
      // Inline code — no lang, no newlines
      Emit('<code>');
      Emit(HtmlEscape(LNode^.Text));
      Emit('</code>');
    end
    else if LLang <> '' then
    begin
      Emit('<pre><code class="language-' + HtmlEscape(LLang) + '">');
      Emit(HtmlEscape(LNode^.Text));
      Emit('</code></pre>');
    end
    else
    begin
      Emit('<pre><code>');
      Emit(HtmlEscape(LNode^.Text));
      Emit('</code></pre>');
    end;
  end;
end;

{ Computation Tags }

procedure TMuInterpreter.HandleLet(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LValue: TMuValue;
begin
  LNode := FAST.GetNode(AIndex);
  if (LNode = nil) or (LNode^.Text = '') then
    Exit;

  // Value is from children (text or nested tags)
  if LNode^.FirstChild <> MU_NO_NODE then
  begin
    // If first child is a tag (like {eval}), render it and capture
    LValue := TMuValue.FromString(NodeTextContent(AIndex));
  end
  else
    LValue := TMuValue.FromString('');

  FEnv.Bind(LNode^.Text, LValue);
end;

procedure TMuInterpreter.HandleSet(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LValue: TMuValue;
begin
  LNode := FAST.GetNode(AIndex);
  if (LNode = nil) or (LNode^.Text = '') then
    Exit;

  if LNode^.FirstChild <> MU_NO_NODE then
    LValue := TMuValue.FromString(NodeTextContent(AIndex))
  else
    LValue := TMuValue.FromString('');

  FEnv.Update(LNode^.Text, LValue);
end;

procedure TMuInterpreter.HandleGet(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LPath: string;
  LValue: TMuValue;
  LChild: TMuNodeIndex;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  LPath := LNode^.Text.Trim();
  if LPath = '' then
    LPath := NodeTextContent(AIndex).Trim();
  if LPath = '' then
    Exit;

  // Intercept body param from {call}: render call children directly
  if (FCallBodyNode <> MU_NO_NODE) and (LPath = FCallBodyParam) then
  begin
    LChild := FAST.GetNode(FCallBodyNode)^.FirstChild;
    while LChild <> MU_NO_NODE do
    begin
      RenderNode(LChild);
      LChild := FAST.GetNode(LChild)^.NextSibling;
    end;
    Exit;
  end;

  LValue := ResolvePath(LPath);

  // Strict mode: report error for undefined variables
  if FStrictMode and LValue.IsNil() then
    FErrors.Add(esError, MU_ERROR_INTERP_UNKNOWN_TAG,
      RSInterpStrictUndefinedVar, [LPath]);

  Emit(HtmlEscape(LValue.AsString()));
end;

procedure TMuInterpreter.HandleEval(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LChildNode: PMuNode;
  LExprText: string;
  LValue: TMuValue;
  LTempIdx: Integer;
  LTempName: string;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // If the node has direct text, use it as-is
  if LNode^.Text <> '' then
  begin
    LValue := EvalExpr(LNode^.Text.Trim());
    Emit(HtmlEscape(LValue.AsString()));
    Exit;
  end;

  // Build expression text from children. Tag children (e.g. {get price})
  // are resolved to their values and bound as temporary variables so the
  // expression evaluator can handle all value types — including lists and
  // maps that cannot round-trip through AsString().
  FEnv.Push();
  try
    LTempIdx := 0;
    LExprText := '';
    LChild := LNode^.FirstChild;
    while LChild <> MU_NO_NODE do
    begin
      LChildNode := FAST.GetNode(LChild);
      if LChildNode^.Kind = nkText then
        LExprText := LExprText + LChildNode^.Text
      else if LChildNode^.Kind = nkTag then
      begin
        LTempName := '__e' + IntToStr(LTempIdx);
        Inc(LTempIdx);
        FEnv.Bind(LTempName, EvalNodeValue(LChild));
        LExprText := LExprText + LTempName;
      end;
      LChild := LChildNode^.NextSibling;
    end;

    LExprText := LExprText.Trim();
    if LExprText = '' then
      Exit;

    LValue := EvalExpr(LExprText);
    Emit(HtmlEscape(LValue.AsString()));
  finally
    FEnv.Pop();
  end;
end;

procedure TMuInterpreter.HandleInterpolation(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LValue: TMuValue;
begin
  LNode := FAST.GetNode(AIndex);
  if (LNode = nil) or (LNode^.Text = '') then
    Exit;

  LValue := EvalExpr(LNode^.Text);
  Emit(HtmlEscape(LValue.AsString()));
end;

procedure TMuInterpreter.HandleIf(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LChildNode: PMuNode;
  LConditionMet: Boolean;
  LCondValue: TMuValue;
  LCondText: string;
  LCondChild: TMuNodeIndex;
  LCondChildNode: PMuNode;
  LBodyChild: TMuNodeIndex;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // First child group (before any {else}/{elseif}) is the true branch.
  // The first child is the condition (a tag or text).
  LConditionMet := False;
  LChild := LNode^.FirstChild;

  // Evaluate the condition — first child
  if LChild <> MU_NO_NODE then
  begin
    LChildNode := FAST.GetNode(LChild);

    // If condition is a tag (like {get show}), render it to get the value
    if LChildNode^.Kind = nkTag then
    begin
      LCondText := NodeTextContent(LChild);
      if LCondText <> '' then
        LCondValue := EvalExpr(LCondText)
      else
      begin
        // Render the tag to get its output as the condition
        // Save output, render, capture, restore
        FEnv.Push();
        try
          LCondValue := FEnv.Resolve(NodeTextContent(LChild));
        finally
          FEnv.Pop();
        end;
      end;
    end
    else
      LCondValue := TMuValue.FromString(LChildNode^.Text.Trim());

    LConditionMet := LCondValue.IsTruthy();
    LChild := LChildNode^.NextSibling; // move past condition
  end;

  if LConditionMet then
  begin
    // Render true branch — children until {else}/{elseif}
    while LChild <> MU_NO_NODE do
    begin
      LChildNode := FAST.GetNode(LChild);
      if (LChildNode^.Kind = nkTag) and
         ((LChildNode^.TagName = 'else') or (LChildNode^.TagName = 'elseif')) then
        Break;
      RenderNode(LChild);
      LChild := LChildNode^.NextSibling;
    end;
  end
  else
  begin
    // Skip true branch, find {else} or {elseif}
    while LChild <> MU_NO_NODE do
    begin
      LChildNode := FAST.GetNode(LChild);
      if (LChildNode^.Kind = nkTag) and
         ((LChildNode^.TagName = 'else') or (LChildNode^.TagName = 'elseif')) then
        Break;
      LChild := LChildNode^.NextSibling;
    end;

    // Process branch delimiters
    while LChild <> MU_NO_NODE do
    begin
      LChildNode := FAST.GetNode(LChild);

      if (LChildNode^.Kind = nkTag) and (LChildNode^.TagName = 'else') then
      begin
        // Render else branch content
        RenderChildren(LChild);
        Exit;
      end;

      if (LChildNode^.Kind = nkTag) and (LChildNode^.TagName = 'elseif') then
      begin
        // Evaluate elseif condition — first child of elseif node
        LCondChild := LChildNode^.FirstChild;
        LCondValue := TMuValue.CreateNil();
        if LCondChild <> MU_NO_NODE then
        begin
          LCondChildNode := FAST.GetNode(LCondChild);
          if LCondChildNode^.Kind = nkTag then
          begin
            LCondText := NodeTextContent(LCondChild);
            if LCondText <> '' then
              LCondValue := EvalExpr(LCondText)
            else
              LCondValue := EvalNodeValue(LCondChild);
          end
          else
            LCondValue := TMuValue.FromString(LCondChildNode^.Text.Trim());
        end;

        if LCondValue.IsTruthy() then
        begin
          // Render body children (skip the condition child)
          LBodyChild := FAST.GetNode(LCondChild)^.NextSibling;
          while LBodyChild <> MU_NO_NODE do
          begin
            RenderNode(LBodyChild);
            LBodyChild := FAST.GetNode(LBodyChild)^.NextSibling;
          end;
          Exit;
        end;
      end;

      LChild := LChildNode^.NextSibling;
    end;
  end;
end;

procedure TMuInterpreter.HandleEach(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LChildNode: PMuNode;
  LListValue: TMuValue;
  LList: TMuList;
  LMap: TMuMap;
  LBindingName: string;
  LKeyBinding: string;
  LValueBinding: string;
  LItem: TMuValue;
  LI: Integer;
  LBodyStart: TMuNodeIndex;
  LText: string;
  LParts: TArray<string>;
  LKeys: TArray<string>;
  LLoopMap: TMuMap;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // Parse the {each} content: list expression, binding name(s), then body
  // The first child is the list expression (a tag like {get items})
  // Then text containing the binding name(s)
  // Then the body content

  LChild := LNode^.FirstChild;
  if LChild = MU_NO_NODE then
    Exit;

  // First child: evaluate via AST to get the list value
  LListValue := EvalNodeValue(LChild);
  LChildNode := FAST.GetNode(LChild);

  LChild := LChildNode^.NextSibling;

  // Next: binding name(s) from text
  LBindingName := '';
  LKeyBinding := '';
  LValueBinding := '';
  if (LChild <> MU_NO_NODE) then
  begin
    LChildNode := FAST.GetNode(LChild);
    if LChildNode^.Kind = nkText then
    begin
      LText := LChildNode^.Text.Trim();
      LParts := LText.Split([' ', #9]);
      if Length(LParts) >= 1 then
        LBindingName := LParts[0];
      if Length(LParts) >= 2 then
      begin
        LKeyBinding := LParts[0];
        LValueBinding := LParts[1];
      end;
      LChild := LChildNode^.NextSibling;
    end;
  end;

  if LBindingName = '' then
    Exit;

  LBodyStart := LChild;

  // Iterate
  if LListValue.Kind = vkList then
  begin
    LList := LListValue.AsList();
    if LList = nil then
      Exit;

    for LI := 0 to LList.Count - 1 do
    begin
      Inc(FIterationCount);
      if FIterationCount > FMaxIterations then
      begin
        FErrors.Add(esError, MU_ERROR_INTERP_ITERATION_LIMIT,
          RSInterpIterationLimit);
        Exit;
      end;

      FEnv.Push();
      try
        LItem := LList[LI];
        FEnv.Bind(LBindingName, LItem);

        // Bind loop variables (spec §4.5)
        LLoopMap := TMuMap.Create();
        LLoopMap.SetErrors(FErrors);
        LLoopMap.Put('index', TMuValue.FromInteger(LI));
        LLoopMap.Put('count', TMuValue.FromInteger(LI + 1));
        LLoopMap.Put('first', TMuValue.FromBoolean(LI = 0));
        LLoopMap.Put('last', TMuValue.FromBoolean(LI = LList.Count - 1));
        LLoopMap.Put('length', TMuValue.FromInteger(LList.Count));
        FEnv.Bind('loop', TMuValue.FromMap(LLoopMap));

        // Render body
        LChild := LBodyStart;
        while LChild <> MU_NO_NODE do
        begin
          RenderNode(LChild);
          LChild := FAST.GetNode(LChild)^.NextSibling;
        end;
      finally
        FEnv.Pop();
        FreeAndNil(LLoopMap);
      end;
    end;
  end
  else if (LListValue.Kind = vkMap) and (LKeyBinding <> '') then
  begin
    // Map iteration: {each {get map} key value ... }
    LMap := LListValue.AsMap();
    if LMap = nil then
      Exit;

    LKeys := LMap.GetKeys();
    for LI := 0 to Length(LKeys) - 1 do
    begin
      Inc(FIterationCount);
      if FIterationCount > FMaxIterations then
      begin
        FErrors.Add(esError, MU_ERROR_INTERP_ITERATION_LIMIT,
          RSInterpIterationLimit);
        Exit;
      end;

      FEnv.Push();
      try
        FEnv.Bind(LKeyBinding, TMuValue.FromString(LKeys[LI]));
        FEnv.Bind(LValueBinding, LMap.Get(LKeys[LI]));

        LChild := LBodyStart;
        while LChild <> MU_NO_NODE do
        begin
          RenderNode(LChild);
          LChild := FAST.GetNode(LChild)^.NextSibling;
        end;
      finally
        FEnv.Pop();
      end;
    end;
  end;
end;

procedure TMuInterpreter.HandleCall(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LCallName: string;
  LDefIndex: TMuNodeIndex;
  LDefNode: PMuNode;
  LI: Integer;
  LAttr: TMuAttr;
  LDefAttr: TMuAttr;
  LSavedBodyNode: TMuNodeIndex;
  LSavedBodyParam: string;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // Component name is in Node.Text (set by ParseCallBody)
  LCallName := LNode^.Text.Trim();
  if LCallName = '' then
    Exit;

  // Find the component definition
  if (FComponents = nil) or
     (not FComponents.TryGetValue(LCallName, LDefIndex)) then
    Exit;

  Inc(FRecursionDepth);
  if FRecursionDepth > FMaxRecursionDepth then
  begin
    FErrors.Add(esError, MU_ERROR_INTERP_RECURSION_LIMIT,
      RSInterpRecursionLimit);
    Dec(FRecursionDepth);
    Exit;
  end;

  try
    FEnv.Push();
    try
      LDefNode := FAST.GetNode(LDefIndex);
      if LDefNode = nil then
        Exit;

      // Bind parameters from {def} defaults
      for LI := 0 to LDefNode^.AttrCount - 1 do
      begin
        LDefAttr := FAST.GetAttr(LDefIndex, LI);
        FEnv.Bind(LDefAttr.AttrName,
          TMuValue.FromString(LDefAttr.AttrValue));
      end;

      // Override with {call} provided attributes
      for LI := 0 to LNode^.AttrCount - 1 do
      begin
        LAttr := FAST.GetAttr(AIndex, LI);
        FEnv.Bind(LAttr.AttrName,
          TMuValue.FromString(LAttr.AttrValue));
      end;

      // Save and set body interception state so {get body} in the
      // def walks the call's children directly (no double-escape)
      LSavedBodyNode := FCallBodyNode;
      LSavedBodyParam := FCallBodyParam;

      if (LNode^.FirstChild <> MU_NO_NODE) and
         (LDefNode^.AttrCount > 0) then
      begin
        LDefAttr := FAST.GetAttr(LDefIndex, LDefNode^.AttrCount - 1);
        FCallBodyNode := AIndex;
        FCallBodyParam := LDefAttr.AttrName;
      end
      else
      begin
        FCallBodyNode := MU_NO_NODE;
        FCallBodyParam := '';
      end;

      try
        // Render the component body
        RenderChildren(LDefIndex);
      finally
        FCallBodyNode := LSavedBodyNode;
        FCallBodyParam := LSavedBodyParam;
      end;
    finally
      FEnv.Pop();
    end;
  finally
    Dec(FRecursionDepth);
  end;
end;

{ Expression Evaluation }

function TMuInterpreter.EvalExpr(const AText: string): TMuValue;
var
  LRoot: TMuExprNodeIndex;
  LErrorsBefore: Integer;
begin
  if AText.Trim() = '' then
    Exit(TMuValue.CreateNil());

  LErrorsBefore := FErrors.ErrorCount();
  FExprParser.SetErrors(FErrors);
  LRoot := FExprParser.Parse(AText);

  if (FErrors.ErrorCount() > LErrorsBefore) or (LRoot = MU_NO_EXPR) then
    Exit(TMuValue.CreateNil());

  Result := EvalExprNode(FExprParser, LRoot);
end;

function TMuInterpreter.EvalExprNode(const AExprParser: TMuExprParser;
  const AIndex: TMuExprNodeIndex): TMuValue;
var
  LNode: PMuExprNode;
  LLeft: TMuValue;
  LRight: TMuValue;
  LArgs: TArray<TMuValue>;
  LArgNode: TMuExprNodeIndex;
  LArgCount: Integer;
  LIntA: Int64;
  LIntB: Int64;
  LFloatA: Double;
  LFloatB: Double;
begin
  Result := TMuValue.CreateNil();
  if AIndex = MU_NO_EXPR then
    Exit;

  LNode := AExprParser.GetExprNode(AIndex);
  if LNode = nil then
    Exit;

  if LNode^.Kind = ekLiteral then
  begin
    if LNode^.Op = 'string' then
      Exit(TMuValue.FromString(LNode^.Text));
    if LNode^.Text = 'true' then
      Exit(TMuValue.FromBoolean(True));
    if LNode^.Text = 'false' then
      Exit(TMuValue.FromBoolean(False));
    if LNode^.Text = 'nil' then
      Exit(TMuValue.CreateNil());
    // Number
    if Pos('.', LNode^.Text) > 0 then
      Exit(TMuValue.FromFloat(StrToFloatDef(LNode^.Text, 0.0)))
    else
      Exit(TMuValue.FromInteger(StrToInt64Def(LNode^.Text, 0)));
  end;

  if LNode^.Kind = ekIdent then
    Exit(FEnv.Resolve(LNode^.Text));

  if LNode^.Kind = ekPath then
  begin
    Result := FEnv.Resolve(LNode^.Text);
    if Result.IsNil() and (Pos('.', LNode^.Text) > 0) then
    begin
      LLeft := FEnv.Resolve(LNode^.Text.Split(['.'])[0]);
      if LLeft.Kind = vkMap then
        Result := LLeft.AsMap().Resolve(
          Copy(LNode^.Text, Pos('.', LNode^.Text) + 1, MaxInt));
    end;
    Exit;
  end;

  if LNode^.Kind = ekUnary then
  begin
    LLeft := EvalExprNode(AExprParser, LNode^.Left);
    if LNode^.Op = 'not' then
      Exit(TMuValue.FromBoolean(not LLeft.IsTruthy()));
    if LNode^.Op = '-' then
    begin
      if LLeft.Kind = vkFloat then
        Exit(TMuValue.FromFloat(-LLeft.AsFloat()))
      else
        Exit(TMuValue.FromInteger(-LLeft.AsInteger()));
    end;
    Exit;
  end;

  if LNode^.Kind = ekCall then
  begin
    // Collect arguments from FirstChild chain
    LArgCount := 0;
    LArgNode := LNode^.FirstChild;
    while LArgNode <> MU_NO_EXPR do
    begin
      Inc(LArgCount);
      LArgNode := AExprParser.GetExprNode(LArgNode)^.NextSibling;
    end;

    SetLength(LArgs, LArgCount);
    LArgCount := 0;
    LArgNode := LNode^.FirstChild;
    while LArgNode <> MU_NO_EXPR do
    begin
      LArgs[LArgCount] := EvalExprNode(AExprParser, LArgNode);
      Inc(LArgCount);
      LArgNode := AExprParser.GetExprNode(LArgNode)^.NextSibling;
    end;

    Exit(FBuiltins.Call(LNode^.Op, LArgs));
  end;

  if LNode^.Kind = ekPipe then
  begin
    LLeft := EvalExprNode(AExprParser, LNode^.Left);

    // Collect extra args
    LArgCount := 0;
    LArgNode := LNode^.FirstChild;
    while LArgNode <> MU_NO_EXPR do
    begin
      Inc(LArgCount);
      LArgNode := AExprParser.GetExprNode(LArgNode)^.NextSibling;
    end;

    SetLength(LArgs, LArgCount);
    LArgCount := 0;
    LArgNode := LNode^.FirstChild;
    while LArgNode <> MU_NO_EXPR do
    begin
      LArgs[LArgCount] := EvalExprNode(AExprParser, LArgNode);
      Inc(LArgCount);
      LArgNode := AExprParser.GetExprNode(LArgNode)^.NextSibling;
    end;

    Exit(FPipes.Evaluate(LLeft, LNode^.Op, LArgs));
  end;

  if LNode^.Kind = ekBinary then
  begin
    LLeft := EvalExprNode(AExprParser, LNode^.Left);
    LRight := EvalExprNode(AExprParser, LNode^.Right);

    // String concatenation: + when either operand is string
    if (LNode^.Op = '+') and
       ((LLeft.Kind = vkString) or (LRight.Kind = vkString)) then
      Exit(TMuValue.FromString(LLeft.AsString() + LRight.AsString()));

    // Arithmetic
    if (LNode^.Op = '+') or (LNode^.Op = '-') or
       (LNode^.Op = '*') or (LNode^.Op = '/') or (LNode^.Op = '%') then
    begin
      // Use float if either is float
      if (LLeft.Kind = vkFloat) or (LRight.Kind = vkFloat) then
      begin
        LFloatA := LLeft.AsFloat();
        LFloatB := LRight.AsFloat();
        if LNode^.Op = '+' then
          Exit(TMuValue.FromFloat(LFloatA + LFloatB));
        if LNode^.Op = '-' then
          Exit(TMuValue.FromFloat(LFloatA - LFloatB));
        if LNode^.Op = '*' then
          Exit(TMuValue.FromFloat(LFloatA * LFloatB));
        if LNode^.Op = '/' then
        begin
          if LFloatB = 0.0 then
          begin
            FErrors.Add(esError, MU_ERROR_INTERP_DIV_ZERO,
              RSInterpDivZero);
            Exit(TMuValue.CreateNil());
          end;
          Exit(TMuValue.FromFloat(LFloatA / LFloatB));
        end;
        if LNode^.Op = '%' then
        begin
          if LFloatB = 0.0 then
          begin
            FErrors.Add(esError, MU_ERROR_INTERP_DIV_ZERO,
              RSInterpDivZero);
            Exit(TMuValue.CreateNil());
          end;
          Exit(TMuValue.FromFloat(LFloatA - Int(LFloatA / LFloatB) * LFloatB));
        end;
      end
      else
      begin
        LIntA := LLeft.AsInteger();
        LIntB := LRight.AsInteger();
        if LNode^.Op = '+' then
          Exit(TMuValue.FromInteger(LIntA + LIntB));
        if LNode^.Op = '-' then
          Exit(TMuValue.FromInteger(LIntA - LIntB));
        if LNode^.Op = '*' then
          Exit(TMuValue.FromInteger(LIntA * LIntB));
        if LNode^.Op = '/' then
        begin
          if LIntB = 0 then
          begin
            FErrors.Add(esError, MU_ERROR_INTERP_DIV_ZERO,
              RSInterpDivZero);
            Exit(TMuValue.CreateNil());
          end;
          Exit(TMuValue.FromInteger(LIntA div LIntB));
        end;
        if LNode^.Op = '%' then
        begin
          if LIntB = 0 then
          begin
            FErrors.Add(esError, MU_ERROR_INTERP_DIV_ZERO,
              RSInterpDivZero);
            Exit(TMuValue.CreateNil());
          end;
          Exit(TMuValue.FromInteger(LIntA mod LIntB));
        end;
      end;
    end;

    // Comparison
    if LNode^.Op = '==' then
      Exit(TMuValue.FromBoolean(LLeft.AsString() = LRight.AsString()));
    if LNode^.Op = '!=' then
      Exit(TMuValue.FromBoolean(LLeft.AsString() <> LRight.AsString()));
    if LNode^.Op = '<' then
      Exit(TMuValue.FromBoolean(LLeft.AsFloat() < LRight.AsFloat()));
    if LNode^.Op = '>' then
      Exit(TMuValue.FromBoolean(LLeft.AsFloat() > LRight.AsFloat()));
    if LNode^.Op = '<=' then
      Exit(TMuValue.FromBoolean(LLeft.AsFloat() <= LRight.AsFloat()));
    if LNode^.Op = '>=' then
      Exit(TMuValue.FromBoolean(LLeft.AsFloat() >= LRight.AsFloat()));

    // Logical
    if LNode^.Op = 'and' then
      Exit(TMuValue.FromBoolean(LLeft.IsTruthy() and LRight.IsTruthy()));
    if LNode^.Op = 'or' then
      Exit(TMuValue.FromBoolean(LLeft.IsTruthy() or LRight.IsTruthy()));
  end;
end;

{ Main Entry Point }

function TMuInterpreter.Render(const AAST: TMuAST;
  const AEnv: TMuEnvironment;
  const ABuiltins: TMuBuiltins;
  const AComponents: TDictionary<string, TMuNodeIndex>): string;
begin
  FAST := AAST;
  FEnv := AEnv;
  FBuiltins := ABuiltins;
  FComponents := AComponents;
  FOutput.Clear();
  FIterationCount := 0;
  FRecursionDepth := 0;
  FIndentLevel := 0;
  FIncludeStack.Clear();
  FCallBodyNode := MU_NO_NODE;
  FCallBodyParam := '';

  FExprParser.SetErrors(FErrors);
  FPipes.SetErrors(FErrors);
  FPipes.SetBuiltins(FBuiltins);

  Status(RSInterpStatusStart);

  RenderNode(FAST.Root);

  Status(RSInterpStatusComplete, [FOutput.Length, FErrors.ErrorCount()]);

  Result := FOutput.ToString();

  // Free temporary lists/maps created by builtins during this render pass
  FBuiltins.FreeAllocations();
end;

procedure TMuInterpreter.SetCustomTags(
  const ATags: TDictionary<string, TMuTagHandler>);
begin
  FCustomTags := ATags;
end;

function TMuInterpreter.GetOutput(): TStringBuilder;
begin
  Result := FOutput;
end;

procedure TMuInterpreter.SetIncludeResolver(const AResolver: TMuIncludeResolver);
begin
  FIncludeResolver := AResolver;
end;

procedure TMuInterpreter.HandleInclude(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LFilename: string;
  LIncludeAST: TMuAST;
  LSavedAST: TMuAST;
  LHasAttrs: Boolean;
  LI: Integer;
  LAttr: TMuAttr;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // Get filename from node text or child content (same pattern as HandleGet)
  LFilename := LNode^.Text.Trim();
  if LFilename = '' then
    LFilename := NodeTextContent(AIndex).Trim();
  if LFilename = '' then
    Exit;

  if not Assigned(FIncludeResolver) then
  begin
    FErrors.Add('', LNode^.Line, LNode^.Col, esError,
      MU_ERROR_INTERP_INCLUDE_FAIL, RSInterpIncludeNotFound, [LFilename]);
    Exit;
  end;

  // Circular include detection
  if FIncludeStack.IndexOf(LFilename) >= 0 then
  begin
    FErrors.Add(esError, MU_ERROR_INTERP_CIRCULAR_INCLUDE,
      RSInterpCircularInclude, [LFilename]);
    Exit;
  end;

  Status(RSInterpIncludeResolving, [LFilename]);

  // Resolve and parse the include file
  LIncludeAST := FIncludeResolver(LFilename);
  if LIncludeAST = nil then
    Exit;

  // Track include for circular detection
  FIncludeStack.Add(LFilename);
  try
    // Bind include attributes as local variables in a new scope (spec §4.7)
    LHasAttrs := LNode^.AttrCount > 0;
    if LHasAttrs then
    begin
      FEnv.Push();
      for LI := 0 to LNode^.AttrCount - 1 do
      begin
        LAttr := FAST.GetAttr(AIndex, LI);
        FEnv.Bind(LAttr.AttrName,
          TMuValue.FromString(InterpolateAttrValue(LAttr.AttrValue)));
      end;
    end;

    try
      // Swap AST, render included content inline, restore
      LSavedAST := FAST;
      FAST := LIncludeAST;
      RenderChildren(LIncludeAST.Root);
      FAST := LSavedAST;
    finally
      if LHasAttrs then
        FEnv.Pop();
    end;
  finally
    FIncludeStack.Delete(FIncludeStack.Count - 1);
    FreeAndNil(LIncludeAST);
  end;
end;

end.
