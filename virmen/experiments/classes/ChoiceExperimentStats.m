classdef ChoiceExperimentStats < handle

  %------- Constants
  properties (Constant)
    MIN_PROBABILITY   = 0.15                % Rectification for probability of drawing a trial of a given type
    PAST_RANGE        = 3                   % Number of standard deviations to consider items in the past
    ERR_INTERVAL      = 1 - (normcdf(1, 0, 1) - normcdf(-1, 0, 1))
    
    CHOICES           = Choice.all()        % All available choices
    NUM_CHOICES       = numel(ChoiceExperimentStats.CHOICES)
    CHOICE_LINES      = {'--','-','-','-'}  % Line styles for the corresponding Choice
    MARKERS           = {'<','>' ,'' ,'' }  % Marker styles for the corresponding Choice
    CHOICE_COLOR      = [ 0   0   1     ...   L
                        ; 1   0   0     ...   R
                        ; 0   0   0     ...   current
                        ]
    AVG_COLOR         = [ 0   0   0     ...   Average over all trial types
                        ; 0   123 255   ...   Weighted average
                        ] / 255
    CRIT_LINES        = {'-','--','-.'}     % Line styles for [performance, bias, quality]
    CRIT_MARKER       = {'o','s' ,'d' }     % Marker styles for [performance, bias, quality]
    CRIT_COLOR        = [ 0   123 255   ...   Performance
                        ; 255 166 0     ...   Bias
                        ; 86  214 0     ...   Quality
                        ] / 255
    NOWEIGHT_COLOR    = [ 1 1 1 ]*0.7       % Zero weight trials
    VIOLATION_MARKER  = 'o'                 % Violation trials
    VIOLATION_COLOR   = [ 1 0 0 ]           % Violation trials
    METRIC_MARKER     = 's'                 % Psychometric points
                      
    MARKER_SIZE       = 4
    FONT_SIZE         = 11

    EXP_SMOOTHING     = 0.05;
    
    MAZE_FINEBIN      = 10                  % cm
    MAZE_BIN          = 50                  % cm
    SPEED_BIN         = 4                   % cm/s
    FREQ_NBINS        = 41
    FREQ_SCALE        = 1.5
    MAZE_RANGE        = [0 50]              % cm
    SPEED_RANGE       = [0 125]             % cm/s
    ROTVEL_RANGE      = [-0.25 0.25]        % rev/s
    ANGLE_RANGE       = [-80 80]            % degrees
    
    RGX_FILE          = '(?<=^|[ ''"])([-\w]*[:\\/][-\w\\/\.]*)'
  end
  
  %------- Private data
  properties (Access = protected)
    mazeColor         % Color spectrum for the corresponding maze ID
    mazePrev          % Color spectrum for the previous maze ID
    mazeBkg           % Background color spectrum for the corresponding maze ID
    
    plotWindow  = []  % Figure for informative display
    plotAxes          % Axes for online performance plots
    plotMetric        % Axes for psychometric plots
    plotMotion        % Axes for online motion plots
    btnStop           % Button for ending the experiment
    lstLog            % Display for informative log as entered via log()
    hMazeID           % Blocks indicating maze level
    textMazeID        % Text indicating maze level
    hFracCorrect      % Plots for success rate vs. trial type
    hNoWeight         % Plots for zero weight trials
    hViolation        % Plots for violation trials
    hCriteria         % Plots for advancement criteria
    hTrialProb        % Plots for probabilities used to draw trials
    hMetric           % Plots for psychometrics
    hMetricErr        % Errorbars for psychometrics
    hSpeed            % Plots for animal's speed
    hRotation         % Plots for animal's rotational velocity
    hViewAngle        % Plots for animal's view angle
    txtAnimal         % Label for animal name display
    txtLabel          % Labels for info display fields
    txtTrialStart     % Display for time at which current trial was started
    txtTrialDur       % Display for how long the current trial has been running
    txtTrialMed       % Display for the median trial duration
    txtRunDur         % Display for how long the experiment has been running
    txtRewarded       % Display for total amount of rewards received
    
    startTic          % tic for start of first trial
    trialTic          % tic for start of current trial
    trialElapsed      % seconds elapsed for current trial
    runElapsed        % seconds elapsed for current run
    
    pseudorandoms     % Pseudo-random sequence for more uniform distribution of choices
    weightPast        % Weighting factor of decisions in the past
  end
  
  %------- Public data
  properties (SetAccess = protected)
    animal            % Information about animal
    totalTrials       % Total number of requested trials
    totalMazes        % Total number of maze IDs
    currentSection    % Index of the last reset point (due to maze changes) of statistics
    currentTrial      % Index of the current trial
    mazeLabel         % Short label to identify the maze type
    mazeID            % Which maze configuration
    
    startTime         % Start time of first trial
    trialTime         % Start time of current trial
    endExperiment     % Whether or not the experiment should be ended as per user request
    totalRewards      % Total accumulated rewards so far
    drawMethod        % Acceptable methods for drawing trials
    drawIndex         % Currently selected method for drawing trials
    rewardScale       % Currently applied scale on rewards
    logText           % List of lines logged

    ascDuration       % Duration of trials in ascending order, including inter-trial intervals
    sumTrialLength    % Sum length of trials of the indexed type, not including inter-trial intervals
    sumOfType         % Total number of trials of the indexed type throughout this session
    
    %===== Indexed by trial (1 = start of run) =====================================================
    trialType         % Type of trial i.e. which is the correct choice
    trialChoice       % Choice made by the animal
    trialProb         % Probability used to draw choices for various trials
    trialWeight       % Weight of the indexed trial of the given type, as given to recordChoice()
    trialNCues        % Number of cues of various types in the given trial
    isCorrect         % True if the correct choice was made in the indexed trial
    isGood            % True if the indexed trial passed user-specified quality criteria

    %===== Cumulative and reset whenever maze ID changes ===========================================
    typeIndex         % List of indices of trials of the given type

    numTrials         % Number of trials of the indexed type
    numCorrect        % Number of correct trials of the given type
    numGood           % True if the trial of the given type passes user-defined quality criteria
    
    wgtTrials         % Sum weight of trials of the indexed type
    wgtCorrect        % Weighted count of correct trials
    wgtGood           % Weighted count of trials passing user-defined quality criteria

    consecCorrect     % Number of correct trials up to and including the indexed one
    consecWrong       % Number of wrong trials up to and including the indexed one

    %===== Moving averages for advancement criteria ================================================
    movingLabel       % Descriptive label for moving averages
    movingStart       % Lower bound (inclusive) of trials used for moving average
    movingNTrials     % Number of (weighted) trials tabulated in moving averages
    movingWeighted    % Whether or not to compute a weighted average (as opposed to weight = 1)
    movingTrialW      % History of sum weights of trials for moving average
    movingPerform     % History of sum weights of correct trials for moving average
    movingGood        % History of sum weights of good quality trials for moving average

    %===== Pyschometric plot configuration =========================================================
    deltaBins         % Bin edges for difference in number of R - L cues
  end

  %________________________________________________________________________
  methods
    %----- Constructor
    function obj = ChoiceExperimentStats(animal, mazeLabel, totalTrials, totalMazes, deltaBins, historyRange, nPseudorand)
      
      obj.trialElapsed  = nan;
      obj.runElapsed    = nan;
      
      obj.animal        = animal;
      obj.totalTrials   = totalTrials;
      obj.totalMazes    = totalMazes;
      obj.currentSection= 0;
      obj.currentTrial  = 0;
      obj.mazeLabel     = mazeLabel;
      obj.mazeID        = zeros(1, totalTrials);
      obj.startTime     = [];
      obj.trialTime     = [];
      obj.endExperiment = false;
      obj.totalRewards  = 0;

      obj.trialType     = repmat(Choice.nil, 1, totalTrials);
      obj.trialChoice   = repmat(Choice.nil, 1, totalTrials);
      obj.trialProb     = nan(obj.NUM_CHOICES, totalTrials);
      obj.trialWeight   = zeros(obj.NUM_CHOICES, totalTrials);
      obj.trialNCues    = nan(obj.NUM_CHOICES, totalTrials);
      obj.isCorrect     = false(obj.NUM_CHOICES, totalTrials);
      obj.isGood        = false(obj.NUM_CHOICES, totalTrials);

      obj.typeIndex     = cell(obj.NUM_CHOICES, 1);
      obj.ascDuration   = [];
      obj.sumTrialLength= zeros(obj.NUM_CHOICES, 1);
      obj.sumOfType     = zeros(obj.NUM_CHOICES, 1);
      obj.numTrials     = zeros(obj.NUM_CHOICES, totalTrials);
      obj.numCorrect    = zeros(obj.NUM_CHOICES, totalTrials);
      obj.numGood       = zeros(obj.NUM_CHOICES, totalTrials);
      obj.wgtTrials     = zeros(obj.NUM_CHOICES, totalTrials);
      obj.wgtCorrect    = zeros(obj.NUM_CHOICES, totalTrials);
      obj.wgtGood       = zeros(obj.NUM_CHOICES, totalTrials);
      obj.consecCorrect = zeros(obj.NUM_CHOICES, totalTrials);
      obj.consecWrong   = zeros(obj.NUM_CHOICES, totalTrials);
      
      obj.hCriteria     = gobjects(0);
      obj.hMetric       = gobjects(0);
      obj.hMetricErr    = gobjects(0);
      
      % Factor by which to weight trials in recent history
      if nargin < 6
        historyRange    = 20;
      end
      obj.weightPast    = normpdf(-obj.PAST_RANGE * historyRange:0, 0, historyRange);

      % Pseudo-random sequence for more uniform distribution of choices
      if nargin < 7
        nPseudorand     = 1000;
      end
      obj.pseudorandoms = repmat(obj.CHOICES, 1, floor(totalTrials / obj.NUM_CHOICES));
      disp('mixing trials') 
      tic
      for iBlock = 1:nPseudorand:numel(obj.pseudorandoms) - nPseudorand + 1
        block           = iBlock:iBlock + nPseudorand - 1;
        subset          = obj.pseudorandoms(block);
        obj.pseudorandoms(block)  = subset(randperm(nPseudorand));

        
        
      end
      toc
      obj.pseudorandoms = [obj.pseudorandoms, randi([1 obj.NUM_CHOICES], 1, totalTrials - numel(obj.pseudorandoms))];
      
      % Trial drawing methods and reward level
      obj.drawMethod    = {};
      obj.drawIndex     = 1;
      obj.rewardScale   = 1;
      obj.logText       = {};
      
      % Moving averages for advancement criteria (user requested)
      obj.movingLabel   = {};
      obj.movingStart   = nan(1, obj.totalTrials);
      obj.movingNTrials = [];
      obj.movingWeighted= [];
      obj.movingTrialW  = zeros(obj.NUM_CHOICES, obj.totalTrials);
      obj.movingPerform = zeros(obj.NUM_CHOICES, obj.totalTrials);
      obj.movingGood    = zeros(obj.NUM_CHOICES, obj.totalTrials);
      
      % Pyschometric plots
      if nargin < 5
        obj.deltaBins   = uniformBinsAround(9, 0, 3);
      else
        obj.deltaBins   = rowvec(deltaBins);
      end
    end
    
    %----- Stops various displays/controls
    function stop(obj)
      
      if ~isempty(obj.plotWindow)
        set(obj.plotWindow, 'CloseRequestFcn' , 'closereq');
        delete(obj.btnStop);
        obj.btnStop     = [];
      end
      
    end
    
    %----- Conversions
    function choice = Choice(obj)
      choice  = obj.trialType(obj.currentTrial);
    end
    
    %----- Update duration displays
    function update(obj)
      
      if isempty(obj.plotWindow)
        return;
      end
      
      if ~isempty(obj.trialTic)
        trialElapsed      = round(toc(obj.trialTic));
        if trialElapsed ~= obj.trialElapsed
          obj.trialElapsed  = trialElapsed;
          set(obj.txtTrialDur, 'String', seconds2str(trialElapsed, false, '(%02d:%02d)'));
        end
      end
      
    end
    
    %----- Update run/trial information display
    function updateRun(obj, position, velocity, rotationalVelocity)
      
      if isempty(obj.plotWindow)
        return;
      end

      obj.runElapsed    = round(toc(obj.startTic));
      set(obj.txtRunDur, 'String', seconds2str(obj.runElapsed));
      
      if nargin < 2
        return;
      end
      
      % Update speed and view angle displays
      refPos            = position(:,2);
      set(obj.hSpeed(end)     , 'XData', refPos, 'YData', [sqrt(sum(velocity(1:end-1,1:2).^2, 2)); nan]);
      set(obj.hRotation(end)  , 'YData', refPos, 'XData', [rotationalVelocity(1:end-1) / (2*pi); nan]);
      set(obj.hViewAngle(end) , 'YData', refPos, 'XData', [position(1:end-1,end); nan] * 180/pi);
      
    end
      
    %----- Update reward display
    function updateReward(obj)
      
      if isempty(obj.plotWindow)
        return;
      end

      set(obj.txtRewarded, 'String', sprintf( '%.2f mL (%.2g uL x %.2g)'      ...
                                            , obj.totalRewards                ...
                                            , RigParameters.rewardSize*1000   ...
                                            , obj.rewardScale                 ...
                                            ));
                                          
    end
    
    %----- Add a trial drawing method to the list, by name (string)
    function addDrawMethod(obj, varargin)
      if numel(varargin) == 1 && iscell(varargin)
        varargin  = varargin{1};
      end
      obj.drawMethod(end+1:end+numel(varargin)) = varargin;
    end
    
    %----- Switch to the next drawing method in the list, or cycle back to start
    function nextDrawMethod(obj)
      obj.drawIndex         = obj.drawIndex + 1;
      if obj.drawIndex > numel(obj.drawMethod)
        obj.drawIndex       = 1;
      end
      obj.log('Next trials will be drawn via %s.', obj.drawMethod{obj.drawIndex});
    end
    
    %----- Sets the current trial drawing method by name (string)
    function setDrawMethod(obj, methodName)
      obj.drawIndex         = find(strcmp(obj.drawMethod, methodName));
      if isempty(obj.drawIndex)
        error ( 'ChoiceExperimentStats:setDrawMethod'             ...
              , 'Invalid draw method "%s", must be one of: %s'    ...
              , methodName, strjoin(obj.drawMethod, ' OR ')       ...
              );
      end
      obj.log('Trials will be drawn via %s.', obj.drawMethod{obj.drawIndex});
    end
    
    %----- Draw a trial using the currently selected method in the list
    function [success, probability] = drawTrial(obj, maze, mazeRange, varargin)
      
      % Update plots based on previous trial info
      if ~isempty(obj.plotWindow)
        if nargin > 2
          mazeRange   = ChoiceExperimentStats.extendHistogram2D(obj.hSpeed(1), mazeRange, obj.MAZE_FINEBIN);
