(* ::Package:: *)

BeginPackage["AnalyticCollapse`"]

$PrintFrontendOutput::usage = 
		"Global variable to suppress frontend output that is awful in absence of it (e.g. PrintTemporary)"

MakeScanInBetaCAndNu::usage = 
		"
		This function makes a scan in beta and nu in the given intervals and with given resolutions
		calculating for each set of parameters the quality of the collapse of the given data.
		
		The output is a list in the form { \[Beta], \[Nu], varianceOfKurtosis, {\!\(\*SubscriptBox[\(x\), \(min\)]\), \!\(\*SubscriptBox[\(x\), \(max\)]\)}}

		There are 8 parameters to be specified:
			[allDataInBeta, bCmin, bCmax, bCres, nuMin, nuMax, nuRes, factorToBeAppliedToXRange]
		"

FindMinimumVarianceAndPrintCollapseParametersFromDiscreteScan::usage = 
		"
		FindMinimumVarianceAndPrintCollapseParametersFromDiscreteScan[collapseQualityScanOutput] is a 
		function to get the best collapse information. Its input is the output of the function
		MakeScanInBetaCAndNu.
		"

MakePlotOfScanSeparatingBlocksOfBetas::usage = 
		"
		MakePlotOfScanSeparatingBlocksOfBetas[collapseQualityScanOutput] is a function to get a graphic
		visualization of the scan done in \[Beta] and in \[Nu]. Its input is the output of the function
		MakeScanInBetaCAndNu and in the plot a line connecting all the points at the same beta will
		be drawn to help the eye.
		"

MinimizeNumericallyQualityOfCollapse::usage = 
		"
		This function minimizes the quality of the collapse of the given data in the given intervals.
		
		The output is a list in the form { \[Beta], \[Nu], varianceOfKurtosis, {\!\(\*SubscriptBox[\(x\), \(min\)]\), \!\(\*SubscriptBox[\(x\), \(max\)]\)}}

		There are 6 parameters to be specified:
			[allDataInBeta, bCmin, bCmax, nuMin, nuMax, factorToBeAppliedToXRange]
		"

FindCriticalParametersAndEstimateErrorsOnThemUsingEstimatorsUsingADiscreteScan::usage =
        "TODO: explain better!

		This function makes a scan in beta and nu in the given intervals and with given resolutions
		calculating for each set of parameters the quality of the collapse of the given data and estimators.
		Being the quality defined as the mean variance of the kurtosis among the different volumes,
		the lower it is the better is the collapse. Therefore, after each scan the parameters corresponding
		to the minimum variance are extracted and temporarily saved. This scan is repeated using the data 
		and the estimators. In particular, using the outcome of the scans done with the estimators an error
		on the final nu and on beta critical can be estimated (bootstrap).

		There are 9 parameters to be specified:
			[allDataInBeta, allEstimatorsInBeta, bCmin, bCmax, bCres, nuMin, nuMax, nuRes, factorToBeAppliedToXRange]

		NOTE: The data in beta must be in the form    { {{beta, kurtosis}}, volume }
			  while the estimators must be in the form { {{estimatorNumber, beta, kurtosis}}, volume }.
			  The factorToBeAppliedToXRange should be a real number bigger than 0 and less than
			  or equal to 1, which can be used to reduce the interval in the scaling variable
			  in which the collapse is done. By default, the interval in which the collapse is
			  done is the largest, symmetric interval around 0 in x common to all volumes!"

FindCriticalParametersAndEstimateErrorsOnThemUsingEstimatorsUsingAContinuousScan::usage =
        "TODO: explain better!

		This function finds numerically the values of \!\(\*SubscriptBox[\(\[Beta]\), \(c\)]\) and \[Nu] which gives the best quality of the collapse
		of the given data. Being the quality defined as the mean variance of the kurtosis among the different
		volumes, the lower it is the better is the collapse. This numerical minimization is repeated using the data 
		and the estimators. In particular, using the outcome of the calculation done with the estimators an error
		on the final \[Nu] and on \!\(\*SubscriptBox[\(\[Beta]\), \(c\)]\) can be estimated (bootstrap).

		There are 7 parameters to be specified:
			[allDataInBeta, allEstimatorsInBeta, bCmin, bCmax, nuMin, nuMax, factorToBeAppliedToXRange]

		NOTE: The data in beta must be in the form    { {{beta, kurtosis}}, volume }
			  while the estimators must be in the form { {{estimatorNumber, beta, kurtosis}}, volume }.
			  The factorToBeAppliedToXRange should be a real number bigger than 0 and less than
			  or equal to 1, which can be used to reduce the interval in the scaling variable
			  in which the collapse is done. By default, the interval in which the collapse is
			  done is the largest, symmetric interval around 0 in x common to all volumes!"

