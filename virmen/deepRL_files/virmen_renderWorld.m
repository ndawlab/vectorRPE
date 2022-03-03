function virmen_renderWorld()

global vr;
% Configurations that depend on user functions
if exist(func2str(vr.exper.transformationFunction),'file') == 3   % MEX programs don't report nargin
    numTransformInputs = 1;
else
    numTransformInputs = nargin(vr.exper.transformationFunction);
end
numMovementOutputs = nargout(vr.exper.movementFunction);


% Reset user input states (keyboard and mouse)
vr.textClicked = NaN;
vr.keyPressed = NaN;
vr.keyReleased = NaN;
vr.buttonPressed = NaN;
vr.buttonReleased = NaN;
vr.modifiers = NaN;
vr.activeWindow = NaN;

% Translate+rotate coordinates and calculate distances from animal
[vertexArray, distance] = virmenProcessCoordinates(vr.worlds{vr.oldWorld}.surface.vertices,vr.position);

% Transform 3D coordinates to 2D screen coordinates
try
    if numTransformInputs == 2
        vertexArrayTransformed = vr.exper.transformationFunction(vertexArray, vr);
    else
        vertexArrayTransformed = vr.exper.transformationFunction(vertexArray);
    end
catch ME
    drawnow;
    virmenOpenGLRoutines(2);
    err = struct;
    err.message = ME.message;
    err.stack = ME.stack(1:end-1);
    return
end

% Number of transformations returned by the user's function
nDim = size(vertexArrayTransformed,3);

% Extract triangles visible in each transformation
triangles = virmenVisibleTriangles(vr.worlds{vr.oldWorld}.surface.triangulation,vertexArrayTransformed ...
    ,nDim,size(vertexArrayTransformed,2),vr.worlds{vr.oldWorld}.surface.visible);

% Assign distances as the z coordinate
for d = 1:nDim
    vertexArrayTransformed(3,:,d) = distance;
end

% Sort triangles from back to front (only when transparency is on)
if size(vr.worlds{vr.currentWorld}.surface.colors,1)==4
    ord = virmenTrianglesDistance(distance,vr.worlds{vr.oldWorld}.surface.triangulation);
    [~, ord] = sort(ord,'descend');
    triangles = virmenOrderTriangles(triangles,size(triangles,2),nDim,ord);
end

% Set up textboxes and plots
%     if ~isempty(vr.text) || ~isempty(vr.plot)
%         % Fill in texts with defaults
%         for ndx = 1:length(vr.text)
%             if isempty(vr.text(ndx).string)
%                 vr.text(ndx).string = '';
%             end
%             if isempty(vr.text(ndx).position)
%                 vr.text(ndx).position = [0 0];
%             end
%             if isempty(vr.text(ndx).size)
%                 vr.text(ndx).size = 0.03;
%             end
%             if isempty(vr.text(ndx).color)
%                 vr.text(ndx).color = [1 1 1];
%             end
%             if isempty(vr.text(ndx).window)
%                 vr.text(ndx).window = 1;
%             end
%         end
%
%         % Fill in plots with defaults
%         for ndx = 1:length(vr.plot)
%             if isempty(vr.plot(ndx).x) || isempty(vr.plot(ndx).y)
%                 vr.plot(ndx).x = [];
%                 vr.plot(ndx).y = [];
%             end
%             if isempty(vr.plot(ndx).color)
%                 vr.plot(ndx).color = [1 1 1];
%             end
%             if isempty(vr.plot(ndx).window)
%                 vr.plot(ndx).window = 1;
%             end
%         end
%     end

% Render the environment
drawnow;
vr.cursorPosition = zeros(size(vr.windows,2),2);
for wind = 1:size(vr.windows,2)
    % Determine the total number of line segments to draw
    tot = 0;
    for ndx = 1:length(vr.text)
        if vr.text(ndx).window == wind
            for s = 1:length(vr.text(ndx).string)
                tot = tot+length(letterFont{double(vr.text(ndx).string(s))});
            end
        end
    end
    colors = zeros(6,tot);
    coords = zeros(4,tot);
    
    % Create arrays of coordinates and colors
    cnt = 0;
    for ndx = 1:length(vr.text)
        if vr.text(ndx).window == wind
            for s = 1:length(vr.text(ndx).string)
                virmenCreateLetters(coords,colors,cnt,letterGrid,letterFont{double(vr.text(ndx).string(s))},vr.text(ndx).size,vr.text(ndx).position,s,vr.text(ndx).color);
            end
        end
    end
    
    % Attach plots to the arrays of coordinates and colors
    %         for ndx = 1:length(vr.plot)
    %             if vr.plot(ndx).window == wind
    %                 sz = size(coords,2);
    %                 coords(:,sz+1:sz+length(vr.plot(ndx).x)-1) = ...
    %                     [vr.plot(ndx).x(1:end-1); vr.plot(ndx).y(1:end-1); vr.plot(ndx).x(2:end); vr.plot(ndx).y(2:end)];
    %                 colors([1 4],sz+1:sz+length(vr.plot(ndx).x)-1) = vr.plot(ndx).color(1);
    %                 colors([2 5],sz+1:sz+length(vr.plot(ndx).x)-1) = vr.plot(ndx).color(2);
    %                 colors([3 6],sz+1:sz+length(vr.plot(ndx).x)-1) = vr.plot(ndx).color(3);
    %             end
    %         end
    
    % Create an array of indices
    indices = 0:2*size(coords,2)-1;
    
    % Render the environment
    if ~isnan(vr.transformations(wind)) && vr.transformations(wind) <= nDim
        [keyPressed, keyReleased, buttonPressed, buttonReleased, modifiers, activeWindow, vr.cursorPosition(wind,:)] = ...
            virmenOpenGLRoutines(1,vertexArrayTransformed,triangles,vr.worlds{vr.oldWorld}.surface.colors ...
            ,coords,int32(indices),colors,wind,vr.transformations(wind) ...
            ,3*size(vertexArrayTransformed,2),3*size(triangles,2) ...
            ,vr.worlds{vr.oldWorld}.changed);
    else
        [keyPressed, keyReleased, buttonPressed, buttonReleased, modifiers, activeWindow, vr.cursorPosition(wind,:)] = ...
            virmenOpenGLRoutines(1,[],[],[],coords,int32(indices),colors,wind,0,0,0,false);
    end
    
    % Process user inputs (keyboard and mouse)
    if keyPressed >= 0
        vr.keyPressed = keyPressed;
    end
    if keyReleased >= 0
        vr.keyReleased = keyReleased;
    end
    if buttonPressed >= 0
        vr.buttonPressed = buttonPressed;
    end
    if buttonReleased >= 0
        vr.buttonReleased = buttonReleased;
    end
    if modifiers >= 0
        vr.modifiers = modifiers;
    end
    if activeWindow >= 0
        vr.activeWindow = activeWindow+1;
    end
    
end
end