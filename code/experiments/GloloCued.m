function e = GloloCued(varargin)
    %this randomizer needs to runa bunch of QUESTs in 

    e = Experiment...
        ( 'params', struct...
            ( 'skipFrames', 1  ...
            , 'priority', 9 ...
            , 'hideCursor', 0 ...
            , 'doTrackerSetup', 0 ...
            , 'input', struct ...
                ( 'keyboard', KeyboardInput() ...
                , 'knob', PowermateInput() ...
                ) ...
            )...
        , varargin{:} ...
        );
    
    e.trials.base = GloLoCuedTrial...
        ( 'barOnset', 0 ...                         %randomized below
        , 'barCueDuration', 1/30 ...
        , 'barCueDelay', 0.3 ...
        , 'barFlashColor', [1 1 1] ...
        , 'barFlashDuration', 1/30 ...
        , 'barLength', 2 ...
        , 'barWidth', 0.15 ...
        , 'barPhase', 0 ...                         %randomized below
        , 'barRadius', 8 ...
        , 'fixationPointSize', 0.1 ...
        , 'targets{1}.motion', CircularCauchyMotion ...
            ( 'angle', 90 ...
            , 'color', [0.5; 0.5; 0.5] ...
            , 'dt', 0.2 ...
            , 'n', 5 ...
            , 'phase', 0 ...                        %randomized below
            , 'radius', 5 ...
            , 't', 0.2 ...
            , 'dphase', 1/5 ...
            , 'wavelength', 0.375 ...
            , 'width', 1 ...
            , 'duration', 0.075 ...
            , 'velocity', 5 ...
            , 'order', 4 ...
            )...
        );
        
    %tell the randomizer how to randomize the trial each time.
    
    %The range of temporal offsets:
    %from the onset of the second flash to the onset of the fourth flash is
    %49 timepoints at 120 fps
    e.trials.add('barOnset', e.trials.base.motion.t + e.trials.base.motion.dt * linspace(0,3,13));
    
    %The bar origin is random around the circle and orientation follows
    %motion phase, angle, bar onset, bar phase
    e.trials.add({'targets{1}.motion.phase', 'targets{1}.motion.angle'}, @(b)num2cell(rand()*2*pi * [1 180/pi] + [0 90]));
    
    e.trials.add({'targets{1}.motion.velocity', 'targets{1}.motion.dphase'}, {{-e.trials.base.motion.velocity, -e.trials.base.motion.dphase}, {e.trials.base.motion.velocity, e.trials.base.motion.dphase}});
    
    %bar phase is sampled in a range...
    e.trials.add('extra.barStepsAhead', linspace(-0.5, 1, 7));
    %that is centered on the location of the bar.
    e.trials.add('barPhase', @(b)b.extra.barStepsAhead*b.motion.dphase + b.motion.phase + (b.barOnset-b.motion.t(1))*b.motion.dphase ./ b.motion.dt);
            
    %the message to show between blocks.
    e.trials.blockTrial = MessageTrial('message', @()sprintf('Press knob to continue. %d blocks remain', e.trials.blocksLeft()));
    
    e.trials.fullFactorial = 1;
    e.trials.reps = 5;
    e.trials.blockSize = 91;
