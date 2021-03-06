%In this trial, the subect fixates at the central point, a motion occurs,
%and the subject has to respont by turning the knob let or right. Pretty
%simple...

function this = ConcentricTrial(varargin)
    %speed bodges. With these we have to assume this object is a singleton. Oh god.
    persistent fixation;
    persistent textFeedback;
    persistent motion;
    persistent occluders;
    %persistent eyePosition;
    %persistent this; %can't do that, but as long as 'this' isn't
    %referenced?
    
    startTime = 0;
    knobTurnThreshold = 3;
    awaitInput = 0.5; %how early to accept a response from the subject. Fixation is also enforced up until this time.
    maxResponseLatency = Inf; %how long to wait for the response (measured after awaitInput)
    lateTimeout = 0.5;
    earlyTimeout = 0.5;
    
    fixation = FilledDisk([0, 0], 0.1, [0 0 0]);
    %eyePosition = FilledDisk(function(h) [h.eyeX(end) h.eyeY(end)], 0.1, [255 0 0]);
    
    textFeedback = Text('centered', 1, 'loc', [0 0]);
    
    audioCueTimes = []; %when to play an audio cue, relative to motion onset.
   
    requireFixation = 1;
    fixationLatency = 2; %how long to wait for acquiring fixation
    
    fixationStartWindow = 3; %this much radius for starting fixation
    fixationSettle = 0.3; %allow this long for settling fixation.
    fixationWindow = 1.5; %subject must fixate this closely...
    reshowStimulus = 0; %whether to reshow the stimulus after the response (for training purposes)
    beepFeedback = 0; %whether to give a tone for correct/incorrect feedback...
    desiredResponse = 0; %which response (1 = cw) is correct, if feedback is desired.
    feedbackFailedFixation = 0;
    
    motion = [];
    
    occluders={};
    useOccluders = 0;

    extra = struct();

    persistent init__;
    this = autoobject(varargin{:});
    
    persistent audio_;

    function [params, result] = run(params)
        interval = params.screenInterval;
        
        result = struct('startTime', NaN, 'success', 0, 'abort', 0, 'response', 1);
        
        trigger = Trigger();
        trigger.panic(keyIsDown('q'), @abort);
        if requireFixation
            trigger.singleshot(atLeast('next', startTime - interval/2), @awaitFixation);
        else
            trigger.singleshot(atLeast('next', startTime - interval/2), @startMotion);
        end

        %in any case, log all the knob rotations
        trigger.multishot(nonZero('knobRotation'), @knobRotated);

        
        motionStarted_ = Inf;
        motion.setVisible(0);
        fixation.setVisible(0);
        for i = occluders(:)'
            i{1}.setVisible(0);
        end
        
        if requireFixation && (beepFeedback || ~isempty(audioCueTimes))
            audio_ = params.input.audioout;
            main = mainLoop ...
                ( 'input', {params.input.eyes, audio_, params.input.keyboard, params.input.knob, EyeVelocityFilter()} ...
                , 'graphics', {fixation, textFeedback, motion, occluders{:}} ...
                , 'triggers', {trigger} ...
                );
        elseif requireFixation
            main = mainLoop ...
                ( 'input', {params.input.eyes, params.input.keyboard, params.input.knob, EyeVelocityFilter()} ...
                , 'graphics', {fixation, textFeedback, motion, occluders{:}} ...
                , 'triggers', {trigger} ...
                );
        elseif (beepFeedback || ~isempty(audioCueTimes))
            audio_ = params.input.audioout;
            main = mainLoop ...
                ( 'input', {audio_, params.input.keyboard, params.input.knob} ...
                , 'graphics', {fixation, textFeedback, motion, occluders{:}} ...
                , 'triggers', {trigger} ...
                );
        else
            main = mainLoop ...
                ( 'input', {params.input.keyboard, params.input.knob} ...
                , 'graphics', {fixation, textFeedback, motion, occluders{:}} ...
                , 'triggers', {trigger} ...
                );
        end
        
        main.go(params);
        
        function knobRotated(h)
            %do nothing, just log the event.
        end
                
        function awaitFixation(h)
            fixation.setVisible(1);
            if useOccluders
                for i = occluders(:)'
                    i{1}.setVisible(1, h.next()); % do we want it available here, or in sync with the rest of the stimulus?
                end
            end
            trigger.first ...
                ( circularWindowEnter('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationStartWindow), @settleFixation, 'eyeFt' ...
                , atLeast('eyeFt', h.next + fixationLatency), @failedWaitingFixation, 'eyeFt' ...
                );
        end
        
        function failedWaitingFixation(k)
            failed(k);
        end

        function settleFixation(k)
            trigger.first ...
                ( atLeast('eyeFt', k.triggerTime + fixationSettle), @startMotion, 'eyeFt' ...
                , circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationStartWindow), @failedSettling, 'eyeFt' ...
                );
        end
        
        function failedSettling(k)
            failed(k);
        end
        
        responseCollectionHandle_ = [];
        function startMotion(h)
            fixation.setVisible(1);
            motion.setVisible(1, h.next);
            if useOccluders
                for i = occluders(:)'
                    i{1}.setVisible(1);
                end
            end
            
            for i = audioCueTimes(:)'
                %set the cues to play at the presice times relative to
                %simulus onset.
                audio_.play('cue', h.next + i);
            end

            motionStarted_ = h.next;
            if requireFixation
                trigger.first...
                    ( atLeast('eyeFt', h.next + awaitInput), @endFixationPeriod, 'eyeFt' ...
                    , circularWindowExit('eyeFx', 'eyeFy', 'eyeFt', fixation.getLoc, fixationWindow), @failedFixation, 'eyeFt' ...
                    );
            end
            %respond to input from the beginning of every trial...
            responseCollectionHandle_ = trigger.first...
                ( atLeast('knobPosition', h.knobPosition+knobTurnThreshold), @cw, 'knobTime' ...
                , atMost('knobPosition', h.knobPosition-knobTurnThreshold), @ccw, 'knobTime' ...
                , atLeast('knobDown', 1), @failed, 'knobTime' ... 
                );
        end
        
        function endFixationPeriod(h)
            %do nothing;;;
        end
        
        function failedFixation(h)
            if feedbackFailedFixation
                %flash the fix point as feedback.
                fixationFlashOff(h);
                trigger.singleshot(atLeast('next', h.next + 0.25), @fixationFlashOn);
                trigger.singleshot(atLeast('next', h.next + 0.50), @fixationFlashOff);
                trigger.singleshot(atLeast('next', h.next + 0.75), @fixationFlashOn);
                trigger.singleshot(atLeast('next', h.next + 1.00), @fixationFlashOff);
                trigger.singleshot(atLeast('next', h.next + 1.00), @failed);
                trigger.remove(responseCollectionHandle_);
                fprintf(2, '>>>> broke fixation\n');
            else
                failed(h)
            end
        end
        
        function fixationFlashOn(h)
            fixation.setVisible(1);
        end
        
        function fixationFlashOff(h)
            fixation.setVisible(0);
        end
        
        function cw(h)
            result.response = 1;
            responseCollected(h);
        end

        function ccw(h)
            result.response = -1;
            responseCollected(h);
        end

        function responseCollected(h)
            result.success = 1;
            %start something else, based on the response
            endplay = 0;
            if beepFeedback
                if desiredResponse == 0
                    [~, endplay] = audio_.play('click');
                elseif result.response == desiredResponse
                    %make a beep
                    [~, endplay] = audio_.play('ding');
                else
                    [~, endplay] = audio_.play('buzz');
                end
            end
            
            if h.knobTime - awaitInput < motionStarted_;
                trigger.singleshot(atLeast('refresh',h.refresh+1), @tooShort);
            elseif h.knobTime - motionStarted_ - awaitInput > maxResponseLatency
                trigger.singleshot(atLeast('refresh',h.refresh+1), @tooLong);
            elseif reshowStimulus
                trigger.singleshot(atLeast('refresh',h.refresh+1), @reshow);
            else
                trigger.singleshot(atLeast('next',max(motionStarted_ + awaitInput + maxResponseLatency, endplay+interval)), @stop);
            end
        end
        
        function tooLong(h)
            %audio feedback.
            result.success = 0;
            %fixation.setColor([255 0 0]);
            textFeedback.setText('Too slow');
            textFeedback.setVisible(1);
            fixation.setVisible(0)
            trigger.singleshot(atLeast('next', h.next + lateTimeout), @stop);
            fprintf(2, '>>>> too slow\n');
        end
        
        function tooShort(h)
            %visual feedback.
            result.success = 0;
            %fixation.setColor([0 0 255]);
            textFeedback.setText('Too fast');
            textFeedback.setVisible(1);
            fixation.setVisible(0);
            trigger.singleshot(atLeast('next', h.next + earlyTimeout), @stop);
            fprintf(2, '>>>> too fast\n');
        end
        
        function reshow(h)
            motion.setVisible(0);
            motion.setVisible(1, h.next);
            trigger.singleshot(atLeast('next', h.next + awaitInput - interval/2), @stop);
        end
        
        function abort(h)
            result.abort = 1;
            stop(h);
        end
        
        function failed(h)
            result.success = 0;
            stop(h);
        end
        
        function stop(h)
           motion.setVisible(0);
           fixation.setVisible(0);
           fixation.setColor([0 0 0]);
           textFeedback.setVisible(0);
           if useOccluders
               for i = occluders(:)'
                   i{1}.setVisible(0, h.next);
               end
           end
           result.endTime = h.next;
           trigger.singleshot(atLeast('refresh', h.refresh+1), main.stop);
        end
    end
end