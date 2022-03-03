function vr = initializeDAQ(vr)

  % Reset DAQ in case it is still in use
  daqreset;

  % Digital input/output lines used for reward delivery etc.
  if RigParameters.hasDAQ
    nidaqPulse('end');
    nidaqPulse('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.rewardChannel);
  end

  % ScanImage synchronization
  if RigParameters.hasSyncComm
    nidaqI2C('end');
    nidaqI2C('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.syncClockChannel, RigParameters.syncDataChannel);
  end

  % Lickometer
  if RigParameters.hasLickMeter
      initLickAcq();
  end
  
end
