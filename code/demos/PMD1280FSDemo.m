function this = PMD1280FSDemo(varargin)

%I want to sample X and Y at 1000 Hz, and receive at least 120
%packets/second. At 31 samples/packet, I need 3720 samples/sec.
%So on two channels, do this by oversampling 2x:

    defaults = struct ...
        ( 'daqOptions', struct ...
            ( 'f', 1000 ...
            , 'channel', [0 1 0 1 0 1 0 1] ... %sample channels 1 and 2 repeatedly for oversampling
            , 'range', [1 1 1 1 1 1 1 1] ...
            , 'immediate', 0 ...
            , 'trigger', 0 ... %set this to 1 and connect the vsync line
            ...                %from the monitor port to the PMD's trigger
            ...                %input, and sample start will be
            ...                %synchronized with the flame 
            ) ...
        , 'preferences', struct('skipSyncTests', 2) ...
        , 'backgroundColor', 0 ...
        , 'foregroundColor', 1 ...
        , 'requireCalibration', 0 ...
        , 'history', 10000 ... %how many points to draw on the screen at once
        , 'bigSparkColor', [5 1 0]' ...
        , 'bigSparkSize', 8 ...
        , 'bigSparkVelocity', 5 ... %pixels per second
        , 'bigSparkLifetime', 20 ... %seconds
        , 'bigSparkJump', 0 ... %seconds
        , 'littleSparkColor', [0 127 255]' ...
        , 'littleSparkSize', 2 ...
        , 'littleSparkVelocity', 100 ... %pixels per second
        , 'littleSparkLifetime', 10 ... %seconds
        , 'littleSparkJump', 50 ... %pixels
        , 'sparkLengthScaler', 0.05 ... %
    );
        
    params = namedargs(defaults, varargin{:});
    device = PMD1208FS('options', params.daqOptions);
    %device.reset();

    require(getScreen(params), device.init, highPriority(), @runDemo);
    function runDemo(params)
        %scale the full samples range of the ADC onto the screen.
        offset = (params.rect([3 4]) + params.rect([1 2]))' / 2;
        vmax = device.vmax();
        gain = (params.rect([3 2])' - offset) ./ vmax([1;2]);
    
        interval = Screen('getFlipInterval', params.window);
        
        %add like sparkles
        Screen('BlendFunction', params.window, 'GL_SRC_ALPHA', 'GL_ONE');
        
        [VBL] = Screen('Flip', params.window);
        device.AInScanBegin(VBL + interval);
        [samples, t] = device.AInScanSample();
        [VBL] = Screen('Flip', params.window);

        %run until mouse is pressed
        buttons = [];
        sampleHistory = zeros(2,0);
        tHistory = zeros(1,0);
        vHistory = zeros(2,0);
        while ~any(buttons)
            
            %apply oversampling and gain corrections
            samples = [mean(samples(1:2:end, :), 1); mean(samples(2:2:end, :), 1)];
            samples = samples .* gain(:, ones(1, size(samples, 2))) + offset(:, ones(1, size(samples, 2)));
           
            %remember the most recent points for drawing to the screen
            nPoints = params.history;
            nNewPoints = min(size(samples,2),nPoints);
            sampleHistory = ...
                [ sampleHistory(:, max(1, end-(nPoints)+nNewPoints+1):end) ...
                , samples(:, end-nNewPoints+1:end) ...
                ];
            tHistory = ...
                [ tHistory(:, max(1, end-(nPoints)+nNewPoints+1):end) ...
                , t(:, end-nNewPoints+1:end) ...
                ];
            vHistory = ...
                [ vHistory(:, max(1, end-(nPoints)+nNewPoints+1):end) ...
                , randn(2, nNewPoints) ...
                ];
            
            
            if size(sampleHistory, 2) >= 1
                %sparks move
                lifetimes = abs((VBL + interval) - tHistory);
                coords = sampleHistory + (lifetimes([1;1],:) + params.bigSparkJump).*vHistory.*params.bigSparkVelocity;
                colors = params.bigSparkColor * max(1 - lifetimes / params.bigSparkLifetime, 0);
                Screen('DrawDots', params.window, coords, params.bigSparkSize, colors, [], 0);
                
                norm = [1;1] * (sqrt(vHistory(1,:).^2 + vHistory(2,:).^2));
                normed = vHistory ./ norm;
                jumps = normed * params.littleSparkJump;
                starts = sampleHistory + (lifetimes([1;1],:)).*vHistory.*params.littleSparkVelocity + jumps;
                ends =   sampleHistory + (lifetimes([1;1],:) + norm*params.sparkLengthScaler).*vHistory.*params.littleSparkVelocity + jumps;
                colors = params.littleSparkColor * max(1 - lifetimes / params.littleSparkLifetime, 0);
                Screen('DrawLines', params.window, reshape([starts; ends], 2, []), params.littleSparkSize, reshape([colors; colors], 3, []), [], 0);
            end

            Screen('DrawingFinished', params.window);
            
            %grab more samples
            [samples, t] = device.AInScanSample();
            [x, y, buttons] = GetMouse();
            
            VBL = Screen('Flip', params.window, VBL + interval/2);
        end
        
        device.AInStop();
        
    end

end
