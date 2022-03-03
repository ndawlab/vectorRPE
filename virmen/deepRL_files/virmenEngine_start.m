function vr = virmenEngine_start(exper)
% Virmen engine

% *************************************************************************
% Copyright 2013, Princeton University.  All rights reserved.
%
% By using this software the USER indicates that he or she has read,
% understood and will comply with the following:
%
%  --- Princeton University hereby grants USER nonexclusive permission to
% use, copy and/or modify this software for internal, noncommercial,
% research purposes only. Any distribution, including publication or
% commercial sale or license, of this software, copies of the software, its
% associated documentation and/or modifications of either is strictly
% prohibited without the prior consent of Princeton University. Title to
% copyright to this software and its associated documentation shall at all
% times remain with Princeton University.  Appropriate copyright notice
% shall be placed on all software copies, and a complete copy of this
% notice shall be included in all copies of the associated documentation.
% No right is granted to use in advertising, publicity or otherwise any
% trademark, service mark, or the name of Princeton University.
%
%  --- This software and any associated documentation is provided "as is"
%
% PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES, EXPRESS OR
% IMPLIED, INCLUDING THOSE OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR
% PURPOSE, OR THAT  USE OF THE SOFTWARE, MODIFICATIONS, OR ASSOCIATED
% DOCUMENTATION WILL NOT INFRINGE ANY PATENTS, COPYRIGHTS, TRADEMARKS OR
% OTHER INTELLECTUAL PROPERTY RIGHTS OF A THIRD PARTY.
%
% Princeton University shall not be liable under any circumstances for any
% direct, indirect, special, incidental, or consequential damages with
% respect to any claim by USER or any third party on account of or arising
% from the use, or inability to use, this software or its associated
% documentation, even if Princeton University has been advised of the
% possibility of those damages.
% *************************************************************************

% Clean up in case of an incorrect exit (e.g. user terminated Virmen by stopping debug mode)
drawnow;
virmenOpenGLRoutines(2);

% No error by default
err = -1;

global vr;

% Load experiment
vr.exper = exper;
vr.code = exper.experimentCode(); %#ok<*STRNU>
[letterGrid, letterFont, letterAspectRatio] = virmenLoadFont;
[vr.windows, vr.transformations] = virmenLoadWindows(exper);
% hacking this to make the window smaller
vr.windows(3) = 120; % 960
vr.windows(4) = 68;      % 540

% Load worlds
vr.worlds = struct([]);
for wNum = 1:length(vr.exper.worlds)
    vr.worlds{wNum} = loadVirmenWorld(vr.exper.worlds{wNum});
    if size(vr.worlds{wNum}.surface.colors,1) == 4
        vr.worlds{wNum}.surface.colors(4,isnan(vr.worlds{wNum}.surface.colors(4,:))) = 1-eps;
    end
end


% Initialize parameters
vr.experimentEnded = false;
vr.currentWorld = 1;
vr.position =  vr.worlds{vr.currentWorld}.startLocation;
vr.velocity = [0 0 0 0];
vr.dt = NaN;
vr.dp = NaN(1,4);
vr.dpResolution = inf;
vr.collision = false;
vr.text = struct('string',{},'position',{},'size',{},'color',{},'window',{});
vr.plot = struct('x',{},'y',{},'color',{},'window',{});
vr.textClicked = NaN;
vr.keyPressed = NaN;
vr.keyReleased = NaN;
vr.buttonPressed = NaN;
vr.buttonReleased = NaN;
vr.modifiers = NaN;
vr.activeWindow = NaN;
vr.cursorPosition = NaN;
vr.iterations = 0;
vr.timeStarted = NaN;
vr.timeElapsed = 0;
vr.sensorData = [];
vr.LickData = [];

% if RigParameters.hasLickMeter
%     vr.LickData = single(zeros(1,50)); %2*size_hardware_lickbuffer*max_unread_buffers
% end

% Configurations that depend on user functions
if exist(func2str(vr.exper.transformationFunction),'file') == 3   % MEX programs don't report nargin
    numTransformInputs = 1;
else
    numTransformInputs = nargin(vr.exper.transformationFunction);
end
numMovementOutputs = nargout(vr.exper.movementFunction);

% Initialize an OpenGL window
drawnow;
virmenOpenGLRoutines(0,vr.windows,ismac);



% Run initialization code
try
    vr = vr.code.initialization(vr); %#ok<*NASGU>
catch ME
    drawnow;
    virmenOpenGLRoutines(2);
    err = struct;
    err.message = ME.message;
    err.stack = ME.stack(1:end-1);
    return
end


% Initialize engine
vr.oldWorld = NaN;
vr.oldBackgroundColor = [NaN NaN NaN];
vr.oldColorSize = NaN;
vr.timeStarted = now;

% Timing related info
firstTic = tic;
vr.dt = 0; % Don't move on the first time step


% now within the while loop...

% Update the number of iterations
vr.iterations = vr.iterations + 1;

% Switch worlds, if necessary
if vr.currentWorld ~= vr.oldWorld
    vr.oldWorld = vr.currentWorld;
end

% Set transparency options, if necessary
if vr.oldColorSize ~= size(vr.worlds{vr.currentWorld}.surface.colors,1)
    vr.oldColorSize = size(vr.worlds{vr.currentWorld}.surface.colors,1);
    drawnow;
    virmenOpenGLRoutines(3,vr.oldColorSize);
end

% Set world background color, if necessary
if ~all(vr.oldBackgroundColor==vr.worlds{vr.currentWorld}.backgroundColor)
    vr.oldBackgroundColor = vr.worlds{vr.currentWorld}.backgroundColor;
    drawnow;
    virmenOpenGLRoutines(4,vr.oldBackgroundColor);
end



% Run custom code on each engine iteration
try
    vr = vr.code.runtime(vr);
catch ME
    drawnow;
    virmenOpenGLRoutines(2);
    err = struct;
    err.message = ME.message;
    err.stack = ME.stack(1:end-1);
    return
end



end
