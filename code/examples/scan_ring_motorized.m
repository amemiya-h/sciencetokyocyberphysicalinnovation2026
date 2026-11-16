%SCAN_RING_MOTORIZED  Motorised turntable, fixed microscope: one ring -> audio.
%
% The stepper turns the disc a little more than once at a steady speed while
% the microscope records video. The video is then read like a hand-turned
% one, so the camera needs no link to the motor.
% Starting and stopping the recording is done by hand on the microscope
% (the script waits for you). Edit the marked lines.

addpath(fileparts(fileparts(mfilename('fullpath'))));

% --- Describe the scan (EDIT) ---------------------------------------------
port        = "COM5";      % serial port of the Arduino; "" for a dry run
videoFile   = 'data/keyence_recording/ring_motor_01.avi';   % where you will save the video
frameRate   = 12.36;       % frames per second of the recording
radiusMm    = 84;          % radius of the grooves under the lens (a ruler is enough)
travelPx    = 100;         % image travel per frame; smaller = more views, longer scan
revolutions = 1.1;         % a full turn plus overlap to close it

cfg = groove.defaultConfig();
cfg.camera.pixelSizeUm      = 148.8 / 30;   % Keyence VHX: 148.8 um / magnification
cfg.camera.spindleDirection = 'down';       % where the spindle is in the image
[~, runName] = fileparts(videoFile);
runFolder = fullfile('results', 'runs', runName);          % everything this run writes goes here
if ~exist(runFolder, 'dir'), mkdir(runFolder); end
cfg.run.edgeCache = fullfile(runFolder, 'edges.mat');

% --- Turn the disc ---------------------------------------------------------
if strlength(port) > 0
    dev = rig.connect(port);
else
    dev = rig.simulated();
end
speed = rig.rotationSpeed(cfg, radiusMm, frameRate, travelPx);
duration = 360 * revolutions / speed;
fprintf('Turning %.2f revolutions at %.2f deg/s: %.0f s, about %.0f frames.\n', ...
    revolutions, speed, duration, duration * frameRate);
fprintf('Keep the exposure under %.1f ms so the image moves less than a pixel during it.\n', ...
    1000 / (travelPx * frameRate));

input('Focus, start the recording on the microscope, then press Enter. ', 's');
rig.rotate(dev, 360 * revolutions, speed);
input(sprintf('Stop the recording, save it as %s, then press Enter. ', videoFile), 's');
dev.close();

% --- Read the video --------------------------------------------------------
source = groove.io.videoFrameSource(videoFile);
[ring, report] = groove.processFreehand(source, cfg);
disp(table(report.noise.bandHz, report.noise.signalUm, report.noise.noiseUm, report.noise.snrDb, ...
    'VariableNames', {'bandHz', 'signalUm', 'noiseUm', 'snrDb'}));

cfg.audio.noiseProfile = report.noise;   % filter by the measured noise
audio = groove.audio.edgesToAudio(ring, cfg);
audio = groove.audio.resampleTo(audio, ring.sampleRate, 48000);
audio = max(-1, min(1, audio));
audiowrite(fullfile(runFolder, 'audio.wav'), audio, 48000, 'BitsPerSample', 16);
save(fullfile(runFolder, 'result.mat'), 'ring', 'report', '-v7.3');
