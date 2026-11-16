function scan = video_scan(videoFile, S, p, cacheDir, fmt, maxFrames)
%VIDEO_SCAN  The single decoding pass over the video (methods A5, B1, B2).
%   scan = VIDEO_SCAN(videoFile, S, p, cacheDir, fmt, maxFrames) decodes
%   every frame once and keeps only compact measurements:
%     rd{k}    Part A: dark-groove centres at 1/S.video.downsample
%              resolution, one per groove per block of spiralFit.subsample
%              columns, [x y width_um contrast groove ok] (GROOVE_TRACKS:
%              only grooves that are long tracks; ok = position usable)
%     du, dv   motion from frame k-1 to k, full-res px (PHASE_CORR)
%     pk       phase-correlation peak (match quality)
%     focus    mean squared Laplacian (sharpness)
%     thumb    1/(4*ds) thumbnail, uint8 (loop closure)
%     t        time stamp, s
%   and, for the frames Part B uses, full-resolution groove centres in
%   every column (scan.B{j} = [col y amp width_px groove ok], frame scan.pick(j)).
%   Part B frames are chosen during the pass (method B1): the travel along
%   the groove is cut into windows W/video.views px long and the sharpest
%   frame of each window is kept (video.focusWeight blends sharpness with
%   being near the window centre). Results are cached per batch of frames.
if nargin < 6 || isempty(maxFrames), maxFrames = Inf; end
ds = S.video.downsample;
mir = S.microscope.mirrored;
vs = vsrc_open(videoFile);
[~, vname] = fileparts(videoFile);
Q.ds = ds; Q.colStep = S.spiralFit.subsample; Q.p = p; Q.W = vs.W; Q.H = vs.H;
key = struct('video', vname, 'Q', Q, 'mirrored', mir, 'views', S.video.views, ...
    'fw', S.video.focusWeight, 'pitch', S.record.pitch_um, 'gw', S.record.grooveWidth_um, 'tol', S.record.grooveWidthTol, 'version', 5);
Bt = 32;
win = vs.W / S.video.views;
fprintf('scan: %s, %dx%d, %.3f fps, ~%d frames; Part A at 1/%d (a reading every %d px), Part B frames every %.0f px of travel\n', ...
    vname, vs.W, vs.H, vs.fps, vs.K, ds, ds * Q.colStep, win);