PrepareDataToBeExported::usage = 
		"
		PrepareDataToBeExported[data, numberPartition: 1] takes the data and puts them in
		exponential form with 12 decimal digits. A partition in groups of \"numberPartition\"
		elements is done if required.
		"

WriteResultsToFile::usage =
		"
		Function to write reult to a file. It needs 8 parameters
		
			[filename, results, bCmin, bCmax, bCres, nuMin, nuMax, nuRes]
		
		in order to produce an header into the file with the information about the scan.
		NOTE: The file filename is created (if not existing) in the Directory[] folder, while
			   the data are appended to it if existing.
		"

Begin["`Private`"]

$PrintFrontendOutput = False

xMap[b_,bC_,ns_,nu_]:=(b-bC)*ns^(1/nu)

x[dataInBeta_,bC_,nu_]:=xMap[dataInBeta[[1]][[All,1]],bC,dataInBeta[[2]],nu];

ConvertDataInBetaToDataInX[dataInBeta_,bC_,nu_]:= (*Here I drop the information on the volumes that is not needed anymore*)
	Module[{newData=dataInBeta},
		newData[[1]][[All,1]]=x[dataInBeta,bC,nu];
		Flatten[Drop[newData,{2}],1]
	]
xRangeCalc[allDataInX_]:=
	Module[{mins, maxs,deltaX},
		mins=Table[Min[data[[All,1]]],{data,allDataInX}];
		maxs=Table[Max[data[[All,1]]],{data,allDataInX}];
		deltaX=Min[Abs[{Max[mins],Min[maxs]}]];
		{-deltaX,deltaX}
	]

GetInterpolatedKurtosis[allDataInX_]:=
	Module[{interpolatedKurtosis},
		interpolatedKurtosis= Table[Interpolation[kurtosis],{kurtosis,allDataInX}];
		interpolatedKurtosis
	]

CalculateVarianceOfKurtosis[interpolatedKurtosis_,xRange_]:=
	Module[{xMin,xMax,deltaX,integral,numOfKurtosis},
		xMin=xRange[[1]];
		xMax=xRange[[2]];
		deltaX=xMax-xMin;
		numOfKurtosis=Length[interpolatedKurtosis];
		integral=NIntegrate[numOfKurtosis*Sum[f[x]^2,{f,interpolatedKurtosis}]-Sum[f[x],{f,interpolatedKurtosis}]^2,{x,xMin,xMax}];
		integral/deltaX
	]

GetVarianceOfKurtosisFromDataInBeta[allDataInBeta_,betaC_?NumericQ,nu_?NumericQ,factorToBeAppliedToXRange_]:=
	Module[{allDataInX,xRange, interpolatedKurtosis},
		allDataInX=Table[ConvertDataInBetaToDataInX[data,betaC,nu],{data,allDataInBeta}];
		xRange=factorToBeAppliedToXRange*xRangeCalc[allDataInX];
		interpolatedKurtosis=GetInterpolatedKurtosis[allDataInX];
		CalculateVarianceOfKurtosis[interpolatedKurtosis,xRange]
	]

GetQualityOfCollapseForFixedParameters[allDataInBeta_,betaC_,nu_,factorToBeAppliedToXRange_]:=
	Module[{varianceOfKurtosis,collapseQuality,collapseQualityScan,xRange},
		varianceOfKurtosis = GetVarianceOfKurtosisFromDataInBeta[allDataInBeta,betaC,nu,factorToBeAppliedToXRange];
		(*I calculate xRange also here to give it to collapseQuality as output*)
		xRange=factorToBeAppliedToXRange*xRangeCalc[Table[ConvertDataInBetaToDataInX[data,betaC,nu],{data,allDataInBeta}]]; 
		collapseQuality={betaC,nu,varianceOfKurtosis,xRange};
		collapseQuality
	]

MakeScanInBetaCAndNu[allDataInBeta_,bCmin_,bCmax_,bCres_,nuMin_,nuMax_,nuRes_,factorToBeAppliedToXRange_]:=
	Module[{varianceOfKurtosis,collapseQuality,collapseQualityScan,xRange},
		collapseQualityScan={};
		Do[
			AppendTo[collapseQualityScan,GetQualityOfCollapseForFixedParameters[allDataInBeta,bC,nu,factorToBeAppliedToXRange]];
		,{bC,bCmin,bCmax,bCres},{nu,nuMin,nuMax,nuRes}];
		collapseQualityScan
	]

