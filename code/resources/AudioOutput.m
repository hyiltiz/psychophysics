function this = AudioOutput(varargin)
    %This is an object driver that provides output to the audio card and
    %lets you set up a number of named samples to play. During a trial, you
    %can call audioout.play() with a sample name and desired onset time to start
    %playing the named sample.
    %
    %This provides an interface to the PsychPortAudio routines with a
    %different flavor -- it lets you establish a group of named
    %samples, and play the samples by name, by specifying onset times.
    %The flexibility for specifying accurate onset times is what 
    %differentiates this approach from the 'scheduling' (really, sequencing) 
    %facility built into PsychPortAudio.
    %
    %Samples played at the same time will sum together (possibly clipping,
    %and not clipping elegantly.)
    %
    %Finally, you can specify a 'filter' function to apply to the audio
    %output before going to the speaker, or even as an easy way to compute
    %your own live streaming audio. The arguments of a filter function are:
    
    freq = 44100;
    channels = [0 1]; %which channels to use for output, in which order.
    latbias = 30/44100; %set a default for this?
    reqlatencyclass = 4;
    deviceid = []; %leave empty to use default, or specify a device.
    buffersize = [];
    bufferSecs = 5; %this actually probably doesn't matter for online audio computation, as long as it's large enough to get you to the next frame.
    framesAhead = 1; %normally we compute through the next refresh. Up this if you want audio to be more robust to frame skips. THe tradeoff is that there is more latency between deciding to play a sound and the sound actually playing.
    samples = struct();
    filter = []; %the filter function (optional).
    record = 0; %whether to record the generated output for posterity.
    
    
%% init
    %init is called at the beginning of the experiment.
    pahandle_ = NaN;
    logf_ = [];
    interval_ = 0;
    initted_ = 0;
    function [release, params, next] = init(params) %#ok
        if initted_
            error('AudioOutput:alreadyOpened', 'Device already opened!');
        end
        if isfield(params, 'logf')
            logf_ = params.logf;
        end
        
        %munge the arguments for PsychPortAudio...
        mode = 1;
        nChannels = numel(channels);
        selectChannels = channels(:)';
        
        %open the device
        pahandle_ = PsychPortAudio('Open', deviceid, mode, reqlatencyclass, freq, nChannels, buffersize, [], selectChannels);
        
        release = @close;
        function close()
            PsychPortAudio('Close', pahandle_);
            logf_ = [];
        end

        next = @setRunMode_;
    end

    sampleRate_ = [];
    function [release, params, next] = setRunMode_(params)
        status = PsychPortAudio('GetStatus', pahandle_);
        sampleRate_ = status.SampleRate;
        interval_ = params.cal.interval;

        %since we might output audio intermittently, the run mode is set to
        %allow this.
        previous = PsychPortAudio('RunMode', pahandle_, 1);
    
        release = @undo;
        function undo
            PsychPortAudio('RunMode', pahandle_, previous);
        end
        
        next = @setLatency_;
    end

    function [release, params, next] = setLatency_(params)
        previous = PsychPortAudio('LatencyBias', pahandle_, latbias);
        params.soundLatencyBias = PsychPortAudio('LatencyBias', pahandle_);

        release = @close;
        function close()
            PsychPortAudio('LatencyBias', pahandle_, previous);
        end
        
        next = @initOutput_;
    end

    outputBufferSize_ = [];
    function [release, params, next] = initOutput_(params)
        %allocate output buffers
        outputBufferSize_ = 1024 * ceil(bufferSecs * sampleRate_ / 1024);
        overflow = PsychPortAudio('FillBuffer', pahandle_, dummy_(0, outputBufferSize_, sampleRate_, 0, channels)); %#ok
        PsychPortAudio('SetLoop', pahandle_); %a circular buffer; loop everything
        
        release = @close;
        function close
            PsychPortAudio('DeleteBuffer', [], 1);
        end
        next = @loadSamples_;
    end

    function [release, params] = loadSamples_(params)
        cellfun(@loadSample_, struct2cell(samples), fieldnames(samples), 'UniformOutput', 0);
            
        release = @unloadSamples_;
    end

    %At beginning of experiment, render the sound samples.
    sampleData_ = struct();
    function loadSample_(sample, name)
        %load or otherwise compute the sample.
        if ischar(samples.(name))
            sampleData_.(name) = loadAudioFile_(sample);
        else
            d = e(sample, channels, sampleRate_);
            if size(d, 1) ~= numel(channels)
                error('audioOutput:wrongNumberOfChannels', 'wrong number of channels in sample "%s"', name);
            end
            sampleData_.(name) = d;
        end
    end
       
    function audiodata = loadAudioFile_(filename) %#ok
        [~,~,ext] = fileparts(filename);
        switch ext
            case '.wav'
                [audiodata, infreq] = wavread(filename);
            case '.aiff'
                [audiodata, infreq] = aiffread(filename);
            otherwise
                [audiodata, infreq] = wavread(filename);
        end
        
        if isinteger(audiodata)
            mn = double(intmin(class(audiodata)));
            mx = double(intmax(class(audiodata)));
            audiodata = double(audiodata) ./ ((mx-mn)/2) - ((mn / (mx-mn) + 0.5)/2);
        end
        
        % Resampling supported. Check if needed.
        if infreq ~= freq
            % Need to resample this to target frequency 'freq':
            % fprintf('Resampling file %s from %i Hz to %i Hz... ', filename, infreq, freq);
            audiodata = resample(audiodata, freq, infreq);
        end

        [~, ninchannels] = size(audiodata);
        audiodata = repmat(transpose(audiodata), numel(channels) / ninchannels, 1);
    end

    function unloadSample_(name)
        %does nothing, as I don't use the scheduler function.
        sampleData_ = rmfield(sampleData_, name);
        %    PsychPortAudio('DeleteBuffer', pahandle_, sampleHandles_.(name));
    end

    function unloadSamples_()
        cellfun(@unloadSample_, fieldnames(samples));
    end
    
    function setSamples(newSamples) %#ok
        if initted_
            %whoops. must go through and see what has changed.
            oldSamples = s;
            oldnames = fieldnames(oldSamples);
            newnames = fieldnames(newSamples);
            
            changed = intersect(oldnames, newnames);
            removed = setdiff(oldnames, newnames);
            added = setdiff(newnames, oldnames);
            
            sellfun(@remove, removed);
            cellfun(@(n) fif(~isequalwithequalnans(oldSamples.(n), newSamples.(n), @change, [], n) , changed));
            cellfun(@add, added);
        end
        
        function change(samplename)
            remove(samplename);
            add(samplename);
        end

        function remove(sampleName)
            unloadSample_(sampleName);
        end

        function add(samplename)
            loadSample_(samplename)
        end

        samples = newSamples;
    end
    