pool_get();
rd = {}; du = []; dv = []; pk = []; foc = []; tt = []; th = {};
Bp = {}; pick = [];
prevDs = []; Pp = NaN; slope = NaN;
st = struct('U', 0, 'w', NaN, 'best', -Inf, 'bk', 0, 'bimg', [], 'fref', NaN);
b = 0; kNext = 1; done = false; tic;
while ~done
    b = b + 1;
    cf = fullfile(cacheDir, sprintf('scan_b%04d.mat', b));
    [ok, D] = cache_get(cf, key);
    if ~ok
        if kNext > maxFrames, break; end
        if vs.next ~= kNext
            vs = vsrc_seek(vs, kNext - 1);
            [fr, ~, vs] = vsrc_read(vs);
            chk = block_down(gray_frame(fr, mir), ds);
            if mean(abs(chk(:) - single(prevDs(:)))) > 2
                fprintf('  seek check failed, decoding from the start\n');
                vs = vsrc_seek(vs, 1);
                for i = 1:kNext - 1, [~, ~, vs] = vsrc_read(vs); end
            end
        end
        n = min(Bt, maxFrames - kNext + 1);
        full = cell(1, n); cur = cell(1, n); t = zeros(1, n); m = 0;
        for i = 1:n
            [fr, ti, vs] = vsrc_read(vs);
            if isempty(fr), break; end
            m = m + 1;
            G = gray_frame(fr, mir);
            full{m} = uint8(G); cur{m} = block_down(G, ds); t(m) = ti;
        end
        if m == 0, break; end
        full = full(1:m); cur = cur(1:m); t = t(1:m);
        if isnan(Pp)
            Pp = est_spacing(full{1}, S.record.pitch_um / p);
            slope = est_slope(cur{1});            % rows per column, same at both scales
        end
        wpx = S.record.grooveWidth_um / p; tol = S.record.grooveWidthTol;
        prv = [{prevDs}, cur(1:m-1)];
        Drd = cell(1, m); Ddu = nan(1, m); Ddv = nan(1, m); Dpk = nan(1, m);
        Dfoc = nan(1, m); Dth = cell(1, m);
        cs = Q.colStep; Pd = Pp / ds;
        parfor i = 1:m
            F = cur{i};
            [h, w] = size(F); nC = floor(w / cs);
            Bc = reshape(mean(reshape(double(F(:, 1:nC * cs)), h, cs, nC), 2), h, nC);
            Tr = groove_tracks(Bc, Pd, cs, slope, wpx / ds, tol);
            uds = (Tr.col - 1) * cs + (cs + 1) / 2;
            x = ds * uds - (ds - 1) / 2 - (Q.W + 1) / 2;
            y = ds * Tr.y - (ds - 1) / 2 - (Q.H + 1) / 2;
            Drd{i} = single([x, y, Tr.w * ds * p, Tr.amp, Tr.g, Tr.ok]);
            L = 4 * F(2:end-1, 2:end-1) - F(1:end-2, 2:end-1) - F(3:end, 2:end-1) ...
                - F(2:end-1, 1:end-2) - F(2:end-1, 3:end);
            Dfoc(i) = mean(L(:).^2);
            Dth{i} = uint8(block_down(F, 4));
            P = prv{i};
            if ~isempty(P)
                [a, c, q] = phase_corr(P, F);
                Ddu(i) = a * ds; Ddv(i) = c * ds; Dpk(i) = q;
            end
        end
        % Part B frame choice, in order: one frame per window of travel
        sel = []; selImg = {};
        if isnan(st.fref), st.fref = median(Dfoc); end
        for i = 1:m
            k = kNext + i - 1;
            if ~isnan(Ddu(i)), st.U = st.U + Ddu(i); end
            wi = floor(st.U / win);
            cen = 1 - abs(st.U - (wi + 0.5) * win) / (win / 2);
            if wi ~= st.w
                if st.bk > 0, sel(end + 1) = st.bk; selImg{end + 1} = st.bimg; end %#ok<AGROW>
                st.w = wi; st.best = -Inf; st.bk = 0; st.bimg = [];
            end
            score = S.video.focusWeight * Dfoc(i) / st.fref + (1 - S.video.focusWeight) * cen;
            if score > st.best
                st.best = score; st.bk = k; st.bimg = full{i};
            end
        end
        final = (m < n) || (vs.next > vs.K + 5);
        if strcmp(vs.kind, 'video'), final = final || ~hasFrame(vs.vr); end
        if final && st.bk > 0, sel(end + 1) = st.bk; selImg{end + 1} = st.bimg; st.bk = 0; end
        Db = cell(1, numel(sel));
        parfor j = 1:numel(sel)
            Tr = groove_tracks(single(selImg{j}), Pp, 1, slope, wpx, tol);
            Db{j} = single([Tr.col, Tr.y, Tr.amp, Tr.w, Tr.g, Tr.ok]);
        end
        D = struct();
        D.k = kNext:kNext + m - 1; D.t = t;
        D.rd = Drd; D.du = Ddu; D.dv = Ddv; D.pk = Dpk; D.focus = Dfoc; D.thumb = Dth;
        D.lastDs = cur{m}; D.final = final; D.Pp = Pp; D.slope = slope;
        D.pick = sel; D.B = Db; D.state = st;
        cache_put(cf, key, D, fmt);
        fprintf('  batch %d: frames %d-%d, %d Part B frames, %.1f s elapsed\n', b, D.k(1), D.k(end), numel(sel), toc);
    end
    rd = [rd, D.rd]; du = [du, D.du]; dv = [dv, D.dv]; pk = [pk, D.pk]; %#ok<AGROW>
    foc = [foc, D.focus]; tt = [tt, D.t]; th = [th, D.thumb]; %#ok<AGROW>
    Bp = [Bp, D.B]; pick = [pick, D.pick]; %#ok<AGROW>
    prevDs = D.lastDs; kNext = D.k(end) + 1; Pp = D.Pp; slope = D.slope; st = D.state;
    done = D.final || kNext > maxFrames;
end
K = numel(rd);
scan.K = K; scan.W = vs.W; scan.H = vs.H; scan.fps = vs.fps; scan.ds = ds;
scan.t = tt(:); scan.du = du(:); scan.dv = dv(:); scan.pk = pk(:); scan.focus = foc(:);
scan.rd = rd; scan.thumb = cat(3, th{:});
scan.B = Bp; scan.pick = pick(:); scan.Pp = Pp; scan.slope = slope;
scan.video = videoFile;
nr = cellfun(@(r) size(r, 1), rd);
fprintf('scan: %d frames, Part A readings per frame median %d; groove spacing %.2f px; %d Part B frames, %.0f readings each; %.1f s\n', ...
    K, round(median(nr)), Pp, numel(pick), mean(cellfun(@(r) size(r, 1), Bp)), toc);
end
