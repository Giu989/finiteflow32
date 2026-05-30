(* ::Package:: *)

Print["finiteflow32 Mathematica FFAlgGroebner test starting"];

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

SetAttributes[expectFailure, HoldFirst];
expectFailure[expr_, label_] := Module[{res},
  res = Quiet[Check[expr, $Failed]];
  If[!TrueQ[res === $Failed],
    Print["Unexpected success in ", label, ": ", res];
    fail[label <> " did not fail"]
  ];
];

(* Lower-level node without elimination. *)
graph = Unique["ff32GroebnerNodeGraph"];
input = Unique["ff32GroebnerNodeInput"];
coeffNode = Unique["ff32GroebnerNodeCoeff"];
gbNode = Unique["ff32GroebnerNode"];

idealPattern = {
  {
    {{1, 1}, x^2},
    {{1, 2}, y}
  },
  {
    {{1, 3}, x*y},
    {{1, 4}, 1}
  }
};

Check[
  FFNewGraph[graph, input, {a}];
  FFAlgRatNumEval[graph, coeffNode, {1, 1, 1, 1}];
  FFAlgNodeGroebner[graph, gbNode, {coeffNode}, idealPattern, {x, y}];
  FFGraphOutput[graph, gbNode];,
  fail["FFAlgNodeGroebner construction without elimination raised a Mathematica error"]
];

nodeSupport = Check[
  FFGroebnerLearn[graph],
  fail["FFAlgNodeGroebner learning without elimination raised a Mathematica error"]
];
expectedNodeSupport = {{x^2, y}, {x*y, 1}, {y^2, x}};
If[nodeSupport =!= expectedNodeSupport,
  Print["Expected lower-level support: ", expectedNodeSupport];
  Print["Received lower-level support: ", nodeSupport];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodeGroebner learned the wrong no-elimination support"]
];

