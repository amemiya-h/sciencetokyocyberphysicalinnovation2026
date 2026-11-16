function positionMm = moveRadial(dev, millimetres, mmPerSecond)
%MOVERADIAL  Move the radial axis by a distance, and wait until done.
%
%   positionMm = rig.moveRadial(dev, 3.8)         % 3.8 mm toward the spindle
%   positionMm = rig.moveRadial(dev, -3.8, 0.5)   % back out, at 0.5 mm/s
%
%   The turntable must be at rest. Returns the radial position the
%   controller reports, in mm from where it was last zeroed.

if nargin < 3
    mmPerSecond = 1;
end
rig.command(dev, sprintf('W %.4f', mmPerSecond), 'OK');
lines = rig.command(dev, sprintf('Y %.4f', millimetres), 'OK,Y', abs(millimetres) / mmPerSecond + 30);
positionMm = NaN;
for n = 1:numel(lines)
    if strncmp(lines{n}, 'RD,', 3)
        fields = sscanf(lines{n}(4:end), '%f,%f,%f');
        positionMm = fields(3);
    end
end
end
