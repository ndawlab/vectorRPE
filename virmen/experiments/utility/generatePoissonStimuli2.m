%% GENERATEPOISSONSTIMULI(experimentPath)
%
% example:
% generatePoissonStimuli2('poisson_blocks.mat',@PoissonBlocksC3_nocues)
%
%   Pre-generates a bank of Poisson stimulus trains for the given
%   experiment configuration. experimentPath should be the ViRMEn .mat file
%   that contains the world configuration. An absolute path is not required
%   if it is in the Matlab path.
%
%   This function returns the stimulus bank, which should be saved in a
%   .mat file of your choice. Note that your experiment code should be
%   configured to load the appropriate object depending on how you named
%   it; in poisson_towers.m the bank is called 'poissonStimuli'.
%
%   Note that for this code to work, it is assumed that you have added 
%       code.setup = @setupTrials;
%   to the main function in your experiment's .m file, where setupTrials()
%   is the function that calls prepareMazes() and so forth to set up
%   parameters for each maze difficulty level. See poisson_towers.m for 
%   example usage.
%
function stimuli = generatePoissonStimuli2(experimentPath, protocol)

  % Load experiment and maze configuration
  vr        = load(experimentPath);
  code      = vr.exper.experimentCode();
  if nargin > 1
    vr      = code.setup(vr, protocol);
    info    = functions(protocol);
    target  = fullfile(parsePath(info.file), ['stimulus_trains_' func2str(protocol) '.mat']);
    
    if exist(target, 'file')
      fprintf('WARNING:  Target %s already exists!\n', target);
    end
  else
    vr      = code.setup(vr);
  end
  
  % Configure stimuli for all maze levels
  stimuli   = vr.stimulusGenerator(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
  for mainMaze = 1:numel(vr.mazes)
    mazeID  = [mainMaze, vr.mazes(mainMaze).criteria.warmupMaze];
    for iMaze = mazeID
      [~,lCue,params] = configureMaze(vr, iMaze, mainMaze, false);
      stimuli.configure(lCue, params{:});
    end
  end
  
%   Write to disk if so desired
%   if nargin > 1
%     fprintf('This should be saved to:\n   %s\n', target);
%     yes     = input('Proceed (y/n)?  ', 's');
%     if strcmpi(yes, 'y')
%       poissonStimuli  = stimuli;
%       save(target, 'poissonStimuli');
%       fprintf('Done.\n');
%     else
%       fprintf('Aborted.\n');
%     end
%   end
  fprintf("saving stimuli as %s", target)
  poissonStimuli  = stimuli;
  save(target, 'poissonStimuli');
  
end
