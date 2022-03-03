function config = risingTowersConfig(hallWidth, cueInset, theta, avgMouseDyCueUp, avgMouseRunningSpeed)

  % Absolute visual angle in degrees (0 is facing forward) at which cues begin to rise for a forward facing mouse
  if nargin < 3
    theta                 = 20;
  end
  % The proportion of [the distance between [cue beginning to rise] and [cue's position]] at which the cue will be totally up, for the *avg* mouse 
  if nargin < 4
    avgMouseDyCueUp       = 0.9;
  end
  % Speed of an average mouse, in cm/s
  if nargin < 5
    avgMouseRunningSpeed  = 45;
  end
  

  % Ben Deverett's definition (but I don't really understand why he does
  % his computation in a more complicated way)
  theta           = theta * pi/180;
  lateralToCue    = hallWidth/2 - cueInset;
  cueRiseDistance = lateralToCue / tan(theta);
  cueRiseTime     = avgMouseDyCueUp * cueRiseDistance / avgMouseRunningSpeed;

  config          = [cueRiseDistance, cueRiseTime];
  
end
