%% Loads a sound file and computes its duration
function sound = loadSound(wavFile, durationFactor, amplitudeFactor)

  if nargin < 2
    durationFactor    = 1;
  end
  if nargin < 3
    amplitudeFactor   = 1;
  end

  [sound.y, sound.Fs] = audioread(wavFile);
  sound.y             = amplitudeFactor .* sound.y;
  sound.duration      = durationFactor * numel(sound.y) / sound.Fs;
  sound.player        = audioplayer(sound.y, sound.Fs);

end
