function T = synth_truth(shake)
%SYNTH_TRUTH  Known disc, poses and music for the synthetic Part A test.
%   A small video (768 x 576 px, 6 um/px, 360 frames) of a disc 24 mm from
%   the rig axis, turned by hand about 1.15 revolutions, with eccentricity,
%   wobble, a varying pitch, lens distortion, music on the groove, surface
%   texture and noise. The spiral sense is s = -1, so the fit has to find it.
%   synth_truth(true): hand-shake case: in four windows of frames the disc
%   jumps across the grooves by 0.24-0.44 groove from frame to frame (the
%   radial offset alternates in sign), and the turning reverses once.
if nargin < 1, shake = false; end
T.shake = shake;
T.p = 6; T.W = 768; T.H = 576; T.K = 360; T.fps = 10;
T.s = -1; T.sgnY = 1;
R = 4000;                                   % px, axis to image centre
m = tand(2.1);
ay = R / sqrt(1 + m^2);
T.a = [-m * ay; ay];
T.e = [-9; 12];                             % px (90 um)
k = (1:T.K)';
v = 80 * (1 + 0.35 * sin(2 * pi * k / 97) + 0.2 * sin(2 * pi * k / 31 + 1));
if shake, v(150:158) = -70; end            % reversal
T.theta = 0.3 + cumsum(v) / R;
T.w = [1.2 * sin(2 * pi * k / 140 + 0.5), 1.0 * cos(2 * pi * k / 90)];
ct = cos(T.theta); st = sin(T.theta);
T.c = [T.a(1) + ct * T.e(1) - st * T.e(2) + T.w(:, 1), ...
       T.a(2) + st * T.e(1) + ct * T.e(2) + T.w(:, 2)];
if shake
    Pp = 120 / T.p; ah = T.a / norm(T.a);
    win = [60:70, 120:128, 150:158, 200:210, 275:283];
    u = mod(sin((1:T.K)' * 12.9898) * 43758.5453, 1);      % fixed pseudo-random numbers
    off = zeros(T.K, 1);
    off(win) = (-1).^win(:) .* (0.12 + 0.1 * u(win)) * Pp;
    T.shakeFrames = win; T.shakeOffset = off;
    T.c = T.c + off * ah';
end
T.dpow = [2 0; 3 1; 4 0; 2 2];
T.alpha = [1.5; -1.0; 0.8; 0.6];
% pitch P(r) and the groove count N(r) = int_r^r0 1/P
T.r0 = 24000;
T.rg = (20000:0.5:28000)';
T.Pg = 120 * (1 + 0.05 * sin(2 * pi * (T.rg - 24000) / 2000));
G = 1 ./ T.Pg;
cum = [0; cumsum((G(1:end-1) + G(2:end)) / 2 * 0.5)];
T.Ng = interp1(T.rg, cum, T.r0) - cum;
% music on the groove (um, outward +), groove shape, image
T.Trev = 60 / 33.3333;
T.tones = [2.5 440 0; 1.5 1230 1; 1.0 97 2];
T.width = 64; T.blur = 1.5 * T.p; T.Lgt = 200; T.Drk = 40;
T.bline = 25; T.tau = 4;
% surface texture fixed on the disc: smooth random grey variation plus dark
% dust specks, on a polar grid (r, arc length at r0), 10 um cells
rng(7);
T.texR = (T.r0 - 3500:10:T.r0 + 3500)';
C = 2 * pi * T.r0;
T.texS = 0:10:C;
nr = numel(T.texR); ns = numel(T.texS);
T.tex = single(smooth_noise(nr, ns, 1.5) * 6 + smooth_noise(nr, ns, 6) * 6);
spk = smooth_noise(nr, ns, 1.2);
T.tex(spk > 2.6) = T.tex(spk > 2.6) - 60;
T.tex(:, end) = T.tex(:, 1);                 % periodic in angle
T.noise = 4;
end

function z = smooth_noise(nr, ns, sig)
% unit-variance Gaussian-filtered white noise (sig in cells), periodic
z = randn(nr, ns);
fr = ifftshift((0:nr-1)' - floor(nr / 2)) / nr;
fs = ifftshift((0:ns-1) - floor(ns / 2)) / ns;
z = real(ifft2(fft2(z) .* exp(-2 * pi^2 * sig^2 * (fr.^2 + fs.^2))));
z = z / std(z(:));
end
