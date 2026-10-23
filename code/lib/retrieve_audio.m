function r = retrieve_audio(dataDir, trackOpts, audioOpts)
%RETRIEVE_AUDIO  Retrieval path: frames -> centreline -> audio, plus scores.
%   r = RETRIEVE_AUDIO(dataDir, trackOpts, audioOpts) tracks the groove
%   through every frame in dataDir, fills gaps, plays the centreline back
%   (centreline_to_audio), and only then opens truth.mat to score it.
%
%   Inputs
%     dataDir    dataset written by simulate_scan
%     trackOpts  as for track_groove_edges; expectedWidth (nominal
%                groove geometry), profileSmooth (~2 um) and feature
%                (from the light type) are filled in if missing
%     audioOpts  as for centreline_to_audio; grooveSpeed and riaa are
%                taken from meta.mat if missing
%
%   Output struct r
%     meta, tr, xFilled     metadata, tracked edges, gap-filled centreline
%     est, ref              audio from the tracked and the true centreline,
%                           through the same playback chain
%     truth                 contents of truth.mat
%     coverage              fraction of rows with a detected edge pair
%     rmseDetected, rmseFilled   centreline error (um)
%     snr                   audio SNR of est against ref (dB)

meta = load(fullfile(dataDir, 'meta.mat'));
if ~isfield(trackOpts, 'expectedWidth')
    trackOpts.expectedWidth = 2 * meta.scene.depth * tand(meta.scene.includedAngle/2);
end
if ~isfield(trackOpts, 'profileSmooth')
    trackOpts.profileSmooth = max(3, round(2 / meta.dy));   % ~2 um
end
if ~isfield(trackOpts, 'feature')     % step edges under coaxial light,
    if strcmp(meta.light.type, 'coaxial')   % bright lines otherwise
        trackOpts.feature = 'step';
    else
        trackOpts.feature = 'ridge';
    end
end
if ~isfield(audioOpts, 'grooveSpeed')
    audioOpts.grooveSpeed = meta.grooveSpeed;
end
if ~isfield(audioOpts, 'riaa')
    audioOpts.riaa = meta.scene.riaa;
end

r.meta = meta;
r.tr = track_groove_dataset(dataDir, meta, trackOpts);
r.xFilled = fill_gaps(meta.y, r.tr.centre);
r.est = centreline_to_audio(r.xFilled, meta.dy, audioOpts);

% Evaluation only from here on
r.truth = load(fullfile(dataDir, 'truth.mat'));
r.ref = centreline_to_audio(r.truth.xc, meta.dy, audioOpts);

detected = ~isnan(r.tr.centre);
r.coverage = mean(detected);
r.rmseDetected = sqrt(mean((r.tr.centre(detected) - r.truth.xc(detected)).^2));
r.rmseFilled = sqrt(mean((r.xFilled - r.truth.xc).^2));
r.snr = 10*log10(sum(r.ref.audio.^2) / sum((r.est.audio - r.ref.audio).^2));
end
