function updateDAQsync(vr)

% scale down maze index so as to fit output voltage range
mazeID    = vr.currentMaze / 10;
% convert trial type (L/R) to a sign
% TODO TODO TODO -- this does not work for more than two choices!!!
midID     = floor(numel(vr.protocol.CHOICES) / 2);
if vr.trialType > midID
  trialID = double(vr.trialType) - midID;
else
  trialID = -(double(vr.trialType) - midID) - 1;
end


% construct vector of output values
outputVector = [ vr.position(1)/100         ... 
               , vr.position(2)/100         ...
               , angleMPiPi(vr.position(4)) ...
               , trialID * mazeID           ...
               ];

% cue the data to be sent
putsample(vr.ao,outputVector);
