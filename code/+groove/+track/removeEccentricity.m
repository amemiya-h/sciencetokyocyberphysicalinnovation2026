function [position, eccentricityUm] = removeEccentricity(position)
%REMOVEECCENTRICITY  Take the off-centre wobble out of the groove position.
%
%   [position, eccentricityUm] = groove.track.removeEccentricity(position)
%
%   A pressing whose hole is off-centre adds a sine of exactly one cycle
%   per turn to the measured radius. It is fitted by least squares and
%   subtracted, leaving the path the lathe actually cut. Needs at least
%   two turns of data.

angle  = position.angleRad;
radius = position.radiusMm;
perRev = round(2*pi / (angle(2) - angle(1)));
assert(numel(radius) >= 2 * perRev, 'At least two turns are needed.');

% A one-turn moving average follows the spiral but is blind to the wobble.
% Computed from a running sum, for the samples that have a full turn
% around them.
halfTurn = floor(perRev / 2);
interior = (halfTurn + 1):(numel(radius) - halfTurn);
runningSum = cumsum([0, radius]);
trend = nan(size(radius));
trend(interior) = (runningSum(interior + halfTurn + 1) - runningSum(interior - halfTurn)) / (2 * halfTurn + 1);

basis = [cos(angle(:)), sin(angle(:))];
coefficients = basis(interior, :) \ (radius(interior) - trend(interior)).';

position.radiusMm = radius - (basis * coefficients).';
eccentricityUm = norm(coefficients) * 1e3;
end
