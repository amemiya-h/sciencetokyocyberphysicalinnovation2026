function vs = vsrc_seek(vs, k)
%VSRC_SEEK  Position the source so that the next VSRC_READ returns frame k.
switch vs.kind
    case 'mat'
        vs.next = k;
    case 'video'
        vs.vr.CurrentTime = max(0, (k - 1) / vs.fps);
        vs.next = k;
end
end
