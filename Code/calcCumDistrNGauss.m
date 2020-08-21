function [cumDistrNGauss,J] = calcCumDistrNGauss(param,abscissa,variableMean,...
    variableStd,logData,gaussParamIn,ratioTol)
%CALCCUMDISTRNGAUSS calculates the cumulative distribution of N Gaussians
%
%SYNOPSIS cumDistrNGauss = calcCumDistrNGauss(param,abscissa,variableMean,...
%     variableStd,logData,gaussParamIn)
%
%INPUT  param       : Vector of parameters indicating the means,
%                     stds and amplitudes of the N Gaussians.
%       abscissa    : Abscissa values at which the cumulative
%                     distribution is calculated.
%       variableMean: Flag with potential values:
%                     - 0 if assuming the fixed relationship
%                     (mean of nth Gaussian) = n * (mean of 1st Gaussian).
%                     - 1 if there is no relationship between the means of
%                     different Gaussians.
%                     - 2, 3, etc. if assuming the same fixed relationship
%                     as 0 but that the first detected Gaussian is actually
%                     the 2nd, 3rd, etc. Gaussian in the relationship.
%                     Optional. Default: 1.
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
%                     Gaussians to fit  = abs(variableMean).
%                     Optional. Default: 1.
%       variableStd : Flag with potential values:
%                     - 0 if assuming that all Gaussians have the same
%                     standard deviation. 
%                     - 1 if there is no relationship
%                     between the standard deviations of different
%                     Gaussians.
%                     - 2 if assuming the relationship
%                     (std of nth Gaussian) = sqrt(n) * (std of 1st Gaussian).
%                     This relationship is generalized if variableMean > 1.
%                     *** variableStd can equal 2 only if variableMean is
%                     not 1. ***
%                     - 3 if assuming the relationship
%                     (std of nth Gaussian) = n * (std of 1st Gaussian).
%                     This relationship is generalized if variableMean > 1.
%                     *** variableStd can equal 3 only if variableMean is
%                     not 1. ***
%                     Optional. Default: 1.
%       logData     : 1 for log normal data, where the log(data) is being
%                     fitted to a normal distribution, 0 otherwise. Note
%                     that data are passed to this function already after
%                     taking the log.
%                     Optional. Default: 0.
%       gaussParamIn: Matrix with number of rows equal to number of
%                     modes and two columns indicating the mean and
%                     standard deviation of each mode. If input, the
%                     specified mode parameters are used, and only the
%                     mode amplitudes are determined by data fitting. In
%                     this case, the input variableMean and variableStd
%                     are not used.
%                     Optional. Default: [].
%       ratioTol    : Tolerance for ratio between mean/std of reference Gaussian
%                     and mean/std of the other Gaussians. Applies to cases
%                     where variableMean~=1 and variableStd = 1, 2 or 3.
%                     If 0, ratio is taken strictly.
%                     If > 0, ratio is allowed to wiggle by ratioTol about
%                     the theoretial ratio. 
%                     If one entry, same value is used for both mean and
%                     std. If two entries, then first is for mean and
%                     second is for std.
%                     Optional. Default: 0.
%
%OUTPUT cumDistrNGauss: Values of the resulting cumulative distribution
%                       given the input abscissa values.
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
% cumDistrNGauss    : cumulative sum of N gaussians, same size as abscissa
% J                 : Jacobian, length(absicissa) x length(param)

cumDistrNGauss = [];

%% Input

%check whether correct number of input arguments was used
if nargin < 2
    disp('--calcCumDistrNGauss: Incorrect number of input arguments!');
    return
end

if nargin < 3 || isempty(variableMean)
    variableMean = 1;
end

if nargin < 4 || isempty(variableStd)
    variableStd = 1;
end

if nargin < 5 || isempty(logData)
    logData = 0;
end
if logData && (variableMean==1&&variableStd~=1)
    disp('--fitHistWithGaussians: For log-normal fit, no current implementation for constrained std but variable mean. Exiting.')
    return
end

if nargin < 6 || isempty(gaussParamIn)
    gaussParamIn = [];
else
    variableMean = -1;
    variableStd = -1;
