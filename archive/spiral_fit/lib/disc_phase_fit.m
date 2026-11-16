function [M, hist] = disc_phase_fit(M, chunks, Lk, S, R)
%DISC_PHASE_FIT  Staged robust fit of the disc model (method A5).
%   Minimises the Huber sum of the groove-reading residuals Psi - n (turns
%   fixed by the chain), the motion-link and overlap residuals (DISC_LINKS)
%   and the priors of DISC_PRIORS, by damped Gauss-Newton on the sparse
%   normal equations. Stages (spiralFit.stages) free the parameters in order:
%     poses       the per-frame centre c_k and rotation theta_k
%     pitch       + g(r) = 1/P(r)
%     distortion  + the lens distortion
%   Each finished stage is cached in R.cache.
st = S.spiralFit.stages; if ischar(st), st = {st}; end
hk = S.spiralFit.huberK;
nIt = S.spiralFit.iterationsPerStage;
[~, I] = disc_pack(M);
groups = struct('poses', {{'dcx', 'dcy', 'dth'}}, 'pitch', {{'beta'}}, 'distortion', {{'alpha'}});
M = disc_update(M);
act = false(I.n, 1);
hist = struct('stage', {}, 'it', {}, 'cost', {}, 'medAbs_um', {}, 'sig', {}, 'lambda', {});
for si = 1:numel(st)
    name = st{si};
    if ~isfield(groups, name), error('disc_phase_fit:stage', 'unknown stage %s', name); end
    for g = groups.(name), act(I.(g{1})) = true; end
    cf = fullfile(R.cache, sprintf('fit_stage%d_%s.mat', si, name));
    key = struct('priors', 7, 'record', S.record, 'motion', S.motion, 'overlap', S.overlap, 'stage', name, 'si', si, ...
        'nIt', nIt, 'hk', hk, 'nread', sum(cellfun(@(c) size(c, 1), chunks)), 'nlink', numel(Lk.a), 'nf', numel(M.fk), 'sum', sum(cellfun(@(c) double(sum(c(:, 4))), chunks)));
    [ok, D] = cache_get(cf, key);
    if ok
        M = D.M; hist = D.hist;
        fprintf('fit stage %d (%s): loaded from cache\n', si, name);
        continue;
    end
    % robust scale of the residual at the start of the stage
    Rr = disc_residuals(M, chunks, 4);
    sig = double(max(1e-3, 1.4826 * median(abs(Rr.rho))));
    clear Rr
    [H, gv, cost] = disc_normal(M, chunks, sig, hk);
    [Hl, gl, cl] = disc_links(M, Lk, hk, I);
    [Hp, gp, cp] = disc_priors(M, S);
    H = H + Hl; gv = gv + gl; cost = cost + cl + cp;
    lam = 1e-4;
    ia = find(act);
    fprintf('fit stage %d (%s): %d free parameters, robust spread %.4f turns, cost %.6g (links %.6g)\n', ...
        si, name, numel(ia), sig, cost, cl);
    hkc = hk; lsPhase = strcmp(name, 'pitch');
    for it = 1:nIt
        % pitch stage: the start pitch is a constant, so the readings far from the
        % frame centre start up to a few turns off and a Huber loss would treat
        % them as outliers; the first iterations are plain least squares
        if it > 3, lsPhase = false; end
        hki = hk; if lsPhase, hki = 1e6; end
        if hki ~= hkc
            hkc = hki;
            [H, gv, cost] = disc_normal(M, chunks, sig, hkc);
            [Hl, gl, cl] = disc_links(M, Lk, hkc, I);
            H = H + Hl; gv = gv + gl; cost = cost + cl + cp0(M, S);
            [Hp, gp] = disc_priors(M, S);
        end
        A = H(ia, ia) + Hp(ia, ia);
        b = gv(ia) + gp(ia);
        dsc = sqrt(max(full(diag(A)), 1e-30));
        Dn = spdiags(1 ./ dsc, 0, numel(ia), numel(ia));
        accepted = false;
        for tries = 1:8
            An = Dn * A * Dn + lam * speye(numel(ia));
            step = -(An \ (Dn * b)) ./ dsc;
            v = disc_pack(M);
            v(ia) = v(ia) + step;
            Mt = disc_unpack(M, v);
            [Ht, gt, ct] = disc_normal(Mt, chunks, sig, hkc);
            [Hlt, glt, clt] = disc_links(Mt, Lk, hkc, I);
            [Hpt, gpt, cpt] = disc_priors(Mt, S);
            ct = ct + clt + cpt;
            if ct <= cost
                accepted = true; break;
            end
            lam = lam * 10;
        end
        if ~accepted
            if lsPhase, lsPhase = false; continue; end
            fprintf('  it %2d: no decrease, stage converged\n', it);
            break;
        end
        dc = cost - ct;
        M = Mt; H = Ht + Hlt; gv = gt + glt; Hp = Hpt; gp = gpt; cost = ct; cl = clt;
        lam = max(1e-8, lam / 10);
        Rr = disc_residuals(M, chunks, 4);
        mu = median(abs(double(Rr.rho) .* double(Rr.P)));
        clear Rr
        isp = ismember(ia, [I.dcx; I.dcy]);
        fprintf('  it %2d: cost %.6g (-%.3g; links %.6g), median |Psi-n| %.2f um, max|step| centre %.2g px, lambda %.0e\n', ...
            it, cost, dc, cl, mu, max([0; abs(step(isp))]), lam);
        hist(end+1) = struct('stage', name, 'it', it, 'cost', cost, 'medAbs_um', mu, 'sig', sig, 'lambda', lam); %#ok<AGROW>
        if dc < 1e-7 * cost && ~lsPhase, break; end
        if dc < 1e-7 * cost, lsPhase = false; end
    end
    cache_put(cf, key, struct('M', M, 'hist', hist), R.fmt);
end
end

function c = cp0(M, S)
[~, ~, c] = disc_priors(M, S);
end
