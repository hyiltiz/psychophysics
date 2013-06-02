function FourWheelsDemo(varargin)
    params = struct...
        ( 'edfname',    '' ...
        , 'dummy',      1  ...
        , 'skipFrames', 1  ...
        , 'requireCalibration', 0 ...
        , 'hideCursor', 0 ...
        , 'aviout', '' ...
        );

    persistent init__;
    this = autoobject();

    playDemo(this, params, varargin{:});

    function run(params)

        interval = params.cal.interval; %screen refresh interval

        base = 14; %base of square

        radius = 2.5; %approximate radius
        n = 5; %number in each wheel
        dx = 0.75; %translation per appearance
        dt = 0.15; %time interval between appearances
        contrast = 1; %contrast of each appearance (they superpose)

        %To make a looped movie, the radius should be adjusted so that a
        %whole number of translations brings the spot back exactly.
        radius = round(radius*2*pi/dx)*dx/2/pi %adjusted radius (will print out)
        period = radius*2*pi*dt/dx %time taken for a full rotation (will print out)

        %how many frames to render (2 full rotations)
        nFrames = round(2 * period / interval)

        %spatiotemporal structure of each appearance:
        phases = (1:n) * 2 * pi / n; %distribute evenly around a circle
        times = (0:n-1) * 0 - 2*dt; %dt/n - 2*dt; %onset times are *not* staggered to avoid strobing appearance, but start "before" 0 to have a fully formed wheel at the first frame
        phaseadj = dx/dt / radius * times; %compensate positions for staggered onset times

        %on the left two, congruent motion
        patch1 = CauchyPatch...
            ( 'velocity', 5 ... %velocity of peak spatial frequency
            , 'size', [0.75 0.375 0.1]... %half wavelength of peak spatial frequency in x; sigma of gaussian envelopes in y and t
            , 'order', 4 ... %order of cauchy function
            );

        circle1a = CircularMotionProcess ...
            ( 'radius', radius ...
            , 'dt', dt ...
            , 'x', -base/sqrt(2) ...
            , 'y', -base/sqrt(2) ...
            , 'dphase', -dx / radius ...
            , 'phase', phases... % - phaseadj ...
            , 'angle', 90 + phases * 180/pi... %(phases - phaseadj) * 180 / pi ...
            , 'color', [contrast contrast contrast]' / 3 ...
            , 't', times ...
            );

        circle1b = CircularMotionProcess ...
            ( 'radius', radius ...
            , 'dt', dt ...
            , 'x', -base/sqrt(2) ...
            , 'y', base/sqrt(2) ...
            , 'dphase', -dx / radius ...
            , 'phase', phases(1) ... % - phaseadj ...
            , 'angle', 90 + phases(1) * 180/pi... %(phases - phaseadj) * 180 / pi ...
            , 'color', [contrast contrast contrast]' / 3 ...
            , 't', times(1) ...
            );

        %on the right, incongruent motion
        patch2 = CauchyPatch...
            ( 'velocity', 5 ... %velocity of peak spatial frequency
            , 'size', [0.75 0.375 0.1]... %half wavelength of peak spatial frequency in x; sigma of gaussian envelopes in y and t
            , 'order', 4 ... %order of cauchy function
            );

        circle2a = CircularMotionProcess ...
            ( 'radius', radius ...
            , 'dt', dt ... % dt/2
            , 'x', base/sqrt(2) ...
            , 'y', -base/sqrt(2) ...
            , 'dphase', dx / radius ... % dx/2
            , 'phase', phases ... % + phaseadj...
            , 'angle', 90 + phases * 180/pi... ... % + (phases + phaseadj) * 180 / pi ...
            , 'color', [contrast contrast contrast]' / 3 ...
            , 't', times ...
            );

        circle2b = CircularMotionProcess ...
            ( 'radius', radius ...
            , 'dt', dt ... % dt/2
            , 'x', base/sqrt(2) ...
            , 'y', base/sqrt(2) ...
            , 'dphase', dx / radius ... % dx/2
            , 'phase', phases(1) ... % + phaseadj...
            , 'angle', 90 + phases(1) * 180/pi... ... % + (phases + phaseadj) * 180 / pi ...
            , 'color', [contrast contrast contrast]' / 3 ...
            , 't', times(1) ...
            );

%        dots = ComboProcess(circle1, circle2);

        sprites1a = CauchySpritePlayer(patch1, circle1a);
        sprites1b = CauchySpritePlayer(patch1, circle1b);
        sprites2a = CauchySpritePlayer(patch2, circle2a);
        sprites2b = CauchySpritePlayer(patch2, circle2b);

        %one fixation points at the center
        fixation = FilledDisk([0 0], 0.1, 0, 'visible', 1);

        keyboardInput = KeyboardInput();

        timer = RefreshTrigger();
        timer2 = RefreshTrigger();
        stopKey = KeyDown();

        main = mainLoop ...
            ( 'graphics', {sprites1a, sprites1b, sprites2a, sprites2b, fixation} ...
            , 'triggers', {stopKey, timer, timer2} ...
            , 'input', {keyboardInput} ...
            );

        stopKey.set(main.stop, 'q');
        timer.set(@start, 0);

        params = require(initparams(params), keyboardInput.init, main.go);

        function start(h)
            sprites1a.setVisible(1, h.next);
            sprites1b.setVisible(1, h.next);
            sprites2a.setVisible(1, h.next);
            sprites2b.setVisible(1, h.next);
            %timer.set(@moveSpot, h.refresh + oscillatoryDuration/interval);
            timer.unset();
            if ~isempty(params.aviout)
                timer2.set(main.stop, h.refresh + nFrames);
            end
        end

        function moveSpot(h)
            fixation3.setLoc([sin(2*pi*(h.refresh-h.triggerRefresh)*interval/oscillatoryPeriod)*oscillatoryAmplitude, -base/sqrt(3)]);
            if (h.refresh-h.triggerRefresh)*interval > oscillatoryDuration
                timer.set(@moveSpot, h.triggerRefresh + (oscillatoryDuration+oscillatoryDelay)/interval);
                fixation3.setLoc([0 -base/sqrt(3)]);
            end
        end
    end
end
