function plotMazeDifficulty(stimulusBank, protocol, mazeIDs)

  % Load
  load(stimulusBank);
  stimuli                         = poissonStimuli;
  stimuli.setTrialMixing(5000, 1, 1);
  [mazes, ~, globalSettings, vr]  = protocol(struct());
  
  % Figures
  deltaBins                       = linspace(0, 1.2, 13);
  axs                             = axes( 'Parent'          , figure          ...
                                        , 'Color'           , 'none'          ...
                                        );
  colors                          = othercolor('Mrainbow', numel(mazeIDs));
  hold(axs, 'on');
  xlabel(axs, '\Delta / N');
  ylabel(axs, 'Frequency');
  
  % Maze difficulties
  defaults                        = cell2struct(globalSettings(2:2:end), globalSettings(1:2:end), 2);
  defaults.panSessionTrials       = 0;
  for iMaze = 1:numel(mazeIDs)
    settings                      = mergestruct(defaults, mazes(mazeIDs(iMaze)));
    settings.nCueSlots            = settings.lCue/settings.cueMinSeparation;
    
    stimParameters                = cell(size(vr.stimulusParameters));
    for iParam = 1:numel(vr.stimulusParameters)
      stimParameters{iParam}      = settings.(vr.stimulusParameters{iParam});
    end
    stimuli.configure(settings.lCue, stimParameters{:});
    
    delta                         = nan(1, stimuli.targetNTrials);
    for iTrial = 1:stimuli.targetNTrials
      trial                       = stimuli.nextTrial();
      delta(iTrial)               = (trial.nSalient - trial.nDistract) / (trial.nSalient + trial.nDistract);
    end
    
    deltaProb                     = histcounts(delta, deltaBins, 'Normalization', 'probability');
    line( 'Parent'            , axs                     ...
        , 'XData'             , deltaBins(1:end-1)      ...
        , 'YData'             , deltaProb               ...
        , 'LineWidth'         , 1                       ...
        , 'Color'             , colors(iMaze,:)         ...
        );
  end
  
  % Formatting
  legend(axs, arrayfun(@(x) sprintf('T%d',x), mazeIDs, 'UniformOutput', false), 'Location', 'NorthWest');

end
