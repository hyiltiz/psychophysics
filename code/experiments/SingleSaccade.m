function e = SingleSaccade(varargin)
    params = struct...
        ( 'edfname',    '' ...
        , 'dummy',      0  ...
        , 'skipFrames', 1  ...
        , 'requireCalibration', 0 ...
        , 'filename', '' ...
        , 'subject', 'zzz' ...
        , 'logfile', '' ...
        , 'priority', 9 ...
        , 'hideCursor', 0 ...
        , 'diagnostics', 0 ...
        );
    params = namedargs(params, varargin{:});
    
    e = Experiment...
        ( 'trials', SingleSaccadeTrialGenerator...
            ( 'base', SingleSaccadeTrial...
                ( 'cue', 0.5 ...
                , 'targetTrackingDuration', 0.45 ...
                , 'cueJump', 0.1 ...
                , 'patch', CauchyPatch ...
                    ( 'size', [1/2 0.5 0.1] ...
                    , 'velocity', 5 ... 
                    ) ...
                )...
            , 'n', 5 ...
            , 'radius', 8 ...
            , 'excluded', 5 ... 
            , 'dx', 0.75 ...
            , 'dt', 0.15 ...
            , 'contrast', 0.5 ...
            , 'cueMin', 0.2 ...
            , 'cueMax', 1.0 ...
            , 'numInBlock', 50 ...
            )...
        , params);
    
    e.run();
end