function this = ConcentricDirectionDiscriminabilityTitrate(varargin)
    %fir s certain set oif local motion contrasts, and a certain set of
    %global motion contrasts, 

    this = ConcentricDirectionConstant();
    this.caller=getversion(1);
        
    this.trials.remove('extra.r');
    this.trials.remove('extra.nTargets');
    this.trials.remove('extra.globalDirection');
    this.trials.remove('extra.localDirection');
        
    % a reasonable value set for DX.
    valueSet = [-.1 .* (3/2).^((10:-1:1)./2) -.1:.025:.1 .1 .* (3/2).^((1:10)./2)];
    
    % a 3-down, 1-up staircase.
    makeDxUpperStaircase = @()DiscreteStaircase...
        ( 'criterion', @directionCorrect...
        , 'Nup', 1, 'Ndown', 3, 'useMomentum', 1 ...
        , 'valueSet', valueSet, 'currentIndex', 24);

    %a 3-up, 1-down staircase
    makeDxLowerStaircase = @()DiscreteStaircase...
        ( 'criterion', @directionCorrect...
        , 'Nup', 3, 'Ndown', 1, 'useMomentum', 1 ...
        , 'valueSet', valueSet, 'currentIndex', 6);

    % a 1-up, 1-down staircase.
    makeDxMiddleStaircase = @()DiscreteStaircase...
        ( 'criterion', @directionCorrect...
        , 'Nup', 1, 'Ndown', 1, 'useMomentum', 1 ...
        , 'valueSet', valueSet, 'currentIndex', 15);

    %plot([-.1 .* (3/2).^((10:-1:1)./3) -.1:.02:.1 .1 .* (3/2).^((1:15)./3)] )
    
    this.trials.addBefore...
        ( 'extra.phase' ...
        , {'extra.r', 'extra.globalDirection', 'extra.localDirection'}...
        , { { 20/3, 1, 1 }, { 20/3, -1, -1 } })
    
    %Note that the staircases operate on both clockwise and
    %counterclockwise motion. Therefore I only need "upper" staircases for
    %the zeroi-local-contrast case (I can look for biases in
    %post-analysis.)
    %
    %Yes, this is a bit convoluted.
    this.trials.addBefore...
        ( 'extra.phase' ...
        , { 'extra.nTargets' ...
          , 'extra.globalVScalar'...
          , 'extra.directionContrast'...
          } ...
        , { 
          , { 5,  makeDxUpperStaircase(),    0} ...
          , { 10, makeDxUpperStaircase(),    0} ...
          , { 14, makeDxUpperStaircase(),    0} ...
          , { 20, makeDxUpperStaircase(),    0} ...
          , { 5,  makeDxUpperStaircase(),   .1} ...
          , { 5,  makeDxLowerStaircase(),   .1} ...
          , { 10, makeDxUpperStaircase(),   .1} ...
          , { 10, makeDxLowerStaircase(),   .1} ...
          , { 14, makeDxUpperStaircase(),   .1} ...
          , { 14, makeDxLowerStaircase(),   .1} ...
          , { 20, makeDxUpperStaircase(),   .1} ...
          , { 20, makeDxLowerStaircase(),   .1} ...
        });
    
    this.trials.add('desiredResponse', 0);

    this.trials.reps = 35;
    this.trials.blockSize = 168;
    
    %determines whether the detected mtoion direction aggrees with global
    %displacement.
    function correct = directionCorrect(trial, result)
        correct = 0;
        if result.success == 1
            gd = trial.property__('extra.globalDirection');
            ld = trial.property__('extra.localDirection');
            if (sign(gd) == -sign(ld))
                return
            end
            if gd == 0
                if result.response == -ld
                    correct = 1;
                else
                    correct = -1;
                end
            else
                if result.response == -gd;
                    correct = 1;
                else
                    correct = -1;
                end
            end
        end
    end
    
    this.property__(varargin{:});
end
