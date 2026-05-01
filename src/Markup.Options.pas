{===============================================================================
  Markup™ - Document Authoring Language

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit Markup.Options;

{$I Markup.Defines.inc}

interface

type
  { TMuUnknownTagBehavior }
  TMuUnknownTagBehavior = (
    utEscape,     // Escape and show as text
    utPassthrough // Wrap in <span class="mu-unknown">
  );

  { TMuOptions }
  TMuOptions = record
    MaxIterations: Integer;
    MaxRecursionDepth: Integer;
    MaxOutputSize: Integer;
    StrictMode: Boolean;
    AllowHTML: Boolean;
    PrettyPrint: Boolean;
    UnknownTagBehavior: TMuUnknownTagBehavior;

    class function Defaults(): TMuOptions; static;
  end;

implementation

class function TMuOptions.Defaults(): TMuOptions;
begin
  Result.MaxIterations := 10000;
  Result.MaxRecursionDepth := 100;
  Result.MaxOutputSize := 10 * 1024 * 1024;
  Result.StrictMode := False;
  Result.AllowHTML := True;
  Result.PrettyPrint := False;
  Result.UnknownTagBehavior := utEscape;
end;

end.
