function res = video_to_audio(videoFile, varargin)
%VIDEO_TO_AUDIO  One step: microscope video of the turning disc -> audio.
%   VIDEO_TO_AUDIO              asks for the video file
%   VIDEO_TO_AUDIO(videoFile)   e.g. 'data/keyence_recording/20261027_184833.avi'
%   VIDEO_TO_AUDIO(videoFile, 'magnification', 50, 'rpm', 100/3, ...)
%
%   1. extract_ring_frames: picks frames covering one revolution from the
%      video and saves them next to it (skipped if already done).
%   2. retrieve_ring_polar: unwarps every frame about the rig axis, reads
%      every groove straight across, rejects impossible readings, lines
%      the frames up, follows the spiral and plays it back.
%
%   Outputs in results/runs/ (<name> = video file name):
%     <name>_polar_all_eq.wav   the whole visible spiral, ready to listen to
%     <name>_polar_all.wav      the same, unprocessed
%     <name>_polar_stereo.wav / _mono.wav, <name>_polar_chains/, _log.txt,
%     <name>_polar_result.mat
%
%   Options (name, value; defaults in brackets)
%     magnification  VHX zoom; pixel = 148.8/mag um [50]
%     rpm            [100/3]
%     mirrored       true if the VHX shows a mirror image [false]
%     views          frames that see each point; more views are averaged
%                    into less noise (e.g. 4; default: 20-50% overlap,
%                    i.e. 1-2 views). Results get the tag <name>_v<views>
%     redo           extract the frames again [false]
%     vMax, rhoMin   physical limits of the cut (m/s, um) [0.3, 10]
%   Recording: grooves left-right along the long side, record's outer edge
%   at the top, disc turned in its playing direction through at least one
%   full revolution.

if nargin < 1 || isempty(videoFile)
    [f, p] = uigetfile({'*.avi;*.mp4;*.wmv;*.mov', 'Video files'}, ...
                       'Video of the record grooves', fullfile(project_root(), 'data'));
    if isequal(f, 0), return; end
    videoFile = fullfile(p, f);
end
if ~exist(videoFile, 'file') && exist(fullfile(project_root(), videoFile), 'file')
    videoFile = fullfile(project_root(), videoFile);
end
opts = struct(varargin{:});
tAll = tic;
fprintf('== Extracting one revolution of frames from %s\n', videoFile);
dataDir = extract_ring_frames(videoFile, opts);
fprintf('== Reading the grooves\n');
[~, name] = fileparts(videoFile);
ropts = rmfield_if(opts, {'magnification', 'rpm', 'mirrored', 'redo', 'minOverlap', ...
                          'maxOverlap', 'views', 'outDir', 'plot'});
if isfield(opts, 'views') && ~isnan(opts.views)
    name = sprintf('%s_v%d', name, opts.views);
end
ropts.tag = [name '_polar'];
res = retrieve_ring_polar(dataDir, ropts);
fprintf('== Done in %.1f min. Listen to %s\n', toc(tAll) / 60, ...
    fullfile(res.runsDir, [res.tag '_all_eq.wav']));
end

function s = rmfield_if(s, names)
for k = 1:numel(names)
    if isfield(s, names{k}), s = rmfield(s, names{k}); end
end
end
