function this = SpaceEvents(calibration_)
%base class for event managers that teack an object (mouse, eye) over
%time.
this = public(@add, @remove, @update, @clear, @sample);

%-----private data-----

%The event-oriented idea is based around a list of triggers. The
%lists specify a criterion that is to be met and a function to be
%called when the criterion is met.

%Array of trigger-interface objects. An advantage of closure-structs over
%matlab objects is that you can have an array containing diferent
%implementations of one interface.

triggers_ = cell(0);
transform_ = transformToDegrees(calibration_);

    function add(trigger)
        %adds a trigger obeject.
        triggers_{end + 1} = trigger;
    end

    function remove(trigger)
        %Removes a trigger object.
        searchid = trigger.id();
        found = find(cellfun(@(x)x.id() == searchid, triggers_), 'UniformOutput', 0);
        triggers_{found(1)} = [];
    end

    function clear
        triggers{1:end} = [];
    end

    function update
        %Sample the eye
        [x, y, t] = this.sample();
        [x, y] = transform_(x, y); %convert to degrees (native units)

        %send the sample to each trigger and the triggers will fire if they
        %match
        for trig = triggers_
            trig{:}.check(x, y, t);
        end
    end
end