end

if nargin < 7 || isempty(ratioTol)
    ratioTol = 0;
elseif length(ratioTol) == 1
    ratioTol = ratioTol*[1 1];
end

%% Calculating the cumulative distribution

%get the means, standard deviations and amplitudes of the Gaussians from the input
%parameter vector

%% Encode the case so that logic branches are now flat

% caseCode in decimal: MSLR
caseCode =  (variableMean == 1)*1000 + variableStd*100 + logData*10 + (sum(ratioTol)~=0);

%get relationship of first fitted Gaussian to real first Gaussian in series
firstGauss = max(variableMean,1);

%determine reference Gaussian
refGauss = max(abs(min(variableMean,1)),1);

% mu_n    = mean of nth normal distribution
% sigma_n = standard deviation of nth normal distribution
% A_n     = amplitude of nth normal distribution
% n       = index of normal distribution in range between
%           firstGauss and N+firstGauss-1
% N       = number of normal distributions (numGauss)



switch caseCode
    
%% Fixed mean and std

    case {-100,-110} % fixed mean, fixed std, normal or lognormal
        
        % param = [A_1 ... A_N]'
        % size(param) == [N 1];
        
        %get number of Gaussians
        numGauss = length(param);
        
        %get their means, stds and amplitudes
        gaussMean = gaussParamIn(:,1);
        gaussStd  = gaussParamIn(:,2);
        gaussAmp  = param;
        
%% Variable mean

    case {1000,1010} % variable mean, equal stds, normal or lognormal
        
        % param = [mu_1 ... mu_N, sigma, amp_1 ... amp_N]
        % size(param) == [2*N+1 1];
        % all gaussians have the same standard deviation

        %get number of Gaussians
        numGauss = floor(length(param)/2);
        
        %get their means, stds and amplitudes
        gaussMean = param(1:numGauss);
        gaussStd  = repmat(param(numGauss+1),numGauss,1);
        gaussAmp  = param(numGauss+2:end);
        
    case {1100,1110} % variable mean, variable std, normal or lognormal
        
        % param = [mu_1, sigma_1, A_1 ; ... ; mu_N, sigma_N, A_N]
        % size(param) == [N 3]

        %get number of Gaussians
        numGauss = length(param)/3;
        
        %get their means, stds and amplitudes
        gaussMean = param(1:numGauss);
        gaussStd  = param(numGauss+1:2*numGauss);
        gaussAmp  = param(2*numGauss+1:end);
        
