function updateDAQ_backVR(vr)

% construct vector of output values
outputVector = [vr.cue, mod(vr.position(4),2*pi), vr.position(1)/100, vr.position(2)/100];

% cue the data to be sent
putsample(vr.ao, outputVector);

end
