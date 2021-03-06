function initializer = GetEyelink(varargin)
%
%Produces an intialization function for use with REQUIRE, which:
%
%Connects to the Eyelink system, running the
%calibration and choosing an file name; cleans up the connection at close.
%
%Input structure fields:
%   window - the PTB window number
%   rect - the window rect
%   edfname - the file name to use -- use empty string for no file,
%                otherwise it will pick a name
%
%Output structure fields:
%   el - the eyelink info structure
%   edfname - the EDF file name
%   localname - full path to where the EDF file is downloaded locally
%   dummy - whether the eyelink was opened in dummy mode

FILE_CANT_OPEN = -1;

defaults = struct...
    ( 'hideCursor', 0 ...
    );

%build the initializer, and curry it with given args.

initializer = joinResource(namedargs(defaults, varargin{:}), @connect, @initDefaults, @doSetup, @openEDF);

%sub-initializers:

    %open/close the eyelink connection
    function [release, details] = connect(details)
        
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
                details.dummy = 0;
            catch
                %There is no rhyme or reason as to why eyelink throws
                %an error and not a status code here
                status = -1;
            end
            if (status < 0)
                warning('GetEyelink:dummyMode', 'Using eyelink in dummy mode');
                status = Eyelink('InitializeDummy');
                details.dummy = 1;
            end
        else
            if details.dummy
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
                Eyelink('Shutdown'); %no output argument
            end
        end
    end


    %initialize eyelink defaults. Requires the 'window' field from getScreen.
    %output fields - 'dummy' if we are in dummy mode
    function [release, details] = initDefaults(details)
        el = EyelinkInitDefaults(details.window);
        details.el = el;
    
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

    %do the tracker setup. Requires the 'el' field from initDefaults as
    %well as the 'rect' field from getScreen.
    function [release, details] = doSetup(details)
        
        %set and record as many settings as possible
        details = setupEyelink(details);
        
        if details.dummy
            message(details, 'Eyelink unattached, using mouse mode');
        else
            message(details, 'Do tracker setup now');
            status = EyelinkDoTrackerSetup(details.el, details.el.ENTER_KEY);
            if status < 0
                error('getEyelink:TrackerSetupFailed', 'Eyelink setup failed.');
            end
        end
        
        %repeat it again since doTrackerSetup turns on filtering, FFS
        details = setupEyelink(details);
        
        if (details.hideCursor)
            HideCursor();
        end
        [release, details] = deal(@show, details);
        
        function show
            ShowCursor();
        end
    end

    %open the eyelink data file on the eyelink machine
    %input field: dummy: skips a file check in dumy mode
    %output field: edfFilename = the name of the EDF file created
    function [release, details] = openEDF(details)
        e = env;

        if ~isfield(details, 'edfname')
            %pick some kind of unique filename by combining a prefix with
            %a 7-letter encoding of the date and time

            pause(1); % to make it likely that we get a unique filename, hah!
                      % oh, why is the eyelink so dumb?q
            details.edfname = ['z' clock2filename(clock) '.edf'];
        end
        
        if ~isfield(details, 'localname') || (~isempty(details.edfname) && isempty(details.localname))
            %make a note of where we will find the file locally
            
            %if we're in an experiment, use those values...
            if all(isfield(details, {'subject', 'caller'}))
                details.localname = fullfile...
                    ( e.eyedir...
                    , sprintf ...
                    ( '%s-%04d-%02d-%02d__%02d-%02d-%02d-%s.edf'...
                    , details.subject, floor(clock), details.caller.function ...
                    ) ...
                    );
            else
                details.localname = fullfile(e.eyedir, details.edfname);
            end
        end

        if ~isempty(details.edfname)
            %the eyelink has no way directly to check that the filename is
            %valid or non-existing... so we must assert that we can't open the
            %file yet.
            tmp = tempname();
            status = Eyelink('ReceiveFile',details.edfname,tmp);
            if (~details.dummy) && (status ~= FILE_CANT_OPEN)
                error('Problem generating filename (expected status %d, got %d)',...
                    details.el.FILE_CANT_OPEN, status);
            end

            %destructive step: open the file
            %FIXME - what data can I get out of here?
            Eyelink('command', 'link_sample_data = LEFT,RIGHT,GAZE,AREA');
            status = Eyelink('OpenFile', details.edfname);
            if (status < 0)
                error('getEyelink:fileOpenError', ...
                    'status %d opening eyelink file %s', status, details.edfname);
            end
            
            if isfield(details, 'log')
                oldlog = details.log;
            else
                oldlog = @noop;
            end

            params.log = @logMessage;
        else
            %not recording -- don't leave some random previous file open on
            %eyelink
            status = Eyelink('CloseFile');
            if status ~= 0
                error('GetEyelink:couldNotClose', 'status %d closing EDF file', status);
            end
            details.localname = '';
        end
        
        %when we are done with the file, download it
        release = @downloadFile;


        function downloadFile
            %if we were recording to a file, download it
            if ~isempty(details.edfname) && ~isempty(details.localname)
                %try both in any case
                status = Eyelink('CloseFile');
                if Eyelink('IsConnected') ~= details.el.dummyconnected
                    fsize = Eyelink('ReceiveFile', details.edfname, details.localname);

                    if (fsize < 0 || status < 0)
                        error('getEyeink:fileTransferError', ...
                            'File %s empty or not transferred (close status: %d, receive: %d)',...
                            details.edfname, status, fsize);
                    end
                end
            end
        end
        
        function logMessage(str)
           %FIXME: if not recording to an EDF this is just unnecessary....
            if Eyelink('IsConnected')
                chunksize = 128;
                %the eyelink logs mesages with a maximum length of 139 chars,
                %so we should wrap longer messages (placing a backslash at the
                %end of message as reminder) into 139 char blocks.
                stop = 0;
                for i = 1:chunksize-1:numel(str)
                    if numel(str) > i + chunksize-1
                        chunk = [str(i:i+chunksize-2) '\'];
                    else
                        chunk = str(i:end);
                        stop = 1;
                    end

                    try
                        %the eyelink toolbox is very picky and will crash eveything if
                        %the string is too long or contains incorrect format
                        %specifiers...
                        status = Eyelink('Message', '%s', chunk);

                        %generally we want to keep logging to the file when
                        %these may be a problem with the eyelink
                        if status ~= 0
                            warning('status %d logging to eyelink', status);
                            fprintf(file_, 'WARNING status %d logging to eyelink\n', status);
                        end
                    catch
                        e = lasterr;
                        warning('openLog:eyelinkException', 'error logging to eyelink: %s', e);
                        fprintf(file_, 'WARNING error logging to eyelink: %s\n', e);
                    end

                    if(stop)
                        break;
                    end
                end
            end 
            oldlog(str);
        end
    end
end
