function updateDAQ(vr)


% construct vector of output values
outputVector = [vr.position(1)/100 ... 
                vr.position(2)/100 ...
                mod(vr.position(4),2*pi) ...
                vr.odor];

% cue the data to be sent
putsample(vr.ao,outputVector);
