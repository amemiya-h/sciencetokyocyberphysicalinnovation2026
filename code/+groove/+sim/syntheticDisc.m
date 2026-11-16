function disc = syntheticDisc()
%SYNTHETICDISC  Description of a made-up record, for testing without hardware.
%
%   disc = groove.sim.syntheticDisc();
%
%   The groove is a spiral starting at startRadiusMm. leftUm(t) and
%   rightUm(t) give each channel's displacement along its 45-degree axis,
%   in micrometres, at playback time t (seconds, vectorised). The default
%   is a 1 kHz tone on the left and, on the right, a 440 Hz tone plus a slow
%   sweep, so that no two stretches of groove look alike.

disc.startRadiusMm  = 101.0;     % groove centre at playback time zero
disc.pitchUm        = 120;       % spacing between neighbouring turns
disc.grooveWidthUm  = 60;        % width at the surface when unmodulated
disc.eccentricityUm = 0;         % how far off-centre the pressing is
disc.rpm            = 100/3;
disc.leftUm  = @(t) 3.0 * sin(2*pi*1000*t);
disc.rightUm = @(t) 2.0 * sin(2*pi*440*t) + 1.0 * sin(2*pi*(200*t + 15*t.^2));
end
