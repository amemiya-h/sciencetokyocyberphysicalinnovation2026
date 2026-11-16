function [H, gv, cost, n] = disc_normal(M, chunks, sig, hk)
%DISC_NORMAL  Sparse normal equations of the groove readings over all chunks (parfor).
[~, I] = disc_pack(M);
nc = numel(chunks);
Hc = cell(nc, 1); gc = cell(nc, 1); cc = cell(nc, 1);
cost = 0; n = 0;
parfor ci = 1:nc
    [Hb, gb, cols, c1, n1] = disc_chunk(M, chunks{ci}, sig, hk, I);
    Hc{ci} = Hb; gc{ci} = gb; cc{ci} = cols;
    cost = cost + c1; n = n + n1;
end
ii = cell(nc, 1); jj = cell(nc, 1); vv = cell(nc, 1);
gv = zeros(I.n, 1);
for ci = 1:nc
    cols = cc{ci};
    [a, b] = ndgrid(cols, cols);
    ii{ci} = a(:); jj{ci} = b(:); vv{ci} = Hc{ci}(:);
    gv(cols) = gv(cols) + gc{ci};
end
H = sparse(cat(1, ii{:}), cat(1, jj{:}), cat(1, vv{:}), I.n, I.n);
end
