function [inner, outer] = grooveEdges(disc, angle)
%GROOVEEDGES  True edge radii of the synthetic groove at an unwound angle.
%
%   [inner, outer] = groove.sim.grooveEdges(disc, angle)
%
%   angle  unwound playback angle in radians (0 = start of the groove);
%          any array shape
%   inner, outer  edge radii in mm, same shape as angle

time   = angle / (2*pi) * 60 / disc.rpm;
centre = disc.startRadiusMm - disc.pitchUm * 1e-3 * angle / (2*pi) ...
         + disc.eccentricityUm * 1e-3 * cos(angle);
half   = disc.grooveWidthUm * 1e-3 / 2;

inner = centre - half + sqrt(2) * 1e-3 * disc.leftUm(time);
outer = centre + half + sqrt(2) * 1e-3 * disc.rightUm(time);
end