%           ChoiceExperimentStats.extendHistogram1D([obj.hRotation(1:end-1) obj.hViewAngle(1:end-1)], mazeRange, obj.MAZE_BIN);
%           
%           set(obj.plotMotion(1)    , 'XLim', mazeRange);
%           set(obj.plotMotion(2:end), 'YLim', mazeRange);
        end
%         rachel: taking this out. it's breaking my code
        if      obj.currentTrial > 0                          ...
            &&  obj.currentTrial <= numel(obj.trialChoice)    ...
            && obj.trialChoice(obj.currentTrial) <= ChoiceExperimentStats.NUM_CHOICES
%           count       = ChoiceExperimentStats.compileData2D(obj.hSpeed(end), obj.hSpeed(1));
%           ChoiceExperimentStats.compileData1D(obj.hRotation(end) , obj.hRotation(obj.trialChoice(obj.currentTrial)) , count);
%           ChoiceExperimentStats.compileData1D(obj.hViewAngle(end), obj.hViewAngle(obj.trialChoice(obj.currentTrial)), count);
        end
      end

      % Draw a new trial
      if isempty(obj.drawMethod)
        obj.drawMethod{end+1} = 'pseudorandomTrial';
        obj.drawIndex         = 1;
        obj.log('Defaulting to trials drawn via %s', obj.drawMethod{obj.drawIndex});
      end
      
      
      [success, probability]  = obj.(obj.drawMethod{obj.drawIndex})(maze, varargin{:});

    end
      
    
    %----- Manual addition of a trial of a given type
    function [success, probability] = newTrial(obj, maze, type, probability)
      
      % Return false if the maximum number of trials has been reached
      if obj.currentTrial == numel(obj.mazeID)
        success = false;
        return;
      end
      
      % Increment trial counters and record maze/trial type
      obj.trialTime                               = clock;
      obj.trialTic                                = tic;
      obj.currentTrial                            = obj.currentTrial + 1;
      obj.mazeID(obj.currentTrial)                = maze;
      obj.trialType(obj.currentTrial)             = type;
      obj.sumOfType(type)                         = obj.sumOfType(type) + 1;
      
      % Update time display
      if isempty(obj.startTime)
        obj.startTime                             = obj.trialTime;
        obj.startTic                              = obj.trialTic;
      end
      if ~isempty(obj.plotWindow)
        set(obj.txtTrialStart, 'String', datestr(obj.trialTime, 'HH:MM:SS'));
      end
      
      % Reset some statistics if maze ID has changed
      if obj.currentTrial < 2 || obj.mazeID(obj.currentTrial-1) ~= maze
        obj.currentSection                        = obj.currentTrial;
        obj.typeIndex                             = cell(size(obj.typeIndex));
        obj.numTrials(:,obj.currentTrial)         = 0;
        obj.numCorrect(:,obj.currentTrial)        = 0;
        obj.numGood(:,obj.currentTrial)           = 0;
        obj.wgtTrials(:,obj.currentTrial)         = 0;
        obj.wgtCorrect(:,obj.currentTrial)        = 0;
        obj.wgtGood(:,obj.currentTrial)           = 0;
        obj.consecCorrect(:,obj.currentTrial)     = 0;
        obj.consecWrong(:,obj.currentTrial)       = 0;
        obj.movingStart(:,obj.currentTrial)       = obj.currentSection;
        obj.movingTrialW(:,obj.currentTrial)      = 0;
        obj.movingPerform(:,obj.currentTrial)     = 0;
        obj.movingGood(:,obj.currentTrial)        = 0;
        
        obj.addDataPoint(obj.hFracCorrect, nan, nan(size(obj.hFracCorrect)));
        obj.addDataPoint(obj.hNoWeight   , nan, nan(size(obj.hNoWeight   )));
        obj.addDataPoint(obj.hViolation  , nan, nan(size(obj.hViolation  )));
        obj.addDataPoint(obj.hCriteria   , nan, nan(size(obj.hCriteria   )));
        obj.addDataPoint(obj.hTrialProb  , nan, nan(size(obj.hTrialProb  )));
    
      % Otherwise copy cumulative statistics from previous trial
      else
        obj.numTrials(:,obj.currentTrial)         = obj.numTrials(:,obj.currentTrial  - 1);
        obj.numCorrect(:,obj.currentTrial)        = obj.numCorrect(:,obj.currentTrial  - 1);
        obj.numGood(:,obj.currentTrial)           = obj.numGood(:,obj.currentTrial  - 1);
        obj.wgtTrials(:,obj.currentTrial)         = obj.wgtTrials(:,obj.currentTrial  - 1);
        obj.wgtCorrect(:,obj.currentTrial)        = obj.wgtCorrect(:,obj.currentTrial - 1);
        obj.wgtGood(:,obj.currentTrial)           = obj.wgtGood(:,obj.currentTrial  - 1);
        obj.consecCorrect(:,obj.currentTrial)     = obj.consecCorrect(:,obj.currentTrial - 1);
        obj.consecWrong(:,obj.currentTrial)       = obj.consecWrong(:,obj.currentTrial - 1);
        obj.movingStart(:,obj.currentTrial)       = obj.movingStart(:,obj.currentTrial - 1);
        obj.movingTrialW(:,obj.currentTrial)      = obj.movingTrialW(:,obj.currentTrial - 1);
        obj.movingPerform(:,obj.currentTrial)     = obj.movingPerform(:,obj.currentTrial - 1);
        obj.movingGood(:,obj.currentTrial)        = obj.movingGood(:,obj.currentTrial - 1);
      end
      
      % Special case where user forced the trial to be of a certain type
      if nargin < 4
        probability                               = zeros(obj.NUM_CHOICES, 1);
        probability(type)                         = 1;
      end
      obj.trialProb(:,obj.currentTrial)           = probability;
      
      success = true;
      
    end
    
    %----- Draw a random trial with equal probability
    function [success, probability] = randomTrial(obj, maze, varargin)
      [success, probability]  = obj.newTrial( maze                                      ...
                                            , obj.CHOICES(randi([1 obj.NUM_CHOICES]))   ...
                                            , 1 / obj.NUM_CHOICES                       ...
                                            );
    end
    
    %----- Draw a pseudo-random trial with equal probability
    function [success, probability] = pseudorandomTrial(obj, maze, varargin)
      [success, probability]  = obj.newTrial( maze                                      ...
                                            , obj.pseudorandoms(obj.currentTrial + 1)   ...
                                            , 1 / obj.NUM_CHOICES                       ...
                                            );
    end
    
    %----- Draw a trial with higher probability for trials with high error
    %      fractions. Specifically if e_i is the fraction of error trials
    %      for type i, then the probability to draw it is e_i / sum(e_j).
    function [success, probability] = errorWeightedTrial(obj, maze, varargin)
      
      % Obtain correct fraction of the historical items to consider
      correctFrac   = obj.weightedCorrectness(maze);
      
      % In case of insufficient data, resort to equal probability trials
      if isempty(correctFrac)
        [success, probability]  = obj.pseudorandomTrial(maze);
        return;
      end

      % Compute the cumulative probability of the set of choices
