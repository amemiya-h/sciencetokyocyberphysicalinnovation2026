function rgb = eyepiece_look(I, x, y, opts)
%EYEPIECE_LOOK  Present a simulated frame like a photo through the eyepiece.
%   rgb = EYEPIECE_LOOK(I, x, y, opts) turns a monochrome frame (rows along
%   the groove, values in [0,1]) into a colour image with the grooves
%   running left to right, tinted like the microscope lamp, with an
%   optional circular field stop and vignetting. For display only; the
%   retrieval uses the monochrome frames.
%
%   Inputs
%     I     nRows x nCols frame, x across (um), y along the groove (um)
%     opts  struct with fields
%       tint        1x3 RGB of the brightest land, 0..1, e.g. a halogen
%                   lamp [0.87 0.70 0.42]
%       fieldStop   diameter of the visible circle (um), [] for none
%       vignetting  brightness lost at the edge of the field (0..1)
%
%   Output
%     rgb   uint8 image, nCols x nRows x 3

J = I' / prctile_simple(I(:), 0.98);              % land ~ 1
[Y, X] = meshgrid(y - mean(y), x - mean(x));      % same layout as J
r = sqrt(X.^2 + Y.^2);
if isempty(opts.fieldStop)
    R = max(r(:));
else
    R = opts.fieldStop / 2;
end
J = J .* (1 - opts.vignetting * min(r / R, 1).^2);
J(r > R) = 0;

rgb = uint8(255 * min(max(J .* reshape(opts.tint, 1, 1, 3), 0), 1));
end

function v = prctile_simple(a, p)
a = sort(a);
v = a(max(1, round(p * numel(a))));
end
