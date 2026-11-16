function q = pctl(v, p)
%PCTL  Percentile p (0..100) of v, ignoring NaN (no toolbox needed).
v = sort(v(~isnan(v(:))));
if isempty(v), q = NaN; return; end
q = v(max(1, min(numel(v), round(p / 100 * numel(v)))));
end
