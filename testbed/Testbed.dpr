{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Markup.API in '..\src\Markup.API.pas',
  Markup.AST in '..\src\Markup.AST.pas',
  Markup.Builtins in '..\src\Markup.Builtins.pas',
  Markup.Config in '..\src\Markup.Config.pas',
  Markup.Context in '..\src\Markup.Context.pas',
  Markup.Engine in '..\src\Markup.Engine.pas',
  Markup.Environment in '..\src\Markup.Environment.pas',
  Markup.ExprParser in '..\src\Markup.ExprParser.pas',
  Markup.Interpreter in '..\src\Markup.Interpreter.pas',
  Markup.JSON in '..\src\Markup.JSON.pas',
  Markup.Lexer in '..\src\Markup.Lexer.pas',
  Markup.Options in '..\src\Markup.Options.pas',
  Markup.Parser in '..\src\Markup.Parser.pas',
  Markup.Pipes in '..\src\Markup.Pipes.pas',
  Markup.Resources in '..\src\Markup.Resources.pas',
  Markup.Semantics in '..\src\Markup.Semantics.pas',
  Markup.TestCase in '..\src\Markup.TestCase.pas',
  Markup.TOML in '..\src\Markup.TOML.pas',
  Markup.Utils in '..\src\Markup.Utils.pas',
  Markup.Value in '..\src\Markup.Value.pas',
  UTest.Demo in 'UTest.Demo.pas',
  UTestbed in 'UTestbed.pas',
  UTest.Demo.API in 'UTest.Demo.API.pas',
  UTest.Demo.Builtins in 'UTest.Demo.Builtins.pas',
  UTest.Demo.Extensibility in 'UTest.Demo.Extensibility.pas',
  UTest.Demo.Formatting in 'UTest.Demo.Formatting.pas',
  UTest.Demo.Logic in 'UTest.Demo.Logic.pas';

begin
  RunTestbed();
end.
