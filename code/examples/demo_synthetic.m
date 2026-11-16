%DEMO_SYNTHETIC  The whole pipeline on a simulated record. No hardware needed.
%
% From the project root:  addpath examples; demo_synthetic
% Writes demo_audio.wav and demo_groove_position.csv to the current folder.

addpath(fileparts(fileparts(mfilename('fullpath'))));

% A virtual setup, kept coarse so the demo finishes in a minute or two.
cfg = groove.defaultConfig();
cfg.camera.pixelSizeUm     = 4;
cfg.audio.sampleRate       = 24000;
cfg.turntable.framesPerRev = 2454.4;

% Two overlapping radial positions on a made-up disc.
disc      = groove.sim.syntheticDisc();
radiiMm   = [100.0, 99.2];
frameSize = [400, 96];
numFrames = ceil(1.05 * cfg.turntable.framesPerRev);   % a bit over one turn

sources = cell(size(radiiMm));
for k = 1:numel(radiiMm)
    cfg.ring.radiusMm = radiiMm(k);
    sources{k} = groove.sim.frameSource(disc, cfg, frameSize, numFrames);
end

% Frames -> continuous groove -> audio and groove position.
side     = groove.processSide(sources, radiiMm, cfg);
audio    = groove.audio.edgesToAudio(side, cfg);
position = groove.track.groovePosition(side, cfg);

audiowrite('demo_audio.wav', audio, cfg.audio.sampleRate);
groove.io.writePositionCsv('demo_groove_position.csv', position);
fprintf('Recovered %.1f s of stereo audio from %.1f groove turns.\n', ...
    size(audio, 1) / cfg.audio.sampleRate, side.numTurns);
