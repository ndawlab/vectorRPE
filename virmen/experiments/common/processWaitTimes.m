%% Standard handling of waiting periods (inter trial intervals etc.) in a ViRMen experiment.
function [waitStart, waitTime] = processWaitTimes(waitStart, waitTime)

  if waitTime > 0

    if isempty(waitStart)
      % Start of a wait period, begin timer
      waitStart   = tic;

    elseif toc(waitStart) >= waitTime
      % Done waiting, reset and proceed with normal operations
      waitStart   = [];
      waitTime    = 0;
    end
    
  elseif waitTime < 0
    % No need to wait, reset and proceed with normal operations
    waitStart     = [];
    waitTime      = 0;
    
  end
  
end
