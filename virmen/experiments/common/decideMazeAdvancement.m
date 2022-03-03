%% Gets the next maze ID to be run by the animal, given its past history of sessions run and performance levels.
function [vr, mazeChanged] = decideMazeAdvancement(vr, numMazes)
  
  % Default to the total number of available mazes
  if nargin < 2
    numMazes                = numel(vr.mazes);
  end
  

  % Special case for user override
  criteria                  = vr.mazes(vr.mainMazeID).criteria;
  if vr.mazeChange ~= 0
    mazeChanged             = true;
    vr.mazeID               = vr.mazeID + vr.mazeChange;
    vr.mazeChange           = 0;
    
    % If the new maze is part of the warmup sequence, adjust the stored
    % index to match, otherwise treat it as setting the main maze
    vr.warmupIndex          = find(criteria.warmupMaze == vr.mazeID, 1, 'first');
    if isempty(vr.warmupIndex)
      vr.warmupIndex        = 0;
      vr.mainMazeID         = vr.mazeID;
    end

    vr.protocol.log('User enforced maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);
    return;
  end
  
  

  % Obtain performance criteria from online tally
  mazeChanged               = false;
  [performance, bias, goodFraction, numTrials, numPerMin]                 ...
                            = vr.protocol.getStatistics();
  
  % Special case for first trial
  if vr.iterations < 2
    mazeChanged             = true;
                          
  % If running a main maze, check for advancement or demotion
  elseif vr.warmupIndex < 1
    % Within-session advancement
    if      criteria.numSessions < 1                                      ...
        &&  ~isempty(numTrials)                                           ...
        &&  all(numTrials   >= criteria.numTrials/2)                      ...
        &&  numPerMin       >= criteria.numTrialsPerMin                   ...
        &&  performance     >= criteria.performance                       ...
        &&  bias            <  criteria.maxBias                           ...
        &&  vr.mainMazeID   <  numMazes
      mazeChanged           = true;
      vr.mainMazeID         = vr.mainMazeID + 1;
      criteria              = vr.mazes(vr.mainMazeID).criteria;
      if isempty(criteria.warmupMaze)
        vr.warmupIndex      = 0;
        vr.mazeID           = vr.mainMazeID;
      else
        vr.warmupIndex      = 1;
        vr.mazeID           = criteria.warmupMaze(vr.warmupIndex);
      end
      vr.protocol.log('Advanced to maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);

    %{
    *** NOT USEFUL ***
      
    % Demotion to easier maze
    elseif  ~isempty(criteria.demoteBlockSize)                            ...
        &&  all(numTrials(:) > criteria.demoteBlockSize/2)                ...
        &&  issorted(performance)                                         ...
        &&( performance(1)  <  criteria.demotePerform                     ...
        ||  bias(1)         >= criteria.demoteBias                        ...
          )
      mazeChanged           = true;
      vr.mazeID             = vr.mazeID - 1;
      vr.warmupIndex        = 0;
      vr.protocol.log('Demoted to maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);
    %}
    end
    
  % If running a warmup maze, check for advancement to a second warmup or
  % to the main maze
  elseif    ~isempty(numTrials)                                           ...
        &&  all(numTrials   >= criteria.warmupNTrials(vr.warmupIndex)/2)  ...
        &&  performance     >= criteria.warmupPerform(vr.warmupIndex)     ...
        &&  bias            <  criteria.warmupBias(vr.warmupIndex)        ...
        &&  goodFraction    >= criteria.warmupMotor(vr.warmupIndex)
      mazeChanged           = true;
      vr.warmupIndex        = vr.warmupIndex + 1;
  
    if vr.warmupIndex > numel(criteria.warmupMaze)
      vr.mazeID             = vr.mainMazeID;
      vr.warmupIndex        = 0;
      vr.protocol.log('Done with warmup, running main maze %d', vr.mazeID);
    else
      vr.mazeID             = criteria.warmupMaze(vr.warmupIndex);
      vr.protocol.log('Running warmup maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);
    end
  end

end
