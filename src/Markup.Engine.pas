{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Engine;

{$I Markup.Defines.inc}

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  Winapi.ShellAPI,
  Markup.Utils,
  Markup.Resources,
  Markup.Value,
  Markup.AST,
  Markup.Context,
  Markup.Lexer,
  Markup.Parser,
  Markup.ExprParser,
  Markup.Semantics,
  Markup.Environment,
  Markup.Builtins,
  Markup.Pipes,
  Markup.Interpreter,
  Markup.Options,
  Markup.JSON;

const
  MU_ERROR_ENGINE_EMPTY_SOURCE = 'MS-G001';
  MU_ERROR_ENGINE_PARSE_FAILED = 'MS-G002';
  MU_ERROR_ENGINE_RENDER_FAILED = 'MS-G003';
  MU_ERROR_ENGINE_FILE_SAVE     = 'MS-G004';

type
  { TMuErrorHandler - Callback for real-time error reporting }
  TMuErrorHandler = reference to procedure(const AError: TMuError);

  { TMuEngine }
  TMuEngine = class(TMuBaseObject)
  private
    FLexer: TMuLexer;
    FParser: TMuParser;
    FSemantics: TMuSemanticPass;
    FInterpreter: TMuInterpreter;
    FEnvironment: TMuEnvironment;
    FBuiltins: TMuBuiltins;
    FJson: TMuJSON;
    FOptions: TMuOptions;
    FLastAST: TMuAST;
    FCustomTags: TDictionary<string, TMuTagHandler>;
    FIncludePaths: TStringList;
    FOnError: TMuErrorHandler;

    procedure ApplyOptions();
    procedure WireErrors();
    procedure ResetState();
    function ResolveIncludePath(const AFilename: string): string;

    // Internal parse pipeline — stores result in FLastAST
    function InternalParse(const ASource: string): TMuAST;

    // Internal render — shared by all render paths
    function InternalRender(const AAST: TMuAST;
      const ADataMap: TMuMap): string;

  public
    constructor Create(); override;
    destructor Destroy(); override;

    // One-shot: source + optional JSON data → HTML
    function Convert(const ASource: string;
      const AData: string = ''): string; overload;
    function Convert(const ASource: string;
      const ADataMap: TMuMap): string; overload;

    // One-shot: source + optional JSON data → HTML file, optionally open
    function ConvertToFile(const ASource: string;
      const AFilename: string;
      const AData: string = '';
      const AOpenInBrowser: Boolean = False): Boolean;

    // Two-step: parse returns caller-owned AST
    function Parse(const ASource: string): TMuAST;

    // Render a parsed AST
    function Render(const AAST: TMuAST): string; overload;
    function Render(const AAST: TMuAST;
      const ADataMap: TMuMap): string; overload;

    // Legacy two-step (kept for backward compat)
    function ParseSource(const ASource: string): TMuAST;
    function RenderAST(const AAST: TMuAST;
      const AData: string = ''): string;

    // Registration
    procedure RegisterFunction(const AName: string;
      const AFunc: TMuBuiltinFunc);
    procedure RegisterTag(const ATagName: string;
      const AHandler: TMuTagHandler);

    // Include paths
    procedure AddIncludePath(const APath: string);

    // Configuration
    procedure SetOptions(const AOptions: TMuOptions);
    function GetOptions(): TMuOptions;
    procedure SetStatusCallback(const ACallback: TMuStatusCallback; const AUserData: Pointer = nil); override;

    // Access
    function GetEnvironment(): TMuEnvironment;
    function GetBuiltins(): TMuBuiltins;
    function GetJSON(): TMuJSON;
    function GetLastAST(): TMuAST;
    function GetCustomTags(): TDictionary<string, TMuTagHandler>;

    // Error callback
    property OnError: TMuErrorHandler read FOnError write FOnError;
  end;

implementation

{ TMuEngine }

constructor TMuEngine.Create();
begin
  inherited;
  FLexer := TMuLexer.Create();
  FParser := TMuParser.Create();
  FSemantics := TMuSemanticPass.Create();
  FInterpreter := TMuInterpreter.Create();
  FEnvironment := TMuEnvironment.Create();
  FBuiltins := TMuBuiltins.Create();
  FJson := TMuJSON.Create();
  FOptions := TMuOptions.Defaults();
  FLastAST := nil;
  FCustomTags := TDictionary<string, TMuTagHandler>.Create();
  FIncludePaths := TStringList.Create();
  FOnError := nil;

  WireErrors();
  ApplyOptions();
end;

destructor TMuEngine.Destroy();
begin
  FreeAndNil(FIncludePaths);
  FreeAndNil(FCustomTags);
  FreeAndNil(FLastAST);
  FreeAndNil(FJson);
  FreeAndNil(FBuiltins);
  FreeAndNil(FEnvironment);
  FreeAndNil(FInterpreter);
  FreeAndNil(FSemantics);
  FreeAndNil(FParser);
  FreeAndNil(FLexer);
  inherited;
end;

procedure TMuEngine.WireErrors();
begin
  FLexer.SetErrors(FErrors);
  FParser.SetErrors(FErrors);
  FSemantics.SetErrors(FErrors);
  FInterpreter.SetErrors(FErrors);
  FEnvironment.SetErrors(FErrors);
  FBuiltins.SetErrors(FErrors);
  FJson.SetErrors(FErrors);

  // Forward error notifications to the API error handler
  FErrors.OnAdd :=
    procedure(const AError: TMuError)
    begin
      if Assigned(FOnError) then
        FOnError(AError);
    end;
end;

procedure TMuEngine.SetStatusCallback(const ACallback: TMuStatusCallback; const AUserData: Pointer);
begin
  inherited SetStatusCallback(ACallback, AUserData);
  FLexer.SetStatusCallback(ACallback, AUserData);
  FParser.SetStatusCallback(ACallback, AUserData);
  FSemantics.SetStatusCallback(ACallback, AUserData);
  FInterpreter.SetStatusCallback(ACallback, AUserData);
  FBuiltins.SetStatusCallback(ACallback, AUserData);
  FJson.SetStatusCallback(ACallback, AUserData);
end;

procedure TMuEngine.ApplyOptions();
begin
  FInterpreter.MaxIterations := FOptions.MaxIterations;
  FInterpreter.MaxRecursionDepth := FOptions.MaxRecursionDepth;
  FInterpreter.MaxOutputSize := FOptions.MaxOutputSize;
  FInterpreter.PrettyPrint := FOptions.PrettyPrint;
  FInterpreter.StrictMode := FOptions.StrictMode;
  FInterpreter.AllowHTML := FOptions.AllowHTML;
  FInterpreter.UnknownTagBehavior := FOptions.UnknownTagBehavior;
end;

procedure TMuEngine.ResetState();
begin
  FErrors.Clear();
  FEnvironment.Clear();
  FreeAndNil(FLastAST);
end;

function TMuEngine.ResolveIncludePath(const AFilename: string): string;
var
  I: Integer;
  LPath: string;
begin
  // Check absolute path
  if TPath.IsPathRooted(AFilename) and TFile.Exists(AFilename) then
    Exit(AFilename);

  // Search registered include paths
  for I := 0 to FIncludePaths.Count - 1 do
  begin
    LPath := TPath.Combine(FIncludePaths[I], AFilename);
    if TFile.Exists(LPath) then
      Exit(LPath);
  end;

  Result := '';
end;

function TMuEngine.InternalParse(const ASource: string): TMuAST;
var
  LTokens: TArray<TMuToken>;
  LAST: TMuAST;
begin
  Result := nil;

  if ASource = '' then
  begin
    FErrors.Add(esError, MU_ERROR_ENGINE_EMPTY_SOURCE,
      RSEngineEmptySource);
    Exit;
  end;

  // Lexer
  LTokens := FLexer.Tokenize(ASource);
  if FErrors.HasErrors() then
    Exit;

  // Parser
  LAST := FParser.Parse(LTokens);
  if FErrors.HasErrors() then
  begin
    FreeAndNil(LAST);
    Exit;
  end;

  // Semantics
  FSemantics.Analyze(LAST);
  if FErrors.HasErrors() then
  begin
    FreeAndNil(LAST);
    Exit;
  end;

  Result := LAST;
end;

function TMuEngine.InternalRender(const AAST: TMuAST;
  const ADataMap: TMuMap): string;
var
  LComponents: TDictionary<string, TMuNodeIndex>;
begin
  Result := '';

  if AAST = nil then
  begin
    FErrors.Add(esError, MU_ERROR_ENGINE_RENDER_FAILED,
      RSEngineRenderFailed);
    Exit;
  end;

  // Bind external data map if provided
  if ADataMap <> nil then
    FEnvironment.Bind('data', TMuValue.FromMap(ADataMap));

  // Get component map from semantics
  LComponents := FSemantics.GetComponents();

  // Wire custom tags to interpreter
  FInterpreter.SetCustomTags(FCustomTags);

  // Wire include resolver — lex + parse included files on demand
  FInterpreter.SetIncludeResolver(
    function(const AFilename: string): TMuAST
    var
      LPath: string;
      LSource: string;
      LTokens: TArray<TMuToken>;
    begin
      Result := nil;
      LPath := ResolveIncludePath(AFilename);
      if LPath = '' then
      begin
        FErrors.Add(esError, MU_ERROR_INTERP_INCLUDE_FAIL,
          RSInterpIncludeNotFound, [AFilename]);
        Exit;
      end;
      LSource := TFile.ReadAllText(LPath, TEncoding.UTF8);
      LTokens := FLexer.Tokenize(LSource);
      if FErrors.HasErrors() then
        Exit;
      Result := FParser.Parse(LTokens);
    end
  );

  // Render
  ApplyOptions();
  Result := FInterpreter.Render(AAST, FEnvironment, FBuiltins, LComponents);

  Status(RSEngineStatusComplete, [Length(Result), FErrors.ErrorCount()]);
end;

{ Public methods — new API }

function TMuEngine.Parse(const ASource: string): TMuAST;
begin
  // Clear errors and environment, then parse
  FErrors.Clear();
  FEnvironment.Clear();
  Result := InternalParse(ASource);
  // Caller owns the returned AST
end;

function TMuEngine.Render(const AAST: TMuAST): string;
begin
  FEnvironment.Clear();
  Result := InternalRender(AAST, nil);
end;

function TMuEngine.Render(const AAST: TMuAST;
  const ADataMap: TMuMap): string;
begin
  FEnvironment.Clear();
  Result := InternalRender(AAST, ADataMap);
end;

function TMuEngine.Convert(const ASource: string;
  const AData: string): string;
var
  LAST: TMuAST;
  LDataValue: TMuValue;
  LDataMap: TMuMap;
begin
  Result := '';
  Status(RSEngineStatusConvert);

  ResetState();
  LAST := InternalParse(ASource);
  if (LAST = nil) or FErrors.HasErrors() then
    Exit;

  FLastAST := LAST;

  // Parse JSON data if provided
  LDataMap := nil;
  try
    if AData <> '' then
    begin
      LDataValue := FJson.Parse(AData);
      if FErrors.HasErrors() then
        Exit;
      if LDataValue.Kind = vkMap then
        LDataMap := LDataValue.AsMap();
    end;

    Result := InternalRender(LAST, LDataMap);
  finally
    FreeAndNil(LDataMap);
  end;
end;

function TMuEngine.Convert(const ASource: string;
  const ADataMap: TMuMap): string;
var
  LAST: TMuAST;
begin
  Result := '';
  Status(RSEngineStatusConvert);

  ResetState();
  LAST := InternalParse(ASource);
  if (LAST = nil) or FErrors.HasErrors() then
    Exit;

  FLastAST := LAST;
  Result := InternalRender(LAST, ADataMap);
end;

function TMuEngine.ConvertToFile(const ASource: string;
  const AFilename: string;
  const AData: string;
  const AOpenInBrowser: Boolean): Boolean;
var
  LHtml: string;
  LFilename: string;
begin
  Result := False;

  LHtml := Convert(ASource, AData);
  if FErrors.HasErrors() then
    Exit;

  Status(RSEngineStatusSaveFile);

  // Force .html extension and ensure output directory exists
  LFilename := TPath.ChangeExtension(AFilename, '.html');
  TMuUtils.CreateDirInPath(LFilename);

  try
    TFile.WriteAllText(LFilename, LHtml, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      FErrors.Add(esError, MU_ERROR_ENGINE_FILE_SAVE,
        Format(RSEngineFileSaveFailed, [LFilename]));
      Exit;
    end;
  end;

  if AOpenInBrowser then
    ShellExecute(0, 'open', PChar(LFilename), nil, nil, SW_SHOWNORMAL);

  Result := True;
end;

{ Legacy two-step methods — backward compat }

function TMuEngine.ParseSource(const ASource: string): TMuAST;
begin
  ResetState();
  FLastAST := InternalParse(ASource);
  Result := FLastAST;
end;

function TMuEngine.RenderAST(const AAST: TMuAST;
  const AData: string): string;
var
  LDataValue: TMuValue;
  LDataMap: TMuMap;
begin
  LDataMap := nil;
  try
    if AData <> '' then
    begin
      LDataValue := FJson.Parse(AData);
      if FErrors.HasErrors() then
      begin
        Result := '';
        Exit;
      end;
      if LDataValue.Kind = vkMap then
        LDataMap := LDataValue.AsMap();
    end;

    Result := InternalRender(AAST, LDataMap);
  finally
    FreeAndNil(LDataMap);
  end;
end;

{ Registration }

procedure TMuEngine.RegisterFunction(const AName: string;
  const AFunc: TMuBuiltinFunc);
begin
  FBuiltins.RegisterFunc(AName, AFunc);
end;

procedure TMuEngine.RegisterTag(const ATagName: string;
  const AHandler: TMuTagHandler);
begin
  FCustomTags.AddOrSetValue(LowerCase(ATagName), AHandler);
end;

{ Include paths }

procedure TMuEngine.AddIncludePath(const APath: string);
begin
  if FIncludePaths.IndexOf(APath) < 0 then
    FIncludePaths.Add(APath);
end;

{ Configuration }

procedure TMuEngine.SetOptions(const AOptions: TMuOptions);
begin
  FOptions := AOptions;
  ApplyOptions();
end;

function TMuEngine.GetOptions(): TMuOptions;
begin
  Result := FOptions;
end;

{ Access }

function TMuEngine.GetEnvironment(): TMuEnvironment;
begin
  Result := FEnvironment;
end;

function TMuEngine.GetBuiltins(): TMuBuiltins;
begin
  Result := FBuiltins;
end;

function TMuEngine.GetJSON(): TMuJSON;
begin
  Result := FJson;
end;

function TMuEngine.GetLastAST(): TMuAST;
begin
  Result := FLastAST;
end;

function TMuEngine.GetCustomTags(): TDictionary<string, TMuTagHandler>;
begin
  Result := FCustomTags;
end;

end.
