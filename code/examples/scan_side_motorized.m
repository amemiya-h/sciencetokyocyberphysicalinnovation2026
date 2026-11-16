%SCAN_SIDE_MOTORIZED  Motorised turntable and radial axis: many rings -> audio.
%
% Step and repeat: turn the disc a little more than once, move the
% microscope inward by part of the field of view, turn again, and so on.
% Each ring is one video. The rings are then read one by one and spliced
% where their grooves overlap.
% Starting and stopping each recording is done by hand on the microscope
% (the script waits for you). Edit the marked lines.

addpath(fileparts(fileparts(mfilename('fullpath'))));

% --- Describe the scan (EDIT) ---------------------------------------------
port          = "COM5";    % serial port of the Arduino; "" for a dry run
videoPattern  = 'data/keyence_recording/side_ring_%02d.avi';   % where you will save each ring
numRings      = 4;
frameRate     = 12.36;     % frames per second of the recordings
frameHeightPx = 1536;      % image height (the radial direction), pixels
firstRadiusMm = 140;       % radius under the lens for the first, outermost ring
overlap       = 0.5;       % share of the field of view neighbouring rings have in common
travelPx      = 100;       % image travel per frame
revolutions   = 1.1;

cfg = groove.defaultConfig();
cfg.camera.pixelSizeUm      = 148.8 / 30;   % Keyence VHX: 148.8 um / magnification
cfg.camera.spindleDirection = 'down';       % where the spindle is in the image
runFolder = fullfile('results', 'runs', 'side_scan');       % everything this run writes goes here
if ~exist(runFolder, 'dir'), mkdir(runFolder); end
cfg.run.edgeCache = fullfile(runFolder, 'edges.mat');      % one cache file per ring is derived from this

% --- Scan -------------------------------------------------------------------
if strlength(port) > 0
    dev = rig.connect(port);
else
    dev = rig.simulated();
end
fieldMm = frameHeightPx * cfg.camera.pixelSizeUm * 1e-3;
stepMm  = (1 - overlap) * fieldMm;
fprintf('Field of view %.2f mm; the microscope moves in by %.2f mm between rings.\n', fieldMm, stepMm);

videoFiles = cell(1, numRings);
for k = 1:numRings
    radiusMm = firstRadiusMm - (k - 1) * stepMm;
    if k > 1
        rig.moveRadial(dev, stepMm);        % + is toward the spindle
    end
    % The surface speed is kept the same on every ring, so inner rings turn faster.
    speed = rig.rotationSpeed(cfg, radiusMm, frameRate, travelPx);
    videoFiles{k} = sprintf(videoPattern, k);
    fprintf('Ring %d of %d at radius %.1f mm: %.2f deg/s, %.0f s.\n', ...
        k, numRings, radiusMm, speed, 360 * revolutions / speed);
    input('Refocus, start the recording, then press Enter. ', 's');
    rig.rotate(dev, 360 * revolutions, speed);
    input(sprintf('Stop the recording, save it as %s, then press Enter. ', videoFiles{k}), 's');
end
rig.moveRadial(dev, -(numRings - 1) * stepMm);      % back to where it started
dev.close();

% --- Read the videos ---------------------------------------------------------
[side, reports] = groove.processFreehandSide(videoFiles, cfg);
fprintf('Whole scan: %.1f groove turns, %.1f s of audio\n', side.numTurns, numel(side.inner) / side.sampleRate);

cfg.audio.noiseProfile = reports{1}.noise;   % filter by the measured noise
audio = groove.audio.edgesToAudio(side, cfg);
audio = groove.audio.resampleTo(audio, side.sampleRate, 48000);
audio = max(-1, min(1, audio));
audiowrite(fullfile(runFolder, 'audio.wav'), audio, 48000, 'BitsPerSample', 16);
save(fullfile(runFolder, 'result.mat'), 'side', 'reports', '-v7.3');
