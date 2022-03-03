 function vr = judgeVRTrial(vr, alwaysSuccess, freezeMovement)

  if nargin < 2
    alwaysSuccess   = false;
  end
%   if nargin < 3
%     freezeMovement  = true;
%   end


  % Freeze movement for a set amount of time
%   if freezeMovement
%     vr              = freezeArduino(vr);
%   end
% rachel: turning this off

  % there shouldn't be a difference for rew vs non-reward. rachel taking
  % the if/then statement out  
  vr.state        = BehavioralState.EndOfTrial;
  % If the correct choice has been made, enter reward state
%   if vr.choice == vr.trialType || alwaysSuccess
%     vr.state        = BehavioralState.DuringReward;
%     vr.rewardFactor = vr.protocol.rewardScale;
% 
% 
% 
%   % Otherwise deliver aversive stimulus and a longer time-out period
%   else
% %     if isfield(vr, 'punishment')
% %       play(vr.punishment.player);
% %     end
% 
%     vr.state        = BehavioralState.EndOfTrial;
%     vr.rewardFactor = 0;
%     vr.waitTime     = 0; %changed this from the punishment wait time
%   end

end
