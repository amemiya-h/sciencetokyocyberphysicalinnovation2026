function [b, a] = biquad_design(type, f0, fs, Q)
%BIQUAD_DESIGN  2nd-order 'low' or 'high' pass (bilinear, prewarped).
%   Q = 1/sqrt(2) gives a Butterworth section.
w0 = 2 * pi * f0 / fs; al = sin(w0) / (2 * Q); cw = cos(w0);
switch type
    case 'low',  b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2];
    case 'high', b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2];
end
a = [1 + al, -2 * cw, 1 - al];
b = b / a(1); a = a / a(1);
end
