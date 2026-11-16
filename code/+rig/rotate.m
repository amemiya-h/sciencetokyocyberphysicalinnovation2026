function rotate(dev, degrees, degreesPerSecond)
%ROTATE  Turn the table by an angle at a steady speed, and wait until done.
%
%   rig.rotate(dev, 396, 4.2)
%
%   Positive angles turn counter-clockwise seen from above (firmware
%   convention). The firmware ramps up and down at its set acceleration.

rig.command(dev, sprintf('R %.4f', abs(degreesPerSecond)), 'OK');
duration = abs(degrees) / abs(degreesPerSecond);
rig.command(dev, sprintf('M %.4f', degrees), 'DN', duration + 30);
end
