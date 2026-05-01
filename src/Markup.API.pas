{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.API;

{$I Markup.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Markup.Utils,
  Markup.Value,
  Markup.AST,
  Markup.Context,
  Markup.Engine,
  Markup.Builtins,
  Markup.JSON,
  Markup.Options;

type
  TMuApiTagHandler = procedure(const ACtx: Pointer;
    const AUserData: Pointer);
  TMuApiFuncHandler = function(const AArgCount: Integer;
    const AArgs: Pointer; const AUserData: Pointer): Pointer;
  TMuApiErrorHandler = procedure(const ASeverity: Integer;
    const ACode: PAnsiChar; const AMessage: PAnsiChar;
    const AUserData: Pointer);
  TMuApiStatusHandler = procedure(const AText: PAnsiChar;
    const AUserData: Pointer);

// Lifecycle
function  markup_create(): TMuEngine; exports markup_create;
procedure markup_destroy(const AEngine: TMuEngine); exports markup_destroy;
function  markup_version(): PAnsiChar; exports markup_version;
procedure markup_free(const APtr: PAnsiChar); exports markup_free;

// Parsing and rendering
function  markup_parse(const AEngine: TMuEngine;
  const ASource: PAnsiChar): TMuAST; exports markup_parse;
procedure markup_doc_destroy(const ADoc: TMuAST); exports markup_doc_destroy;
function  markup_render(const AEngine: TMuEngine;
  const ADoc: TMuAST;
  const AData: PAnsiChar): PAnsiChar; exports markup_render;
function  markup_convert(const AEngine: TMuEngine;
  const ASource: PAnsiChar;
  const AData: PAnsiChar): PAnsiChar; exports markup_convert;
function  markup_convert_to_file(const AEngine: TMuEngine;
  const ASource: PAnsiChar;
  const AData: PAnsiChar;
  const AFilename: PAnsiChar;
  const AOpenInBrowser: Boolean): Boolean; exports markup_convert_to_file;

// Validation and error reporting
function  markup_validate(const AEngine: TMuEngine;
  const ASource: PAnsiChar): PAnsiChar; exports markup_validate;
function  markup_last_errors(
  const AEngine: TMuEngine): PAnsiChar; exports markup_last_errors;

// Include paths
procedure markup_add_include_path(const AEngine: TMuEngine;
  const APath: PAnsiChar); exports markup_add_include_path;

// Options configuration
procedure markup_set_pretty_print(const AEngine: TMuEngine;
  const AEnabled: Boolean); exports markup_set_pretty_print;
procedure markup_set_strict_mode(const AEngine: TMuEngine;
  const AEnabled: Boolean); exports markup_set_strict_mode;
procedure markup_set_allow_html(const AEngine: TMuEngine;
  const AEnabled: Boolean); exports markup_set_allow_html;
procedure markup_set_unknown_tag_behavior(const AEngine: TMuEngine;
  const ABehavior: Integer); exports markup_set_unknown_tag_behavior;
procedure markup_set_max_iterations(const AEngine: TMuEngine;
  const AMax: Integer); exports markup_set_max_iterations;
procedure markup_set_max_recursion(const AEngine: TMuEngine;
  const AMax: Integer); exports markup_set_max_recursion;
procedure markup_set_max_output_size(const AEngine: TMuEngine;
  const AMax: Integer); exports markup_set_max_output_size;

// Custom tag extensibility
procedure markup_register_tag(const AEngine: TMuEngine;
  const ATagName: PAnsiChar; const AHandler: TMuApiTagHandler;
  const AUserData: Pointer); exports markup_register_tag;

function  markup_ctx_tag_name(
  const ACtx: TMuRenderContext): PAnsiChar; exports markup_ctx_tag_name;
function  markup_ctx_attr(const ACtx: TMuRenderContext;
  const AAttrName: PAnsiChar): PAnsiChar; exports markup_ctx_attr;
function  markup_ctx_has_attr(const ACtx: TMuRenderContext;
  const AAttrName: PAnsiChar): Boolean; exports markup_ctx_has_attr;
procedure markup_ctx_emit(const ACtx: TMuRenderContext;
  const AText: PAnsiChar); exports markup_ctx_emit;
procedure markup_ctx_emit_children(
  const ACtx: TMuRenderContext); exports markup_ctx_emit_children;

// Custom function extensibility
procedure markup_register_function(const AEngine: TMuEngine;
  const AFuncName: PAnsiChar; const AHandler: TMuApiFuncHandler;
  const AUserData: Pointer); exports markup_register_function;

// Function argument accessors
function  markup_arg_as_string(const AArgs: Pointer;
  const AIndex: Integer): PAnsiChar; exports markup_arg_as_string;
function  markup_arg_as_integer(const AArgs: Pointer;
  const AIndex: Integer): Int64; exports markup_arg_as_integer;
function  markup_arg_as_float(const AArgs: Pointer;
  const AIndex: Integer): Double; exports markup_arg_as_float;
function  markup_arg_as_boolean(const AArgs: Pointer;
  const AIndex: Integer): Boolean; exports markup_arg_as_boolean;
function  markup_arg_as_uint64(const AArgs: Pointer;
  const AIndex: Integer): UInt64; exports markup_arg_as_uint64;
function  markup_arg_count(
  const AArgs: Pointer): Integer; exports markup_arg_count;

// Function result constructors — return heap-allocated PMuValue
function  markup_result_string(
  const AValue: PAnsiChar): PMuValue; exports markup_result_string;
function  markup_result_integer(
  const AValue: Int64): PMuValue; exports markup_result_integer;
function  markup_result_float(
  const AValue: Double): PMuValue; exports markup_result_float;
function  markup_result_boolean(
  const AValue: Boolean): PMuValue; exports markup_result_boolean;
function  markup_result_uint64(
  const AValue: UInt64): PMuValue; exports markup_result_uint64;
function  markup_result_nil(): PMuValue; exports markup_result_nil;

// Error and status handler registration
procedure markup_set_error_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiErrorHandler;
  const AUserData: Pointer); exports markup_set_error_handler;
procedure markup_set_status_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiStatusHandler;
  const AUserData: Pointer); exports markup_set_status_handler;

