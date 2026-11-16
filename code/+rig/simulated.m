function dev = simulated()
%SIMULATED  A stand-in for the turntable controller, for dry runs.
%
%   dev = rig.simulated()
%
%   Accepts the same commands as rig.connect's device and answers at once
%   with the replies the firmware would give, keeping track of the table
%   angle and radial position. Nothing moves and no time passes. Every
%   command is printed, so a script can be checked before the rig exists.

state = containers.Map();      % a handle object: the closures below share it
state('queue')   = {};
state('steps')   = 0;          % turntable position, microsteps
state('radial')  = 0;          % radial position, mm
stepsPerDegree = 25600 / 360;

dev.send       = @(line) answer(state, char(line), stepsPerDegree);
dev.receive    = @() nextReply(state);
dev.setTimeout = @(seconds) [];
dev.close      = @() [];
end


function answer(state, line, stepsPerDegree)
fprintf('  [rig] %s\n', line);
letter = upper(line(1));
value  = sscanf(line(2:end), '%f', 1);
replies = {};
switch letter
    case {'M', 'A'}
        if letter == 'M'
            state('steps') = state('steps') + round(value * stepsPerDegree);
        else
            state('steps') = round(value * stepsPerDegree);
        end
        replies = {'MV,0,0', ['OK,' letter], sprintf('DN,0,%d', state('steps'))};
    case 'Y'
        state('radial') = state('radial') + value;
        replies = {sprintf('RD,0,0,%.4f', state('radial')), 'OK,Y'};
    case 'Q'
        replies = {sprintf('RD,0,0,%.4f', state('radial'))};
    case 'P'
        replies = {sprintf('POS,0,%d,%.4f', state('steps'), state('steps') / stepsPerDegree)};
    case 'H'
        state('steps') = 0;
        replies = {'MV,0,0', 'OK,H', 'HOME,0,ok'};
    case 'X'
        replies = {'DN,0,0', 'OK,X'};
    case 'K'
        state('radial') = 0;
        replies = {'OK,K'};
    case 'Z'
        state('steps') = 0;
        replies = {'OK,Z'};
    otherwise
        replies = {['OK,' letter]};
end
state('queue') = [state('queue'), replies];
end


function line = nextReply(state)
queue = state('queue');
if isempty(queue)
    line = '';
else
    line = queue{1};
    state('queue') = queue(2:end);
end
end
