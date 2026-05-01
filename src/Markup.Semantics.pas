{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Semantics;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markup.Utils,
  Markup.Resources,
  Markup.AST,
  Markup.ExprParser;

const
  MU_ERROR_SEM_ELSE_OUTSIDE_IF   = 'MS-S001';
  MU_ERROR_SEM_MISSING_CONDITION = 'MS-S002';
  MU_ERROR_SEM_MISSING_NAME      = 'MS-S003';
  MU_ERROR_SEM_MISSING_PATH      = 'MS-S004';
  MU_ERROR_SEM_INVALID_NESTING   = 'MS-S005';
  MU_ERROR_SEM_UNKNOWN_COMPONENT = 'MS-S006';
  MU_ERROR_SEM_DUPLICATE_DEF     = 'MS-S007';
  MU_ERROR_SEM_EXPR_INVALID      = 'MS-S008';
  MU_ERROR_SEM_VOID_HAS_CONTENT  = 'MS-S009';
  MU_ERROR_SEM_META_POSITION     = 'MS-S010';
  MU_ERROR_SEM_DEF_PARAM_ORDER   = 'MS-S011';

type
  { TMuSemanticPass }
  TMuSemanticPass = class(TMuBaseObject)
  private
    FAST: TMuAST;
    FComponents: TDictionary<string, TMuNodeIndex>;

    // Phase A — Structural validation
    procedure ValidateStructure(const AIndex: TMuNodeIndex;
      const AParentTag: string);
    procedure ValidateTag(const AIndex: TMuNodeIndex;
      const AParentTag: string);
    procedure ValidateExpressions(const AIndex: TMuNodeIndex);
    procedure ValidateVoidTags(const AIndex: TMuNodeIndex);
    procedure ValidateMetaPosition(const ARootIndex: TMuNodeIndex);
    procedure ValidateDefParams(const AIndex: TMuNodeIndex);

    // Phase B — Component registration
    procedure CollectDefs(const AIndex: TMuNodeIndex);
    procedure ValidateCalls(const AIndex: TMuNodeIndex);

    // Helpers
    function IsBlockTag(const ATagName: string): Boolean;
    function IsHeading(const ATagName: string): Boolean;
    function IsVoidTag(const ATagName: string): Boolean;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Analyze(const AAST: TMuAST);
    function GetComponents(): TDictionary<string, TMuNodeIndex>;
  end;

implementation

{ TMuSemanticPass }

constructor TMuSemanticPass.Create();
begin
  inherited;
  FComponents := TDictionary<string, TMuNodeIndex>.Create();
end;

destructor TMuSemanticPass.Destroy();
begin
  FreeAndNil(FComponents);
  inherited;
end;

function TMuSemanticPass.IsBlockTag(const ATagName: string): Boolean;
begin
  Result := (ATagName = 'table') or (ATagName = 'section') or
            (ATagName = 'grid') or (ATagName = 'list') or
            (ATagName = 'olist') or (ATagName = 'dlist') or
            (ATagName = 'form') or (ATagName = 'box') or
            (ATagName = 'article') or (ATagName = 'aside') or
            (ATagName = 'header') or (ATagName = 'footer') or
            (ATagName = 'nav') or (ATagName = 'main') or
            (ATagName = 'quote') or (ATagName = 'details') or
            (ATagName = 'fig') or (ATagName = 'columns') or
            (ATagName = 'card') or (ATagName = 'note') or
            (ATagName = 'tip') or (ATagName = 'warning') or
            (ATagName = 'danger');
end;

function TMuSemanticPass.IsHeading(const ATagName: string): Boolean;
begin
  Result := (ATagName = 'h1') or (ATagName = 'h2') or
            (ATagName = 'h3') or (ATagName = 'h4') or
            (ATagName = 'h5') or (ATagName = 'h6');
end;

function TMuSemanticPass.IsVoidTag(const ATagName: string): Boolean;
begin
  Result := (ATagName = 'line') or (ATagName = 'br') or
            (ATagName = 'img') or (ATagName = 'input') or
            (ATagName = 'meta');
end;

{ Phase A — Structural Validation }

procedure TMuSemanticPass.ValidateStructure(const AIndex: TMuNodeIndex;
  const AParentTag: string);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
begin
  if AIndex = MU_NO_NODE then
    Exit;
  if FErrors.ReachedMaxErrors() then
    Exit;

  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  if LNode^.Kind = nkTag then
    ValidateTag(AIndex, AParentTag);

  // Recurse into children
  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    if FErrors.ReachedMaxErrors() then
      Exit;
    ValidateStructure(LChild, LNode^.TagName);
    LChild := FAST.GetNode(LChild)^.NextSibling;
  end;
end;

procedure TMuSemanticPass.ValidateTag(const AIndex: TMuNodeIndex;
  const AParentTag: string);
var
  LNode: PMuNode;
  LTagName: string;
  LChild: TMuNodeIndex;
  LChildNode: PMuNode;
begin
  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  LTagName := LNode^.TagName;

  // {else}/{elseif} must only appear inside {if}
  if (LTagName = 'else') or (LTagName = 'elseif') then
  begin
    if AParentTag <> 'if' then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_ELSE_OUTSIDE_IF, RSSemElseOutsideIf, [LTagName]);
      Exit;
    end;
  end;

  // {if} must have at least one child (condition)
  if LTagName = 'if' then
  begin
    if LNode^.FirstChild = MU_NO_NODE then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_MISSING_CONDITION, RSSemMissingCondition, ['if']);
      Exit;
    end;
  end;

  // {each} must have content
  if LTagName = 'each' then
  begin
    if LNode^.FirstChild = MU_NO_NODE then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_MISSING_CONDITION, RSSemMissingCondition, ['each']);
      Exit;
    end;
  end;

  // {def} must have a name
  if LTagName = 'def' then
  begin
    if LNode^.Text = '' then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_MISSING_NAME, RSSemMissingName, ['def']);
      Exit;
    end;
  end;

  // {call} must have a name (in Text or first text child)
  if LTagName = 'call' then
  begin
    if (LNode^.Text = '') and (LNode^.FirstChild = MU_NO_NODE) then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_MISSING_NAME, RSSemMissingName, ['call']);
      Exit;
    end;
  end;

  // {let}/{set} must have a variable name
  if (LTagName = 'let') or (LTagName = 'set') then
  begin
    if LNode^.Text = '' then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_MISSING_NAME, RSSemMissingName, [LTagName]);
      Exit;
    end;
  end;

  // {get} must have a path
  if LTagName = 'get' then
  begin
    if (LNode^.Text = '') and (LNode^.FirstChild = MU_NO_NODE) then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_MISSING_PATH, RSSemMissingPath);
      Exit;
    end;
  end;

  // {include} must have a path
  if LTagName = 'include' then
  begin
    if (LNode^.Text = '') and (LNode^.FirstChild = MU_NO_NODE) and
       (LNode^.AttrCount = 0) then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esError,
        MU_ERROR_SEM_MISSING_PATH, RSSemMissingPath);
      Exit;
    end;
  end;

  // Headings must not contain block-level tags (spec §8.2)
  if IsHeading(LTagName) then
  begin
    LChild := LNode^.FirstChild;
    while LChild <> MU_NO_NODE do
    begin
      LChildNode := FAST.GetNode(LChild);
      if (LChildNode^.Kind = nkTag) and IsBlockTag(LChildNode^.TagName) then
      begin
        FErrors.Add('', LChildNode^.Line, LChildNode^.Col, esError,
          MU_ERROR_SEM_INVALID_NESTING, RSSemInvalidNesting,
          [LChildNode^.TagName, LTagName]);
        Exit;
      end;
      LChild := LChildNode^.NextSibling;
    end;
  end;
