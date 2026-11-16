function homeTable(dev)
%HOMETABLE  Turn slowly until the home flag enters the sensor, and zero there.
%
%   rig.homeTable(dev)
%
%   Needs the optional photo-interrupter. Gives every ring the same
%   starting angle, which removes the half-sample step at ring joins.

lines = rig.command(dev, 'H', 'HOME', 100);
if isempty(strfind(lines{end}, 'ok')) %#ok<STREMP>
    error('rig:homeFailed', 'Homing failed: no flag seen within one revolution.');
end
end
