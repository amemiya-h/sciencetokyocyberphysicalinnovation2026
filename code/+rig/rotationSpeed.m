function degreesPerSecond = rotationSpeed(cfg, radiusMm, frameRate, travelPixels)
%ROTATIONSPEED  Table speed that moves the image a chosen distance per frame.
%
%   degreesPerSecond = rig.rotationSpeed(cfg, 84, 12.36, 100)
%
%   radiusMm      radius of the grooves under the microscope
%   frameRate     camera frames per second
%   travelPixels  how far the grooves should move between frames. About 100
%                 gives 5 or more views of every point at 30x and keeps the
%                 used part of each frame near the image centre.

surfaceSpeedMm = travelPixels * cfg.camera.pixelSizeUm * 1e-3 * frameRate;
degreesPerSecond = surfaceSpeedMm / radiusMm * 180 / pi;
end
