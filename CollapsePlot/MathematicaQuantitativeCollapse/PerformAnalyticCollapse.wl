#!/usr/local/bin/MathematicaScript -script

AppendTo[$Path, Directory[]];

If[FindFile["AnalyticCollapse`"] === $Failed, Print["Package \"AnalyticCollapse\" could not be loaded! Aborting..."]; Abort[], Needs["AnalyticCollapse`"]]

SetOptions[ $Output, FormatType -> OutputForm ];

(*
 Order of the command line parameters:
    1)   betaC minimum
    2)   betaC maximum
    3)   betaC scan resolution (0 for continuous scan)
    4)   nu minimum
    5)   nu maximum
    6)   nu scan resolution (0 for continuous scan)
    7)   ddx minimum
    8)   ddx maximum
    9)   ddx resolution
    10+) names of files containing data 
    
  NOTE: The datafile must be in the format: {{Beta, Kurtosis}}
        The estimator datafile must be in the format: {{EstimatorNumber, Beta, Kurtosis}}
        and it should have the same name as the data file, 
        with "_estimators" before the extension.
*)
givenCommandLines = Rest[$ScriptCommandLine];
{bCmin, bCmax, bCres, nuMin, nuMax, nuRes, ddxMin, ddxMax, ddxRes} = ToExpression[givenCommandLines[[1;;9]]];
NamesOfFiles = givenCommandLines[[11;;]]
NamesOfFilesWithEstimators = StringInsert[#, "_estimators", -5] & /@ NamesOfFiles;

If[givenCommandLines[[10]]!="stdout",
   stream = OpenWrite[givenCommandLines[[10]], FormatType -> OutputForm]; $Output = {stream}
]

(*----------------------------------------------------------------------------------*)
(*Checks on the resolutions, one zero and one non zero not allowed*)
If[(bCres!=0 && nuRes==0) || (bCres==0 && nuRes!=0), Print["Both resolutions must be zero or non-zero! Aborting..."]; Abort[]]

(*----------------------------------------------------------------------------------*)
(*Checks on the existence of the files*)
If[!FileExistsQ[#],
   Print[StringForm["File \"``\" not found! Aborting...", #]]; Abort[]
] & /@ Join[NamesOfFiles, NamesOfFilesWithEstimators]

(*Check on the name of the files: they must contain "ns" with at least one digit afterwards*)
If[
    Length[StringCases[#, RegularExpression["ns[[:digit:]]+"]]]!=1,
    Print[StringForm["File \"``\" does not contain one and only one occurence of \"ns[[::digit]]+\"! Aborting...", #]]; Abort[]
] & /@ StringReplace[NamesOfFiles, RegularExpression[".*/"] -> ""]

(*----------------------------------------------------------------------------------*)
(*Import data*)
Volume[filename_] := 
    Module[{basename},
        basename = StringReplace[filename, RegularExpression[".*/"] -> ""];
        ToExpression[StringCases[StringCases[basename, RegularExpression["ns[[:digit:]]+"]], RegularExpression["[[:digit:]]+"]][[1, 1]]]
    ]
AllDataInBeta = {Import[#], Volume[#]} & /@ NamesOfFiles;
AllEstimatorsInBeta = {Import[#], Volume[#]} & /@ NamesOfFilesWithEstimators;

(*Build up name of output file*)
NameOfOutputFile = StringTake[NamesOfFiles//First, StringPosition[NamesOfFiles//First, "_", 1][[1,1]]-1]
NameOfOutputFile = Fold[StringJoin, NameOfOutputFile, "_ns" <> ToString[Volume[#]] & /@ NamesOfFiles ]
NameOfOutputFile = NameOfOutputFile <> "_analyticCollapse.dat"

(*----------------------------------------------------------------------------------*)

Print["\n"]
ResultToBeExportedToFile={};
Do[
    If[bCres!=0 && nuRes!=0,
        iterationResult=AbsoluteTiming[FindCriticalParametersAndEstimateErrorsOnThemUsingEstimatorsUsingADiscreteScan[AllDataInBeta, AllEstimatorsInBeta, bCmin, bCmax, bCres, nuMin, nuMax, nuRes, i]],
        iterationResult=AbsoluteTiming[FindCriticalParametersAndEstimateErrorsOnThemUsingEstimatorsUsingAContinuousScan[AllDataInBeta, AllEstimatorsInBeta, bCmin, bCmax, nuMin, nuMax, i]]
    ]
    Print[StringForm["Time to perform calculation: `` sec.",ToString[iterationResult[[1]]],TraditionalForm]];
    Print["Result:"]
    Print["\t" <> PrepareDataToBeExported[Drop[iterationResult,{1}], 6]//MatrixForm];
    AppendTo[ResultToBeExportedToFile,Drop[iterationResult,{1}]];
    Clear[iterationResult];
    Print[];
, {i, Range[ddxMax,ddxMin,-ddxRes]}]

WriteResultsToFile[NameOfOutputFile, PrepareDataToBeExported[ResultToBeExportedToFile,6], bCmin, bCmax, bCres, nuMin, nuMax, nuRes];






