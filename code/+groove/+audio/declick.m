function [edge, clickFraction] = declick(edge, sampleRate, maxVelocityCmS)
%DECLICK  Remove jumps no cutting lathe could have made.
%
%   [edge, clickFraction] = groove.audio.declick(edge, sampleRate, maxVelocityCmS)
%
%   edge   one groove edge along the groove, in mm
%   A speck of dust or a mis-read edge shows as the edge moving sideways
%   faster than any recorded sound does. Samples around such a jump are
%   replaced by a straight line between their good neighbours.
%
%   clickFraction  share of samples replaced

velocity = [0, diff(edge)] * sampleRate / 10;          % cm/s
jump = abs(velocity) > maxVelocityCmS;
bad  = conv(double(jump), ones(1, 9), 'same') > 0;     % a few samples either side
clickFraction = mean(bad);
if any(bad)
    edge(bad) = NaN;
    edge = groove.util.fillGaps(edge);
end
end
