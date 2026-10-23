clear; close all; clc;

%% 1. DEFINE THE SYNTHETIC VINYL GROOVE

% All dimensions are in micrometres (um)
% Groove parameters (all dimensions in micrometres)
A = 20;                 % Lateral groove displacement amplitude (um)
lambda = 200;           % Wavelength along groove (um)
depth = 25;             % Groove depth (um)
includedAngle = 90;     % Included angle between groove sides (degrees)

% Coordinate grid
x = -100:1:100;
y = 0:1:1000;
[X, Y] = meshgrid(x, y);

% Sinusoidal groove centreline
xc = A * sin(2*pi*Y/lambda);

% V-shaped groove cross-section
halfAngle = includedAngle/2;
halfWidth = depth * tand(halfAngle);

% Distance from the groove centreline
distanceFromCentre = abs(X - xc);

% Groove surface: flat outside, sloping inside
Z = -max(depth - distanceFromCentre/tand(halfAngle), 0);

% True centreline for validation
x_true = xc;

%% 2. DISPLAY THE MODELLED GROOVE

figure('Color','w');

surf(X, Y, Z, Z, 'EdgeColor','none');
colormap(gca, gray(256));

xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
zlabel('Surface height, z (\mum)');
title('Modelled Vinyl Groove');

colorbar;
axis tight;
view(45,30);
camlight;
lighting gouraud;


figure('Color','w');

imagesc(x, y, Z);
set(gca,'YDir','normal');
axis image;
colormap(gca, gray(256));

xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
title('Groove Surface Height (Top View)');

colorbar;


%% 3. CALCULATE SURFACE NORMALS
% Determine the local orientation of the surface
% Columns correspond to x; rows correspond to y
[dZdx, dZdy] = gradient(Z, ...
    x(2)-x(1), y(2)-y(1));

Nx = -dZdx;
Ny = -dZdy;
Nz = ones(size(Z));

% Normalise surface normal vectors
normalLength = sqrt(Nx.^2 + Ny.^2 + Nz.^2);

Nx = Nx ./ normalLength;
Ny = Ny ./ normalLength;
Nz = Nz ./ normalLength;


%% 4. DEFINE CAMERA AND LIGHT SOURCES

% Camera directly above the groove
cameraDirection = [0, 0, 1];


% Desired incidence angle measured from the surface normal
incidenceAngle = 60;  % degrees

% Convert angle into horizontal and vertical components
h = sind(incidenceAngle);
v = cosd(incidenceAngle);

% Light A illuminates from one side
lightA = [ h, -0.25, v];
lightA = lightA / norm(lightA);

% Light B illuminates from the opposite side
lightB = [-h, -0.25, v];
lightB = lightB / norm(lightB);



%% 5. SIMULATE REFLECTED INTENSITY FROM LIGHT A

specularExponent = 40;

halfDirectionA = lightA + cameraDirection;
halfDirectionA = halfDirectionA / norm(halfDirectionA);

normalDotHalfA = ...
    Nx * halfDirectionA(1) + ...
    Ny * halfDirectionA(2) + ...
    Nz * halfDirectionA(3);

normalDotHalfA = max(normalDotHalfA, 0);

specA = normalDotHalfA .^ specularExponent;

% Raw, uncorrected intensity map
I_A = 0.05 + 0.95 * specA;


%% 6. SIMULATE REFLECTED INTENSITY FROM LIGHT B

halfDirectionB = lightB + cameraDirection;
halfDirectionB = halfDirectionB / norm(halfDirectionB);

normalDotHalfB = ...
    Nx * halfDirectionB(1) + ...
    Ny * halfDirectionB(2) + ...
    Nz * halfDirectionB(3);

normalDotHalfB = max(normalDotHalfB, 0);

specB = normalDotHalfB .^ specularExponent;

% Raw, uncorrected intensity map
I_B = 0.05 + 0.95 * specB;


%% 7. AVERAGE THE TWO RAW INTENSITY MAPS

% Average the two raw intensity maps
I_both_raw = (I_A + I_B) / 2;

