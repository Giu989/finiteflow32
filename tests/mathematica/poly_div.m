(* ::Package:: *)

Print["finiteflow32 Mathematica FFAlgNodePolyDiv test starting"];

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
If[prime >= 2^31, fail["Active FiniteFlow32 prime is not msolve-compatible"]];

graph = Unique["ff32PolyDivGraph"];
input = Unique["ff32PolyDivInput"];
targetNode = Unique["ff32PolyDivTarget"];
idealNode = Unique["ff32PolyDivIdeal"];
polyNode = Unique["ff32PolyDivNode"];

targetPattern = {
  {
    {{1, 1}, x^3},
    {{1, 2}, y}
  },
  {
    {{1, 3}, x^2*y},
    {{1, 4}, x}
  }
};

idealPattern = {
  {
    {{2, 1}, x^2},
    {{2, 2}, y}
  },
  {
    {{2, 3}, x*y},
    {{2, 4}, 1}
  }
};

Check[
  FFNewGraph[graph, input, {a}];
  FFAlgRatFunEval[graph, targetNode, {input}, {a}, {1, 1, 1, 1}];
  FFAlgRatFunEval[graph, idealNode, {input}, {a}, {1, 1, 1, 1}];
  FFAlgNodePolyDiv[
    graph,
    polyNode,
    {targetNode, idealNode},
    {targetPattern, idealPattern},
    {x, y}
  ];
  FFGraphOutput[graph, polyNode];,
  fail["FFAlgNodePolyDiv graph construction raised a Mathematica error"]
];

learnedBasis = Check[
  FFPolyDivLearn[graph, {x, y}],
  fail["FFAlgNodePolyDiv learning raised a Mathematica error"]
];

expectedBasis = {1, y};
If[learnedBasis =!= expectedBasis,
  Print["Expected learned basis: ", expectedBasis];
  Print["Received learned basis: ", learnedBasis];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodePolyDiv learned the wrong monomial basis"]
];

result = Check[
  FFGraphEvaluate[graph, {17}, "PrimeNo" -> 0],
  fail["FFAlgNodePolyDiv graph evaluation raised a Mathematica error"]
];

expected = {1, 1, 0, 0};
If[result =!= expected,
  Print["Expected coefficients: ", expected];
  Print["Received coefficients: ", result];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodePolyDiv returned the wrong flattened coefficients"]
];

Quiet[Check[FFDeleteGraph[graph], Null]];

Print["finiteflow32 Mathematica FFAlgNodePolyDiv test passed"];
finish[0];



