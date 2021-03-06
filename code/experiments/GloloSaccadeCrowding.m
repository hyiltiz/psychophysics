function e = GloloSaccadeCorwding(varargin)
    e = Experiment(varargin{:});
    
    its = Genitive();
    

    e.trials.base = GloloSaccadeTrial...
        ( 'extra', struct...
            ( 'minSpace', 12 ...
            , 'distractorRelativeContrast', 1 ...
            , 'r', 12 ...
            , 'dt', .15 ...
            , 'l', 1.125 ...
            , 'color', [0.5 0.5;0.5 0.5;0.5 0.5] ...
            , 'tf', 20/3 ...
            , 'globalVScalar', 1 ...
            , 'wavelengthScalar', 0.15 ...
            , 'widthScalar', 0.05 ...
            , 'nTargets', 5 ...
            ) ... 
        , 'fixation', FilledDisk ...
            ( 'radius', 0.2 ...
            , 'loc', [0 0] ...
            ) ...
        , 'fixationTime', Inf ...
        , 'fixationLatency', 1.0 ...
        , 'fixationStartWindow', 2 ...
        , 'fixationSettle', 0.4 ...
        , 'fixationWindow', 3 ...
        , 'targetOnset', 0 ...
        , 'usePrecue', 1 ...
        , 'precueOnset', 0 ...
        , 'precueDuration', 0.1 ...
        , 'precue', CauchyDrawer ...
            ( 'source', CircularSmoothCauchyMotion ...
                ('radius', 8 ...
                , 'phase', 0 ...
                , 'angle', 90 ...            
                , 'omega', 0 ...
                , 'color', [0.125 0.125 0.125]' ...
                , 'wavelength', 1 ...
                , 'width', 1 ...
                , 'order', 4 ...
                )...
            )...
        , 'target', CauchyDrawer ...
            ( 'source', CircularSmoothCauchyMotion ...
                ('radius', 8 ...
                , 'phase', 0 ...
                , 'angle', 90 ...            
                , 'omega', 0 ...
                , 'color', [0.125 0.125 0.125]' ...
                , 'wavelength', 1 ...
                , 'width', 1 ...
                , 'order', 4 ...
                )...
            ) ...
        , 'useTrackingTarget', 1 ...
        , 'trackingTarget', CauchySpritePlayer ...
            ('process', CircularCauchyMotion ...
                ( 'radius', 8 ...
                , 'dt', .15 ...
                , 'dphase', [1.5/8] ...
                , 'x', 0 ...
                , 'y', 0 ...
                , 't', .15 ...
                , 'n', [Inf] ...
                , 'color', [0.5 0.5 0.5]' ...
                , 'velocity', 10 ... %velocity of peak spatial frequency
                , 'wavelength', 0.75 ...
                , 'width', 1 ...
                , 'duration', [0.1 0.1] ...
                , 'order', 4 ...
                , 'phase', [0 0] ...
                , 'angle', [90 90] ...
                ) ...
            ) ...
        , 'targetBlank', Inf ...
        , 'cueTime', Inf ... %assuming 200ms latency, this places most saccades right in between for max. effect
        , 'minLatency', 0.1 ... %too short a latency counts as jumping the gun
        , 'maxLatency', 0.5 ...
        , 'maxTransitTime', 0.15 ...
        , 'targetWindow', 8 ...
        , 'rewardSize', 0 ...
        , 'rewardTargetBonus', 0.15 ...
        , 'rewardLengthBonus', 0.10 ...
        , 'errorTimeout', 0 ...
        , 'earlySaccadeTimeout', 3.0 ...
        );
    
    %the target parameters are selected from a grid of stimulus
    %parameters.
    e.trials.add({'extra.r', 'fixationWindow'}, {{15 10} {10 20/3} {20/3 40/9}});
    
    %vary the number of targets
    e.trials.add('extra.nTargets', [2 3 4 5 6 7 8]);
    
    %GlobalVScalar is multiplied by radius to get global velocity, centered
    %around 10 deg/dec at 10 radius... that is to say this is merely
    %radians/sec around the circle.
    e.trials.add('extra.globalVScalar', [2/3 1 1.5 -2/3 -1 -1.5]);
    
    %temporal frequency is chosen here...
    e.trials.add('extra.tf', [-15 -10 -20/3 20/3 10 15]);

    %and wavelength is set to the RADIUS multiplied by this (note
    %this is independent of dt or dx)
    e.trials.add('extra.wavelengthScalar', [2/30 .1 .15])
    
    %dt changes independently of it all
    e.trials.add('extra.dt', [2/30, 0.10 0.15]);
    %The durations are 2/3 of the dt. (at the same global speed)
    e.trials.add('trackingTarget.process.duration', @(b)b.extra.dt * 2/3);

    %TODO: hmmm, I should work out a way to get the counterphase trials in
    %there as well.
        
    %the target window for saccades
    e.trials.add('targetWindow', @(b)b.extra.r(1) - b.fixationWindow/2);
    
    %The target appears on the screen somewhere (but we don't know where
    %the distracctor is yet)
    e.trials.add('target.source.phase(1)', UniformDistribution('lower', 0, 'upper', 2*pi));
    
    %the target onset comes at a somewhat unpredictable time.
    e.trials.add('targetOnset', ExponentialDistribution('offset', 0.3, 'tau', 0.5));
    
    %the cue time comes on unpredictably after the target onset.
    e.trials.add('cueTime', ExponentialDistribution('offset', 0.4, 'tau', 0.5));

    %But on some of trials the monkey is rewarded for just fixating.
    e.trials.add('fixationTime', GammaDistribution('offset', 0.7, 'shape', 2, 'scale', 0.8));

    %The precue, if there is one, comes 300 ms before the target onset.
    e.trials.add('precueOnset', @(b)b.targetOnset - 0.3);
    
    %The target tracking time is also variable.
    e.trials.add('targetFixationTime', ExponentialDistribution('offset', 0.3, 'tau', 0.4));
    
    %procedurally set up the global appearance of the stimulus
    e.trials.add([], @globalAppearance);
    function b = globalAppearance(b)
        %This function procedurally sets up the global appearance.
        extra = b.extra;

        trackingProcess = b.trackingTarget.process;
        trackingProcess.setRadius(extra.r);
        trackingProcess.setDt(extra.dt);
        trackingProcess.setT(extra.dt);
        trackingProcess.setDphase(extra.dt .* extra.globalVScalar);
        
        %the target moves the same as the first stimulus.
        targetSource = b.target.source;
        ph = targetSource.property__(its.phase(1));
        targetSource.setRadius(extra.r(1));
        targetSource.setOmega(extra.globalVScalar(1));
        targetSource.setAngle(ph * 180/pi + 90);
        
        %the wheel phase is aligned to the target phase, when the wheel
        %appears. The wheel has spokes.
        ph = ph + trackingProcess.getT() .* targetSource.getOmega();
        trackingProcess.setPhase(ph + 2*pi*(0:extra.nTargets-1)/extra.nTargets);
        trackingProcess.setAngle(trackingProcess.getPhase() * 180/pi + 90);

        %the precue is appears unmoving in the location of the original
        %target.
        precueSource = b.precue.source;
        precueSource.setRadius(targetSource.getRadius());
        precueSource.setPhase(targetSource.getPhase());
        precueSource.setAngle(targetSource.getAngle());
    end
    
    e.trials.add([], @localAppearance);
    function b = localAppearance(b)
        extra = b.extra;
        trackingProcess = b.trackingTarget.process;
        
        wl = extra.r .* extra.wavelengthScalar;
        v = wl .* extra.tf;
        
        trackingProcess.setWavelength(wl);
        trackingProcess.setVelocity(v);
        trackingProcess.setWidth(extra.r .* extra.widthScalar);
        col = repmat(extra.color, 1, extra.nTargets);
        col(:, 2:end) = col(:, 2:end) .* extra.distractorRelativeContrast;
        trackingProcess.setColor(col);
        if any(col > 0.5)
           noop(); 
        end
        
        %Make sure that after the changeover to the smooth target, the target
        %stll has the same (mean) contrast and wavelength.
        targetSource = b.target.source;
        targetSource.setColor(trackingProcess.property__(its.color(:,1)) .* trackingProcess.property__(its.duration(1)) ./ trackingProcess.property__(its.dt(1)));
        targetSource.setWavelength(trackingProcess.property__(its.wavelength(:,1)));
        targetSource.setWidth(trackingProcess.property__(its.width(1)));
        
        precueSource = b.precue.source;
        precueSource.setColor(targetSource.getColor());
        precueSource.setWavelength(targetSource.getWavelength());
        precueSource.setWidth(targetSource.getWidth());
    end
        
    %minimize time between trials.
    e.trials.interTrialInterval = 0;
    
%    e.trials.fullFactorial = 1;
%    e.trials.reps = 30;
    e.trials.blockSize = 300;
    e.trials.requireSuccess = 0;
    
    %begin with an eye calibration and again every three hundred trials...
    %
    e.trials.blockTrial = EyeCalibrationMessageTrial...
        ( its.base.absoluteWindow, 10 ...
        , its.base.maxLatency, 0.5 ...
        , its.base.fixDuration, 0.75 ...
        , its.base.fixWindow, 4 ...
        , its.base.rewardDuration, 75 ...
        , its.base.settleTime, 0.5 ...
        , its.base.targetRadius, 0.25 ...
        , its.base.targetInnerRadius, 0.1 ...
        , its.minCalibrationInterval, 900 ...
        , its.base.onset, 0 ...
        , its.maxStderr, 0.3 ...
        , its.minN, 20 ...
        , its.maxN, 50 ...
        , its.interTrialInterval, 0.5 ...
        );
end
