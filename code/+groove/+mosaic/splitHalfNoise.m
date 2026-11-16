function noise = splitHalfNoise(mosaic, period, cfg)
%SPLITHALFNOISE  How much of the result is music and how much is noise.
%
%   noise = groove.mosaic.splitHalfNoise(mosaic, period, cfg)
%
%   The mosaic was also built twice over, from odd frames only and from
%   even frames only. The groove is the same in both; the image noise is
%   not. So half their sum is groove plus a little noise, and half their
%   difference is noise alone. Comparing the two by frequency band shows
%   up to what frequency the scan carries real signal.
%
%   noise fields (one entry per band)
%     bandHz     band edges, numBands x 2
%     signalUm   rms edge movement in the band (groove + noise)
%     noiseUm    rms noise of the full average in the band
%     snrDb      signal-to-noise ratio of the full average
%   and, at full frequency resolution, frequencyHz, totalPower, noisePower

bandHz = [30 100; 100 300; 300 1000; 1000 3000; 3000 6000; 6000 10000; 10000 15000; 15000 20000];
sampleRate = period / (60 / cfg.record.rpm);
segment = 4096;
taper   = 0.5 - 0.5 * cos(2*pi * (0:segment - 1) / (segment - 1));
frequency = (0:segment/2) * sampleRate / segment;

seen    = mosaic.weight > 0.3;
used    = find(sum(seen, 2) > 3000);
covered = find(sum(seen(used, :), 1) >= numel(used) / 2);
first   = covered(1) + floor((covered(end) - covered(1) + 1 - period) / 2);
turn    = first : first + period - 1;

sumPower  = zeros(1, segment/2 + 1);
diffPower = zeros(1, segment/2 + 1);
count = 0;
for t = used.'
    weightA = squeeze(mosaic.halfWeight(1, t, turn)).';
    weightB = squeeze(mosaic.halfWeight(2, t, turn)).';
    for edge = 1:2
        if edge == 1, sums = mosaic.halfTop; else, sums = mosaic.halfBottom; end
        a = double(squeeze(sums(1, t, turn)).') ./ max(double(weightA), 1e-6);
        b = double(squeeze(sums(2, t, turn)).') ./ max(double(weightB), 1e-6);
        present = weightA > 0.2 & weightB > 0.2;
        for start = 1:segment/2:period - segment + 1
            piece = start:start + segment - 1;
            if ~all(present(piece))
                continue        % a bridged hole is neither groove nor noise
            end
            sumPower  = sumPower  + segmentPower((a(piece) + b(piece)) / 2, taper);
            diffPower = diffPower + segmentPower((a(piece) - b(piece)) / 2, taper);
            count = count + 1;
        end
    end
end
scale = (cfg.camera.pixelSizeUm)^2 / (count * sum(taper.^2) * segment / 2);   % to um^2 per bin, one-sided

numBands = size(bandHz, 1);
noise.bandHz   = bandHz;
noise.signalUm = zeros(numBands, 1);
noise.noiseUm  = zeros(numBands, 1);
noise.snrDb    = zeros(numBands, 1);
for n = 1:numBands
    inBand = frequency >= bandHz(n, 1) & frequency < bandHz(n, 2);
    total  = sum(sumPower(inBand))  * scale;
    random = sum(diffPower(inBand)) * scale;
    noise.signalUm(n) = sqrt(total);
    noise.noiseUm(n)  = sqrt(random);
    noise.snrDb(n)    = 10 * log10(max(total - random, 1e-12) / random);
end
noise.sampleRate  = sampleRate;
noise.frequencyHz = frequency;              % full resolution, for groove.audio.noiseFilter
noise.totalPower  = sumPower  * scale;      % groove + noise of the full average
noise.noisePower  = diffPower * scale;      % noise of the full average
end


function p = segmentPower(x, taper)
% Power spectrum of one tapered segment, positive frequencies only.
% (Not called "power": in MATLAB that name is the .^ operator.)
x = x - mean(x);
spectrum = fft(x .* taper);
half = floor(numel(x) / 2) + 1;
p = real(spectrum(1:half) .* conj(spectrum(1:half)));
end
