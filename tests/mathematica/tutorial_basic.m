(* ::Package:: *)

Print["finiteflow32 Mathematica tutorial test starting"];

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

vars = {x1, x2, x3};
fun1 = {
  (1 + x1)/(1 + x2),
  (1 + x2)/(1 + x3),
  (1 + x1)/(1 + x3),
  (1 + x1^2)/(1 + x2^2)
};
fun2 = {
  (1 + x2^2)/(1 + x3^2),
  (1 + x1^2)/(1 + x3^2),
  (1 - x1^2)/(1 - x2^2),
  (1 - x1^2)/(1 - x3^2)
};

graph = Unique["ff32TutorialGraph"];
input = Unique["ff32TutorialInput"];
ratFun1 = Unique["ff32TutorialFun1"];
ratFun2 = Unique["ff32TutorialFun2"];
matmul = Unique["ff32TutorialMatMul"];

Check[
  FFNewGraph[graph, input, vars];
  FFAlgRatFunEval[graph, ratFun1, {input}, vars, fun1];
  FFAlgRatFunEval[graph, ratFun2, {input}, vars, fun2];
  FFAlgMatMul[graph, matmul, {ratFun1, ratFun2}, 2, 2, 2];
  FFGraphOutput[graph, matmul];,
  fail["tutorial graph construction raised a Mathematica error"]
];

prime = FFPrimeNo[0];
point = {123, 345, 567};
pointRules = Thread[vars -> point];

evalResult = Check[
  FFGraphEvaluate[graph, point, "PrimeNo" -> 0],
  fail["tutorial graph evaluation raised a Mathematica error"]
];
expectedEval = FFRatMod[Flatten[Partition[fun1 /. pointRules, 2] . Partition[fun2 /. pointRules, 2]], prime];

If[evalResult =!= expectedEval,
  Print["Expected evaluation: ", expectedEval];
  Print["Received evaluation: ", evalResult];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["tutorial graph evaluation returned the wrong result"]
];

reconstructed = Check[
  FFReconstructFunction[graph, vars, "NThreads" -> 1],
  fail["tutorial reconstruction raised a Mathematica error"]
];
expectedFunctions = Flatten[Partition[fun1, 2] . Partition[fun2, 2]];
probeRules = {x1 -> 12/19, x2 -> 30/17, x3 -> 23/41};

If[!ListQ[reconstructed] ||
   !AllTrue[(reconstructed - expectedFunctions) /. probeRules, TrueQ[# == 0]&],
  Print["Expected reconstruction: ", expectedFunctions];
  Print["Received reconstruction: ", reconstructed];
  Quiet[Check[FFDeleteGraph[graph], Null]];
  fail["tutorial reconstruction did not match the tutorial expression"]
];

Quiet[Check[FFDeleteGraph[graph], Null]];

Print["finiteflow32 Mathematica tutorial test passed"];
finish[0];



