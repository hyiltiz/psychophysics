
function e = GloLoCuedFlashLag(varargin)
    %An experiment that is aimed to measure the flash lag in glolo motion
    %stimuli as a function of the local velocity. Use both temporal
    %feequency and spatial frequency as ways of varying local velocity.

    e = Experiment...
        ( 'params', namedargs...
            ( 'skipFrames', 1  ...
            , 'priority', 0 ...
            , 'hideCursor', 0 ...
            , 'eyelinkSettings.sample_rate', 250 ...
            )...
        , varargin{:} ...
        );
    
 
    %heh. line continuations don't work properly inside cells. This gets a parse error:
    % x = { function1 ...
    %         ( 'arg1', arg1 ) };
    
    
    e.trials.base = GloLoCuedTrial...
        ( 'fixationStartWindow', 3 ...
        , 'fixationSettle', 0.1 ...
        , 'fixationWindow', 4 ...
        , 'barOnset', 0.6750 ...                         %4.5 flashes
        , 'barCueDuration', 1/30 ...
        , 'barCueDelay', 0.65 ...
        , 'barFlashColor', [1 1 1] ...
        , 'barFlashDuration', 1/30 ...
        , 'barLength', 2 ...
        , 'barWidth', 0.15 ...
        , 'barPhase', 0 ...                         %randomized below
        , 'barRadius', 10 ...
        , 'fixationPointSize', 0.1 ...
        , 'targets', ...
            { CauchySpritePlayer( ...
                'process', CircularCauchyMotion ...
                    ( 'radius', 8 ...
                    , 'dt', 0.15 ...
                    , 'dphase', 1.5/8 ... %dx = 1.5
                    , 'x', 0 ...
                    , 'y', 0 ...
                    , 't', 0 ...
                    , 'n', 7 ...
                    , 'color', [0.5 0.5 0.5]' ...
                    , 'velocity', 10 ... %velocity of peak spatial frequency
                    , 'wavelength', 0.75 ...
                    , 'width', 0.5 ...
                    , 'duration', 0.1 ...
                    , 'order', 4 ...
                    ) ...
                ) ...
            , CauchyDrawer( ...
                'source', CircularSmoothCauchyMotion ...
                    ('radius', 8 ...
                    , 'color', [1/3 1/3 1/3]' ...
                    , 'omega', 10/8 ... %everything nominal 10 degrees/sec
                    , 'wavelength', 0.75 ...
                    , 'width', 0.5 ...
                    , 'order', 4 ...
                    ) ...
                ) ...
            } ...
        );
        
    e.trials.add('barCueDelay', ExponentialDistribution('offset', 0.3, 'tau', 0.15));
    
    %tell the randomizer how to randomize the trial each time.
    
    %The range of temporal offsets:
    %we will measure at just one temporal offset, after 4.5 appearances
    
    %The bar origin is random around the circle and orientation follows
    %motion phase, angle, bar onset, bar phase
    e.trials.add({'targets{1}.process.phase', 'targets{1}.process.angle', 'targets{2}.source.phase', 'targets{2}.source.angle'}, @(b)num2cell(rand()*2*pi * [1 180/pi 1 180/pi] + [0 90 0 90]));
    dt = e.trials.base.targets{1}.process.dt;
    dph = e.trials.base.targets{1}.process.dphase;
    omega = dph ./ dt;
    e.trials.add({'targets{1}.process.dphase', 'targets{2}.source.omega'}, {{-dph -omega} {dph omega}});
    
    %bar phase is sampled in a range...
    e.trials.add('extra.barStepsAhead', linspace(-1, 2, 7));
    %that is centered on the location of the bar.
    e.trials.add('barPhase', @(b)b.extra.barStepsAhead*b.targets{1}.process.dphase + b.targets{1}.process.phase + (b.barOnset-b.targets{1}.process.t(1))*b.targets{1}.process.dphase ./ b.targets{1}.process.dt);
            
    %the message to show between blocks.
    e.trials.startTrial = MessageTrial('message', @()sprintf('Turn the knob to report the position of the flash.\n%d blocks remain.\nPress the knob to continue.', e.trials.blocksLeft()));
    e.trials.blockTrial = EyeCalibrationMessageTrial...
        ( 'minCalibrationInterval', 0 ...
        , 'base.absoluteWindow', 100 ...
        , 'base.maxLatency', 0.5 ...
        , 'base.fixDuration', 0.5 ...
        , 'base.fixWindow', 4 ...
        , 'base.rewardDuration', 10 ...
        , 'base.settleTime', 0.3 ...
        , 'base.targetRadius', 0.2 ...
        , 'base.onset', 0 ...
        , 'maxStderr', 0.5 ...
        , 'minN', 10 ...
        , 'maxN', 50 ...
        , 'interTrialInterval', 0.4 ...
        );
    e.trials.endBlockTrial = MessageTrial('message', @()sprintf('%d blocks remain.\nPress knob to continue.', e.trials.blocksLeft()));
    e.trials.endTrial = MessageTrial('message', sprintf('All done!\nPress the knob to finish.\nThanks!'));
    
    %vary local velocity in two ways. These are the values from
    %GlolosaccadeCharlie whcih is 12 degrees at 15 degrees/sec, scaled down
    %to 8 degrees at 10 deg/sec.
    e.trials.add...
        ( {'extra.wavelengthScaling', 'whichTargets', 'targets{1}.process.velocity', 'targets{1}.process.color', 'targets{2}.source.color', 'targets{1}.process.wavelength', 'targets{2}.source.wavelength', 'stimulusDuration'} ...
        , ...
            { {NaN 2  10  [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  7*dt} ...
            , {1   1 -15  [1/6    1/6   1/6  ]' [1/9    1/9    1/9 ]' 1.125 1.125 Inf} ...
            , {1   1 -5   [.5     .5    .5   ]' [1/3    1/3    1/3 ]' 0.375 0.375 Inf} ...
            , {1   1  5   [.5     .5    .5   ]' [1/3    1/3    1/3 ]' 0.375 0.375 Inf} ...
            , {1   1  15  [1/6    1/6   1/6  ]' [1/9    1/9    1/9 ]' 1.125 1.125 Inf} ...
            , {0   1 -15  [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  Inf} ...
            , {0.5 1 -10  [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  Inf} ...
            , {0   1 -5   [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  Inf} ...
            , {0   1  0   [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  Inf} ...
            , {0   1  5   [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  Inf} ...
            , {0.5 1  10  [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  Inf} ...
            , {0   1  15  [.25    .25   .25  ]' [1/6    1/6    1/6 ]' 0.75  0.75  Inf} ...
            } ...
        );
%            , {NaN 2  5   [.5     .5    .5   ]' [1/3    1/3    1/3 ]' 0.375 0.375 7*dt} ...
%            , {NaN 2  15  [1/6    1/6   1/6  ]' [1/9    1/9    1/9 ]' 1.125 1.125 7*dt} ...
    
    %{

        %}
    
    e.trials.fullFactorial = 1;
    e.trials.reps = 6;
    e.trials.blockSize = 168;