% Smooth the averaged intensity map slightly
I_both = smoothdata(I_both_raw, 2, 'gaussian', 5);
I_both = smoothdata(I_both, 1, 'gaussian', 5);


%% 8. DISPLAY THE THREE REFLECTION MAPS IN GREYSCALE

figure('Color','w');

subplot(1,3,1);
imagesc(x, y, I_A);
set(gca,'YDir','normal');
axis image;
colormap(gca, gray(256));
clim([0 1]);
colorbar;
xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
title('Light A');

subplot(1,3,2);
imagesc(x, y, I_B);
set(gca,'YDir','normal');
axis image;
colormap(gca, gray(256));
clim([0 1]);
colorbar;
xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
title('Light B');

subplot(1,3,3);
imagesc(x, y, I_both);
set(gca,'YDir','normal');
axis image;
colormap(gca, gray(256));
clim([0 1]);
colorbar;
xlabel('Across groove, x (\mum)');
ylabel('Along groove, y (\mum)');
title('Average of Both Lights');

sgtitle('Simulated Reflected-Light Intensity Maps');



%% 9. Detect and track both groove edges

% Select the reflection image to analyse
I_test = I_both;

% Known approximate groove geometry
% For a 90-degree V-groove of 25 um depth:
expectedWidth = 2 * depth * tand(includedAngle/2);

% Tracking parameters
profileSmooth = 5;       % Smoothing of each intensity profile
trackingWindow = 8;      % Maximum midpoint movement allowed (um)
minWidth = 0.5 * expectedWidth;
maxWidth = 1.5 * expectedWidth;

nRows = size(I_test, 1);

% Preallocate results
x_left = nan(nRows, 1);
x_right = nan(nRows, 1);
x_centre_raw = nan(nRows, 1);

% Initial centre estimate.
% For this synthetic groove, xc starts at zero when y = 0.
% For a real image, use a manually selected starting position.

previousCentre = 0;

% Previous accepted left and right edge locations
previousLeft = NaN;
previousRight = NaN;
previousDetectedRow = NaN;

dx = x(2) - x(1);

% Maximum expected lateral edge movement per unit distance
% along the groove (x and y are both in micrometres)
maxEdgeSlope = 1.5;