%       probability   = sqrt( 1 - correctFrac );
      probability   = max(min( sqrt(1 - correctFrac) , 1-obj.MIN_PROBABILITY), obj.MIN_PROBABILITY);
      probability   = probability / sum(probability);
      cumulative    = cumsum(probability);
      cumulative(end) = inf;    % Hack to ensure that a choice is always made

      % Draw from a multinomial distribution
      toss          = rand();
      for iChoice = 1:obj.NUM_CHOICES
        if toss < cumulative(iChoice)
          [success, probability]  = obj.newTrial(maze, obj.CHOICES(iChoice), probability);
          return;
        end
      end
      
      error('errorWeightedTrial:sanity', 'Should be impossible to reach here.');
    end
    
    
    %----- Draw a trial according to ERADE prescription.
    %      TODO : This currently only works for binary choices.
    function [success, probability] = eradeTrial(obj, maze, alpha, varargin)
      % Recommended setting for randomization factor
      if nargin < 3
        alpha       = 1/2;
      end
      % Obtain correct fraction of the historical items to consider
      correctFrac   = obj.weightedCorrectness(maze);
      

      if isempty(correctFrac)
        [success, probability]  = obj.pseudorandomTrial(maze);
        return;
      end
      


      % Compute estimator of ideal probabilities
      wrongFrac2    = max(min( sqrt(1 - correctFrac) , 1-obj.MIN_PROBABILITY), obj.MIN_PROBABILITY);
      rhoEstim      = wrongFrac2 / sum(wrongFrac2);
  
      % Compute current assignment fraction to choice 1
%       assignFrac    = numel(obj.typeIndex{1}) / sum(cellfun(@numel,obj.typeIndex));
      past          = min( numel(obj.weightPast), obj.currentTrial ) - 1 : -1 : 0;
      typeWeight    = obj.weightPast(end-past) .* (obj.trialType(obj.currentTrial-past) == 1);
      assignFrac    = sum(typeWeight) / sum(obj.weightPast(end-past));
      
      % ERADE prescription
      if assignFrac > rhoEstim(1)
        prob1       = alpha * rhoEstim(1);
      elseif assignFrac == rhoEstim(1)
        prob1       = rhoEstim(1);
      else
        prob1       = 1 - alpha * (1 - rhoEstim(1));
      end
      
      % Draw type for this trial
      toss          = rand();
      if toss < prob1
        trial       = obj.CHOICES(1);
      else
        trial       = obj.CHOICES(2);
      end
      
      [success, probability]  = obj.newTrial(maze, trial, [prob1; 1-prob1]);
%       [success, probability]  = obj.pseudorandomTrial(maze); % for
%       turning off erade!
      
    end
    
    %----- Draw left trials only.
    function [success, probability] = leftOnlyTrial(obj, maze, varargin)
      [success, probability] = obj.newTrial(maze, Choice.L);
    end
    
    %----- Draw right trials only.
    function [success, probability] = rightOnlyTrial(obj, maze, varargin)
      [success, probability] = obj.newTrial(maze, Choice.R);
    end
    
    
    %----- Setup performance statistics stored by recordChoice(); zeros
    %      out any previously stored values
    function setupStatistics(obj, numTrials, numBlocks, isWeighted, deltaBins)

      if isempty(numTrials)
        obj.movingNTrials   = [];
        obj.movingLabel     = {};
      else
        obj.movingNTrials   = ceil(numTrials/2);
        if numBlocks > 1
          indices           = -cumsum(ceil(repmat(numTrials,1,numBlocks)/2));
          obj.movingLabel   = arrayfun( @(n1,n2) sprintf('(Past %d-%d)', n1, n2)  ...
                                      , abs([0 indices(1:end-1)])                 ...
                                      , abs(indices + 1)                          ...
                                      , 'UniformOutput' , false                   ...
                                      );
        else
          obj.movingLabel   = {sprintf('(Past %d trials)', numTrials)};
        end
      end
      obj.movingWeighted    = isWeighted;
      if nargin > 4
        obj.deltaBins       = rowvec(deltaBins);
        if ~isempty(obj.deltaBins)
          binSize           = obj.deltaBins(2) - obj.deltaBins(1);
          set(obj.plotMetric(1), 'XLim', [obj.deltaBins(1) - binSize, obj.deltaBins(end) + binSize]);
        end
      end

%       if ~isempty(obj.plotWindow) && ishghandle(obj.plotWindow)
%         obj.createAdvancementPlots();
%       end
      
    end
    
    %----- Get advancement criteria statistics
    function [performance, bias, goodFraction, numTrials, numTrialsPerMin, trialIndex] = getStatistics(obj)
      
      statIndex             = obj.currentTrial;
      performance           = nan(1, numel(obj.movingLabel));
      bias                  = nan(1, numel(obj.movingLabel));
      goodFraction          = nan(1, numel(obj.movingLabel));

      if statIndex < 1
        numTrials           = nan(obj.NUM_CHOICES, numel(obj.movingLabel));
        numTrialsPerMin     = 0;
        trialIndex          = nan(obj.NUM_CHOICES, numel(obj.movingLabel));
        return;
      end
      
      [numTrials,trialIndex]= obj.getHistory(obj.movingTrialW , numel(obj.movingLabel));
      numTrialsPerMin       = 60 / obj.getMedianTrialDuration();
      typePerform           = obj.getHistory(obj.movingPerform, numel(obj.movingLabel));
      totalTrials           = sum(numTrials);
      
      performance           = sum(typePerform) ./ totalTrials;
      bias                  = abs ( typePerform(Choice.R,:) ./ numTrials(Choice.R,:)      ...
                                  - typePerform(Choice.L,:) ./ numTrials(Choice.L,:)      ...
                                  );
      goodFraction          = sum(obj.getHistory(obj.movingGood, numel(obj.movingLabel))) ...
                           ./ totalTrials                                                 ...
                            ;
      
    end
    
    %----- Get average length of trials (not including inter-trial interval)
    function duration = getMeanTrialLength(obj)
      duration  = sum(obj.sumTrialLength) / sum(obj.sumOfType);
    end
    
    %----- Get median trial duration (including inter-trial interval)
    function duration = getMedianTrialDuration(obj)

      if isempty(obj.ascDuration)
        duration  = nan;
      elseif mod(numel(obj.ascDuration), 2) == 0
        duration  = mean(obj.ascDuration([end/2, end/2+1]));
      else
        duration  = obj.ascDuration(ceil(end/2));
      end
      
    end
    
    %----- Set reward scale factor according to per-animal configuration
    function updateRewardScale(obj, warmupIndex, mazeID)

      obj.rewardScale   = obj.animal.rewardFactor(1 + (warmupIndex > 0), mazeID);
      if warmupIndex > 0
        label           = 'warm-up';
      else
        label           = 'main';
      end
      
      obj.log ( 'Scaling rewards by %.3g for %s maze %d'  ...
              , obj.rewardScale, label, mazeID            ...
              );
      obj.updateReward();
      
    end
    
    %----- Set reward scale factor appropriate for the current average duration of trials
    function computeRewardScale(obj, nominalPerformance, minScale, maxScale, itiCorrect, itiWrong)

      remainingTime     = obj.animal.session(obj.animal.sessionIndex).duration * 60;
      if ~isempty(obj.startTime)
        remainingTime   = remainingTime - etime(clock, obj.startTime);
      end
      trialDuration     = obj.getMeanTrialLength()                          ...
                        +      nominalPerformance  * itiCorrect             ...
                        + (1 - nominalPerformance) * itiWrong               ...
                        ;
      remainingTrials   = remainingTime / trialDuration;
      remainingAlloc    = obj.animal.waterAlloc - obj.totalRewards;
      
      obj.rewardScale   = ( remainingAlloc     / RigParameters.rewardSize ) ...
                        / ( nominalPerformance * remainingTrials          ) ...
                        ;

      if obj.rewardScale < minScale || ~isfinite(obj.rewardScale)
        obj.rewardScale = minScale;
      elseif obj.rewardScale > maxScale
        obj.rewardScale = maxScale;
      end

      obj.log ( 'Scaling rewards by %.3g assuming %.3g%% correct %.3g trials (%.3gs/trial) in %.3gmin to achieve %.3gmL rewards' ...
              , obj.rewardScale                       ...
              , nominalPerformance * 100              ...
              , remainingTrials, trialDuration        ...
              , remainingTime / 60, remainingAlloc    ...
              );
            
      obj.updateReward();
      
    end
    
    function setRewardScale(obj, scale, verbose)
      obj.rewardScale   = scale;
      if nargin > 2 && verbose
        obj.log ( 'Scaling rewards by %.3g (%.3g uL)'      ...
                , obj.rewardScale                                   ...
                , obj.rewardScale * 1000*RigParameters.rewardSize   ...
                );
      end
    end
    
    %----- Register choice for the current trial
    function performance = recordChoice(obj, choice, reward, weight, isGoodQuality, trialLength, numCues, varargin)

