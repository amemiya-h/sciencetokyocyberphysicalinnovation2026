function y = zeroPhaseFilter(b, a, x, padding)
%ZEROPHASEFILTER  Filter forward then backward, so nothing is delayed.
%
%   y = groove.audio.zeroPhaseFilter(b, a, x, padding)
%
%   x        row vector
%   padding  samples of mirrored signal added at each end to hide the
%            start-up transient; a few periods of the cutoff is enough

padding = min(padding, numel(x) - 1);
head = 2*x(1)   - x(padding + 1:-1:2);          % point-mirrored extension
tail = 2*x(end) - x(end - 1:-1:end - padding);
extended = [head, x, tail];

extended = filter(b, a, extended);
extended = fliplr(filter(b, a, fliplr(extended)));

y = extended(padding + 1:end - padding);
end
