function e = GloLoAdjustment(varargin)

    e = Experiment...
        ( 'continuing', 0 ...
        , 'trials', Randomizer...
            ( 'blocksize', 50 ...
            , 'base', GloLoAdjustmentTrial...
                ( 'barOnset', 0 ...
                , 'barBackgroundColor', [0.5 0.5 0.5] ...
                , 'barFlashColor', [1 1 1] ...
                , 'barFlashDuration', 1/30 ...
                , 'loopDuration', 1.2 ...
                , 'barLength', 1 ...
                , 'barWidth', 0.15 ...
                , 'barPhase', 0 ...
                , 'barRadius', 6 ...
                , 'ccwResponseKey', 'z' ...
                , 'cwResponseKey', 'x' ...
                , 'satisfiedResponseKey', 'space'...
                , 'fixationPointSize', 0.1 ...
                , 'knobTurnThreshold', 3 ...
                , 'motion', CircularMotionProcess ...
                    ( 'angle', 90 ...
                    , 'color', [0.5; 0.5; 0.5] ...
                    , 'dt', 0.2 ...
                    , 'n', 5 ...
                    , 'phase', 0 ...
                    , 'radius', 5 ...
                    , 't', 0.2 ...
                    )...
                , 'patch', CauchyPatch...
                    ( 'size', [0.375 1 0.075]...
                    , 'velocity', 5 ...
                    , 'order', 4 ...
                    ) ...
                ) ...
            ) ...
        , 'params', struct...
            ( 'skipFrames', 1  ...
            , 'requireCalibration', 1 ...
            , 'priority', 9 ...
            , 'hideCursor', 0 ...
            , 'input', struct ...
                ( 'keyboard', KeyboardInput() ...
                , 'knob', PowermateInput() ...
                ) ...
            )...
        , varargin{:} ...
        );
    
    %tell the randomizer how to randomize the trial each time. TODO: think
    %about how to save this splendid mechanism to disk...
    
    e.trials.add('patch.velocity', num2cell(e.trials.base.patch.velocity * [-1 1]));
    e.trials.add('motion.dphase', num2cell([-1 1] ./ e.trials.base.motion.radius));
    %randomly choose a range of temporal offsets and provide an initial
    e.trials.add('barOnset', num2cell(e.trials.base.motion.t + e.trials.base.motion.dt * (0:0.25:e.trials.base.motion.n - 1)));
    %Bar origin is random around the circle
    e.trials.add({'motion.phase', 'motion.angle'}, @()num2cell(rand()*2*pi * [1 180/pi] + [0 90]));
    %and for each trial pick an appropriate bar phase based on these
    e.trials.add('barPhase', @(b) b.motion.phase + (b.barOnset-b.motion.t(1))*b.motion.dphase./b.motion.dt);

    %Go!
    e.run();