end;

procedure TMuSemanticPass.ValidateExpressions(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LExprParser: TMuExprParser;
  LErrorsBefore: Integer;
begin
  if AIndex = MU_NO_NODE then
    Exit;
  if FErrors.ReachedMaxErrors() then
    Exit;

  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // Validate interpolation expressions ({=expr} stored as tag "=")
  if (LNode^.Kind = nkTag) and (LNode^.TagName = '=') and
     (LNode^.Text <> '') then
  begin
    LErrorsBefore := FErrors.ErrorCount();
    LExprParser := TMuExprParser.Create();
    try
      LExprParser.SetErrors(FErrors);
      LExprParser.Parse(LNode^.Text);
      if FErrors.ErrorCount() > LErrorsBefore then
      begin
        FErrors.Add('', LNode^.Line, LNode^.Col, esError,
          MU_ERROR_SEM_EXPR_INVALID, RSSemExprInvalid,
          [LNode^.Text]);
        Exit;
      end;
    finally
      LExprParser.Free();
    end;
  end;

  // Recurse
  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    ValidateExpressions(LChild);
    LChild := FAST.GetNode(LChild)^.NextSibling;
  end;
end;

procedure TMuSemanticPass.ValidateVoidTags(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
begin
  if AIndex = MU_NO_NODE then
    Exit;
  if FErrors.ReachedMaxErrors() then
    Exit;

  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  if (LNode^.Kind = nkTag) and IsVoidTag(LNode^.TagName) and
     (LNode^.FirstChild <> MU_NO_NODE) then
  begin
    FErrors.Add('', LNode^.Line, LNode^.Col, esError,
      MU_ERROR_SEM_VOID_HAS_CONTENT, RSSemVoidHasContent,
      [LNode^.TagName]);
    Exit;
  end;

  // Recurse
  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    ValidateVoidTags(LChild);
    LChild := FAST.GetNode(LChild)^.NextSibling;
  end;
end;

procedure TMuSemanticPass.ValidateMetaPosition(
  const ARootIndex: TMuNodeIndex);
var
  LRoot: PMuNode;
  LChild: TMuNodeIndex;
  LChildNode: PMuNode;
  LSeenContent: Boolean;
begin
  LRoot := FAST.GetNode(ARootIndex);
  if LRoot = nil then
    Exit;

  LSeenContent := False;
  LChild := LRoot^.FirstChild;

  while LChild <> MU_NO_NODE do
  begin
    LChildNode := FAST.GetNode(LChild);

    if LChildNode^.Kind = nkTag then
    begin
      if LChildNode^.TagName = 'meta' then
      begin
        if LSeenContent then
        begin
          FErrors.Add('', LChildNode^.Line, LChildNode^.Col, esWarning,
            MU_ERROR_SEM_META_POSITION, RSSemMetaPosition);
        end;
      end
      else
        LSeenContent := True;
    end
    else if (LChildNode^.Kind = nkText) and (LChildNode^.Text.Trim() <> '') then
      LSeenContent := True;

    LChild := LChildNode^.NextSibling;
  end;
end;

procedure TMuSemanticPass.ValidateDefParams(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LI: Integer;
  LAttr: TMuAttr;
  LSeenOptional: Boolean;
begin
  if AIndex = MU_NO_NODE then
    Exit;
  if FErrors.ReachedMaxErrors() then
    Exit;

  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  // Check {def} parameter ordering: required before optional
  if (LNode^.Kind = nkTag) and (LNode^.TagName = 'def') and
     (LNode^.AttrCount > 0) then
  begin
    LSeenOptional := False;
    for LI := 0 to LNode^.AttrCount - 2 do  // skip last param (body/block content)
    begin
      LAttr := FAST.GetAttr(AIndex, LI);
      if LAttr.AttrValue <> '' then
        LSeenOptional := True
      else if LSeenOptional then
      begin
        FErrors.Add('', LNode^.Line, LNode^.Col, esError,
          MU_ERROR_SEM_DEF_PARAM_ORDER, RSSemDefParamOrder,
          [LAttr.AttrName, LNode^.Text]);
        Exit;
      end;
    end;
  end;

  // Recurse
  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    ValidateDefParams(LChild);
    LChild := FAST.GetNode(LChild)^.NextSibling;
  end;
end;

{ Phase C — Component Registration }

procedure TMuSemanticPass.CollectDefs(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
begin
  if AIndex = MU_NO_NODE then
    Exit;
  if FErrors.ReachedMaxErrors() then
    Exit;

  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  if (LNode^.Kind = nkTag) and (LNode^.TagName = 'def') and
     (LNode^.Text <> '') then
  begin
    if FComponents.ContainsKey(LNode^.Text) then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esWarning,
        MU_ERROR_SEM_DUPLICATE_DEF, RSSemDuplicateDef, [LNode^.Text]);
    end;
    FComponents.AddOrSetValue(LNode^.Text, AIndex);
  end;

  // Recurse into children
  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    CollectDefs(LChild);
    LChild := FAST.GetNode(LChild)^.NextSibling;
  end;
end;

procedure TMuSemanticPass.ValidateCalls(const AIndex: TMuNodeIndex);
var
  LNode: PMuNode;
  LChild: TMuNodeIndex;
  LCallName: string;
begin
  if AIndex = MU_NO_NODE then
    Exit;
  if FErrors.ReachedMaxErrors() then
    Exit;

  LNode := FAST.GetNode(AIndex);
  if LNode = nil then
    Exit;

  if (LNode^.Kind = nkTag) and (LNode^.TagName = 'call') then
  begin
    // Get component name from Text field (set by ParseCallBody)
    LCallName := LNode^.Text.Trim();

    if (LCallName <> '') and (not FComponents.ContainsKey(LCallName)) then
    begin
      FErrors.Add('', LNode^.Line, LNode^.Col, esWarning,
        MU_ERROR_SEM_UNKNOWN_COMPONENT, RSSemUnknownComponent, [LCallName]);
    end;
  end;

  // Recurse into children
  LChild := LNode^.FirstChild;
  while LChild <> MU_NO_NODE do
  begin
    ValidateCalls(LChild);
    LChild := FAST.GetNode(LChild)^.NextSibling;
  end;
end;

{ Main Entry Point }

procedure TMuSemanticPass.Analyze(const AAST: TMuAST);
begin
  FAST := AAST;
  FComponents.Clear();

  Status(RSSemStatusStart);

  // Phase A — Structural validation
  Status(RSSemPhaseA);
  ValidateStructure(FAST.Root, '');
  ValidateVoidTags(FAST.Root);
  ValidateMetaPosition(FAST.Root);
  ValidateDefParams(FAST.Root);
  ValidateExpressions(FAST.Root);
  if FErrors.HasErrors() then
  begin
    Status(RSSemStatusComplete, [FErrors.ErrorCount()]);
    Exit;
  end;

  // Phase B — Component registration
  Status(RSSemPhaseC);
  CollectDefs(FAST.Root);
  ValidateCalls(FAST.Root);

  Status(RSSemStatusComplete, [FErrors.ErrorCount()]);
end;

function TMuSemanticPass.GetComponents(): TDictionary<string, TMuNodeIndex>;
begin
  Result := FComponents;
end;

end.
