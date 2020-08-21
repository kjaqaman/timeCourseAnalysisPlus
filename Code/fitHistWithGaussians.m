function [numObsPerBinP,binCenterP,modeParam,errFlag,fitRes] = ...
    fitHistWithGaussians(observations,alpha,variableMean,variableStd,...
    showPlot,numModeMinMax,binStrategy,plotName,logData,modeParamIn,ratioTol)
%FITHISTWITHGAUSSIANS determines the number of Gaussians + their characteristics to fit a histogram
%
%SYNOPSIS [numObsPerBinP,binCenterP,modeParam,errFlag,fitRes] = ...
%    fitHistWithGaussians(observations,alpha,variableMean,variableStd,...
%    showPlot,numModeMinMax,binStrategy,plotName,logData,modeParamIn,ratioTol)
%
%NOTE: "R" OPTION DISABLED AT THE MOMENT. CODE NEEDS UPDATING TO USE "R".
%    If/when "R" option is enabled (command potentially outdated too): 
%    [numObsPerBin,binCenter,modeParam,errFlag] = fitHistWithGaussians(...
%    observations,'R',showPlot,numModeMinMax)
%
%INPUT  observations: Vector of observations whose histogram is to be fitted.
%       alpha       : Alpha-value for the F-test that compares the
%                     fit of n+1 Gaussians to the fit of n Gaussians.
%                     If alpha=1, the BIC is used instead of the F-test to
%                     determine number of Gaussians.
%                     If 'R' instead of numerical value, the program will
%                     call the function mclust in the statistical package
%                     R. For this, you will need the toolbox matlab2R,
%                     a local installation of R with a COM interface, and
%                     Windows as OS. 'R' OPTION DISABLED AT THE MOMENT.
%       variableMean: Flag with potential values:
%                     - 0 if assuming the fixed relationship
%                     (mean of nth Gaussian) = n * (mean of 1st Gaussian).
%                     - 1 if there is no relationship between the means of
%                     different Gaussians.
%                     - 2, 3, etc. if assuming the same fixed relationship
%                     as 0 but that the first detected Gaussian is actually
%                     the 2nd, 3rd, etc. Gaussian in the relationship.
%                     - -2, -3, etc. if assuming a fixed relationship as 0
%                     but taking the 2nd, 3rd, etc. Gaussian as the
%                     reference, instead of the 1st. 
%                     Example: if variableMean = -2, and suppose mean of
%                     second Gaussian = M, then:
%                     mean of 1st Gaussian = M/2, mean of 3rd Gaussian = 3M/2, etc.
%                     This condition is identical to variableMean = 0
%                     (and will resort back to 0) if there is no wiggle
%                     room in the fit (i.e. ratioTol = 0 (see last input
%                     variable)).
%                     To apply this condition, the minimum number of
%                     Gaussians to fit = abs(variableMean).
%                     NOTE: TO PREVENT THIS CONDITION FROM GIVING
%                     NONSENSICAL RESULTS, THE MINIMUM FRACTION OF MODE 1
%                     IS CURRENTLY SET TO 0.3.
%                     Optional. Default: 0.
%       variableStd : Flag with potential values:
%                     - 0 if assuming that all Gaussians have the same
%                     standard deviation. 
%                     - 1 if there is no relationship
%                     between the standard deviations of different
%                     Gaussians.
%                     - 2 if assuming the relationship
%                     (std of nth Gaussian) = sqrt(n) * (std of 1st Gaussian).
%                     This relationship is generalized if variableMean > 1 or < -1.
%                     *** variableStd can equal 2 only if variableMean is
%                     not 1. ***
%                     - 3 if assuming the relationship
%                     (std of nth Gaussian) = n * (std of 1st Gaussian).
%                     This relationship is generalized if variableMean > 1 or < -1.
%                     *** variableStd can equal 3 only if variableMean is
%                     not 1. ***
%                     Optional. Default: 0.
%       showPlot    : 0 - to not plot anything
%                     1 - to plot the histogram and fitted Gaussians
%                     2 - like 1, but with smooth histogram.
%                     Optional. Default: 1.
%       numModeMinMax:Vector with minimum and maximum number of modes
%                     (Gaussian or log-normal) to fit. 
%                     Optional. Default: [1 9].
%                     If only one value is input, it will be taken as the
%                     maximum.
%       binStrategy : Binning strategy for calculating the cumulative
%                     histogram. 1 for using "histogram" and 2 for using
%                     the data directly.
%                     Optional. Default: 2.
%       plotName    : The title of the plotted figure.
%                     Optional. Default: 'Figure'.
%       logData     : 1 for log normal data, where the log(observations) is
%                     fitted, 0 otherwise. This option is not valid with 'R'.
%                     Optional. Default: 0.
%       modeParamIn : Matrix with number of rows equal to number of
%                     modes and two columns indicating the mean/M
%                     (Gaussian/lognormal) and standard deviation/S
%                     (Gaussian/lognormal) of each mode. If input, the
%                     specified mode parameters are used, and only the mode
%                     amplitudes are determined by data fitting. In this
%                     case, the input alpha, variableMean, variableStd
%                     and numModeMinMax are not used.
%                     Optional. Default: [].
%       ratioTol    : Tolerance for ratio between mean/std of reference Gaussian
%                     and mean/std of the other Gaussians. IMplemented for
%                     variableMean ~= 1 and variableStd = 1, 2 or 3.
%                     If 0, ratio is taken strictly.
%                     If > 0, ratio is allowed to wiggle by ratioTol about
%                     the theoretial ratio.
%                     If one entry, same value is used for both mean and
%                     std. If two entries, then first is for mean and
%                     second is for std.
%                     Example: If ratioTol = 0.1, then mean of 2nd Gaussian
%                     can vary between 1.9 and 2.1 of mean of 1st Gaussian
%                     (instead of exactly 2). Same holds for std.
%                     If ratioTol = [0.1 0.2], then mean can vary by 0.1
%                     and std by 0.2.
%                     Optional. Default: 0.
%
%OUTPUT numObsPerBin: Number of observations that fall in each bin.
%       binCenter   : Center of each bin.
%       modeParam   : Matrix with number of rows equal to number of fitted
%                     modes and four columns indicating (1) the mean/M
%                     (Gaussian/lognormal), (2) standard deviation/S
%                     (Gaussian/lognormal), (3) amplitude and (4) effective
%                     number of data points of each mode. A fifth column
%                     with an entry in the first row stores the mean square
%                     residual of the fit.
%       errFlag     : 0 if function executes normally, 1 otherwise.
%       fitRes      : Structure array with fitting results for the whole
%                     range of fitted Gaussians (from min to max). This is
%                     output in case user wants to post-process the fitting
%                     results in an application-specific manner outside of
%                     this function.
%
%REMARKS The fitted Gaussians are normalized. Thus, the contribution of one
%Gaussian is given by
%(modeParam(3)/(modeParam(2)*sqrt(2pi)))
%                     *exp(-(x-modeParam(1))^2/(2*modeParam(2)^2)
%
%        For larger samples, binning strategy 1 (using "histogram") works
%        better than binning strategy 2 (using the data directly), at
%        least when using the matlab option (not R).
%        "Better" means the following: 
%        I generated N(10,1) samples of size 500-200000 and applied the
%        code to them. For all samples, binning strategy 1 gave back 1
%        Gaussian as the best fit more often than binning strategy 2, which
%        often (~50% of the time) found at least 2 Gaussians.
%        With binning strategy 1, the following are "good" alpha-values
%        and the corresponding probability of getting back 1 Gaussian:
%        sample size        alpha-value
%            500            1e-2 (90%), 1e-3 (99%)
%          1,000            1e-3 (95%), 1e-4 (99%)
%         10,000            1e-4 (90%), 1e-5 (95%)
%         50,000            1e-6 (90%), 1e-8 (95%)
%        100,000            1e-6 (90%), 1e-8 (95%)
%        200,000            1e-7 (90%), 1e-10 (95%)
%
%
%NOTE ON VARIABLESTD FLAG (April 2015)
%Following Mutch et al. Biophys. J. 2007, especially concerning log-normal
%distributed intensities:
% *** Case of variableStd = 2 (std follows sqrt(n)) assumes that fluorophores
%are independent of each other and that their intensity distributions can
%be added. For this additive process, the std relative to the mean
%decreases with n.
% *** Case of variableStd = 3 (std follows n) assumes that the spread of
%fluorophore intensities is not only because of the fluorophore but also
%because of errors/noise in the measurement process. Since these
%errors/noise are always there, the distribution shape stays the same no
%matter the number of fluorophores. Hence in this case the std relative to
%the mean is independent of n. They call this a multiplied distribution or
%process.
%
%Khuloud Jaqaman, August 2006; major updates in 2014 and 2015
%
% Copyright (C) 2020, Jaqaman Lab - UT Southwestern 
%
% This file is part of timeCourseAnalysisPlus.
% 
% timeCourseAnalysisPlus is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% timeCourseAnalysisPlus is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with timeCourseAnalysisPlus.  If not, see <http://www.gnu.org/licenses/>.
% 
% 

%% Output

numObsPerBinP = [];
binCenterP = [];
modeParam = [];
errFlag = 0;

%% Input

%check whether correct number of input arguments was used
if nargin < 2
    disp('--fitHistWithGaussians: Incorrect number of input arguments!');
    errFlag = 1;
    return
else
    %make sure observations is a column vector
    observations = observations(:);
end

%this will obviously change if R option ever comes back
isR = false;

if alpha < 0 || alpha > 1
    disp('--fitHistWithGaussians: Variable "alpha" should be between 0 and 1!');
    errFlag = 1;
end

if nargin < 3 || isempty(variableMean)
    variableMean = 0;
end

if nargin < 4 || isempty(variableStd)
    variableStd = 0;
else
    if ~any(variableStd == [0,1,2,3])
        disp('--fitHistWithGaussians: Variable "variableStd" should be 0, 1, 2 or 3!');
        errFlag = 1;
    end
end

if nargin < 5 || isempty(showPlot)
    showPlot = 1;
else
    if ~any(showPlot == [0,1,2])
        disp('--fitHistWithGaussians: Variable "showPlot" should be 0, 1, or 2!');
        errFlag = 1;
    end
end

if nargin < 6 || isempty(numModeMinMax)
    minNumGauss = 1;
    maxNumGauss = 9;
else
    if any(numModeMinMax < 1)
        disp('--fitHistWithGaussians: Variable "numModeMinMax" should be at least 1!');
        errFlag = 1;
    end
    if length(numModeMinMax) > 1
        minNumGauss = numModeMinMax(1);
        maxNumGauss = numModeMinMax(2);
    else
        minNumGauss = 1;
        maxNumGauss = numModeMinMax;
    end
end

%this is the case where reference Gaussian is not 1st Gaussian
if variableMean < -1
    minNumGauss = max(minNumGauss,abs(variableMean));
    maxNumGauss = max(maxNumGauss,minNumGauss);
end

if nargin < 7 || isempty(binStrategy)
    binStrategy = 2;
else
    if ~any(binStrategy == [1,2])
        disp('--fitHistWithGaussians: Variable "binStrategy" should be 1 or 2!');
        errFlag = 1;
    end
end

if nargin < 8 || isempty(plotName)
    plotName = 'Figure';
end

if nargin < 9 || isempty(logData)
    logData = 0;
end
if logData && (variableMean==1&&variableStd~=1)
    disp('--fitHistWithGaussians: For log-normal fit, no current implementation for constrained std but variable mean. Exiting.')
    return
end

if nargin < 10 || isempty(modeParamIn)
    modeParamIn = [];
else
    minNumGauss = size(modeParamIn,1);
    maxNumGauss = minNumGauss;
    variableMean = -1;
    variableStd = -1;
    alpha = 1;
end

if nargin < 11 || isempty(ratioTol)
    ratioTol = 0;
elseif length(ratioTol) == 1
    ratioTol = ratioTol*[1 1];
end

if sum(ratioTol) == 0 && variableMean < -1
    disp('WARNING: Because ratioTol = 0, variableMean is reset to 0. For variableMean < -1 to have an impact, ratioTol should be > 0.');
    variableMean = 0;
end

% check error flag
if errFlag
    return
end

%convert data to log if log-normal distribution is fitted
if logData
    if (any(observations<=0))
        disp('WARNING: Some observations are not positive. Will ignore them to fit log-normal distribution.');
        observations = observations(observations>0);
    end
    observations0 = observations;
    observations = log(observations);
end

% %get rid of outliers in the observations vector
% [~,inlierIdx] = detectOutliers(observations,4);
% observations = observations(inlierIdx);

%% Histogram calculation and fitting

% ---------- SWITCH BETWEEN MATLAB AND R ---------------

switch binStrategy
    
    case 1 %use "histogram"
        
        %get the number of observations
        numObservations = length(find(~isnan(observations)));
        
        %calculate the histogram
        [numObsPerBin,binCenter] = optimalHistogram(observations);
        numObsPerBin = numObsPerBin'*(binCenter(2)-binCenter(1));
        binCenter = binCenter';
        
        %determine the number of bins used
        numBins = length(binCenter);
        
        %calculate the cumulative histogram
        cumHist = zeros(numBins,1);
        for iBin = 1 : numBins
            cumHist(iBin) = sum(numObsPerBin(1:iBin));
        end
        
    case 2
        
        % for the optimization: don't bin the cumulative histogram. However, don't
        % use duplicate values - therefore, use cdfcalc. It also returns the number
        % of non-NaN observations, and an error message, if any.
        [cumHist,binCenter,numObservations,errMsg] = cdfcalc(observations);
        if ~isempty(errMsg)
            % disp/return instead of throwing the error b/c of Khuloud's standard
            disp(sprintf('--%s',errMsg))
            return
        end
        
        % number of bins is the number of different x-values
        numBins = length(binCenter);
        % cdfcalc returns n+1 values for cumHist. 1:end-1 is the bottom of the
        % step, 2:end the top. Take the middle for best results.
        % cumHist = (cumHist(2:end)+cumHist(1:end-1))/2;
        
        % make cumHist with binCenters in middle of top of step
        binCenter = (binCenter(1:end-1)+binCenter(2:end))/2;
        cumHist = cumHist(2:end-1);
        numBins = numBins - 1;
        
        % downsample to about 1000 points if necessary
        if numBins > 1000
            dsIdx = unique(round(linspace(1,numBins,1000)))';
            cumHist = cumHist(dsIdx);
            binCenter = binCenter(dsIdx);
            numBins = length(dsIdx);
        end
        
        % make cumHist go from 1:numObservations
        cumHist = cumHist * numObservations;
        
end

%set some optimization options
options = optimset('MaxFunEvals',100000,'MaxIter',10000,'TolFun',1e-5,'Display','off');

%initialize structure of fitting results
fitRes = repmat(struct('numMode',NaN,'modeParam',[],'residuals',[],...
    'numParam',NaN,'numData',NaN,'numDegFree',NaN,...
    'valueBIC',NaN,'pValueFTest',NaN),maxNumGauss,1);

%fit the cumulative histogram with the whole range of number of Gaussians
for numGaussT = minNumGauss : maxNumGauss
    
    %assign parameter initial guesses
    tmp = prctile(observations,linspace(10,90,numGaussT+2));
    meanInitialGuess = tmp(2:end-1)';
    stdInitialGuess = nanstd(observations)/sqrt(numGaussT)*ones(numGaussT,1);
    ampInitialGuess = numObservations/numGaussT*ones(numGaussT,1);
    modeParamT = [meanInitialGuess stdInitialGuess ampInitialGuess];
    if ~isempty(modeParamIn)
        modeParamT(:,1:2) = modeParamIn;
    end
    
    %assign parameter lower bounds
    lb = [min(observations)*ones(numGaussT,1) zeros(numGaussT,1) zeros(numGaussT,1)];
    if variableMean < -1
        lb(1,3) = 0.3*length(observations);
    end
    
    %assign parameter upper bounds
    ub = [max(observations)*ones(numGaussT,1) 5*nanstd(observations)*ones(numGaussT,1) 2*numObservations*ones(numGaussT,1)];
    
    switch variableMean
        
        case -1 %if mean is given
            
            switch variableStd
                
                case -1 %if std is given
                    
                    %calculate number of parameters and number of degrees of freedom
                    numParamT = numGaussT;
                    numDegFreeT = numBins - numParamT;
                    
                    %assign parameter initial values
                    x0 = modeParamT(:,3);
                    
                    %assign lower and upper bounds
                    lb = lb(:,3);
                    ub = ub(:,3);
                    
                    %estimate unknown parameters
                    [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                        binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData,modeParamIn);
                    residualsT = -residualsT;
                    
                    %get output from parameters vector
                    modeParamT(:,3) = param;
                    
            end
            
        case 1 %if mean is variable
            
            switch variableStd
                
                case 0 %if std is constrained to all stds are equal
                    
                    %calculate number of parameters and number of degrees of freedom
                    numParamT = 2*numGaussT + 1;
                    numDegFreeT = numBins - numParamT;
                    
                    %assign parameter initial values
                    x0 = [modeParamT(:,1); modeParamT(1,2); modeParamT(:,3)];
                    
                    %assign lower and upper bounds
                    lb = [lb(:,1); lb(1,2); lb(:,3)];
                    ub = [ub(:,1); ub(1,2); ub(:,3)];
                    
                    %estimate unknown parameters
                    [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                        binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData);
                    residualsT = -residualsT;
                    
                    %get output from parameters vector
                    modeParamT(:,1) = param(1:numGaussT);
                    modeParamT(:,2) = repmat(param(numGaussT+1),numGaussT,1);
                    modeParamT(:,3) = param(numGaussT+2:end);
                    
                case 1 %if std is variable
                    
                    %calculate number of parameters and number of degrees of freedom
                    numParamT = 3*numGaussT;
                    numDegFreeT = numBins - numParamT;
                    
                    %assign parameter initial values
                    x0 = modeParamT(:);
                    
                    %assign lower and upper bounds
                    lb = lb(:);
                    ub = ub(:);
                    
                    %estimate unknown parameters
                    [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                        binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData);
                    residualsT = -residualsT;
                    
                    %get output from parameters vector
                    modeParamT = reshape(param,numGaussT,3);
                    
                case 2 %if std is constrained to std_n = sqrt(n)*std_1
                    
                    %inform user that this option is not valid
                    disp('--fitHistWithGaussians: variableStd can equal 2 only if variableMean ~= 1. Exiting.');
                    return
                    
                case 3 %if std is constrained to std_n = n*std_1
                    
                    %inform user that this option is not valid
                    disp('--fitHistWithGaussians: variableStd can equal 3 only if variableMean ~= 1. Exiting.');
                    return
                    
            end %(switch variableStd)
            
        otherwise %if mean is constrained to mean_n = n * mean_1 or, in general, there is a reference mode
            
            %get relationship of first fitted mode to real first
            %mode in series
            firstMode = max(variableMean,1);
            
            %determine reference mode and dependent modes
            refMode = max(abs(min(variableMean,1)),1);
            modes2replace = setdiff(1:numGaussT,refMode);

            %determine mode multiplier series, depending on first mode
            %and reference mode
            multiplierSeries = (firstMode:numGaussT+firstMode-1)'/refMode;
            
            switch variableStd
                
                case 0 %if std is constrained to all stds are equal
                    
                    %calculate number of parameters and number of degrees of freedom
                    numParamT = numGaussT + 2;
                    numDegFreeT = numBins - numParamT;
                    
                    %assign parameter initial values
                    x0 = [modeParamT(1,1:2)'; modeParamT(:,3)];
                    
                    %assign lower and upper bounds
                    lb = [lb(1,1:2)'; lb(:,3)];
                    ub = [ub(1,1:2)'; ub(:,3)];
                    
                    %estimate unknown parameters
                    [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                        binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData);
                    residualsT = -residualsT;
                    
                    %get output from parameters vector
                    if ~logData
                        tmpMean = param(1) / firstMode;
                        modeParamT(:,1) = (firstMode:numGaussT+firstMode-1)' * tmpMean;
                        modeParamT(:,2) = repmat(param(2),numGaussT,1);
                    else
                        dataMean1 = exp(param(1)+param(2)^2/2);
                        dataMean1 = dataMean1 / firstMode;
                        dataVar1 = exp(param(2)^2+2*param(1))*(exp(param(2)^2)-1);
                        dataMeanN = (firstMode:numGaussT+firstMode-1)'*dataMean1;
                        dataVarN = repmat(dataVar1,numGaussT,1);
                        modeParamT(:,1) = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
                        modeParamT(:,2) = sqrt(log(dataVarN./dataMeanN.^2+1));
                    end
                    modeParamT(:,3) = param(3:end);
                    
                case 1 %if std is variable
                    
                    if sum(ratioTol) == 0 %if strict ratio
                        
                        %calculate number of parameters and number of degrees of freedom
                        numParamT = 2*numGaussT + 1;
                        numDegFreeT = numBins - numParamT;
                        
                        %assign parameter initial values
                        x0 = [modeParamT(1,1); modeParamT(:,2); modeParamT(:,3)];
                        
                        %assign lower and upper bounds
                        lb = [lb(1,1); lb(:,2); lb(:,3)];
                        ub = [ub(1,1); ub(:,2); ub(:,3)];
                        
                        %estimate unknown parameters
                        [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                            binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData);
                        residualsT = -residualsT;
                        
                        %get output from parameters vector
                        if ~logData
                            tmpMean = param(1) / firstMode;
                            modeParamT(:,1) = (firstMode:numGaussT+firstMode-1)' * tmpMean;
                        else
                            dataMean1 = exp(param(1)+param(2)^2/2);
                            dataMean1 = dataMean1 / firstMode;
                            dataMeanN = (firstMode:numGaussT+firstMode-1)' * dataMean1;
                            modeParamT(:,1) = log(dataMeanN) - param(2:numGaussT+1).^2/2;
                        end
                        modeParamT(:,2:3) = reshape(param(2:end),numGaussT,2);
                        
                    else %if there is wiggle room
                        
                        %calculate number of parameters and number of degrees of freedom
                        numParamT = 3*numGaussT;
                        numDegFreeT = numBins - numParamT;
                        
                        %assign parameter initial values
                        x0 = modeParamT;
                        x0(modes2replace,1) = multiplierSeries(modes2replace);
                        
                        %assign lower and upper bounds
                        lb(modes2replace,1) = x0(modes2replace,1) - ratioTol(1);
                        ub(modes2replace,1) = x0(modes2replace,1) + ratioTol(1);
                        
                        %convert to vectors
                        x0 = x0(:);
                        lb = lb(:);
                        ub = ub(:);
                        
                        %estimate unknown parameters
                        [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                            binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData,[],ratioTol);
                        residualsT = -residualsT;
                        
                        %get output from parameters vector
                        param = reshape(param,numGaussT,3);
                        if ~logData
                            tmpMean = param(refMode,1) / firstMode;
                            modeParamT(modes2replace,1) = param(modes2replace,1) * tmpMean;
                        else
                            dataMeanRef = exp(param(refMode,1)+param(refMode,2)^2/2);
                            dataMeanRef = dataMeanRef / firstMode;
                            dataMeanN = param(modes2replace,1) * dataMeanRef;
                            modeParamT(modes2replace,1) = log(dataMeanN) - param(modes2replace,2).^2/2;
                        end
                        modeParamT(refMode,1) = param(refMode,1);
                        modeParamT(:,2:3) = param(:,2:3);
                        
                    end
                    
                case 2 %if std is constrained to std_n = sqrt(n)*std_1
                    
                    if sum(ratioTol) == 0 %if strict ratio
                        
                        %calculate number of parameters and number of degrees of freedom
                        numParamT = numGaussT + 2;
                        numDegFreeT = numBins - numParamT;
                        
                        %assign parameter initial values
                        x0 = [modeParamT(1,1:2)'; modeParamT(:,3)];
                        
                        %assign lower and upper bounds
                        lb = [lb(1,1:2)'; lb(:,3)];
                        ub = [ub(1,1:2)'; ub(:,3)];
                        
                        %estimate unknown parameters
                        [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                            binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData);
                        residualsT = -residualsT;
                        
                        %get output from parameters vector
                        if ~logData
                            tmpMean = param(1) / firstMode;
                            modeParamT(:,1) = (firstMode:numGaussT+firstMode-1)' * tmpMean;
                            tmpStd = param(2) / sqrt(firstMode);
                            modeParamT(:,2) = sqrt(firstMode:numGaussT+firstMode-1)' * tmpStd;
                        else
                            dataMean1 = exp(param(1)+param(2)^2/2);
                            dataMean1 = dataMean1 / firstMode;
                            dataVar1 = exp(param(2)^2+2*param(1))*(exp(param(2)^2)-1);
                            dataVar1 = dataVar1 / firstMode;
                            dataMeanN = (firstMode:numGaussT+firstMode-1)' * dataMean1;
                            dataVarN = (firstMode:numGaussT+firstMode-1)' * dataVar1;
                            modeParamT(:,1) = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
                            modeParamT(:,2) = sqrt(log(dataVarN./dataMeanN.^2+1));
                        end
                        modeParamT(:,3) = param(3:end);
                        
                    else %if there is wiggle room
                        
                        %calculate number of parameters and number of degrees of freedom
                        numParamT = 3*numGaussT;
                        numDegFreeT = numBins - numParamT;
                        
                        %assign parameter initial values
                        x0 = modeParamT;
                        x0(modes2replace,1) = multiplierSeries(modes2replace);
                        x0(modes2replace,2) = multiplierSeries(modes2replace);
                        
                        %assign lower and upper bounds
                        lb(modes2replace,1) = x0(modes2replace,1) - ratioTol(1);
                        lb(modes2replace,2) = x0(modes2replace,2) - ratioTol(2);
                        ub(modes2replace,1) = x0(modes2replace,1) + ratioTol(1);
                        ub(modes2replace,2) = x0(modes2replace,2) + ratioTol(2);
                        
                        %convert to vectors
                        x0 = x0(:);
                        lb = lb(:);
                        ub = ub(:);
                        
                        %estimate unknown parameters
                        [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                            binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData,[],ratioTol);
                        residualsT = -residualsT;
                        
                        %get output from parameters vector
                        param = reshape(param,numGaussT,3);
                        if ~logData
                            tmpMean = param(refMode,1) / firstMode;
                            modeParamT(modes2replace,1) = param(modes2replace,1) * tmpMean;
                            tmpStd = param(refMode,2) / sqrt(firstMode);
                            modeParamT(modes2replace,2) = sqrt(param(modes2replace,2)) * tmpStd;
                        else
                            dataMeanRef = exp(param(refMode,1)+param(refMode,2)^2/2);
                            dataMeanRef = dataMeanRef / firstMode;
                            dataVarRef = exp(param(refMode,2)^2+2*param(refMode,1))*(exp(param(refMode,2)^2)-1);
                            dataVarRef = dataVarRef / firstMode;
                            dataMeanN = param(modes2replace,1) * dataMeanRef;
                            dataVarN = param(modes2replace,2) * dataVarRef;
                            modeParamT(modes2replace,1) = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
                            modeParamT(modes2replace,2) = sqrt(log(dataVarN./dataMeanN.^2+1));
                        end
                        modeParamT(refMode,1:2) = param(refMode,1:2);
                        modeParamT(:,3) = param(:,3);
                        
                    end
                    
                case 3 %if std is constrained to std_n = n*std_1
                    
                    if sum(ratioTol) == 0 %if strict ratio
                        
                        %calculate number of parameters and number of degrees of freedom
                        numParamT = numGaussT + 2;
                        numDegFreeT = numBins - numParamT;
                        
                        %assign parameter initial values
                        x0 = [modeParamT(1,1:2)'; modeParamT(:,3)];
                        
                        %assign lower and upper bounds
                        lb = [lb(1,1:2)'; lb(:,3)];
                        ub = [ub(1,1:2)'; ub(:,3)];
                        
                        %estimate unknown parameters
                        %KJ: Do not use Jacobian for now. Must check and
                        %potentially generalize.
                        %                         options.Jacobian = 'on';
                        %                         options.DerivativeCheck = 'on';
                        [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                            binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData);
                        residualsT = -residualsT;
                        
                        %get output from parameters vector
                        if ~logData
                            tmpMean = param(1) / firstMode;
                            modeParamT(:,1) = (firstMode:numGaussT+firstMode-1)' * tmpMean;
                            tmpStd = param(2) / firstMode;
                            modeParamT(:,2) = (firstMode:numGaussT+firstMode-1)' * tmpStd;
                        else
                            dataMean1 = exp(param(1)+param(2)^2/2);
                            dataMean1 = dataMean1 / firstMode;
                            dataVar1 = exp(param(2)^2+2*param(1))*(exp(param(2)^2)-1);
                            dataVar1 = dataVar1 / (firstMode^2);
                            dataMeanN = (firstMode:numGaussT+firstMode-1)' * dataMean1;
                            dataVarN = (firstMode:numGaussT+firstMode-1)'.^2 * dataVar1;
                            modeParamT(:,1) = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
                            modeParamT(:,2) = sqrt(log(dataVarN./dataMeanN.^2+1));
                        end
                        modeParamT(:,3) = param(3:end);
                        
                    else %if there is wiggle room
                        
                        %calculate number of parameters and number of degrees of freedom
                        numParamT = 3*numGaussT;
                        numDegFreeT = numBins - numParamT;
                        
                        %assign parameter initial values
                        x0 = modeParamT;
                        x0(modes2replace,1) = multiplierSeries(modes2replace);
                        x0(modes2replace,2) = multiplierSeries(modes2replace);
                        
                        %assign lower and upper bounds
                        lb(modes2replace,1) = x0(modes2replace,1) - ratioTol(1);
                        lb(modes2replace,2) = x0(modes2replace,2) - ratioTol(2);
                        ub(modes2replace,1) = x0(modes2replace,1) + ratioTol(1);
                        ub(modes2replace,2) = x0(modes2replace,2) + ratioTol(2);
                        
                        %convert to vectors
                        x0 = x0(:);
                        lb = lb(:);
                        ub = ub(:);
                        
                        %estimate unknown parameters
                        [param,~,residualsT] = lsqcurvefit(@calcCumDistrNGauss,x0,...
                            binCenter,cumHist,lb,ub,options,variableMean,variableStd,logData,[],ratioTol);
                        residualsT = -residualsT;
                        
                        %get output from parameters vector
                        param = reshape(param,numGaussT,3);
                        if ~logData
                            tmpMean = param(refMode,1) / firstMode;
                            modeParamT(modes2replace,1) = param(modes2replace,1) * tmpMean;
                            tmpStd = param(refMode,2) / firstMode;
                            modeParamT(modes2replace,2) = param(modes2replace,2) * tmpStd;
                        else
                            dataMeanRef = exp(param(refMode,1)+param(refMode,2)^2/2);
                            dataMeanRef = dataMeanRef / firstMode;
                            dataVarRef = exp(param(refMode,2)^2+2*param(refMode,1))*(exp(param(refMode,2)^2)-1);
                            dataVarRef = dataVarRef / (firstMode^2);
                            dataMeanN = param(modes2replace,1) * dataMeanRef;
                            dataVarN = param(modes2replace,2).^2 * dataVarRef;
                            modeParamT(modes2replace,1) = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
                            modeParamT(modes2replace,2) = sqrt(log(dataVarN./dataMeanN.^2+1));
                        end
                        modeParamT(refMode,1:2) = param(refMode,1:2);
                        modeParamT(:,3) = param(:,3);
                        
                    end
                    
            end %(switch variableStd)
            
    end %(switch variableMean)
    
    %calculate BIC value for this fit
    valueBIC = numBins*log(sum(residualsT.^2)/numBins) + log(numBins)*numParamT;
    
    %calculate F-test p-value from comparing this fit to previous one
    if numGaussT == minNumGauss
        
        pValueFTest = 0; %give fake p-value of 0, as at least first fit should be accepted in this scheme
        
    else
        
        %get test statistic, which is F-distributed
        testStat = (sum(residualsT.^2)/numDegFreeT)/...
            (sum(fitRes(numGaussT-1).residuals.^2)/fitRes(numGaussT-1).numDegFree);
        
        %get p-value of test statistic
        pValueFTest = fcdf(testStat,fitRes(numGaussT-1).numDegFree,numDegFreeT);
        
    end
    
    %save results of this fit
    fitRes(numGaussT).numMode     = numGaussT;
    fitRes(numGaussT).modeParam   = modeParamT;
    fitRes(numGaussT).residuals   = residualsT;
    fitRes(numGaussT).numParam    = numParamT;
    fitRes(numGaussT).numData     = numBins;
    fitRes(numGaussT).numDegFree  = numDegFreeT;
    fitRes(numGaussT).valueBIC    = valueBIC;
    fitRes(numGaussT).pValueFTest = pValueFTest;
    
    
end %(for numGaussT = minNumGauss : maxNumGauss)

%determine the best model
if alpha == 1 %BIC
    valueBIC = vertcat(fitRes.valueBIC);
    indxBestFit = find(valueBIC == min(valueBIC));
else %F-test
    pValueFTest = vertcat(fitRes.pValueFTest);
    indxBestFit = find(pValueFTest>alpha,1,'first') - 1;
    if isempty(indxBestFit)
        indxBestFit = maxNumGauss;
    end
end

%output its parameters
numGauss = fitRes(indxBestFit).numMode;
modeParam = fitRes(indxBestFit).modeParam;
residuals = fitRes(indxBestFit).residuals;
numDegFree = fitRes(indxBestFit).numDegFree;

%order the Gaussians in ascending value of the mean
gaussMeans = modeParam(:,1);
[~,orderIndx] = sort(gaussMeans);
modeParam = modeParam(orderIndx,:);

%calculate the effective number of datapoints falling in each mode
for iMode = 1 : size(modeParam,1)
    modeParam(iMode,4) = modeParam(iMode,3)*...
        ( normcdf(max(observations),modeParam(iMode,1),modeParam(iMode,2)) ...
        - normcdf(min(observations),modeParam(iMode,1),modeParam(iMode,2)) );
end

%append the sum of squared residuals / # degrees of freedom to
%the first row of modeParam
if ~isR
    modeParam(1,end+1) = sum(residuals.^2) / numDegFree;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plotting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%revert back to actual data in case of log-normal
if logData
    observations = observations0;
end

% make a histogram for plotting and output. Choose how to calculate bins
if showPlot == 2
    [numObsPerBinP,binCenterP] = optimalHistogram(observations,'smooth');
    numObsPerBinP = numObsPerBinP*(binCenterP(2)-binCenterP(1));
elseif showPlot ~= 0
    [numObsPerBinP,binCenterP] = optimalHistogram(observations);
    if length(binCenterP)<20
        [numObsPerBinP,binCenterP] = hist(observations,20);
        numObsPerBinP = numObsPerBinP/(binCenterP(2)-binCenterP(1));
    end
    numObsPerBinP = numObsPerBinP*(binCenterP(2)-binCenterP(1));
end

%if the user wants to plot
if showPlot
    
    %get the distribution from the optimized parameters
    %     distrNGauss = zeros(size(binCenterP));
    distrIndGauss = zeros(numGauss,length(binCenterP));
    for i=1:numGauss
        % no longer multiply by the bin width - histograms is normed now
        if ~logData
            distrIndGauss(i,:) = modeParam(i,3)*normpdf(binCenterP,...
                modeParam(i,1),modeParam(i,2))*(binCenterP(2)-binCenterP(1));
        else
            distrIndGauss(i,:) = modeParam(i,3)*lognpdf(binCenterP,...
                modeParam(i,1),modeParam(i,2))*(binCenterP(2)-binCenterP(1));
        end
    end
    distrNGauss = sum(distrIndGauss,1);
    
    %get the cumulative distribution from the optimized parameters
    cumDistrNGauss = zeros(size(binCenter));
    for i=1:numGauss
        %         if ~logData
        cumDistrNGauss = cumDistrNGauss + modeParam(i,3)*normcdf(binCenter,...
            modeParam(i,1),modeParam(i,2));
        %         else
        %             cumDistrNGauss = cumDistrNGauss + modeParam(i,3)*logncdf(binCenter,...
        %                 modeParam(i,1),modeParam(i,2));
        %         end
    end
    
    %make new figure
    if isempty(plotName)
        figure
    else
        figure('Name',plotName,'NumberTitle','off')
    end
    
    %plot the histogram and the fitted Gaussians in the left half of the
    %figure. Correct by the number of NaNs
    subplot(1,2,1);
    bar(binCenterP,numObsPerBinP,'k')
    hold on
    for i = 1 : numGauss
        plot(binCenterP,distrIndGauss(i,:) * sum(isfinite(observations))/...
            numObservations,'g--','LineWidth',2.5)
    end
    plot(binCenterP,distrNGauss * sum(isfinite(observations))/...
        numObservations,'r','LineWidth',2.5)
    xlabel('Observation values')
    ylabel('Counts')
    
    %plot the cumulative histogram and the fitted Gaussians in the right
    %half of the figure
    subplot(1,2,2);
    if ~logData
        plot(binCenter,cumHist,'k.')
        hold on
        plot(binCenter,cumDistrNGauss,'r','LineWidth',2.5)
        xlabel('Observation values')
        ylabel('Cumulative counts')
    else
        plot(exp(binCenter),cumHist,'k.')
        hold on
        plot(exp(binCenter),cumDistrNGauss,'r','LineWidth',2.5)
        xlabel('Observation values')
        ylabel('Cumulative counts')
    end
    
end %(if showPlot)

%%%%% ~~ the end ~~ %%%%%


%OLD R STUFF THAT IS OUTDATED

%function setup part

% % Check whether to use the matlab routine or R
% switch isnumeric(alpha)
%     case 1

%     case 0 % alpha is not numeric
%
%         plotName = []; %this is to avoid a code crash
%
%         isR = true;
%
%         if strmatch(alpha,'R')
%             % check whether we are on windows, and try to launch R
%             if ispc
%                 try
%                     status = openR;
%                 catch
%                     disp('--fitHistWithGaussians: unable to launch R');
%                     errFlag = 1;
%                 end
%                 if ~status
%                     disp('--fitHistWithGaussians: unable to launch R');
%                     errFlag = 1;
%                 else
%                     leaveRopen = false;
%                 end
%             else
%                 disp('--fitHistWithGaussians: ''R'' needs the COM interface and therefore only runs under Windows');
%                 errFlag = 1;
%             end
%         else
%             disp('--fitHistWithGaussians: unknown option for second input');
%             errFlag = 1;
%         end
%         
%         % check for display and numModeMinMaxians
%         % variableMean ~showPlot
%         if nargin < 3 || isempty(variableMean)
%             showPlot = 1;
%         else
%             if ~any(variableMean == [0,1,2])
%                 disp('--fitHistWithGaussians: Variable "showPlot" should be either 0, 1, or 2!');
%                 errFlag = 1;
%             else
%                 showPlot = variableMean;
%             end
%         end
%         % variableStd ~numModeMinMax
%         if nargin < 4 || isempty(variableStd)
%             numModeMinMax = 9;
%             minNumGauss = 1;
%         else
%             numModeMinMax = variableStd;
%             if length(numModeMinMax) > 1
%                 minNumGauss = numModeMinMax(1);
%                 numModeMinMax = numModeMinMax(2);
%             else
%                 minNumGauss = 1;
%             end
%             if numModeMinMax < 1
%                 disp('--fitHistWithGaussians: Variable "numModeMinMaxians" should be at least 1');
%                 errFlag = 1;
%             end
%         end
% 
% end % switch


%actual fitting part

% switch isR
%     
%     case 0 % run Matlab
        


%         % ----- R ------
%     case 1
%         % check if downsampling necessary - cap at 1000 observations
%         numObservations = length(observations);
%         % remove NaN, Inf
%         observationsC = observations;
%         observationsC(~isfinite(observationsC)) = [];
%         numObservationsC = length(observationsC);
%         if  numObservationsC > 1000
%             observationsDS = sort(observationsC);
%             observationsDS = observationsDS(round(linspace(1,numObservationsC,1000)));
%         else
%             observationsDS = observationsC;
%         end
%         clear observationsC
%         
%         % run R (it's already open)
%         
%         % load mclust
%         evalR('library(mclust)')
%         
%         % put observations into R
%         putRdata('inputData',observationsDS);
%         
%         % run Mclust - they have changed the syntax since the last version!
%         try
%             % new version
%             evalR(sprintf('clusterData <- Mclust(inputData,G=%i:%i)',minNumGauss,numModeMinMax))
%             % read mu, sigma, and probabilities (which will give amplitudes
%             % when multiplied by the number of observations)
%             mu = evalR('clusterData$parameters$mean');
%             sigma = sqrt(evalR('clusterData$parameters$variance$sigmasq'));
%             numGauss = length(mu);
%             if numGauss == 1
%                 amp = numObservations;
%             else
%                 amp = evalR('clusterData$parameters$pro')*numObservations;
%             end
%             
%         catch
%             try
%                 % old version
%                 evalR(sprintf('clusterData <- Mclust(inputData,%i,%i)',minNumGauss,numModeMinMax))
%                 % read mu, sigma, and probabilities (which will give amplitudes
%                 % when multiplied by the number of observations)
%                 mu = evalR('clusterData$mu');
%                 sigma = sqrt(evalR('clusterData$sigma'));
%                 % take care of possible equal sigma
%                 if length(sigma) == 1
%                     sigma = repmat(sigma,1,length(mu));
%                 end
%                 if length(mu) == 1
%                     amp = numObservations;
%                 else
%                     amp = evalR('clusterData$pro')*numObservations;
%                 end
%                 numGauss = length(mu);
%             catch
%                 rethrow(lasterror)
%             end
%         end
%         
%         % check the number of sigmas
%         if length(sigma) ~= numGauss
%             sigma = sigma * ones(1,numGauss);
%         end
%         
%         % catenate into modeParam
%         modeParam = [mu',sigma',amp'];
%         
%         
%         
%         % close R
%         if ~leaveRopen
%             closeR
%         end
%         
% end


%this was in plotting subfunction

%     if isR
%         [cumHist,binCenter] = cdfcalc(observations);
%         binCenter = (binCenter(1:end-1)+binCenter(2:end))/2;
%         cumHist = cumHist(2:end-1) * numObservations;
%     end
    
