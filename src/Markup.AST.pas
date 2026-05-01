{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.AST;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  Markup.Utils;

type
  { TMuNodeKind }
  TMuNodeKind = (
    nkText,
    nkTag,
    nkComment,
    nkVerbatim
  );

  { TMuTrim }
  TMuTrim = (
    trimNone,
    trimLeft,
    trimRight,
    trimBoth
  );

  { TMuNodeIndex - Index into the node arena, -1 = none }
  TMuNodeIndex = Integer;

const
  MU_NO_NODE = -1;

type
  { TMuAttr - Key-value attribute record }
  TMuAttr = record
    AttrName: string;
    AttrValue: string;
  end;

  { PMuNode }
  PMuNode = ^TMuNode;

  { TMuNode - AST node record stored in flat arena }
  TMuNode = record
    Kind: TMuNodeKind;
    TagName: string;
    Text: string;
    Line: Integer;
    Col: Integer;
    Trim: TMuTrim;
    FirstChild: TMuNodeIndex;
    NextSibling: TMuNodeIndex;
    AttrStart: Integer;
    AttrCount: Integer;
  end;

  { TMuAST - Flat arena of nodes and attributes }
  TMuAST = class(TMuBaseObject)
  private
    FNodes: TList<TMuNode>;
    FAttrs: TList<TMuAttr>;
    FRoot: TMuNodeIndex;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // Node management
    function NewNode(const AKind: TMuNodeKind; const ALine: Integer;
      const ACol: Integer): TMuNodeIndex;
    function GetNode(const AIndex: TMuNodeIndex): PMuNode;
    procedure AddChild(const AParent: TMuNodeIndex;
      const AChild: TMuNodeIndex);

    // Attribute management
    function AddAttr(const AAttrName: string;
      const AAttrValue: string): Integer;
    function GetAttr(const ANode: TMuNodeIndex;
      const AAttrIndex: Integer): TMuAttr;
    function HasAttr(const ANode: TMuNodeIndex;
      const AAttrName: string): Boolean;
    function GetAttrValue(const ANode: TMuNodeIndex;
      const AAttrName: string; const ADefault: string = ''): string;

    // Traversal
    function ChildCount(const ANode: TMuNodeIndex): Integer;
    function GetChild(const ANode: TMuNodeIndex;
      const AChildIndex: Integer): TMuNodeIndex;

    // Properties
    function NodeCount(): Integer;
    function AttrCount(): Integer;
    property Root: TMuNodeIndex read FRoot write FRoot;
  end;

implementation

{ TMuAST }

constructor TMuAST.Create();
begin
  inherited;
  FNodes := TList<TMuNode>.Create();
  FAttrs := TList<TMuAttr>.Create();
  FRoot := MU_NO_NODE;
end;

destructor TMuAST.Destroy();
begin
  FreeAndNil(FAttrs);
  FreeAndNil(FNodes);
  inherited;
end;

function TMuAST.NewNode(const AKind: TMuNodeKind; const ALine: Integer;
  const ACol: Integer): TMuNodeIndex;
var
  LNode: TMuNode;
begin
  LNode.Kind := AKind;
  LNode.TagName := '';
  LNode.Text := '';
  LNode.Line := ALine;
  LNode.Col := ACol;
  LNode.Trim := trimNone;
  LNode.FirstChild := MU_NO_NODE;
  LNode.NextSibling := MU_NO_NODE;
  LNode.AttrStart := -1;
  LNode.AttrCount := 0;

  Result := FNodes.Count;
  FNodes.Add(LNode);
end;

function TMuAST.GetNode(const AIndex: TMuNodeIndex): PMuNode;
begin
  if (AIndex < 0) or (AIndex >= FNodes.Count) then
    Result := nil
  else
    Result := @FNodes.List[AIndex];
end;

procedure TMuAST.AddChild(const AParent: TMuNodeIndex;
  const AChild: TMuNodeIndex);
var
  LParentNode: PMuNode;
  LSibling: TMuNodeIndex;
begin
  LParentNode := GetNode(AParent);
  if LParentNode = nil then
    Exit;

  if LParentNode^.FirstChild = MU_NO_NODE then
  begin
    LParentNode^.FirstChild := AChild;
  end
  else
  begin
    // Walk to last sibling
    LSibling := LParentNode^.FirstChild;
    while FNodes.List[LSibling].NextSibling <> MU_NO_NODE do
      LSibling := FNodes.List[LSibling].NextSibling;
    FNodes.List[LSibling].NextSibling := AChild;
  end;
end;

function TMuAST.AddAttr(const AAttrName: string;
  const AAttrValue: string): Integer;
var
  LAttr: TMuAttr;
begin
  LAttr.AttrName := AAttrName;
  LAttr.AttrValue := AAttrValue;
  Result := FAttrs.Count;
  FAttrs.Add(LAttr);
end;

function TMuAST.GetAttr(const ANode: TMuNodeIndex;
  const AAttrIndex: Integer): TMuAttr;
var
  LNode: PMuNode;
  LAbsIndex: Integer;
begin
  LNode := GetNode(ANode);
  if LNode = nil then
  begin
    Result.AttrName := '';
    Result.AttrValue := '';
    Exit;
  end;

  LAbsIndex := LNode^.AttrStart + AAttrIndex;
  if (AAttrIndex < 0) or (AAttrIndex >= LNode^.AttrCount) or
     (LAbsIndex >= FAttrs.Count) then
  begin
    Result.AttrName := '';
    Result.AttrValue := '';
    Exit;
  end;

  Result := FAttrs[LAbsIndex];
end;

function TMuAST.HasAttr(const ANode: TMuNodeIndex;
  const AAttrName: string): Boolean;
var
  LNode: PMuNode;
  LI: Integer;
begin
  Result := False;
  LNode := GetNode(ANode);
  if LNode = nil then
    Exit;

  for LI := 0 to LNode^.AttrCount - 1 do
  begin
    if SameText(FAttrs[LNode^.AttrStart + LI].AttrName, AAttrName) then
      Exit(True);
  end;
end;

function TMuAST.GetAttrValue(const ANode: TMuNodeIndex;
  const AAttrName: string; const ADefault: string): string;
var
  LNode: PMuNode;
  LI: Integer;
begin
  Result := ADefault;
  LNode := GetNode(ANode);
  if LNode = nil then
    Exit;

  for LI := 0 to LNode^.AttrCount - 1 do
  begin
    if SameText(FAttrs[LNode^.AttrStart + LI].AttrName, AAttrName) then
      Exit(FAttrs[LNode^.AttrStart + LI].AttrValue);
  end;
end;

function TMuAST.ChildCount(const ANode: TMuNodeIndex): Integer;
var
  LSibling: TMuNodeIndex;
  LNode: PMuNode;
begin
  Result := 0;
  LNode := GetNode(ANode);
  if LNode = nil then
    Exit;

  LSibling := LNode^.FirstChild;
  while LSibling <> MU_NO_NODE do
  begin
    Inc(Result);
    LSibling := FNodes.List[LSibling].NextSibling;
  end;
end;

function TMuAST.GetChild(const ANode: TMuNodeIndex;
  const AChildIndex: Integer): TMuNodeIndex;
var
  LSibling: TMuNodeIndex;
  LNode: PMuNode;
  LI: Integer;
begin
  Result := MU_NO_NODE;
  LNode := GetNode(ANode);
  if LNode = nil then
    Exit;

  LSibling := LNode^.FirstChild;
  LI := 0;
  while LSibling <> MU_NO_NODE do
  begin
    if LI = AChildIndex then
      Exit(LSibling);
    Inc(LI);
    LSibling := FNodes.List[LSibling].NextSibling;
  end;
end;

function TMuAST.NodeCount(): Integer;
begin
  Result := FNodes.Count;
end;

function TMuAST.AttrCount(): Integer;
begin
  Result := FAttrs.Count;
end;

end.
