classdef TimePoints < Process
    %Psuedo-Process that simply stores important timepoints within a MovieList
    %
    %PROPERTIES
    %   times_      : cell array of 6 element array containing time.
    %                 [yr month day hr min sec]
    %   eventList_  : cell array of strings describing what happened at
    %                 given time point. Following list contains potential
    %                 elements of eventList
    %       'start'         : when observation started
    %       'VEGF_added'    : when VEGF was added to the sample
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
    
    properties
        times_           %cell array of 6 element array containing time [yr month day hr min sec]
        eventList_       %cell array of strings describing what happened at given time point
    end
    %% Constructor
    methods(Access = public)
        function obj = TimePoints(owner)
            %obj.owner_ = owner;
            %obj.name_ = getName();
            obj = obj@Process(owner, TimePoints.getName());
            obj.times_ = {};
            obj.eventList_ = {};
            obj.funName_ = @(varargin) true;
        end
    end
    %% Get Set
    methods
        function indx = getIndex(obj, eventType)
            indx = find(cellfun(@(x) strcmpi(x, eventType), obj.eventList_));
        end
    end
    %% Add / Remove time points
    methods
        %adds a timepoint
        function addTimePoint(obj, time, eventName)
            ip = inputParser;
            ip.addRequired('time', @(x) isnumeric(x) && numel(x)==6);
            ip.addRequired('eventName', @isstr);
            ip.parse(time, eventName);
            obj.times_{end+1} = time;
            obj.eventList_{end+1} = eventName;
        end
        %deletes a timepoint at given index
        function deleteTimePoint(obj, indx)
            ip = inputParser;
            ip.addRequired('indx', @isnumeric);
            ip.parse(indx);
            mask = true(1,numel(obj.times_));
            mask(indx) = false;
            obj.times_ = obj.times_(mask);
            obj.eventList_ = obj.eventList_(mask);
        end
    end
    %% Superclass abstracts
    methods(Static)
        function funParams = getDefaultParams()
        end
        function name = getName()
            name = 'TimePoints';
        end
    end
end

