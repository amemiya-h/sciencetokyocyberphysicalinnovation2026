%TEST_SYNTHETIC  End-to-end check on a simulated disc. Run from the project root.
%
% Renders two overlapping rings of a synthetic stereo record, runs the full
% pipeline on them, and compares the result with the known truth.
% Takes a minute or two.

addpath(fileparts(fileparts(mfilename('fullpath'))));

cfg = groove.defaultConfig();
cfg.camera.pixelSizeUm     = 4;        % coarse, to keep the test quick
cfg.audio.sampleRate       = 24000;
cfg.turntable.framesPerRev = 2454.4;   % deliberately not an integer
cfg.camera.spindleDirection = 'up';
cfg.camera.motionDirection  = 'left';

disc = groove.sim.syntheticDisc();
disc.eccentricityUm = 40;
frameSize = [400, 96];
numFrames = 2600;                      % about 1.06 revolutions
radii     = [100.0, 99.2];
startAngles = [0, 2.1];                % second scan starts somewhere else

sources = cell(1, 2);
for k = 1:2
    cfg.ring.radiusMm = radii(k);
    sources{k} = groove.sim.frameSource(disc, cfg, frameSize, numFrames, startAngles(k));
end

% --- 1. Each ring against the truth, then the join -------------------------
tic
perRev = round(cfg.audio.sampleRate * 60 / cfg.record.rpm);
rings = cell(1, 2);
startSample = zeros(1, 2);     % where each ring starts along the true groove
for k = 1:2
    cfg.ring.radiusMm = radii(k);
    rings{k} = groove.processRing(sources{k}, cfg);

    % The radius tells which turn the ring starts on; the rest is known.
    centre = (rings{k}.inner(1:perRev) + rings{k}.outer(1:perRev)) / 2;
    firstTurn = round((disc.startRadiusMm - mean(centre)) / (disc.pitchUm * 1e-3) ...
                - 0.5 - startAngles(k) / (2*pi));
    angle = startAngles(k) + 2*pi*firstTurn ...
            + ((1:numel(rings{k}.inner)) - 0.5) * 2*pi / perRev;
    [trueInner, trueOuter] = groove.sim.grooveEdges(disc, angle);
    errorUm = 1e3 * [rings{k}.inner - trueInner; rings{k}.outer - trueOuter];
    fprintf('Ring %d: %d turns, edge error %.3f um rms, %.3f um worst\n', k, ...
        rings{k}.numTurns, sqrt(mean(errorUm(:).^2)), max(abs(errorUm(:))));
    assert(sqrt(mean(errorUm(:).^2)) < 0.05, 'Edges are off by more than 0.05 um rms.');
    startSample(k) = angle(1) * perRev / (2*pi);
end

side = groove.track.joinRings(rings{1}, rings{2}, cfg);
cut  = numel(side.inner) - numel(rings{2}.inner) + 1;
joinError = cut - 1 - (startSample(2) - startSample(1));
fprintf('Join is %.2f samples from the true position\n', joinError);
assert(abs(joinError) <= 0.5, 'Rings were joined at the wrong place.');
fprintf('Processed in %.0f s: %.2f turns, %.1f s of audio\n', ...
    toc, side.numTurns, numel(side.inner) / side.sampleRate);

% --- 2. Channel separation -----------------------------------------------
audio = groove.audio.edgesToAudio(side, cfg);
levelDb = @(x, f) 20*log10(abs(sum(x(:).' .* exp(-2i*pi*f*(0:numel(x)-1)/cfg.audio.sampleRate))) / numel(x));
leakLeft  = levelDb(audio(:, 1), 440)  - levelDb(audio(:, 2), 440);
leakRight = levelDb(audio(:, 2), 1000) - levelDb(audio(:, 1), 1000);
fprintf('Crosstalk: %.0f dB into left, %.0f dB into right\n', leakLeft, leakRight);
assert(leakLeft < -30 && leakRight < -30, 'Channels leak into each other.');

% --- 3. Groove position --------------------------------------------------
position = groove.track.groovePosition(side, cfg);
[flat, eccentricityUm] = groove.track.removeEccentricity(position);
pitchUm = -1e3 * (flat.radiusMm(end) - flat.radiusMm(1)) / (flat.angleRad(end) / (2*pi));
fprintf('Eccentricity %.1f um (true %.0f), pitch %.1f um (true %.0f)\n', ...
    eccentricityUm, disc.eccentricityUm, pitchUm, disc.pitchUm);
assert(abs(eccentricityUm - disc.eccentricityUm) < 1, 'Eccentricity is wrong.');
assert(abs(pitchUm - disc.pitchUm) < 1, 'Pitch is wrong.');

% --- 4. Other mounting: disc turned backwards, camera the other way up ----
cfg.camera.spindleDirection = 'down';
cfg.camera.motionDirection  = 'right';
cfg.turntable.playbackDirection = false;
cfg.ring.radiusMm = 100;
lastwarn('');
ring  = groove.processRing(groove.sim.frameSource(disc, cfg, frameSize, numFrames), cfg);
audio = groove.audio.edgesToAudio(ring, cfg);
leak  = levelDb(audio(:, 1), 440) - levelDb(audio(:, 2), 440);
kymograph = groove.scan.buildKymograph(sources{1}, cfg, 1:500:40000);
fprintf('Backwards scan: %d turns, crosstalk %.0f dB\n', ring.numTurns, leak);
assert(isempty(lastwarn) && ring.numTurns >= 10 && leak < -30, 'Backwards scan failed.');

disp('All checks passed.');
