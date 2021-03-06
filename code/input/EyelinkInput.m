function this = EyelinkInput(varargin)
    %handles eye position input and recording.

    badSampleCount = 0;
    missingSampleCount = 0;
    goodSampleCount = 0;
    
    streamData = 1; %data streaming would be good...
    recordStreamedData = 1;
    
    recordFileSamples = 0;
    recordFileEvents = 0;
    recordLinkSamples = 1;
    recordLinkEvents = 0;
    
    queueData = 1;
    
    keepRecordingBetweenTrials = 1;
    keepingRunning_ = 0;

    doTheTrackerSetup = 1;
    edfname = '';
    localname = '';
    dummy = 0;
    
    persistent init__; %#ok
    
    persistent slope;
    persistent offset;
    persistent calibrationDate;
    persistent calibrationSubject;
    
    %speed bodges. With these we have to assume this object is a singleton. Oh god.
    persistent defaults;
    %persistent this; %can't do that, but as long as 'this' isn't
    %referenced?
    persistent sampleCache_; %has to be persistent because of speed nonsense.
    
    if isempty(slope)
        slope = 1 * eye(2); % a 2*2 matrix relating voltage to eye position
        offset = [0;0]; % the eye position offset
        calibrationDate = [];
        calibrationSubject = [];
    end
    
    this = autoobject(varargin{:});
    
    slowdown_ = [];
    dummy_ = [];
    window_ = [];
    toDegrees_ = @noop;
    
    %default parameters during initialization
    defaults = struct...
        ( 'hideCursor', 0 ... %whether we should hide the mouse cursor
        , 'dummy', 0 ... %whether to simulate eyelink input with the mouse
        );
    
    data = zeros(0,3);

    sampleCacheLength = 3000;
    sampleCache_ = struct('time',cell(sampleCacheLength, 1),'type',0,'flags',0,'px',0,'py',0,'hx',0,'hy',0,'pa',0,'gx',0,'gy',0,'rx',0,'ry',0,'status',0,'input',0,'buttons',0,'htype',0,'hdata',0);
    [sampleCache_.time] = deal(1); %maybe a speed improvement if everything is preallocated.
    
%% initialization routines

    %the initializer will be called once per experiment and does global
    %setup of everything.
    freq_ = [];
    pahandle_ = [];
    interval_ = [];
    logf_ = [];
    function [release, params, next] = init(params)
        a = joinResource(defaults, @connect_, @initDefaults_, @doSetup_, getSound(), @openEDF_);
        
        interval_ = params.screenInterval;
        logf_ = params.logf;
        
        data = zeros(0,3);
        
        [release, params, next] = a(params);
    end

    function [release, details] = connect_(details)
        
        %check the connection before, because:
        %stupidly, Eyelink('Initialize') returns 0 if the eyelink is
        %already initialized IN DUMMY MODE. Bah.
        if Eyelink('isconnected')
            warning('GetEyelink:already_connected', 'Eyelink was left connected');
            Eyelink('ShutDown');
        end
           
        %connect to the eyelink machine.
        if ~isfield(details, 'dummy')
            %auto-choose real or dummy mode
            try
                status = Eyelink('Initialize');
                dummy = 0;
            catch
                %There is no rhyme or reason as to why eyelink throws
                %an error and not a status code here
                status = -1;
            end
            if (status < 0)
                warning('GetEyelink:dummyMode', 'Using eyelink in dummy mode');
                status = Eyelink('InitializeDummy');
                dummy = 1;
            end
        else
            if dummy
                status = Eyelink('InitializeDummy');
            else
                status = Eyelink('Initialize');
            end
            if status < 0
                error('getEyelink:initFailed',...
                    'Initialization status %d', status);
            end
        end

        release = @close;
        
        function close
            if (status >= 0)
                Eyelink('Shutdown');
            end
        end
    end

    %we will need this struct laying around. It doesn't change much.
    persistent el_;
    %initialize eyelink defaults. Requires the 'window' field from getScreen.
    %output fields - 'dummy' if we are in dummy mode
    function [release, details] = initDefaults_(details)
        el_ = EyelinkInitDefaults(details.window);
        details.el = el_;
    
        %hackish, because I don't yet want to tear up EyelinkInitDefaults,
        %but background and foreground color should be specifiable from the
        %experiment outset
        details.el.backgroundcolour = details.backgroundIndex;
        details.el.foregroundcolour = details.foregroundIndex;
        
        [release, details] = deal(@noop, details);
        
        function noop
            %While EyelinkInitDefaults changes the eyelink's screen
            %resolution settings, there is no way to tell what the setings
            %were before, so there is nothing to be done for cleanup.
        end
        
        
    end

    function [release, params] = doSetup_(params)
        %%make sure we have a screen number...
        params = doTrackerSetup(params);
        %set and record as many settings as possible
        if (params.hideCursor)
            HideCursor();
        end
        release = @show;

        function show
            %sonce ther's no way to read the settings off the Eyelink,
            %there's no way to restore state...
            ShowCursor();
        end
    end

    persistent samples_;


