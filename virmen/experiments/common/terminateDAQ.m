function terminateDAQ(vr)

  if RigParameters.hasDAQ
    nidaqPulse('end');
  end
  if RigParameters.hasSyncComm
      nidaqI2C('end');
  end
  
  % Lickometer
  if RigParameters.hasLickMeter
      terminateLickAcq();
  end
  
end