%% Constrained mean

    case 0000 % constrained mean, equal stds, normal
        
        % param = [mu_1, sigma_1, A_1, ..., A_N]';
        % size(param) = [2+N 1];
        
        %get number of Gaussians
        numGauss = length(param)-2;
        
        %get their means, stds and amplitudes
        tmpMean = param(1)/firstGauss;
        gaussMean = (firstGauss:numGauss+firstGauss-1)' * tmpMean;
        gaussStd  = repmat(param(2),numGauss,1);
        gaussAmp  = param(3:end);
        
    case 0010 % constrained mean, equal stds, lognormal
        
        % param = [mu_1, sigma_1, A_1, ..., A_N]';
        % size(param) = [2+N 1];
        
        %get number of Gaussians
        numGauss = length(param)-2;

        % mu = log(m / sqrt(1 + v/m^2)) = log(m^2 / sqrt(m^2 + v)
        % sigma = sqrt(log(1 + v/m^2))
        
        % calculate mean of the non-logarithmized sample,m
        % m = exp(mu + sigma^2) = exp(mu)*exp(sigma^2)
        dataMean1 = exp(param(1)+param(2)^2/2);
        dataMean1 = dataMean1 / firstGauss;
        
        % calculate variance of the non-logarithmized sample,v
        % v = exp(sigma^2 + 2*mu)*[exp(sigma^2)-1]
        %   = m^2 * [v/m^2]
        dataVar1 = exp(param(2)^2+2*param(1))*(exp(param(2)^2)-1);
        
        % means of other gaussians are multiples of first mean
        dataMeanN = (firstGauss:numGauss+firstGauss-1)'*dataMean1;
        dataVarN = repmat(dataVar1,numGauss,1);
        
        % compute the expected logarithmic mean and std
        gaussMean = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
        gaussStd = sqrt(log(dataVarN./dataMeanN.^2+1));
        gaussAmp  = param(3:end);
        
%% Constrained mean, Variable std

    case 0100 % constrained mean (strict), variable std, normal
        
        % param = [mu_1, sigma_1, ... sigma_N, A_1, ..., A_N]';
        % size(param) = [1+2*N 1];
        
        %get number of Gaussians
        numGauss = floor(length(param)/2);
        
        %get their means, stds and amplitudes
        tmpMean = param(1)/firstGauss;
        gaussMean = (firstGauss:numGauss+firstGauss-1)' * tmpMean;
        gaussStd  = param(2:numGauss+1);
        gaussAmp  = param(numGauss+2:end);
        
    case 0110 % constrained mean (strict), variable std, lognormal
        
        % param = [mu_1, sigma_1, ... sigma_N, A_1, ..., A_N]';
        % size(param) == [1+2*N, 1];
        
        %get number of Gaussians
        numGauss = floor(length(param)/2);
        
        %get their means, stds and amplitudes
        dataMean1= exp(param(1)+param(2)^2/2);
        dataMean1 = dataMean1 / firstGauss;
        dataMeanN = (firstGauss:numGauss+firstGauss-1)' * dataMean1;
        gaussMean = log(dataMeanN) - param(2:numGauss+1)'.^2/2;
        gaussStd  = param(2:numGauss+1);
        gaussAmp  = param(numGauss+2:end);
        
    case 0101 % constrained mean (wiggle), variable std, normal
        
        % param = [mu_firstGauss, n_{firstGauss+1}, n_{firstGauss+N-1}; ...
        %          sigma_firstGauss, ... sigma_{firstGauss+N-1}; ...
        %          A_firstGauss, ..., A_{firstGauss+N-1}]';
        % size(param) == [N 3];
        % wiggle room means that n multipliers can vary
        
        %get number of Gaussians
        numGauss = length(param)/3;
        
        %determine dependent Gaussians
        gauss2replace = setdiff(1:numGauss,refGauss);
        
        %get their means, stds and amplitudes
        param = reshape(param,numGauss,3);
        
        gaussMean = NaN(numGauss,1);
        gaussMean(refGauss) = param(refGauss,1);
        tmpMean = param(refGauss,1) / firstGauss;
        gaussMean(gauss2replace) = param(gauss2replace,1) * tmpMean;
        
        gaussStd  = param(:,2);
        gaussAmp  = param(:,3);
        
    case 0111 % constrained mean (wiggle), variable std, lognormal
        
        % param = [mu_firstGauss, n_{firstGauss+1}, n_{firstGauss+N-1}; ...
        %          sigma_firstGauss, ... sigma_{firstGauss+N-1}; ...
        %          A_firstGauss, ..., A_{firstGauss+N-1}]';
        % size(param) == [N 3];
        
        %get number of Gaussians
        numGauss = length(param)/3;
        
        %determine dependent Gaussians
        gauss2replace = setdiff(1:numGauss,refGauss);
        
        %get their means, stds and amplitudes
        param = reshape(param,numGauss,3);
        
        gaussMean = NaN(numGauss,1);
        gaussMean(refGauss) = param(refGauss,1);
        dataMeanRef = exp(param(refGauss,1)+param(refGauss,2)^2/2);
        dataMeanRef = dataMeanRef / firstGauss;
        dataMeanN = param(gauss2replace,1) * dataMeanRef;
        gaussMean(gauss2replace) = log(dataMeanN) - param(gauss2replace,2).^2/2;
        
        gaussStd  = param(:,2);
        gaussAmp  = param(:,3);
        
%% Constrained mean, Constrained std (scales with sqrt(n))
% if std is constrained to std_n = sqrt(n)*std_1

    case 0200 % constrained mean & std (strict), normal
        
        % param = [mu_firstGauss, sigma_firstGauss, A_firstGauss, ..., A_{firstGauss+N-1}]';
        % size(param) == [2+N 1]
        
        %get number of Gaussians
        numGauss = length(param)-2;
        
        %get their means, stds and amplitudes
        tmpMean = param(1)/firstGauss;
        gaussMean = (firstGauss:numGauss+firstGauss-1)' * tmpMean;
        tmpStd = param(2) / sqrt(firstGauss);
        gaussStd  = sqrt(firstGauss:numGauss+firstGauss-1)' * tmpStd;
        gaussAmp  = param(3:end);
        
    case 0210 % constrained mean & std (strict), lognormal
        % param = [mu_firstGauss, sigma_firstGauss, A_firstGauss, ..., A_{firstGauss+N-1}]';
        % size(param) == [2+N 1]
        
        %get number of Gaussians
        numGauss = length(param)-2;
        
        %get their means, stds and amplitudes
        dataMean1 = exp(param(1)+param(2)^2/2);
        dataMean1 = dataMean1 / firstGauss;
        
        dataVar1 = exp(param(2)^2+2*param(1))*(exp(param(2)^2)-1);
        dataVar1 = dataVar1 / firstGauss;
        
        dataMeanN = (firstGauss:numGauss+firstGauss-1)' * dataMean1;
        dataVarN = (firstGauss:numGauss+firstGauss-1)' * dataVar1;
        
        gaussMean = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
        gaussStd = sqrt(log(dataVarN./dataMeanN.^2+1));
        gaussAmp  = param(3:end);
        
    case 0201 % constrained mean & std (wiggle), normal
        
        % param = [mu_firstGauss, n_{firstGauss+1}, n_{firstGauss+N-1}; ...
        %          sigma_firstGauss, nn_{firstGauss+1}, ... nn_{firstGauss+N-1}; ...
        %          A_firstGauss, ..., A_{firstGauss+N-1}]';
        % %n is the multiplier for mu
        % %nn is the multiplier for sigma
        % size(param) == [N 3];
        
        %get number of Gaussians
        numGauss = length(param)/3;
        
        %determine dependent Gaussians
        gauss2replace = setdiff(1:numGauss,refGauss);
        
        %get their means, stds and amplitudes
        param = reshape(param,numGauss,3);
        
        gaussMean = NaN(numGauss,1);
        gaussMean(refGauss) = param(refGauss,1);
        tmpMean = param(refGauss,1) / firstGauss;
        gaussMean(gauss2replace) = param(gauss2replace,1) * tmpMean;
        
        gaussStd = NaN(numgauss,1);
        gaussStd(refGauss) = param(refGauss,2);
        tmpStd = param(refGauss,2) / sqrt(firstGauss);
        gaussStd(gauss2replace) = sqrt(param(gauss2replace,2)) * tmpStd;
        
        gaussAmp = param(:,3);
        
    case 0211 % constrained mean & std (wiggle), lognormal
        
        % param = [mu_firstGauss, n_{firstGauss+1}, n_{firstGauss+N-1}; ...
        %          sigma_firstGauss, nn_{firstGauss+1}, ... nn_{firstGauss+N-1}; ...
        %          A_firstGauss, ..., A_{firstGauss+N-1}]';
        % %n is the multiplier for mu
        % %nn is the multiplier for sigma
        % size(param) == [N 3];
        
        %get number of Gaussians
        numGauss = length(param)/3;
        
        %determine dependent Gaussians
        gauss2replace = setdiff(1:numGauss,refGauss);
        
        %get their means, stds and amplitudes
        param = reshape(param,numGauss,3);
        
        dataMeanRef = exp(param(refGauss,1)+param(refGauss,2)^2/2);
        dataMeanRef = dataMeanRef / firstGauss;
        
        dataVarRef = exp(param(refGauss,2)^2+2*param(refGauss,1))*(exp(param(refGauss,2)^2)-1);
        dataVarRef = dataVarRef / firstGauss;
        
        dataMeanN = param(gauss2replace,1) * dataMeanRef;
        dataVarN = param(gauss2replace,2) * dataVarRef;
        
        gaussMean = NaN(numGauss,1);
        gaussMean(refGauss) = param(refGauss,1);
        gaussMean(gauss2replace) = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
        
        gaussStd = NaN(numGauss,1);
        gaussStd(refGauss) = param(refGauss,2);
        gaussStd(gauss2replace) = sqrt(log(dataVarN./dataMeanN.^2+1));
        
        gaussAmp = param(:,3);
        
%% Constrained mean, Constrained std (scales with n)
%if std is constrained to std_n = n*std_1

    case 0300 % constrained mean & std (strict), normal
        
        % param = [mu_firstGauss, sigma_firstGauss, A_firstGauss, ..., A_{firstGauss+N-1}]';
        % size(param) == [2+N 1]
        
        %get number of Gaussians
        numGauss = length(param)-2;
        
        %get their means, stds and amplitudes
        tmpMean = param(1)/firstGauss;
        gaussMean = (firstGauss:numGauss+firstGauss-1)' * tmpMean;
        tmpStd = param(2) / firstGauss;
        gaussStd  = (firstGauss:numGauss+firstGauss-1)' * tmpStd;
        gaussAmp  = param(3:end);
        
    case 0310 % constrained mean & std (strict), lognormal
        
        % param = [mu_firstGauss, sigma_firstGauss, A_firstGauss, ..., A_{firstGauss+N-1}]';
        % size(param) == [2+N 1]
        
        %get number of Gaussians
        numGauss = length(param)-2;
        
        %get their means, stds and amplitudes
        dataMean1 = exp(param(1)+param(2)^2/2);
        dataMean1 = dataMean1 / firstGauss;
        
        dataVar1 = exp(param(2)^2+2*param(1))*(exp(param(2)^2)-1);
        dataVar1 = dataVar1 / (firstGauss^2);
        
        dataMeanN = (firstGauss:numGauss+firstGauss-1)' * dataMean1;
        dataVarN = (firstGauss:numGauss+firstGauss-1)'.^2 * dataVar1;
        
        gaussMean = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));
        gaussStd = sqrt(log(dataVarN./dataMeanN.^2+1));
        gaussAmp  = param(3:end);
        
    case 0301 % constrained mean & std (wiggle), normal
        
        % param = [mu_firstGauss, n_{firstGauss+1}, n_{firstGauss+N-1}; ...
        %          sigma_firstGauss, nn_{firstGauss+1}, ... nn_{firstGauss+N-1}; ...
        %          A_firstGauss, ..., A_{firstGauss+N-1}]';
        % %n is the multiplier for mu
        % %nn is the multiplier for sigma
        % size(param) == [N 3];
        
        %get number of Gaussians
        numGauss = length(param)/3;
        
        %determine dependent Gaussians
        gauss2replace = setdiff(1:numGauss,refGauss);
        
        %get their means, stds and amplitudes
        param = reshape(param,numGauss,3);
        
        gaussMean = NaN(numGauss,1);
        gaussMean(refGauss) = param(refGauss,1);
        tmpMean = param(refGauss,1) / firstGauss;
        gaussMean(gauss2replace) = param(gauss2replace,1) * tmpMean;
        
        gaussStd = NaN(numgauss,1);
        gaussStd(refGauss) = param(refGauss,2);
        tmpStd = param(refGauss,2) / firstGauss;
        gaussStd(gauss2replace) = param(gauss2replace,2) * tmpStd;
        
        gaussAmp = param(:,3);
        
    case 0311 % constrained mean & std (wiggle), lognormal
        
        % param = [mu_firstGauss, n_{firstGauss+1}, n_{firstGauss+N-1}; ...
        %          sigma_firstGauss, nn_{firstGauss+1}, ... nn_{firstGauss+N-1}; ...
        %          A_firstGauss, ..., A_{firstGauss+N-1}]';
        % %n is the multiplier for mu
        % %nn is the multiplier for sigma
        % size(param) == [N 3];
        
        %get number of Gaussians
        numGauss = length(param)/3;
        
        %determine dependent Gaussians
        gauss2replace = setdiff(1:numGauss,refGauss);
        
        %get their means, stds and amplitudes
        param = reshape(param,numGauss,3);
        
        dataMeanRef = exp(param(refGauss,1)+param(refGauss,2)^2/2);
        dataMeanRef = dataMeanRef / firstGauss;
        
        dataVarRef = exp(param(refGauss,2)^2+2*param(refGauss,1))*(exp(param(refGauss,2)^2)-1);
        dataVarRef = dataVarRef / (firstGauss^2);
        
        dataMeanN = param(gauss2replace,1) * dataMeanRef;
        dataVarN = (param(gauss2replace,2).^2) * dataVarRef;

        gaussMean = NaN(numGauss,1);
        gaussMean(refGauss) = param(refGauss,1);
        gaussMean(gauss2replace) = log(dataMeanN.^2./sqrt(dataVarN+dataMeanN.^2));

        gaussStd = NaN(numGauss,1);
        gaussStd(refGauss) = param(refGauss,2);
        gaussStd(gauss2replace) = sqrt(log(dataVarN./dataMeanN.^2+1));

        gaussAmp = param(:,3);
        
    otherwise
        
        % caseCode not found
        error('calcCumDistrNGauss:UnsupportedParameters', ...
            ['variableMean  = %d\n', ...
            'variableStd   = %d\n', ...
            'logData       = %d\n', ...
            'sum(ratioTot) = %g\n', ...
            'caseCode      = %d\n'], ...
            variableMean, ...
            variableStd, ...
            logData, ...
            sum(ratioTol), ...
            caseCode ...
            );
        
