%% Enumeration constants for identifying optical sensors.
classdef MovementSensor < uint8

  enumeration
    BottomVelocity  (1)
    BottomPosition  (2)
    FrontVelocity   (3)
    ViewAngleLocked (4)
  end
  
  methods (Static)
    
    function num = count()
      num = numel(enumeration('MovementSensor'));
    end
    
  end
  
end
