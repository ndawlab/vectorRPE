function vr = initializeGradedExperiment(vr)
  
  % Don't execute the rest of the code (which can be slow) if the
  % experiment was aborted for some reason
  if vr.experimentEnded
    return;
  end

  % Make a copy of world configuration to modify
  vr.exper            = copyVirmenObject(vr.exper);

  % State flag for simulation
  vr.mazeChange       = 0;
  vr.state            = BehavioralState.SetupTrial;
  
  % Configure ViRMEn collision detection
  vr.dpResolution     = 0.01;

  % Variables used to impose pauses (after reward, inter-trial etc.)
  vr.waitStart        = [];
  vr.waitTime         = 0;
  vr.soundStart       = [];
  
  % Should the experiment end when the wrong choice is made?
  if isfield(vr.exper.variables, 'enforceSuccess')
    vr.enforceSuccess = eval(vr.exper.variables.enforceSuccess);
  end

  % Reward level as valve opening time (converted to milliseconds)
  vr.rewardMSec       = RigParameters.rewardDuration * 1000;
  vr.rewardFactor     = 1;
  
  % Durations of various pauses
  vr.trialEndPauseDur = eval(vr.exper.variables.trialEndPauseDuration);
  vr.itiCorrectDur    = eval(vr.exper.variables.interTrialCorrectDuration);
  vr.itiWrongDur      = eval(vr.exper.variables.interTrialWrongDuration);

end