%% remote EDF file opening and download
    %open the eyelink data file on the eyelink machine. Upon closing,
    %download the file.
    %input field: dummy: skips a file check in dumy mode
    %output field: edfFilename = the name of the EDF file created
    function [release, details] = openEDF_(details)
        e = env;

        %default behavior is to rocord to EDF, if NOT streaming data
        %(if streaming data goes into the log which is easier.)
        if isempty(edfname)
            if (recordFileSamples || recordFileEvents) && ~streamData
                %pick some kind of unique filename by combining a prefix with
                %a 7-letter encoding of the date and time
            
                pause(1); % to make it likely that we get a unique filename, hah!
                % oh, why is the eyelink so dumb?
                edfname = ['z' clock2filename(clock) '.edf'];
            else
                edfname = '';
            end
        end
        
        if ~isempty(edfname) && isempty(localname)
            %choose a place to download the EDF file to
            
            %if we're in an experiment, use those values...
            if all(isfield(details, {'subject', 'caller'}))
                localname = fullfile...
                    ( e.eyedir...
                    , sprintf ...
                    ( '%s-%04d-%02d-%02d__%02d-%02d-%02d-%s.edf'...
                    , details.subject, floor(clock), details.caller.function ...
                    ) ...
                    );
            else
                localname = fullfile(e.eyedir, edfname);
            end
        end

        if ~isempty(edfname)
            %the eyelink has no way directly to check that the filename is
            %valid or non-existing... so we must assert that we can't open the
            %file yet.
            tmp = tempname();
            status = Eyelink('ReceiveFile',edfname,tmp);
            if (~dummy) && (status ~= -1)
                error('Problem generating filename (expected status %d, got %d)',...
                    -1, status);
            end

            %destructive step: open the file
            %FIXME - adjust this according to what data we save...
            Eyelink('command', 'link_sample_data = GAZE');
            status = Eyelink('OpenFile', edfname);
            if (status < 0)
                error('getEyelink:fileOpenError', ...
                    'status %d opening eyelink file %s', status, edfname);
            end
        else
            %not recording -- don't leave some random previous file open on
            %eyelink
            status = Eyelink('CloseFile');
            if status ~= 0
                error('GetEyelink:couldNotClose', 'status %d closing EDF file', status);
            end
            localname = '';
        end
        
        %when we are done with the file, download it
        release = @downloadFile;

        function downloadFile
            if keepingRunning_
                %flush it all.
                Eyelink('StopRecording');
                %discard the rest...
                while (Eyelink('GetNextDataType'))
                end
                keepingRunning_ = 0;
            end
            
            %if we were recording to a file, download it
            if ~isempty(edfname) && ~isempty(localname)
                %try both in any case
                status = Eyelink('CloseFile');
                if Eyelink('IsConnected') ~= details.el.dummyconnected
                    fsize = Eyelink('ReceiveFile', edfname, localname);

                    if (fsize < 0 || status < 0)
                        error('getEyeink:fileTransferError', ...
                            'File %s empty or not transferred (close status: %d, receive: %d)',...
                            edfname, status, fsize);
                    end
                end
            end
        end
    end

