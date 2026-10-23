function v = groove_motion_at(sig, fs, t)
%GROOVE_MOTION_AT  Evaluate a band-limited audio-rate signal at any times.
%   v = GROOVE_MOTION_AT(sig, fs, t) interpolates sig (sampled at fs, first
%   sample at t = 0) at the times t (s) with a cubic spline fitted only to
%   the stretch of samples around t, so it stays fast for long signals.
%   Times outside the signal are clamped to its ends.

n = numel(sig);
i0 = max(1, floor(min(t(:)) * fs) - 4);
i1 = min(n, ceil(max(t(:)) * fs) + 6);
if i1 <= i0
    v = repmat(sig(min(max(i0, 1), n)), size(t));
    return;
end
tSeg = ((i0:i1)' - 1) / fs;
tq = min(max(t, tSeg(1)), tSeg(end));
v = interp1(tSeg, sig(i0:i1), tq, 'spline');
end
