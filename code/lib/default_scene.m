function scene = default_scene()
%DEFAULT_SCENE  Record, groove and surface parameters for the forward model.
%   scene = DEFAULT_SCENE() returns typical LP values. Values marked
%   (assumed) are plausible guesses, not measurements; replace them with
%   measured values once photos of a real record exist.
%   All lengths in micrometres (um) unless stated.

% Record and playback
scene.radius = 0.146;           % groove radius (m); outer groove of a 12" LP
scene.rpm = 100/3;              % 33 1/3 rpm

% Groove geometry
scene.depth = 25;               % nominal depth
scene.includedAngle = 90;       % between the walls (deg); standard 90 +/- 2
scene.bottomRadius = 4;         % rounded groove bottom (assumed, a few um)
scene.rimRadius = 1;            % rounding of the groove edges (assumed)
scene.pitch = 130;              % centre-to-centre spacing of adjacent turns
scene.nNeighbours = 1;          % adjacent turns modelled on each side
scene.halfWidth = 195;          % half-width of the simulated strip across the groove

% Cutting
scene.riaa = true;              % cut with RIAA pre-emphasis
scene.stereo = true;            % 45/45 stereo: L-R becomes vertical motion
scene.peakLateral = 25;         % largest lateral excursion of the clip
scene.band = [20 20e3];         % audio band (Hz)

% Vinyl surface (black PVC)
scene.refractiveIndex = 1.54;   % PVC
scene.roughness = 0.03;         % rms micro-slope, Beckmann m (assumed)
scene.diffuseAlbedo = 0.02;     % black vinyl (assumed)

% Dust
scene.dust.perMm2 = 30;         % particles per mm^2 (assumed; a cleaned record)
scene.dust.radius = [0.5 4];    % particle radius range
scene.dust.albedo = 0.5;        % diffuse reflectance of a particle (assumed)
end