%       Special case for violation trials
      type                                        = obj.trialType(obj.currentTrial);
      correct                                     = (choice == type);
      obj.trialChoice(obj.currentTrial)           = choice;
      if choice > ChoiceExperimentStats.NUM_CHOICES
        performance   = obj.updatePlots();
        return;
      end
      
      % Default arguments
      if nargin < 4
        weight        = 1;
        isGoodQuality = 1;
      else
        obj.sumTrialLength(type)                  = obj.sumTrialLength(type) + trialLength;
      end
      
      % Store per-trial info
      obj.totalRewards                            = obj.totalRewards + reward;
      obj.trialWeight(type, obj.currentTrial)     = weight;
      obj.isCorrect(type, obj.currentTrial)       = correct;
      obj.isGood(type, obj.currentTrial)          = isGoodQuality;

      % Increment trial type counters
      obj.numTrials(type,obj.currentTrial)        = obj.numTrials(type,obj.currentTrial) + 1;
      obj.typeIndex{type}(end+1)                  = obj.currentTrial;
      
      % Cumulative statistics
      obj.wgtTrials(type,obj.currentTrial)        = obj.wgtTrials(type,obj.currentTrial) + weight;
      if correct
        % Increment statistics for correct trials
        obj.numCorrect(type, obj.currentTrial)    = obj.numCorrect(type, obj.currentTrial) + 1;
        obj.wgtCorrect(type, obj.currentTrial)    = obj.wgtCorrect(type, obj.currentTrial) + weight;
        obj.consecCorrect(type, obj.currentTrial) = obj.consecCorrect(type, obj.currentTrial) + 1;
        obj.consecWrong(type, obj.currentTrial)   = 0;
            
      else
        % Increment statistics for wrong trials
        obj.consecCorrect(type, obj.currentTrial) = 0;
        obj.consecWrong(type, obj.currentTrial)   = obj.consecWrong(type, obj.currentTrial) + 1;
      end
      if isGoodQuality
        obj.numGood(type, obj.currentTrial)       = obj.numGood(type, obj.currentTrial) + 1;
        obj.wgtGood(type, obj.currentTrial)       = obj.wgtGood(type, obj.currentTrial) + weight;
      end
      
      % Store cue information
      if nargin > 6
        obj.trialNCues(:, obj.currentTrial)       = numCues(:);
      end
      
      % Update sampling location of moving averages
      if obj.movingWeighted
        obj.updateMovingOffset(obj.wgtTrials);
      else
        obj.updateMovingOffset(obj.numTrials);
      end
      
      % Update moving averages
      if ~obj.movingWeighted
        obj.updateMovingSum('movingTrialW'  , obj.trialType   , []);
        obj.updateMovingSum('movingPerform' , obj.isCorrect   , []);
        obj.updateMovingSum('movingGood'    , obj.isGood      , []);
      elseif weight > 0
        obj.updateMovingSum('movingTrialW'  , obj.trialWeight , []);
        obj.updateMovingSum('movingPerform' , obj.isCorrect   , obj.trialWeight);
        obj.updateMovingSum('movingGood'    , obj.isGood      , obj.trialWeight);
      end
      
      % Update online display
      performance     = obj.updatePlots();
      if ~isempty(obj.plotWindow)
        obj.updateReward();
        obj.updateRun(varargin{:});
        
        medDuration   = obj.getMedianTrialDuration();
        set(obj.txtTrialMed, 'String', sprintf('%.3gs',medDuration));
      end
      
    end

    %----- Record duration of the trial including inter-trial interval
    function recordTrialDuration(obj, trialDuration)
      
      if isnan(trialDuration)
        return;
      end
      
      % Sorted order of trial durations
      if isempty(obj.ascDuration) || trialDuration > obj.ascDuration(end)
        obj.ascDuration(end+1)              = trialDuration;
      else
        iDuration                           = binarySearch(obj.ascDuration, trialDuration, 1, 1);
        obj.ascDuration(iDuration+1:end+1)  = obj.ascDuration(iDuration:end);
        obj.ascDuration(iDuration)          = trialDuration;
      end
      
    end
    
    %----- Turns on plotting of statistics on screen
    function plot(obj, monitor)
      obj.setupPlotWindow(monitor);
      obj.updatePlots();
    end
    
    %----- Return all figures created by this object
    function plots = getPlots(obj)
      plots   = obj.plotWindow;
    end

    %----- Log 
    function log(obj, format, varargin)

      if nargin > 2
        obj.logText{end+1}  = sprintf(format, varargin{:});
      else
        obj.logText{end+1}  = format;
      end
      
      if ~isempty(obj.plotWindow) && ishghandle(obj.plotWindow)
        set ( obj.lstLog                      ...
            , 'String'  , obj.logText         ...
            , 'Value'   , numel(obj.logText)  ...
            );
        drawnow;
        
      else
        fprintf(obj.logText{end});
        fprintf('\n');
      end
    end
    
  end
  
  %________________________________________________________________________
  methods (Access = protected)

    %----- Turn off user controls
    function deactivateControls(obj)
      if isempty(obj.plotWindow)
        return;
      end
      
      set(obj.btnStop   , 'Enable'          , 'off'         ...
                        , 'ForegroundColor' , [0 0 0]       ...
                        , 'BackgroundColor' , [1 1 1]*0.95  ...
                        );
      set(obj.plotWindow, 'CloseRequestFcn' , 'closereq');
    end
    
    %----- Callback for end of experiment
    function fcnStopExperiment(obj, handle, event, immediateEnd, varargin)

      % Show a confirmation dialog box if so requested
      if nargin > 3 && immediateEnd
        hVerify     = warndlg('Pressing OK will force an immediate end of the experiment.', 'Confirm end of experiment');
        btnVerify   = findall(get(hVerify,'Children'), 'Type', 'UIControl');
        set(btnVerify, 'Callback', {@confirmEndExperiment, true});
      else
        obj.stopExperiment();
      end
      
      function confirmEndExperiment(handle, event, varargin)
        delete(hVerify);
        obj.stopExperiment(varargin{:});
      end
      
    end

    %----- Set flag for end of experiment
    function stopExperiment(obj, immediateEnd)
      if nargin > 1 && immediateEnd
        obj.endExperiment = inf;    % Magic value to force immediate ending
      else
        obj.endExperiment = true;
      end
      obj.deactivateControls();
    end
    
      
    %----- Compute weighted average correct fraction
    function correctFrac = weightedCorrectness(obj, maze)
        
      
        % Special case where there is insufficient past to consider

%       
      if    obj.currentTrial < 1                  ...
        ||  obj.mazeID(obj.currentTrial) ~= maze  ...
        ||  any(cellfun(@isempty, obj.typeIndex))
        correctFrac           = [];
        return;
      end
      
      correctFrac             = zeros(obj.NUM_CHOICES, 1);
      for iChoice = 1:obj.NUM_CHOICES
        past                  = min( numel(obj.weightPast), numel(obj.typeIndex{iChoice}) ) - 1 : -1 : 0;
        correctFrac(iChoice)  = sum( obj.weightPast(end-past)                                 ...
                                  .* obj.isCorrect(iChoice,obj.typeIndex{iChoice}(end-past))  ...
                                   )                                                          ...
                              / sum(obj.weightPast(end-past))                                 ...
                              ;
      end
      
    end
    
    %----- Set up plotting window for statistics display
    function handle = setupPlotWindow(obj, monitor, remake)
      
      % If there's already one and we don't want to remake, return it
      if ~isempty(obj.plotWindow) && ishghandle(obj.plotWindow)
        if nargin < 3 || ~remake
          handle        = figure(obj.plotWindow);
          return;
        end
        close(obj.plotWindow);
      end
      
      % Create a window centered on the screen
      if nargin < 2
        monitor         = 1;
      end
      screen            = get(0, 'MonitorPosition');
      screen            = screen(min(monitor, end), :);
      windowSize        = [min(1200, screen(3) - 50), min(1000, screen(4) - 50)];
      obj.plotWindow    = figure( 'Name'            , 'ViRMEn Experiment Statistics'      ...
                                , 'Position'        , [screen(1:2) + [10 48], windowSize] ...
                                , 'Color'           , [1 1 1]                             ...
                                , 'Menubar'         , 'none'                              ...
                                , 'Toolbar'         , 'figure'                            ...
                                , 'Visible'         , 'off'                               ...
                                , 'CloseRequestFcn' , {@obj.fcnStopExperiment, true}      ...
                                );
      colormap(obj.plotWindow, flipud(gray(256)));
      
      % Initialize various informative displays
      obj.plotAxes      = gobjects(0);
      obj.plotMetric    = gobjects(0);
      obj.plotMotion    = gobjects(0);
      obj.hMazeID       = gobjects(0);
      obj.textMazeID    = gobjects(0);