for r = 1:nRows

    %% Step 1: Smooth profile and calculate intensity gradient
    profile = smoothdata(I_test(r, :), ...
                         'gaussian', profileSmooth);

    gradientProfile = gradient(profile, dx);
    edgeStrength = abs(gradientProfile);

    % Candidate edges = local maxima of gradient magnitude
    candidateIndices = find(islocalmax(edgeStrength));

    % Require candidate edges to be reasonably close to
    % the expected left and right sides of the groove
    candidateX = x(candidateIndices);
    candidateStrength = edgeStrength(candidateIndices);

    leftMask = candidateX < previousCentre;
    rightMask = candidateX > previousCentre;

    leftIndices = candidateIndices(leftMask);
    rightIndices = candidateIndices(rightMask);

    leftStrength = candidateStrength(leftMask);
    rightStrength = candidateStrength(rightMask);

    %% Step 2: Evaluate possible left-right edge pairs

    bestScore = -Inf;
    bestLeft = NaN;
    bestRight = NaN;

    for i = 1:length(leftIndices)

        xl = x(leftIndices(i));

        for j = 1:length(rightIndices)

            xr = x(rightIndices(j));

            % Candidate groove width and midpoint
            widthCandidate = xr - xl;
            centreCandidate = (xl + xr) / 2;

            % Reject implausible widths
            if widthCandidate < minWidth || ...
               widthCandidate > maxWidth
                continue;
            end

            % Reject midpoints too far from previous estimate
            if abs(centreCandidate - previousCentre) ...
                    > trackingWindow
                continue;
            end


            % Enforce continuity of each individual groove edge
            if ~isnan(previousDetectedRow)

                % Distance along the groove since the last accepted pair
                deltaY = abs(y(r) - y(previousDetectedRow));

                % Allow physical movement plus one x-grid spacing
                maxAllowedMovement = maxEdgeSlope * deltaY + dx;

               
            end


            % Normalise edge strengths for scoring
            strengthL = leftStrength(i);
            strengthR = rightStrength(j);

            maxStrength = max(edgeStrength) + eps;
            strengthScore = ...
                (strengthL + strengthR) / (2 * maxStrength);

            % Prefer plausible width and continuous tracking
            widthPenalty = abs(widthCandidate ...
                - expectedWidth) / expectedWidth;

            trackingPenalty = abs(centreCandidate ...
                - previousCentre) / trackingWindow;


            % Continuity penalty for movement of individual edges
            continuityPenalty = 0;

            if ~isnan(previousDetectedRow)
                deltaY = abs(y(r) - y(previousDetectedRow));
                maxAllowedMovement = maxEdgeSlope * deltaY + dx;

                leftMovement = abs(xl - previousLeft);
                rightMovement = abs(xr - previousRight);

                % Penalise movement beyond the expected allowance
                leftExcess = max(0, leftMovement - maxAllowedMovement);
                rightExcess = max(0, rightMovement - maxAllowedMovement);

                continuityPenalty = ...
                    (leftExcess + rightExcess) / (2 * maxAllowedMovement);
            end

            % Higher score is better
            score = strengthScore ...
                - 0.5 * widthPenalty ...
                - 0.5 * trackingPenalty ...
                - 0.5 * continuityPenalty;


            if score > bestScore
                bestScore = score;
                bestLeft = xl;
                bestRight = xr;
            end
        end
    end

    %% Step 3: Save edge positions and update tracking


    if ~isnan(bestLeft)
        x_left(r) = bestLeft;
        x_right(r) = bestRight;
        x_centre_raw(r) = (bestLeft + bestRight) / 2;

        % Update tracking references only after accepting a pair
        previousCentre = x_centre_raw(r);
        previousLeft = bestLeft;
        previousRight = bestRight;
        previousDetectedRow = r;
  


    else
        % If no valid pair is found, retain the previous
        % estimate as a search reference, but mark this row
        % as missing rather than inventing edge measurements.
        previousCentre = previousCentre;
    end
end


%% Fill occasional missing rows and smooth the estimate

validRows = find(~isnan(x_centre_raw));

if numel(validRows) < 2
    error(['Too few valid edge pairs detected. ', ...
           'Inspect the intensity profile and adjust parameters.']);
end

