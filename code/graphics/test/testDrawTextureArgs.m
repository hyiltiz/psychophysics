function this = testDrawTextureArgs()
    this = struct();

    params_ = struct();
    
    function initializer = init()
        initializer = joinResource ...
            ( getScreen ...
                ( 'backgroundColor', 0 ...
                , 'foregroundColor',  1 ...
                , 'requireCalibration', 0 ...
                , 'preferences.SkipSyncTests', 2 ...
                , 'preferences.Verbosity', 0 ...
                , 'preferences.SuppressAllWarnings', 1 ...
                , 'preferences.VisualDebugLevel', 0 ...
                ) ... 
            , @makeTextures ...
            , @storeParams ...
            );
        
        function [r, params] = makeTextures(params);
            %make up some textures
            [x, y] = meshgrid( linspace(0, 1, 256), linspace(0, 1, 256) );
            a1 = (-cos(4 * 2 * pi * x) + 1) / 4 ...
               * (params.whiteIndex - params.blackIndex) + params.blackIndex;
            a2 = (-cos(4 * 2 * pi * y) + 1) / 4 ...
               * (params.whiteIndex - params.blackIndex) + params.blackIndex;
            
            params.tex1 = Screen('MakeTexture', params.window, a1);
            params.tex2 = Screen('MakeTexture', params.window, a2);
            
            r = @remove;
            function remove()
                if any(Screen('Windows') == params.window)
                    Screen('Close', params.tex1);
                    Screen('Close', params.tex2);
                end
            end
        end
        
        function [r, params] = storeParams(params)
            params_ = params;
            r = @remove;
            function remove
                params_ = struct();
            end
        end
    end

    function testNormals
        Screen( 'DrawTexture', params_.window, params_.tex1 ...
              , [], [], [], [], []);
        Screen( 'DrawTexture', params_.window, params_.tex2 ...
              , [], [], [], [], []);
        Screen('Flip', params_.window);
        %should draw 4 horizontal stripes
        WaitSecs(0.5);
    end

    function testChangeSrcFactorOnly
        Screen( 'DrawTexture', params_.window, params_.tex1 ...
               , [], [], [], [], [], 'GL_ONE', []);
        Screen( 'DrawTexture', params_.window, params_.tex2 ...
              , [], [], [], [], [], hex2dec('0306'), []); %GL_DST_COLOR
        Screen('Flip', params_.window);
        %should draw grid of round bumps
        WaitSecs(0.5);
    end

    function testChangeDstFactorOnly
        Screen('DrawTexture', params_.window, params_.tex1 ...
              , [], [], [], [], [], [], 1); %GL_ONE
        Screen('DrawTexture', params_.window, params_.tex2 ...
              , [], [], [], [], [], [], 'GL_SRC_COLOR');
        Screen('Flip', params_.window);
        %should draw bumps on top of stripes
        WaitSecs(0.5);
    end

    function testChangeBothFactors
        Screen('DrawTexture', params_.window, params_.tex1 ...
              , [], [], [], [], [], 'GL_ONE', 1);
        Screen('DrawTexture', params_.window, params_.tex2 ...
              , [], [], [], [], [], 1, 'GL_ONE');
        Screen('Flip', params_.window);
        %should draw a plaid
        WaitSecs(0.5);
    end

    function testChangeEquation
        Screen('DrawTexture', params_.window, params_.tex1 ...
              , [], [], [], [], [], [], [], 'GL_FUNC_ADD');
        Screen('DrawTexture', params_.window, params_.tex2 ...
              , [], [], [], [], [], [], [], hex2dec('8008')); %max
        Screen('Flip', params_.window);
        %should draw a waffle
        WaitSecs(0.5);
    end

    function invalidSrcFactorTestGen(srcfactor)
        try
            Screen('DrawTexture', params_.window, params_.tex2 ...
                , [], [], [], [], [], srcfactor, []);
            fail('expected error for %s', dumpstring(srcfactor, 'constant'));
        catch
            %Gah, there's no way in matlab to do this idiom cleanly! No 
            %usable concept of an exception type.
            e = lasterror;
            assert(~isequal(e.identifier, 'assert:assertionFailed'));
        end
    end

    for srcfactor = {'GL_SRC_COLOR', 'GL_SRC_CrLOR', 768, 2345}
        this.(['testInvalidSrcFactor_' num2str(srcfactor{:})]) = ...
            @() invalidSrcFactorTestGen(srcfactor{:});
    end

    function invalidDstFactorTestGen(dstfactor)
        try
            Screen('DrawTexture', params_.window, params_.tex2 ...
                , [], [], [], [], [], [], dstfactor);
            fail('expected error for %s', dumpstring(dstfactor, 'constant'));
        catch
            %Gah, there's no way in matlab to do this idiom cleanly! No 
            %usable concept of an exception type.
            e = lasterror;
            assert(~isequal(e.identifier, 'assert:assertionFailed'));
        end
    end

    for dstfactor = {'GL_DST_COLOR', 'GL_DST_CrLOR', 774, 2345}
        this.(['testInvalidDstFactor_' num2str(dstfactor{:})]) = ...
            @() invalidDstFactorTestGen(dstfactor{:});
    end

    function invalidEqnTestGen(eqn)
        try
            Screen('DrawTexture', params_.window, params_.tex2 ...
                , [], [], [], [], [], [], [], eqn);
            fail('expected error for %s', dumpstring(dstfactor, 'constant'));
        catch
            %Gah, there's no way in matlab to do this idiom cleanly! No 
            %usable concept of an exception type.
            e = lasterror;
            assert(~isequal(e.identifier, 'assert:assertionFailed'));
        end
    end

    for eqn = {'GL_FUNC_ODD', hex2dec('800c')}
        this.(['testInvalidEqn_' num2str(eqn{:})]) = ...
            @() invalidEqnTestGen(eqn{:});
    end

    this = inherit ...
        ( TestCase() ...
        , public ...
            ( @init ... 
            , @testNormals ...
            , @testChangeSrcFactorOnly ...
            , @testChangeDstFactorOnly ...
            , @testChangeBothFactors ...
            , @testChangeEquation ...
            ) ...
        , publicize(this) ...
        );
end