%% begin
    %The 'begin' resource is acquired at the beginning of every trial.

    confirmed_ = 0;
    push_ = @noop; %the function to record some data...
    readout_ = @noop; %the function to store data...
    running_ = [];
    starting_ = [];
    
    lastsampleix_ = -1;
    nextStreamTime_ = NaN;
    underflowed_ = 0;
    startTime_ = [];
    function [release, params] = begin(params)
        if record
            [push_, readout_] = linkedlist(2);
        end
        confirmed_ = 0;
        PsychPortAudio('FillBuffer', pahandle_, dummy_(0, outputBufferSize_, sampleRate_, 0, channels));
        PsychPortAudio('SetLoop', pahandle_); %a circular buffer; loop everything
        startTime_ = PsychPortAudio('Start', pahandle_, 0);
        lastsampleix_ = -1;
        lastStreamTime_ = NaN;
        underflowed_ = 0;
        
        running_ = cell(0,3);
        starting_ = cell(0,2);
        
        release = @stop;
        function stop
            running_ = cell(0,3);
            starting_ = cell(0,2);
            
            PsychPortAudio('Stop', pahandle_, 0, 0);
            
            if record
                data = readout_();
                fprintf(logf_,'AUDIO_OUT %s\n', smallmat2str(data));
            end
            
            if underflowed_
                %warning('AudioOutput:overflow', 'Audio output buffer underflow detected!');
            end
        end
    end

    %called to say HEY WE'RE REALLY BEGINNING, after n vblanks
    function sync(n,t) %#ok
        %do-nothing. we already started up in begin().
    end

