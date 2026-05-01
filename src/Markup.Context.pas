{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Context;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Markup.Utils,
  Markup.AST;

type
  { Forward declaration }
  TMuRenderContext = class;

  { TMuTagHandler - Callback for custom tag rendering }
  TMuTagHandler = reference to procedure(const ACtx: TMuRenderContext);

  { TMuChildRenderer - Callback to render children of a node }
  TMuChildRenderer = reference to procedure(const AParent: TMuNodeIndex);

  { TMuRenderContext - Context passed to custom tag handlers }
  TMuRenderContext = class(TMuBaseObject)
  private
    FAST: TMuAST;
    FNodeIndex: TMuNodeIndex;
    FOutput: TStringBuilder;
    FChildRenderer: TMuChildRenderer;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    procedure Init(const AAST: TMuAST;
      const ANodeIndex: TMuNodeIndex;
      const AOutput: TStringBuilder;
      const AChildRenderer: TMuChildRenderer);

    function TagName(): string;
    function Attr(const AAttrName: string): string;
    function HasAttr(const AAttrName: string): Boolean;
    procedure Emit(const AText: string);
    procedure EmitChildren();
  end;

implementation

{ TMuRenderContext }

constructor TMuRenderContext.Create();
begin
  inherited;
  FAST := nil;
  FNodeIndex := MU_NO_NODE;
  FOutput := nil;
  FChildRenderer := nil;
end;

destructor TMuRenderContext.Destroy();
begin
  inherited;
end;

procedure TMuRenderContext.Init(const AAST: TMuAST;
  const ANodeIndex: TMuNodeIndex;
  const AOutput: TStringBuilder;
  const AChildRenderer: TMuChildRenderer);
begin
  FAST := AAST;
  FNodeIndex := ANodeIndex;
  FOutput := AOutput;
  FChildRenderer := AChildRenderer;
end;

function TMuRenderContext.TagName(): string;
var
  LNode: PMuNode;
begin
  Result := '';
  if (FAST = nil) or (FNodeIndex = MU_NO_NODE) then
    Exit;
  LNode := FAST.GetNode(FNodeIndex);
  if LNode <> nil then
    Result := LNode^.TagName;
end;

function TMuRenderContext.Attr(const AAttrName: string): string;
begin
  Result := '';
  if (FAST = nil) or (FNodeIndex = MU_NO_NODE) then
    Exit;
  Result := FAST.GetAttrValue(FNodeIndex, AAttrName);
end;

function TMuRenderContext.HasAttr(const AAttrName: string): Boolean;
begin
  Result := False;
  if (FAST = nil) or (FNodeIndex = MU_NO_NODE) then
    Exit;
  Result := FAST.HasAttr(FNodeIndex, AAttrName);
end;

procedure TMuRenderContext.Emit(const AText: string);
begin
  if FOutput <> nil then
    FOutput.Append(AText);
end;

procedure TMuRenderContext.EmitChildren();
begin
  if Assigned(FChildRenderer) and (FNodeIndex <> MU_NO_NODE) then
    FChildRenderer(FNodeIndex);
end;

end.
