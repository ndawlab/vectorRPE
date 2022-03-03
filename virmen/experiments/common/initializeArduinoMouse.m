%% Initialization code for optical sensor + Arduino + MouseReader_2sensors class setup.
%
%   This code initializes a MouseReader_2sensors object to be stored in the ViRMEn vr struct, which
%   will then be used at each behavioral iteration to communicate with the Arduino.
%
%   Several rig-dependent quantities like calibration constants are stored in the RigParameters
%   class. The following arguments are accepted by this function:
%
%     virmenDisplacementPerCm   : Number of virtual world units per centimeter travel in the real
%                                 world. This is typically set to 1.
%     virmenRotationsPerRev     : Number if virtual world angular rotations per revolution of the
%                                 ball in the real world. This is typically set to a low gain (e.g.
%                                 1/2.5) for a sensor positioned along the anterior-posterior axis
%                                 of the mouse. For a sensor positioned at the bottom of the ball
%                                 (ventral to the mouse) this can be set to 1 (linear gain) or nan
%                                 for exponential gain (see moveArduinoLinearVelocity.m for a more
%                                 thorough explanation).
%     virmenSensor              : Which sensor to use for controlling motion in the virtual world;
%                                 should be one of the MovementSensor enumerations e.g.
%                                 MovementSensor.BottomVelocity.
%
function vr = initializeArduinoMouse(vr, virmenDisplacementPerCm, virmenRotationsPerRev, virmenSensor)

  % initialize mouse communications via Arduino 
  vr.mr           = MouseReader_2sensors(RigParameters.arduinoPort);
  
  % Scale factors for various components of velocity
  dotsPerRev      = RigParameters.sensorDotsPerRev(virmenSensor);
  vr.scaleX       = virmenDisplacementPerCm * RigParameters.ballCircumference / dotsPerRev;
  vr.scaleY       = virmenDisplacementPerCm * RigParameters.ballCircumference / dotsPerRev;
  if virmenSensor >= MovementSensor.FrontVelocity
    vr.scaleA     = virmenRotationsPerRev   * 2*pi                            / dotsPerRev;
  else
    vr.scaleA     = virmenRotationsPerRev;
  end
  
end