end

%% mkitti original code
%calculate the cumulative distribution
% cumDistrNGauss = zeros(size(abscissa));
% for i=1:numGauss
%     cumDistrNGauss = cumDistrNGauss + gaussAmp(i)*normcdf(abscissa,...
%         gaussMean(i),gaussStd(i));
% end

%% mkitti: vectorization of normcdf
% abscissaSize = size(abscissa);
% nAbscissa = prod(abscissaSize);
% abscissa = abscissa(:);
% % gaussMean, gaussStd should be a 1 x numGauss row vectors
% gaussMean = gaussMean(:)';
% gaussStd = gaussStd(:)';
% % expand to match
% abscissa = abscissa(:,ones(1,numGauss));
% nAbscissaOnes = ones(1,nAbscissa);
% gaussMean = gaussMean(nAbscissaOnes,:);
% gaussStd = gaussStd(nAbscissaOnes,:);
% % produce a numel(abscissa) X numGauss matrix
% cumDistrNGauss = ...
%      normcdf(    abscissa ...
%               , gaussMean ...
%               ,  gaussStd ...
%               );

% %% mkitti: inlining normcdf
% % TODO: Check if gaussStd == 0
abscissaSize = size(abscissa);
% nAbscissa = prod(abscissaSize);
abscissa = abscissa(:);
% gaussMean, gaussStd should be a 1 x numGauss row vectors
gaussMean = gaussMean(:)';
gaussStd = gaussStd(:)';
% z = (x-mu) ./ sigma
z = bsxfun(@rdivide,bsxfun(@minus,abscissa,gaussMean),gaussStd);
% sqrt because we want the normalized cdf
cumDistrNGauss = 0.5 * erfc(-z ./ sqrt(2));
% check for zeros
gaussStdEqZero = ~gaussStd;
if(any(gaussStdEqZero))
    cumDistrNGauss(:,gaussStdEqZero) = bsxfun(@ge,abscissa,gaussMean(gaussStdEqZero));
