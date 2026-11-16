function side = processSide(sources, radiiMm, cfg)
%PROCESSSIDE  Process several rings and join them into one continuous groove.
%
%   side = groove.processSide(sources, radiiMm, cfg)
%
%   sources  cell array of frame sources, one per radial position, ordered
%            from the outside of the disc toward the label
%   radiiMm  radius at the image centre for each source, in the same order
%   cfg      configuration (cfg.ring.radiusMm is overwritten for each ring)
%
%   side     same layout as a ring, covering everything that was scanned

assert(numel(sources) == numel(radiiMm), 'One radius is needed per source.');
assert(all(diff(radiiMm) < 0), 'Order the rings from the outside inward.');

side = [];
for k = 1:numel(sources)
    cfg.ring.radiusMm = radiiMm(k);
    fprintf('Ring %d of %d (radius %.2f mm)\n', k, numel(sources), radiiMm(k));
    ring = groove.processRing(sources{k}, cfg);
    if isempty(side)
        side = ring;
    else
        side = groove.track.joinRings(side, ring, cfg);
    end
end
end
