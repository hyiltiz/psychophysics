function this = TimeTrigger(time_, fn_)
%Produces an object fires a trigger when a certain time has passed.
%The object has a unique serial number.

%----- public interface -----
this = inherit(Identifiable(), public(@check));

%----- methods -----
    function check(x, y, t)
        if (t >= time_)
            fn_(x, y, t);
        end
    end
end