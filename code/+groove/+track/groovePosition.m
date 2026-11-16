function position = groovePosition(ring, cfg)
%GROOVEPOSITION  Where the mastering lathe put the groove: b(theta).
%
%   position = groove.track.groovePosition(ring, cfg)
%
%   The groove centre is low-passed so the audio wiggle disappears and only
%   the slow path remains: the spiral, the mastering pitch changes, and the
%   once-per-turn wobble of an off-centre pressing.
%
%   position fields (all 1 x N)
%     angleRad      unwound disc angle, 0 at the first sample
%     timeSec       playback time of each point
%     radiusMm      groove centre radius about the turntable axis
%     widthUm       groove width at the surface (slow part), which follows
%                   the cutting depth

fs = ring.sampleRate;
[b, a] = groove.audio.biquad('lowpass', cfg.position.lowpassHz, fs);
padding = round(3 * fs / cfg.position.lowpassHz);

centre = groove.audio.zeroPhaseFilter(b, a, (ring.inner + ring.outer) / 2, padding);
width  = groove.audio.zeroPhaseFilter(b, a, ring.outer - ring.inner, padding);

step = ring.samplesPerRev / cfg.position.samplesPerRev;
pick = round(1:step:numel(centre));

position.angleRad = (pick - 1) * 2*pi / ring.samplesPerRev;
position.timeSec  = (pick - 1) / fs;
position.radiusMm = centre(pick);
position.widthUm  = width(pick) * 1e3;
end
