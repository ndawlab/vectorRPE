%% A reward opens the valve for a timed duration (specified in ms) with millisecond precision
function deliverReward(vr, duration)

  nidaqPulse('ttl', duration);

%   turnOnReward(vr);
%   java.lang.Thread.sleep(duration);
%   turnOffReward(vr);

end

