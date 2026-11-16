function sel = select_ring_frames(mot, opts)
%SELECT_RING_FRAMES  Pick video frames that cover one revolution.
%   sel = SELECT_RING_FRAMES(mot, opts) uses the motion trace from
%   scan_video_motion. The disc's content moves along x; adding up the
%   frame-to-frame shifts gives each frame's position X along the groove
%   (pixels). One revolution later frame 1's content comes back (the
%   strongest match to frame 1 once the disc has moved on), which fixes
%   the revolution length exactly. Frames are then picked greedily from
%   frame 1 so that consecutive picks overlap by minOverlap..maxOverlap of
%   the width, preferring the best focused frame (a warped disc drifts in
%   and out of focus as it turns), until the ring closes back onto frame 1.
%
%   opts fields (defaults in brackets)
%     minOverlap   [0.2]   maxOverlap   [0.5]
%     views        if given, how many frames should see each point: the
%                  picks are then about W/views apart (0.8-1.2 x that),
%                  instead of following min/maxOverlap [NaN]
%     minLoopResp  smallest loop-closure match accepted [0.08]; it must
%                  also stand out 5x above the typical unrelated match
%
%   Output struct sel
%     frames     1 x N chosen frame numbers (first is 1)
%     X          1 x N their positions along the groove (px)
%     stepPx     1 x N shift to the next pick, the last one back to frame 1
%                one revolution later (px)
%     revPx      one revolution (px); ring = true if it was found
%     loopFrame  frame matching frame 1 one revolution later
%     driftPx    radial creep over the revolution (px, image y down),
%                with the skew's share removed
%     radialPx   1 x N radial shift of the content from each pick to the
%                next (px, image y down, skew's share removed): the rig
%                wobbles, and the disc creeps
%     skew       direction of motion relative to the image x axis (rad)
%     speed      1 x N disc motion around each pick (px per frame)
%     sharp      1 x N focus value of each pick

if nargin < 2, opts = struct(); end
def = struct('minOverlap', 0.2, 'maxOverlap', 0.5, 'minLoopResp', 0.08, 'views', NaN);
f = fieldnames(def);
for k = 1:numel(f)
    if ~isfield(opts, f{k}), opts.(f{k}) = def.(f{k}); end
end

W = mot.width;
X = cumsum(mot.dx);
moving = abs(mot.dx) > 5;
sel.skew = atan(median(mot.dy(moving) ./ mot.dx(moving)));

% Loop closure: best match to frame 1 after the disc has moved well away
far = X > 1.5 * W & X > 0.5 * max(X);
sel.ring = false;
sel.revPx = inf;  sel.loopFrame = NaN;  sel.driftPx = 0;
if any(far)
    r = mot.respRef;  r(~far) = -inf;
    [best, kc] = max(r);
    if best >= opts.minLoopResp && best > 5 * median(mot.respRef(far))
        sel.ring = true;
        sel.loopFrame = kc;
        sel.revPx = X(kc) - mot.dxRef(kc);
        sel.driftPx = mot.dyRef(kc) - mot.dxRef(kc) * tan(sel.skew);
    end
end

% Motion around each frame (exposure overlaps both neighbouring intervals)
dxn = [abs(mot.dx(2:end)), 0];
speed = max(abs(mot.dx), dxn);

if isnan(opts.views)
    minAdv = (1 - opts.maxOverlap) * W;
    maxAdv = (1 - opts.minOverlap) * W;
else
    minAdv = 0.8 * W / opts.views;
    maxAdv = 1.2 * W / opts.views;
end
lastX = min(sel.revPx, max(X));
frames = 1;
while true
    kp = frames(end);  Xc = X(kp);
    if sel.ring && sel.revPx - Xc <= maxAdv, break; end
    ahead = (1:mot.n) > kp;
    d = X - Xc;
    cand = find(ahead & d >= minAdv & d <= maxAdv & X <= lastX);
    if isempty(cand)
        % moving too fast here: take the furthest frame still overlapping
        cand = find(ahead & d > 0 & d <= maxAdv & X <= lastX, 1, 'last');
        if isempty(cand)
            % the disc jumped past the target: take the next frame, which
            % is fine as long as it still overlaps (20% of the width)
            nxt = find(ahead & d > 0 & X <= lastX, 1);
            if isempty(nxt), break; end
            if d(nxt) > 0.8 * W
                warning('select_ring_frames:gap', ...
                    'No overlapping frame after frame %d (jump %.0f px)', kp, d(nxt));
            end
            cand = nxt;
        end
    end
    % best focus; less motion breaks ties
    score = -mot.sharp(cand) + 1e-4 * speed(cand);
    [~, i] = min(score);
    frames(end+1) = cand(i);   %#ok<AGROW>
end

sel.frames = frames;
sel.X = X(frames);
Y = cumsum(mot.dy);
if sel.ring
    % frame 1 one revolution later, as if it were one more pick
    Xs = [sel.X, X(1) + sel.revPx];
    Ys = [Y(frames), Y(sel.loopFrame) - mot.dyRef(sel.loopFrame)];
else
    Xs = sel.X;  Ys = Y(frames);
end
sel.stepPx = diff(Xs);
sel.radialPx = diff(Ys) - tan(sel.skew) * diff(Xs);
sel.speed = speed(frames);
sel.sharp = mot.sharp(frames);
end
