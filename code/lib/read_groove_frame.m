function [I, rows] = read_groove_frame(dataDir, meta, k)
%READ_GROOVE_FRAME  Load camera frame k of a dataset written by simulate_scan.
%   [I, rows] = READ_GROOVE_FRAME(dataDir, meta, k) returns the image I
%   scaled to [0,1] of the ADC range, and the indices of its rows in the
%   full groove. meta is the struct loaded from dataDir/meta.mat.

I = double(imread(fullfile(dataDir, sprintf('frame_%05d.png', k)))) / meta.adcMax;
rows = ((k - 1) * meta.frameRows + 1 : (k - 1) * meta.frameRows + size(I, 1))';
end
