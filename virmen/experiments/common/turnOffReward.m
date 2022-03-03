function vr = turnOffReward(vr)

  nidaqPulse('off');
  %putvalue(vr.dio.Line(RigParameters.rewardChannel), 0);

end
