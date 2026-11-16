function writePositionCsv(filename, position)
%WRITEPOSITIONCSV  Save groove position as a plain text table.
%
%   groove.io.writePositionCsv('groove_position.csv', position)
%
%   position  output of groove.track.groovePosition
%   Columns: angle_rad, time_s, radius_mm, width_um

file = fopen(filename, 'w');
assert(file > 0, 'Cannot open %s for writing.', filename);
fprintf(file, 'angle_rad,time_s,radius_mm,width_um\n');
fprintf(file, '%.6f,%.6f,%.6f,%.3f\n', ...
    [position.angleRad; position.timeSec; position.radiusMm; position.widthUm]);
fclose(file);
end
