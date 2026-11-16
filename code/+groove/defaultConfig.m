function cfg = defaultConfig()
%DEFAULTCONFIG  All tunable parameters of the pipeline, with sane defaults.
%
%   cfg = groove.defaultConfig();
%
%   Lengths are in the unit named by the field (Um = micrometres,
%   Mm = millimetres). Edit the returned struct before passing it on.

% --- The record -----------------------------------------------------------
cfg.record.rpm = 100/3;              % speed the record was cut for (33 1/3)
cfg.record.playsInward = true;       % false for the rare inside-out record

% --- The camera -----------------------------------------------------------
% The image must be oriented so the grooves run horizontally (along columns).
cfg.camera.pixelSizeUm      = 2.0;      % size of one pixel on the disc surface
cfg.camera.spindleDirection = 'down';   % 'down': spindle is toward the bottom
                                        %         of the image (larger row index)
                                        % 'up'  : spindle is toward the top
cfg.camera.motionDirection  = 'right';  % direction the disc surface moves
                                        % through the image: 'right' or 'left'

% --- The turntable --------------------------------------------------------
cfg.turntable.framesPerRev      = 4000;  % camera frames per disc revolution
                                         % (need not be an integer)
cfg.turntable.playbackDirection = true;  % true : disc turns the way it would
                                         %        on a record player
                                         % false: it turns backwards

% --- The ring being scanned (set for every radial position) ---------------
cfg.ring.radiusMm = 100;             % disc radius seen at the image centre row

% --- Groove detection -----------------------------------------------------
cfg.detect.threshold  = 0.5;         % edge level, as a fraction between the
                                     % dark (wall) and bright (land) levels
cfg.detect.minWidthUm = 30;          % narrower dark runs are rejected (dust)
cfg.detect.maxWidthUm = 220;         % wider dark runs are rejected (merged grooves)
cfg.detect.maxGlintUm = 8;           % a bright line this thin inside a groove
                                     % (the groove bottom) is ignored
cfg.detect.localWindowUm = 300;      % brightness levels are judged over this
                                     % radial distance (a few groove pitches),
                                     % so uneven lighting does not matter
cfg.detect.minContrast = 0.4;        % regions with less light/dark contrast than
                                     % this fraction of the typical are land
cfg.detect.maxGrooves = 40;          % most grooves expected in one image column

% --- Tracking -------------------------------------------------------------
cfg.track.gateUm        = 25;        % a groove may move this far between
                                     % neighbouring samples; keep it below
                                     % half the smallest groove pitch
cfg.track.maxGapSamples = 400;       % longest dropout bridged by interpolation
cfg.track.minCoverage   = 0.98;      % a groove turn is used only if at least
                                     % this fraction of it was detected

% --- Joining rings --------------------------------------------------------
cfg.join.minScore    = 0.5;          % warn when the overlap match is weaker
cfg.join.searchTurns = 1.5;          % how far (in turns) the true join may lie
                                     % from where the ring radii say it is;
                                     % Inf searches the whole overlap

% --- Registered mosaic (groove.processFreehand) ----------------------------
% For scans where the disc angle of each frame is not known in advance.
cfg.mosaic.halfWidthUm     = 1500;   % each frame contributes its central band
                                     % of this half-width; lens distortion
                                     % grows away from the centre
cfg.mosaic.widenFactor     = 0.75;   % the band widens to this multiple of the
                                     % frame-to-frame shift when the disc moved far
cfg.mosaic.maxBackward     = 0.20;   % largest shift searched, as a fraction of
cfg.mosaic.maxForward      = 0.60;   % the frame width, against / along the motion
cfg.mosaic.rejectUm        = 7.5;    % a view this far from the others is dropped
                                     % (dust, a mis-detected edge)
cfg.mosaic.clickSigma      = 6;      % a sample where odd and even frames differ
                                     % by more than this many times the typical
                                     % amount is dropped (dust, misread edge)
cfg.mosaic.shakeLengthUm   = 15000;  % frame slides slower than this length of
                                     % groove are taken as real groove position,
                                     % faster ones as shake
cfg.mosaic.minOverlapUm    = 10000;  % groove length that must be seen twice,
                                     % one revolution apart, to close the turn

% --- Audio ----------------------------------------------------------------
cfg.audio.sampleRate = 96000;        % output sample rate, Hz. This also sets
                                     % the angular sampling of the scan.
cfg.audio.highpassHz = 20;           % removes spiral drift, eccentricity, warp
cfg.audio.lowpassHz  = Inf;          % set below the noise-dominated band of a
                                     % scan (see groove.mosaic.splitHalfNoise)
cfg.audio.maxVelocityCmS = 40;       % faster edge movement is a click (dust),
                                     % not sound; Inf turns click removal off
cfg.audio.noiseProfile = [];         % set to report.noise (freehand scans) to
                                     % filter by the measured noise instead of
                                     % a fixed low-pass
cfg.audio.minHoleMs  = 2;            % bridged holes longer than this are faded
cfg.audio.holeFadeMs = 5;            % to silence over this long on each side
cfg.audio.invert     = false;        % flip absolute polarity of both channels
cfg.audio.peakLevel  = 0.9;          % output is normalised to this peak

% --- Running ----------------------------------------------------------------
cfg.run.parallel  = true;            % read frames on all parallel workers
                                     % (needs the Parallel Computing Toolbox;
                                     % without it the same code runs serially)
cfg.run.edgeCache = '';              % .mat file to keep the groove edges in.
                                     % Edge reading is the slow step; with a
                                     % cache a rerun skips it.

% --- Groove position output -----------------------------------------------
cfg.position.lowpassHz     = 10;     % everything slower than this is "position"
cfg.position.samplesPerRev = 3600;   % points per revolution in the output
end
