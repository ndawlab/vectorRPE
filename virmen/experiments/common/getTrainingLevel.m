%% Gets the next maze ID to be run by the animal, given its past history of sessions run and performance levels.
% The trainee.data field should contain performance data for past sessions
% that the animal has run. The expected segmentation is as follows:
%   trainee.data            : per day
%   trainee.data.run        : per run (occurs whenever the experimenter
%                             starts a training session) in the given day
%   trainee.data.run.block  : per block of trials with the same mazeID in
%                             the given run
%
% N.B.:   Currently it is assumed that the animal runs only one session per
%         day, i.e. the presence of multiple entries in trainee.data.run is
%         assumed to be due to technical issues and if a new run is started
%         on the same day, the last maze is resumed.
% N.B.:   This will not behave well for sessions run close to midnight with
%         multiple runs per session.
%
function [mainMazeID, mazeID, warmupIndex, prevPerformance] = getTrainingLevel(mazes, trainee, console, numMazes, doAutoAdvance)

  % Get the maze level achieved in the last session run by the animal,
  % skipping days where no (valid) performance data was taken.
  lastBlock         = [];
  lastDay           = nan;
  warmupIndex       = 0;
  prevPerformance   = nan;
  todaysDate        = TrainingRegiment.dateStamp();
  for iDay = numel(trainee.data):-1:1
    block           = getTrainingBlocks(trainee.data(iDay).run);
    if isempty(block)
      continue;
    end
    
    if isnan(lastDay)
      lastBlock     = block;
      lastDay       = iDay;
    end
    
    % Also get the performance in the previous day's session
    if ~isequal(todaysDate, trainee.data(iDay).date)
      numTrials     = block(end).numTrials(1:size(block(end).performance,1), :);
      prevPerformance = sum(numTrials .* block(end).performance) / sum(numTrials);
      break;
    end
  end
  
  
  % Special case for a naive animal or user override of the main maze to start at
  if trainee.overrideMazeID || isnan(lastDay)
    mainMazeID      = trainee.mainMazeID;
    if mainMazeID > numel(mazes)
      console.log ( 'WARNING:  user-specified main maze %d exceeds the number of mazes (%d), enforcing threshold.'  ...
                  , mainMazeID, numel(mazes)  ...
                  );
      mainMazeID    = numel(mazes);
    end
    
    criteria        = mazes(mainMazeID).criteria;
    if isempty(criteria.warmupMaze)
      mazeID        = mainMazeID;
    else
      warmupIndex   = 1;
      mazeID        = criteria.warmupMaze(warmupIndex);
    end

    if trainee.overrideMazeID
      console.log('User override:  starting animal "%s" on main maze %d.', trainee.name, mainMazeID);
    else
      console.log('Starting new animal "%s" on main maze %d.', trainee.name, mainMazeID);
      if mainMazeID > 1
        prevPerformance = 0.7;    % Assumed performance level for non-naive animals
      end
    end
    
    return;         % Nothing left to do
  
  % Special case for animals that have not achieved the target maze in the
  % last session, in which case it should resume the attempt
  elseif lastBlock(end).mazeID ~= lastBlock(end).mainMazeID
    mainMazeID      = lastBlock(end).mainMazeID;
    if mainMazeID > numel(mazes)
      console.log ( 'WARNING:  previous main maze %d exceeds the number of mazes (%d), enforcing threshold.'  ...
                  , mainMazeID, numel(mazes)  ...
                  );
      mainMazeID    = numel(mazes);
    end
    console.log('Resuming animal "%s" on main maze %d.', trainee.name, mainMazeID);

  % Check if the animal has reached criterion for the last maze that was run
  else
    mainMazeID      = lastBlock(end).mainMazeID;
    if mainMazeID > numel(mazes)
      console.log ( 'WARNING:  previous main maze %d exceeds the number of mazes (%d), enforcing threshold.'  ...
                  , mainMazeID, numel(mazes)  ...
                  );
      mainMazeID    = numel(mazes);
    end
    
    criteria        = mazes(mainMazeID).criteria;
    numPasses       = 0;
    trialTypes      = 1:numel(TrainingRegiment.CHOICES);

    % Don't count data collected in the same day (N.B. doesn't work for
    % multiple sessions)
    if isequal(todaysDate, trainee.data(lastDay).date)
      lastButToday  = lastDay - 1;
    else
      lastButToday  = lastDay;
    end
    
    for iDay = lastButToday:-1:1
      % Ignore if no trials have been run in this session, or fail if the
      % last block run is not in the required maze
      block         = getTrainingBlocks(trainee.data(iDay).run);
      if isempty(block)
        continue;
      end
      if block(end).mazeID ~= mainMazeID
        break;
      end

      % Compute quantities used for advancement criteria
      numTrials     = block(end).numTrials(trialTypes);
      numPerMin     = 60 / block(end).medianTrialDur;
      performance   = sum( numTrials                            ...
                        .* block(end).performance(trialTypes)   ...
                         )                                      ...
                    / sum(numTrials)                            ...
                    ;
      bias          = abs ( block(end).performance(Choice.R)    ...
                          - block(end).performance(Choice.L)    ...
                          );
      if    all(numTrials >= criteria.numTrials/2)              ...
        &&  numPerMin     >= criteria.numTrialsPerMin           ...
        &&  performance   >= criteria.performance               ...
        &&  bias          <  criteria.maxBias
        numPasses   = numPasses + 1;
        if numPasses >= criteria.numSessions
          break;
        end
      else
        break;
      end
    end
  
    % Special case to retain last training level
    if ~doAutoAdvance
      console.log('No automatic advancement:  resuming animal "%s" on main maze %d.', trainee.name, mainMazeID);
      
    % If the desired number of consecutive sessions has been achieved,
    % advance the animal to the next maze (if any)
    elseif numPasses < max(criteria.numSessions, 1)
      console.log('Resuming animal "%s" on maze %d.', trainee.name, mainMazeID);

    elseif mainMazeID < numMazes
      mainMazeID    = mainMazeID + 1;
      console.log('Advancing animal "%s" to maze %d.', trainee.name, mainMazeID);

    else
      console.log('Animal "%s" has achieved criteria for the last maze %d!', trainee.name, mainMazeID);
    end
  end

  
  %-------------------------------------------------------------------------------------------------
  % Determine the maze to run based on whether there are warmup trials
  criteria          = mazes(mainMazeID).criteria;
  
  % Special case for resuming a session started on the same day
  if isequal(todaysDate, trainee.data(lastDay).date)
    mazeID          = trainee.data(lastDay).run(end).block(end).mazeID;
    if mazeID ~= mainMazeID
      warmupIndex   = find(criteria.warmupMaze == mazeID, 1, 'first');
      % Force the maze to be either a warmup maze or the main maze
      if isempty(warmupIndex)
        warning('getTrainingLevel:sanity', 'The animal has previously run maze %d which is not part of the warmup sequence for maze %d.', mazeID, mainMazeID);
        mazeID      = mainMazeID;
        warmupIndex = 0;
      end
    end
    console.log('Continuing animal "%s" on maze %d for today''s session.', trainee.name, mainMazeID);
  
  % If there are warmup mazes, start at the first
  elseif ~isempty(criteria.warmupMaze)
    warmupIndex     = 1;
    mazeID          = criteria.warmupMaze(warmupIndex);
    console.log('Starting with warmup maze %d.', mazeID);
    
  % Otherwise start at the main maze
  else
    mazeID          = mainMazeID;
  end
  
end

%%
function block = getTrainingBlocks(run)

  block     = [];
  if isempty(run)
    return;
  end
  
  for iRun = 1:numel(run)
    if ~run.isActive
      continue;
    end
      
    for iBlock = 1:numel(run(iRun).block)
      if ~run(iRun).block(iBlock).isActive
        continue;
      end
      
      if isempty(block)
        block         = run(iRun).block(iBlock);
      else
        block(end+1)  = run(iRun).block(iBlock);
      end
    end
  end

end
