function [fr, t, vs] = vsrc_read(vs)
%VSRC_READ  Read the next frame in order. fr = [] at the end.
fr = []; t = NaN;
switch vs.kind
    case 'mat'
        if vs.next <= vs.K
            fr = vs.F(:, :, vs.next); t = (vs.next - 1) / vs.fps;
        end
    case 'video'
        if hasFrame(vs.vr)
            t = vs.vr.CurrentTime;
            fr = readFrame(vs.vr);
        end
end
if ~isempty(fr), vs.next = vs.next + 1; end
end
