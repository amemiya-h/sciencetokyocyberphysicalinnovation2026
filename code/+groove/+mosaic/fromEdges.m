function [ring, report] = fromEdges(allEdges, cfg)
%FROMEDGES  Frames' groove edges -> one continuous groove (no known angles).
%
%   [ring, report] = groove.mosaic.fromEdges(allEdges, cfg)
%
%   allEdges  cell array from groove.mosaic.extractAllEdges
%   cfg       must have cfg.frameHeight (image rows) set
%
%   ring      continuous groove, as from groove.track.unwindRing
%   report    numbers that say how good the scan was, and report.timing:
%             seconds spent in each stage

fprintf('Registering %d frames\n', numel(allEdges));
stage = tic;
registration = groove.mosaic.registerFrames(allEdges, cfg);
timing.registerSeconds = toc(stage);

fprintf('Building the mosaic\n');
stage = tic;
draft  = groove.mosaic.buildMosaic(allEdges, registration, cfg);
mosaic = groove.mosaic.buildMosaic(allEdges, registration, cfg, draft);
timing.mosaicSeconds = toc(stage);

stage = tic;
[period, stepSign, strength] = groove.mosaic.findRevolution(mosaic, cfg);
noise = groove.mosaic.splitHalfNoise(mosaic, period, cfg);
[mosaic, clickFraction] = groove.mosaic.rejectDisagreement(mosaic, cfg);
ring  = groove.mosaic.unwindMosaic(mosaic, period, stepSign, cfg);
timing.unwindSeconds = toc(stage);

report.framePosition   = registration.position;     % pixels along the groove
report.frameShift      = diff(registration.position);
report.matchScore      = registration.score;
report.radialSlipPx    = registration.radial;
report.shiftScale      = registration.scaleCoefficients;
report.frameOffsetPx   = mosaic.frameOffset;
report.viewSpreadPx    = mosaic.viewSpread;
report.viewsPerPoint   = median(mosaic.weight(mosaic.weight > 0.3));
report.tiltAndBend     = mosaic.shape;
report.revolutionBins  = period;
report.revolutionStrength = strength;
report.revolutionsFilmed  = (max(registration.position) - min(registration.position)) / period;
report.centreRadiusMm  = period / (2*pi) * cfg.camera.pixelSizeUm * 1e-3;
report.noise           = noise;
report.clickFraction   = clickFraction;     % share of samples dropped as clicks
report.timing          = timing;
end