%       obj.mazeColor     = jet(obj.totalMazes);
      obj.mazeColor     = othercolor('Mrainbow', obj.totalMazes);
      obj.mazePrev      = brighten( imadjust(obj.mazeColor, [0;1], [0.2,0.8]), 0.75 );
      obj.mazeBkg       = brighten( imadjust(obj.mazeColor, [0;1], [0.2,0.8]), 0.9  );
      [~,choiceNames]   = enumeration('Choice');
      choiceNames       = cellfun(@(x) [x ' trials'], choiceNames, 'UniformOutput', false);

      
      % Create plot for fractions of correct and wrong trials
      obj.plotAxes(end+1)                                                         ...
                        = axes( 'Parent'        , obj.plotWindow                  ...
                              , 'Units'         , 'normalized'                    ...
                              , 'Position'      , [0.05 0.68 0.54 0.25]           ...
                              , 'FontSize'      , obj.FONT_SIZE - 1               ...
                              , 'XLim'          , [0 obj.totalTrials/2] + 0.5     ...
                              , 'YLim'          , [-0.05 1.05]                    ...
                              , 'YGrid'         , 'on'                            ...
                              , 'GridLineStyle' , ':'                             ...
                              , 'GridAlpha'     , 1                               ...
                              , 'Box'           , 'on'                            ...
                              , 'Layer'         , 'top'                           ...
                              , 'Color'         , 'none'                          ...
                              , 'ActivePositionProperty'  , 'Position'            ...
                              );
      ylabel(obj.plotAxes(end), 'Fraction correct');
      hold(obj.plotAxes(end), 'on');
      
    	obj.hFracCorrect  = gobjects(1, obj.NUM_CHOICES + 2);
      for iChoice = 1:numel(obj.hFracCorrect)
        obj.hFracCorrect(iChoice) = line( 'Parent'      , obj.plotAxes(end)       ...
                                        , 'XData'       , []                      ...
                                        , 'YData'       , []                      ...
                                        );
        if isempty(obj.MARKERS{iChoice})
          set ( obj.hFracCorrect(iChoice)                                         ...
              , 'LineStyle'       , obj.CHOICE_LINES{iChoice}                     ...
              , 'LineWidth'       , 1                                             ...
              , 'Color'           , obj.AVG_COLOR(iChoice-numel(obj.CHOICES),:)   ...
              );
        else
          set ( obj.hFracCorrect(iChoice)                                         ...
              , 'LineStyle'       , 'none'                                        ...
              , 'Marker'          , obj.MARKERS{iChoice}                          ...
              , 'MarkerSize'      , obj.MARKER_SIZE                               ...
              , 'MarkerFaceColor' , [0 0 0]                                       ...
              , 'MarkerEdgeColor' , 'none'                                        ...
              );
        end
      end

      legend( obj.hFracCorrect                                                    ...
            , [choiceNames(1:end-1); {'Cumulative avg.'; '(\geq1 distractor)'}]   ...
            , 'Location', 'SouthEast'                                             ...
            , 'Box'     , 'off'                                                   ...
            , 'FontSize', obj.FONT_SIZE - 2                                       ...
            );
          
      % Highlights for weighted and violation trials
      obj.hNoWeight     = gobjects(1, obj.NUM_CHOICES);
      obj.hViolation    = gobjects(1, obj.NUM_CHOICES);
      for iChoice = 1:numel(obj.hNoWeight)
        obj.hNoWeight(iChoice)                                                    ...
                        = line( 'Parent'          , obj.plotAxes(end)             ...
                              , 'XData'           , []                            ...
                              , 'YData'           , []                            ...
                              , 'LineStyle'       , 'none'                        ...
                              , 'Marker'          , obj.MARKERS{iChoice}          ...
                              , 'MarkerSize'      , obj.MARKER_SIZE               ...
                              , 'MarkerFaceColor' , obj.NOWEIGHT_COLOR            ...
                              , 'MarkerEdgeColor' , 'none'                        ...
                              );
      obj.hViolation(iChoice)                                                     ...
                        = line( 'Parent'          , obj.plotAxes(end)             ...
                              , 'XData'           , []                            ...
                              , 'YData'           , []                            ...
                              , 'LineStyle'       , 'none'                        ...
                              , 'Marker'          , obj.MARKERS{iChoice}          ...
                              , 'MarkerSize'      , obj.MARKER_SIZE               ...
                              , 'MarkerFaceColor' , obj.VIOLATION_COLOR           ...
                              , 'MarkerEdgeColor' , 'none'                        ...
                              );
      end

      
      % Create plot for advancement criteria
      obj.plotAxes(end+1)                                                         ...
                        = axes( 'Parent'        , obj.plotWindow                  ...
                              , 'Units'         , 'normalized'                    ...
                              , 'Position'      , [0.05 0.49 0.54 0.16]           ...
                              , 'FontSize'      , obj.FONT_SIZE - 1               ...
                              , 'XLim'          , [0 obj.totalTrials/2] + 0.5     ...
                              , 'YLim'          , [-0.05 1.05]                    ...
                              , 'YGrid'         , 'on'                            ...
                              , 'GridLineStyle' , ':'                             ...
                              , 'GridAlpha'     , 1                               ...
                              , 'Box'           , 'on'                            ...
                              , 'Layer'         , 'top'                           ...
                              , 'Color'         , 'none'                          ...
                              , 'ActivePositionProperty'  , 'Position'            ...
                              );
      ylabel(obj.plotAxes(end), 'Fraction pass criteria');
      hold(obj.plotAxes(end), 'on');
      obj.createAdvancementPlots();
      
      
      % Create plot for probabilty distribution used to draw trials
      obj.plotAxes(end+1)                                                         ...
                        = axes( 'Parent'        , obj.plotWindow                  ...
                              , 'Units'         , 'normalized'                    ...
                              , 'Position'      , [0.05 0.42 0.54 0.04]           ...
                              , 'FontSize'      , obj.FONT_SIZE - 1               ...
                              , 'XLim'          , [0 obj.totalTrials/2] + 0.5     ...
                              , 'YLim'          , [-0.05 1.05]                    ...
                              , 'YGrid'         , 'on'                            ...
                              , 'XTick'         , []                              ...
                              , 'GridLineStyle' , ':'                             ...
                              , 'GridAlpha'     , 1                               ...
                              , 'Box'           , 'on'                            ...
                              , 'Layer'         , 'top'                           ...
                              , 'Color'         , 'none'                          ...
                              , 'ActivePositionProperty'  , 'Position'            ...
                              );
      xlabel(obj.plotAxes(end), 'Trial');
      hold(obj.plotAxes(end), 'on');

      obj.hTrialProb    = line( 'Parent'          , obj.plotAxes(end)             ...
                              , 'XData'           , []                            ...
                              , 'YData'           , []                            ...
                              , 'LineStyle'       , obj.CHOICE_LINES{Choice.R}    ...
                              , 'LineWidth'       , 1                             ...
                              );
      legend( obj.hTrialProb, {[char(Choice.R) ' trial probability']}             ...
            , 'Location', 'SouthEast'                                             ...
            , 'Box'     , 'off'                                                   ...
            , 'FontSize', obj.FONT_SIZE - 2                                       ...
            );

      % Common range and position for overlaid axes
      linkaxes(obj.plotAxes, 'x');
      setAxesZoomMotion(zoom(obj.plotWindow), obj.plotAxes, 'horizontal');

      
      % Create plot for animal's speed
      obj.plotMotion(end+1)                                                       ...
                        = axes( 'Parent'        , obj.plotWindow                  ...
                              , 'Units'         , 'normalized'                    ...
                              , 'Position'      , [0.64 0.85 0.34 0.08]           ...
                              , 'FontSize'      , obj.FONT_SIZE - 1               ...
                              , 'XLim'          , obj.MAZE_RANGE                  ...
                              , 'YLim'          , obj.SPEED_RANGE                 ...
                              , 'YGrid'         , 'on'                            ...
                              , 'GridLineStyle' , ':'                             ...
                              , 'GridAlpha'     , 1                               ...
                              , 'Box'           , 'on'                            ...
                              , 'Layer'         , 'top'                           ...
                              , 'Color'         , 'none'                          ...
                              , 'CLim'          , [0 1]                           ...
                              );
      ylabel(obj.plotMotion(end), 'Speed (cm/s)');
      hold(obj.plotMotion(end), 'on');

      % Create plot for animal's rotational velocity
      obj.plotMotion(end+1)                                                       ...
                        = axes( 'Parent'        , obj.plotWindow                  ...
                              , 'Units'         , 'normalized'                    ...
                              , 'Position'      , [0.64 0.45 0.165 0.37]          ...
                              , 'FontSize'      , obj.FONT_SIZE - 1               ...
                              , 'XLim'          , obj.ROTVEL_RANGE                ...
                              , 'YLim'          , obj.MAZE_RANGE                  ...
                              , 'XGrid'         , 'on'                            ...
                              , 'GridLineStyle' , ':'                             ...
                              , 'GridAlpha'     , 1                               ...
                              , 'Box'           , 'on'                            ...
                              , 'Color'         , 'none'                          ...
                              );
      xlabel(obj.plotMotion(end), 'Rotational velocity (rev/s)');
      ylabel(obj.plotMotion(end), 'y (cm)');
      hold(obj.plotMotion(end), 'on');
      
      % Create plot for animal's view angle
      obj.plotMotion(end+1)                                                       ...
                        = axes( 'Parent'        , obj.plotWindow                  ...
                              , 'Units'         , 'normalized'                    ...
                              , 'Position'      , [0.815 0.45 0.165 0.37]         ...
                              , 'FontSize'      , obj.FONT_SIZE - 1               ...
                              , 'XLim'          , obj.ANGLE_RANGE                 ...
                              , 'XDir'          , 'reverse'                       ...
                              , 'YLim'          , obj.MAZE_RANGE                  ...
                              , 'XGrid'         , 'on'                            ...
                              , 'YTickLabel'    , {}                              ...
                              , 'GridLineStyle' , ':'                             ...
                              , 'GridAlpha'     , 1                               ...
                              , 'Box'           , 'on'                            ...
                              , 'Layer'         , 'top'                           ...
                              , 'Color'         , 'none'                          ...
                              );
      xlabel(obj.plotMotion(end), 'View angle (\circ)');
      hold(obj.plotMotion(end), 'on');
      
      % Plots for past and current trial, all choices
      obj.hSpeed        = gobjects(0);
      obj.hSpeed(end+1) = image ( 'Parent'          , obj.plotMotion(1)                     ...
                                , 'XData'           , obj.MAZE_RANGE(1):obj.MAZE_FINEBIN:obj.MAZE_RANGE(2) + obj.MAZE_FINEBIN/10 ...
                                , 'YData'           , obj.SPEED_RANGE(1):obj.SPEED_BIN:obj.SPEED_RANGE(2)  + obj.SPEED_BIN/10    ...
                                , 'CDataMapping'    , 'scaled'                              ...
                                , 'UserData'        , 0                                     ...
                                );
      set(obj.hSpeed(end), 'CData', zeros(numel(get(obj.hSpeed(end),'YData')), numel(get(obj.hSpeed(end),'XData'))));
      obj.hSpeed(end+1) = line  ( 'Parent'          , obj.plotMotion(1)                     ...
                                , 'Color'           , obj.CRIT_COLOR(2,:)                   ...
                                , 'LineWidth'       , 1.5                                   ...
                                );
                              
      % Template binned histogram data
      spatialBins       = obj.MAZE_RANGE(1):obj.MAZE_BIN:obj.MAZE_RANGE(2) - obj.MAZE_BIN/10;
      templateHist      = zeros(obj.FREQ_NBINS, numel(spatialBins));
      templateEnd       = nan(1, numel(spatialBins));
      
      % Plots for past and current trial, by choice
      obj.hRotation     = gobjects(1, obj.NUM_CHOICES + 1);
      obj.hViewAngle    = gobjects(1, obj.NUM_CHOICES + 1);
      for iChoice = 1:numel(obj.hRotation)
        obj.hRotation(iChoice)                                                              ...
                        = patch ( 'Parent'          , obj.plotMotion(2)                     ...
                                , 'XData'           , [ repmat(linspace(obj.ROTVEL_RANGE(1), obj.ROTVEL_RANGE(2), obj.FREQ_NBINS)', 1, numel(spatialBins))  ...
                                                      ; templateEnd ]                       ...
                                , 'YData'           , [ templateHist; templateEnd ]         ...
                                , 'FaceColor'       , 'none'                                ...
                                , 'EdgeColor'       , obj.CHOICE_COLOR(iChoice,:)           ...
                                , 'LineWidth'       , 0.5 + (iChoice > obj.NUM_CHOICES)     ...
                                , 'UserData'        , spatialBins                           ...
                                );
        obj.hViewAngle(iChoice)                                                             ...
                        = patch ( 'Parent'          , obj.plotMotion(3)                     ...
                                , 'XData'           , [ repmat(linspace(obj.ANGLE_RANGE(1), obj.ANGLE_RANGE(2), obj.FREQ_NBINS)', 1, numel(spatialBins))    ...
                                                      ; templateEnd ]                       ...
                                , 'YData'           , [ templateHist; templateEnd ]         ...
                                , 'FaceColor'       , 'none'                                ...
                                , 'EdgeColor'       , obj.CHOICE_COLOR(iChoice,:)           ...
                                , 'LineWidth'       , 0.5 + (iChoice > obj.NUM_CHOICES)     ...
                                , 'UserData'        , spatialBins                           ...
                                );
      end

%       legend( obj.hSpeed, [arrayfun(@(x) [char(x), ' choice'], Choice.all(), 'UniformOutput', false), {'Current'}]  ...
%             , 'Location', 'NorthEast'                                             ...
%             , 'Box'     , 'off'                                                   ...
%             , 'FontSize', obj.FONT_SIZE - 2                                       ...
%             );
      
      % Create plot for psychometric curve
      obj.plotMetric(end+1)                                                       ...
                        = axes( 'Parent'        , obj.plotWindow                  ...
                              , 'Units'         , 'normalized'                    ...
                              , 'Position'      , [0.05 0.05 0.3 0.34]            ...
                              , 'FontSize'      , obj.FONT_SIZE - 1               ...
                              , 'YLim'          , [0 1]                           ...
                              , 'XGrid'         , 'on'                            ...
                              , 'YGrid'         , 'on'                            ...
                              , 'GridLineStyle' , ':'                             ...
                              , 'GridAlpha'     , 0.5                             ...
                              , 'Box'           , 'on'                            ...
                              , 'Color'         , 'none'                          ...
                              , 'Layer'         , 'top'                           ...
                              , 'ActivePositionProperty'  , 'Position'            ...
                              );
      xlabel(obj.plotMetric(end), '#R - #L towers');
      ylabel(obj.plotMetric(end), 'Fraction turned right');
      if isempty(obj.deltaBins)
        set(obj.plotMetric(end), 'XLim', [-15 15]);
      else
        binSize         = obj.deltaBins(2) - obj.deltaBins(1);
        set(obj.plotMetric(end), 'XLim', [obj.deltaBins(1) - binSize, obj.deltaBins(end) + binSize]);
      end

      
      % Context menu for copying items
      enhanceCopying(obj.plotWindow);
      enhanceCopying(obj.plotAxes);
      enhanceCopying(obj.plotMetric);
      copyMenu          = uicontextmenu(obj.plotWindow);

      % Informative log display
      obj.lstLog        = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'listbox'               ...
                                    , 'String'              , {}                      ...
                                    , 'FontName'            , 'FixedWidth'            ...
                                    , 'FontSize'            , obj.FONT_SIZE           ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.37 0.01, 0.62 0.38]  ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    , 'Callback'            , @ChoiceExperimentStats.openListboxFile  ...
                                    , 'UIContextMenu'       , copyMenu                ...
                                    );
      uimenu( copyMenu                                                                ...
            , 'Label'     , '&Copy selected line'                                     ...
            , 'Callback'  , {@ChoiceExperimentStats.copyListboxItem, obj.lstLog}      ...
            );
      
      
      % Animal info display
      obj.txtAnimal     = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , obj.animal.name         ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'FontWeight'          , 'bold'                  ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.01 0.96, 0.06 0.03]  ...
                                    , 'HorizontalAlignment' , 'center'                ...
                                    , 'ForegroundColor'     , [1 1 1]                 ...
                                    , 'BackgroundColor'     , obj.animal.color        ...
                                    );
                                  
      % Time displays
      obj.txtLabel(1)   = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , 'Trial start:'          ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.08 0.95, 0.08 0.04]    ...
                                    , 'HorizontalAlignment' , 'right'                 ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtLabel(2)   = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , '/ median :'            ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.29 0.95, 0.08 0.04]  ...
                                    , 'HorizontalAlignment' , 'left'                  ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtLabel(3)   = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , 'Run duration:'         ...
                                    , 'FontSize'             , obj.FONT_SIZE + 1      ...
                                    , 'FontWeight'          , 'bold'                  ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.37 0.95, 0.14 0.04]  ...
                                    , 'HorizontalAlignment' , 'right'                 ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtLabel(4)   = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , 'Rewarded:'             ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'FontWeight'          , 'bold'                  ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.6 0.95, 0.08 0.04]  ...
                                    , 'HorizontalAlignment' , 'right'                 ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtTrialStart = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , 'HH:MM:SS'              ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.18 0.95, 0.1 0.04]   ...
                                    , 'HorizontalAlignment' , 'left'                  ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtTrialDur   = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , '(MM:SS)'               ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.24 0.95, 0.05 0.04]  ...
                                    , 'HorizontalAlignment' , 'left'                  ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtTrialMed   = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , '(n/a)'                 ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.35 0.95, 0.04 0.04]  ...
                                    , 'HorizontalAlignment' , 'left'                  ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtRunDur     = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , 'HH:MM:SS'              ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'FontWeight'          , 'bold'                  ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.53 0.95, 0.06 0.04]  ...
                                    , 'HorizontalAlignment' , 'left'                  ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );
      obj.txtRewarded   = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'text'                  ...
                                    , 'String'              , '#.## mL (#.# uL x #.#)'...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'FontWeight'          , 'bold'                  ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.69 0.95, 0.15 0.04]  ...
                                    , 'HorizontalAlignment' , 'left'                  ...
                                    , 'BackgroundColor'     , [1 1 1]                 ...
                                    );

      % End experiment button
      obj.btnStop       = uicontrol ( 'Parent'              , obj.plotWindow          ...
                                    , 'Style'               , 'pushbutton'            ...
                                    , 'String'              , 'END experiment'        ...
                                    , 'FontSize'            , obj.FONT_SIZE + 1       ...
                                    , 'FontWeight'          , 'bold'                  ...
                                    , 'Units'               , 'normalized'            ...
                                    , 'Position'            , [0.855 0.95, 0.13 0.04] ...
                                    , 'ForegroundColor'     , [1 1 1]                 ...
                                    , 'BackgroundColor'     , [1 0 0]                 ...
                                    , 'Callback'            , @obj.fcnStopExperiment  ...
                                    );
                                  
      set(obj.plotWindow, 'Visible', 'on');
      
    end
    
    
    %----- Update plots with the latest data
    function fracCorrect = updatePlots(obj)

      % This only has effect if there is a plot object and there are trials
      if isempty(obj.plotWindow) || obj.currentTrial < 1
        fracCorrect       = [];
        return;
      end
      trialType           = obj.trialType(obj.currentTrial);
      statIndex           = obj.currentTrial;

      
      % Fractions of correct and wrong trials
      fracCorrect         = obj.numCorrect(:,statIndex) ./ obj.numTrials(:,statIndex);
      % Average correct fraction regardless of trial type
      fracCorrect(end+1)  = sum(obj.numCorrect(:,statIndex)) ./ sum(obj.numTrials(:,statIndex));
      fracCorrect(end+1)  = sum(obj.wgtCorrect(:,statIndex)) ./ sum(obj.wgtTrials(:,statIndex));
