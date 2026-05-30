(* ::Package:: *)

Print["finiteflow32 Mathematica FFAddOne test starting"];

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

vars = {x, y, z};
funcs = {x, y + 1, z^2 + x};
expectedFuncs = funcs + 1;

graph = Unique["ff32AddOneGraph"];
input = Unique["ff32AddOneInput"];
base = Unique["ff32AddOneBase"];
addOne = Unique["ff32AddOneNode"];

Check[
  FFNewGraph[graph, input, vars];
  FFAlgRatFunEval[graph, base, {input}, vars, funcs];
  FFAddOne[graph, addOne, base];
  FFGraphOutput[graph, addOne];
  result = FFGraphEvaluate[graph, {0, 1, prime - 1}, "PrimeNo" -> 0];,
  fail["FFAddOne graph construction or evaluation raised a Mathematica error"]
];

expected = {1, 3, 2};
If[result =!= expected,
  Print["Expected: ", expected];
  Print["Received: ", result];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAddOne native evaluation returned the wrong result"]
];

reconstructed = Check[
  FFReconstructFunction[graph, vars, "NThreads" -> 1, "MinPrimes" -> 2, "MaxPrimes" -> 4],
  fail["FFAddOne reconstruction raised a Mathematica error"]
];

probeRules = {x -> 2/3, y -> 5/7, z -> 11/13};
If[!ListQ[reconstructed] ||
   !AllTrue[(reconstructed - expectedFuncs) /. probeRules, TrueQ[# == 0]&],
  Print["Expected reconstruction: ", expectedFuncs];
  Print["Received reconstruction: ", reconstructed];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAddOne reconstruction did not match the expected expressions"]
];

Quiet[Check[FFDeleteGraph[graph], Null]];

Print["finiteflow32 Mathematica FFAddOne test passed"];
finish[0];

