(* ::Package:: *)

Print["finiteflow32 Mathematica multiprime reconstruction test starting"];

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

If[FFNAvailablePrimes[] != 400,
  fail["Expected 400 active 32-bit primes, found " <> ToString[FFNAvailablePrimes[]]]
];
If[FFPrimeNo[0] > 2^32 - 1 || FFPrimeNo[399] > 2^32 - 1,
  fail["The active prime table is not the 32-bit table"]
];

vars = {x, y};
large1 = 2^120 + 2^64 + 12345;
large2 = -(2^113 + 2^35 + 98765);
funcs = {
  large1*x + large2*y + 7,
  (large1 + x + 3 y)/(1 + x + y),
  (large2*x*y + large1)/(3 + 2 x + y)
};

graph = Unique["ff32MultiprimeGraph"];
input = Unique["ff32MultiprimeInput"];
node = Unique["ff32MultiprimeNode"];

Check[
  FFNewGraph[graph, input, vars];
  FFAlgRatFunEval[graph, node, {input}, vars, funcs];
  FFGraphOutput[graph, node];,
  fail["multiprime graph construction raised a Mathematica error"]
];

tooFew = Check[
  FFReconstructFunction[graph, vars, "NThreads" -> 1, "MinPrimes" -> 1, "MaxPrimes" -> 2],
  fail["low-prime reconstruction raised a Mathematica error"]
];
If[ListQ[tooFew],
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["reconstruction unexpectedly succeeded with only two 32-bit primes"]
];

reconstructed = Check[
  FFReconstructFunction[graph, vars, "NThreads" -> 1, "MinPrimes" -> 8, "MaxPrimes" -> 12],
  fail["multiprime reconstruction raised a Mathematica error"]
];

probeRules = {x -> 11/7, y -> 13/5};
If[!ListQ[reconstructed] ||
   !AllTrue[(reconstructed - funcs) /. probeRules, TrueQ[# == 0]&],
  Print["Expected reconstruction: ", funcs];
  Print["Received reconstruction: ", reconstructed];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["multiprime reconstruction did not match the expected expressions"]
];

Quiet[Check[FFDeleteGraph[graph], Null]];

Print["finiteflow32 Mathematica multiprime reconstruction test passed"];
finish[0];



