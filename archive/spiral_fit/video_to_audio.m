function out = video_to_audio(videoFile, varargin)
%VIDEO_TO_AUDIO  Microscope video of a record -> audio (Parts A and B).
%   out = VIDEO_TO_AUDIO(videoFile, Name, Value, ...) runs DISC_MODEL_FIT
%   (the disc: spiral, poses, pitch, distortion) and MUSIC_ON_SPIRAL (the
%   music on that spiral) into one run folder results/runs/<RunName>/,
%   writing <video>_mono.wav, _stereo.wav (raw) and _mono_eq.wav,
%   _stereo_eq.wav (listenable), partA.mat, partB.mat, check figures and
%   log.txt. Slow steps are cached there, so a rerun resumes.
%   Options: 'RunName' (default <video name>), 'Magnification',
%   'Settings' (struct merged into code/settings.json), 'MaxFrames'.
%   Example: video_to_audio('data/keyence_recording/20261029_163032.avi', 'Magnification', 30)
ip = inputParser;
ip.addParameter('RunName', '');
ip.addParameter('Magnification', []);
ip.addParameter('Settings', struct());
ip.addParameter('MaxFrames', Inf);
ip.parse(varargin{:});
o = ip.Results;
[~, vname] = fileparts(videoFile);
if isempty(o.RunName), o.RunName = vname; end
out.partA = disc_model_fit(videoFile, 'RunName', o.RunName, 'Magnification', o.Magnification, ...
    'Settings', o.Settings, 'MaxFrames', o.MaxFrames);
out.partB = music_on_spiral(videoFile, out.partA, 'RunName', o.RunName, 'Settings', o.Settings);
end
