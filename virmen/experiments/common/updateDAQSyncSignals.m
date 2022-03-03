%% Updates analog output line voltages according to behavioral information that should be sent to a synchronization computer (ClampEx).
%
%   Note that this function is called as part of the user-specified
%   runtimeCodeFun(), which means that in the ViRMEn pipeline it occurs
%   just before the changes made in the current iteration number
%   (vr.iterations) are executed by ViRMEn in terms of display update etc.
%
function updateDAQSyncSignals(data)

  if ~RigParameters.hasSyncComm
    return;
  end

  nidaqI2C('send', data, true, false);
  
end
