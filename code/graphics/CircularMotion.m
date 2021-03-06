function this = circularMotion(varargin)
    %note, make 'radius' a 2*2 matrix and this can be used for elliptical
    %motion as well...

    center = [0;0];
    radius = 0;
    omega = 0;
    phase = 0;
    
    %argh! variable onsets need to extend to this too...
    
    persistent init__;
    this = autoobject(varargin{:});
    
    function loc = e(t)
        c = center(:);
        loc = c(:, ones(numel(t),1)) + [cos(t*omega + phase); -sin(t*omega+phase)] * radius;
    end
end