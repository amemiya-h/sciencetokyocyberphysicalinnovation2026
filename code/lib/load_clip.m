function [sig, fs] = load_clip(audioFile, tStart, tLength)
%LOAD_CLIP  Read tLength seconds of audio starting at tStart (s).
%   [sig, fs] = LOAD_CLIP(audioFile, tStart, tLength) returns all channels.

info = audioinfo(audioFile);
fs = info.SampleRate;
first = max(1, round(tStart*fs) + 1);
last = min(info.TotalSamples, first + round(tLength*fs) - 1);
sig = audioread(audioFile, [first, last]);
end
