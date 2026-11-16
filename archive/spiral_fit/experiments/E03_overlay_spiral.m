%E03_OVERLAY_SPIRAL  Draw the fitted blank spiral over video frames.
%   For a few Part B frames, overlays the model's dark-groove lines
%   (Psi = integer) and the measured groove centres, labelled with the
%   music-turn number used in the Part B checks (turn 0 = first turn in
%   time). Turns given in badTurns are drawn red, the rest yellow. The
%   measured centres are coloured by their COUNTED turn (TURN_COUNT),
%   cycling through three colours (grooves are GROOVE_TRACKS tracks,
%   numbered in order); centres whose counted turn differs from the
%   model's round(Psi) are drawn larger, in magenta, and those without a
%   usable position (dust on the groove) in white. Output: <run>/overlay_k####.png.
run = '20261027_184833';
badTurns = 0:8;
vf = fullfile(project_root(), 'data', 'keyence_recording', [run '.avi']);
dirR = fullfile(project_root(), 'results', 'runs', run);
A = load(fullfile(dirR, 'partA.mat')); M = A.model;
B = load(fullfile(dirR, 'partB.mat'), 't');
t0 = min(B.t); T = 60 / A.settings.record.rpm;
S = A.settings;
scan = video_scan(vf, S, M.p, fullfile(dirR, 'cache'), '-v7');
vs = vsrc_open(vf);
sel = scan.pick(round(linspace(1, numel(scan.pick), 4)));
cols = [1 0.3 0.3; 0.3 1 0.3; 0.3 0.6 1];
for k = sel(:)'
    j = find(scan.pick == k, 1);
    [G, vs] = vsrc_frame(vs, k, S.microscope.mirrored);
    gx = 1:8:M.W; gy = 1:4:M.H;
    [GX, GY] = meshgrid(gx, gy);
    E = disc_eval(M, GX(:) - (M.W + 1) / 2, GY(:) - (M.H + 1) / 2, k * ones(numel(GX), 1));
    PS = reshape(E.psi, size(GX)); PH = reshape(E.phi, size(GX));
    fig = figure('Visible', 'off', 'Position', [0 0 2048 1536] / 1.25);
    axes('Position', [0 0 1 1]);
    imagesc(G); colormap(gray); axis image off; hold on;
    for n = ceil(min(PS(:))):floor(max(PS(:)))
        C = contourc(gx, gy, PS, [n n]);
        if isempty(C), continue; end
        xs = C(1, 2:end); ys = C(2, 2:end);
        ok = xs > 0; xs = xs(ok); ys = ys(ok);
        if isempty(xs), continue; end
        % music-turn number at this line's middle
        im = round(numel(xs) / 2);
        e = disc_eval(M, xs(im) - (M.W + 1) / 2, ys(im) - (M.H + 1) / 2, k);
        tt = T * (n - M.s * e.phi / (2 * pi));
        turn = floor((tt - t0) / T);
        c = [1 0.9 0.2]; if any(turn == badTurns), c = [1 0.1 0.1]; end
        plot(xs, ys, '-', 'Color', c, 'LineWidth', 0.8);
        text(8, ys(1), sprintf('%d', turn), 'Color', c, 'FontSize', 9, 'FontWeight', 'bold');
    end
    % measured groove centres (every 16th column), coloured by assigned turn
    Cm = double(scan.B{j}); Cm = Cm(mod(Cm(:, 1), 8) == 0, :);
    xc = Cm(:, 1) - (M.W + 1) / 2; yc = Cm(:, 2) - (M.H + 1) / 2;
    e = disc_eval(M, xc, yc, k * ones(size(Cm, 1), 1));
    g = Cm(:, 5); isG = Cm(:, 6) > 0;
    pm = accumarray(g, e.psi, [], @median, NaN); gi = find(~isnan(pm));
    cand = round(pm(gi)) - M.sgnY * (gi - 1); good = abs(pm(gi) - round(pm(gi))) < 0.2;
    n0 = mode(cand(good)); ng = n0 + M.sgnY * ((1:numel(pm))' - 1); n = ng(g);
    turn = floor((T * (n - M.s * e.phi / (2 * pi)) - t0) / T);
    for q = 0:2
        m = isG & mod(turn, 3) == q;
        plot(Cm(m, 1), Cm(m, 2), '.', 'Color', cols(q + 1, :), 'MarkerSize', 4);
    end
    m = isG & n ~= round(e.psi);
    plot(Cm(m, 1), Cm(m, 2), '.', 'Color', [1 0 1], 'MarkerSize', 7);
    plot(Cm(~isG, 1), Cm(~isG, 2), '.', 'Color', [1 1 1], 'MarkerSize', 7);
    title(sprintf('frame %d', k));
    f = fullfile(dirR, sprintf('overlay_tracks_k%04d.png', k));
    print(fig, f, '-dpng', '-r100'); close(fig);
    fprintf('wrote %s\n', f);
end