nodeResult = Check[
  FFGraphEvaluate[graph, {17}, "PrimeNo" -> 0],
  fail["FFAlgNodeGroebner evaluation without elimination raised a Mathematica error"]
];
expectedNodeResult = {1, 1, 1, 1, 1, prime - 1};
If[nodeResult =!= expectedNodeResult,
  Print["Expected lower-level coefficients: ", expectedNodeResult];
  Print["Received lower-level coefficients: ", nodeResult];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodeGroebner returned the wrong no-elimination coefficients"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

(* Lower-level node with block elimination and nonstandard variable order. *)
graph = Unique["ff32GroebnerElimGraph"];
input = Unique["ff32GroebnerElimInput"];
coeffNode = Unique["ff32GroebnerElimCoeff"];
gbNode = Unique["ff32GroebnerElimNode"];

elimPattern = {
  {
    {{1, 1}, z},
    {{1, 2}, x},
    {{1, 3}, y}
  },
  {
    {{1, 4}, x*y},
    {{1, 5}, 1}
  },
  {
    {{1, 6}, z^2},
    {{1, 7}, x}
  }
};

Check[
  FFNewGraph[graph, input, {a}];
  FFAlgRatNumEval[graph, coeffNode, {1, 1, 1, 1, -1, 1, -1}];
  FFAlgNodeGroebner[
    graph,
    gbNode,
    {coeffNode},
    elimPattern,
    {z, x, y},
    EliminateVariables -> {z}
  ];
  FFGraphOutput[graph, gbNode];,
  fail["FFAlgNodeGroebner construction with elimination raised a Mathematica error"]
];

elimSupport = Check[
  FFGroebnerLearn[graph, {z, x, y}],
  fail["FFAlgNodeGroebner learning with elimination raised a Mathematica error"]
];
expectedElimSupport = {{y^3, x, y, 1}, {x^2, y^2, x, 1}, {x*y, 1}};
If[elimSupport =!= expectedElimSupport,
  Print["Expected eliminated support: ", expectedElimSupport];
  Print["Received eliminated support: ", elimSupport];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodeGroebner learned the wrong elimination support"]
];
elimAutoSupport = Check[
  FFGroebnerLearn[graph],
  fail["FFAlgNodeGroebner automatic eliminated-variable learning raised a Mathematica error"]
];
If[elimAutoSupport =!= expectedElimSupport,
  Print["Expected automatic eliminated support: ", expectedElimSupport];
  Print["Received automatic eliminated support: ", elimAutoSupport];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodeGroebner automatic eliminated-variable learning returned the wrong support"]
];
If[!FreeQ[elimSupport, z],
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodeGroebner elimination support contains eliminated variable"]
];

elimResult = Check[
  FFGraphEvaluate[graph, {19}, "PrimeNo" -> 0],
  fail["FFAlgNodeGroebner evaluation with elimination raised a Mathematica error"]
];
expectedElimResult = {1, 1, 2, prime - 1, 1, 1, prime - 1, 2, 1, prime - 1};
If[elimResult =!= expectedElimResult,
  Print["Expected eliminated coefficients: ", expectedElimResult];
  Print["Received eliminated coefficients: ", elimResult];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgNodeGroebner returned the wrong elimination coefficients"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

(* High-level wrapper without and with elimination. *)
graph = Unique["ff32GroebnerWrapperGraph"];
input = Unique["ff32GroebnerWrapperInput"];
gbNode = Unique["ff32GroebnerWrapperNode"];
Check[
  FFNewGraph[graph, input, {a, b}];
  FFAlgGroebner[
    graph,
    gbNode,
    {a*x^2 + b*y, a*x*y + b},
    {x, y},
    {a, b}
  ];
  FFGraphOutput[graph, gbNode];,
  fail["FFAlgGroebner construction without elimination raised a Mathematica error"]
];
wrapperSupport = Check[
  FFGroebnerLearn[graph, {x, y}],
  fail["FFAlgGroebner learning without elimination raised a Mathematica error"]
];
If[wrapperSupport =!= expectedNodeSupport,
  Print["Expected high-level support: ", expectedNodeSupport];
  Print["Received high-level support: ", wrapperSupport];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgGroebner learned the wrong no-elimination support"]
];
paramRatio = Mod[7*PowerMod[5, -1, prime], prime];
expectedWrapperResult = {1, paramRatio, 1, paramRatio, 1, prime - 1};
wrapperResult = Check[
  FFGraphEvaluate[graph, {5, 7}, "PrimeNo" -> 0],
  fail["FFAlgGroebner evaluation without elimination raised a Mathematica error"]
];
If[wrapperResult =!= expectedWrapperResult,
  Print["Expected high-level coefficients: ", expectedWrapperResult];
  Print["Received high-level coefficients: ", wrapperResult];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgGroebner returned the wrong no-elimination coefficients"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

graph = Unique["ff32GroebnerWrapperElimGraph"];
input = Unique["ff32GroebnerWrapperElimInput"];
gbNode = Unique["ff32GroebnerWrapperElimNode"];
Check[
  FFNewGraph[graph, input, {a, b}];
  FFAlgGroebner[
    graph,
    gbNode,
    {
      z + x + y,
      x*y - 1,
      z^2 - x
    },
    {z, x, y},
    {a, b},
    "EliminateVariables" -> {z}
  ];
  FFGraphOutput[graph, gbNode];,
  fail["FFAlgGroebner construction with elimination raised a Mathematica error"]
];
wrapperElimSupport = Check[
  FFGroebnerLearn[graph, {z, x, y}, "EliminateVariables" -> {z}],
  fail["FFAlgGroebner learning with elimination raised a Mathematica error"]
];
If[wrapperElimSupport =!= expectedElimSupport,
  Print["Expected high-level eliminated support: ", expectedElimSupport];
  Print["Received high-level eliminated support: ", wrapperElimSupport];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgGroebner learned the wrong elimination support"]
];
wrapperElimResult = Check[
  FFGraphEvaluate[graph, {11, 13}, "PrimeNo" -> 0],
  fail["FFAlgGroebner evaluation with elimination raised a Mathematica error"]
];
If[wrapperElimResult =!= expectedElimResult,
  Print["Expected high-level eliminated coefficients: ", expectedElimResult];
  Print["Received high-level eliminated coefficients: ", wrapperElimResult];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["FFAlgGroebner returned the wrong elimination coefficients"]
];
Quiet[Check[FFDeleteGraph[graph], Null]];

graph = Unique["ff32GroebnerInvalidGraph"];
input = Unique["ff32GroebnerInvalidInput"];
FFNewGraph[graph, input, {a}];
expectFailure[
  FFAlgGroebner[graph, "badOrder", {x + 1}, {x}, {}, MonomialOrder -> "Lexicographic"],
  "unsupported Groebner monomial order"
];
expectFailure[
  FFAlgGroebner[graph, "badElimMissing", {x + y}, {x, y}, {}, EliminateVariables -> {z}],
  "eliminated variable not in variables"
];
expectFailure[
  FFAlgGroebner[graph, "badElimDuplicate", {x + y}, {x, y}, {}, EliminateVariables -> {x, x}],
  "duplicate eliminated variable"
];
expectFailure[
  FFAlgGroebner[graph, "badElimAll", {x + y}, {x, y}, {}, EliminateVariables -> {x, y}],
  "eliminating all variables"
];
expectFailure[
  FFAlgGroebner[graph, "badVariables", {x + y}, {x, x}, {}],
  "duplicate Groebner variables"
];
expectFailure[
  FFAlgGroebner[graph, "missingParameters", {x + 1}, {x}],
  "missing Groebner parameters argument"
];
expectFailure[
  FFAlgGroebner[graph, "badPolynomial", {1/(1 + x)}, {x}, {}],
  "Groebner polynomial variable in denominator"
];
expectFailure[
  FFAlgGroebner[graph, "badCoefficient", {Sin[a] x + 1}, {x}, {a}],
  "Groebner non-rational coefficient"
];
expectFailure[
  FFAlgNodeGroebner[graph, "badNodeElim", {}, {}, {x}, EliminateVariables -> {z}],
  "lower-level invalid eliminated variable"
];
Quiet[Check[FFDeleteGraph[graph], Null]];

Print["finiteflow32 Mathematica FFAlgGroebner test passed"];
finish[0];
