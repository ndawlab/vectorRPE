classdef RigParameters

  properties (Constant)
    
    rig                 = 'Bezos2'
    simulationMode      = true             % true to run in simulation mode with human input via keyboard
    hasDAQ              = false              % false for testing on laptop
    hasSyncComm         = false             % true if digital communications should be used for synchronization (ScanImage)
    minIterationDT      = 0.01              % Minimum expected ViRMEn frame rate in seconds
    hasLickMeter        = false
    
    arduinoPort         = 'COM10'           % Arduino port as seen in the Windows Device Manager
    sensorDotsPerRev    = 100
    ballCircumference   = 63.8              % in cm
    
    toroidXFormP1       = 0.4458            % p1 parameter (slope) from poly1 fit of toroidal screen transformation
    toroidXFormP2       = 0.4331            % p2 parameter (offset) from poly1 fit of toroidal screen transformation
    colorAdjustment     = [0; 0.6; 0.7]     % [R; G; B] scale factor for projector display
    soundAdjustment     = 0.2               % Scale factor for sound volume
% 
%     nidaqDevice         = 1                 % NI-DAQ device identifier 
%     nidaqPort           = 0                 % NI-DAQ port number
%     syncClockChannel    = 5                 % NI-DAQ digital line for I2C clock signal
%     syncDataChannel     = 6                 % NI-DAQ digital line for I2C data signal
%     
    rewardChannel       = 1                 % NI-DAQ digital line for turning on/off the solenoid valve
    rewardSize          = 4/1000            % in mL
    rewardDuration      = 0.06              % Valve opening duration (in seconds) for 4uL reward
    
  end
  
  methods (Static, Access = protected)
    
    function dotsPerRev = sensorCalibration()
      % Sensor dots per ball revolution, obtained using the calibrateBall script
      
      dotsPerRev        = nan(1, MovementSensor.count());
      dotsPerRev(MovementSensor.FrontVelocity)  = 23101/10;
      dotsPerRev(MovementSensor.BottomVelocity) = 23101/10;
      dotsPerRev(MovementSensor.BottomPosition) = dotsPerRev(MovementSensor.BottomVelocity);
      
      if any(isnan(dotsPerRev))
        error('RigParameters:sensorCalibration', 'Some sensor calibration data was not specified, please correct this.');
      end
      
    end
    
  end
  
end
