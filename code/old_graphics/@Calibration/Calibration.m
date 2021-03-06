function [p, signal] = Calibration(varargin)
% function p = Calibration('propertyName', 'propertyValue')
%
% A set of calibration data. This includes frame 
% rate, angular spacing, and gamma correction information. 
%
% The object also includes machine name and color information so that a 
% calibration can be looked up.
% 
% Properties:
% 'machine' the machine name.
% 'screen' the screen number from psych-toolbox.
% 'distance' the distance from the screen to the observer's eye, in some units.
% 'spacing' the pixel spacing, in the same units.
% 'rect' the screen dimensions in pixels.
% 'pixelSize' the screen bit depth.
% 'interval' the frame interval in seconds (1 / refresh rate)
% 'gamma' A gamma correction table.
% 'calibration_rect' the rectangle that we placed the photometer over
% 'measurement' the raw gamma measurements.
% 'measured' set to true if the gamma table has been produced by photometric 
%  measurement.
% 'bitdepth' the bit depth of the gamma correction table.
%
% The constructor with no arguments will try to load the calibration from a 
% known location and match it to the current system. 
%
% The defaults (for demos and such) assumes a screen spanning 30 degrees
% (vertically, usually) and having square pixels.
% 
% Methods:
% p = save(p) saves the calibration to a standard directory.
% p = load(p) finds the calibration that matches this computer and screen 
%             resolution.
% p = calibrate_gamma(p) speaks to a photometer on the given screen, and fills out 
%     its own gamma correction table.

%the "signal output" is an out-of-band calling argument. if called with
%nargout=2, Calibration will not attempt to retreive a previous calibration.

classname = mfilename('class');
args = varargin;

if ~isempty(args) && isa(args{1}, classname)
	%copy constructor
	p = args{1};
	args = args(2:end);
else
	%default values to be IGNORED
	p.computer = NaN;
    p.ptb = NaN;
	p.screenNumber = NaN;
	p.distance = NaN;
	p.spacing = NaN;
	p.rect = NaN;
	p.pixelSize = NaN;
	p.interval = NaN;
	p.gamma = NaN;
	p.calibrated = NaN;
    p.calibration = NaN;
	p.bitdepth = NaN;
	p.date = NaN;
    p.center = NaN;
	 
    p.svn = svninfo(fileparts(mfilename('fullpath')));
	p = class(p, classname, PropertyObject);
end

if length(args) >= 2
	p = set(p, args{:});
end

%the real work: read the system for default values.
if isscalar(p)
    if isnumeric(p.computer) && isnan(p.computer)
        p.computer = Screen('Computer');
        p.computer = rmfield(p.computer, 'location'); %changes when network settings change
        p.computer.kern = rmfield(p.computer.kern, 'hostname'); %this changes all the time
        p.computer.hw = rmfield(p.computer.hw, 'usermem'); %this changes all the time
    end

    l = localExperimentParams();

    if isnumeric(p.ptb) && isnan(p.ptb)
        p.ptb = Screen('Version');
        p.ptb = rmfield(p.ptb, 'authors'); %too long to dump out in our saved file
    end

    if isnan(p.screenNumber)
        if isfield(l, 'ScreenNumber')
            p.screenNumber = l.screenNumber;
        else
            p.screenNumber = max(Screen('Screens'));
        end
    end
    if isnan(p.rect)
        p.rect = Screen('Rect', p.screenNumber);
    end
    if isnan(p.pixelSize)
        p.pixelSize = Screen('PixelSize', p.screenNumber);
    end
    if isnan(p.interval)
        fr = Screen('FrameRate', p.screenNumber);
        if (fr == 0)
            warning('Calibration:noFrameRate', 'Unable to determine frame rate');
            fr=60;
        end

        p.interval = 1/fr;
    end

    if isnan(p.center)
        p.center = [0 0]; % where the "fixation point" is; measured in degrees
        % from the center of the screen
    end
end

%the above specifies system parameters; given this we should be able to find a
%saved calibration that matches.
if nargout < 2
    [p, found] = load(p);
    if ~found
        %if not, continue with initialization.
        if isnan(p.date)
            p.date = date();
        end
        if isnan(p.distance)
            p.distance = 20*pi; %one cm per degree;
        end
        if isnan(p.spacing)
            %millimeters per pixel
            sp = [30 30]./(p.rect([3 4]) - p.rect([1 2]));
            p.spacing = [max(sp) max(sp)];
        end
        if isnan(p.gamma)
            %%%		p.gamma = Screen('ReadNormalizedGammaTable', p.screenNumber);
            p.gamma = linspace(0,1,256)' * [1 1 1];
        end
        if isnan(p.calibrated)
            p.calibrated = 0;
        end
        if isnan(p.bitdepth)
            p.bitdepth = 8;
        end
    end
else
    found = 0; %not really
    signal = 1;
end