implementation

var
  FVersionStr: UTF8String;

{ UTF-8 helpers }

function AllocUtf8(const AStr: string): PAnsiChar;
var
  LUtf8: UTF8String;
  LLen: Integer;
begin
  LUtf8 := UTF8String(AStr);
  LLen := Length(LUtf8);
  GetMem(Result, LLen + 1);
  if LLen > 0 then
    Move(LUtf8[1], Result^, LLen);
  Result[LLen] := #0;
end;

function Utf8ToStr(const APtr: PAnsiChar): string;
begin
  if APtr = nil then
    Result := ''
  else
    Result := string(UTF8String(APtr));
end;

{ Closure factories — capture by value to avoid capture-by-reference bug }

function MakeApiTagWrapper(const AHandler: TMuApiTagHandler;
  const AUserData: Pointer): TMuTagHandler;
begin
  Result :=
    procedure(const ACtx: TMuRenderContext)
    begin
      AHandler(Pointer(ACtx), AUserData);
    end;
end;

function MakeApiFuncWrapper(const AHandler: TMuApiFuncHandler;
  const AUserData: Pointer): TMuBuiltinFunc;
begin
  Result :=
    function(const AArgs: TArray<TMuValue>): TMuValue
    var
      LResultPtr: PMuValue;
    begin
      LResultPtr := PMuValue(AHandler(Length(AArgs), Pointer(@AArgs), AUserData));
      if LResultPtr = nil then
        Result := TMuValue.CreateNil()
      else
      begin
        Result := LResultPtr^;
        Dispose(LResultPtr);
      end;
    end;
end;

{ Error serialization }

function ErrorsToJson(const AEngine: TMuEngine): string;
var
  LErrors: TMuErrors;
  LItems: TList<TMuError>;
  LSB: TStringBuilder;
  LI: Integer;
  LErr: TMuError;
  LSev: string;
