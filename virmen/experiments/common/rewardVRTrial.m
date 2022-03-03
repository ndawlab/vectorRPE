function vr = rewardVRTrial(vr, rewardFactor, doEndTrial)

  % Compute reward duration
  if nargin > 1
    rewardMSec  = rewardFactor * vr.rewardMSec;
  else
    rewardMSec  = vr.rewardMSec;
  end

  if RigParameters.hasDAQ
    deliverReward(vr, rewardMSec);
  end

  % Reward duration needs to be converted to seconds
  if nargin < 3 || doEndTrial
    vr.waitTime = 0; % vr.trialEndPauseDur - rewardMSec/1000;
    vr.state    = BehavioralState.EndOfTrial;
  end
  
end
