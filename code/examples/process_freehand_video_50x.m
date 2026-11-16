%PROCESS_FREEHAND_VIDEO_50X  The 50x hand-turned recording of 2026-10-27 -> audio.
%
% One video of a little more than one revolution at one radial position.
% Nothing needs to be known about how the disc moved. Edit the marked lines.
% Run from the repository root. Writes edges.mat (cache), result.mat and
% audio.wav into results/runs/<video name>/.

addpath(fileparts(fileparts(mfilename('fullpath'))));

cfg = groove.defaultConfig();

% --- Describe your setup (EDIT) -------------------------------------------
videoFile = 'data/keyence_recording/20261027_184833.avi';
cfg.camera.pixelSizeUm      = 148.8 / 50;   % Keyence VHX: 148.8 um / magnification
cfg.camera.spindleDirection = 'down';       % where the spindle is in the image

% Everything this run writes goes into results/runs/<video name>/.
[~, runName] = fileparts(videoFile);
runFolder = fullfile('results', 'runs', runName);
if ~exist(runFolder, 'dir'), mkdir(runFolder); end
cfg.run.edgeCache = fullfile(runFolder, 'edges.mat');     % keeps the slow step for reruns

% --- Process ---------------------------------------------------------------
source = groove.io.videoFrameSource(videoFile);
[ring, report] = groove.processFreehand(source, cfg);

% How good was the scan? Signal against noise, by frequency band.
disp(table(report.noise.bandHz, report.noise.signalUm, report.noise.noiseUm, report.noise.snrDb, ...
    'VariableNames', {'bandHz', 'signalUm', 'noiseUm', 'snrDb'}));

% --- Audio -----------------------------------------------------------------
cfg.audio.noiseProfile = report.noise;   % filter by the measured noise
audio = groove.audio.edgesToAudio(ring, cfg);
audio = groove.audio.resampleTo(audio, ring.sampleRate, 48000);
audio = max(-1, min(1, audio));     % resampling can overshoot full scale by a hair
audiowrite(fullfile(runFolder, 'audio.wav'), audio, 48000, 'BitsPerSample', 16);
save(fullfile(runFolder, 'result.mat'), 'ring', 'report', '-v7.3');
