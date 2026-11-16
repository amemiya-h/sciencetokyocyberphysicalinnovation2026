function [Z, wall] = groove_surface(x, centres, depths, scene)
%GROOVE_SURFACE  Height map of one or more parallel V-grooves.
%   [Z, wall] = GROOVE_SURFACE(x, centres, depths, scene)
%
%   Each groove has a 90-degree-style V cross-section (scene.includedAngle)
%   with a rounded bottom (scene.bottomRadius) and rounded edges
%   (scene.rimRadius). Lateral modulation moves the whole cross-section
%   sideways, which is how a cutting stylus moves. Vertical modulation
%   changes the depth, and with it the groove width.
%
%   Inputs
%     x        1 x nCols positions across the grooves (um)
%     centres  nRows x nGrooves centreline of each groove in each row (um)
%     depths   nRows x nGrooves depth of each groove in each row (um)
%     scene    struct with includedAngle (deg), bottomRadius, rimRadius (um)
%
%   Outputs
%     Z     nRows x nCols height: 0 on the land between grooves (um)
%     wall  nRows x nCols logical, true on the straight groove walls (used
%           for the wall-to-wall double reflection)

Z = zeros(size(centres, 1), numel(x));
wall = false(size(Z));
for g = 1:size(centres, 2)
    [zg, wg] = groove_profile(abs(x(:)' - centres(:, g)), depths(:, g), scene);
    deeper = zg < Z;
    Z(deeper) = zg(deeper);
    wall(deeper) = wg(deeper);
end
end