%% tracker setup: do calibration

    function details = doTrackerSetup(details)
        details = setupEyelink(details);
        
        if ~dummy && doTheTrackerSetup
            message(details, 'Do tracker setup now');
            status = EyelinkDoTrackerSetup(details.el) %, details.el.ENTER_KEY);
            if status < 0
                error('getEyelink:TrackerSetupFailed', 'Eyelink setup failed.');
            end
        end
        
        %repeat it again since doTrackerSetup turns on filtering, FFS
        details = setupEyelink(details);
    end

%% begin (called each trial)

    clockoffset_ = 0;
    slowdown_ = 1;
    
    push_ = @noop; %the function to record some data...
    readout_ = @noop; %the function to store data...
    
    function [release, details] = begin(details)
        freq_ = details.freq;
        pahandle_ = details.pahandle;
        
        badSampleCount = 0;
        missingSampleCount = 0;
        goodSampleCount = 0;

        if isfield(details, 'slowdown')
            slowdown_ = details.slowdown;
        end
        
        toDegrees_ = transformToDegrees(details.cal);
        
        dummy_ = dummy;
        window_ = details.window;

        %t1 = GetSecs();
        [details.clockoffset, details.clockoffsetMeasured] = getclockoffset(details);
        clockoffset_ = details.clockoffset;
        %t1 = GetSecs() - t1
        
        %This field will be set to empty by mainLoop. I will tell it what
        %event fields to remove from the log. Then trigger software will
        %remove them before logging.
        details.notlogged = union(details.notlogged, {'eyeX', 'eyeY', 'eyeT'});
        
        samples_ = 0.9 * sin(linspace(0, 750*2*pi, freq_));
        
        if dummy_
            release = @noop;
        else
            if recordStreamedData && queueData
                [push_, readout_] = linkedlist(2);
            end
            
            %this can take a half second if run with high priority?
            if keepingRunning_
                %pull in some data
                input(struct());
            else
                Eyelink('StartRecording', recordFileSamples, recordFileEvents, recordLinkSamples, recordLinkEvents);
            end
            
            %It retuns -1 but still records! WTF!@!!
            %if status ~= 0
            %    error('EyelinkInput:error', 'status %d starting recording', status);
            %end
            
            %the samples and events are recorded anew each trial.
            release = @doRelease;
        end
        
        function doRelease
            %this can take a half second if run with high priority?
            if keepRecordingBetweenTrials
                keepingRunning_ = 1;
            else
                Eyelink('StopRecording');
                %discard the rest...
                while (Eyelink('GetNextDataType'))
                end
                keepingRunning_ = 0;
            end
            
            if streamData && recordStreamedData
                %read out data...
                if queueData
                    data = readout_();
                end
                fprintf(logf_,'EYE_DATA %s\n', smallmat2str(data));
            end
        end
    end

%% sync
    startTime_ = 0;
    function sync(n, t) %#ok
        startTime_ = t + n * interval_;
    end

