%PROFILE_FREEHAND_VIDEO  Where does the time go? MATLAB profiler on a short stretch.
%
% Runs edge reading, registration and the mosaic on 150 frames with the
% profiler on and opens the profiler report. Parallel reading is switched
% off here, because the profiler only sees the main process.
% (A stretch this short has no full revolution, so it stops at the mosaic.)

addpath(fileparts(fileparts(mfilename('fullpath'))));

cfg = groove.defaultConfig();
videoFile = 'data/keyence_recording/20261029_163032.avi';     % EDIT
cfg.camera.pixelSizeUm      = 148.8 / 30;                     % EDIT
cfg.camera.spindleDirection = 'down';                         % EDIT
cfg.run.parallel = false;

source = groove.io.subsetFrameSource(groove.io.videoFrameSource(videoFile), 200:349);
cfg.frameHeight = source.frameSize(1);

profile on
allEdges     = groove.mosaic.extractAllEdges(source, cfg);
registration = groove.mosaic.registerFrames(allEdges, cfg);
mosaic       = groove.mosaic.buildMosaic(allEdges, registration, cfg);
profile off
profile viewer
