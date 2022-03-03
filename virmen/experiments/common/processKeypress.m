%% Some standard ways in which user keypress can be used to control a ViRMen experiment.
function vr = processKeypress(vr, console)

global rotation_transform
if isempty(rotation_transform)
    rotation_transform=0;
end

global forwardface_flag
if isempty(forwardface_flag)
    forwardface_flag=0;
end
persistent vrMovieWriter;
  if vr.iterations < 2
    vrMovieWriter = [];
  end

%   if ~isempty(vr.keyPressed) && isfinite(vr.keyPressed)
%     vr.keyPressed
%   end

  switch vr.keyPressed
    
    % Increment maze ID to a more difficult configuration
    case 334    % Numpad +
      if vr.mazeID + vr.mazeChange < numel(vr.mazes)
        vr.mazeChange = vr.mazeChange + 1;
        console.log('Next maze will be %d %s = %d', vr.mazeID, incr2str(vr.mazeChange), vr.mazeID + vr.mazeChange);
      end
      
    % Decrement maze ID to an easier configuration
    case 333    % Numpad -
      if vr.mazeID + vr.mazeChange > 1
        vr.mazeChange = vr.mazeChange - 1;
        console.log('Next maze will be %d %s = %d', vr.mazeID, incr2str(vr.mazeChange), vr.mazeID + vr.mazeChange);
      end
      
    % Give reward
    case 82     % R
      deliverReward(vr, vr.rewardMSec);
      
    % Toggle trial selection method
    case 331    % Numpad /
      if isfield(vr, 'protocol')
        vr.protocol.nextDrawMethod();
      end

%     % Toggle comment entry status for ExperimentLog
%     case 330    % Numpad .
%       if isfield(vr, 'logger')
%         vr.logger.toggleComment();
%       end

    % Forfeit a trial, as if the animal has made a wrong choice
    case 261    % Delete
      vr.choice     = Choice.nil;
      vr.state      = BehavioralState.ChoiceMade;
      if isfield(vr, 'protocol')
        trial       = sprintf(' %d', vr.protocol.currentTrial);
      else
        trial       = '';
      end
      
      console.log('Forfeiting trial%s with choice = %s', trial, char(vr.choice));
      
    % Increase reward factor
    case 266    % Page up
      vr.protocol.setRewardScale( min(vr.protocol.rewardScale + 0.2, 2) );
      console.log ( 'User override: Scaling rewards by %.3g (%.3g uL)'                  ...
                  , vr.protocol.rewardScale                                             ...
                  , vr.protocol.rewardScale * 1000*RigParameters.rewardSize             ...
                  );
      
    % Decrease reward factor
    case 267    % Page down
      vr.protocol.setRewardScale( max(vr.protocol.rewardScale - 0.2, 1) );
      console.log ( 'User override: Scaling rewards by %.3g (%.3g uL)'                  ...
                  , vr.protocol.rewardScale                                             ...
                  , vr.protocol.rewardScale * 1000*RigParameters.rewardSize             ...
                  );

    % Start/stop movie recording
    case 332    % Numpad *
      if isempty(vrMovieWriter)
        [path,name]   = parsePath(vr.logger.logFile);
        vrMovieFile   = fullfile(path, [name datestr(now, '_yyyymmdd_HHMMSS')]);
        vrMovieWriter = VideoWriter(vrMovieFile, 'MPEG-4');
        vrMovieWriter.FrameRate = 20;   % Human tuned
        open(vrMovieWriter);
        
        console.log('Begin capture of movie in %s%s%s', vrMovieWriter.Path, filesep, vrMovieWriter.Filename);
      else
        close(vrMovieWriter);
        vrMovieFile   = fullfile(vrMovieWriter.Path, vrMovieWriter.Filename);
        console.log('Movie stored in %s%s%s', vrMovieFile);
%         explorer(vrMovieFile);
        vrMovieWriter = [];
      end
      
%     % Toggle display of orientation cues
%     case 259    % Backspace
%       vr.orientationTargets = ~vr.orientationTargets;
%       vr                    = cacheMazeConfig(vr, vr.orientationTargets);
% 
%       if vr.orientationTargets
%         console.log('Distal visual cues will be turned on for orientation');
%       else
%         console.log('Distal visual cues will be turned off');
%       end
      
 case 65 % A 
     rotation_transform = rotation_transform+5*pi/180;
     console.log('rotation_transform now %.2g', rotation_transform*180/pi);
     
 case 90 % Z 
     rotation_transform = rotation_transform-5*pi/180;
     console.log('rotation_transform now %.2g', rotation_transform*180/pi);
     
 case 70 % F 
     if forwardface_flag
         forwardface_flag = 0;
         console.log('Forward Facing off');
     else
         forwardface_flag = 1;
         console.log('Forward Facing on');         
     end
     
     % Debug break
    case 284      % Pause
      keyboard;
      
  end


  if ~isempty(vrMovieWriter)
    frame   = virmenGetFrame(1);
    writeVideo(vrMovieWriter, flipud(frame));
  end

end