end


%% Calculate Jacobian

%KJ 190321: This part not used, at least within fitHistWithGaussians. 
%           Check/verify/generalize before using.

if(nargout > 1)
    % d(erfc(z)) / dz = -2e^{-z^2} / sqrt(pi)
    % d(cumDistrNGauss) / dz = e^{-z^2/2} / sqrt(2*pi)
    dcumDistrNGauss_dz = exp(-z.^2/2)./sqrt(2*pi);
    % d(z) / d(abscissa)  = 1 / gaussStd
    % d(z) / d(gaussMean) = - 1 / gaussStd
    % d(cumDistrNGauss) / d(gaussMean) = d(cumDistrNGauss) / dz * -1/gaussStd
    % Also mulitply by gaussAmp here to scale cumDistrNGauss
    dcumDistrNGauss_dgaussMean = -bsxfun(@times,dcumDistrNGauss_dz,gaussAmp(:)'./gaussStd);

    % d(z) / d(gaussStd)  = -(abscissa - gaussMean)/gaussStd.^2
    %                     = -z/gaussStd
    % d(cumDistrNGauss) / d(gaussStd) = d(cumDistrNGauss) / dz * -z/gaussStd
    % dcumDistrNGauss_dgaussStd = bsxfun(@rdivide,dcumDistrNGauss_dz.*z,gaussStd);
    %
    % d(cumDistrNGauss) / d(gaussStd) = d(cumDistrNGauss) / d(gaussMean) * z
    
    % Maximum relative difference between user-supplied and
    % finite-difference derivatives exceeds 1e-6 for the Std calculation
    dcumDistrNGauss_dgaussStd = dcumDistrNGauss_dgaussMean .* z;
    dcumDistrNGauss_dgaussAmp = cumDistrNGauss;

    % caseCode in decimal: MSLR
    % caseCode =  (variableMean == 1)*1000 + variableStd*100 + logData*10 + (sum(ratioTol)~=0);
    switch(caseCode)
        case -100
            J = dcumDistrNGauss_dgaussAmp;
        case 1000
            % variableMean
            % J = nAbscissa x 2 numGauss + 1 = nX x (nGaussMean,1 gaussStd, nGaussAmp)
            J = [dcumDistrNGauss_dgaussMean sum(dcumDistrNGauss_dgaussStd,2) dcumDistrNGauss_dgaussAmp];
        case 1100
            % variableMean and variableStd
            % J = nAbscissa x 3 numGauss = nX x (nGaussMean,nGaussStd,nGaussAmp)
            J = [dcumDistrNGauss_dgaussMean dcumDistrNGauss_dgaussStd dcumDistrNGauss_dgaussAmp];
        case 0000
            % constrained mean and single std
            % J = nAbscissa x 2 + numGauss = nX x (gaussMean, gaussStd, nGaussAmp)
            n = (1+(0:numGauss-1)/firstGauss)';
            J = [dcumDistrNGauss_dgaussMean*n sum(dcumDistrNGauss_dgaussStd,2) dcumDistrNGauss_dgaussAmp];
        case 0010
            % logData constrained mean, single std
            n = (1+(0:numGauss-1)/firstGauss)';
            % what if firstGauss is not 1?
            sigma = param(2);
            dZn_dsigma_n = -bsxfun(@rdivide,z,gaussStd);
            % Also need to multiply through by gaussAmp
            dZn_dsigma = bsxfun(@times,gaussAmp(:)'.*sigma./gaussStd,bsxfun(@rdivide, 1 + dZn_dsigma_n,(n'.^2-1)*exp(-sigma.^2)+1) - 1);
            J = [sum(dcumDistrNGauss_dgaussMean,2) sum(dcumDistrNGauss_dz.*dZn_dsigma,2) dcumDistrNGauss_dgaussAmp];
        case 0100
            % constrained mean, variable std
            % J = nAbscissa x 1 + 2*numGauss = nX x (guassMean, nGaussStd, nGaussAmp)
            n = (1+(0:numGauss-1)/firstGauss)';
            J = [dcumDistrNGauss_dgaussMean*n dcumDistrNGauss_dgaussStd dcumDistrNGauss_dgaussAmp];
        case 0110
            % logData, constrained mean, variable std
            J = [sum(dcumDistrNGauss_dgaussMean,2) ... 
                dcumDistrNGauss_dgaussStd(:,1)     + gaussStd(1)*sum(dcumDistrNGauss_dgaussMean(:,2:end),2) ... % dcumDistrNGauss_d(gaussStd_1)
                dcumDistrNGauss_dgaussStd(:,2:end) + bsxfun(@times,gaussAmp(2:end),dcumDistrNGauss_dz(:,2:end)) ... % dcumDistrNGauss_d(gaussStd_n), n > 1
                dcumDistrNGauss_dgaussAmp];
        case 0101
            % constrained mean, variable std, wiggle room
            % J = nAbscissa x 3 numGauss = nX x (nGaussMean,nGaussStd,nGaussAmp)
            n = [1 ; param(2:end,1)/firstGauss];
            J = [dcumDistrNGauss_dgaussMean*n dcumDistrNGauss_dgaussMean(:,2:end)*param(1) dcumDistrNGauss_dgaussStd dcumDistrNGauss_dgaussAmp];
        case 0111
            % logdata, constrained mean (wiggle), variable std
            n = [1 ; param(2:end,1)/firstGauss];
            J = [sum(dcumDistrNGauss_dgaussMean,2) bsxfun(@rdivide,dcumDistrNGauss_dgaussMean(:,2:end),n(2:end)') ... 
                dcumDistrNGauss_dgaussStd(:,1)     + gaussStd(1)*sum(dcumDistrNGauss_dgaussMean(:,2:end),2) ... % dcumDistrNGauss_d(gaussStd_1)
                dcumDistrNGauss_dgaussStd(:,2:end) + bsxfun(@times,gaussAmp(2:end)',dcumDistrNGauss_dz(:,2:end)) ... % dcumDistrNGauss_d(gaussStd_n), n > 1
                dcumDistrNGauss_dgaussAmp];
        case 0200
            % J = nAbscissa x 2 + numGauss
            %   = nX x (gaussMean,gaussStd,nGaussAmp)
            n = (1+(0:numGauss-1)/firstGauss)';
            J = [dcumDistrNGauss_dgaussMean*n dcumDistrNGauss_dgaussStd*sqrt(n) dcumDistrNGauss_dgaussAmp];
%         case 0210
%         case 0201
%             % J = nAbscissa x 3 numGauss = nX x (nGaussMean,nGaussStd,nGaussAmp)
%             J = [dcumDistrNGauss_dgaussMean dcumDistrNGauss_dgaussStd*[1 sqrt(param(2:end,2)/firstGauss)]' bsxfun(@rdivide,dcumDistrNGauss_dgaussStd(:,2:end),param(2:end,2)')/2 dcumDistrNGauss_dgaussAmp];
%         case 0211
        case 0300
            % J = nAbscissa x (2 + numGauss )
            %   = nAbscissa x (gaussMean,gaussStd,nGaussAmp)
            n = (1+(0:numGauss-1)/firstGauss)';
            J = [dcumDistrNGauss_dgaussMean*n dcumDistrNGauss_dgaussStd*n dcumDistrNGauss_dgaussAmp];
        case 0310
            % J = nAbscissa x (2 + numGauss )
            %   = nAbscissa x (gaussMean,gaussStd,nGaussAmp)
            J = [sum(dcumDistrNGauss_dgaussMean,2) sum(dcumDistrNGauss_dgaussStd,2) dcumDistrNGauss_dgaussAmp];
            assert(~any(isnan(J(:))));
%         case 0301
%             % J = nAbscissa x 3 numGauss = nX x (nGaussMean,nGaussStd,nGaussAmp)
%             J = [dcumDistrNGauss_dgaussMean dcumDistrNGauss_dgaussStd dcumDistrNGauss_dgaussAmp];
%         case 0311
%             % J = nAbscissa x 3 numGauss = nX x (nGaussMean,nGaussStd,nGaussAmp)
%             J = [dcumDistrNGauss_dgaussMean dcumDistrNGauss_dgaussStd dcumDistrNGauss_dgaussAmp];
        otherwise
            error('calcCumDistrNGauss:JacobianCaseNotImplemented', ...
                'The Jacobian has not been implemented for this input case: %04d', caseCode);
    end
end

%% mkitti: Finish vectorization / inlining by summing gaussians together
% gaussAmp(:) should be a numGauss x 1 column vector
% product should be a numel(abscissa) x 1 column vector
cumDistrNGauss = cumDistrNGauss * gaussAmp(:);
cumDistrNGauss = reshape(cumDistrNGauss,abscissaSize);

%% %%% ~~ the end ~~ %%%%%
