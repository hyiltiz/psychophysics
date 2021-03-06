function exp = ConcentricDirectionSegment_nj(exp)
    disp('configuring for nj');
    
    %set the global speed.
    exp.trials.base.extra.directionContrast = .2;
    %we're just looking at one combination of contrast and two values of
    %global V...
    %We want -0.1 and -0.2 degree displacement to be most informative
    globalV = [-.1] / (20/3) / 0.1 ;
    
    exp.trials.addBefore('extra.globalDirection', 'extra.globalVScalar', {globalV(1)});
    exp.trials.addBefore('extra.globalDirection', {'extra.globalDirection', 'extra.localDirection'}, {{1 1},{-1 -1}});
    exp.trials.remove('extra.globalDirection');
    exp.trials.remove('extra.localDirection');
    
    exp.trials.replace('extra.side', ...
        { 'left', 'right' ...
        , 'left', 'right' ...
        , 'left', 'right' ...
        }, 1, 1); %side is blocked

    exp.trials.add('desiredResponse', 0);
    
    exp.trials.base.extra.instruction = 'spots';
    exp.trials.startTrial.message = @()sprintf('Look for the movement of the individual spots.\nPress knob to begin.\n%d blocks in experiment', exp.trials.blocksLeft());
    exp.trials.endBlockTrial.message = @()sprintf('Take a break, stretch, adjust your chair, etc.\nPress knob to continue.\n%d blocks remain\nLook for the movement of individual spots.', exp.trials.blocksLeft());
    exp.trials.base.maxResponseLatency = 0.75;

    exp.trials.reps = 1;
    exp.trials.reps = floor(1000 / exp.trials.numLeft());
    exp.trials.blockSize = floor(exp.trials.numLeft() / 6);
    
end