function DN = camera_sensor(P, cam, exposure)
%CAMERA_SENSOR  Convert light on each pixel into noisy digital numbers.
%   DN = CAMERA_SENSOR(P, cam, exposure)
%   P         signal per pixel (from camera_optics)
%   exposure  electrons per unit of P (fixed for a whole scan)
%   Adds pixel gain non-uniformity, photon shot noise and read noise,
%   and quantises to cam.bits. If cam.nAverage > 1, that many exposures
%   of the same position are averaged (shot and read noise drop by
%   sqrt(nAverage); the fixed gain pattern does not). Output: digital
%   numbers on the 0 .. 2^bits - 1 scale (fractional after averaging).

nAvg = 1;
if isfield(cam, 'nAverage')
    nAvg = cam.nAverage;
end
adcMax = 2^cam.bits - 1;
e = P * exposure;
e = e .* (1 + cam.prnu * randn(size(e)));
DN = zeros(size(e));
for k = 1:nAvg
    ek = e + sqrt(max(e, 0)) .* randn(size(e)) + cam.readNoise * randn(size(e));
    DN = DN + min(max(round(ek / cam.fullWell * adcMax), 0), adcMax);
end
DN = DN / nAvg;
end