% took out all plotting (rachel)
%       % Distinguish violation trials
%       if obj.trialChoice(obj.currentTrial) > ChoiceExperimentStats.NUM_CHOICES
%         obj.addDataPoint( obj.hViolation(trialType), statIndex, -0.05 );
%         
%       else
%         obj.addDataPoint( obj.hFracCorrect(trialType), statIndex, fracCorrect(trialType) );
%         obj.addDataPoint( obj.hFracCorrect(end-1:end), statIndex, fracCorrect(end-1:end) );
%       
%         % Highlights for zero weight trials
%         if obj.trialWeight(trialType, obj.currentTrial) == 0
%           obj.addDataPoint( obj.hNoWeight(trialType), statIndex, fracCorrect(trialType) );
%         end
%       end
%       
%       
%       % Moving averages for performance criteria
%       [performance, bias, goodFraction, ~, ~, trialIndex] = obj.getStatistics();
%       if ~isempty(performance)
%         obj.addDataPoint( obj.hCriteria(1,:), statIndex                                 ...
%                         , [performance(1), bias(1), goodFraction(1)]                    ...
%                         );
%         for iBlock = 1:numel(performance)
%           obj.setDataPoint( obj.hCriteria(1+iBlock,:), trialIndex(iBlock)               ...
%                           , [performance(iBlock), bias(iBlock), goodFraction(iBlock)]   ...
%                           );
%         end
%       end
% 
%       
%       % Probabilty distribution used to draw trials
%       obj.addDataPoint( obj.hTrialProb, statIndex, obj.trialProb(Choice.R,obj.currentTrial) );
% 
%       
%       % Create a new block if the maze ID has changed
%       if obj.currentTrial < 2 || obj.mazeID(obj.currentTrial) ~= obj.mazeID(obj.currentTrial-1)
%         iMaze     = size(obj.hMazeID, 2) + 1;
%         for iPlot = 1:numel(obj.plotAxes)
%           obj.hMazeID(iPlot, iMaze)                                                           ...
%                   = patch ( 'Parent'    , obj.plotAxes(iPlot)                                 ...
%                           , 'XData'     , obj.currentTrial + [-0.5, 0.5, 0.5, -0.5]           ...
%                           , 'YData'     , [-0.1, -0.1, 1.2, 1.2]                              ...
%                           , 'FaceColor' , obj.mazeBkg(obj.mazeID(obj.currentTrial),:)         ...
%                           , 'FaceAlpha' , 0.7                                                 ...
%                           , 'LineStyle' , 'none'                                              ...
%                           );
%           uistack(obj.hMazeID(iPlot, iMaze), 'bottom');
%         end
%         
%         obj.textMazeID(iMaze)                                                                 ...
%                   = text( obj.currentTrial - 0.2, 1.05                                        ...
%                         , sprintf('%s%d', obj.mazeLabel, obj.mazeID(obj.currentTrial))        ...
%                         , 'Parent', obj.plotAxes(1)                                           ...
%                         , 'FontSize'            , 10                                          ...
%                         , 'FontWeight'          , 'bold'                                      ...
%                         , 'Color'               , [1 1 1]*0.5                                 ...
%                         , 'HorizontalAlignment' , 'left'                                      ...
%                         , 'VerticalAlignment'   , 'bottom'                                    ...
%                         );
%       
%         % Add another psychometric plot
%         if ~isempty(obj.deltaBins)
%           % First change formatting of previous maze
%           if ~isempty(obj.hMetric)
%             set(obj.hMetric(end), 'Marker', 'none', 'Color', obj.mazePrev(obj.mazeID(obj.currentTrial),:));
%             set(obj.hMetricErr(end), 'Color', obj.mazeBkg(obj.mazeID(obj.currentTrial),:), 'LineWidth', 1);
%           end
% 
%           % Create psychometric plot and error bars
%           obj.hMetric(end + 1)                                                                ...
%                   = line( 'Parent'          , obj.plotMetric                                  ...
%                         , 'XData'           , obj.deltaBins                                   ...
%                         , 'YData'           , nan(size(obj.deltaBins))                        ...
%                         , 'ZData'           , zeros(size(obj.deltaBins))                      ...
%                         , 'LineWidth'       , 1.5                                             ...
%                         , 'Marker'          , obj.METRIC_MARKER                               ...
%                         , 'MarkerSize'      , obj.MARKER_SIZE * 2                             ...
%                         , 'Color'           , obj.mazeColor(obj.mazeID(obj.currentTrial),:)   ...
%                         , 'MarkerFaceColor' , obj.mazeColor(obj.mazeID(obj.currentTrial),:)   ...
%                         , 'MarkerEdgeColor' , 'none'                                          ...
%                         );
%           obj.hMetricErr(end + 1)                                                             ...
%                   = line( 'Parent'          , obj.plotMetric                                  ...
%                         , 'XData'           , colvec( [ obj.deltaBins                         ...
%                                                       ; obj.deltaBins                         ...
%                                                       ; nan(size(obj.deltaBins))              ...
%                                                       ] )                                     ...
%                         , 'YData'           , nan(3*numel(obj.deltaBins), 1)                  ...
%                         , 'LineWidth'       , 1                                               ...
%                         , 'Color'           , obj.mazeColor(obj.mazeID(obj.currentTrial),:)   ...
%                         );
%           uistack(obj.hMetricErr(end) , 'top');
%           uistack(obj.hMetric(end)    , 'top');
%         end
%         
%       % Otherwise extend the previous block to include the current trial
%       else
%         for iPlot = 1:size(obj.hMazeID, 1)
%           xPos    = get(obj.hMazeID(iPlot, end), 'XData');
%           set(obj.hMazeID(iPlot, end), 'XData', xPos + [0; 1; 1; 0]);
%         end
%       end
%       
%       % Adjust plot ranges if necessary
%       if obj.currentTrial >= obj.totalTrials/2
%         set(obj.plotAxes, 'XLim', [0 obj.totalTrials] + 0.5);
%       end
%       
%       % Accumulate statistics across trials
%       if obj.trialChoice(obj.currentTrial) <= ChoiceExperimentStats.NUM_CHOICES
%         obj.histogramData ( obj.hMetric(end), obj.hMetricErr(end)                 ...
%                           , obj.trialNCues(Choice.R, obj.currentTrial)            ...
%                           - obj.trialNCues(Choice.L, obj.currentTrial)            ...
%                           , obj.trialChoice(obj.currentTrial) == Choice.R         ...
%                           , obj.deltaBins                                         ...
%                           );
%       end
      
    end

    %----- Update sampling location of moving averages
    function updateMovingOffset(obj, numTrials)
      
      if isempty(obj.movingNTrials)
        return;
      end
      
      % movingOffset keeps track of the range of trials used to compute
      % various blocks of moving averages, with [movingOffset(i),
      % movingOffset(i+1)-1] being the set of included trials in block i.
      % When there are enough trials, these blocks are guaranteed to have
      % at least movingNTrials number of trials per trial type (L, R).
      
      % Block boundaries can shift by more than one trial because there
      % could be a long stretch of trials of only one type (although this
      % behavior can be debated); ergo we try all valid ranges
      for iStart = obj.movingStart(obj.currentTrial) + 1:obj.currentTrial - 1
        blockTrials   = numTrials(:, obj.currentTrial)  ...
                      - numTrials(:, iStart)            ...
                      ;
        if all(blockTrials >= obj.movingNTrials)
          obj.movingStart(obj.currentTrial) = iStart;
        else
          break;      % When there are already not enough trials, no point continuing
        end
      end
      
    end

    %----- Increment sums for moving average statistics
    function updateMovingSum(obj, quantity, values, weights)

      if obj.currentTrial > obj.currentSection
        removedTrials = obj.movingStart(obj.currentTrial-1)           ...
                      : obj.movingStart(obj.currentTrial) - 1         ...
                      ;
      else
        removedTrials = [];
      end
      
      obj.(quantity)(:,obj.currentTrial)                              ...
        = obj.(quantity)(:,obj.currentTrial)                          ...
        - sum(obj.getValuesAt(values, weights, removedTrials   ),2)   ...
        +     obj.getValuesAt(values, weights, obj.currentTrial)      ...
        ;
      
    end
    
    %----- Get values at specified offsets
    function [values, trialIndex] = getHistory(obj, allValues, numBlocks)
      
      values              = nan(size(allValues,1), numBlocks);
      trialIndex          = nan(1, numBlocks);
      iStart              = obj.currentTrial;
      for iBlock = 1:numBlocks
        if isnan(iStart) || iStart < obj.currentSection
          break;
        end
        values(:,iBlock)  = allValues(:, iStart);
        trialIndex(iBlock)= iStart;
        iStart            = obj.movingStart(iStart) - 1;
      end
      
    end
    
    %----- Create (additional) plots for advancement criteria
    function createAdvancementPlots(obj)
      
      % Reverse order so that more important plots are on top
      for iCrit = numel(obj.CRIT_MARKER):-1:1
        for iBlock = 1:numel(obj.movingLabel)+1
          if      iBlock > size(obj.hCriteria,1)                            ...
              ||  iCrit  > size(obj.hCriteria,2)                            ...
              ||  ~ishghandle(obj.hCriteria(iBlock,iCrit))
            obj.hCriteria(iBlock,iCrit)                                     ...
                      = line( 'Parent'          , obj.plotAxes(2)           ...
                            , 'XData'           , []                        ...
                            , 'YData'           , []                        ...
                            , 'LineWidth'       , 1                         ...
                            , 'Color'           , obj.CRIT_COLOR(iCrit,:)   ...
                            );
          end
          
          if iBlock > 1
            if iBlock == 2
              color   = obj.CRIT_COLOR(iCrit,:);
            else
              color   = [1 1 1];
            end
            set ( obj.hCriteria(iBlock,iCrit)                               ...
                , 'LineStyle'       , 'none'                                ...
                , 'Marker'          , obj.CRIT_MARKER{iCrit}                ...
                , 'MarkerSize'      , obj.MARKER_SIZE                       ...
                , 'MarkerFaceColor' , color                                 ...
                , 'MarkerEdgeColor' , obj.CRIT_COLOR(iCrit,:)               ...
                );
          end
        end
      end

      if ~isempty(obj.hCriteria)
        hLegend       = legend( [obj.hCriteria(1,:), obj.hCriteria(2:numel(obj.movingLabel)+1,1)']  ...
                              , [{'Performance', 'Bias', 'Good quality'}, obj.movingLabel]          ...
                              , 'Location', 'SouthEast'                                             ...
                              , 'Box'     , 'off'                                                   ...
                              , 'FontSize', obj.FONT_SIZE - 2                                       ...
                              );
        if obj.movingWeighted
          legendTitle(hLegend, '\geq1 distractor');
        else
          legendTitle(hLegend, 'All trials');
        end
      end
      
    end
    
  end
  
  %________________________________________________________________________
  methods (Static)
    
    %----- Open selected item if it matches a file name
    function openListboxFile(handle, event)
      
      % Only consider double-click events
      if ~strcmpi(get(get(handle, 'Parent'), 'SelectionType'), 'open')
        return;
      end
      
      items     = get(handle, 'String');
      matches   = regexp(items{get(handle, 'Value')}, ChoiceExperimentStats.RGX_FILE, 'match');
      for iMatch = 1:numel(matches)
        if exist(matches{iMatch}, 'file')
          fprintf('Loading %s\n', matches{iMatch});
          evalin('base', sprintf('load(''%s'')', matches{iMatch}));
          commandwindow;
        else
          fprintf('%s is not an existing file.\n', matches{iMatch});
        end
      end
      
    end
    
    %----- Copy data from listbox to clipboard
    function copyListboxItem(handle, event, object)
      
      items = get(object,'String');
      clipboard('copy', items{get(object, 'Value')});
      
    end
    
    %----- Helper for updateMovingSum()
    function value = getValuesAt(values, weights, indices)
      
      if isempty(indices)
        value   = 0;
      elseif size(values,1) < ChoiceExperimentStats.NUM_CHOICES
        value   = zeros(ChoiceExperimentStats.NUM_CHOICES, numel(indices));
        for iVal = 1:numel(indices)
          if values(indices(iVal)) <= size(value,1)
            value(values(indices(iVal)), iVal)  = 1;
          end
        end
      elseif isempty(weights)
        value   = values(:, indices);
      else
        value   = values(:, indices) .* weights(:, indices);
      end
      
    end
    
    %----- Add a data point to a plot
    function addDataPoint(handle, x, y)
      
      for iHandle = 1:numel(handle)
        if isnan(y(iHandle))
          continue;
        end
        
        
        xData         = get(handle(iHandle), 'XData');
        yData         = get(handle(iHandle), 'YData');
        xData(end+1)  = x;
        yData(end+1)  = y(iHandle);

        set ( handle(iHandle)   ...
            , 'XData' , xData   ...
            , 'YData' , yData   ...
            );
      end
      
    end
    
    %----- Set data point for a plot
    function setDataPoint(handle, x, y)
      
      for iHandle = 1:numel(handle)
        set ( handle(iHandle)         ...
            , 'XData' , x             ...
            , 'YData' , y(iHandle)    ...
            );
      end
      
    end

    %----- Move data points from a given plot to another
    function compileData1D(source, target, norm)
      
      sourceX             = get(source, 'XData');
      sourceY             = get(source, 'YData');
      targetX             = get(target, 'XData');
      targetY             = get(target, 'YData');
      targetBin           = get(target, 'UserData');
      
      % Consider only monotonically increasing points
      selected            = ( sourceY >= cummax(sourceY) );
      sourceX             = sourceX(selected);
      sourceY             = sourceY(selected);
      iSource             = binarySearch(sourceY, targetBin, -1, 2);
      iTarget             = binarySearch(targetX(1:end-1,1), sourceX(iSource), -1, 2);
      iTarget             = sub2ind(size(targetY), iTarget, (1:numel(iTarget))');

      % Ugly: undo drawing offset and scale
      freqScale           = ChoiceExperimentStats.FREQ_SCALE * (targetBin(2) - targetBin(1));
      targetBin           = repmat(targetBin, size(targetY,1), 1);
      targetY             = (targetY - targetBin) / freqScale;
      
      % Increment 1D histograms (exponential filter)
      addedY              = zeros(size(targetY));
      addedY(iTarget)     = 1;
      targetY             = ChoiceExperimentStats.EXP_SMOOTHING * addedY          ...
                          + (1 - ChoiceExperimentStats.EXP_SMOOTHING) * targetY   ...
                          ;
      targetY             = targetBin + targetY * freqScale;
                      
      % Set new content and erase old
      set(target, 'YData', targetY);
      set(source, 'XData', nan, 'YData', nan);
      
    end
    
    %----- Move data points from a given plot to another
    function norm = compileData2D(source, target)
      
      sourceX           = get(source, 'XData');
      sourceY           = get(source, 'YData');
      targetX           = get(target, 'XData');
      targetY           = get(target, 'YData');
      targetH           = get(target, 'CData');
      norm              = get(target, 'UserData');
      
      % Consider only monotonically increasing points
      selected          = ( sourceX >= cummax(sourceX) );
      sourceX           = sourceX(selected);
      sourceY           = sourceY(selected);
      iSource           = binarySearch(sourceX, targetX, -1, 2);
      iTarget           = binarySearch(targetY, sourceY(iSource), -1, 2);
      iTarget           = sub2ind(size(targetH), iTarget, 1:numel(iTarget));
      
      % Increment 2D histogram
      norm              = norm + 1;
      addedH            = zeros(size(targetH));
      addedH(iTarget)   = 1;
      targetH           = ChoiceExperimentStats.EXP_SMOOTHING * addedH          ...
                        + (1 - ChoiceExperimentStats.EXP_SMOOTHING) * targetH   ...
                        ;
                      
      % Set new content and erase old
      set(target, 'CData', targetH, 'UserData', norm);
      set(source, 'XData', nan, 'YData', nan);
      
    end
    
    %----- Accumulate histogram
    function histogramData(hHisto, hError, x, y, xCenters)

      % Get current values
      histX           = get(hHisto, 'XData');
      histY           = get(hHisto, 'YData');
      histW           = get(hHisto, 'ZData');

      % Locate bin to add to
      bin             = binarySearch(xCenters, x, -1, 2);
      if histW(bin) <= 0
        histY(bin)    = 0;
      end
      
      % Weighted average of bin content
      histX(bin)      = accumulateMean(histX(bin), histW(bin), x, 1);
      [histY(bin), histW(bin)]  ...
                      = accumulateMean(histY(bin), histW(bin), y, 1);
                
      % Set new values
      set(hHisto, 'XData', histX, 'YData', histY, 'ZData', histW);

      % Compute interval assuming binomial statistics
      if ~isempty(hError)
        [phat,pci]    = binointerval( histY(bin) * histW(bin)             ...
                                    , histW(bin)                          ...
                                    , ChoiceExperimentStats.ERR_INTERVAL  ...
                                    );
        errX          = get(hError, 'XData');
        errY          = get(hError, 'YData');
        errX((1:2) + 3*(bin-1)) = histX(bin);
        errY((1:2) + 3*(bin-1)) = pci(:);

        set(hError, 'XData', errX, 'YData', errY);
      end
      
    end

    %----- Extend 2D histogram to cover the given range
    function xRange = extendHistogram2D(handle, xRange, dx)

      for iH = 1:numel(handle)
        xBins       = get(handle(iH), 'XData');
        data        = get(handle(iH), 'CData');
        xRange      = [ floor(xRange(1) / dx), ceil(xRange(2)/dx) ] * dx;
        xRange(1)   = min(xRange(1), xBins(1));
        xRange(2)   = max(xRange(2), xBins(end));

        morePre     = xRange(1):dx:xBins(1) - dx/10;
        morePost    = xBins(end) + dx:dx:xRange(2) + dx/10;
        if isempty(morePre) && isempty(morePost)
          continue;
        end
        
        data        = padarray(data, [0 numel(morePre)] , 0, 'pre' );
        data        = padarray(data, [0 numel(morePost)], 0, 'post');
        set ( handle(iH)                                    ...
            , 'XData'     , [morePre xBins morePost]        ...
            , 'CData'     , data                            ...
            );
      end

    end
    
    %----- Extend 1D histogram to cover the given range
    function xRange = extendHistogram1D(handle, xRange, dx)

      for iH = 1:numel(handle)
        xData       = get(handle(iH), 'XData');
        yData       = get(handle(iH), 'YData');
        xBins       = get(handle(iH), 'UserData');
        xRange      = [ floor(xRange(1) / dx), ceil(xRange(2)/dx) ] * dx;
        xRange(1)   = min(xRange(1), xBins(1));
        xRange(2)   = max(xRange(2), xBins(end));

        morePre     = xRange(1):dx:xBins(1) - dx/10;
        morePost    = xBins(end) + dx:dx:xRange(2) + dx/10;
        if isempty(morePre) && isempty(morePost)
          continue;
        end
        
        xBins       = [morePre xBins morePost];
        xData       = repmat(xData(:,1), 1, numel(xBins));
        yData       = [ repmat(morePre, size(yData,1), 1)   ...
                      , yData                               ...
                      , repmat(morePost, size(yData,1), 1)  ...
                      ];
        yData(end,:)= nan;
        set ( handle(iH)                                    ...
            , 'XData'     , xData                           ...
            , 'YData'     , yData                           ...
            , 'UserData'  , xBins                           ...
            );
      end
      
    end
    
  end
  
end
