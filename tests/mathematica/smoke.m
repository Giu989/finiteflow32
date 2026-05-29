(* ::Package:: *)

Print["finiteflow32 Mathematica smoke test starting"];

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

If[!IntegerQ[$FFVersion] || !IntegerQ[$FFVersionMinor],
  fail["FiniteFlow32 package loaded, but native version query failed"]
];

prime = FFPrimeNo[0];
If[!IntegerQ[prime] || prime <= 0, fail["FFPrimeNo[0] did not return a positive integer prime"]];

graph = Unique["ff32SmokeGraph"];
input = Unique["ff32SmokeInput"];
node = Unique["ff32SmokeNode"];

Check[
  FFNewGraph[graph, input, {x, y}];
  FFAlgRatFunEval[graph, node, {input}, {x, y}, {x + 2 y, x y + 1, (1 + x)/(1 + y)}];
  FFGraphOutput[graph, node];
  result = FFGraphEvaluate[graph, {7, 11}, "PrimeNo" -> 0];,
  fail["Graph construction or evaluation raised a Mathematica error"]
];

expected = {29, 78, FFRatMod[2/3, prime]};

If[result =!= expected,
  Print["Expected: ", expected];
  Print["Received: ", result];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["simple native graph evaluation returned the wrong result"]
];

Quiet[Check[FFDeleteGraph[graph], Null]];

Print["finiteflow32 Mathematica smoke test passed"];
finish[0];



