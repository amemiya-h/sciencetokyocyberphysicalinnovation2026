function [audio, info] = edgesToAudio(ring, cfg)
%EDGESTOAUDIO  Convert groove edges into a stereo recording.
%
%   [audio, info] = groove.audio.edgesToAudio(ring, cfg)
%
%   ring   a ring or a whole joined side
%   audio  numSamples x 2, left then right, ready for audiowrite
%   info   peakVelocityCmS: the largest groove velocity found, per channel
%          clickFraction: share of samples replaced as clicks, per channel
%
%   In a 45/45 stereo groove each wall carries one channel: the wall nearer
%   the spindle is left, the wall nearer the rim is right. Seen from above,
%   a wall moving by d along its own normal shifts its top edge sideways by
%   sqrt(2)*d, while the other edge stays put. So each edge is one channel.
%
%   Optional: cfg.audio.noiseProfile = report.noise applies the measured
%   noise filter (groove.audio.noiseFilter). Bridged holes are faded out.
%
%   The edges give displacement. A cartridge outputs velocity, and the RIAA
%   curve is defined on that, so: differentiate, high-pass, de-emphasise.

fs = ring.sampleRate;

edges = [ring.inner; ring.outer];                              % left; right
info.clickFraction = [0, 0];
if cfg.audio.maxVelocityCmS < Inf
    limit = cfg.audio.maxVelocityCmS * sqrt(2);                % edge moves sqrt(2) x the channel
    for channel = 1:2
        [edges(channel, :), info.clickFraction(channel)] = groove.audio.declick(edges(channel, :), fs, limit);
    end
end
displacementMm = edges / sqrt(2);
velocity = [zeros(2, 1), diff(displacementMm, 1, 2)] * fs;    % mm/s

[bHigh, aHigh] = groove.audio.biquad('highpass', cfg.audio.highpassHz, fs);
[bRiaa, aRiaa] = groove.audio.riaaPlaybackFilter(fs);
padding = round(3 * fs / cfg.audio.highpassHz);

audio = zeros(size(velocity));
for channel = 1:2
    v = groove.audio.zeroPhaseFilter(bHigh, aHigh, velocity(channel, :), padding);
    velocity(channel, :) = v;
    audio(channel, :) = filter(bRiaa, aRiaa, v);
end

% Measured noise profile: turn each frequency down by its share of noise.
if isfield(cfg.audio, 'noiseProfile') && ~isempty(cfg.audio.noiseProfile)
    audio = groove.audio.noiseFilter(audio.', fs, cfg.audio.noiseProfile).';
end

% Holes that were bridged with a straight line: fade the sound out before
% and back in after, so a hole is a short silence and not a thump.
if isfield(ring, 'bridged') && any(ring.bridged)
    audio = audio .* holeFade(ring.bridged, fs, cfg);
end

if isfield(cfg.audio, 'lowpassHz') && cfg.audio.lowpassHz < fs / 2
    [bLow, aLow] = groove.audio.biquad('lowpass', cfg.audio.lowpassHz, fs);
    for channel = 1:2
        for pass = 1:2      % twice, forward and backward: a steep, delay-free cut
            audio(channel, :) = groove.audio.zeroPhaseFilter(bLow, aLow, audio(channel, :), 200);
        end
    end
end

info.peakVelocityCmS = max(abs(velocity), [], 2).' / 10;

if cfg.audio.invert
    audio = -audio;
end
% Scale by a high percentile, not the single largest sample: one click from
% a speck of dust must not make the whole recording quiet.
level = sort(abs(audio(:)));
level = level(round(0.999 * numel(level)));
audio = max(-1, min(1, audio.' * (cfg.audio.peakLevel / level)));
end


function gain = holeFade(bridged, fs, cfg)
% 1 everywhere, 0 inside bridged stretches longer than cfg.audio.minHoleMs,
% with a smooth fade of cfg.audio.holeFadeMs on either side. Shorter
% stretches (removed clicks) are left alone: the bridge is inaudible there.
minLength  = max(1, round(cfg.audio.minHoleMs  * 1e-3 * fs));
fadeLength = max(3, round(cfg.audio.holeFadeMs * 1e-3 * fs));
change = diff([0, double(bridged), 0]);
starts = find(change == 1);
stops  = find(change == -1) - 1;
hole = zeros(size(bridged));
for n = find(stops - starts + 1 >= minLength)
    hole(max(1, starts(n) - fadeLength):min(numel(hole), stops(n) + fadeLength)) = 1;
end
ramp = 0.5 - 0.5 * cos(2*pi * (1:2*fadeLength - 1) / (2*fadeLength));
gain = 1 - min(1, conv(hole, ramp / sum(ramp), 'same'));
end