%% input function, called once per loop.
    hardwareBufferSize_ = 0;
    startTime_ = [];
    function state = input(state)
        %once the playback machine has started, gather info about it for
        %streaming.
        status = PsychPortAudio('GetStatus', pahandle_);
        if ~confirmed_
            if status.Active
                sampleRate_ = status.SampleRate;
                hardwareBufferSize_ = status.BufferSize;
                confirmed_ = 1;
            else
                return;
            end
        end
        %we need to make sure data is queued up through this upcoming
        %refresh and the next.
        
        %firstSample = hardwareBufferSize_*floor(max(lastsampleix_ + 1, status.PositionSecs * sampleRate_)/hardwareBufferSize_);
        firstSample = lastsampleix_+1;
        
        %if we fell behind, don't bother computing what's been skipped
        if status.ElapsedOutSamples > lastsampleix_
            if lastsampleix_ > 0
                underflowed_ = 1;
                %the log entry says:
                fprintf(logf_,'AUDIO_UNDERFLOW %d %d %f\n', lastsampleix_, status.ElapsedOutSamples, status.CurrentStreamTime);
            end                
            lastsampleix_ = status.ElapsedOutSamples;
        end
        %when the chunk we are to compute will start to hit the speaker.
        onset = status.CurrentStreamTime + (lastsampleix_ - status.ElapsedOutSamples + 1)/sampleRate_;
        
        %we need as many new samples as will carry us though the next
        %refreshes, chunked into hardware buffers.
        nSamples = hardwareBufferSize_*ceil( (state.next + interval_*framesAhead - onset)*sampleRate_/hardwareBufferSize_);
        %^number of samples
        %                                  ( number of buffers to compute                                                )                                 
        %Now compute the next chunk of audio (depending on the experiment)
        if (nSamples <= 0)
            return
        end
        data = gatherSamples_(firstSample, nSamples, sampleRate_, onset, channels);
        if ~isempty(filter)
            data = filter(firstSample, data, sampleRate_, onset, channels);
        end
        nDataSamples = size(data, 2);
 
        bufferIndex = mod(firstSample, outputBufferSize_);
        if (bufferIndex + nDataSamples > outputBufferSize_)
            if bufferIndex+nDataSamples == outputBufferSize_
                PsychPortAudio('RefillBuffer', pahandle_, 0, data, bufferIndex);
            else
                endn = outputBufferSize_ - bufferIndex;
                PsychPortAudio('RefillBuffer', pahandle_, 0, data(:,1:endn), bufferIndex);
                PsychPortAudio('RefillBuffer', pahandle_, 0, data(:,endn+1:end), 0);
            end
        else
            PsychPortAudio('RefillBuffer', pahandle_, 0, data, bufferIndex);
        end


        lastsampleix_ = lastsampleix_ + nDataSamples;
        nextStreamTime_ = onset + nSamples/sampleRate_;
    end

    function out = gatherSamples_(firstSample, nSamples, sampleRate, onset, channels)
        out = zeros(numel(channels), nSamples);

        %for samples that are running:
        %running_ = {sampleName_; total_samples, starting_index};
        
        %add up all the sounds that are running.
        for s = size(running_, 1):-1:1;
            %how many samples for this...
            i = firstSample - running_{s,3} + 1; %index within sample of beginning of chunk
            ns = min(nSamples, running_{s,2} - i + 1); %number of points to extract from sample
            sampleData = sampleData_.(running_{s,1});
            out(:, 1:ns) = out(:, 1:ns) + sampleData(:,i:i+ns-1); %extracting into the right place.
            
            if ns >= running_{s,2} - i + 1
                %done with that sample, remove it from running.
                running_(s,:) = [];
            end
        end
        
        %Find samples that are starting now, and add them as well.
        ix = find([starting_{:,1}] <= onset + (nSamples-1)/sampleRate | isnan([starting_{:,1}]));
        for i = ix(:)'            
            sampleOnset = starting_{i,1};
            sampleContents = sampleData_.(starting_{i,2});
            
            if isnan(sampleOnset)
                sampleOnset = onset;
            end

            %possible that the sample started before our chunk start time
            startIndex = round((sampleOnset - onset)*sampleRate + 1);
            if startIndex <= 0
                sampleStartIndex = 2 - startIndex;
                startIndex = 1;
                %should probably log this condition as it indicates a
                %sample
                %started midway through.
                if sampleStartIndex > size(sampleContents, 2)
                    break;
                end
            else
                sampleStartIndex = 1;
            end

            %does the sample actually complete in this chunk?
            if size(sampleContents, 2) - sampleStartIndex + 1 + startIndex - 1 - nSamples <= 0
                out(:, startIndex:(startIndex + size(sampleContents, 2)-sampleStartIndex)) = ...
                    out(:, startIndex:(startIndex + size(sampleContents, 2)-sampleStartIndex)) + sampleContents(:,sampleStartIndex:end);
            else
                %sample starts and continues into the next chunk
                out(:, startIndex:end) = out(:, startIndex:end) + sampleContents(:, sampleStartIndex:(sampleStartIndex + nSamples - startIndex));
                running_(end+1, :) = {starting_{i,2}, size(sampleContents, 2), firstSample + startIndex + sampleStartIndex - 2};
            end
            
            %log that the sample played.
            fprintf(logf_,'AUDIO_SAMPLE %s %.15g %d\n', starting_{i,2}, sampleOnset, firstSample + startIndex - 1);
        end
        starting_(ix,:) = [];
    end

    function out = dummy_(from,howmany,rate,onset,channels) %#ok
        %fill buffer with zeros
        out = zeros(numel(channels), howmany); 
    end

    function [startTime, endTime] = play(sampleName, time) %#ok
        %function play(sampleName, time)
        %'time' is the scheduled onset time of the sample. Note audio is
        %computed slightlt in advance of graphics (typically.) If you
        %do not schedule your sounds well in advance, specify time=NaN or
        %leave off; it will play "as soon as possible" and the ESTIMATED
        %start time will be returned.
        if nargin < 2
            time = NaN;
        end

        starting_(end+1, :) = {time, sampleName};
        if isnan(time) %when might we begin the sample?
            startTime = nextStreamTime_;
        else
            startTime = time;
        end
        
        endTime = startTime + size(sampleData_.(sampleName), 2) / sampleRate_;
    end

    persistent init__; %#ok
    this = autoobject(varargin{:});
end