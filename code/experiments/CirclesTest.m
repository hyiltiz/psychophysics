function CirclesTest(varargin)
    params = struct...
        ( 'edfname',    '' ...
        , 'dummy',      1  ...
        , 'skipFrames', 0  ...
        , 'requireCalibration', 0 ...
        , 'density', 0.5 ...
        );
    params = namedargs(params, varargin{:});

    c = CircularMotionProcess;
    require(setupEyelinkExperiment(params), @runDemo)
    function runDemo(params)
        
        patch = CauchyPatch...
            ( 'velocity', 5 ...
            , 'size', [0.5 0.75 0.1]...
            );
        
        radius = 4;
        n = 5; %number going each way
        separation = 12; %
        dx = 0.75;
        dt = 0.15;
        
        phases = (1:n) * 2 * pi / n;
        circle1 = CircularMotionProcess ...
            ( 'radius', radius ...
            , 'dt', dt ...
            , 'x', separation/2 ...
            , 'dphase', dx / radius ...
            , 'phase', phases ...
            , 'angle', 90 + phases * 180 / pi ...
            , 'color', [0.5 0.5 0.5] ...
            , 't', sort(rand(1, n)) * dt ...
            );
        
%        phases = rand(1, n) * 2 * pi;
        circle2 = CircularMotionProcess ...
            ( 'radius', radius ...
            , 'dt', dt ...
            , 'x', -separation/2 ...
            , 'dphase', -dx / radius ...
            , 'phase', phases ...
            , 'angle', 90 + phases * 180 / pi ...
            , 'color', [0.5 0.5 0.5] ...
            , 't', sort(rand(1, n)) * dt ...
            );

        dots = ComboProcess(circle1, circle2);
        
        sprites = SpritePlayer(patch, dots);
        
        fixation1 = FilledDisk([separation/2 0], 0.075, 0);
        fixation2 = FilledDisk([-separation/2 0], 0.075, 0);
        
        startTrigger = UpdateTrigger(@start);
        
        main = mainLoop ...
            ( {sprites, fixation1, fixation2} ...
            , {startTrigger} ...
            );
        
        params = main.go(params);
        
        function start(x, y, t, next)
            sprites.setVisible(1, next);
            fixation1.setVisible(1);
            fixation2.setVisible(1);
            startTrigger.unset();
        end
        
    end
end