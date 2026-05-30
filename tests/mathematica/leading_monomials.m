(* ::Package:: *)

Print["finiteflow32 Mathematica LeadingMonomials test starting"];

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

SetAttributes[expectFailure, HoldFirst];
expectFailure[expr_, label_] := Module[{res},
  res = Quiet[Check[expr, $Failed]];
  If[!TrueQ[res === $Failed],
    Print["Unexpected success in ", label, ": ", res];
    fail[label <> " did not fail"]
  ];
];

monomialListQ[monoms_, vars_] := Module[{rules},
  ListQ[monoms] && AllTrue[
    monoms,
    Function[mon,
      TrueQ[PolynomialQ[mon, vars]] &&
      (rules = CoefficientRules[mon, vars]; Length[rules] == 1 &&
       rules[[1,2]] === 1)
    ]
  ]
];

basic = Check[
  LeadingMonomials[{x^2 + y, x*y + 1}, {x, y}, "RandomSeed" -> 1234],
  fail["LeadingMonomials failed on the basic ideal"]
];

If[!TrueQ[basic === {x^2, x*y, y^2}],
  Print["Expected leading monomials: ", {x^2, x*y, y^2}];
  Print["Received leading monomials: ", basic];
  fail["LeadingMonomials returned the wrong basic leading ideal"]
];

paramIdeal = {
  (a + 1) x^2 + b y,
  (a b + 3) x*y + 1
};

param1 = Check[
  LeadingMonomials[paramIdeal, {x, y}, "RandomSeed" -> 98765],
  fail["LeadingMonomials failed on the parameter-dependent ideal"]
];
param2 = Check[
  LeadingMonomials[paramIdeal, {x, y}, "RandomSeed" -> 98765],
  fail["LeadingMonomials failed on a repeated seeded parameter-dependent ideal"]
];

If[!TrueQ[param1 === param2],
  Print["First seeded result: ", param1];
  Print["Second seeded result: ", param2];
  fail["LeadingMonomials was not deterministic with a fixed random seed"]
];

If[!monomialListQ[param1, {x, y}],
  Print["Parameter-dependent result: ", param1];
  fail["LeadingMonomials returned expressions that are not monomials in the supplied variables"]
];

elimBasic = Check[
  LeadingMonomials[
    {x + y + z, x*y - 1, z^2 - x},
    {z, x, y},
    {z},
    "RandomSeed" -> 1234
  ],
  fail["LeadingMonomials failed on one-variable block elimination"]
];

If[!TrueQ[elimBasic === {y^3, x^2, x*y}],
  Print["Expected one-variable elimination leading monomials: ", {y^3, x^2, x*y}];
  Print["Received one-variable elimination leading monomials: ", elimBasic];
  fail["LeadingMonomials returned the wrong one-variable elimination leading ideal"]
];

If[!monomialListQ[elimBasic, {x, y}] || !FreeQ[elimBasic, z],
  Print["Elimination result: ", elimBasic];
  fail["LeadingMonomials returned eliminated variables in the one-variable elimination result"]
];

elimMultiple = Check[
  LeadingMonomials[
    {u - x - y, v - x*y, u + v + x},
    {u, v, x, y},
    {u, v},
    "RandomSeed" -> 4321
  ],
  fail["LeadingMonomials failed on two-variable block elimination"]
];

If[!TrueQ[elimMultiple === {x*y}],
  Print["Expected two-variable elimination leading monomials: ", {x*y}];
  Print["Received two-variable elimination leading monomials: ", elimMultiple];
  fail["LeadingMonomials returned the wrong two-variable elimination leading ideal"]
];

elimOrdered = Check[
  LeadingMonomials[
    {x + y + z, x*y - 1, z^2 - x},
    {z, x, y},
    {z},
    "RandomSeed" -> 2468
  ],
  fail["LeadingMonomials failed on order-preserving block elimination"]
];

If[!TrueQ[elimOrdered === {y^3, x^2, x*y}],
  Print["Expected order-preserving elimination leading monomials: ", {y^3, x^2, x*y}];
  Print["Received order-preserving elimination leading monomials: ", elimOrdered];
  fail["LeadingMonomials did not preserve surviving variable order or grevlex order"]
];

paramElim = Check[
  LeadingMonomials[
    {(a + 1) z + x + y, x*y - b, z^2 - x},
    {z, x, y},
    {z},
    "RandomSeed" -> 13579
  ],
  fail["LeadingMonomials failed on parameter-dependent block elimination"]
];

If[!monomialListQ[paramElim, {x, y}] || !FreeQ[paramElim, z],
  Print["Parameter-dependent elimination result: ", paramElim];
  fail["LeadingMonomials returned invalid monomials for parameter-dependent elimination"]
];

expectFailure[
  LeadingMonomials[{}, {x}],
  "empty ideal"
];
expectFailure[
  LeadingMonomials[{x + 1}, {}],
  "empty variable list"
];
expectFailure[
  LeadingMonomials[{x + 1}, {x, x}],
  "duplicate variable list"
];
expectFailure[
  LeadingMonomials[{x + 1}, {x + y}],
  "non-symbol variable list"
];
expectFailure[
  LeadingMonomials[{x + y}, {x, y}, {z}],
  "elimination variable not in variable list"
];
expectFailure[
  LeadingMonomials[{x + y}, {x, y}, {x, x}],
  "duplicate elimination variable"
];
expectFailure[
  LeadingMonomials[{x + y}, {x, y}, {x, y}],
  "eliminating all variables"
];
expectFailure[
  LeadingMonomials[{1/(1 + x)}, {x}],
  "non-polynomial expression in variable"
];
expectFailure[
  LeadingMonomials[{Sin[a] x + 1}, {x}, "RandomSeed" -> 1],
  "non-rational specialized coefficient"
];
expectFailure[
  LeadingMonomials[{x + 1}, {x},
    "MsolveExecutable" -> "/definitely/not/a/finiteflow32/msolve"],
  "missing msolve executable"
];

Print["finiteflow32 Mathematica LeadingMonomials test passed"];
finish[0];
