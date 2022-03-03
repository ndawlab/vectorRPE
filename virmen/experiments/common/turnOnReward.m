function vr = turnOnReward(vr)

  nidaqPulse('on');
  %putvalue(vr.dio.Line(RigParameters.rewardChannel), 1);

end
