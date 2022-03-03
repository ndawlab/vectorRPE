%% Ensure that stimulus bank exists and is properly configured
function vr = checkStimulusBank(vr, loadMixingInfo)
  
  % Require that file exists
  if ~exist(vr.stimulusBank, 'file')
    errordlg( sprintf('Stimulus bank %s does not exist.', vr.stimulusBank)  ...
            , 'Missing stimulus bank', 'modal'                              ...
            );
    vr.experimentEnded      = true;
    return;
  end
  
  % Record commit tag
  [~,vr.stimulusCommit]     = system(['git log -1 --format="%H" -- ' vr.stimulusBank]);
  
  % Load stimuli
  vr.protocol.log('Loading stimuli bank from %s.', vr.stimulusBank);
  bank                      = load(vr.stimulusBank);
  vr.poissonStimuli         = bank.poissonStimuli;
  vr.stimulusBank           = vr.exper.userdata.regiment.relativePath(vr.stimulusBank);
  
  % Load number of trials info if not explicitly specified
  if loadMixingInfo
    vr.targetNumTrials      = vr.poissonStimuli.targetNTrials;
    vr.trialDuplication     = vr.poissonStimuli.trialDuplication;
    vr.trialDispersion      = vr.poissonStimuli.trialDispersion;
    vr.panSessionTrials     = numel(vr.poissonStimuli.selTrials) - vr.targetNumTrials;
    for var = {'targetNumTrials', 'trialDuplication', 'trialDispersion', 'panSessionTrials'}
      vr.exper.variables.(var{:}) = num2str(vr.(var{:}));
    end
  end
  vr.poissonStimuli.setTrialMixing(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
  vr.protocol.log('Configured %d trials with duplication factor %.3g, mixed with %d pan-session trials from bank.', vr.targetNumTrials, vr.trialDuplication, vr.panSessionTrials);
  
  for iMaze = 1:numel(vr.mazes)
    [~,lCue,stimParameters] = configureMaze(vr, iMaze, iMaze, false, false);

    % Ensure that all mazes have been accounted for in stimulus bank
    if vr.poissonStimuli.configure(lCue, stimParameters{:});
      errordlg( sprintf('Stimuli parameters not configured for maze %d. Use the generatePoissonStimuli() function to pre-generate stimuli.', iMaze) ...
              , 'Stimulus sequences not configured', 'modal'  ...
              );
      vr.experimentEnded    = true;
      return;
    end
  end
  
  % HACK: Force recalculation when behavior starts
  vr.exper.variables.nCueSlots  = '1';

end
