function [time1, time2, before_request, before_request2, offset] = getEyelinkTime(timeout)
    % FIXME: This is slow (50 MS). Eyelink('TimeOffset') is fast but it
    % measures tracker time since the initialization of the Eyelink
    % library, whcih is fucking useless

    
    %{
        %select and eval this part after defining your function...
        Eyelink('Initialize');
        Priority(9);

        [time1, time2, before1, before2, offsets] = deal(zeros(1000,1));

            begin = GetSecs()
            for i = 1:numel(time1)
                [time1(i), time2(i), before1(i), before2(i), offsets(i)] = getEyelinkTime(0.05);
                WaitSecs(0.01);
                if GetSecs() - begin > 10
                    time1(i+1:end) = [];
                    time2(i+1:end) = [];
                    before1(i+1:end) = [];
                    before2(i+1:end) = [];
                    offsets(i+1:end) = [];
                    break;
                end
            end

        Priority(0);
        plot( before1 - before1(1), (time1 - time1(1))/1000 - before1 + before1(1), 'r-'...
            , before2 - before2(1), (time2 - time2(1))/1000 - before2 + before2(1), 'b-'...
            , before2 - before2(1), (offsets - offsets(1))/1000, 'g-');

        title('Time offsets');
        ylabel('offset (s)');
        legend('Using TrackerTime', 'Using RequestTime/ReadTime', 'Using TimeOffset', 'Location', 'SouthOutside');

        xlabel('time of measurement (s)');
    
        Eyelink('ShutDown');

    %}

    %requests the time from the eyelink, and the time before and after
    %the request was made. after 'softtimeout' has passed, the eyelink
    %is prodded again. After 'hardtimeout' has passed, an error is
    %thrown. Unreliable stuff, this...

    before_request = GetSecs();
    time1 = Eyelink('TrackerTime') * 1000;
    offset = Eyelink('TimeOffset');
    before_request2 = GetSecs();
    status = Eyelink('RequestTime');
    after_request = GetSecs();

    if status ~= 0
        error('doClockSync:badStatus', ...
            'status %d from requesttime', status);
    end

    start = before_request;
    time2 = 0;
    time2 = Eyelink('ReadTime');
    while(time2 == 0)
        s = GetSecs();
        if (s - start) > timeout
            disp('timeout');
            time2 = NaN;
            break;
        end
        WaitSecs(0.0005);
        time2 = Eyelink('ReadTime');
    end
end