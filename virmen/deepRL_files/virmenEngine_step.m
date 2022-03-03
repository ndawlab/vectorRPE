function [rew, curr_y_pos, tow_positions] = virmenEngine_step(PosFromData)

rew = 0;
tow_positions = -1; 
% -1 to repersent that the experiment hasn't ended yet

global vr; 

% one step of virmenEngine  
if ~vr.experimentEnded
    
    if vr.state == BehavioralState.InterTrial % previoulsy, EndOfTrial
        rew = -1;
        curr_y_pos = vr.position(2);
        tow_positions = -1;
        
        
    else % if in trial, move accordingly 
        if vr.state == BehavioralState.ChoiceMade % intertrial
%             if length(vr.cuePos{1}) == length(vr.cuePos{2}) % always reward for equal trials
%                 rew = 1;
%             else
%                 rew = vr.choice == vr.trialType;
%             end

            rew = (vr.choice == vr.trialType) + 1;
        end
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


        % Input movement information
        try

            vr.velocity = vr.exper.movementFunction(vr, PosFromData);
            vr.dt = PosFromData(5)/1000;

        catch ME
            drawnow;
            virmenOpenGLRoutines(2);
            err = struct;
            err.message = ME.message;
            err.stack = ME.stack(1:end-1);
            return
        end

        % Calculate displacement
        vr.dp = vr.velocity*vr.dt;

        % Detect collisions with edges (continuous-time collision detection)
        [vr.dp(1:2), vr.collision] = virmenResolveCollisions(vr.position(1:2),vr.dp(1:2), ...
            vr.worlds{vr.currentWorld}.walls.endpoints,vr.worlds{vr.currentWorld}.walls.radius2, ...
            vr.worlds{vr.currentWorld}.walls.angle,vr.worlds{vr.currentWorld}.walls.border1, ...
            vr.worlds{vr.currentWorld}.walls.border2,vr.dpResolution);

        % Update position
        vr.position = vr.position + vr.dp;
        curr_y_pos = vr.position(2);
        tow_positions = vr.cuePos;
        % Rachel 8/2020 TODO: this might be buggy. might hav eto fix
        if vr.state ~= BehavioralState.WithinTrial && vr.state ~= BehavioralState.ChoiceMade
            tow_positions = -1; 
          
        end
        
    end % otherwise, initialize world accordingly 
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
    virmen_renderWorld()
    
    
else
    
    % Display engine runtime information
%     disp(['Ran ' num2str(vr.iterations-1) ' iterations in ' num2str(vr.timeElapsed,4) ...
%         ' s (' num2str(vr.timeElapsed*1000/(vr.iterations-1),3) ' ms/frame refresh time).']);

    % Run termination code
    try
          vr.code.termination(vr);
    catch ME
          drawnow;
          virmenOpenGLRoutines(2);
          err = struct;
          err.message = ME.message;
          err.stack = ME.stack(1:end-1);
          return
    end

    % Close the window used by ViRMEn
    drawnow;
    virmenOpenGLRoutines(2);
end

end


