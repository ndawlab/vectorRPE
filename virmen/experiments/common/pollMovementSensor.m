% Send request for the readout to be used in the next iteration
function pollMovementSensor(vr)

  if vr.hasArduino
    % At the first iteration, synchronize Arduino and Virmen clocks
    % inasmuch as possible
%     if vr.iterations == 1
%       arduinoReader('reset');
%     end
    arduinoReader('poll');
  end
  
end