FindMinimumVarianceAndPrintCollapseParametersFromDiscreteScan[collapseQualityScan_]:=
	Module[{minVariance,minVariancePosition},
		minVariance=Min[collapseQualityScan[[All,3]]];
		minVariancePosition=Position[collapseQualityScan[[All,3]],minVariance];
		Flatten[Extract[collapseQualityScan,minVariancePosition],1]
	]

MinimizeNumericallyQualityOfCollapse[allDataInBeta_,bCmin_,bCmax_,nuMin_,nuMax_,factorToBeAppliedToXRange_]:=
	Module[{bC,nu,collapseQuality},
		If[bCmin==bCmax && nuMin==nuMax,Print["MinimizeNumericallyQualityOfCollapse called with mins=maxs! Aborting..."];Abort[]];
		If[bCmin==bCmax,
			collapseQuality={NArgMin[{GetVarianceOfKurtosisFromDataInBeta[allDataInBeta,bCmin,nu,factorToBeAppliedToXRange],nuMin<nu<nuMax},nu]};
			PrependTo[collapseQuality,bCmin];
		];
		If[nuMin==nuMax,
			collapseQuality={NArgMin[{GetVarianceOfKurtosisFromDataInBeta[allDataInBeta,bC,nuMin,factorToBeAppliedToXRange],bCmin<bC<bCmax},bC]};
			AppendTo[collapseQuality,nuMin];
		];
		If[bCmin!=bCmax && nuMin!=nuMax,
			collapseQuality=NArgMin[{GetVarianceOfKurtosisFromDataInBeta[allDataInBeta,bC,nu,factorToBeAppliedToXRange],bCmin<bC<bCmax && nuMin<nu<nuMax},{bC,nu}];
		];
		(*Recalculate the quality of the collapse for minimizing parameters*)
		GetQualityOfCollapseForFixedParameters[allDataInBeta,collapseQuality[[1]],collapseQuality[[2]],factorToBeAppliedToXRange]
	]

(*To Plot the result of a discrete scan*)
GetQualitiesInNu[collapseQualityScan_]:=Partition[Flatten[Take[collapseQualityScan,{1,-1},{2,3}]],2];

MakePlotOfScanSeparatingBlocksOfBetas[collapseQualityScan_]:=
	Module[{numberOfNu,dataToPlot,legendLabels},
		numberOfNu=Count[collapseQualityScan[[All,1]],collapseQualityScan[[1,1]]];
		dataToPlot=GetQualitiesInNu[collapseQualityScan];
		legendLabels=Table["\[Beta]=" <> ToString[label],{label,DeleteDuplicates[collapseQualityScan[[All,1]]]}];
		ListLinePlot[Partition[dataToPlot,numberOfNu], PlotRange->{Automatic}, PlotLegends->legendLabels]
	]

(*From here on modules to make bootstrap on each data point*)
CalculateBootstrapError[list_]:=Sqrt[Total[(list-Mean[list])^2]/Length[list]];

