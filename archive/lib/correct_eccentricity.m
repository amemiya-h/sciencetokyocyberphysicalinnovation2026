function [chains, ecc] = correct_eccentricity(chains)
%CORRECT_ECCENTRICITY  Remove the wow caused by an off-centre disc.
%   [chains, ecc] = CORRECT_ECCENTRICITY(chains) needs chains covering at
%   least about half a revolution in total. If the groove spiral's centre
%   is offset by e from the rig's axis, every groove's radius drifts by
%   e*cos(theta - thetaE) once per revolution, and angles measured about
%   the rig axis are off by (e/r)*sin(thetaE - theta), which would play
%   back as a once-per-revolution speed wobble. The drift is fitted to all
%   chains at once (each chain also gets its own offset and slow trend for
%   the spiral), then the angles are corrected and resampled.
%
%   ecc: struct with A, B (um): e*cos(thetaE), e*sin(thetaE), and e (um)

rows = {};  rhs = {};  nC = numel(chains);
for c = 1:nC
    th = chains(c).theta(:);
    r = chains(c).centre(:);
    ok = ~isnan(r);
    if nnz(ok) < 50, continue; end
    % slow part only: average over 1/100 revolution blocks
    nb = max(1, round(numel(th) / max(1, (th(end)-th(1)) / (2*pi/100))));
    k = floor((0:numel(th)-1)' / nb);
    thb = accumarray(k(ok)+1, th(ok), [], @mean);
    rb = accumarray(k(ok)+1, r(ok), [], @mean);
    cnt = accumarray(k(ok)+1, 1);
    thb = thb(cnt > 0);  rb = rb(cnt > 0);
    tc = (thb - mean(thb)) / (2*pi);
    Z = zeros(numel(thb), 3*nC);
    Z(:, 3*c-2:3*c) = [ones(size(tc)), tc, tc.^2];      % own offset + trend
    rows{end+1} = [cos(thb), sin(thb), Z];               %#ok<AGROW>
    rhs{end+1} = rb;                                     %#ok<AGROW>
end
M = vertcat(rows{:});
y = vertcat(rhs{:});
keepCols = [true, true, any(M(:, 3:end) ~= 0, 1)];
x = M(:, keepCols) \ y;
ecc.A = x(1);  ecc.B = x(2);  ecc.e = hypot(x(1), x(2));

for c = 1:nC
    th = chains(c).theta;
    r = chains(c).centre;
    if numel(th) < 2 || all(isnan(r)), continue; end   % too short to resample
    rr = r;  rr(isnan(rr)) = mean(r(~isnan(r)));
    thS = th - (ecc.B * cos(th) - ecc.A * sin(th)) ./ rr;   % angle about the spiral centre
    grid = thS(1) : (th(2) - th(1)) : thS(end);
    f = {'outer', 'inner', 'centre'};
    for k = 1:3
        chains(c).(f{k}) = interp1(thS, chains(c).(f{k}), grid, 'linear', NaN);
    end
    chains(c).theta = grid;
end
end
