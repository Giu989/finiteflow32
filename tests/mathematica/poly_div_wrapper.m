(* ::Package:: *)

Print["finiteflow32 Mathematica FFAlgPolyDiv wrapper test starting"];

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

makeGraph[] := Module[{graph = Unique["ff32PolyDivWrapperGraph"], input = Unique["ff32PolyDivWrapperInput"]},
  FFNewGraph[graph, input, {a, b}];
  graph
];

SetAttributes[expectFailure, HoldFirst];
expectFailure[expr_, label_] := Module[{res},
  res = Quiet[Check[expr, $Failed]];
  If[!TrueQ[res === $Failed],
    Print["Unexpected success in ", label, ": ", res];
    fail[label <> " did not fail"]
  ];
];

targets = {
  (a + b) x^2 y + (a^2 + 1) x
};

ideal = {
  (a + 1) x + b y
};

graph = makeGraph[];
Check[
  FFAlgPolyDiv[graph, "autoOut", targets, ideal, {x, y}, {a, b}];
  FFGraphOutput[graph, "autoOut"];,
  fail["FFAlgPolyDiv explicit-parameter construction raised a Mathematica error"]
];

preLearnEval = Quiet[Check[FFGraphEvaluate[graph, {3, 5}, "PrimeNo" -> 0], $Failed]];
If[!TrueQ[preLearnEval === $Failed],
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgPolyDiv unexpectedly produced an immediately evaluable node"]
];

learnedBasis = Check[
  FFPolyDivLearn[graph, {x, y}],
  fail["FFAlgPolyDiv output node failed in the normal learning workflow"]
];
If[!ListQ[learnedBasis],
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFPolyDivLearn did not return a monomial basis for the wrapper-created node"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

graph = makeGraph[];
Check[
  FFAlgPolyDiv[graph, "explicitOut", targets, ideal, {x, y}, {a, b}];,
  fail["FFAlgPolyDiv repeated construction raised a Mathematica error"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

graph = Module[{g = Unique["ff32PolyDivWrapperGraph"], input = Unique["ff32PolyDivWrapperInput"]},
  FFNewGraph[g, input, {b, a}];
  g
];
Check[
  FFAlgPolyDiv[
    graph,
    "orderedParamsOut",
    {a + b y},
    {x},
    {x, y},
    {b, a}
  ];
  FFGraphOutput[graph, "orderedParamsOut"];,
  fail["FFAlgPolyDiv reversed-parameter construction raised a Mathematica error"]
];
orderedBasis = Check[
  FFPolyDivLearn[graph, {x, y}],
  fail["FFAlgPolyDiv reversed-parameter node failed to learn"]
];
If[!TrueQ[orderedBasis === {y, 1}],
  Print["Expected reversed-parameter learned basis: ", {y, 1}];
  Print["Received reversed-parameter learned basis: ", orderedBasis];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgPolyDiv reversed-parameter learned basis was unexpected"]
];
orderedEval = Check[
  FFGraphEvaluate[graph, {3, 5}, "PrimeNo" -> 0],
  fail["FFAlgPolyDiv reversed-parameter node failed to evaluate"]
];
If[!TrueQ[orderedEval === {3, 5}],
  Print["Expected reversed-parameter evaluation: ", {3, 5}];
  Print["Received reversed-parameter evaluation: ", orderedEval];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgPolyDiv did not respect the explicit parameter order"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

graph = makeGraph[];
Check[
  FFAlgPolyDiv[
    graph,
    "rationalOut",
    {((a + 1)/(b - 2)) x^2 + a y},
    {(b + 1) x + y},
    {x, y},
    {a, b}
  ];,
  fail["FFAlgPolyDiv rational-coefficient construction raised a Mathematica error"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

graph = Module[{g = Unique["ff32PolyDivWrapperGraph"], input = Unique["ff32PolyDivWrapperInput"]},
  FFNewGraph[g, input, {c, a, b}];
  g
];
Check[
  FFAlgPolyDiv[
    graph,
    "threeParamOut",
    {c x + (a + b) y},
    {(a + 1) x + b y},
    {x, y},
    {c, a, b}
  ];,
  fail["FFAlgPolyDiv failed to accept a larger explicit parameter list"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

graph = makeGraph[];
expectFailure[
  FFAlgPolyDiv[graph, "missingParams", targets, ideal, {x, y}],
  "missing explicit parameter list"
];
expectFailure[
  FFAlgPolyDiv[graph, "badOption", targets, ideal, {x, y}, {a, b}, InputNode -> "in"],
  "unsupported InputNode option"
];
expectFailure[
  FFAlgPolyDiv[graph, "badCoeffOption", targets, ideal, {x, y}, {a, b}, CoefficientNodeName -> "coeffs"],
  "unsupported CoefficientNodeName option"
];
expectFailure[
  FFAlgPolyDiv[graph, "badVarsOption", targets, ideal, {x, y}, {a, b}, Variables -> Automatic],
  "unsupported Variables option"
];
expectFailure[
  FFAlgPolyDiv[graph, "badOrder", targets, ideal, {x, y}, {a, b}, MonomialOrder -> "Lexicographic"],
  "unsupported monomial order"
];
expectFailure[
  FFAlgPolyDiv[graph, "badPolynomial", {1/(1 + x)}, ideal, {x, y}, {a, b}],
  "polynomial variable in denominator"
];
expectFailure[
  FFAlgPolyDiv[graph, "emptyVars", targets, ideal, {}, {a, b}],
  "empty explicit variables"
];
expectFailure[
  FFAlgPolyDiv[graph, "duplicateVars", targets, ideal, {x, x}, {a, b}],
  "duplicate explicit variables"
];
expectFailure[
  FFAlgPolyDiv[graph, "nonSymbolVars", targets, ideal, {x + y}, {a, b}],
  "non-symbol explicit variables"
];
expectFailure[
  FFAlgPolyDiv[graph, "missingCoeffParam", targets, ideal, {x, y}, {a}],
  "missing coefficient parameter"
];
expectFailure[
  FFAlgPolyDiv[graph, "duplicateParams", targets, ideal, {x, y}, {a, a}],
  "duplicate explicit parameters"
];
expectFailure[
  FFAlgPolyDiv[graph, "overlapParams", targets, ideal, {x, y}, {a, x}],
  "parameter overlaps polynomial variable"
];
expectFailure[
  FFAlgPolyDiv[graph, "nonSymbolParams", targets, ideal, {x, y}, {a + b}],
  "non-symbol explicit parameters"
];
expectFailure[
  FFAlgPolyDiv[graph, "badCoeff", {Sin[a] x + y}, ideal, {x, y}, {a, b}],
  "non-rational coefficient expression"
];
Quiet[Check[FFDeleteGraph[graph], Null]];

Print["finiteflow32 Mathematica FFAlgPolyDiv wrapper test passed"];
finish[0];