%% actual input function
    refresh_ = []; 
    next_ = [];
    function k = input(k)
        %Brings in samples from the eyelink and adds them to the structure
        %given as input.
        %Fields added are:
        %   eyeX, eyeY, eyeT (complete traces) and
        %   x, y, t (the latest sample each call).
        %Translates the x and y values to degrees of visual angle.        
        %Coordinates will be NaN if the eye position is not available.
        if dummy_
            [x, y, buttons] = GetMouse(window_);
            
            t = GetSecs() / slowdown_;
            if any(buttons) %simulate blinking
                x = NaN;
                y = NaN;
                badSampleCount = badSampleCount + 1;
            else
                goodSampleCount = goodSampleCount + 1;
            end

            [x, y] = toDegrees_(x, y);

            k.x = x;
            k.y = y;
            k.t = t;
        else            
             if streamData
                [samples, ~, drained] = Eyelink('GetQueuedData');
                while ~drained
                    [newsamples, ~, drained] = Eyelink('GetQueuedData');
                    try
                        samples = cat(2, samples, newsamples);
                    catch e
                        vars = who();
                        save('catdump.mat', vars{:})
                        rethrow(e)
                    end
                end
                
                %drop all lost data samples
                if (size(samples, 2)) ~= 0
                    try
                        samples(:,samples(2,:) == el_.LOSTDATAEVENT) = [];
                    catch e
                        rethrow(e)
                    end
                end
                
                if (size(samples,2)) == 0
                    [k.eyeX, k.eyeY, k.eyeT] = deal(zeros(0,1));
                    k.x = NaN;
                    k.y = NaN;
                    k.t = GetSecs() / slowdown_;
                else
                    
                    x = samples(14,:);
                    y = samples(16,:);
                    
                    x(x == -32768) = NaN;
                    y(isnan(x)) = NaN;
                    
                    [x, y] = toDegrees_(x, y);
                    
                    l = [x;y];
                    l = slope*l+offset(:,ones(1,size(l, 2)));

                    k.eyeX = l(1,:);
                    k.eyeY = l(2,:);
                    
                    k.eyeT = (samples(1,:) - clockoffset_) / 1000 / slowdown_;

                    if recordStreamedData
                        if queueData
                            push_([k.eyeX;k.eyeY;k.eyeT]);
                        else
                            fprintf(logf_,'EYE_DATA %s\n', smallmat2str([k.eyeX;k.eyeY;k.eyeT]));
                        end
                    end

                    %already written experiments expect
                    %x, y, t to be the latest samples.
                    k.x = k.eyeX(end);
                    k.y = k.eyeY(end);
                    k.t = k.eyeT(end);
                end
            else
                %If you don't want to stream everything into matlab, just 
                %gather the latest sample on every refresh. 
                if Eyelink('NewFloatSampleAvailable') == 0;
                    %no data?
                    x = NaN;
                    y = NaN;
                    t = GetSecs() / slowdown_;
                    missingSampleCount = missingSampleCount + 1;
                else
                    % Probably don't need to do this eyeAvailable check every
                    % frame. Profile this call?
                    eye = Eyelink('EyeAvailable');
                    switch eye
                        case el_.BINOCULAR
                            error('eyeEvents:binocular',...
                                'don''t know which eye to use for events');
                        case el_.LEFT_EYE
                            eyeidx = 1;
                        case el_.RIGHT_EYE
                            eyeidx = 2;
                    end

                    sample = Eyelink('NewestFloatSample');
                    x = sample.gx(eyeidx);
                    y = sample.gy(eyeidx);
                    if x == -32768 %no position -- blinking?
                        badSampleCount = badSampleCount + 1;
                        x = NaN;
                        y = NaN;
                    else
                        goodSampleCount = goodSampleCount + 1;
                    end

                    t = (sample.time - clockoffset_) / 1000 / slowdown_;
                end
                [x, y] = toDegrees_(x, y);

                k.x = x;
                k.y = y;
                k.t = t;
            end
        end
    end

    function [refresh, startTime] = reward(rewardAt, duration)
        %for psychophysics, just produce a beep...
        %generate a buffer...
        PsychPortAudio('Stop', pahandle_);
        PsychPortAudio('FillBuffer', pahandle_, samples_(1:floor(duration/1000*freq_)), 0);
        startTime = PsychPortAudio('Start', pahandle_, 1, 0); %next_ + (rewardAt - refresh_) * interval_);
        refresh = refresh_ + round(startTime - next_)/interval_;
        fprintf(logf_,'REWARD %d %d %d %f\n', rewardAt, duration, refresh, startTime);
    end

    function predictedclock = eventCode(clockAt, code)
        predictedclock = clockAt;
        fprintf(logf_,'EVENT_CODE %d %d %d\n', clockAt, code, clockAt);
    end
end
