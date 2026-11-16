%PROCESS_REAL_SIDE  Template for processing real scans. Edit the marked lines.
%
% One video per radial position, each a little more than one revolution,
% listed from the outside of the disc toward the label.

addpath(fileparts(fileparts(mfilename('fullpath'))));

cfg = groove.defaultConfig();

% --- Describe your setup (EDIT) -------------------------------------------
cfg.camera.pixelSizeUm          = 2.0;      % from a stage micrometer
cfg.camera.spindleDirection     = 'down';   % where the spindle is in the image
cfg.camera.motionDirection      = 'right';  % which way the surface moves
cfg.turntable.framesPerRev      = 4000;     % stepper steps per rev / steps per frame
cfg.turntable.playbackDirection = true;     % false if the disc turns backwards
cfg.audio.sampleRate            = 96000;

% --- List your scans (EDIT) -----------------------------------------------
videoFiles = {'ring_01.avi', 'ring_02.avi', 'ring_03.avi'};
radiiMm    = [145.0, 143.6, 142.2];         % radius at the image centre

% --- Check the first ring by eye before committing to the full run --------
sources = cellfun(@groove.io.videoFrameSource, videoFiles, 'UniformOutput', false);
cfg.ring.radiusMm = radiiMm(1);
figure; imagesc(groove.scan.buildKymograph(sources{1}, cfg)); colormap gray
title('Each groove should be a clean dark band with sharp edges');

% --- Process ---------------------------------------------------------------
side     = groove.processSide(sources, radiiMm, cfg);
audio    = groove.audio.edgesToAudio(side, cfg);
position = groove.track.groovePosition(side, cfg);

audiowrite('side.wav', audio, cfg.audio.sampleRate, 'BitsPerSample', 24);
groove.io.writePositionCsv('groove_position.csv', position);
save('side.mat', 'side', 'cfg', '-v7.3');
