function updateDAQ_cue(vr)


% construct vector of output values
outputVector = [vr.position(1)/100 ... 
                vr.position(2)/100 ...
                mod(vr.position(4),2*pi) ...
                vr.cue];

% cue the data to be sent
putsample(vr.ao,outputVector);