begin
  LErrors := AEngine.GetErrors();
  LItems := LErrors.GetItems();

  LSB := TStringBuilder.Create();
  try
    LSB.Append('[');
    for LI := 0 to LItems.Count - 1 do
    begin
      LErr := LItems[LI];
      if LI > 0 then
        LSB.Append(',');

      if LErr.Severity = esHint then
        LSev := 'hint'
      else if LErr.Severity = esWarning then
        LSev := 'warning'
      else if LErr.Severity = esError then
        LSev := 'error'
      else if LErr.Severity = esFatal then
        LSev := 'fatal'
      else
        LSev := 'unknown';

      LSB.Append('{"severity":"');
      LSB.Append(LSev);
      LSB.Append('","code":"');
      LSB.Append(LErr.Code);
      LSB.Append('","message":"');
      LSB.Append(StringReplace(
        StringReplace(LErr.Message, '\', '\\', [rfReplaceAll]),
        '"', '\"', [rfReplaceAll]));
      LSB.Append('"}');
    end;
    LSB.Append(']');
    Result := LSB.ToString();
  finally
    FreeAndNil(LSB);
  end;
end;

{ Lifecycle }

function markup_create(): TMuEngine;
begin
  Result := TMuEngine.Create();
end;

procedure markup_destroy(const AEngine: TMuEngine);
begin
  if AEngine <> nil then
    AEngine.Free();
end;

function markup_version(): PAnsiChar;
begin
  Result := PAnsiChar(FVersionStr);
end;

procedure markup_free(const APtr: PAnsiChar);
begin
  if APtr <> nil then
    FreeMem(Pointer(APtr));
end;

{ Parsing and rendering }

function markup_parse(const AEngine: TMuEngine;
  const ASource: PAnsiChar): TMuAST;
begin
  Result := AEngine.Parse(Utf8ToStr(ASource));
end;

procedure markup_doc_destroy(const ADoc: TMuAST);
begin
  if ADoc <> nil then
    ADoc.Free();
end;

function markup_render(const AEngine: TMuEngine;
  const ADoc: TMuAST; const AData: PAnsiChar): PAnsiChar;
var
  LDataStr: string;
  LDataVal: TMuValue;
  LDataMap: TMuMap;
  LResult: string;
  LJson: TMuJSON;
begin
  LDataStr := Utf8ToStr(AData);
  if LDataStr = '' then
  begin
    Result := AllocUtf8(AEngine.Render(ADoc));
    Exit;
  end;

  LJson := AEngine.GetJSON();
  LDataVal := LJson.Parse(LDataStr);
  LDataMap := nil;
  try
    if LDataVal.Kind = vkMap then
    begin
      LDataMap := LDataVal.AsMap();
      LResult := AEngine.Render(ADoc, LDataMap);
    end
    else
      LResult := AEngine.Render(ADoc);

    Result := AllocUtf8(LResult);
  finally
    FreeAndNil(LDataMap);
  end;
end;

function markup_convert(const AEngine: TMuEngine;
  const ASource: PAnsiChar; const AData: PAnsiChar): PAnsiChar;
var
  LDataStr: string;
  LDataVal: TMuValue;
  LDataMap: TMuMap;
  LResult: string;
  LJson: TMuJSON;
begin
  LDataStr := Utf8ToStr(AData);
  if LDataStr = '' then
  begin
    Result := AllocUtf8(AEngine.Convert(Utf8ToStr(ASource)));
    Exit;
  end;

  LJson := AEngine.GetJSON();
  LDataVal := LJson.Parse(LDataStr);
  LDataMap := nil;
  try
    if LDataVal.Kind = vkMap then
    begin
      LDataMap := LDataVal.AsMap();
      LResult := AEngine.Convert(Utf8ToStr(ASource), LDataMap);
    end
    else
      LResult := AEngine.Convert(Utf8ToStr(ASource));

    Result := AllocUtf8(LResult);
  finally
    FreeAndNil(LDataMap);
  end;
end;

function markup_convert_to_file(const AEngine: TMuEngine;
  const ASource: PAnsiChar;
  const AData: PAnsiChar;
  const AFilename: PAnsiChar;
  const AOpenInBrowser: Boolean): Boolean;
begin
  Result := AEngine.ConvertToFile(
    Utf8ToStr(ASource),
    Utf8ToStr(AFilename),
    Utf8ToStr(AData),
    AOpenInBrowser);
end;

{ Validation and error reporting }

function markup_validate(const AEngine: TMuEngine;
  const ASource: PAnsiChar): PAnsiChar;
var
  LDoc: TMuAST;
begin
  AEngine.GetErrors().Clear();
  LDoc := AEngine.Parse(Utf8ToStr(ASource));
  try
    Result := AllocUtf8(ErrorsToJson(AEngine));
  finally
    FreeAndNil(LDoc);
  end;
end;

function markup_last_errors(const AEngine: TMuEngine): PAnsiChar;
begin
  Result := AllocUtf8(ErrorsToJson(AEngine));
end;

{ Include paths }

procedure markup_add_include_path(const AEngine: TMuEngine;
  const APath: PAnsiChar);
begin
  AEngine.AddIncludePath(Utf8ToStr(APath));
end;

{ Options configuration }

procedure markup_set_pretty_print(const AEngine: TMuEngine;
  const AEnabled: Boolean);
var
  LOpts: TMuOptions;
begin
  LOpts := AEngine.GetOptions();
  LOpts.PrettyPrint := AEnabled;
  AEngine.SetOptions(LOpts);
end;

procedure markup_set_strict_mode(const AEngine: TMuEngine;
  const AEnabled: Boolean);
var
  LOpts: TMuOptions;
begin
  LOpts := AEngine.GetOptions();
  LOpts.StrictMode := AEnabled;
  AEngine.SetOptions(LOpts);
end;

procedure markup_set_allow_html(const AEngine: TMuEngine;
  const AEnabled: Boolean);
var
  LOpts: TMuOptions;
begin
  LOpts := AEngine.GetOptions();
  LOpts.AllowHTML := AEnabled;
  AEngine.SetOptions(LOpts);
end;

procedure markup_set_unknown_tag_behavior(const AEngine: TMuEngine;
  const ABehavior: Integer);
var
  LOpts: TMuOptions;
begin
  LOpts := AEngine.GetOptions();
  LOpts.UnknownTagBehavior := TMuUnknownTagBehavior(ABehavior);
  AEngine.SetOptions(LOpts);
end;

procedure markup_set_max_iterations(const AEngine: TMuEngine;
  const AMax: Integer);
var
  LOpts: TMuOptions;
begin
  LOpts := AEngine.GetOptions();
  LOpts.MaxIterations := AMax;
  AEngine.SetOptions(LOpts);
end;

procedure markup_set_max_recursion(const AEngine: TMuEngine;
  const AMax: Integer);
var
  LOpts: TMuOptions;
begin
  LOpts := AEngine.GetOptions();
  LOpts.MaxRecursionDepth := AMax;
  AEngine.SetOptions(LOpts);
end;

procedure markup_set_max_output_size(const AEngine: TMuEngine;
  const AMax: Integer);
var
  LOpts: TMuOptions;
begin
  LOpts := AEngine.GetOptions();
  LOpts.MaxOutputSize := AMax;
  AEngine.SetOptions(LOpts);
end;

{ Custom tag extensibility }

procedure markup_register_tag(const AEngine: TMuEngine;
  const ATagName: PAnsiChar; const AHandler: TMuApiTagHandler;
  const AUserData: Pointer);
begin
  AEngine.RegisterTag(Utf8ToStr(ATagName),
    MakeApiTagWrapper(AHandler, AUserData));
end;

function markup_ctx_tag_name(const ACtx: TMuRenderContext): PAnsiChar;
begin
  Result := AllocUtf8(ACtx.TagName());
end;

function markup_ctx_attr(const ACtx: TMuRenderContext;
  const AAttrName: PAnsiChar): PAnsiChar;
begin
  Result := AllocUtf8(ACtx.Attr(Utf8ToStr(AAttrName)));
end;

function markup_ctx_has_attr(const ACtx: TMuRenderContext;
  const AAttrName: PAnsiChar): Boolean;
begin
  Result := ACtx.HasAttr(Utf8ToStr(AAttrName));
end;

procedure markup_ctx_emit(const ACtx: TMuRenderContext;
  const AText: PAnsiChar);
begin
  ACtx.Emit(Utf8ToStr(AText));
end;

procedure markup_ctx_emit_children(const ACtx: TMuRenderContext);
begin
  ACtx.EmitChildren();
end;

{ Custom function extensibility }

procedure markup_register_function(const AEngine: TMuEngine;
  const AFuncName: PAnsiChar; const AHandler: TMuApiFuncHandler;
  const AUserData: Pointer);
begin
  AEngine.RegisterFunction(Utf8ToStr(AFuncName),
    MakeApiFuncWrapper(AHandler, AUserData));
end;

{ Function argument accessors }

function markup_arg_count(const AArgs: Pointer): Integer;
var
  LArgsPtr: ^TArray<TMuValue>;
begin
  if AArgs = nil then
  begin
    Result := 0;
    Exit;
  end;
  LArgsPtr := AArgs;
  Result := Length(LArgsPtr^);
end;

function markup_arg_as_string(const AArgs: Pointer;
  const AIndex: Integer): PAnsiChar;
var
  LArgsPtr: ^TArray<TMuValue>;
begin
  if AArgs = nil then
  begin
    Result := AllocUtf8('');
    Exit;
  end;
  LArgsPtr := AArgs;
  if (AIndex < 0) or (AIndex >= Length(LArgsPtr^)) then
  begin
    Result := AllocUtf8('');
    Exit;
  end;
  Result := AllocUtf8(LArgsPtr^[AIndex].AsString());
end;

function markup_arg_as_integer(const AArgs: Pointer;
  const AIndex: Integer): Int64;
var
  LArgsPtr: ^TArray<TMuValue>;
begin
  if AArgs = nil then
  begin
    Result := 0;
    Exit;
  end;
  LArgsPtr := AArgs;
  if (AIndex < 0) or (AIndex >= Length(LArgsPtr^)) then
  begin
    Result := 0;
    Exit;
  end;
  Result := LArgsPtr^[AIndex].AsInteger();
end;

function markup_arg_as_float(const AArgs: Pointer;
  const AIndex: Integer): Double;
var
  LArgsPtr: ^TArray<TMuValue>;
begin
  if AArgs = nil then
  begin
    Result := 0.0;
    Exit;
  end;
  LArgsPtr := AArgs;
  if (AIndex < 0) or (AIndex >= Length(LArgsPtr^)) then
  begin
    Result := 0.0;
    Exit;
  end;
  Result := LArgsPtr^[AIndex].AsFloat();
end;

function markup_arg_as_boolean(const AArgs: Pointer;
  const AIndex: Integer): Boolean;
var
  LArgsPtr: ^TArray<TMuValue>;
begin
  if AArgs = nil then
  begin
    Result := False;
    Exit;
  end;
  LArgsPtr := AArgs;
  if (AIndex < 0) or (AIndex >= Length(LArgsPtr^)) then
  begin
    Result := False;
    Exit;
  end;
  Result := LArgsPtr^[AIndex].AsBoolean();
end;

function markup_arg_as_uint64(const AArgs: Pointer;
  const AIndex: Integer): UInt64;
var
  LArgsPtr: ^TArray<TMuValue>;
begin
  if AArgs = nil then
  begin
    Result := 0;
    Exit;
  end;
  LArgsPtr := AArgs;
  if (AIndex < 0) or (AIndex >= Length(LArgsPtr^)) then
  begin
    Result := 0;
    Exit;
  end;
  Result := LArgsPtr^[AIndex].AsUInt64();
end;

{ Function result constructors — heap-allocate, caller (engine) disposes }

function markup_result_string(const AValue: PAnsiChar): PMuValue;
begin
  New(Result);
  Result^ := TMuValue.FromString(Utf8ToStr(AValue));
end;

function markup_result_integer(const AValue: Int64): PMuValue;
begin
  New(Result);
  Result^ := TMuValue.FromInteger(AValue);
end;

function markup_result_float(const AValue: Double): PMuValue;
begin
  New(Result);
  Result^ := TMuValue.FromFloat(AValue);
end;

function markup_result_boolean(const AValue: Boolean): PMuValue;
begin
  New(Result);
  Result^ := TMuValue.FromBoolean(AValue);
end;

function markup_result_uint64(const AValue: UInt64): PMuValue;
begin
  New(Result);
  Result^ := TMuValue.FromUInt64(AValue);
end;

function markup_result_nil(): PMuValue;
begin
  New(Result);
  Result^ := TMuValue.CreateNil();
end;

{ Error and status handler registration }

procedure markup_set_error_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiErrorHandler; const AUserData: Pointer);
begin
  if not Assigned(AHandler) then
  begin
    AEngine.OnError := nil;
    Exit;
  end;

  AEngine.OnError :=
    procedure(const AError: TMuError)
    var
      LUtf8Code: UTF8String;
      LUtf8Msg: UTF8String;
    begin
      LUtf8Code := UTF8String(AError.Code);
      LUtf8Msg := UTF8String(AError.Message);
      AHandler(Ord(AError.Severity),
        PAnsiChar(LUtf8Code), PAnsiChar(LUtf8Msg), AUserData);
    end;
end;

procedure markup_set_status_handler(const AEngine: TMuEngine;
  const AHandler: TMuApiStatusHandler; const AUserData: Pointer);
begin
  if not Assigned(AHandler) then
  begin
    AEngine.SetStatusCallback(nil);
    Exit;
  end;

  AEngine.SetStatusCallback(
    procedure(const AText: string; const AInternalUserData: Pointer)
    var
      LUtf8: UTF8String;
    begin
      LUtf8 := UTF8String(AText);
      AHandler(PAnsiChar(LUtf8), AUserData);
    end,
    AUserData);
end;

initialization
  FVersionStr := UTF8String(TMuUtils.GetModuleVersionString(HInstance));

end.
