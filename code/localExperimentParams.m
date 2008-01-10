function params = localExperimentParams()

%Judging from the machine we are running on, looks up experiment
%configuraittion parameters
c = Screen('Computer');

switch c.machineName
    case 'pastorianus' %this is the psychophysics rig
        params = struct ...
            ( 'requireCalibration', 1 ...
            , 'logfile', '' ...
            , 'dummy', 0 ...
            , 'priority', 0 ...
            , 'input', struct ...
                ( 'eyes', EyelinkInput() ...
                , 'knob', PowermateInput() ...
                ) ...
            );
    case 'cerevisiae' %this is my g4 laptop
        %i am only testing on this laptop
        params = struct ...
            ( 'subject', 'zzz' ...
            , 'edfname', '' ...
            , 'requireCalibration', 1 ...
            , 'dummy', 0 ...
            , 'input', struct ...
                ( 'eyes', EyelinkInput() ...
                , 'knob', KnobInput() ...
                ) ...
            );
        
    case 'boulardii' %this is my monkey rig
        params = struct ...
            ( 'requireCalibration', 1 ...
            , 'dummy', 0 ...
            , 'input', struct ...
                ( 'eyes', LabJackInput() ... %unless using eyelink...?
                ) ...
            );
    otherwise
        params = struct();
end