% Interpolate missing detections for plotting/comparison
x_centre_filled = interp1(validRows, ...
    x_centre_raw(validRows), (1:nRows)', 'linear', NaN);

% Fill missing values at the ends if needed
x_centre_filled = fillmissing( ...
    x_centre_filled, 'nearest');

% Smoothed estimate; retain raw estimate for validation
windowSize = 21;
x_centre_smooth = smoothdata( ...
    x_centre_filled, 'sgolay', windowSize);


%% Step 4: Compare with the true centreline

trueCentre = xc(:, 1);

errorRaw = x_centre_filled - trueCentre;
errorSmooth = x_centre_smooth - trueCentre;

rmseRaw = sqrt(mean(errorRaw.^2, 'omitnan'));
rmseSmooth = sqrt(mean(errorSmooth.^2, 'omitnan'));

biasRaw = mean(errorRaw, 'omitnan');
biasSmooth = mean(errorSmooth, 'omitnan');

fprintf('\n--- Edge-pair centreline results ---\n');
fprintf('Valid edge pairs: %d / %d rows\n', ...
    numel(validRows), nRows);
fprintf('Expected groove width: %.2f um\n', expectedWidth);
fprintf('Raw RMSE: %.3f um\n', rmseRaw);
fprintf('Smoothed RMSE: %.3f um\n', rmseSmooth);
fprintf('Raw bias: %.3f um\n', biasRaw);
fprintf('Smoothed bias: %.3f um\n', biasSmooth);


%% Plot reconstructed centreline

figure;
plot(y, trueCentre, 'k-', 'LineWidth', 2);
hold on;
plot(y, x_centre_filled, 'r:', 'LineWidth', 1);
plot(y, x_centre_smooth, 'b-', 'LineWidth', 1.5);

xlabel('Distance along groove, y (um)');
ylabel('Lateral position, x (um)');
title('Centreline Reconstruction Using Edge-Pair Tracking');
legend('True centreline', 'Raw edge midpoint', ...
       'Smoothed edge midpoint', 'Location', 'best');
grid on;


%% Plot detected edges on the intensity image

figure;
imagesc(x, y, I_test);
set(gca, 'YDir', 'normal');
colormap(gray(256));
clim([0 1]);
hold on;

plot(x_left, y, 'r.', 'MarkerSize', 4);
plot(x_right, y, 'b.', 'MarkerSize', 4);
plot(x_centre_filled, y, 'y-', 'LineWidth', 1.5);

xlabel('Lateral position, x (um)');
ylabel('Distance along groove, y (um)');
title('Detected Edges and Reconstructed Centreline');
legend('Left edge', 'Right edge', 'Estimated centreline');



%% 13. Quantitative Error Analysis

% Ground-truth centreline (known because the groove is simulated)
trueCentre = xc(:,1);
position = y(:);

% Identify rows where the edge detector found a real edge pair
detectedMask = isfinite(x_centre_raw) & isfinite(trueCentre);

% Identify rows where an estimate is available after interpolation
filledMask = isfinite(x_centre_filled) & isfinite(trueCentre);

% Calculate errors: estimate minus true centreline, in micrometres
errorDetected = x_centre_raw(detectedMask) ...
              - trueCentre(detectedMask);

errorFilled = x_centre_filled(filledMask) ...
            - trueCentre(filledMask);

errorSmoothed = x_centre_smooth(filledMask) ...
              - trueCentre(filledMask);

% Calculate error metrics
% RMSE, MAE, mean bias, maximum absolute error, median absolute error
calculateMetrics = @(e) [ ...
    sqrt(mean(e.^2)), ...
    mean(abs(e)), ...
    mean(e), ...
    max(abs(e)), ...
    median(abs(e)) ];

metricsDetected = calculateMetrics(errorDetected);
metricsFilled = calculateMetrics(errorFilled);
metricsSmoothed = calculateMetrics(errorSmoothed);

% Display results in a table
method = ["Raw detected points"; ...
          "Interpolated estimate"; ...
          "Smoothed estimate"];

results = table(method, ...
    [metricsDetected(1); metricsFilled(1); metricsSmoothed(1)], ...
    [metricsDetected(2); metricsFilled(2); metricsSmoothed(2)], ...
    [metricsDetected(3); metricsFilled(3); metricsSmoothed(3)], ...
    [metricsDetected(4); metricsFilled(4); metricsSmoothed(4)], ...
    [metricsDetected(5); metricsFilled(5); metricsSmoothed(5)], ...
    'VariableNames', {'Method','RMSE_um','MAE_um','Bias_um', ...
                      'MaxAbsError_um','MedianAbsError_um'});

disp(' ');
disp('CENTRELINE RECONSTRUCTION ERROR');
disp(results);

% Report how often the edge detector found a pair without interpolation
detectionCoverage = 100 * nnz(detectedMask) / numel(trueCentre);

fprintf('Direct detection coverage: %.1f%% (%d of %d rows)\n', ...
    detectionCoverage, nnz(detectedMask), numel(trueCentre));


%% 14. Plot the Reconstruction Error Along the Groove

% Recalculate errors for every row after interpolation and smoothing
errorFilledAll = x_centre_filled - trueCentre;
errorSmoothedAll = x_centre_smooth - trueCentre;

figure;
plot(position, errorFilledAll, 'LineWidth', 1.2);
hold on;
plot(position, errorSmoothedAll, 'LineWidth', 1.5);
yline(0, 'k--', 'Zero error');
xlabel('Position along groove, y (\mum)');
ylabel('Centreline error (\mum)');
title('Reconstruction Error Along the Groove');
legend('Interpolated estimate', 'Smoothed estimate', ...
       'Location', 'best');
grid on;
hold off;


%% 15. Plot the Distribution of Absolute Errors

figure;
histogram(abs(errorDetected), 20, ...
          'Normalization', 'probability');
hold on;
histogram(abs(errorSmoothedAll), 20, ...
          'Normalization', 'probability');
xlabel('Absolute centreline error (\mum)');
ylabel('Fraction of samples');
title('Distribution of Absolute Reconstruction Error');
legend('Directly detected points', 'Smoothed estimate', ...
       'Location', 'best');
grid on;
hold off;


%% 16. Plot Estimated Centreline Against Ground Truth

figure;
plot(position, trueCentre, 'LineWidth', 2);
hold on;
plot(position, x_centre_filled, '--', 'LineWidth', 1.2);
plot(position, x_centre_smooth, 'LineWidth', 1.2);
xlabel('Position along groove, y (\mum)');
ylabel('Lateral position, x (\mum)');
title('True and Reconstructed Groove Centrelines');
legend('True centreline', 'Interpolated estimate', ...
       'Smoothed estimate', 'Location', 'best');
grid on;
hold off;


%% 17. Compare Detected Edges with True Geometric Edges

trueLeft = trueCentre - halfWidth;
trueRight = trueCentre + halfWidth;

figure('Color','w');
imagesc(x, y, I_test);
set(gca,'YDir','normal');
colormap(gray(256));
clim([0 1]);
hold on;

% True geometric groove boundaries
plot(trueLeft, y, 'c-', 'LineWidth', 1.5);
plot(trueRight, y, 'c-', 'LineWidth', 1.5);

% Detected boundaries
plot(x_left, y, 'r.', 'MarkerSize', 5);
plot(x_right, y, 'b.', 'MarkerSize', 5);

xlabel('Lateral position, x (\mum)');
ylabel('Distance along groove, y (\mum)');
title('Detected Edges Compared with True Groove Boundaries');

legend('True left edge', 'True right edge', ...
    'Detected left edge', 'Detected right edge', ...
    'Location', 'best');
grid on;
hold off;


%% 18. Centreline Error at the Sinusoidal Turning Points

% The centreline peaks and troughs occur at these y positions
turningPoints = lambda/4 : lambda/2 : max(y);

figure('Color','w');
plot(y, x_centre_smooth - trueCentre, 'k-', ...
    'LineWidth', 1.2);
hold on;
yline(0, 'k--');

for k = 1:length(turningPoints)
    xline(turningPoints(k), 'r:', 'LineWidth', 1);
end

xlabel('Distance along groove, y (\mum)');
ylabel('Centreline error (\mum)');
title('Reconstruction Error Near Groove Turning Points');
grid on;
hold off;

%% 19. Compare Intensity Profiles at Different Groove Orientations

yPeak = lambda/4;
yMidSlope = lambda/2;
yOther = 3*lambda/8;

selectedY = [yPeak, yMidSlope, yOther];
profileLabels = {'Turning point', ...
    'Opposite turning point', ...
    'Intermediate position'};

figure('Color','w');

for k = 1:length(selectedY)

    [~,row] = min(abs(y-selectedY(k)));

    profile = smoothdata(I_test(row,:), ...
        'gaussian', profileSmooth);

    gradientProfile = abs(gradient(profile, dx));

    subplot(3,1,k);

    plot(x, profile, 'k-', 'LineWidth', 1.2);
    hold on;

    xline(trueLeft(row), 'c--', 'True left edge');
    xline(trueRight(row), 'c--', 'True right edge');

    if isfinite(x_left(row))
        xline(x_left(row), 'r-', 'Detected left');
    end

    if isfinite(x_right(row))
        xline(x_right(row), 'b-', 'Detected right');
    end

    ylabel('Intensity');
    title(sprintf('%s: y = %.1f \\mum', ...
        profileLabels{k}, y(row)));

    grid on;
    hold off;
end

xlabel('Lateral position, x (\mum)');