BuildNewSetOfDataInBetaExtractingBlockOfDataFromEstimators[allEstimatorsInBeta_,blockNumber_]:=
	Module[{newData=allEstimatorsInBeta},
		Do[
			newData[[i,1]]=Drop[Select[newData[[i,1]],#[[1]]==blockNumber&],{},{1}];
			If[newData[[i,1]]=={},Print[StringForm["Tried to extract block `` from estimators, not found! Aborting...",blockNumber]];Abort[]];
		,{i,Length[newData]}];
		newData
	]

GetNumberOfEstimatorsToBeUsed[allEstimatorsInBeta_]:=
	Module[{numberOfEstimators},
		numberOfEstimators={};
		Do[
			AppendTo[numberOfEstimators,Length[DeleteDuplicates[allEstimatorsInBeta[[i,1]][[All,1]]]]];
		,{i,Length[allEstimatorsInBeta]}];
		If[Length[Union[numberOfEstimators]]!=1,MessageDialog["GetNumberOfEstimatorsToBeUsed::Found different number of estimators in estimator files! Using minimum number!"]];
		Min[numberOfEstimators]
	]

(*Function for final scan, two possibilities: discrete scan or using minimization of Mathematica*)
MyProgressBar[dyn:Dynamic[var_],start_,total_]:=PrintTemporary@Row[{ProgressIndicator[dyn,{start,total}]," ",Dynamic@NumberForm[100. var/total,{\[Infinity],2}],"% ",dyn}]

FindCriticalParametersAndEstimateErrorsOnThemUsingEstimatorsUsingADiscreteScan[allDataInBeta_,allEstimatorsInBeta_,bCmin_,bCmax_,bCres_,nuMin_,nuMax_,nuRes_,factorToBeAppliedToXRange_]:=
	Module[{centralValues,bootstrapList,errorsOnBeta,errorsOnNu,nBoot,tmpString,myProg,startIterationTime,timeString},
		If[$PrintFrontendOutput,
			Print[StringForm["Parameters of the scan: \!\(\*SubscriptBox[\(\[Beta]\), \(c\)]\)\[Element][``,``] with \[Delta]\[Beta]=``   \[Nu]\[Element][``,``] with \[Delta]\[Nu]=``   \[CapitalDelta]x=``*\[CapitalDelta]x_max",
				NumberForm[bCmin,Infinity],NumberForm[bCmax,Infinity],NumberForm[bCres,Infinity],
				NumberForm[nuMin,Infinity],NumberForm[nuMax,Infinity],NumberForm[nuRes,Infinity],NumberForm[factorToBeAppliedToXRange,Infinity]]
			],
			Print[StringForm["Parameters of the scan: betaC in [``,``] with deltaBetaC=``   nu in [``,``] with deltaNu=``   deltaX=``*deltaX_max",
				NumberForm[bCmin,Infinity],NumberForm[bCmax,Infinity],NumberForm[bCres,Infinity],
				NumberForm[nuMin,Infinity],NumberForm[nuMax,Infinity],NumberForm[nuRes,Infinity],NumberForm[factorToBeAppliedToXRange,Infinity]]
			]
		]
		If[$PrintFrontendOutput, tmpString=PrintTemporary["Working with central values..."]];
		startIterationTime=SessionTime[];
		centralValues=FindMinimumVarianceAndPrintCollapseParametersFromDiscreteScan[MakeScanInBetaCAndNu[allDataInBeta,bCmin,bCmax,bCres,nuMin,nuMax,nuRes,factorToBeAppliedToXRange]];
		If[$PrintFrontendOutput, NotebookDelete[tmpString]];
		Print[StringForm["Working with central values... done in ``s!",NumberForm[SessionTime[]-startIterationTime,Infinity]]];
		If[$PrintFrontendOutput, tmpString=PrintTemporary["Working on bootstrap estimators..."]];
		bootstrapList={};
		nBoot=GetNumberOfEstimatorsToBeUsed[allEstimatorsInBeta]-1;
		If[$PrintFrontendOutput, myProg=MyProgressBar[Dynamic[i],0,nBoot]];
		Do[
			startIterationTime=SessionTime[];
			AppendTo[bootstrapList,
			FindMinimumVarianceAndPrintCollapseParametersFromDiscreteScan[
				MakeScanInBetaCAndNu[
					BuildNewSetOfDataInBetaExtractingBlockOfDataFromEstimators[allEstimatorsInBeta,i],bCmin,bCmax,bCres,nuMin,nuMax,nuRes,factorToBeAppliedToXRange]
				]
			];
			If[$PrintFrontendOutput,
				NotebookDelete[timeString]; timeString=PrintTemporary[StringForm["Time to conclude iteration ``: ``",i,NumberForm[SessionTime[]-startIterationTime,Infinity]]],
				If[Mod[i,Floor[nBoot/10]]==0, Print[StringForm["Done `` iterations", i]]]
			];
		,{i,0,nBoot}];
		If[$PrintFrontendOutput, NotebookDelete[tmpString]];
		Print["Working on bootstrap estimators... done!"];
		If[$PrintFrontendOutput, NotebookDelete[myProg]; NotebookFind[SelectedNotebook[],"Print",All,CellStyle]];
		errorsOnBeta=CalculateBootstrapError[bootstrapList[[All,1]]];
		errorsOnNu=CalculateBootstrapError[bootstrapList[[All,2]]];
		{{centralValues[[1]],errorsOnBeta},{centralValues[[2]],errorsOnNu},centralValues[[4]]}
	]

FindCriticalParametersAndEstimateErrorsOnThemUsingEstimatorsUsingAContinuousScan[allDataInBeta_,allEstimatorsInBeta_,bCmin_,bCmax_,nuMin_,nuMax_,factorToBeAppliedToXRange_]:=
	Module[{centralValues,bootstrapList,errorsOnBeta,errorsOnNu,nBoot,tmpString,myProg,startIterationTime,timeString},
		Print[StringForm["Minimizing numerically for: \[Beta]\[Element][``,``]   and for  \[Nu]\[Element][``,``]   with   \[CapitalDelta]x=``*\[CapitalDelta]x_max",
			NumberForm[bCmin,Infinity],NumberForm[bCmax,Infinity],
			NumberForm[nuMin,Infinity],NumberForm[nuMax,Infinity],NumberForm[factorToBeAppliedToXRange,Infinity]]
		];
		tmpString=PrintTemporary["Working with central values..."];
		startIterationTime=SessionTime[];
		centralValues=MinimizeNumericallyQualityOfCollapse[allDataInBeta,bCmin,bCmax,nuMin,nuMax,factorToBeAppliedToXRange];
		NotebookDelete[tmpString]; PrintTemporary[StringForm["Working with central values... done in ``s!",NumberForm[SessionTime[]-startIterationTime,Infinity]]];
		tmpString=PrintTemporary["Working on bootstrap estimators..."];
		bootstrapList={};
		nBoot=GetNumberOfEstimatorsToBeUsed[allEstimatorsInBeta]-1;
		myProg=MyProgressBar[Dynamic[i],0,nBoot];
		Do[
			startIterationTime=SessionTime[];
			AppendTo[bootstrapList,MinimizeNumericallyQualityOfCollapse[
				BuildNewSetOfDataInBetaExtractingBlockOfDataFromEstimators[allEstimatorsInBeta,i],bCmin,bCmax,nuMin,nuMax,factorToBeAppliedToXRange]
			];
			NotebookDelete[timeString]; timeString=PrintTemporary[StringForm["Time to conclude iteration ``: ``",i,NumberForm[SessionTime[]-startIterationTime,Infinity]]];
		,{i,0,nBoot}];
		NotebookDelete[tmpString]; PrintTemporary["Working on bootstrap estimators... done!"];
		NotebookDelete[myProg];
		NotebookFind[SelectedNotebook[],"Print",All,CellStyle];
		errorsOnBeta=CalculateBootstrapError[bootstrapList[[All,1]]];
		errorsOnNu=CalculateBootstrapError[bootstrapList[[All,2]]];
		{{centralValues[[1]],errorsOnBeta},{centralValues[[2]],errorsOnNu},centralValues[[4]]}
	]

(*To format the data with fixed precision and exponent written in "e" form*)
Eform[x_?NumericQ,ndig_Integer: 8]:=
	Module[{u,s,p,base,exp,sign,result},
		u=If[x==0,u=0,u=x];
		{s,p}=MantissaExponent[u];
		If[s!=0,{s=s*10;p=p-1}];
		base=ToString[PaddedForm[s,{ndig+2,ndig}]];
		exp=If[p>=0,ToString[p],ToString[-1*p]];
		If[StringLength[exp]<2,exp=StringJoin["0",exp],exp=exp];
		sign=If[p>=0,"e+","e-"];result=StringJoin[base,sign,exp];
		result
	]

PrepareDataToBeExported[data_,numberPartition_: 1]:=
	Module[{list},
		list={data};(*This is to avoid the Flatten to fail in case a scalar is given and the N[] is to make Eform work also with integers*)
		Partition[Eform[N[#],12]&/@Flatten@list,numberPartition]
	]

(*Write result to file*)
WriteResultsToFile[filename_,results_,bCmin_,bCmax_,bCres_,nuMin_,nuMax_,nuRes_]:=
	Module[{myFile},
		SetDirectory[Directory[]];
		myFile=OpenAppend[filename];
		WriteString[myFile,StringForm["#Parameters of the scan: \t betaC in [``:``] with deltaBetaC=`` \t nu in [``:``] with deltaNu=``\n\n",
			NumberForm[bCmin,Infinity],NumberForm[bCmax,Infinity],Eform[bCres,2],
			NumberForm[nuMin,Infinity],NumberForm[nuMax,Infinity],Eform[nuRes,2]]
		];
		WriteString[myFile,"##      betaC                error_betaC                  nu                   error_nu                 xMin                    xMax\n"];
		Export[myFile,results];
		WriteString[myFile,StringForm["\n\n"]];
		Close[myFile];
	]

End[ ]

EndPackage[ ]



