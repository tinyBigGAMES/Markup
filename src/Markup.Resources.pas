{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Resources;

{$I Markup.Defines.inc}

interface

resourcestring

  //--------------------------------------------------------------------------
  // Severity Names
  //--------------------------------------------------------------------------
  RSSeverityHint    = 'Hint';
  RSSeverityWarning = 'Warning';
  RSSeverityError   = 'Error';
  RSSeverityFatal   = 'Fatal';
  RSSeverityNote    = 'Note';
  RSSeverityUnknown = 'Unknown';

  //--------------------------------------------------------------------------
  // Error Format Strings
  //--------------------------------------------------------------------------
  RSErrorFormatSimple              = '%s %s: %s';
  RSErrorFormatWithLocation        = '%s: %s %s: %s';
  RSErrorFormatRelatedSimple       = '  %s: %s';
  RSErrorFormatRelatedWithLocation = '  %s: %s: %s';

  //--------------------------------------------------------------------------
  // Fatal / I/O Messages
  //--------------------------------------------------------------------------
  RSFatalFileNotFound  = 'File not found: ''%s''';
  RSFatalFileReadError = 'Cannot read file ''%s'': %s';
  RSFatalInternalError = 'Internal error: %s';

  //--------------------------------------------------------------------------
  // Lexer Messages
  //--------------------------------------------------------------------------
  RSLexerUnterminatedComment       = 'Unterminated comment starting at line %d, column %d';
  RSLexerUnterminatedInterpolation = 'Unterminated interpolation starting at line %d, column %d';
  RSLexerUnterminatedVerbatim      = 'Unterminated verbatim block';
  RSLexerUnterminatedAttrValue     = 'Unterminated quoted attribute value';
  RSLexerExpectedTagName           = 'Expected tag name after ''{''';
  RSLexerInvalidEscape             = 'Invalid escape sequence ''\%s'', treating ''\'' as literal';
  RSLexerEmptyInterpolation        = 'Empty interpolation expression';
  RSLexerEmptyAttrValue            = 'Empty attribute value after ''=''';
  RSLexerUnclosedBrace             = 'Unclosed ''{'' at end of input (%d unclosed)';
  RSLexerUnterminatedString        = 'Unterminated string starting at line %d, column %d';

  //--------------------------------------------------------------------------
  // Lexer Status Messages
  //--------------------------------------------------------------------------
  RSLexerStatusStart    = 'Tokenizing (%d chars)...';
  RSLexerStatusComplete = 'Tokenized %d tokens (%d errors)';

  //--------------------------------------------------------------------------
  // Parser Messages
  //--------------------------------------------------------------------------
  RSParserUnexpectedToken = 'Unexpected token at line %d, column %d';
  RSParserUnclosedTag     = 'Unclosed tag ''%s''';
  RSParserElseOutsideIf   = '{else}/{elseif} outside of {if}';
  RSParserMissingCondition = 'Missing condition for ''%s''';
  RSParserMissingBinding   = 'Missing binding name for {each}';
  RSParserMissingName      = 'Missing name for ''%s''';

  //--------------------------------------------------------------------------
  // Parser Status Messages
  //--------------------------------------------------------------------------
  RSParserStatusStart    = 'Parsing (%d tokens)...';
  RSParserStatusComplete = 'Parsed %d nodes (%d errors)';

  //--------------------------------------------------------------------------
  // Expression Parser Messages
  //--------------------------------------------------------------------------
  RSExprUnexpectedToken = 'Unexpected token in expression: ''%s''';
  RSExprUnclosedParen   = 'Unclosed parenthesis in expression';
  RSExprEmpty           = 'Empty expression';
  RSExprUnterminatedStr = 'Unterminated string in expression';

  //--------------------------------------------------------------------------
  // Expression Parser Status Messages
  //--------------------------------------------------------------------------
  RSExprStatusStart    = 'Evaluating expression (%d chars)...';
  RSExprStatusComplete = 'Expression evaluated (%d nodes, %d errors)';

  //--------------------------------------------------------------------------
  // Semantic Analysis Messages
  //--------------------------------------------------------------------------
  RSSemElseOutsideIf    = '{%s} found outside of {if}';
  RSSemMissingCondition  = 'Missing condition for {%s}';
  RSSemMissingName       = 'Missing name for {%s}';
  RSSemMissingPath       = 'Missing path for {get} or {include}';
  RSSemInvalidNesting    = '{%s} cannot be nested inside {%s}';
  RSSemUnknownComponent  = 'Unknown component ''%s'' in {call}';
  RSSemDuplicateDef      = 'Duplicate component definition ''%s''';
  RSSemExprInvalid       = 'Invalid expression: ''%s''';
  RSSemVoidHasContent    = 'Void tag {%s} must not have content';
  RSSemMetaPosition      = '{meta} must appear before content-producing tags';
  RSSemDefParamOrder     = 'Required parameter ''%s'' appears after optional parameter in {def %s}';

  //--------------------------------------------------------------------------
  // Semantic Analysis Status Messages
  //--------------------------------------------------------------------------
  RSSemStatusStart    = 'Analyzing...';
  RSSemPhaseA         = 'Validating structure...';
  RSSemPhaseC         = 'Registering components...';
  RSSemStatusComplete = 'Analysis complete (%d errors)';

  //--------------------------------------------------------------------------
  // Environment Messages
  //--------------------------------------------------------------------------
  RSEnvPopGlobal = 'Cannot pop the global scope';

  //--------------------------------------------------------------------------
  // Builtins Messages
  //--------------------------------------------------------------------------
  RSBuiltinUnknown  = 'Unknown function ''%s''';
  RSBuiltinArgCount = 'Function ''%s'' expects %d arguments, got %d';
  RSBuiltinType     = 'Type error in function ''%s'': %s';

  //--------------------------------------------------------------------------
  // Pipe Messages
  //--------------------------------------------------------------------------
  RSPipeUnknownFunc = 'Unknown pipe function ''%s''';

  //--------------------------------------------------------------------------
  // Interpreter Messages
  //--------------------------------------------------------------------------
  RSInterpIterationLimit = 'Maximum iteration limit exceeded';
  RSInterpRecursionLimit = 'Maximum recursion depth exceeded';
  RSInterpOutputLimit    = 'Maximum output size exceeded';
  RSInterpUnknownTag     = 'Unknown tag ''%s''';
  RSInterpDivZero        = 'Division by zero';
  RSInterpTypeError      = 'Type error: %s';
  RSInterpStrictUndefinedVar = 'Undefined variable ''%s'' (strict mode)';
  RSInterpStrictTypeError    = 'Type error in expression (strict mode): %s';
  RSInterpCircularInclude    = 'Circular include detected: ''%s''';

  //--------------------------------------------------------------------------
  // Interpreter Status Messages
  //--------------------------------------------------------------------------
  RSInterpStatusStart    = 'Rendering...';
  RSInterpStatusComplete = 'Rendered %d chars (%d errors)';
  RSInterpIncludeNotFound  = 'Include file not found: ''%s''';
  RSInterpIncludeResolving = 'Including ''%s''...';

  //--------------------------------------------------------------------------
  // JSON Messages
  //--------------------------------------------------------------------------
  RSJsonUnexpected   = 'Expected ''%s'' but found ''%s'' in JSON';
  RSJsonUnterminated = 'Unterminated string in JSON';

  //--------------------------------------------------------------------------
  // JSON Status Messages
  //--------------------------------------------------------------------------
  RSJsonStatusStart    = 'Parsing JSON (%d chars)...';
  RSJsonStatusComplete = 'JSON parsed (%d errors)';

  //--------------------------------------------------------------------------
  // Engine Messages
  //--------------------------------------------------------------------------
  RSEngineEmptySource  = 'Empty source';
  RSEngineRenderFailed = 'Render failed: no AST';
  RSEngineFileSaveFailed = 'Failed to save output to file: ''%s''';

  //--------------------------------------------------------------------------
  // Engine Status Messages
  //--------------------------------------------------------------------------
  RSEngineStatusConvert   = 'Converting...';
  RSEngineStatusSaveFile  = 'Saving to file...';
  RSEngineStatusComplete  = 'Complete (%d chars, %d errors)';

implementation

end.
