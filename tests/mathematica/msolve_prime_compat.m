(* ::Package:: *)

Print["finiteflow32 Mathematica msolve prime compatibility test starting"];

finish[code_] := If[TrueQ[$Notebooks], Null, Exit[code]];
fail[msg_] := (Print["ERROR: ", msg]; If[TrueQ[$Notebooks], Abort[], Exit[1]]);
nonEmptyStringQ[s_] := StringQ[s] && StringLength[s] > 0;
validPrefixQ[p_] := DirectoryQ[FileNameJoin[{p, "share", "finiteflow32", "mathematica"}]] &&
                    DirectoryQ[FileNameJoin[{p, "lib", "finiteflow32", "mathematica"}]];
frontEndDirectory[] := Quiet[Check[If[TrueQ[$Notebooks], NotebookDirectory[], ""], ""]];
candidatePrefixesFromDirectory[dir_] := ExpandFileName /@ {
  FileNameJoin[{dir, "..", "..", "_install", "finiteflow32"}],
  FileNameJoin[{dir, "_install", "finiteflow32"}]
};

envPrefix = Environment["FINITEFLOW32_PREFIX"];
sourceDirectories = DeleteDuplicates @ Select[
  {
    If[nonEmptyStringQ[$InputFileName], DirectoryName[$InputFileName], ""],
    frontEndDirectory[],
    Directory[]
  },
  nonEmptyStringQ
];
candidatePrefixes = DeleteDuplicates @ If[
  nonEmptyStringQ[envPrefix],
  {ExpandFileName[envPrefix]},
  Join @@ (candidatePrefixesFromDirectory /@ sourceDirectories)
];
prefix = SelectFirst[candidatePrefixes, validPrefixQ, $Failed];

If[prefix === $Failed,
  fail["FINITEFLOW32_PREFIX is not set and no local _install/finiteflow32 prefix could be found. Run the build script first, or set FINITEFLOW32_PREFIX in this Mathematica session."]
];

packagePath = FileNameJoin[{prefix, "share", "finiteflow32", "mathematica"}];
libraryPath = FileNameJoin[{prefix, "lib", "finiteflow32", "mathematica"}];

If[!DirectoryQ[packagePath], fail["Mathematica package directory not found: " <> packagePath]];
If[!DirectoryQ[libraryPath], fail["Mathematica LibraryLink directory not found: " <> libraryPath]];

If[!MemberQ[$Path, packagePath], PrependTo[$Path, packagePath]];
If[!MemberQ[$LibraryPath, libraryPath], PrependTo[$LibraryPath, libraryPath]];

Get["FiniteFlow32`"];

prime = FFPrimeNo[0];
If[!IntegerQ[prime] || prime <= 0, fail["FFPrimeNo[0] did not return a positive integer prime"]];
If[prime >= 2^31, fail["Active FiniteFlow32 prime is not supported by msolve: " <> ToString[prime]]];

msolve = Environment["MSOLVE"];
If[!nonEmptyStringQ[msolve], msolve = FindExecutable["msolve"]];
If[!nonEmptyStringQ[msolve],
  msolve = SelectFirst[
    {"/opt/homebrew/bin/msolve", "/usr/local/bin/msolve", "/usr/bin/msolve"},
    FileExistsQ,
    $Failed
  ]
];
If[!nonEmptyStringQ[msolve],
  fail["msolve executable not found. Install msolve or set MSOLVE=/path/to/msolve."]
];

externalRun = Environment["FINITEFLOW32_MSOLVE_EXTERNAL"] === "1";
externalInputFile = Environment["FINITEFLOW32_MSOLVE_INPUT"];
externalOutputFile = Environment["FINITEFLOW32_MSOLVE_OUTPUT"];

tmp = If[
  externalRun,
  DirectoryName[externalInputFile],
  CreateDirectory[FileNameJoin[{$TemporaryDirectory, "finiteflow32-msolve-prime-" <> StringReplace[CreateUUID[], "-" -> ""]}]]
];
inputFile = If[externalRun, externalInputFile, FileNameJoin[{tmp, "input.ms"}]];
outputFile = If[externalRun, externalOutputFile, FileNameJoin[{tmp, "output.ms"}]];

If[externalRun && (!nonEmptyStringQ[inputFile] || !nonEmptyStringQ[outputFile]),
  fail["External msolve test mode requires FINITEFLOW32_MSOLVE_INPUT and FINITEFLOW32_MSOLVE_OUTPUT"]
];

Export[inputFile, StringRiffle[{"x", ToString[prime], "x+1,", "x^2"}, "\n"] <> "\n", "Text"];

inputLines = StringSplit[Import[inputFile, "Text"], "\n"];
If[Length[inputLines] < 2 || ToExpression[inputLines[[2]]] =!= prime,
  fail["The msolve input file did not use the active FiniteFlow32 prime"]
];

If[externalRun,
  Print["finiteflow32 Mathematica wrote msolve input using active prime ", prime];
  finish[0]
];

proc = RunProcess[{msolve, "-f", inputFile, "-o", outputFile, "-n", "1", "-v", "0"}];
If[proc["ExitCode"] =!= 0,
  Print["msolve stdout: ", proc["StandardOutput"]];
  Print["msolve stderr: ", proc["StandardError"]];
  fail["msolve normal-form invocation failed"]
];

If[!FileExistsQ[outputFile], fail["msolve did not produce an output file"]];
output = StringTrim[Import[outputFile, "Text"]];
If[output =!= "[1]:",
  Print["Expected msolve normal form output: [1]:"];
  Print["Received msolve normal form output: ", output];
  fail["msolve normal-form output did not match the expected result"]
];

Quiet[Check[DeleteDirectory[tmp, DeleteContents -> True], Null]];

Print["finiteflow32 Mathematica msolve prime compatibility test passed"];
finish[0];
