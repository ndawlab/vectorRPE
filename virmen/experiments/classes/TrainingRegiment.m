classdef TrainingRegiment < handle

  %------- Constants
  properties (Constant)

    COMM_INTERVAL       = 0.1;          % Time between network communications, in seconds
    DEFAULT_ID          = 'k'
    DEFAULT_SENSOR      = MovementSensor.BottomVelocity;
    DEFAULT_ANGSCALE    = nan           % Default value for viewangle scale factor
    FLUSH_REWARD        = 10            % Number of reward sizes for flushing
    VALVE_TIMEOUT       = 30*60         % Maximum reward valve open duration, in seconds
    
    TRIAL_DRAWING       = {'eradeTrial', 'pseudorandomTrial', 'leftOnlyTrial', 'rightOnlyTrial'};
    
    WEIGHT_RANGE        = [10 30]
    MAX_SESSIONS        = 3
    SESSION_MIN_FRAC    = 0.75
    
    MOTION_POLL         = 0.1;
    MOTION_SECONDS      = 20;
    MOTION_RANGE        = [-50 150];
    MOTION_LABEL        = {'v_x', 'v_y', 'speed'};
    
    DAYS                = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'}
    HOURS               = [9 17]        % Min/max hour of the day
    GUI_SIZE            = [0.98 1]
    GUI_COLOR           = [1 1 1] * 0.95
    OKAY_COLOR          = [0 1 0] * 0.9
    ERROR_COLOR         = [1 0 0]
    HILIGHT_COLOR       = [1 0 0] * 0.9
    REF_COLOR           = [255 225 0] / 255;
    REPOSITORY_BKG      = [255 250 214] / 255
    REPOSITORY_COLOR    = [115 75 0] / 255
    GUI_FONT            = 11
    MONITOR             = 1

    TODAY_COLOR         = [237 247 200] / 255
    LABEL_COLOR         = [191  92 113] / 255
    NTRIALS_COLOR       = [191  92 113] / 255
    CURSOR_COLOR        = [251 200 105] / 255
    WEIRD_COLOR         = [255 181 166] / 255
    INACTIVE_COLOR      = [130 122 121] / 255
    COMMENT_COLOR       = [255 249 171] / 255
    REF_PERFORMANCE     = 0:0.25:1
    NTRIALS_RANGE       = 400
    
    NUM_TRIALTYPES      = Choice.count()
    CHOICES             = Choice.all()
    CHOICE_NAME         = [arrayfun(@char, Choice.all(), 'UniformOutput', false), 'all']
%   	CHOICE_COLOR        = [138 163 49; 119 157 191] / 255
  	CHOICE_COLOR        = [0 0 0; 0 0 0]
    CHOICE_MARKER       = {'<', '>'}
    
    DATA_DIR            = 'data'
    IMAGE_DIR           = 'imaging'
    BACKUP_DIR          = 'backup'
    EXPERIMENT_DIR      = 'experiment'
    
    NDAYS_DATEVEC       = [365; 31; 1]
    
%     RGX_NUMBER          = '^\s*([+-]?\s*[0-9]*[.]?[0-9]*)'
    RGX_NUMBER          = '^\s*(.*?)(?:\s+.*[a-zA-Z].*)?$'
    RGX_DATE            = '^\s*([0-9]*)/?([0-9]*)/?([0-9]*)'
    RGX_TIME            = '^\s*([0-9]*):?([0-9]*)'
    RGX_VARNAME         = '(\w+)'
    RGX_HASNAME         = '^[Nn]ame(?![a-z])|(?<![A-Z])Name$'
    RGX_ISFILE          = '^[Ff]ile|(?<![A-Z])File|[Ee]xperiment'
    RGX_DIGIT           = '[0-9]+'
    RGX_ANINAME         = '(^|[/_-.])%s([/_-.])'
    REP_ANINAME         = '$1%s$2'
    EXISTS_FLAG         = ' (*)  '
    
  end
  
  %------- Private data
  properties (Access = protected, Transient)
    screenSize                    % For positioning GUI figures
    colorID                       % Colors for identifying various animals
    default                       % Defaults for various data formats
    lastPath                      % Last used path by various GUI options
    instruments                   % For communications
    
    figGUI                        % GUI window
    cursorMode                    % For creating data cursors
    axsSchedule                   % Axis for schedule display
    axsMotion                     % Axis for motion display
    linMotion                     % Lines for motion information display
    cntSettings                   % Container for setting controls
    cntRewards                    % Container for reward delivery controls
    chkStoreCode                  % Checkbox to enforce creating a backup of experiment code upon train
    lstRepository                 % Listbox for current branch in repository
    btnRepository                 % Button for current repository status
    btnValve                      % Button to open/close the reward delivery valve
    btnFlush                      % Button to flush reward lines e.g. to get rid of air
    btnReward                     % Button to give ad lib reward to animal
    edtNumRewards                 % Number of rewards delivered by btnReward
    edtInterReward                % Number of seconds between rewards delivered by btnReward
    cntControls                   % Container for button controls
    btnDaily                      % Button to edit daily data
    btnAdd                        % Button to add a new animal
    btnEdit                       % Button to edit info for an existing animal
    btnRemove                     % Button to remove an existing animal
    btnSave                       % Button to save to disk
    btnImport                     % Button to import animals/days from other regiments
    btnSubmit                     % Button to dismiss GUI and return selected value
    btnCancel                     % Button to dismiss GUI with a cancellation
    btnRestart                    % Button to restart Matlab
    cntAnimal                     % Container for per animal performance display
    guiAnimal                     % Display object handles per animal performance
    
    valveTimer                    % Safety timer for shutting off reward delivery valve
    actionStr                     % Task description string for submit button
    actionFcn                     % Callback for submit button
    cancelFcn                     % Callback for cancel button
  end
  
  %------- Public data
  properties (SetAccess = protected, Transient)
    dataSync                      % Output synchronizer
    dataPath                      % Directory in which all data will be stored
    dataFile                      % Data file path relative to dataPath
    backupFile                    % Relative path to backup to (will not overwrite, so maximum once per minute)
    rewardSize                    % Reward size for current session, per animal
  end
  properties (SetAccess = protected)
    adLibRewards                  % Number of ad lib rewards to deliver
    secInterReward                % Number of seconds between ad lib rewards
    doStoreCode                   % Whether the entire code directory should be regularly archived
    
    title                         % Description of regiment for book-keeping
    experiment                    % Versioned backups for all experiments ever used
    animal                        % Animal schedule and performance information
  end

  %________________________________________________________________________
  methods

    %----- Structure version to store an object of this class to disk
    function frozen = saveobj(obj)
      % Use class metadata to determine what properties to save
      metadata      = metaclass(obj);
      
      % Store all mutable and non-transient data
      for iProp = 1:numel(metadata.PropertyList)
        property    = metadata.PropertyList(iProp);
        if ~property.Transient && ~property.Constant
          frozen.(property.Name)  = obj.(property.Name);
        end
      end
      
      % Truncate some intra-struct transient data
      for name = fieldnames(obj.experiment)'
        for iVersion = 1:numel(obj.experiment.(name{:}))
          obj.experiment.(name{:})(iVersion).maze	= struct([]);
        end
      end
      
    end
    
    %----- Constructor: mode can be 'mustread' or 'overwrite'
    function obj = TrainingRegiment(title, filePath, mode, numDataSync)

      % Output synchronization
      if nargin > 3 && ~isempty(numDataSync)
        obj.dataSync  = OutputSynchronizer();
        obj.dataSync.waitForConnections(numDataSync);
      else
        obj.dataSync  = [];
      end
      
      
      % Require that the file exists if in 'mustread' mode
      if nargin < 3
        mode          = '';
      end
      if strcmpi(mode, 'mustread') && ~exist(filePath, 'file')
        throw(MException('TrainingRegiment:mustread', 'File %s does not exist.', filePath));
        
      % Attempt to load from existing file unless overwrite is desired
      elseif ~strcmpi(mode, 'overwrite') && exist(filePath, 'file')
        thawed                        = load(filePath, 'regiment');
        thawed.regiment.dataSync      = obj.dataSync;
        obj.dataSync                  = [];
        obj                           = thawed.regiment;
        [ obj.dataPath, obj.dataFile, obj.backupFile ]    ...
                                      = TrainingRegiment.decideDataFile(filePath);
        
        if ~isempty(title) && ~strcmp(title, obj.title)
          errordlg( { ['Regiment description in ' filePath ' does not match that expected by user:']  ...
                    , ['    "' obj.title '"']               ...
                    , 'in file vs. expected'                ...
                    , ['    "' title '"']                   ...
                    }                                       ...
                  , 'TrainingRegiment load error', 'modal'  ...
                  );
          obj     = [];
        end
        return;
      end
      
      % Formatting
      obj.screenSize                  = get(0, 'MonitorPosition');
%       obj.screenSize                  = obj.screenSize(2,:);
      monitor                         = obj.MONITOR;
      if monitor < 0
        monitor                       = monitor + size(obj.screenSize,1)+1;
      end
      obj.screenSize                  = obj.screenSize(max(min(monitor,end),1), :);
      obj.screenSize                  = obj.screenSize + [0, 50, 0, -100];
      obj.colorID                     = obj.decideColors(0);
      
      % Schedule format per day
      obj.default.session.start       = obj.HOURS(1);
      obj.default.session.duration    = 60;
      
      % Data collected for each maze session
      obj.default.block.isActive      = true;
      obj.default.block.comments      = '';
      obj.default.block.mainMazeID    = nan;
      obj.default.block.mazeID        = nan;
      obj.default.block.duration      = nan;
      obj.default.block.medianTrialDur= nan;
      obj.default.block.numTrials     = zeros(obj.NUM_TRIALTYPES, 1);
      obj.default.block.performance   = zeros(numel(obj.CHOICES), 1);
      obj.default.block.trialType     = int8([]);
      obj.default.block.choice        = int8([]);
      obj.default.block.numSalient    = uint8([]);
      obj.default.block.numDistract   = uint8([]);
      
      obj.default.run.isActive        = true;
      obj.default.run.comments        = '';
      obj.default.run.session         = nan;
      obj.default.run.duration        = 0;
      obj.default.run.rewardMiL       = 0;
      obj.default.run.label           = '';
      obj.default.run.dataFile        = {};
      obj.default.run.block           = repmat(obj.default.block, 0, 0);  % per block
      
      % Behavior and performance per day
      obj.default.data.date           = [];
      obj.default.data.weight         = [];
      obj.default.data.run            = repmat(obj.default.run, 0, 0);   % incremented on session or experiment change
      
      % Animal information format
      obj.default.animal.name                     = '';
      obj.default.animal.importAge                = 8;
      obj.default.animal.importDate               = [];
      obj.default.animal.normWeight               = 20;
      obj.default.animal.waterAlloc               = 1;
      %                                                              T5                      T10                      T15 
      obj.default.animal.rewardFactor             = [ 2, 1.5, 1.2, 1, 1, 1.2, 1.2, 1.2, 1.2, 1.2, 1.4, 1.5, 1.6, 1.8, 1.8, 1.8  ...
                                                    ; 1, 1  , 1  , 1, 1, 1  , 1  , 1  , 1  , 1  , 1.2, 1.2, 1.2, 1.2, 1.2, 1.2  ...
                                                    ];
      obj.default.animal.isActive                 = true;
      obj.default.animal.motionBlurRange          = [];
      obj.default.animal.protocol                 = @PoissonBlocksReboot;
      obj.default.animal.experiment               = '';
      obj.default.animal.stimulusBank             = '';
      obj.default.animal.refImageFiles            = {};
      obj.default.animal.imagingDepth             = 200;
      obj.default.animal.mainMazeID               = 1;
      obj.default.animal.autoAdvance              = true;
      obj.default.animal.trialDrawMethod          = {'TRIAL_DRAWING', 1};
      obj.default.animal.session                  = repmat(obj.default.session, 1, numel(obj.DAYS));
      obj.default.animal.data                     = repmat(obj.default.data, 0, 0);   % per day
      obj.default.animal.virmenFrictionCoeff      = nan;
      obj.default.animal.virmenSensor             = TrainingRegiment.DEFAULT_SENSOR;
      obj.default.animal.virmenDisplacementPerCm  = 1;
      obj.default.animal.virmenRotationsPerRev    = TrainingRegiment.DEFAULT_ANGSCALE;
      
      % Instrumentation control
      obj.valveTimer                  = timer ( 'StartDelay'    , TrainingRegiment.VALVE_TIMEOUT  ...
                                              , 'TimerFcn'      , @obj.turnOffValve               ...
                                              , 'ExecutionMode' , 'singleShot'                    ...
                                              );
      obj.instruments                 = struct();
      obj.instruments.position        = [0 0 0 0];
      obj.instruments.velocity        = [0 0 0 0];
      if RigParameters.hasDAQ
        obj.instruments.motionTimer   = timer ( 'BusyMode'      , 'drop'                          ...
                                              , 'TimerFcn'      , @obj.pollMotion                 ...
                                              , 'ExecutionMode' , 'fixedRate'                     ...
                                              , 'TasksToExecute', inf                             ...
                                              , 'Period'        , TrainingRegiment.MOTION_POLL    ...
                                              );
      end
      
      % Initialize data
      obj.figGUI                      = [];
      obj.guiAnimal                   = struct([]);
      
      obj.actionStr                   = {};
      obj.actionFcn                   = [];
      obj.cancelFcn                   = [];
      obj.adLibRewards                = 5;
      obj.secInterReward              = 2;
      obj.rewardSize                  = [];
      obj.doStoreCode                 = false;
      
      obj.title                       = title;
      obj.experiment                  = struct();
      obj.animal                      = repmat(obj.default.animal, 0, 0);
      if ~isempty(filePath)
        [ obj.dataPath, obj.dataFile, obj.backupFile ]    ...
                                      = TrainingRegiment.decideDataFile(filePath);
      end
      
      if ~isempty(obj.dataPath)
        obj.lastPath                  = obj.dataPath;
      end
      
    end
    
    %----- Destructor
    function delete(obj)
        
      if ~isempty(obj.valveTimer)
        stop(obj.valveTimer);
        delete(obj.valveTimer);
      end
      if ~isempty(obj.dataSync)
        delete(obj.dataSync);
      end
      
    end
    
    %----- Merge data from another object into this one
    function merge(obj, other)
      for exper = fieldnames(other.experiment)'
        if isfield(obj.experiment, exper{:})
          for iVer = 1:numel(other.experiment.(exper{:}))
            obj.experiment.(exper{:})  = mergeSimilar ( obj.experiment.(exper{:})       ...
                                                      , other.experiment.(exper{:})     ...
                                                      , 'version'                       ...
                                                      );
          end
        else
          obj.experiment.(exper{:})   = other.experiment.(exper{:});
        end
      end
      obj.animal        = [obj.animal, other.animal];
      obj.colorID       = obj.decideColors(numel(obj.animal));
      obj.rewardSize    = [obj.rewardSize, other.rewardSize];
    end
    
    %----- Sort animals by name
    function sort(obj)
      
      keys                  = cell(numel(obj.animal), 0);
      for iAni = 1:numel(obj.animal)
        % Extract sorting fields
        [digits, others]    = regexp(obj.animal(iAni).name, obj.RGX_DIGIT, 'match', 'split');
        
        % Pad table of keys
        iEmpty              = size(keys,2) + 1;
        nColumns            = numel(digits) + numel(others);
        if nColumns >= iEmpty
          keys(:, max(1:2:nColumns,iEmpty)) = {''};
          keys(:, max(2:2:nColumns,iEmpty)) = {-inf};
        end
        
        % Register character fields
        index               = 1;
        for iOth = 1:numel(others)
          keys{iAni,index}  = others{iOth};
          index             = index + 2;
        end
        
        % Register numeric fields
        index               = 2;
        for iDig = 1:numel(digits)
          keys{iAni,index}  = str2double(digits{iDig});
          index             = index + 2;
        end
      end
      
      % Sort by columns
      [~, order]            = sortrows(keys, 1:size(keys,2));
      obj.animal            = obj.animal(order);
      
    end
    
    %----- Merge animals by name
    function compactify(obj)
      
      for iAni = numel(obj.animal):-1:2
        jAni              = find(strcmp({obj.animal(1:iAni-1).name}, obj.animal(iAni).name), 1, 'first');
        if isempty(jAni)
          continue;
        end
        
        obj.animal(jAni).data(end + (1:numel(obj.animal(iAni).data))) ...
                          = obj.animal(iAni).data;
        obj.animal(iAni)  = [];
      end
      
    end
    
    %----- Set main and backup file paths
    function setDataFile(obj, filePath)

      [ obj.dataPath, obj.dataFile, obj.backupFile ]    ...
                      = TrainingRegiment.decideDataFile(filePath);
      if isempty(obj.lastPath)
        obj.lastPath  = obj.dataPath;
      end
      
    end
    
    %----- Returns an absolute path relative to dataPath; will set dataPath
    %      to the current directory if not already set
    function path = absolutePath(obj, path)
      if isempty(obj.dataPath)
        obj.dataPath  = pwd;
      end
      
      import java.io.File;
      if ~java.io.File(path).isAbsolute()
        path          = fullfile(obj.dataPath, path);
      end
      path            = strrep(path, '\', '/');
    end
    
    %----- Returns a path relative to dataPath
    %      TODO : This does not fully handle filesystem path format differences
    function path = relativePath(obj, path)
      refPath         = regexprep(obj.dataPath, '\'  , '[\\\\/]+');
      refPath         = regexprep(refPath     , '[.]', '[.]');
      refPath         = ['^' refPath '[\\/]+'];
      path            = regexprep(path, refPath, '', 'once');
      path            = strrep(path, '\', '/');
    end

    %----- Locates figure files a.k.a. online performance display of a given data file
    function [figFile, logFile] = findLogFigures(obj, dataFile)
      
      logFile             = obj.absolutePath(dataFile);
      [path,name,~]       = parsePath(logFile);
      figList             = dir(fullfile(path, [name '*.fig']));
      figFile             = strcat([path filesep], {figList.name});
      
    end
    
    %----- Save this object to the pre-specified data file, with once-per-day backup
    function [data, backup] = save(regiment)
      % Default output values
      data            = [];
      backup          = [];
      
      % Do nothing if nothing is defined
      if isempty(regiment.animal)
        return;
      end
      
      % Save paths
      regiment.backupFile = TrainingRegiment.decideBackupFile(regiment.dataFile);
      dataFile        = regiment.absolutePath(regiment.dataFile);
      backupFile      = regiment.absolutePath(regiment.backupFile);
      
      % If the backup does not exist but a previous save does, back it up
      if ~exist(backupFile, 'file') && exist(dataFile, 'file')
        makepath(backupFile);
        movefile(dataFile, backupFile);
        backup    = backupFile;
      end
      
      % Save to disk, creating the save directory if necessary
      makepath(dataFile);
      save(dataFile, 'regiment');
      data        = dataFile;
    end
    
    %----- Programatically close GUIs
    function figPosition = closeGUI(obj)
    
      obj.closeInstruments();

      if ishghandle(obj.figGUI)
        figPosition   = get(obj.figGUI, 'Position');
        delete(obj.figGUI);
        obj.figGUI    = [];
        obj.btnEdit   = [];
        obj.btnValve  = [];
        obj.guiAnimal = struct([]);
      elseif nargout > 0
        figPosition   = obj.computeFigurePos(obj.GUI_SIZE);
      end

    end
    
    %----- Programatically focus on the valve open/close button
    function selectValveButton(obj)
      if ishghandle(obj.figGUI)
        uicontrol(obj.btnValve);
      end
    end
    
    %----- Ask user to select an animal (saves to disk if user confirms)
    function guiSelectAnimal(obj, actionStr, actionFcn, cancelFcn)
      
      % Show GUI with user specified submit button text
      if nargin > 1
        obj.actionStr         = actionStr;
        obj.actionFcn         = actionFcn;
        obj.cancelFcn         = cancelFcn;
      else
        obj.actionStr         = {};
        obj.actionFcn         = [];
        obj.cancelFcn         = [];
      end
      obj.drawGUI();
      
      % Select the best candidate
      [iAni, iSession, ~]     = obj.whatIsNext();
      if ~isempty(iAni)
        obj.fcnSelectAnimal(obj.guiAnimal(iAni).panel, [], iAni, iSession);
      end
      
    end
    
    %----- Store summary data for behavioral session
    function success = recordBehavior(obj, animal, log, newBlocks)
      
      % Locate animal to store data for
      iAni                    = find(strcmp({obj.animal.name}, animal.name), 1, 'first');
      if isempty(iAni)
        errordlg(['Animal "' animal.name '" does not exist in this database.'], 'Invalid animal name', 'modal');
        success               = false;
        return;
      end
      
      % Locate slot in which to store
      timeStamp               = obj.dateStamp();
      if      isempty(obj.animal(iAni).data)                                        ...
          ||  ~isequal(obj.animal(iAni).data(end).date, timeStamp)
        % Create a new record for a new day
        obj.animal(iAni).data(end+1).date             = timeStamp;
        obj.animal(iAni).data(end).weight             = nan;
        obj.animal(iAni).data(end).run                = obj.default.run;
        
      elseif  isempty(obj.animal(iAni).data(end).run)                              ...
          ||  obj.animal(iAni).data(end).run(end).session ~= animal.sessionIndex   ...
          ||  ~strcmp(obj.animal(iAni).data(end).run(end).label, log.label)
        % Create a new entry if session or maze type has changed
        obj.animal(iAni).data(end).run(end+1)         = obj.default.run;
      end
      
      % Collect information
      run                     = obj.animal(iAni).data(end).run(end);
      run.session             = animal.sessionIndex;
      run.label               = log.label;
      run.dataFile            = obj.relativePath(log.logFile);
      
      for iBlock = newBlocks
        newBlock              = log.block(iBlock);
        run.duration          = run.duration  + newBlock.duration/60;   % convert to minutes
        run.rewardMiL         = run.rewardMiL + newBlock.rewardMiL;

        % Start a new record for the block
        run.block(end+1)                    = obj.default.block;
        run.block(end).mainMazeID           = newBlock.mainMazeID;
        run.block(end).mazeID               = newBlock.mazeID;
        run.block(end).duration             = newBlock.duration/60;     % convert to minutes
        run.block(end).medianTrialDur       = median([newBlock.trial.duration]);
        
        
        for iTrial = 1:numel(newBlock.trial)
          % Accumulate info for current trial
          trialType             = newBlock.trial(iTrial).trialType;
          aniChoice             = newBlock.trial(iTrial).choice;
          if ~iscell(newBlock.trial(iTrial).cuePos)
            keyboard
          end
          numCues               = cellfun(@numel, newBlock.trial(iTrial).cuePos);
          run.block(end).trialType(end+1)   = trialType;
          run.block(end).choice(end+1)      = aniChoice;
          run.block(end).numSalient(end+1)  = numCues(trialType);
          run.block(end).numDistract(end+1) = sum(numCues) - run.block(end).numSalient(end);

          % Accumulate statistics for the current record
          if aniChoice < Choice.nil
            [run.block(end).performance(trialType), run.block(end).numTrials(trialType)]    ...
                                = accumulateMean( run.block(end).performance(trialType)     ...
                                                , run.block(end).numTrials(trialType)       ...
                                                , aniChoice == trialType                    ...
                                                , 1                                         ...
                                                );
          else
            % Special case to record violation trials
            run.block(end).numTrials(end)   = run.block(end).numTrials(end) + 1;
          end
        end
      end
      obj.animal(iAni).data(end).run(end)   = run;
      
      
      % Check if experiment versioning has changed -- note that this
      % assumes that the version index is the same for all blocks in the
      % log (which should be the case because it should not be possible for
      % the code to have changed in the middle of a running session)
      [record, iVersion]      = obj.findOrAddVersion( log.version(newBlock.versionIndex)    ...
                                                    , obj.animal(iAni).experiment           ...
                                                    , false                                 ...
                                                    );
      
      % Look up animal-version association by name
      if isfield(record, obj.animal(iAni).name)
        assoc                 = record.(obj.animal(iAni).name);
      else
        assoc                 = struct([]);
      end
      
      % Check if an entry already exists for the day to be added
      iRun                    = numel(obj.animal(iAni).data(end).run);
      iDay                    = [];
      for iAssoc = 1:numel(assoc)
        if isequal(assoc(iAssoc).date, obj.animal(iAni).data(end).date)
          iDay                = iAssoc;
          break;
        end
      end
      if isempty(iDay)
        assoc(end+1).date     = obj.animal(iAni).data(end).date;
        assoc(end).run        = iRun;
      elseif isempty(find(assoc(iDay).run == iRun, 1, 'first'))
        assoc(iDay).run(end+1)= iRun;
      end

      % Store the updated animal-version association
      obj.experiment.(log.version(newBlock.versionIndex).name)(iVersion).(obj.animal(iAni).name)  ...
                              = assoc;
      
      
      % Return success flag
      success                 = true;
    
    end
    
    %----- Generate a consistent behavioral log file path
    function [logFile, imageFile, syncFile] = whichLog(obj, trainee)

      % Obtain specifications for the current experiment
      if exist(trainee.experiment, 'file')
        vr                = load(trainee.experiment);
        experLabel        = vr.exper.worlds{1}.name(1);
      else
        errordlg( { ['A valid experiment must be specified for animal ' trainee.name '.']   ...
                  , ['Currently it is set to "' trainee.experiment '"']                     ...
                  }                                                                         ...
                , 'Invalid experiment'                                                      ...
                , 'modal'                                                                   ...
                );
        return;
      end

      % Decide name and path for log file
      dateStamp           = datestr(now, 'yyyymmdd');
      [~, logName]        = parsePath(obj.dataFile);
      logFile             = fullfile( obj.dataPath                          ...
                                    , obj.DATA_DIR                          ...
                                    , trainee.name                          ...
                                    , sprintf ( '%s_%s_%s_%s.mat'           ...
                                              , logName                     ...
                                              , trainee.name                ...
                                              , experLabel                  ...
                                              , dateStamp                   ...
                                              )                             ...
                                    );
                                  
      % Generate imaging data file name 
      if nargout > 1
        imageFile         = fullfile( obj.dataPath                          ...
                                    , obj.IMAGE_DIR                         ...
                                    , trainee.name                          ...
                                    , sprintf ( '%s/%s_%s'                  ...
                                              , dateStamp                   ...
                                              , trainee.name                ...
                                              , dateStamp                   ...
                                              )                             ...
                                    );
      end
                                  
      % Generate Clampex data file name 
      if nargout > 2
        syncFile          = fullfile( obj.dataPath                          ...
                                    , obj.DATA_DIR                          ...
                                    , trainee.name                          ...
                                    , sprintf ( '%s_%s'                     ...
                                              , trainee.name                ...
                                              , dateStamp                   ...
                                              )                             ...
                                    );
      end
      
    end
    
    %----- Get the list of sessions for the given day (1 = Monday)
    function info = schedule(obj, dayIndex)
      
      % Obtain all sessions for the day
      info                        = struct([]);
      for iAni = 1:numel(obj.animal)
        sessions                  = obj.animal(iAni).session(:, dayIndex);
        for iSession = 1:numel(sessions)
          info(end+1).animalName  = obj.animal(iAni).name;
          info(end).animalIndex   = iAni;
          info(end).sessionIndex  = iSession;
          info(end).start         = sessions(iSession).start;
          info(end).duration      = sessions(iSession).duration;
        end
      end
      
      % Sort by start time
      if ~isempty(info)
        [~, indices]  = sort([info.start]);
        info          = info(indices);
      end
      
    end
    
    %----- Get the index of the animal by name
    function index = whichAnimal(obj, name, allowMissing)
      for iAni = 1:numel(obj.animal)
        if strcmp(obj.animal(iAni).name, name)
          index   = iAni;
          return;
        end
      end
      
      if nargin > 2 && allowMissing
        index     = [];
      else
        error('whichAnimal:notFound', 'Animal "%s" not found in database.', name);
      end
    end
    
    %----- Compute the total amount of reward given to an animal for a
    %      given date (provided as [year,month,day]) and assumed reward size
    function rewarded = totalRewards(obj, animalName, date, rewardSize)
      
      % Default arguments
      if nargin < 4
        rewardSize    = RigParameters.rewardSize;
      end
      if numel(date) > 3
        date          = date(1:3);
      end
      rewarded        = 0;
      
      % Get the animal index and look up behavioral data for the day
      iAni            = whichAnimal(obj, animalName);
      iDay            = numel(obj.animal(iAni).data);
      while iDay > 0 && ~isequal(obj.animal(iAni).data(iDay).date, date)
        iDay          = iDay - 1;
      end
      if iDay < 1
        return;
      end


      % Sum up all blocks for the day
      maze            = obj.animal(iAni).data(iDay).run;
      if ~isfield(maze, 'rewardMiL')
        % For old data have to manually calculate the reward
        for iMaze = 1:numel(maze)
          for iBlock = 1:numel(maze(iMaze).block)
            rewarded  = rewarded                                              ...
                      + sum ( vertcat(maze(iMaze).block(iBlock).numTrials)    ...
                           .* vertcat(maze(iMaze).block(iBlock).performance)  ...
                            )                                                 ...
                      * rewardSize                                            ...
                      ;
          end
        end
          
      else
        % If reward info was stored, use it
        for iMaze = 1:numel(maze)
          rewarded    = rewarded + maze(iMaze).rewardMiL;
        end
      end
      
    end
    
    %----- Rewire file paths to be the best guess of existing files
    function guessPaths(obj, useAbsolute, verbose)
      
      if nargin < 2
        useAbsolute = false;
      end
      if nargin < 3
        verbose     = true;
      end
      
      % Obtain a reference path list in order of preference
      if isempty(obj.dataPath)
        searchPath  = {};
        fprintf ( [ 'WARNING:  This object is not associated with a file on disk.\n'  ...
                    '          The current directory %s\n'                            ...
                    '          will be used as the preferred location.'               ...
                  ]                                                                   ...
                , searchPath{1}                                                      ...
                );
      else
        searchPath  = {obj.dataPath};
      end
      searchPath    = [ searchPath                                ...
                      , fullfile(obj.dataPath,obj.EXPERIMENT_DIR) ...
                      , {pwd}                                     ...
                      , regexp(path, ';', 'split')                ...
                      ];
      
      
      % Recursively locate everything that should be a file and correct
      % their paths if necessary
      obj.animal      = obj.fixPaths(obj.animal    , '', searchPath, useAbsolute, verbose);
      obj.experiment  = obj.fixPaths(obj.experiment, '', searchPath, useAbsolute, verbose);
      
    end
    
    %----- Locate info on an experiment by version
    function [experName, iVersion] = whichVersion(obj, name, version)
      
      % Optionally the user can specify a version struct with name and
      % mazeVersion fields (e.g. as from ExperimentLog)
      if nargin < 3
        cfg             = name;
      else
        cfg.name        = name;
        cfg.mazeVersion = version;
      end
      
      % Find the record and optionally load the experiment file
      [~, iVersion]     = obj.findOrAddVersion(cfg, [], true);
      experName         = cfg.name;
  
    end
    
    %----- Locate objects in a versioned experiment 
    function objects = whichObjects(obj, experName, iVersion, maze, mazeID, storeObjectProp)

      % Load the experiment file if not already present
      record            = obj.experiment.(experName)(iVersion);
      if isempty(record.exper)
        load(obj.absolutePath(record.file));
        record.exper    = exper;
        record.exper.enableCallbacks();
      end

      % If maze info is not already cached, look it up
      if numel(record.maze) < mazeID || isempty(record.maze(mazeID).id)
        record.maze(mazeID).id            = mazeID;
        
        % Adjust world parameters as specified
        for var = fieldnames(maze.variable)'
          if      isfield(record.exper.variables, var{:})                           ... HACK for Ben's worlds
              &&  ~strcmp(record.exper.variables.(var{:}), maze.variable.(var{:}))
            record.exper.variables.(var{:}) = maze.variable.(var{:});
          end
        end

        % Store objects under their names
        for iObj = 1:numel(record.exper.worlds{maze.world}.objects)
          object        = record.exper.worlds{maze.world}.objects{iObj};
          for field = fieldnames(object)'
            if ~isempty(regexp(field{:}, storeObjectProp, 'once'))
              record.maze(mazeID).(object.name).(field{:})  ...
                        = object.(field{:});
            end
          end
        end
      end
      
      % Store for posterity and set return values 
      obj.experiment.(experName)(iVersion)  = record;
      objects           = record.maze(mazeID);

    end
    
  end


  %________________________________________________________________________
  methods (Access = protected)

    %----- Turn off DAQ lines and timers so that there is no competition
    function closeInstruments(obj)

      try
        % Close valve to be safe
        obj.turnOffValve();

        % Stop DAQ interface
        nidaqPulse('end');
      catch err
        displayException(err);
      end
      
      % Reset Arduino sensor
      if RigParameters.hasDAQ
        stop(obj.instruments.motionTimer);
        arduinoReader('end', true);
      end

    end
    
    %----- Deduce what session is next to be run
    function [iAni, iSession, iDay] = whatIsNext(obj)
      
      % Get day to check the schedule of
      iAni            = [];
      iSession        = [];
      iDay            = day2index();
      timeStamp       = obj.dateStamp();
      timetable       = obj.schedule(iDay);
      
      if isempty(timetable)
        % If the schedule is empty, return a nonsensical value
        return;
      end
      

      % Find the last session that has been run today
      candidate       = nan;
      for iSlot = numel(timetable):-1:1
        jAni          = timetable(iSlot).animalIndex;
        jSession      = timetable(iSlot).sessionIndex;
        
        % Skip inactive animals
        if ~obj.animal(jAni).isActive
          continue;
        end
        
        % If no data has been taken, this animal is a candidate
        if    isempty(obj.animal(jAni).data)  ...
          || ~isequal(obj.animal(jAni).data(end).date, timeStamp)
          candidate   = iSlot;
          continue;
        end
        
        % Compute total amount of time spent in this session
        duration      = 0;
        mazes         = obj.animal(jAni).data(end).run;
        for iMaze = 1:numel(mazes)
          if mazes(iMaze).session == jSession
            duration  = duration + mazes(iMaze).duration;
          end
        end

        % If the animal has not run long enough, it is it, otherwise it's the next 
        if duration < obj.SESSION_MIN_FRAC * timetable(iSlot).duration
          candidate   = iSlot;
        else
          candidate   = iSlot + 1;
        end
        break;
      end
      
      % Record if we've found a candidate
      if isfinite(candidate) && candidate <= numel(timetable)
        iAni          = timetable(candidate).animalIndex;
        iSession      = timetable(candidate).sessionIndex;
      end
      
    end
    
    %----- Redraw controls on the GUI
    function redrawGUI(obj)
    
      if ~isempty(obj.figGUI) && ishghandle(obj.figGUI)
        children      = get(obj.figGUI, 'Children');
        for iChild = 1:numel(children)
          delete(children(iChild));
        end
        obj.guiAnimal = struct([]);
        
      else
        figPosition   = obj.computeFigurePos(obj.GUI_SIZE);
        obj.figGUI    = figure( 'Name'            , ['Animal Training Regiment : ' fullfile(obj.dataPath,obj.dataFile)]  ...
                              , 'Units'           , 'pixels'                              ...
                              , 'Position'        , figPosition                           ...
                              , 'Menubar'         , 'none'                                ...
                              , 'NumberTitle'     , 'off'                                 ...
                              , 'Resize'          , 'on'                                  ...
                              , 'Color'           , obj.GUI_COLOR                         ...
                              , 'Visible'         , 'off'                                 ...
                              , 'CloseRequestFcn' , @obj.fcnCancelAction                  ...
                              );
      end

    end
    
    %----- Draw GUI on screen and set up action handlers
    function drawGUI(obj)
      
      % Create GUI figure on screen (replaces any previous one)
      obj.redrawGUI();
      obj.cursorMode          = datacursormode(obj.figGUI);
      set(obj.figGUI, 'Visible', 'off');
      
      % Create repository branch list and status
      [branches, iCurrent]    = TrainingRegiment.getRepositoryInfo();
      obj.lstRepository       = uicontrol ( 'Parent'              , obj.figGUI                            ...
                                          , 'Units'               , 'normalized'                          ...
                                          , 'Position'            , [0.06 0.96 0.1 0.03]                  ...
                                          , 'BackgroundColor'     , TrainingRegiment.REPOSITORY_BKG       ...
                                          , 'ForegroundColor'     , TrainingRegiment.REPOSITORY_COLOR     ...
                                          , 'Style'               , 'popupmenu'                           ...
                                          , 'String'              , branches                              ...
                                          , 'Value'               , iCurrent                              ...
                                          , 'UserData'            , iCurrent                              ...
                                          , 'FontSize'            , obj.GUI_FONT + 2                      ...
                                          , 'FontWeight'          , 'bold'                                ...
                                          , 'Callback'            , @obj.fcnSwitchRepository              ...
                                          , 'KeyPressFcn'         , @obj.buttonKeypress                   ...
                                          , 'TooltipString'       , 'Switch git branch'                   ...
                                          );
      obj.btnRepository       = uicontrol ( 'Parent'              , obj.figGUI                            ...
                                          , 'Units'               , 'normalized'                          ...
                                          , 'Position'            , [0.18 0.96 0.05 0.03]                 ...
                                          , 'Style'               , 'pushbutton'                          ...
                                          , 'FontSize'            , obj.GUI_FONT + 2                      ...
                                          , 'FontWeight'          , 'bold'                                ...
                                          , 'Callback'            , @obj.fcnCheckRepository               ...
                                          , 'KeyPressFcn'         , @obj.buttonKeypress                   ...
                                          , 'TooltipString'       , 'Refresh git status'                  ...
                                          );
      executeCallback(obj.btnRepository, 'Callback', [], false);
                          
      % Create week schedule display
      obj.axsSchedule         = axes( 'Parent'          , obj.figGUI                                      ...
                                    , 'Color'           , [1 1 1]*0.8                                     ...
                                    , 'Units'           , 'normalized'                                    ...
                                    , 'Position'        , [0.03 0.77 0.24 0.16]                           ...
                                    , 'Box'             , 'on'                                            ...
                                    , 'FontSize'        , obj.GUI_FONT - 2                                ...
                                    , 'Layer'           , 'top'                                           ...
                                    , 'XAxisLocation'   , 'top'                                           ...
                                    , 'XLim'            , [0.5, 0.5+numel(obj.DAYS)]                      ...
                                    , 'YLim'            , obj.HOURS                                       ...
                                    , 'YGrid'           , 'on'                                            ...
                                    , 'YDir'            , 'reverse'                                       ...
                                    , 'XTick'           , 1:numel(obj.DAYS)                               ...
                                    , 'XTickLabel'      , obj.DAYS                                        ...
                                    , 'YTick'           , obj.HOURS(1):2:obj.HOURS(2)                     ...
                                    , 'YTickLabel'      , arrayfun( @(x) sprintf('%02d:00',mod(x-1,24)+1) ...
                                                                  , obj.HOURS(1):2:obj.HOURS(2)           ...
                                                                  , 'UniformOutput', false                ...
                                                                  )                                       ...
                                    );
                                  
      % Create animal motion display
      obj.axsMotion           = axes( 'Parent'          , obj.figGUI                                      ...
                                    , 'Color'           , [1 1 1]                                         ...
                                    , 'Units'           , 'normalized'                                    ...
                                    , 'Position'        , [0.03 0.5 0.24 0.25]                            ...
                                    , 'Box'             , 'on'                                            ...
                                    , 'FontSize'        , obj.GUI_FONT - 1                                ...
                                    , 'XLim'            , [0, obj.MOTION_SECONDS]                         ...
                                    , 'YLim'            , obj.MOTION_RANGE                                ...
                                    , 'YGrid'           , 'on'                                            ...
                                    , 'Layer'           , 'top'                                           ...
                                    );
      xlabel(obj.axsMotion, 'Time (s)', 'FontSize', obj.GUI_FONT - 1);
      ylabel(obj.axsMotion, 'cm/s'    , 'FontSize', obj.GUI_FONT - 1);
      
      obj.linMotion           = gobjects(1, numel(obj.MOTION_LABEL)+1);
      clrMotion               = [ linspecer(numel(obj.MOTION_LABEL)-1, 'qualitative')   ...
                                ; 0 0 0                                                 ...
                                ];
      motionX                 = 0:obj.MOTION_POLL:obj.MOTION_SECONDS;
      motionY                 = nan(size(motionX));
      for iMotion = 1:numel(obj.MOTION_LABEL)
        obj.linMotion(iMotion)= line( 'Parent'          , obj.axsMotion                                   ...
                                    , 'XData'           , motionX                                         ...
                                    , 'YData'           , motionY                                         ...
                                    , 'Color'           , clrMotion(iMotion,:)                            ...
                                    , 'LineWidth'       , 0.5 + (iMotion > 2)                             ...
                                    , 'UserData'        , 1                                               ...
                                    );
      end
      obj.linMotion(end)      = line( 'Parent'          , obj.axsMotion                                   ...
                                    , 'XData'           , [0 0]                                           ...
                                    , 'YData'           , obj.MOTION_RANGE                                ...
                                    , 'Color'           , TrainingRegiment.REF_COLOR                      ...
                                    , 'LineWidth'       , 2                                               ...
                                    );
      legend(obj.linMotion(1:numel(obj.MOTION_LABEL)), obj.MOTION_LABEL, 'FontSize', obj.GUI_FONT - 1, 'Location', 'NorthWest', 'Box', 'off');
                                  
      % Checkboxes for various settings
      obj.cntSettings         = uiflowcontainer ( 'v0'                                                    ...
                                                , 'Parent'        , obj.figGUI                            ...
                                                , 'Units'         , 'normalized'                          ...
                                                , 'Position'      , [0.007 0.37 0.27 0.09]                ...
                                                , 'FlowDirection' , 'TopDown'                             ...
                                                );
      
      % Ad lib reward delivery controls
      obj.chkStoreCode        = uicontrol       ( 'Parent'              , obj.cntSettings                 ...
                                                , 'Style'               , 'checkbox'                      ...
                                                , 'String'              , 'Archive code whenever an experiment is run'  ...
                                                , 'FontSize'            , obj.GUI_FONT + 1                ...
                                                , 'Callback'            , {@obj.fcnToggleSetting, 'doStoreCode'}        ...
                                                , 'KeyPressFcn'         , @obj.buttonKeypress             ...
                                                , 'Value'               , obj.doStoreCode                 ...
                                                );
      obj.cntRewards          = uigridcontainer ( 'v0'                                                    ...
                                                , 'Parent'            	, obj.cntSettings                 ...
                                                , 'GridSize'            , [1, 7]                          ...
                                                , 'HorizontalWeight'    , [6 6 1 3 2 5 2]                 ...
                                                );
      obj.btnValve            = uicontrol       ( 'Parent'              , obj.cntRewards                  ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , 'Open valve'                    ...
                                                , 'FontSize'            , obj.GUI_FONT + 1                ...
                                                , 'Callback'            , @obj.fcnToggleReward            ...
                                                , 'KeyPressFcn'         , @obj.buttonKeypress             ...
                                                , 'UserData'            , false                           ...
                                                , 'TooltipString'       , 'Open/close reward delivery valve'  ...
                                                );
      obj.btnFlush            = uicontrol       ( 'Parent'              , obj.cntRewards                  ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , sprintf('Flush %.2g uL', obj.FLUSH_REWARD * RigParameters.rewardSize*1000)  ...
                                                , 'FontSize'            , obj.GUI_FONT + 1                ...
                                                , 'Callback'            , {@obj.fcnDeliverReward, 'FLUSH_REWARD'}                     ...
                                                , 'KeyPressFcn'         , @obj.buttonKeypress             ...
                                                );
                                uicontrol       ( 'Parent'              , obj.cntRewards                  ...
                                                , 'Style'               , 'text'                          ...
                                                );
      obj.btnReward           = uicontrol       ( 'Parent'              , obj.cntRewards                  ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , 'Give'                          ...
                                                , 'FontSize'            , obj.GUI_FONT + 1                ...
                                                , 'Callback'            , {@obj.fcnDeliverReward, 'adLibRewards', 'secInterReward'}   ...
                                                , 'KeyPressFcn'         , @obj.buttonKeypress             ...
                                                , 'TooltipString'       , 'Deliver ad lib rewards'        ...
                                                );
      obj.edtNumRewards       = uicontrol       ( 'Parent'              , obj.cntRewards                  ...
                                                , 'Style'               , 'edit'                          ...
                                                , 'String'              , num2str(obj.adLibRewards)       ...
                                                , 'FontSize'            , obj.GUI_FONT + 1                ...
                                                , 'BackgroundColor'     , [1 1 1]                         ...
                                                , 'Callback'            , {@obj.fcnEditProperty, 'adLibRewards'}                      ...
                                                , 'KeyPressFcn'         , {@obj.dispatchKeypress, obj.btnReward}                      ...
                                                );
                                uicontrol       ( 'Parent'              , obj.cntRewards                  ...
                                                , 'Style'               , 'edit'                          ...
                                                , 'String'              , sprintf('x %.2guL every', RigParameters.rewardSize*1000)    ...
                                                , 'FontSize'            , obj.GUI_FONT + 1                ...
                                                , 'BackgroundColor'     , obj.GUI_COLOR                   ...
                                                , 'Enable'              , 'inactive'                      ...
                                                );
      obj.edtInterReward      = uicontrol       ( 'Parent'              , obj.cntRewards                  ...
                                                , 'Style'               , 'edit'                          ...
                                                , 'String'              , sprintf('%.2gs', obj.secInterReward)                        ...
                                                , 'FontSize'            , obj.GUI_FONT + 1                ...
                                                , 'BackgroundColor'     , [1 1 1]                         ...
                                                , 'Callback'            , {@obj.fcnEditProperty, 'secInterReward', 's'}               ...
                                                , 'KeyPressFcn'         , {@obj.dispatchKeypress, obj.btnReward}                      ...
                                                );

      % Create action buttons
      obj.cntControls         = uiflowcontainer ( 'v0'                                                    ...
                                                , 'Parent'        , obj.figGUI                            ...
                                                , 'Units'         , 'normalized'                          ...
                                                , 'Position'      , [0.05 0.01 0.2 0.35]                  ...
                                                , 'FlowDirection' , 'TopDown'                             ...
                                                );
      obj.btnDaily            = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'String'        , 'Enter daily data'                    ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnEditDaily                     ...
                                                );
      obj.btnAdd              = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'String'        , 'Add animal'                          ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnAddAnimal                     ...
                                                );
      obj.btnEdit             = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnEditAnimal                    ...
                                                );
      obj.btnRemove           = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnRemoveAnimal                  ...
                                                );
      obj.btnImport           = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'String'        , 'Import animals/days'                 ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnImportData                    ...
                                                );
      obj.btnSave             = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'String'        , 'Save regiment ...'                   ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnSaveRegiment                  ...
                                                );
      if ~isempty(obj.actionFcn)
        obj.btnSubmit         = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnSubmitAction                  ...
                                                , 'KeyPressFcn'   , @obj.buttonKeypress                   ...
                                                );
        obj.btnCancel         = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'String'        , 'Cancel'                              ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnCancelAction                  ...
                                                );
      else
        obj.btnSubmit         = [];
        obj.btnCancel         = [];
      end
      obj.btnRestart          = uicontrol       ( 'Parent'        , obj.cntControls                       ...
                                                , 'Style'         , 'pushbutton'                          ...
                                                , 'String'        , 'Restart Matlab'                      ...
                                                , 'FontSize'      , obj.GUI_FONT + 2                      ...
                                                , 'Callback'      , @obj.fcnRestartMatlab                 ...
                                                );

      % Handlers involving the submit button
      set ( [obj.btnAdd, obj.btnEdit, obj.btnRemove, obj.btnSave]   ...
          , 'KeyPressFcn'   , {@obj.buttonKeypress, obj.btnSubmit}  ...
          );
                                              

      % Create session and performance display per animal
      obj.cntAnimal           = uigridcontainer ( 'v0'                                                    ...
                                                , 'Parent'              , obj.figGUI                      ...
                                                , 'Units'               , 'normalized'                    ...
                                                , 'Position'            , [0.28 0 0.72 1]                 ...
                                                , 'EliminateEmptySpace' , 'on'                            ...
                                                , 'GridSize'            , [size(obj.colorID,1) 2]         ...
                                                , 'HorizontalWeight'    , [1 16]                          ...
                                                , 'Margin'              , 1e-10                           ...
                                                );
      for iAni = 1:numel(obj.animal)
        obj.drawAnimalInfo(iAni, obj.axsSchedule, obj.cntAnimal);
      end

      
      % Some actions cannot be executed until an animal is selected
      obj.turnOffAnimalActions();
      uicontrol(obj.btnAdd);
      
      % Make visible after everything has been laid out
      set(obj.figGUI, 'Visible', 'on');
      enhanceCopying(obj.figGUI);
    
      % Motion information display
      if RigParameters.hasDAQ
        stop(obj.instruments.motionTimer);
        obj.instruments = initializeArduinoReader(obj.instruments, 1, 1, MovementSensor.BottomVelocity);
        start(obj.instruments.motionTimer);
      end

    end
    
    %----- Turn off action buttons associated to animal selection
    function turnOffAnimalActions(obj)
      set (obj.btnEdit    , 'String'    , 'Edit ...'                      ...
                          );
      set (obj.btnRemove  , 'String'    , 'Remove ...'                    ...
                          );
      if ~isempty(obj.btnSubmit)
        set (obj.btnSubmit, 'String'    , '( Select animal to proceed )'  ...
                          , 'FontWeight', 'normal'                        ...
                          );
      end
      set ([obj.btnEdit, obj.btnRemove, obj.btnSubmit]                    ...
                          , 'Enable'    , 'off'                           ...
                          , 'UserData'  , []                              ...
                          );
    end
    
    %----- Draws session and performance info for the given animal
    function drawAnimalInfo(obj, iAni, hSchedule, hContainer)
      
      % Extend capacity of display if necessary
      if iAni > size(obj.colorID, 1)
        obj.colorID         = obj.decideColors(iAni);
        set ( obj.cntAnimal                             ...
            , 'GridSize'    , [size(obj.colorID,1) 1]   ...
            );
      end
      
      % Animal specific variables for convenience
      info              = obj.animal(iAni);
      
      % Create new graphics objects if this is a new animal
      if iAni > numel(obj.guiAnimal)
        % Label for animal name and maze info
        obj.guiAnimal(iAni).info                                                          ...
                            = uigridcontainer ( 'v0'                                      ...
                                              , 'Parent'              , hContainer        ...
                                              , 'EliminateEmptySpace' , 'off'             ...
                                              , 'GridSize'            , [3 1]             ...
                                              , 'VerticalWeight'      , [2 3 2]           ...
                                              , 'Margin'              , 1e-10             ...
                                              );
        obj.guiAnimal(iAni).supplement                                                    ...
                            = uicontrol ( 'Parent'              , obj.guiAnimal(iAni).info...
                                        , 'Style'               , 'pushbutton'            ...
                                        , 'FontSize'            , obj.GUI_FONT            ...
                                        , 'UserData'            , iAni                    ...
                                        , 'TooltipString'       , '(Amount of water received in today''s session) - (animal''s water allocation)'  ...
                                        );
        obj.guiAnimal(iAni).chkAnimal                                                     ...
                            = uicontrol ( 'Parent'              , obj.guiAnimal(iAni).info...
                                        , 'Style'               , 'checkbox'              ...
                                        , 'FontSize'            , obj.GUI_FONT            ...
                                        , 'FontWeight'          , 'bold'                  ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR           ...
                                        , 'Callback'            , {@obj.fcnToggleAnimal, iAni}    ...
                                        , 'TooltipString'       , 'Checked if animal is actively being run in behavioral sessions'  ...
                                        );
        obj.guiAnimal(iAni).controls                                                      ...
                            = uigridcontainer ( 'v0'                                      ...
                                              , 'Parent'              , obj.guiAnimal(iAni).info  ...
                                              , 'EliminateEmptySpace' , 'off'             ...
                                              , 'HorizontalWeight'    , [2 1 1]           ...
                                              , 'GridSize'            , [1 3]             ...
                                              , 'Margin'              , 1e-10             ...
                                              );

        % Maze info/controls
        obj.guiAnimal(iAni).edtMaze                                                       ...
                            = uicontrol ( 'Parent'          , obj.guiAnimal(iAni).controls...
                                        , 'Style'           , 'edit'                      ...
                                        , 'FontSize'        , obj.GUI_FONT                ...
                                        , 'BackgroundColor' , [1 1 1]                     ...
                                        , 'UserData'        , false                       ...
                                        , 'TooltipString'   , 'Main maze being run by the animal; set this to impose a user override'  ...
                                        );
        addlistener(obj.guiAnimal(iAni).edtMaze, 'UserData', 'PostSet', @TrainingRegiment.fcnSyncOverride);
        obj.guiAnimal(iAni).sldMaze                                                       ...
                            = uicontrol ( 'Parent'          , obj.guiAnimal(iAni).controls...
                                        , 'Style'           , 'slider'                    ...
                                        , 'Min'             , 1                           ...
                                        , 'Max'             , 100                         ...
                                        , 'SliderStep'      , [1/99, 1/4]                 ...
                                        , 'Value'           , info.mainMazeID             ...
                                        , 'Callback'        , {@obj.fcnSlideMaze, obj.guiAnimal(iAni).edtMaze, iAni}  ...
                                        , 'TooltipString'   , 'Main maze being run by the animal; set this to impose a user override'  ...
                                        );
        set(obj.guiAnimal(iAni).edtMaze , 'Callback'        , {@obj.fcnEditMaze, obj.guiAnimal(iAni).sldMaze , iAni});
        obj.guiAnimal(iAni).btnMaze                                                       ...
                            = uicontrol ( 'Parent'          , obj.guiAnimal(iAni).controls...
                                        , 'Style'           , 'pushbutton'                ...
                                        , 'String'          , '?'                         ...
                                        , 'Callback'        , {@obj.fcnComputeMaze, iAni} ...
                                        , 'TooltipString'   , 'Click to cancel user override of main maze to be run by the animal'  ...
                                        );


        % Animal performance plots
        obj.guiAnimal(iAni).panel                                                         ...
                            = uipanel   ( 'Parent'          , hContainer                  ...
                                        , 'BackgroundColor' , obj.GUI_COLOR               ...
                                        , 'BorderType'      , 'none'                      ...
                                        , 'ButtonDownFcn'   , {@obj.fcnSelectAnimal,iAni} ...
                                        );

        % Axes for animal performance display
        obj.guiAnimal(iAni).axsPerformance                                                ...
                            = axes( 'Parent'          , obj.guiAnimal(iAni).panel         ...
                                  , 'Units'           , 'normalized'                      ...
                                  , 'Position'        , [0.05 0.26 0.9 0.6]               ...
                                  , 'Color'           , [1 1 1]                           ...
                                  , 'FontSize'        , obj.GUI_FONT - 2                  ...
                                  , 'YLim'            , [-0.05 1.05]                      ...
                                  , 'YTick'           , [0 0.5 1]                         ...
                                  , 'Box'             , 'on'                              ...
                                  , 'ButtonDownFcn'   , { @obj.fcnSelectAnimal, iAni, []  ...
                                                        , obj.figGUI, {@obj.dialogEditData, obj.figGUI, iAni} ...
                                                        }                                 ...
                                  , 'TickDir'         , 'out'                             ...
                                  , 'TickLength'      , [0.005 0.005]                     ...
                                  , 'GridAlpha'       , 1                                 ...
                                  , 'Layer'           , 'top'                             ...
                                  );
        xlabel(obj.guiAnimal(iAni).axsPerformance, '   Day');
        ylabel(obj.guiAnimal(iAni).axsPerformance, 'Correct');
        set ( get(obj.guiAnimal(iAni).axsPerformance,'XLabel')                  ...
            , 'Units'               ,'normalized'                               ...
            , 'Position'            , [1 -0.08 0.2]                             ...
            , 'HorizontalAlignment' , 'left'                                    ...
            , 'VerticalAlignment'   , 'top'                                     ...
            );
        
        obj.guiAnimal(iAni).sldMinSession                                                       ...
                            = uicontrol ( 'Parent'          , obj.guiAnimal(iAni).panel         ...
                                        , 'Style'           , 'slider'                          ...
                                        , 'Min'             , 1                                 ...
                                        , 'Max'             , 2                                 ...
                                        , 'Value'           , 1                                 ...
                                        , 'SliderStep'      , [1 1]                             ...
                                        , 'Units'           , 'normalized'                      ...
                                        , 'Position'        , [0.05 0.03 0.05 0.09]             ...
                                        , 'BackgroundColor' , obj.GUI_COLOR                     ...
                                        , 'Callback'        , {@obj.fcnSlideLimit, obj.guiAnimal(iAni).axsPerformance, 'XLim', 1, @round}  ...
                                        , 'TooltipString'   , 'Set lower bound of days shown in performance display'  ...
                                        );
        obj.guiAnimal(iAni).sldMaxSession                                                       ...
                            = uicontrol ( 'Parent'          , obj.guiAnimal(iAni).panel         ...
                                        , 'Style'           , 'slider'                          ...
                                        , 'Min'             , 1                                 ...
                                        , 'Max'             , 2                                 ...
                                        , 'Value'           , 1                                 ...
                                        , 'SliderStep'      , [1 1]                             ...
                                        , 'Units'           , 'normalized'                      ...
                                        , 'Position'        , [0.9 0.03 0.05 0.09]              ...
                                        , 'BackgroundColor' , obj.GUI_COLOR                     ...
                                        , 'Callback'        , {@obj.fcnSlideLimit, obj.guiAnimal(iAni).axsPerformance, 'XLim', 2, @round}  ...
                                        , 'TooltipString'   , 'Set upper bound of days shown in performance display'  ...
                                        );

                                      
        % Guide lines for performance levels
        perfStyle           = {':', ':'};
        perfColor           = [0.75 0.85];
        for iPerf = 1:numel(obj.REF_PERFORMANCE)
          iFormat           = 2 - mod(iPerf, 2);
          obj.guiAnimal(iAni).linPerformance(iPerf)                                       ...
                            = line( 'Parent'          , obj.guiAnimal(iAni).axsPerformance...
                                  , 'XData'           , [0 1]                             ...
                                  , 'YData'           , [1 1]*obj.REF_PERFORMANCE(iPerf)  ...
                                  , 'LineStyle'       , perfStyle{iFormat}                ...
                                  , 'Color'           , [1 1 1] * perfColor(iFormat)      ...
                                  , 'PickableParts'   , 'none'                            ...
                                  );
        end
          
        % Performance plot lines
        obj.guiAnimal(iAni).session   = [];
        obj.guiAnimal(iAni).label     = [];
%         obj.guiAnimal(iAni).mazeLine  = [];
        obj.guiAnimal(iAni).mazeText  = gobjects(0);
        obj.guiAnimal(iAni).dayLine   = gobjects(0);
        obj.guiAnimal(iAni).dayText   = gobjects(0);
        obj.guiAnimal(iAni).cmmtText  = gobjects(0);
        obj.guiAnimal(iAni).pchCmmt   = gobjects(0);
        obj.guiAnimal(iAni).pchInact  = gobjects(0);
        obj.guiAnimal(iAni).pchWeird  = gobjects(0);
        obj.guiAnimal(iAni).pchToday  = gobjects(0);
        for iChoice = 1:numel(obj.CHOICES)
          obj.guiAnimal(iAni).performance(iChoice)                                        ...
                            = line( 'Parent'          , obj.guiAnimal(iAni).axsPerformance...
                                  , 'XData'           , []                                ...
                                  , 'YData'           , []                                ...
                                  , 'ZData'           , []                                ...
                                  , 'LineStyle'       , 'none'                            ...
                                  , 'Color'           , obj.CHOICE_COLOR(iChoice, :)      ...
                                  , 'Marker'          , obj.CHOICE_MARKER{iChoice}        ...
                                  , 'MarkerSize'      , 4                                 ...
                                  , 'MarkerFaceColor' , obj.CHOICE_COLOR(iChoice, :)      ...
                                  , 'MarkerEdgeColor' , 'none'                            ...
                                  , 'ButtonDownFcn'   , { @obj.fcnDisplayStatistic, iAni  ...
                                                      , [obj.CHOICE_NAME{iChoice} ' = %.3g\n(%.3g trials)'] ...
                                                      , obj.NTRIALS_RANGE }             ...
                                  );
        end

        % Number of trials plot
        obj.guiAnimal(iAni).axsNumTrials                                                  ...
                            = axes( 'Parent'          , obj.guiAnimal(iAni).panel         ...
                                  , 'Units'           , 'normalized'                      ...
                                  , 'Position'        , get(obj.guiAnimal(iAni).axsPerformance, 'Position') ...
                                  , 'Color'           , 'none'                            ...
                                  , 'FontSize'        , obj.GUI_FONT - 2                  ...
                                  , 'YAxisLocation'   , 'right'                           ...
                                  , 'YLim'            , [-0.05 1.05] * obj.NTRIALS_RANGE  ...
                                  , 'YTick'           , (0:0.5:1) * obj.NTRIALS_RANGE     ...
                                  , 'YColor'          , obj.NTRIALS_COLOR                 ...
                                  , 'XTick'           , []                                ...
                                  , 'Box'             , 'off'                             ...
                                  , 'ButtonDownFcn'   , {@obj.fcnSelectAnimal, iAni}      ...
                                  , 'TickDir'         , 'out'                             ...
                                  , 'TickLength'      , [0.005 0.005]                     ...
                                  , 'GridAlpha'       , 1                                 ...
                                  , 'PickableParts'   , 'none'                            ...
                                  );
        ylabel(obj.guiAnimal(iAni).axsNumTrials, 'N. trials', 'Rotation', -90, 'VerticalAlignment', 'bottom');
        linkaxes([obj.guiAnimal(iAni).axsPerformance, obj.guiAnimal(iAni).axsNumTrials], 'x');

        obj.guiAnimal(iAni).numTrials                                                               ...
                            = line( 'Parent'          , obj.guiAnimal(iAni).axsPerformance          ...
                                  , 'XData'           , []                                          ...
                                  , 'YData'           , []                                          ...
                                  , 'LineStyle'       , '-'                                         ...
                                  , 'LineWidth'       , 1                                           ...
                                  , 'Color'           , obj.NTRIALS_COLOR                           ...
                                  , 'ButtonDownFcn'   , {@obj.fcnDisplayStatistic, iAni, '%.3g trials', obj.NTRIALS_RANGE}  ...
                                  );
                            
      end
      
      % Always recreate session time rectangles
      delete(obj.guiAnimal(iAni).session);
      delete(obj.guiAnimal(iAni).label);
      
      for iSession = 1:size(info.session,1)
        for iDay = 1:numel(obj.DAYS)
          [cornerX, cornerY]                                                          ...
                          = rectangleCorners( iDay - 0.5                              ...
                                            , info.session(iSession,iDay).start       ...
                                            , 1                                       ...
                                            , info.session(iSession,iDay).duration/60 ...
                                            );
          obj.guiAnimal(iAni).session(iSession,iDay)                                                          ...
                          = patch ( cornerX, cornerY, obj.colorID(iAni,:)                                     ...
                                  , 'Parent'              , hSchedule                                         ...
                                  , 'EdgeColor'           , 'none'                                            ...
                                  , 'LineWidth'           , 3                                                 ...
                                  , 'ButtonDownFcn'       , {@obj.fcnSelectAnimal, iAni, iSession}            ...
                                  );
          obj.guiAnimal(iAni).label(iSession,iDay)                                                            ...
                          = text  ( 'Parent'              , hSchedule                                         ...
                                  , 'String'              , info.name                                         ...
                                  , 'Position'            , [ iDay                                            ...
                                                            , info.session(iSession,iDay).start               ...
                                                            + info.session(iSession,iDay).duration/60/2       ...
                                                            ]                                                 ...
                                  , 'FontSize'            , obj.GUI_FONT - 3                                  ...
                                  , 'FontWeight'          , 'bold'                                            ...
                                  , 'VerticalAlignment'   , 'middle'                                          ...
                                  , 'HorizontalAlignment' , 'center'                                          ...
                                  , 'ButtonDownFcn'       , {@obj.fcnSelectAnimal, iAni, iSession}            ...
                                  );
        end
      end
      
      % Restore highlight of currently selected session
      [selAni, selSession, selDay]  = obj.currentAnimal();
      if ~isempty(selAni) && selAni(1) == iAni
        set(obj.guiAnimal(iAni).session(selSession, selDay), 'EdgeColor', [1 1 1]);
        uistack(obj.guiAnimal(iAni).session(selSession, selDay), 'top');

        set(obj.guiAnimal(iAni).label(selSession, selDay), 'Color', [1 1 1]);
        uistack(obj.guiAnimal(iAni).label(selSession, selDay), 'top');
      end
      
      % Update performance plots
      obj.plotPerformance(iAni);
      
      % Update animal info
      infoText          = {info.name};
      if exist(info.experiment, 'file')
        vr              = load(info.experiment);
        infoText{end+1} = vr.exper.worlds{1}.name;
      else
        infoText{end+1} = '(?)';
      end
      set ( obj.guiAnimal(iAni).chkAnimal             ...
          , 'String'    , ['<html><center>&nbsp;' strjoin(infoText, '<br/>&nbsp;') '</center></html>']  ...
          );
      executeCallback(obj.guiAnimal(iAni).chkAnimal, 'Callback', [], obj.animal(iAni).isActive);
      
      % Update supplementary water requirement
      rewarded          = obj.totalRewards(info.name, obj.dateStamp(), obj.rewardSize(iAni));
      set(obj.guiAnimal(iAni).supplement, 'String', sprintf('%.1f mL', rewarded - obj.animal(iAni).waterAlloc));
      
      % Update world/maze controls
      if isempty(get(obj.guiAnimal(iAni).edtMaze, 'String'))
        executeCallback(obj.guiAnimal(iAni).btnMaze);
      end
      
    end
    
    %----- (Re-)draw performance plots for a given animal
    function plotPerformance(obj, iAni)

      % Delete old graphics
      delete(obj.guiAnimal(iAni).mazeText);
      delete(obj.guiAnimal(iAni).dayLine);
      delete(obj.guiAnimal(iAni).dayText);
      delete(obj.guiAnimal(iAni).cmmtText);
      delete(obj.guiAnimal(iAni).pchCmmt);
      delete(obj.guiAnimal(iAni).pchInact);
      delete(obj.guiAnimal(iAni).pchWeird);
      delete(obj.guiAnimal(iAni).pchToday);
      obj.guiAnimal(iAni).mazeText  = gobjects(0);
      obj.guiAnimal(iAni).dayLine   = gobjects(0);
      obj.guiAnimal(iAni).dayText   = gobjects(0);
      obj.guiAnimal(iAni).cmmtText  = gobjects(size(obj.animal(iAni).data));
      obj.guiAnimal(iAni).pchCmmt   = gobjects(size(obj.animal(iAni).data));
      obj.guiAnimal(iAni).pchInact  = gobjects(size(obj.animal(iAni).data));
      obj.guiAnimal(iAni).pchWeird  = gobjects(size(obj.animal(iAni).data));
      obj.guiAnimal(iAni).pchToday  = gobjects(size(obj.animal(iAni).data));
      
      % Loop through days/runs/blocks
      today             = obj.dateStamp();
      startToday        = 0;
      xPerf             = [];
      yPerf             = nan(numel(obj.CHOICES), 0);
      zPerf             = nan(numel(obj.CHOICES), 0);
      xNTrials          = nan(3,0);
      yNTrials          = nan(3,0);
      lastMainMaze      = 0;
      numDays           = numel(obj.animal(iAni).data);
      for iDay = 1:numDays
        date            = obj.animal(iAni).data(iDay).date;
        run             = obj.animal(iAni).data(iDay).run;
        if isequal(date, today) && startToday < 1
          startToday    = iDay;
        end
        if isempty(date)
          date          = today;
        end
        
        % Create line denoting start of day
        obj.guiAnimal(iAni).dayLine(end+1)                                                        ...
                        = line( 'Parent'              , obj.guiAnimal(iAni).axsPerformance        ...
                              , 'XData'               , [iDay iDay]                               ...
                              , 'YData'               , [-0.1 1.1]                                ...
                              , 'LineWidth'           , 1                                         ...
                              , 'LineStyle'           , '-'                                       ...
                              , 'Color'               , [1 1 1]*0.9                               ...
                              , 'PickableParts'       , 'none'                                    ...
                              );
        obj.guiAnimal(iAni).dayText(end+1)                                                        ...
                        = text( 'Parent'              , obj.guiAnimal(iAni).axsPerformance        ...
                              , 'Position'            , [iDay, 1.1]                               ...
                              , 'String'              , {'', sprintf('%d/%d', date(2), date(3))}  ...
                              , 'Color'               , [0 0 0]                                   ...
                              , 'FontSize'            , obj.GUI_FONT-3                            ...
                              , 'HorizontalAlignment' , 'left'                                    ...
                              , 'VerticalAlignment'   , 'bottom'                                  ...
                              , 'ButtonDownFcn'       , {@obj.fcnSelectAnimal, iAni}              ...
                              );
                                                
        % Collect data per session
        currentLabel    = '';
        lastMaze        = 0;
        isWeird         = false;
        for iRun = 1:numel(run)
          % Each run occupies the same relative area within a day
          xRun          = iDay + (iRun-1) / numel(run);
          
          % Runs can further be subdivided into blocks of trials
          for iBlock = 1:numel(run(iRun).block)
            xBlock      = xRun + (iBlock-1)/numel(run(iRun).block);
            wBlock      = 1 / numel(run(iRun).block);
          
            % Performance criteria to plot
            mazeID                      = run(iRun).block(iBlock).mazeID;
            mainMazeID                  = run(iRun).block(iBlock).mainMazeID;
            xPerf(end+1)                = xBlock + wBlock/2;
            yPerf(:,end+1)              = run(iRun).block(iBlock).performance(1:size(yPerf,1));
            zPerf(:,end+1)              = run(iRun).block(iBlock).numTrials(1:size(zPerf,1)) ./ obj.NTRIALS_RANGE;
%             yPerf(run(iRun).block(iBlock).numTrials(1:size(yPerf,1)) < 1, end)  = nan;

            % Draw levels denoting the number of trials in the block
            xNTrials(:,end+1)           = xBlock + [nan; 0.1; 0.9] .* wBlock;
            yNTrials(:,end+1)           = [nan; 1; 1] * sum(run(iRun).block(iBlock).numTrials) ./ obj.NTRIALS_RANGE;
            
            
            % Show maze ID label whenever it has changed
            if ~strcmp(run(iRun).label, currentLabel) || mazeID ~= lastMaze
              currentLabel              = run(iRun).label;
              obj.guiAnimal(iAni).mazeText(end+1)                                                   ...
                                        = text( 'Parent'              , obj.guiAnimal(iAni).axsPerformance      ...
                                              , 'String'              , sprintf(' %s%d', currentLabel, mazeID)  ...
                                              , 'Position'            , [xBlock, -0.05]             ...
                                              , 'Color'               , obj.LABEL_COLOR             ...
                                              , 'FontSize'            , obj.GUI_FONT - 3            ...
                                              , 'HorizontalAlignment' , 'left'                      ...
                                              , 'VerticalAlignment'   , 'top'                       ...
                                              , 'Clipping'            , 'on'                        ...
                                              );
            end
            
            % Mark strange days
            if    mazeID > mainMazeID                       ...
               || mazeID < lastMaze                         ...
               ||  ( lastMainMaze > 0                       ...
                  && mainMazeID ~= lastMainMaze             ...
                  && mainMazeID ~= lastMainMaze + 1         ...
                   )                                        %...
%                || ~exist(obj.absolutePath(run(iRun).dataFile), 'file')
              isWeird                   = true;
            end
            lastMainMaze                = mainMazeID;
            lastMaze                    = mazeID;
          end
        end
        
        % Flags for odd days
        if isWeird
          [pchX, pchY]  = rectangleCorners(iDay, -0.05, 1, 1.1);
          obj.guiAnimal(iAni).pchWeird(iDay)                                                      ...
                        = patch ( pchX, pchY, obj.WEIRD_COLOR                                     ...
                                , 'Parent'        , obj.guiAnimal(iAni).axsPerformance            ...
                                , 'EdgeColor'     , 'none'                                        ...
                                , 'PickableParts' , 'none'                                        ...
                                );
          uistack(obj.guiAnimal(iAni).pchWeird(iDay), 'bottom');
        end
        obj.drawAniDayLabels(iAni, iDay);
      end
      
      % If there are sessions today, highlight them
      if startToday > 0
        obj.guiAnimal(iAni).pchToday                                                              ...
                        = rectangle ( 'Parent'        , obj.guiAnimal(iAni).axsPerformance        ...
                                    , 'Position'      , [startToday, -0.05, 1, 1.1]               ...
                                    , 'FaceColor'     , obj.TODAY_COLOR                           ...
                                    , 'EdgeColor'     , 'none'                                    ...
                                    , 'PickableParts' , 'none'                                    ...
                                    );
        uistack(obj.guiAnimal(iAni).pchToday, 'bottom');
      end

      % Update plot data and make sure they're on top of the drawing stack
      if ~isempty(xPerf)
        for iChoice = 1:numel(obj.guiAnimal(iAni).performance)
          set ( obj.guiAnimal(iAni).performance(iChoice)    ...
              , 'XData' , xPerf                             ...
              , 'YData' , yPerf(iChoice,:)                  ...
              , 'ZData' , zPerf(iChoice,:)                  ...
              );
          uistack( obj.guiAnimal(iAni).performance(iChoice), 'top' );
        end
      end
      if ~isempty(xNTrials)
        set ( obj.guiAnimal(iAni).numTrials                 ...
            , 'XData' , xNTrials(:)                         ...
            , 'YData' , yNTrials(:)                         ...
            );
      end
      uistack(obj.guiAnimal(iAni).dayText, 'top');
      
      
      % Extend axes to cover range of sessions
      if numDays > 1
        sessionRange    = [max(1, numDays - 7), numDays + 1];
        set ( obj.guiAnimal(iAni).axsPerformance          ...
            , 'XLim'        , sessionRange                ...
            , 'XTick'       , 1:numDays                   ...
            );
        set ( [ obj.guiAnimal(iAni).sldMinSession         ...
              , obj.guiAnimal(iAni).sldMaxSession         ...
              ]                                           ...
            , 'Max'         , numDays                     ...
            , 'SliderStep'  , [1, 7]/(numDays-1)          ...
            );
        set ( obj.guiAnimal(iAni).sldMinSession           ...
            , 'Value'       , sessionRange(1)             ...
            );
        set ( obj.guiAnimal(iAni).sldMaxSession           ...
            , 'Value'       , numDays                     ...
            );
        for iPerf = 1:numel(obj.guiAnimal(iAni).linPerformance)
          set ( obj.guiAnimal(iAni).linPerformance(iPerf) ...
              , 'XData'     , [1 numDays+1]               ...
              );
        end
      end
      uistack(obj.guiAnimal(iAni).dayLine, 'bottom');
      
    end
    
    %----- (Re-)draw comment/inactive labels for a given animal and day
    function drawAniDayLabels(obj, iAni, iDay)

      % Delete old graphics
      delete(obj.guiAnimal(iAni).cmmtText(iDay));
      delete(obj.guiAnimal(iAni).pchCmmt(iDay));
      delete(obj.guiAnimal(iAni).pchInact(iDay));
      
      run             = obj.animal(iAni).data(iDay).run;
      inactiveX       = [];
      inactiveW       = [];
      commentX        = [];
      commentY        = [];
      commentW        = [];
      commentText     = {};
      for iRun = 1:numel(run)
        % Each run occupies the same relative area within a day
        xRun          = iDay + (iRun-1) / numel(run);
        wRun          = 1 / numel(run);
        if ~run(iRun).isActive
          inactiveX(end+1)            = xRun;
          inactiveW(end+1)            = wRun;
        end
        if ~isempty(run(iRun).comments)
          commentX(end+1)             = xRun;
          commentY(end+1)             = 0.45;
          commentW(end+1)             = wRun;
          commentText{end+1}          = run(iRun).comments;
        end

        % Runs can further be subdivided into blocks of trials
        for iBlock = 1:numel(run(iRun).block)
          xBlock      = xRun + (iBlock-1)/numel(run(iRun).block);
          wBlock      = 1 / numel(run(iRun).block);
          if run(iRun).isActive && ~run(iRun).block(iBlock).isActive
            inactiveX(end+1)          = xBlock;
            inactiveW(end+1)          = wBlock;
          end
          if ~isempty(run(iRun).block(iBlock).comments)
            commentX(end+1)           = xBlock;
            commentY(end+1)           = 0.95;
            commentW(end+1)           = wBlock;
            commentText{end+1}        = run(iRun).block(iBlock).comments;
          end
        end
      end

      % Flags for inactive runs/blocks
      if ~isempty(inactiveX)
        [pchX, pchY]  = rectangleCorners( inactiveX                                   ...
                                        , repmat(-0.05, size(inactiveX))              ...
                                        , inactiveW                                   ...
                                        , repmat(1.1, size(inactiveX))                ...
                                        );
        obj.guiAnimal(iAni).pchInact(iDay)                                            ...
                      = patch ( pchX, pchY, obj.INACTIVE_COLOR                        ...
                              , 'Parent'        , obj.guiAnimal(iAni).axsPerformance  ...
                              , 'EdgeColor'     , 'none'                              ...
                              , 'PickableParts' , 'none'                              ...
                              );
        uistack(obj.guiAnimal(iAni).pchInact(iDay), 'bottom');
      end

      % Flags for comments
      if ~isempty(commentX)
        [pchX, pchY]  = rectangleCorners( commentX                                    ...
                                        , repmat(-0.05, size(commentX))               ...
                                        , commentW                                    ...
                                        , repmat(1.1, size(commentX))                 ...
                                        );
        obj.guiAnimal(iAni).pchCmmt(iDay)                                             ...
                      = patch ( pchX, pchY, obj.COMMENT_COLOR                         ...
                              , 'Parent'        , obj.guiAnimal(iAni).axsPerformance  ...
                              , 'EdgeColor'     , 'none'                              ...
                              , 'PickableParts' , 'none'                              ...
                              );
        uistack(obj.guiAnimal(iAni).pchCmmt(iDay), 'bottom');
        
        for iCmmt = 1:numel(commentX)
          comment     = linewrap(commentText{iCmmt}, 25);
          obj.guiAnimal(iAni).cmmtText(iDay)                                          ...
                      = text  ( commentX(iCmmt) + 0.05, commentY(iCmmt), comment      ...
                              , 'Parent'        , obj.guiAnimal(iAni).axsPerformance  ...
                              , 'Color'         , [1 1 1] * 0.5                       ...
                              , 'FontSize'      , obj.GUI_FONT - 2                    ...
                              , 'FontAngle'     , 'italic'                            ...
                              , 'HorizontalAlignment' , 'left'                        ...
                              , 'VerticalAlignment'   , 'top'                         ...
                              , 'PickableParts' , 'none'                              ...
                              );
        end
      end
      
      % Ensure that weird-day flags do not cover the above
      if isgraphics(obj.guiAnimal(iAni).pchWeird(iDay))
        uistack(obj.guiAnimal(iAni).pchWeird(iDay), 'bottom');
      end
    end
    
    
    %----- Modal dialog box for animal information
    function info = dialogEditAnimal(obj, info, vetoedIDs)

      % Get list of basic editable animal data
      animalData    = fieldnames(info)';
      for iData = numel(animalData):-1:1
        if isstruct(info.(animalData{iData}))
          animalData(iData) = [];
        end
      end
      

      % Setup dialog box window
      hDialog       = figure( 'Name'            , 'Training Schedule'                       ...
                            , 'Units'           , 'pixels'                                  ...
                            , 'Position'        , obj.computeFigurePos([0.8 0.8])           ...
                            , 'Menubar'         , 'none'                                    ...
                            , 'NumberTitle'     , 'off'                                     ...
                            , 'Resize'          , 'on'                                      ...
                            , 'Color'           , obj.GUI_COLOR                             ...
                            );
%                             , 'WindowStyle'     , 'modal'                                   ...
      cData         = uigridcontainer ( 'v0'                                                ...
                                      , 'Parent'              , hDialog                     ...
                                      , 'Units'               , 'normalized'                ...
                                      , 'Position'            , [0.02 0.06 0.75 0.92]       ...
                                      , 'EliminateEmptySpace' , 'off'                       ...
                                      , 'GridSize'            , [numel(animalData),2]       ...
                                      , 'HorizontalWeight'    , [1, 3]                      ...
                                      );
      cSchedule     = uigridcontainer ( 'v0'                                                ...
                                      , 'Parent'              , hDialog                     ...
                                      , 'Units'               , 'normalized'                ...
                                      , 'Position'            , [0.79 0.02 0.2 0.96]        ...
                                      , 'GridSize'            , [numel(obj.DAYS)+1,4]       ...
                                      , 'HorizontalWeight'    , [2, 4, 3, 1]                ...
                                      );
      cAction       = uiflowcontainer ( 'v0'                                                ...
                                      , 'Parent'              , hDialog                     ...
                                      , 'Units'               , 'normalized'                ...
                                      , 'Position'            , [0.2 0.02 0.45 0.06]        ...
                                      , 'FlowDirection'       , 'LeftToRight'               ...
                                      );

      % Create action buttons
      hSubmit               = uicontrol ( 'Parent'        , cAction                         ...
                                        , 'Style'         , 'pushbutton'                    ...
                                        , 'String'        , 'Submit'                        ...
                                        , 'FontSize'      , obj.GUI_FONT + 2                ...
                                        , 'Callback'      , @obj.fcnSubmit                  ...
                                        , 'KeyPressFcn'   , @obj.buttonKeypress             ...
                                        );
      hCancel               = uicontrol ( 'Parent'        , cAction                         ...
                                        , 'Style'         , 'pushbutton'                    ...
                                        , 'String'        , 'Cancel'                        ...
                                        , 'FontSize'      , obj.GUI_FONT + 2                ...
                                        , 'Callback'      , {@obj.fcnCancel, hSubmit}       ...
                                        , 'KeyPressFcn'   , {@obj.buttonKeypress, hSubmit}  ...
                                        );
                                              
      % Create input fields populated with default values
      hInput                = {};
      hMazeQuantity         = gobjects(0);
      hProtocol             = gobjects(0);
      verticalWeights       = ones(size(animalData));
      for iData = 1:numel(animalData)
        hInput{1, iData}    = uicontrol ( 'Parent'              , cData                     ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'String'              , [animalData{iData} ' = '] ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Enable'              , 'inactive'                ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR             ...
                                        , 'HorizontalAlignment' , 'right'                   ...
                                        );
                                      
        validator           = obj.deduceValidator(animalData{iData});
        if isequal(validator, @TrainingRegiment.validateFile)
          dispatcher        = { @obj.dispatchFileInput, '*.mat', 'Select ViRMen experiment' };
          if ~isempty(regexpi(animalData{iData}, 'experiment', 'once'))
            dispatcher      = [ dispatcher                                                  ...
                              , { @TrainingRegiment.validateMazeQuantities                  ... N.B. This depends on the order of fields!!!
                                , hMazeQuantity, hProtocol                                  ...
                                } ];
          end
        else
          dispatcher        = {@obj.dispatchKeypress};
        end
        
        hInput{2, iData}    = uicontrol ( 'Parent'              , cData                     ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'BackgroundColor'     , [1 1 1]                   ...
                                        , 'HorizontalAlignment' , 'left'                    ...
                                        , 'KeyPressFcn'         , [dispatcher, {hSubmit}]   ...
                                        );
        if ~isempty(validator)
          set(hInput{2, iData}, 'Callback', validator);
        end
                                      
        % Movement and other list-based configurations
        if isenum(info.(animalData{iData}))
          [~, options]      = enumeration(class(info.(animalData{iData})));
          set ( hInput{2, iData}        , 'Style'               , 'popupmenu'               ...
                                        , 'String'              , options                   ...
                                        , 'Value'               , double(info.(animalData{iData}))            ...
                                        , 'UserData'            , str2func(class(info.(animalData{iData})))   ...
                                        );

        % Lists from cellstring
        elseif isequal(validator, @TrainingRegiment.validateList)
          options           = TrainingRegiment.(info.(animalData{iData}){1});
          set ( hInput{2, iData}        , 'Style'               , 'popupmenu'               ...
                                        , 'String'              , options                   ...
                                        , 'Value'               , info.(animalData{iData}){2}   ...
                                        , 'UserData'            , info.(animalData{iData})  ...
                                        );
                                      
        % Training protocol
        elseif isfunction(info.(animalData{iData}))
          funcInfo          = functions(info.(animalData{iData}));
          funcList          = dir(fullfile(parsePath(funcInfo.file), '*.m'));
          options           = cellfun(@(x) x(1:end-2), {funcList.name}, 'UniformOutput', false);
          set ( hInput{2, iData}        , 'Style'               , 'popupmenu'               ...
                                        , 'String'              , options                   ...
                                        , 'Value'               , find(strcmp(options,funcInfo.function), 1, 'first') ...
                                        , 'UserData'            , cellfun(@str2func, options, 'UniformOutput', false) ...
                                        );
          hProtocol(end+1)  = hInput{2, iData};
          
        % Freeform text entry
        elseif iscell(info.(animalData{iData}))
          strList           = '';
          for iStr = 1:numel(info.(animalData{iData}))
            strList(iStr, 1:numel(info.(animalData{iData}){iStr}))  = info.(animalData{iData}){iStr};
          end
          set ( hInput{2, iData}        , 'String'              , strList                   ...
                                        );
                                      
        % String entry
        elseif ischar(info.(animalData{iData}))
          set ( hInput{2, iData}        , 'String'              , info.(animalData{iData})  ...
                                        );
                                      
        % Table of quantities set per maze level
        elseif size(info.(animalData{iData}),1) == numel(Choice.all())
          delete(hInput{2, iData});
          hInput{2, iData}  = uitable   ( 'Parent'              , cData                     ...
                                        , 'FontSize'            , obj.GUI_FONT - 1          ...
                                        , 'BackgroundColor'     , [1 1 1]                   ...
                                        , 'RowName'             , {'Main', 'Warm-up'}       ...
                                        , 'ColumnEditable'      , true                      ...
                                        , 'ColumnWidth'         , num2cell(45 * ones(1,size(info.(animalData{iData}),2)))   ...
                                        , 'ColumnFormat'        , repmat({'bank'}, 1, size(info.(animalData{iData}),2))     ...
                                        , 'KeyPressFcn'         , [dispatcher, {hSubmit}]   ...
                                        , 'Data'                , info.(animalData{iData})  ...
                                        );
          verticalWeights(iData)  = 3;
          hMazeQuantity(end+1)    = hInput{2, iData};
          
        % Default to numerical data
        else
          set ( hInput{2, iData}        , 'String'              , mat2str(info.(animalData{iData}))     ...
                                        );
        end
        
        if isequal(validator, @TrainingRegiment.validateString)
          set(hInput{2, iData}, 'Min', 1, 'Max', 5);
          verticalWeights(iData)  = 3;
        end
        if ~isempty(validator)
          validator(hInput{2, iData}, [], hMazeQuantity, info.protocol, info.experiment);
        end
      end
      set(cData, 'VerticalWeight', verticalWeights);
      
      % Create session slider in case of multiple sessions per day
      hPanel                = uipanel   ( 'Parent'              , cSchedule                 ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR             ...
                                        , 'BorderType'          , 'none'                    ...
                                        );
      maxSessions           = max(size(info.session,1), obj.MAX_SESSIONS);
      hSchedule(1,1)        = uicontrol ( 'Parent'              , hPanel                    ...
                                        , 'Style'               , 'slider'                  ...
                                        , 'Units'               , 'normalized'              ...
                                        , 'Position'            , [0.1 0.2 0.8 0.6]         ...
                                        , 'Min'                 , 1                         ...
                                        , 'Max'                 , maxSessions               ...
                                        , 'SliderStep'          , [1/(maxSessions-1), 1]    ...
                                        , 'Value'               , 1                         ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR             ...
                                        );
      
      % Create session time entry list
      headers               = {'', 'Start (hh:mm)', 'Duration (min)'};
      for iHead = 2:numel(headers)
        hSchedule(iHead,1)  = uicontrol ( 'Parent'              , cSchedule                 ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'String'              , headers{iHead}            ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Enable'              , 'inactive'                ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR             ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        );
      end
      hSchedule(numel(headers) + 1, 1)                                                      ...
                            = uicontrol ( 'Parent'              , cSchedule                 ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , 'X'                       ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        , 'KeyPressFcn'         , {@obj.buttonKeypress, hSubmit}          ...
                                        );
                                
      for iDay = 1:numel(obj.DAYS)
        hSchedule(1,iDay+1) = uicontrol ( 'Parent'              , cSchedule                 ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'String'              , obj.DAYS{iDay}            ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Enable'              , 'inactive'                ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR             ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        );
        hSchedule(2,iDay+1) = uicontrol ( 'Parent'              , cSchedule                 ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'BackgroundColor'     , [1 1 1]                   ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        , 'Callback'            , {@obj.validateTime, hSchedule(1,1)}     ...
                                        , 'KeyPressFcn'         , {@obj.dispatchKeypress, hSubmit}        ...
                                        , 'UserData'            , [info.session(:,iDay).start]            ...
                                        );
        hSchedule(3,iDay+1) = uicontrol ( 'Parent'              , cSchedule                 ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'BackgroundColor'     , [1 1 1]                   ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        , 'Callback'            , {@obj.validateDuration, hSchedule(1,1)} ...
                                        , 'UserData'            , [info.session(:,iDay).duration]         ...
                                        );
        hSchedule(4,iDay+1) = uicontrol ( 'Parent'              , cSchedule                 ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , '*'                       ...
                                        , 'FontSize'            , obj.GUI_FONT + 4          ...
                                        , 'FontWeight'          , 'bold'                    ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        , 'KeyPressFcn'         , {@obj.buttonKeypress, hSubmit}          ...
                                        );
      end
      
      % Some callbacks need to be set after all controls have been made
      for iDay = 1:numel(obj.DAYS)
        set(hSchedule(4,iDay+1), 'Callback', {@obj.copyInput, hSchedule(2:3,iDay+1), hSchedule(2:3,[2:iDay, iDay+2:end])});
      end
      set(hSchedule(numel(headers)+1,1) , 'Callback', {@obj.deleteSession, hSchedule(1,1), hSchedule(2,2:end), hSchedule(3,2:end)});
      set(hSchedule(1,1)                , 'Callback', {@obj.switchSession, hSchedule(2,2:end), hSchedule(3,2:end)});
      executeCallback(hSchedule(1,1));
    
      % Focus on default object and wait until user is done
      while ishghandle(hDialog)
        uicontrol(hInput{2,1});
        uiwait(hDialog);
        if ~ishghandle(hDialog) || isempty(get(hSubmit, 'UserData'))
          info  = [];
          break;
        end

        % Retrieve results for animal info
        for iData = 1:numel(animalData)
          info.(animalData{iData})  = obj.deduceData(animalData{iData}, hInput{2,iData});
        end
        
        % Check that ID is valid before continuing
        if isempty(info.name)
          errordlg( 'Animal name must be a valid variable name (starts with letter, no spaces).'          ...
                  , 'Invalid animal name', 'modal'                                                        ...
                  );
        elseif any(strcmp(info.name, vetoedIDs))
          errordlg( sprintf('Animal name "%s" has already been used. Specify a unique name.', info.name)  ...
                  , 'Invalid animal name', 'modal'                                                        ...
                  );
        else        
          % If successful, store session data and stop looping
          for iDay = 1:numel(obj.DAYS)
            
            % Restrict to valid sessions
            startTimes    = get(hSchedule(2,iDay+1), 'UserData');
            durations     = get(hSchedule(3,iDay+1), 'UserData');
            valid         = find( isfinite(startTimes) & (durations > 0) );
            nSessions     = numel(valid);
            
            % Store session info
            info.session(nSessions+1:end,:)         = [];
            for iSession = 1:nSessions
              info.session(iSession,iDay).start     = startTimes(valid(iSession));
              info.session(iSession,iDay).duration  = durations(valid(iSession));
            end
          end
          break;
        end
      end
      
      % Close GUI upon exit
      if ishghandle(hDialog)
        close(hDialog);
      end
      
    end

    %----- Dialog box for daily information
    function [info, dates] = dialogEditDaily(obj)
      
      % Span of dates available to edit
      minDate       = [];
      maxDate       = [];
      for iAni = 1:numel(obj.animal)
        if isempty(obj.animal(iAni).data)
          continue;
        end
        startDate   = obj.date2vec(obj.animal(iAni).data(1).date);
        endDate     = obj.date2vec(obj.animal(iAni).data(end).date);
        
        if isempty(minDate) || etime(startDate, minDate) < 0
          minDate   = startDate;
        end
        if isempty(maxDate) || etime(endDate, maxDate) > 0
          maxDate   = endDate;
        end
      end
      
      dates         = {};
      while etime(minDate, maxDate) <= 0
        dates{end+1}= minDate;
        minDate     = datevec(addtodate(datenum(minDate), 1, 'day'));
      end
      
      % List of editable data
      editables     = setdiff ( fieldnames(obj.default.data)    ...
                              , {'date', 'run'}                 ...
                              );
      data.index    = 1;
                            
      % Create table of data per day and animal
      for iEdit = 1:numel(editables)
        table       = nan(numel(dates), numel(obj.animal));
        variable    = editables{iEdit};
        
        for iAni = 1:numel(obj.animal)
          for iDay = 1:numel(obj.animal(iAni).data)
            for iDate = 1:numel(dates)
              if isequal(dates{iDate}(1:3), obj.animal(iAni).data(iDay).date)
                table(iDate, iAni)  = obj.animal(iAni).data(iDay).(variable);
                break;
              end
            end
          end
        end
        
        data.(variable) = table;
      end

      
      % Setup dialog box window
      hDialog       = figure( 'Name'            , 'Daily information'                       ...
                            , 'Units'           , 'pixels'                                  ...
                            , 'Position'        , obj.computeFigurePos([0.6 0.5])           ...
                            , 'Menubar'         , 'none'                                    ...
                            , 'NumberTitle'     , 'off'                                     ...
                            , 'Resize'          , 'on'                                      ...
                            , 'Color'           , obj.GUI_COLOR                             ...
                            );
      cControls     = uigridcontainer ( 'v0'                                                ...
                                      , 'Parent'              , hDialog                     ...
                                      , 'Units'               , 'normalized'                ...
                                      , 'Position'            , [0.02 0.9 0.96 0.08]        ...
                                      , 'EliminateEmptySpace' , 'off'                       ...
                                      , 'GridSize'            , [1, 4]                      ...
                                      , 'HorizontalWeight'    , [3, 1, 1, 1]                ...
                                      );

      % Create action buttons
      hVariables            = uicontrol ( 'Parent'        , cControls                       ...
                                        , 'Style'         , 'popupmenu'                     ...
                                        , 'String'        , editables                       ...
                                        , 'Value'         , 1                               ...
                                        , 'FontSize'      , obj.GUI_FONT                    ...
                                        , 'KeyPressFcn'   , @obj.buttonKeypress             ...
                                        , 'UserData'      , data                            ...
                                        );
                              uicontrol ( 'Parent'        , cControls                       ...
                                        , 'Style'         , 'text'                          ...
                                        );
      hSubmit               = uicontrol ( 'Parent'        , cControls                       ...
                                        , 'Style'         , 'pushbutton'                    ...
                                        , 'String'        , 'Submit'                        ...
                                        , 'FontSize'      , obj.GUI_FONT                    ...
                                        , 'Callback'      , @obj.fcnSubmit                  ...
                                        , 'KeyPressFcn'   , @obj.buttonKeypress             ...
                                        );
      hCancel               = uicontrol ( 'Parent'        , cControls                       ...
                                        , 'Style'         , 'pushbutton'                    ...
                                        , 'String'        , 'Cancel'                        ...
                                        , 'FontSize'      , obj.GUI_FONT                    ...
                                        , 'Callback'      , {@obj.fcnCancel, hSubmit}       ...
                                        , 'KeyPressFcn'   , {@obj.buttonKeypress, hSubmit}  ...
                                        );
                                              
      % Create input table 
      cVariables            = uitable   ( 'Units'         , 'normalized'                    ...
                                        , 'Position'      , [0.02 0.02 0.96 0.88]           ...
                                        , 'ColumnEditable', true(1, numel(obj.animal))      ...
                                        , 'ColumnFormat'  , repmat({'numeric'}, 1, numel(obj.animal))         ...
                                        , 'ColumnName'    , {obj.animal.name}               ...
                                        , 'RowName'       , cellfun(@date2str, dates, 'UniformOutput', false) ...
                                        , 'FontSize'      , obj.GUI_FONT                    ...
                                        , 'UserData'      , dates                           ...
                                        );
      % Make the columns fill the table space
      tablePos              = rget(cVariables, 'Position', 'Units', 'pixels');
      set(cVariables, 'ColumnWidth', num2cell(tablePos(3) * ones(1,numel(obj.animal)) / (numel(obj.animal)+1)));
      

      % Callbacks that use multiple controls
      set(hVariables, 'Callback', {@obj.fcnSelectEditable, cVariables});
      executeCallback(hVariables);

    
      % Focus on default object and wait until user is done
      while ishghandle(hDialog)
        uiwait(hDialog);
        if ~ishghandle(hDialog) || isempty(get(hSubmit, 'UserData'))
          info  = [];
          break;
        end

        % Retrieve results, making sure to merge the last edited value
        executeCallback(hVariables);
        info  = get(hVariables, 'UserData');
        break;
      end
      
      % Close GUI upon exit
      if ishghandle(hDialog)
        close(hDialog);
      end
      
    end
    
    %----- Dialog box for data import
    function imports = dialogImportData(obj)
      
      % Select regiment to import from
      imports       = [];
      [sourceRegiment, sourcePath]                                                          ...
                    = uigetfile ( {'*.mat', 'MAT-files (*.mat)'}                            ...
                                , 'Select regiment to import from'                          ...
                                , obj.lastPath                                              ...
                                );
      if isequal(sourceRegiment, 0)
        return;
      end
      sourceRegiment= fullfile(sourcePath, sourceRegiment);
      obj.lastPath  = sourcePath;
      
      % Parse regiment for animals/days
      source        = TrainingRegiment('', sourceRegiment, 'mustread');
      srcAnimal     = {source.animal.name};
      srcDate       = nan(0, 3);
      for iAni = 1:numel(srcAnimal)
        srcDate     = union(srcDate, cat(1, source.animal(iAni).data.date), 'rows');
      end
      showYear      = srcDate(1,1) ~= srcDate(end,1);
      

      % Setup dialog box window
      hDialog       = figure( 'Name'            , ['Import from ' sourceRegiment]           ...
                            , 'Units'           , 'pixels'                                  ...
                            , 'Position'        , obj.computeFigurePos([0.95 0.6])          ...
                            , 'Menubar'         , 'none'                                    ...
                            , 'NumberTitle'     , 'off'                                     ...
                            , 'Resize'          , 'on'                                      ...
                            , 'Color'           , obj.GUI_COLOR                             ...
                            );
      cControls     = uigridcontainer ( 'v0'                                                ...
                                      , 'Parent'              , hDialog                     ...
                                      , 'Units'               , 'normalized'                ...
                                      , 'Position'            , [0.01 0.91 0.98 0.08]       ...
                                      , 'EliminateEmptySpace' , 'off'                       ...
                                      , 'GridSize'            , [1, 4]                      ...
                                      , 'HorizontalWeight'    , [4, 5, 1 1]                 ...
                                      );
      cDataSel      = uigridcontainer ( 'v0'                                                ...
                                      , 'Parent'              , hDialog                     ...
                                      , 'Units'               , 'normalized'                ...
                                      , 'Position'            , [0 0.01 1 0.88]             ...
                                      , 'EliminateEmptySpace' , 'off'                       ...
                                      , 'Margin'              , 1                           ...
                                      , 'GridSize'            , [numel(srcAnimal)+1, size(srcDate,1)+1] ...
                                      , 'HorizontalWeight'    , [2, ones(1,size(srcDate,1))]            ...
                                      );

      % Create action buttons
      hMoveData             = uicontrol ( 'Parent'              , cControls                 ...
                                        , 'Style'               , 'checkbox'                ...
                                        , 'String'              , 'Move data files'         ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Value'               , 1                         ...
                                        );
                              uicontrol ( 'Parent'              , cControls                 ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'String'              , '  Select data to import. Right-click on animal to change target name.  '  ...
                                        , 'Enable'              , 'inactive'                ...
                                        , 'FontSize'            , obj.GUI_FONT + 1          ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR             ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        );
      hSubmit               = uicontrol ( 'Parent'              , cControls                 ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , 'Submit'                  ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Callback'            , @obj.fcnSubmit            ...
                                        , 'KeyPressFcn'         , @obj.buttonKeypress       ...
                                        );
      hCancel               = uicontrol ( 'Parent'              , cControls                 ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , 'Cancel'                  ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Callback'            , {@obj.fcnCancel, hSubmit}       ...
                                        , 'KeyPressFcn'         , {@obj.buttonKeypress, hSubmit}  ...
                                        );

      % Date selection buttons
      hAllSel               = uicontrol ( 'Parent'              , cDataSel                  ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , '(all)'                   ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        );
      hDate                 = gobjects(1, size(srcDate,1));
      for iDate = 1:size(srcDate,1)
        if showYear
          dateLabel         = sprintf('%d/%d/%d', srcDate(iDate,1), srcDate(iDate,2), srcDate(iDate,3));
        else
          dateLabel         = sprintf('%d/%d', srcDate(iDate,2), srcDate(iDate,3));
        end
        hDate(iDate)        = uicontrol ( 'Parent'              , cDataSel                  ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , dateLabel                 ...
                                        , 'FontSize'            , obj.GUI_FONT - 1          ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        );
      end
                                      
      % Create selection checkboxes
      hAni                  = gobjects(numel(srcAnimal), 1);
      hSel                  = gobjects(numel(srcAnimal), size(srcDate,1));
      aniDataDay            = nan(numel(srcAnimal), size(srcDate,1));
      for iAni = 1:numel(srcAnimal)
        hAni(iAni)          = uicontrol ( 'Parent'              , cDataSel                  ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , srcAnimal{iAni}           ...
                                        , 'FontSize'            , obj.GUI_FONT - 1          ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        );
                                      
        for iDate = 1:size(srcDate,1)
          hSel(iAni,iDate)  = uicontrol ( 'Parent'              , cDataSel                  ...
                                        , 'Style'               , 'checkbox'                ...
                                        , 'Value'               , 0                         ...
                                        , 'Enable'              , 'off'                     ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        );
        end
        
        % Enable selection only for days when the animal was active
        data                = source.animal(iAni).data;
        for iDay = 1:numel(data)
          iDate             = find(ismember(srcDate, data(iDay).date, 'rows'), 1, 'first');
          if ~isempty(iDate)
            aniDataDay(iAni,iDate)  = iDay;
            set(hSel(iAni,iDate), 'Enable', 'on');
          end
        end
      end
      
      
      % Setup callbacks for data selection
      set(hAllSel         , 'Callback'  , {@TrainingRegiment.fcnToggleCheckbox, hSel});
      for iDate = 1:size(srcDate,1)
        set(hDate(iDate)  , 'Callback'  , {@TrainingRegiment.fcnToggleCheckbox, hSel(:,iDate)});
      end
      for iAni = 1:numel(srcAnimal)
        set( hAni(iAni)   , 'Callback'  , {@TrainingRegiment.fcnToggleCheckbox, hSel(iAni,:)}                                            ...
                      , 'ButtonDownFcn' , {@TrainingRegiment.fcnSetString, sprintf('Rename "%s" to:', srcAnimal{iAni}), srcAnimal{iAni}} ...
           );
      end
      
      
      % Focus on default object and wait until user is done
      uiwait(hDialog);
      if ~ishghandle(hDialog)
        return;
      end
      if isempty(get(hSubmit, 'UserData'))
        stopAndDoNothing();
        return;
      end

      % Loop over all selected data
      doMoveData            = get(hMoveData, 'Value') > 0;
      animal                = obj.animal;
      sourceFiles           = {};
      targetFiles           = {};
      removeFiles           = {};
      for iAni = 1:numel(srcAnimal)
        isSelected          = get(hSel(iAni,:), 'Value');
        if iscell(isSelected)
          isSelected        = cell2mat(isSelected);
        end
        selDates            = isSelected' & isfinite(aniDataDay(iAni,:));
        if ~any(selDates)
          continue;
        end
        
        % Try to locate animal in existing list
        targetName          = get(hAni(iAni), 'String');
        iTarget             = find(strcmp({animal.name}, targetName), 1, 'first');
        iSrcDay             = aniDataDay(iAni, selDates);
        
        % If a new animal, add it to the end
        if isempty(iTarget)
          animal(end+1)     = source.animal(iAni);
          animal(end).data  = source.animal(iAni).data(iSrcDay);
          iTarget           = numel(animal);
          iTgtDay           = 1:numel(animal(end).data);
          
        % If the animal exists but with no data, only import data
        elseif isempty(animal(iTarget).data)
          animal(iTarget).data  = source.animal(iAni).data(iSrcDay);
          iTgtDay           = 1:numel(animal(iTarget).data);
          
        % Otherwise merge into existing data, in order of date
        else
          tgtDates          = cat(1, animal(iTarget).data.date) * obj.NDAYS_DATEVEC;
          iTgtDay           = [];
          for iDay = iSrcDay
            dayData         = source.animal(iAni).data(iDay);
            dayDatenum      = dayData.date * obj.NDAYS_DATEVEC;
            
            % Find location to insert; this should be in increasing order,
            % otherwise the previously stored iTgtDay will be incorrect
            iMatch          = find(tgtDates <= dayDatenum, 1, 'last');
            if isempty(iMatch)
              iMatch        = 1;
            end
            if ~isempty(iTgtDay) && iMatch < iTgtDay(end)
              error('TrainingRegiment:dialogImportData', 'Unexpected order of dates encountered.');
            end
            
            % If data with the same date exists, warn user
            if dayDatenum == tgtDates(iMatch)
              dateLabel     = sprintf('%d/%d/%d', dayData.date(1), dayData.date(2), dayData.date(3));
              choice        = questdlg( sprintf('%s already contains data for %s. Overwrite?', targetName, dateLabel) ...
                                      , ['Data Exists for ' dateLabel]                                                ...
                                      , 'Yes'                                                                         ...
                                      );
              switch choice
                case 'Yes'
                  % First register data/figure files to be removed
                  if doMoveData
                    oldData                     = {animal(iTarget).data(iMatch).run.dataFile};
                    for iFile = 1:numel(oldData)
                      removeFiles{end+1}        = obj.absolutePath(oldData{iFile});
                      removeFiles               = [removeFiles, obj.findLogFigures(removeFiles{end})];
                    end
                  end
                  
                  % Replace existing data with source
                  animal(iTarget).data(iMatch)  = dayData;
                  iTgtDay(end+1)                = iMatch;
                case 'No'
                  continue;
                case 'Cancel'
                  stopAndDoNothing();
                  return;
              end
              
            % If there is no conflict, insert data at the desired location
            else
              animal(iTarget).data  = [ animal(iTarget).data(1:iMatch)      ...
                                      , dayData                             ...
                                      , animal(iTarget).data(iMatch+1:end)  ...
                                      ];
              iTgtDay(end+1)        = iMatch + 1;
              tgtDates              = [tgtDates(1:iMatch); dayDatenum; tgtDates(iMatch+1:end)];
            end
          end
        end
          
        % Rewire paths if so desired
        if doMoveData
          replaceSrc        = sprintf(obj.RGX_ANINAME, srcAnimal{iAni});
          replaceTgt        = sprintf(obj.REP_ANINAME, targetName);
          
          for iDay = iTgtDay
            for iRun = 1:numel(animal(iTarget).data(iDay).run)
              srcFile       = source.relativePath(animal(iTarget).data(iDay).run(iRun).dataFile);
              tgtFile       = regexprep(srcFile, replaceSrc, replaceTgt);

              % Only take action if source and target are different
              srcPath       = source.absolutePath(srcFile);
              tgtPath       = obj.absolutePath(tgtFile);
              if strcmp(srcPath, tgtPath) || ~exist(srcPath, 'file')
                continue;
              end

              % Register data files to be moved
              animal(iTarget).data(iDay).run(iRun).dataFile = tgtFile;
              sourceFiles{end+1}    = srcPath;
              targetFiles{end+1}    = tgtPath;
              
              % Also register online performance plots to be moved
              figFile       = obj.findLogFigures(srcPath);
              for iFig = 1:numel(figFile)
                sourceFiles{end+1}  = figFile{iFig};
                targetFig           = obj.absolutePath(source.relativePath(figFile{iFig}));
                targetFiles{end+1}  = regexprep(targetFig, replaceSrc, replaceTgt);
              end
            end
          end
        end
      end
      
      
      % Confirm file moving with user
      if doMoveData
        targetFiles         = obj.dialogMoveData(sourceFiles, targetFiles);
        if ~iscell(targetFiles)
          stopAndDoNothing();
          return;
        end
        
        fprintf('\n======================  Moving behavioral data (%s) ======================\n', datestr(now));
        % Remove old behavioral data, if any
        for iFile = 1:numel(removeFiles)
          if ~exist(removeFiles{iFile}, 'file')
            continue;
          end
          
          fprintf(' [REMOVE]  %s\n', removeFiles{iFile});
          try
            backupPath      = [removeFiles{iFile}, datestr(now, '.yyyymmdd_HHMMSS')];
            movefile(removeFiles{iFile}, backupPath, 'f');
          catch err
            displayException(err);
          end
        end 

        % Move new data into place
        for iFile = 1:size(targetFiles)
          srcPath           = sourceFiles{iFile};
          tgtPath           = targetFiles{iFile};
          if isempty(tgtPath)
            continue;
          end
          
          tgtDir            = parsePath(tgtPath);
          if ~exist(tgtDir, 'dir')
            mkdir(tgtDir);
          end
          if exist(tgtPath, 'file')
            backupPath      = [tgtPath, datestr(now, '.yyyymmdd_HHMMSS')];
            movefile(tgtPath, backupPath, 'f');
          end
          
          fprintf(' %s\n  -->  %s\n', srcPath, tgtPath);
          try
            movefile(srcPath, tgtPath, 'f');
            
            % For behavioral data, rename the animal inside the log
            [~,~,ext]       = parsePath(tgtPath);
            if strcmpi(ext, '.mat')
              logData       = load(tgtPath);
              logData.log.animal  = animal(iTarget).name;
              save(tgtPath, '-struct', 'logData');
            else
              touchFile(tgtPath);
            end
          catch err
            displayException(err);
          end
        end 
      end

      % Copy all experiment info just to be safe
      for exper = fieldnames(source.experiment)'
        if isfield(obj.experiment, exper{:})
          for iVer = 1:numel(source.experiment.(exper{:}))
            obj.experiment.(exper{:}) = mergeSimilar( obj.experiment.(exper{:})       ...
                                                    , source.experiment.(exper{:})    ...
                                                    , 'version'                       ...
                                                    );
          end
        else
          obj.experiment.(exper{:})   = source.experiment.(exper{:});
        end
      end

      % Apply computed changes
      obj.animal            = animal;
      
      % Close GUI upon exit
      if ishghandle(hDialog)
        close(hDialog);
      end
      obj.guiSelectAnimal(obj.actionStr, obj.actionFcn, obj.cancelFcn);
      
      % Terminate without doing anything
      function stopAndDoNothing()
        uiwait(warndlg('Data import canceled by user.', 'Import Canceled', 'modal'));
        if ishghandle(hDialog)
          close(hDialog);
        end
      end
      
    end
    
    %----- Dialog box for file moving
    function targets = dialogMoveData(obj, sourceFiles, targetFiles)
      
      % Return successfully if nothing to do
      targets       = cell(0, 2);
      if isempty(sourceFiles)
        return;
      end
      
      % Notate files that will be replaced
      sourceFiles   = sourceFiles(:);
      targetFiles   = targetFiles(:);
      for iFile = 1:numel(targetFiles)
        if exist(targetFiles{iFile}, 'file')
          targetFiles{iFile}  = [TrainingRegiment.EXISTS_FLAG targetFiles{iFile}];
        end
      end
      
      % Create dialog figure
      figPos        = obj.computeFigurePos([1 0.5]);
      colWidth      = round((figPos(3) - 10) / 2);
      
      hDialog       = figure( 'Name'            , 'Move Data Files'                           ...
                            , 'Units'           , 'pixels'                                    ...
                            , 'Position'        , figPos                                      ...
                            , 'Menubar'         , 'none'                                      ...
                            , 'NumberTitle'     , 'off'                                       ...
                            , 'Resize'          , 'on'                                        ...
                            , 'Color'           , obj.GUI_COLOR                               ...
                            );
                          
      % Main layout
      cControls     = uigridcontainer ( 'v0'                                                  ...
                                      , 'Parent'              , hDialog                       ...
                                      , 'Units'               , 'normalized'                  ...
                                      , 'Position'            , [0.01 0.91 0.98 0.08]         ...
                                      , 'EliminateEmptySpace' , 'off'                         ...
                                      , 'GridSize'            , [1, 3]                        ...
                                      , 'HorizontalWeight'    , [5, 1 1]                      ...
                                      );
      tFiles        = uitable         ( hDialog                                               ...
                                      , 'Parent'              , hDialog                       ...
                                      , 'Units'               , 'normalized'                  ...
                                      , 'Position'            , [0 0.01 1 0.88]               ...
                                      , 'Data'                , [sourceFiles, targetFiles]    ...
                                      , 'RowName'             , []                            ...
                                      , 'ColumnName'          , {'Source', 'Target'}          ...
                                      , 'ColumnWidth'         , {colWidth, colWidth}          ...
                                      , 'ColumnEditable'      , [false true]                  ...
                                      , 'FontSize'            , obj.GUI_FONT                  ...
                                      );
      
      % Create action buttons
                              uicontrol ( 'Parent'              , cControls                 ...
                                        , 'Style'               , 'edit'                    ...
                                        , 'String'              , [ ' ' TrainingRegiment.EXISTS_FLAG          ...
                                                                    ' Target exists and will be replaced.  '  ...
                                                                  ]                         ...
                                        , 'Enable'              , 'inactive'                ...
                                        , 'FontSize'            , obj.GUI_FONT + 1          ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR             ...
                                        , 'HorizontalAlignment' , 'center'                  ...
                                        );
      hSubmit               = uicontrol ( 'Parent'              , cControls                 ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , 'EXECUTE'                 ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Callback'            , @obj.fcnSubmit            ...
                                        , 'KeyPressFcn'         , @obj.buttonKeypress       ...
                                        );
      hCancel               = uicontrol ( 'Parent'              , cControls                 ...
                                        , 'Style'               , 'pushbutton'              ...
                                        , 'String'              , 'Cancel'                  ...
                                        , 'FontSize'            , obj.GUI_FONT              ...
                                        , 'Callback'            , {@obj.fcnCancel, hSubmit}       ...
                                        , 'KeyPressFcn'         , {@obj.buttonKeypress, hSubmit}  ...
                                        );
      
      % Focus on default object and wait until user is done
      targets                 = false;
      uiwait(hDialog);
      if ~ishghandle(hDialog)
        return;
      elseif isempty(get(hSubmit, 'UserData'))
        close(hDialog);
        return;
      end
      
      % Get list of file operations
      targets                 = get(tFiles, 'Data');
      targets                 = targets(:, 2);
      for iFile = 1:numel(targets)
        if strncmp(targets{iFile}, TrainingRegiment.EXISTS_FLAG, numel(TrainingRegiment.EXISTS_FLAG))
          targets{iFile}      = targets{iFile}(numel(TrainingRegiment.EXISTS_FLAG)+1:end);
        end
      end

      if ishghandle(hDialog)
        close(hDialog);
      end
      
    end
    
    %----- Dialog box for commenting on and inactivating runs/blocks
    function dialogEditData(obj, hFigure, iAni)

      % Get the day that the user clicked on
      clickedPoint          = get(obj.guiAnimal(iAni).axsPerformance, 'CurrentPoint');
      iDay                  = floor(clickedPoint(1));
      if iDay < 1 || iDay > numel(obj.animal(iAni).data)
        return;
      end
      
      % Information to edit
      dayData               = obj.animal(iAni).data(iDay);
      maxBlocks             = 0;
      logFile               = cell(numel(dayData.run), 2);
      for iRun = 1:numel(dayData.run)
        maxBlocks           = max(maxBlocks, numel(dayData.run(iRun).block));
        [logFile{iRun,2}, logFile{iRun,1}]    ...
                            = obj.findLogFigures(dayData.run(iRun).dataFile);
      end
      
      
      % Create dialog figure
      figPos                = obj.computeFigurePos([0.4 0.25]);
      hDialog               = figure( 'Name'            , sprintf ( '%s : Day %d (%d/%d/%d)'                ...
                                                                  , obj.animal(iAni).name, iDay             ...
                                                                  , dayData.date(1), dayData.date(2), dayData.date(3) ...
                                                                  )                                         ...
                                    , 'Units'           , 'pixels'                                          ...
                                    , 'Position'        , figPos                                            ...
                                    , 'Menubar'         , 'none'                                            ...
                                    , 'NumberTitle'     , 'off'                                             ...
                                    , 'Resize'          , 'on'                                              ...
                                    , 'Color'           , obj.GUI_COLOR                                     ...
                                    );
                          
      % Main layout
      cActive         = uigridcontainer ( 'v0'                                                      ...
                                        , 'Parent'              , hDialog                           ...
                                        , 'Units'               , 'normalized'                      ...
                                        , 'Position'            , [0.01 0.67 0.78 0.18]             ...
                                        , 'EliminateEmptySpace' , 'off'                             ...
                                        , 'GridSize'            , [numel(dayData.run), 2+maxBlocks] ...
                                        , 'HorizontalWeight'    , [3, 2*ones(1, 1+maxBlocks)]       ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        );
      cControls       = uiflowcontainer ( 'v0'                                                      ...
                                        , 'Parent'              , hDialog                           ...
                                        , 'Units'               , 'normalized'                      ...
                                        , 'Position'            , [0.81 0.05 0.18 0.78]             ...
                                        , 'FlowDirection'       , 'TopDown'                         ...
                                        , 'Margin'              , 3                                 ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        );
      cComments             = uitabgroup( 'Parent'              , hDialog                           ...
                                        , 'Units'               , 'normalized'                      ...
                                        , 'Position'            , [0.01 0.01 0.78 0.65]             ...
                                        , 'TabLocation'         , 'top'                             ...
                                        );
      
      % Log file list and access buttons
      hLogFile              = uicontrol ( 'Parent'              , hDialog                           ...
                                        , 'Units'               , 'normalized'                      ...
                                        , 'Position'            , [0.01 0.78 0.98 0.2]              ...
                                        , 'Style'               , 'popupmenu'                       ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , logFile(:,1)                      ...
                                        , 'BackgroundColor'     , [1 1 1]                           ...
                                        );
      hCopyLog              = uicontrol ( 'Parent'              , cControls                         ...
                                        , 'Style'               , 'pushbutton'                      ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , 'Copy data path'                  ...
                                        , 'Callback'            , {@obj.fcnCopyToClipboard, hLogFile, 'String', hLogFile, 'Value'}  ...
                                        , 'KeyPressFcn'         , @obj.buttonKeypress               ...
                                        );
      hOpenLog              = uicontrol ( 'Parent'              , cControls                         ...
                                        , 'Style'               , 'pushbutton'                      ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , 'Load data'                       ...
                                        , 'Callback'            , {@obj.fcnRunFunction, hLogFile, 'String', hLogFile, 'Value', @obj.loadInBaseWS}  ...
                                        , 'KeyPressFcn'         , @obj.buttonKeypress               ...
                                        );
      hOpenFig              = uicontrol ( 'Parent'              , cControls                         ...
                                        , 'Style'               , 'pushbutton'                      ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , ''                                ...
                                        , 'UserData'            , logFile(:,2)                      ...
                                        , 'Callback'            , {@obj.fcnRunFunction, [], 'UserData', hLogFile, 'Value', @openfig}  ...
                                        , 'KeyPressFcn'         , @obj.buttonKeypress               ...
                                        );
                              uicontrol ( 'Parent'              , cControls                         ...
                                        , 'Style'               , 'text'                            ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        );
                                      
      % Action buttons
      hSubmit               = uicontrol ( 'Parent'              , cControls                         ...
                                        , 'Style'               , 'pushbutton'                      ...
                                        , 'String'              , 'Apply'                           ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'KeyPressFcn'         , @obj.buttonKeypress               ...
                                        );
      hCancel               = uicontrol ( 'Parent'              , cControls                         ...
                                        , 'Style'               , 'pushbutton'                      ...
                                        , 'String'              , 'Cancel'                          ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'Callback'            , @obj.fcnCloseFigure               ...
                                        , 'KeyPressFcn'         , {@obj.buttonKeypress, hSubmit}    ...
                                        );

      % Editing fields
                              uicontrol ( 'Parent'              , cActive                           ...
                                        , 'Style'               , 'edit'                            ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , ' Active  :  '                    ...
                                        , 'Enable'              , 'inactive'                        ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        );
      
      hRunActive            = gobjects(numel(dayData.run), 1);
      hBlockActive          = gobjects(numel(dayData.run), maxBlocks);
      hRunComment           = gobjects(numel(dayData.run), 1);
      hBlockComment         = gobjects(numel(dayData.run), maxBlocks);
      tRunComment           = gobjects(numel(dayData.run), 1);
      tBlockComment         = gobjects(numel(dayData.run), maxBlocks);
      for iRun = 1:numel(dayData.run)
        if iRun > 1
                              uicontrol ( 'Parent'              , cActive                           ...
                                        , 'Style'               , 'text'                            ...
                                        );
        end
                                      
        % Create checkboxes for (in)activating runs/blocks
        hRunActive(iRun)    = uicontrol ( 'Parent'              , cActive                           ...
                                        , 'Style'               , 'checkbox'                        ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , sprintf(' run %d :', iRun)        ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        , 'Value'               , dayData.run(iRun).isActive        ...
                                        , 'KeyPressFcn'         , {@obj.dispatchKeypress, hSubmit}  ...
                                        );
        % Create tabs for each run
        tRunComment(iRun)   = uitab     ( 'Parent'              , cComments                         ...
                                        , 'Title'               , sprintf('Run %d', iRun)           ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        );
        hRunComment(iRun)   = uicontrol ( 'Parent'              , tRunComment(iRun)                 ...
                                        , 'Style'               , 'edit'                            ...
                                        , 'FontName'            , 'FixedWidth'                      ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , dayData.run(iRun).comments        ...
                                        , 'Units'               , 'normalized'                      ...
                                        , 'Position'            , [0.01 0.01 0.98 0.98]             ...
                                        , 'BackgroundColor'     , [1 1 1]                           ...
                                        , 'HorizontalAlignment' , 'left'                            ...
                                        , 'KeyPressFcn'         , {@obj.dispatchKeypress, hSubmit}  ...
                                        );
                                    
        for iBlock = 1:numel(dayData.run(iRun).block)
          lComment          = sprintf   ( 'block %d (%s%d)'                                         ...
                                        , iBlock                                                    ...
                                        , dayData.run(iRun).label                                   ...
                                        , dayData.run(iRun).block(iBlock).mazeID                    ...
                                        );

          % Create checkboxes for (in)activating runs/blocks
          hBlockActive(iRun,iBlock)                                                                 ...
                            = uicontrol ( 'Parent'              , cActive                           ...
                                        , 'Style'               , 'checkbox'                        ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , sprintf(' block %d', iBlock)      ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        , 'Value'               , dayData.run(iRun).block(iBlock).isActive  ...
                                        , 'KeyPressFcn'         , {@obj.dispatchKeypress, hSubmit}  ...
                                        );
          
          % Create tabs for each block
          tBlockComment(iRun,iBlock)                                                                ...
                            = uitab     ( 'Parent'              , cComments                         ...
                                        , 'Title'               , lComment                          ...
                                        , 'BackgroundColor'     , obj.GUI_COLOR                     ...
                                        );
          hBlockComment(iRun,iBlock)                                                                ...
                            = uicontrol ( 'Parent'              , tBlockComment(iRun,iBlock)        ...
                                        , 'Style'               , 'edit'                            ...
                                        , 'FontName'            , 'FixedWidth'                      ...
                                        , 'FontSize'            , obj.GUI_FONT                      ...
                                        , 'String'              , dayData.run(iRun).block(iBlock).comments  ...
                                        , 'Units'               , 'normalized'                      ...
                                        , 'Position'            , [0.01 0.01 0.98 0.98]             ...
                                        , 'BackgroundColor'     , [1 1 1]                           ...
                                        , 'HorizontalAlignment' , 'left'                            ...
                                        , 'KeyPressFcn'         , {@obj.dispatchKeypress, hSubmit}  ...
                                        );
        end
        
        % Empty space for non-present blocks
        for iBlock = numel(dayData.run(iRun).block)+1:maxBlocks
                              uicontrol ( 'Parent'              , cActive                           ...
                                        , 'Style'               , 'text'                            ...
                                        );
        end
      end
      
      
      % Setup callbacks after GUI elements are created
      set(hLogFile, 'Callback', {@obj.fcnCheckFile, [hCopyLog, hOpenLog], hOpenFig});
      executeCallback(hLogFile);

      set(hSubmit , 'Callback', { @obj.fcnCommitDataEdit, hDialog, iAni, iDay                 ...
                                , hRunActive, hRunComment, hBlockActive, hBlockComment        ...
                                });
      
      for iRun = 1:numel(dayData.run)
        if ~dayData.run(iRun).isActive
          set(hBlockActive(iRun,:), 'Enable', 'off');
        end
        set(hRunActive(iRun)  , 'Callback', { @obj.fcnSetProperty, 'Value', @ispositive       ...
                                            , hBlockActive(iRun,:)                            ...
                                            , 'Enable', 'on', 'off'                           ...
                                            });
        set(hRunComment(iRun) , 'Callback', { @obj.fcnSetProperty, 'String', @isempty         ...
                                            , tRunComment(iRun)                               ...
                                            , 'ForegroundColor', [0 0 0], obj.HILIGHT_COLOR   ...
                                            });
        executeCallback(hRunComment(iRun));
        
        for iBlock = 1:maxBlocks
          if isempty(hBlockComment(iRun,iBlock))
            continue;
          end
          set ( hBlockComment(iRun,iBlock)                                              ...
              , 'Callback', { @obj.fcnSetProperty, 'String', @isempty                   ...
                            , tBlockComment(iRun,iBlock)                                ...
                            , 'ForegroundColor', [0 0 0], obj.HILIGHT_COLOR             ...
                            }                                                           ...
              );
          executeCallback(hBlockComment(iRun,iBlock));
        end
      end
      
    end      
      
    %----- Commits the user's editing of daily data
    function fcnCommitDataEdit(obj, handle, event, hDialog, iAni, iDay, hRunActive, hRunComment, hBlockActive, hBlockComment)

      % Retrieve active run/block selections and comments
      for iRun = 1:numel(obj.animal(iAni).data(iDay).run)
        obj.animal(iAni).data(iDay).run(iRun).isActive                  = get(hRunActive(iRun) , 'Value') > 0;
        obj.animal(iAni).data(iDay).run(iRun).comments                  = get(hRunComment(iRun), 'String');
        
        for iBlock = 1:numel(obj.animal(iAni).data(iDay).run(iRun).block)
          obj.animal(iAni).data(iDay).run(iRun).block(iBlock).isActive  = get(hBlockActive(iRun,iBlock) , 'Value') > 0;
          obj.animal(iAni).data(iDay).run(iRun).block(iBlock).comments  = get(hBlockComment(iRun,iBlock), 'String');
        end
      end
      
      % Recompute display and close dialog box
      obj.drawAniDayLabels(iAni, iDay);
      close(hDialog);
      
    end
    
    %----- Callback for automagic maze ID determination
    function fcnComputeMaze(obj, handle, event, iAni)
      
      if    isempty(obj.animal(iAni).data)                        ...
        ||  isempty(obj.animal(iAni).data(end).run)               ...
        ||  isempty(obj.animal(iAni).data(end).run(end).block)
        % If the animal has no behavioral data, use the default
        mazeID        = obj.animal(iAni).mainMazeID;

      else
        % Obtain the last maze run by the animal
        mazeID        = obj.animal(iAni).data(end).run(end).block(end).mainMazeID;

        % Obtain specifications for the current experiment
        if isfunction(obj.animal(iAni).protocol)
          numMazes  = numel(obj.animal(iAni).protocol());
          step      = 1/(numMazes-1);
          set ( obj.guiAnimal(iAni).sldMaze           ...
              , 'Min'       , 1                       ...
              , 'Max'       , numMazes                ...
              , 'SliderStep', [step, max(step,1/4)]   ...
              , 'Value'     , numMazes                ...
              );
        end
      end
      
      % Safeguard in case no sessions has been run yet
      if ~isfinite(mazeID)
        mazeID        = 1;
      end

      % HACK: I have no idea why but the following is neccessary for
      % the slider to display the proper location
      drawnow;
      set ( obj.guiAnimal(iAni).sldMaze           ...
          , 'Value'     , mazeID                  ...
          );

      % Set the maze ID display
      obj.animal(iAni).mainMazeID = mazeID;
      set ( obj.guiAnimal(iAni).edtMaze           ...
          , 'String'          , num2str(mazeID)   ...
          , 'UserData'        , false             ...
          );
      
    end
    
    %----- Callback to set table data to the variable to edit
    function fcnSelectEditable(obj, handle, event, hTable)
      
      % Get the variable to edit
      allVariables    = get(handle, 'String');
      dates           = get(hTable, 'UserData');
      
      % Store previously edited data in its proper location
      allData         = get(handle, 'UserData');
      table           = get(hTable, 'Data');
      if ~isempty(table)
        allData.(allVariables{allData.index}) = table;
      end
      allData.index   = get(handle, 'Value');
      
      % Load the requested table
      set(hTable, 'Data'    , allData.(allVariables{allData.index}));
      set(handle, 'UserData', allData);
      
    end
    
    %----- Callback to toggle reward delivery valve open/close state
    function fcnToggleReward(obj, handle, event, status)
      
      if nargin < 4
        status    = get(obj.btnValve, 'UserData');
      else
        set(obj.btnValve, 'UserData', status);
      end
      
      obj.setupDAQ();
      
      % If initially on, turn it off
      if status
        set ( obj.btnValve                      ...
            , 'String'          , 'Open valve'  ...
            , 'ForegroundColor' , [0 0 0]       ...
            , 'FontWeight'      , 'normal'      ...
            , 'UserData'        , false         ...
            );
        if RigParameters.hasDAQ
          turnOffReward();
        end
        uicontrol(obj.btnReward);
        
      % If initially off, turn it on
      else
        set ( obj.btnValve                      ...
            , 'String'          , 'Close valve' ...
            , 'ForegroundColor' , [1 0 0]       ...
            , 'FontWeight'      , 'bold'        ...
            , 'UserData'        , true          ...
            );
        if RigParameters.hasDAQ
          turnOnReward();
        end
        uicontrol(obj.btnValve);

        % Prevent infinite valve opening durations
        stop(obj.valveTimer);
        start(obj.valveTimer);
      end
      
    end

    
    %----- Set up DAQ communications as necessary
    function setupDAQ(obj)

      if RigParameters.hasDAQ
        nidaqPulse('end');
        nidaqPulse('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.rewardChannel);
      end

    end
    
    %----- Safety off switch for reward delivery valve
    function turnOffValve(obj, varargin)
      stop(obj.valveTimer);
      executeCallback(obj.btnValve, 'Callback', [], true);
    end  
    
    %----- Update animal motion information
    function pollMotion(obj, varargin)
      
      % Obtain x,y velocity and speed
      velocity          = moveArduinoLiteralMEX(obj.instruments);
      velocity          = velocity(1:2);
      velocity(end+1)   = sqrt(sum(velocity.^2));
      
      % Update lines for velocity data
      index             = get(obj.linMotion(1), 'UserData');
      for iMotion = 1:numel(TrainingRegiment.MOTION_LABEL)
        motionY         = get(obj.linMotion(iMotion), 'YData');
        motionY(index)  = velocity(iMotion);
        set ( obj.linMotion(iMotion)                      ...
            , 'YData'           , motionY                 ...
            );
      end
      
      % Update current time indicator
      timeX             = get(obj.linMotion(1), 'XData');
      set ( obj.linMotion(end)                            ...
          , 'XData'             , timeX([index index])    ...
          );
        
      % Update time index
      if index < numel(motionY)
        index           = index + 1;
      else
        index           = 1;
      end
      set(obj.linMotion(1:numel(TrainingRegiment.MOTION_LABEL)), 'UserData', index);
    end  
    
    
    %----- Callback to toggle variable values
    function fcnToggleSetting(obj, handle, event, property)

      obj.(property)  = get(handle, 'Value');
        
    end
    
    %----- Callback that calls the user-defined action function 
    function fcnSubmitAction(obj, handle, event)

      % Retrieve selection
      index                 = get(obj.btnSubmit, 'UserData');
      info                  = obj.animal(index(1));
      info.overrideMazeID   = get(obj.guiAnimal(index(1)).edtMaze, 'UserData');
      info.color            = obj.colorID(index(1), :);
      info.sessionIndex     = index(2);
      info.day              = index(3);

      % Set status text and disable multiple submissions
      set(obj.btnSubmit, 'Enable', 'off', 'String', sprintf('[[  %s %s  ]]', obj.actionStr{end}, info.name));
      set(obj.btnCancel, 'Enable', 'off');
      drawnow;
      
      obj.closeInstruments();
      
      % Since the user has commited, save to disk
      obj.save();

      % Call the user function
      obj.actionFcn(info);
        
    end
    
    %----- Callback that exits without success
    function fcnCancelAction(obj, handle, event)
      
      obj.closeGUI();
      if ~isempty(obj.cancelFcn)
        obj.cancelFcn();
      end
      
    end
    
    
    %----- Callback to switch git repository branch
    function fcnCheckRepository(obj, handle, event, launchDir)

      [status,out]    = system('git status --porcelain');
      if status ~= 0
        set ( handle  , 'BackgroundColor'   , TrainingRegiment.ERROR_COLOR      ...
                      , 'String'            , '( unknown )'                     ...
                      , 'UserData'          , false                             ...
            );
      elseif isempty(out)
        set ( handle  , 'BackgroundColor'   , TrainingRegiment.OKAY_COLOR       ...
                      , 'String'            , 'Clean'                           ...
                      , 'UserData'          , true                              ...
            );
      else
        set ( handle  , 'BackgroundColor'   , TrainingRegiment.ERROR_COLOR      ...
                      , 'String'            , 'DIRTY'                           ...
                      , 'UserData'          , false                             ...
            );

        if nargin < 4 || launchDir
          [~,gitDir]  = system('git rev-parse --show-toplevel');
          gitDir      = strrep(gitDir, '/', filesep);
          system(sprintf('explorer "%s"', gitDir));
        end
      end
      
    end
    
    %----- Callback to switch git repository branch
    function fcnSwitchRepository(obj, handle, event)
      
      executeCallback(obj.btnRepository, 'Callback', [], false);
      if get(obj.btnRepository, 'UserData') ~= true
        errordlg('Uncomitted changes are present! Commit your changes, refresh the repository status, and try again.', 'Cannot switch git branch', 'modal');
        return;
      end
      
      branches      = get(handle, 'String');
      branch        = branches{get(handle, 'Value')};
      choice        = questdlg( sprintf('Switch to git repository branch "%s"?', branch)    ...
                              , 'Switch git repository branch', 'Yes', 'No', 'Yes'          ...
                              );
      if ~strcmp(choice, 'Yes')
        set(handle, 'Value', get(handle, 'UserData'));
        return;
      end
      
      clear('mex');
      [status,out]  = system(sprintf('git checkout %s', branch));
      if status ~= 0
        errordlg(out, ['Checkout error when switching to branch ' branch], 'modal');
        return;
      end
      
      choice        = questdlg('Restart Matlab? You probably should because classes can have changed -- proceed at your own risk!', 'Restart Matlab', 'Yes', 'No', 'Yes');
      if strcmp(choice, 'Yes')
        TrainingRegiment.fcnRestartMatlab(handle, event);
      end

    end
    
    
    %----- Callback to deliver ad lib rewards
    function fcnDeliverReward(obj, handle, event, numRewards, interval)
      
      % Open communications line with reward delivery system if necessary
      obj.setupDAQ();
      
      % If an interval was specified, deliver in pulses
      if nargin > 4
        if isgui(obj.btnSubmit)
          submitText  = get(obj.btnSubmit, 'String');
          set(obj.btnSubmit, 'Enable', 'off');
        end
        
        for iReward = 1:obj.(numRewards)
          if iReward > 1
            pause(obj.(interval));
          end

          if isgui(obj.btnSubmit)
            set(obj.btnSubmit, 'String', sprintf('[[  Giving reward #%d  ]]', iReward));
          end
          drawnow;
          if RigParameters.hasDAQ
            deliverReward([], 1000*RigParameters.rewardDuration);
          end
        end
        
        if isgui(obj.btnSubmit)
          set(obj.btnSubmit, 'String', submitText, 'Enable', 'on');
        end
        
        
      % Otherwise deliver a lump sum
      elseif RigParameters.hasDAQ
        deliverReward([], 1000*RigParameters.rewardDuration * obj.(numRewards));
      end
      
      if isgui(obj.btnSubmit)
        uicontrol(obj.btnSubmit);
      end
      
    end
    
    %----- Callback for edit fields that control object property values
    function fcnEditProperty(obj, handle, event, property, units)
      value             = get(handle, 'String');
      
      % Handle quantities with units
      if nargin > 4 && ~isempty(units)
        [value, number] = obj.getNumber(value, units);
        set(handle, 'String', value);
        obj.(property)  = eval(number{1});
        
      % Otherwise interpret value verbatim
      else
        obj.(property)  = eval(value);
      end
      
    end
    
    %----- Callback for toggling active status of an animal
    function fcnToggleAnimal(obj, handle, event, iAni, value)
      
      if nargin < 5
        value                     = get(obj.guiAnimal(iAni).chkAnimal, 'Value');
      else
        set(obj.guiAnimal(iAni).chkAnimal, 'Value', value);
      end
      obj.animal(iAni).isActive   = value;
      
      if value
        set ( obj.guiAnimal(iAni).session                   ...
            , 'FaceColor'           , obj.colorID(iAni,:)   ...
            );
      else
        set ( obj.guiAnimal(iAni).session                   ...
            , 'FaceColor'           , 'none'                ...
            );
      end

    end
    
    %----- Callback for selecting an existing animal
    function fcnSelectAnimal(obj, handle, event, iAni, iSession, hFigure, altCallback)
      
      % Special case for right-clicks
      if nargin > 6 && strcmp(get(hFigure, 'SelectionType'), 'alt')
        altCallback{1}(altCallback{2:end});
        return;
      end
      
      % Obtain day index
      iDay            = day2index();
      
      % Default to closest session if none specified
      if nargin < 5 || isempty(iSession)
        refTime       = time2num();
        starts        = [obj.animal(iAni).session(:, iDay).start];
        [~,iSession]  = min(abs(starts - refTime));
      end
      
      % Turn off previous highlights
      set([obj.guiAnimal.panel obj.guiAnimal.info obj.guiAnimal.controls obj.guiAnimal.chkAnimal]   ...
                                                        , 'BackgroundColor' , obj.GUI_COLOR);
      set([obj.guiAnimal.chkAnimal]                     , 'ForegroundColor' , [0 0 0]);
      for jAni = 1:numel(obj.guiAnimal)
        set(obj.guiAnimal(jAni).session                 , 'EdgeColor'       , 'none');
        set(obj.guiAnimal(jAni).label                   , 'Color'           , [0 0 0]);
        set(obj.guiAnimal(jAni).dayText                 , 'Color'           , [0 0 0]);
        set(obj.guiAnimal(jAni).mazeText                , 'Color'           , obj.LABEL_COLOR);
        set(obj.guiAnimal(jAni).axsNumTrials            , 'YColor'          , obj.NTRIALS_COLOR);
      end
      
      % Color the selected panel
      set([obj.guiAnimal(iAni).panel obj.guiAnimal(iAni).info obj.guiAnimal(iAni).controls obj.guiAnimal(iAni).chkAnimal]   ...
                                                        , 'BackgroundColor' , obj.colorID(iAni,:));
      set(obj.guiAnimal(iAni).chkAnimal                 , 'ForegroundColor' , [1 1 1]);
      set(obj.guiAnimal(iAni).session(iSession,iDay)    , 'EdgeColor'       , [1 1 1]);
      set(obj.guiAnimal(iAni).label(iSession,iDay)      , 'Color'           , [1 1 1]);
      set(obj.guiAnimal(iAni).dayText                   , 'Color'           , [1 1 1]);
      set(obj.guiAnimal(iAni).mazeText                  , 'Color'           , [1 1 1]);
      set(obj.guiAnimal(iAni).axsNumTrials              , 'YColor'          , [1 1 1]);
      uistack(obj.guiAnimal(iAni).session(iSession,iDay), 'top');
      uistack(obj.guiAnimal(iAni).label(iSession,iDay)  , 'top');
      
      % Set selection data for action buttons
      actions     = [obj.btnEdit, obj.btnRemove];
      if isgui(obj.btnSubmit)
        actions(end+1)  = obj.btnSubmit;
        set(obj.btnSubmit , 'String'    , sprintf('%s %s (block #%d)', obj.actionStr{1}, obj.animal(iAni).name, iSession) ...
                          , 'FontWeight', 'bold'                                                                          ...
                          );
      end
      
      set(actions       , 'Enable'    , 'on', 'UserData', [iAni, iSession, iDay]);
      set(obj.btnEdit   , 'String'    , ['Edit ' obj.animal(iAni).name]);
      set(obj.btnRemove , 'String'    , ['Remove ' obj.animal(iAni).name]);
                      
      % If continuing a session, go straight to training instead of ad lib rewards
      if isgui(obj.btnSubmit)
        if      ~isempty(obj.animal(iAni).data)                                 ...
            &&  ~isempty(obj.animal(iAni).data(end).run)                        ...
            &&  ~isempty(obj.animal(iAni).data(end).run(end).block)             ...
            &&  isequal(obj.animal(iAni).data(end).date, obj.dateStamp())       ...
            &&  obj.animal(iAni).data(end).run(end).session == iSession
          uicontrol(obj.btnSubmit);
        else
          uicontrol(obj.btnReward);
        end
      end
      
      % Output synchronization and remote control
      if ~isempty(obj.dataSync)
        [~, imageFile, syncFile]  = obj.whichLog(obj.animal(iAni));
        
        % For ScanImage clients
        obj.dataSync.sync ( true, OutputSynchronizer.HELLO                      ...
                          , imageFile                                           ...
                          , sprintf('%.3gum', obj.animal(iAni).imagingDepth)    ...
                          );
        
        for iFile = 1:numel(obj.animal(iAni).refImageFiles)
          obj.dataSync.sync(true, obj.animal(iAni).refImageFiles{iFile});
        end
        
        % For everything else
        obj.dataSync.sync(false, OutputSynchronizer.HELLO, syncFile);
      end
      
    end
    
    %----- Callback for showing a tooltip for the selected statistic
    function fcnDisplayStatistic(obj, handle, event, iAni, format, scale)
      
      hTip  = obj.cursorMode.createDatatip(handle);
      set ( hTip                                                                    ...
          , 'UpdateFcn'       , {@TrainingRegiment.formatStatistic, format, scale}  ...
          , 'MarkerFaceColor' , 'none'                                              ...
          , 'MarkerEdgeColor' , TrainingRegiment.CURSOR_COLOR                       ...
          );
      
      obj.fcnSelectAnimal(handle, event, iAni);

    end
    
    %----- Callback for editing daily data
    function fcnEditDaily(obj, handle, event)

      % Obtain user input for daily data
      [info, dates] = obj.dialogEditDaily();
      if isempty(info)
        return;
      end
      
      % Record the user edited values
      for variable = fieldnames(info)'
        if ~isfield(obj.default.data, variable{:})
          continue;
        end
        table       = info.(variable{:});
        
        for iAni = 1:size(table,2)
          for iDate = 1:size(table,1)
            for iDay = 1:numel(obj.animal(iAni).data)
              if isequal(obj.animal(iAni).data(iDay).date, dates{iDate}(1:3))
                obj.animal(iAni).data(iDay).(variable{:}) = table(iDate, iAni);
                break;
              end
            end
          end
        end
      end
      
    end
    
    %----- Callback for adding an animal to the schedule
    function fcnAddAnimal(obj, handle, event)
      
      % Obtain user input for animal data
      info  = obj.dialogEditAnimal(obj.default.animal, {obj.animal.name});
      if isempty(info)
        return;
      end
      
      % Create an entry for the animal 
      iAni                        = numel(obj.animal) + 1;
      obj.animal(iAni)            = info;
      obj.rewardSize(end+1:iAni)  = RigParameters.rewardSize;

      % Update schedule and performance display 
      obj.drawAnimalInfo(iAni, obj.axsSchedule, obj.cntAnimal);
     
    end
    
    %----- Callback for editing info for an existing animal
    function fcnEditAnimal(obj, handle, event)
      
      % Obtain user input for animal data
      iAni  = get(handle, 'UserData');
      iAni  = iAni(1);          % Session and day number not required
      info  = obj.dialogEditAnimal(obj.animal(iAni), {obj.animal([1:iAni-1, iAni+1:end]).name});
      if isempty(info)
        return;
      end

      % Redraw animal schedule
      obj.animal(iAni)  = info;
      obj.drawAnimalInfo(iAni, obj.axsSchedule, obj.cntAnimal);

      % Update world/maze controls
      if str2double(get(obj.guiAnimal(iAni).edtMaze, 'String')) ~= info.mainMazeID
        set(obj.guiAnimal(iAni).edtMaze, 'String', num2str(info.mainMazeID));
        executeCallback(obj.guiAnimal(iAni).edtMaze);
      end
      
    end
    
    %----- Callback for removing an existing animal
    function fcnRemoveAnimal(obj, handle, event)

      % Remove animal from list
      selection           = get(handle, 'UserData');
      iAni                = selection(1);
      obj.animal(iAni)    = [];
      obj.turnOffAnimalActions();

      % Remake subsequent performance panels since this is the easiest way
      % to ensure proper setting of callbacks
      mazeInfo            = get([obj.guiAnimal(iAni+1:end).edtMaze], {'String', 'UserData'});
      for jAni = iAni:numel(obj.guiAnimal)
        delete( obj.guiAnimal(jAni).session );
        delete( obj.guiAnimal(jAni).label   );
        delete( obj.guiAnimal(jAni).info    );
        delete( obj.guiAnimal(jAni).panel   );
      end
      
      % Delete GUI elements
      obj.guiAnimal(iAni:end) = [];
      
      % Redraw GUI elements
      set(obj.figGUI, 'Visible', 'off');
      for jAni = 1:numel(obj.animal)
        obj.drawAnimalInfo(jAni, obj.axsSchedule, obj.cntAnimal);
      end
      set(obj.figGUI, 'Visible', 'on');
      
      for jAni = iAni:numel(obj.guiAnimal)
        set ( obj.guiAnimal(jAni).edtMaze             ...
            , 'String'    , mazeInfo{jAni-iAni+1,1}   ...
            , 'UserData'  , mazeInfo{jAni-iAni+1,2}   ...
            );
      end
      
    end
    
    %----- Callback to save this object to disk
    function fcnSaveRegiment(obj, handle, event)

      % Create the directory to save into if it doesn't already exist
      targetFile      = obj.absolutePath(obj.dataFile);
      targetPath      = parsePath(targetFile);
      if ~exist(targetPath, 'dir')
        mkdir(targetPath);
      end
      
      [name, path]    = uiputfile('*.mat', 'Save training regiment', targetFile);
      if ~ischar(name)
        return;
      end
      
      obj.setDataFile([path name]);
      
      [data, backup]  = obj.save();
      if isempty(data)
        warndlg('Regiment was not saved -- are you sure it''s not empty?', 'Failed to save training regiment');
      elseif isempty(backup)
        msgbox({'Regiment saved in', ['    ' data], 'No backup was made.'}, 'Training regiment saved');
      else
        msgbox({'Regiment saved in', ['    ' data], 'Previous data backed up in', ['    ' backup]}, 'Training regiment saved');
      end
      
    end

    %----- Callback to upload data to a given location
    function fcnImportData(obj, handle, event)
      
      obj.dialogImportData();
      
    end
    
    %----- Callback for slider-based update of maze ID
    function fcnSlideMaze(obj, slider, event, editor, iAni)
      set(editor, 'String', num2str(round(get(slider, 'Value'))));
      executeCallback(editor);
    end
    
    %----- Callback for edit-based update of maze ID
    function fcnEditMaze(obj, editor, event, slider, iAni)
      value   = str2double(get(editor, 'String'));
      if ~isfinite(value) || value < get(slider, 'Min')
        value = get(slider, 'Min');
      elseif value > get(slider, 'Max')
        value = get(slider, 'Max');
      end
      
      set ( slider, 'Value' , value );
      set ( obj.guiAnimal(iAni).edtMaze           ...
          , 'String'          , num2str(value)    ...
          , 'UserData'        , true              ...
          );

      obj.animal(iAni).mainMazeID = value;
    end

    %----- Computes a central position for a figure of the given size
    function position = computeFigurePos(obj, figureSize)
      
      if numel(figureSize) == 1
        figureSize  = floor(figureSize * obj.screenSize(3:4));
      elseif all(figureSize <= 1)
        figureSize  = floor(figureSize .* obj.screenSize(3:4));
      end      
      border        = round( (obj.screenSize(3:4) - figureSize) / 2 );
      position      = [obj.screenSize(1:2) + border, figureSize];

    end
    
    %----- Backup the given experiment to a standard location
    function backup = backupExperiment(obj, experimentFile, version)
      [~, name]     = parsePath(experimentFile);
      backup        = sprintf ( '%s%s%s_%.1f.mat'               ...
                              , TrainingRegiment.EXPERIMENT_DIR ...
                              , filesep                         ...
                              , name                            ...
                              , version                         ...
                              );
      
      backupFile    = obj.absolutePath(backup);
      makepath(backupFile);
      copyfile(experimentFile, backupFile);
    end
    
    %----- Locate info on an experiment by version
    function [record, iVersion] = findOrAddVersion(obj, version, experimentFile, lookupOnly)
      
      % Default values in case of failure
      record          = [];
      iVersion        = 0;
      
      
      % Look up experiment by name
      if ~isfield(obj.experiment, version.name)
        if lookupOnly;  return;   end
        obj.experiment.(version.name)   = struct('version', {});
      end
      
      % Try to locate the index with the same version number
      iVersion        = find( [obj.experiment.(version.name).version] == version.mazeVersion  ...
                            , 1, 'first'                                                      ...
                            );
      if isempty(iVersion)
        if lookupOnly;  return;   end
      
        % Create a backup of the experiment if it doesn't already exist
        obj.experiment.(version.name)(end+1).file   ...
                      = obj.backupExperiment(experimentFile, version.mazeVersion);
        obj.experiment.(version.name)(end).version  ...
                      = version.mazeVersion;
        iVersion      = numel(obj.experiment.(version.name));
      end

      % Return the located experiment info
      record          = obj.experiment.(version.name)(iVersion);

    end
    
    %----- Rewire all paths
    function data = fixPaths(obj, data, name, searchPath, useAbsolute, verbose)
      
      % For structures, recursively parse all fields
      if isstruct(data)
        for field = fieldnames(data)'
          for index = 1:numel(data)
            data(index).(field{:})  = obj.fixPaths(data(index).(field{:}), field{:}, searchPath, useAbsolute, verbose);
          end
        end
      
      % For cells, parse each item
      elseif iscell(data)
        for index = 1:numel(data)
          data{index}       = obj.fixPaths(data{index}, name, searchPath, useAbsolute, verbose);
        end
        
      % Do work for file candidates that do not exist
      elseif    ischar(data)                                                  ...
            &&  ~isempty(regexp(name, TrainingRegiment.RGX_ISFILE, 'once'))
        candidate           = obj.absolutePath(data);
        if ~exist(candidate, 'file')
          [path, name, ext] = parsePath(data);

          % Search the given path list in order
          for iPath = 1:numel(searchPath)
            candidate       = fullfile(searchPath{iPath}, [name ext]);
            if exist(candidate, 'file')
              if useAbsolute
                candidate   = obj.absolutePath(candidate);
              else
                candidate   = obj.relativePath(candidate);
              end
              if verbose
                fprintf(' ---:GUESS:  %s -> %s\n', data, candidate);
              end
              data          = candidate;
              return;
            end
          end

          % if not found, do nothing
          if verbose
            fprintf(' ---:GUESS:  Failed for %s\n', data);
          end
          
        % If file exists, store absolute path
        elseif useAbsolute
          data              = candidate;
        end        
      end
      
    end

    
    %----- Setup remote control callbacks
    function registerListeners(obj, pager)
      
      pager.addCommandReceiver('E', @obj.remoteGetExperiment  );
      pager.addCommandReceiver('G', @obj.remoteSetRotationGain);
      pager.addCommandReceiver('M', @obj.remoteSetMazeID      );
      pager.addCommandReceiver('S', @obj.remoteStartTraining  );
                
    end
    
    %----- Obtain currently selected animal
    function [animal, session, day] = currentAnimal(obj)

      if ishghandle(obj.figGUI)
        index   = get(obj.btnEdit, 'UserData');
      else
        index   = [];
      end
      
      if ~isempty(index)
        animal  = index(1);
        session = index(2);
        day     = index(3);
      else
        animal  = [];
        session = [];
        day     = [];
      end
      
    end
    
    %----- Remote control : Get experiment info
    function remoteGetExperiment(obj, pager, event)

      iAni              = obj.currentAnimal();
      if ~isempty(iAni)
        
        [~,name,ext]    = parsePath(obj.animal(iAni).experiment);
        
        info            = struct();
        info.animal     = obj.animal(iAni).name;
        info.experiment = [name ext];
        info.maze       = obj.animal(iAni).mainMazeID;
        pager.command ( event.channel                           ...
                      , {}, {}, @IPPager.retryUntilNextCommand  ...
                      , 'e', info                               ...
                      );
        
      end
      
    end
    
    %----- Remote control : set rotational gain
    function remoteSetRotationGain(obj, pager, event)

      iAni        = obj.currentAnimal();
      if ~isempty(iAni)
        
        obj.animal(iAni).virmenRotationsPerRev  = event.message;
        pager.broadcast(event.channel, 'G', obj.animal(iAni).virmenRotationsPerRev);
        
      end
      
    end
    
    %----- Remote control : set maze ID
    function remoteSetMazeID(obj, pager, event)

      iAni        = obj.currentAnimal();
      if ~isempty(iAni)
        
        set(obj.guiAnimal(iAni).sldMaze, 'Value', event.message);
        executeCallback(obj.guiAnimal(iAni).sldMaze);
        pager.broadcast(event.channel, 'M', obj.animal(iAni).mainMazeID);
        
      end
      
    end
    
    %----- Remote control : start training animal
    function remoteStartTraining(obj, pager, event)
      
      iAni        = obj.currentAnimal();
      if ~isempty(iAni) && isgui(obj.btnSubmit)
        executeCallback(obj.btnSubmit);
      end
      
    end

    
  end
  
  %________________________________________________________________________
  methods (Static)

    %----- Structure conversion to load an object of this class from disk
    function obj = loadobj(frozen)

      % Start from default constructor
      obj               = TrainingRegiment('', '');
    
      %**************************  LEGACY SUPPORT  **************************
      for name = fieldnames(frozen.experiment)'
        if ~isfield(frozen.experiment.(name{:}), 'exper')
          [frozen.experiment.(name{:}).exper]   = deal([]);
        end
        if ~isfield(frozen.experiment.(name{:}), 'maze')
          [frozen.experiment.(name{:}).maze]    = deal(struct([]));
        end
      end
      if isfield(frozen.animal, 'mazeID')
        for iAni = 1:numel(frozen.animal)
          frozen.animal(iAni).mainMazeID        = frozen.animal(iAni).mazeID;
        end
        frozen.animal   = rmfield(frozen.animal, 'mazeID');
      elseif isfield(frozen.animal, 'firstMaze')
        for iAni = 1:numel(frozen.animal)
          frozen.animal(iAni).mainMazeID        = frozen.animal(iAni).firstMaze;
        end
        frozen.animal   = rmfield(frozen.animal, 'firstMaze');
      end
      if isfield(frozen.animal, 'vasculatureFile')
        for iAni = 1:numel(frozen.animal)
          frozen.animal(iAni).refImageFiles = {frozen.animal(iAni).vasculatureFile};
        end
        frozen.animal   = rmfield(frozen.animal, 'vasculatureFile');
      elseif isfield(frozen.animal, 'vasculatureFiles')
        for iAni = 1:numel(frozen.animal)
          frozen.animal(iAni).refImageFiles = frozen.animal(iAni).vasculatureFiles;
        end
        frozen.animal   = rmfield(frozen.animal, 'vasculatureFiles');
      end
      if isfield(frozen, 'autoCalcMaze')
        frozen          = rmfield(frozen, 'autoCalcMaze');
      end
      if isfield(frozen, 'uploadPath')
        frozen          = rmfield(frozen, 'uploadPath');
      end
      if isfield(frozen.animal, 'motionBlur')
        for iAni = 1:numel(frozen.animal)
          if frozen.animal(iAni).motionBlur > 0
            frozen.animal(iAni).motionBlurRange = [1 frozen.animal(iAni).motionBlur];
          else
            frozen.animal(iAni).motionBlurRange = [];
          end
        end
        frozen.animal   = rmfield(frozen.animal, 'motionBlur');
      end
      
      hasDuration       = true;
      for iAni = 1:numel(frozen.animal)
        for iDay = 1:numel(frozen.animal(iAni).data)
          for iRun = 1:numel(frozen.animal(iAni).data(iDay).run)
            if hasDuration && ~isfield(frozen.animal(iAni).data(iDay).run(iRun).block, 'duration')
              hasDuration = false;
              warning('TrainingRegiment:loadobj', 'Per-block duration was not stored (as in new version), will use a guesstimate.');
            end
            if hasDuration
              break;
            end
            
            if ~isstruct(frozen.animal(iAni).data(iDay).run(iRun).block)
              frozen.animal(iAni).data(iDay).run(iRun).block  = repmat(obj.default.block, 0);
            end
         
            runDuration = frozen.animal(iAni).data(iDay).run(iRun).duration;
            numTrials   = sum([frozen.animal(iAni).data(iDay).run(iRun).block.numTrials], 1);
            totTrials   = sum(numTrials);
            for iBlock = 1:numel(frozen.animal(iAni).data(iDay).run(iRun).block)
            	frozen.animal(iAni).data(iDay).run(iRun).block(iBlock).duration = runDuration * numTrials(iBlock) / totTrials;
            end
          end
        end
      end
      
      hasMedianDur      = true;
      for iAni = 1:numel(frozen.animal)
        for iDay = 1:numel(frozen.animal(iAni).data)
          for iRun = 1:numel(frozen.animal(iAni).data(iDay).run)
            if hasMedianDur && ~isfield(frozen.animal(iAni).data(iDay).run(iRun).block, 'medianTrialDur')
              hasMedianDur  = false;
              warning('TrainingRegiment:loadobj', 'Median trial duration was not stored (as in new version), will use the mean.');
            end
            if hasMedianDur
              break;
            end
         
            if ~isstruct(frozen.animal(iAni).data(iDay).run(iRun).block)
              frozen.animal(iAni).data(iDay).run(iRun).block  = repmat(obj.default.block, 0);
            end
            
            numTrials   = sum([frozen.animal(iAni).data(iDay).run(iRun).block.numTrials], 1);
            for iBlock = 1:numel(frozen.animal(iAni).data(iDay).run(iRun).block)
            	frozen.animal(iAni).data(iDay).run(iRun).block(iBlock).medianTrialDur   ...
                        = frozen.animal(iAni).data(iDay).run(iRun).block(iBlock).duration / numTrials(iBlock);
            end
          end
        end
      end
      %**********************************************************************
      
      % Transiently calculated properties
      obj.colorID       = obj.decideColors(numel(frozen.animal));
      obj.rewardSize    = repmat(RigParameters.rewardSize, size(frozen.animal));
      
      % Default values
      defaults          = replaceEmptyStruct(obj.default, obj.default);
      
      % Merge all fields from the frozen copy into the new object
      for field = fieldnames(frozen)'
        if isfield(obj.default, field{:})
          fDefault      = defaults.(field{:});
        else
          fDefault      = struct();
        end
        obj.(field{:})  = mergestruct ( obj.(field{:})                  ...
                                      , frozen.(field{:})               ...
                                      , fDefault                        ...
                                      , ~strcmp(field{:},'experiment')  ...
                                      );
      end
      
      % In case the animal has run no sessions, an empty first session can be present; this
      % should be removed to not break other code that requires valid sessions
      for iAni = 1:numel(obj.animal)
        if      ~isempty(obj.animal(iAni).data)          ...
            &&  isempty(obj.animal(iAni).data(1).date)   ...
            &&  isnan(obj.animal(iAni).data(1).run.block.mainMazeID)
          obj.animal(iAni).data(1) = [];
        end
      end
      
    end

    
    %----- Decides on colors for each animal
    function colors = decideColors(maxAnimals)
      
      if maxAnimals <= 9
        colors  = linspecer(9 , 'qualitative');
      elseif maxAnimals <= 12
        colors  = linspecer(12, 'qualitative');
      else
        colors  = linspecer(maxAnimals);
      end
      
    end
    
    %----- Compute main file path
    function [dataPath, dataFile, backupFile] = decideDataFile(filePath)
      
      % Standardize file path
      import java.io.File;
      if ~java.io.File(filePath).isAbsolute()
        filePath      = fullfile(pwd, filePath);
      end
      [path,name,ext] = parsePath(char(filePath));
      if isempty(path)
        path          = pwd;
      end
      
      dataPath        = path;
      dataFile        = [ name ext ];
      backupFile      = TrainingRegiment.decideBackupFile(dataFile);
      
    end    
    
    %----- Compute backup file path
    function backupFile = decideBackupFile(dataFile)
      
      [~,name]        = parsePath(dataFile);
      backupFile      = sprintf ( '%s%s%s_%s.mat'               ...
                                , TrainingRegiment.BACKUP_DIR   ...
                                , filesep                       ...
                                , name                          ...
                                , datestr(now, 'yyyymmdd-hhMM') ...
                                );
    end    
    
    %----- Check for printable characters
    function yes = isPrintable(character)
      yes   = ( ~isempty(character) && character > 31 && character < 127 );
    end
    
    %----- Obtain numeric input with optional postfix
    function [value, number] = getNumber(str, postfix)
      number    = regexp( str, TrainingRegiment.RGX_NUMBER, 'tokens', 'once' );
      if isempty(number)
        value   = '';
        number  = {'nan'};
      elseif nargin > 1
        value   = strcat(number{1}, postfix);
      else
        value   = number{1};
      end
    end
    
    %----- Ensure proper Matlab-compatible variable name
    function validateName(handle, event, varargin)
      input   = regexp(get(handle, 'String'), TrainingRegiment.RGX_VARNAME, 'tokens');
      if isempty(input)
        input = '';
      else
        input = strcat(input{:});
        input = input{:};
      end

      if isempty(input) || ~isletter(input(1))
        input = strcat(TrainingRegiment.DEFAULT_ID, input);
      end
      
      set( handle, 'String', input );
    end
    
    %----- Ensure proper age entry (in weeks)
    function validateAge(handle, event, varargin)
      set( handle, 'String', TrainingRegiment.getNumber(get(handle, 'String'), ' week(s)') );
    end
    
    %----- Ensure proper weight entry (in grams)
    function validateWeight(handle, event, varargin)
      set( handle, 'String', TrainingRegiment.getNumber(get(handle, 'String'), ' gram(s)') );
    end
    
    %----- Ensure proper liquid reward entry (in mL)
    function validateLiquid(handle, event, varargin)
      set( handle, 'String', TrainingRegiment.getNumber(get(handle, 'String'), ' mL') );
    end
    
    %----- Ensure proper date entry
    function validateDate(handle, event, varargin)
      input       = regexp(get(handle, 'String'), TrainingRegiment.RGX_DATE, 'tokens', 'once');
      ref         = clock;
      if isempty(input)
        input     = {ref(2), ref(3), ref(1)};
      else
        input     = { max(min( str2double(input{1}) , 12 ), 1)  ...
                    , max(min( str2double(input{2}) , 31 ), 1)  ...
                    ,     min( str2double(input{3}) , ref(1) )  ...
                    };
      end
      if log10(input{3}) < 2
        input{3}  = floor(ref(1)/100) * 100 + input{3};
      end
      
      set( handle, 'String', sprintf('%d/%d/%d', input{:}) );
    end
    
    %----- Ensure proper time entry
    function validateTime(handle, event, hSession, varargin)
      % Parse string and extract hours/minutes
      input           = regexp(get(handle, 'String'), TrainingRegiment.RGX_TIME, 'tokens', 'once');
      if isempty(input)
        ref           = clock;
        input         = {ref(4), ref(5)};
      else
        input         = { min(max( str2double(input{1}) , TrainingRegiment.HOURS(1) ), TrainingRegiment.HOURS(2))  ...
                        , min(max( str2double(input{2}) , 0 ), 59)  ...
                        };
      end
      
      % Update string display for uniformity
      set( handle, 'String', sprintf('%02d:%02d', input{:}) );

      % Modify hour stored for the current session
      iSession        = round(get(hSession, 'Value'));
      times           = get(handle, 'UserData');
      times(iSession) = input{1} + input{2}/60;
      set(handle, 'UserData', times);
    end
    
    %----- Ensure proper duration entry
    function validateDuration(handle, event, hSession, varargin)
      % Modify duration stored for the current session
      iSession            = round(get(hSession, 'Value'));
      durations           = get(handle, 'UserData');
      durations(iSession) = str2double(get(handle, 'String'));
      set(handle, 'UserData', durations);
    end
    
    %----- Ensure that selected file exists
    function validateFile(handle, event, setup, varargin)
      % In case user provides just the file name, attempt to find the
      % closest matching existing file
      input     = get(handle, 'String');
      if ~isempty(regexp(input, '^[^:\/]+$', 'once'))
        if isempty(regexpi(input, '.mat$', 'once'))
          input = [input '.mat'];
        end
        input   = [pwd filesep input];
        if exist(input, 'file')
          set(handle, 'String', input);
          if nargin > 2
            setup(varargin{:});
          end
        end
      end
    end
    
    %----- Nothing to do for now
    function validateList(handle, event, varargin)
    end
    
    %----- Nothing to do for now
    function validateString(handle, event, varargin)
    end
    
    %----- Populate quantity table according to experimental protocol
    function validateMazeQuantities(handle, event, hTable, protocol, experiment)

      % Verify existence of experiment
      if ~exist(experiment, 'file')
        return;
      end
      
      % Get number of mazes according to protocol
      mazes         = protocol();
      quantities    = get(hTable, 'Data');
      vr            = load(experiment);
      mazeLabels    = arrayfun( @(x) sprintf('%s%d', vr.exper.worlds{1}.name(1), x)   ...
                              , 1:numel(mazes)  , 'UniformOutput', false              ...
                              );

      % Resize data to fit number of mazes
      if size(quantities,2) > numel(mazes)
        quantities  = quantities(:, 1:numel(mazes));
      elseif size(quantities,2) < numel(mazes)
        nExtras     = numel(mazes) - size(quantities,2);
        quantities(:, end+(1:nExtras)) = repmat(quantities(:,end), 1, nExtras);
      end
      
      % Format and set table content
      set ( hTable                                                ...
          , 'ColumnName'  , mazeLabels                            ...
          , 'ColumnWidth' , num2cell(45 * ones(1,numel(mazes)))   ...
          , 'ColumnFormat', repmat({'bank'}, 1, numel(mazes))     ...
          , 'Data'        , quantities                            ...
          );
      
    end
    
    %----- Provides file path entry using either text or dialog box
    function dispatchFileInput(handle, event, mask, title, submitter, varargin)
      if strcmp(event.Key, 'o') && strcmpi(event.Modifier, 'control')
        [filename, pathname] = uigetfile([pwd filesep mask], title);
        
        if filename ~= 0
          set(handle, 'String', [pathname filename]);
          uicontrol(handle);
          executeCallback(handle, '', event, varargin{:});
          
          if nargin > 5
            protocols       = get(varargin{end-1}, 'UserData');
            submitter ( handle, event, varargin{1:end-2}            ...
                      , protocols{get(varargin{end-1}, 'Value')}    ...
                      , get(handle, 'String')                       ...
                      );
          end
        end
      else
        TrainingRegiment.dispatchKeypress(handle, event, submitter);
      end
    end
    
    function dispatchDirInput(handle, event, title, submitter)
      if strcmp(event.Key, 'o') && strcmpi(event.Modifier, 'control')
        pathname  = uigetdir(pwd, title);
        
        if pathname ~= 0
          set(handle, 'String', pathname);
          uicontrol(handle);
          executeCallback(handle, '', event);
        end
      else
        TrainingRegiment.dispatchKeypress(handle, event, submitter);
      end
    end
    
    %----- Provides shortcut keys for listbox selection
    function dispatchListbox(handle, event, submitter)
      if strcmp(event.Key, 'a') && strcmpi(event.Modifier, 'control')
        set(handle, 'Value', 1:numel(get(handle, 'String')));
      else
        TrainingRegiment.dispatchKeypress(handle, event, submitter);
      end
    end
    
    
    %----- Copy user input from one control to others
    function copyInput(handle, event, source, target)
      if size(source, 1) > 1
        for row = 1:size(source, 1)
          set ( target(row,:)                               ...
              , 'String'  , get(source(row,:), 'String')    ...
              , 'UserData', get(source(row,:), 'UserData')  ...
              );
        end
      else
        for col = 1:size(source, 2)
          set ( target(:,col)                               ...
              , 'String'  , get(source(:,col), 'String')    ...
              , 'UserData', get(source(:,col), 'UserData')  ...
              );
        end
      end
    end
    
    %----- Switch input from one session to another
    function switchSession(handle, event, hStart, hDuration)
      iSession        = round(get(handle, 'Value'));
      set(handle, 'TooltipString', ['Block #' num2str(iSession)]);
      
      for iDay = 1:numel(hStart)
        startTimes    = get(hStart(iDay), 'UserData');
        if numel(startTimes) < iSession
          startTimes(end+1:iSession)  = nan;
          set(hStart(iDay), 'UserData', startTimes);
        end
        
        set(hStart(iDay), 'String', time2str(startTimes(iSession)));
      end
      
      for iDay = 1:numel(hDuration)
        durations     = get(hDuration(iDay), 'UserData');
        if numel(durations) < iSession
          durations(end+1:iSession)   = nan;
          set(hDuration(iDay), 'UserData', durations);
        end
        
        set(hDuration(iDay), 'String', num2str(durations(iSession)));
      end
    end

    %----- Delete an entire session
    function deleteSession(handle, event, hSlider, hStart, hDuration)
      iSession        = round(get(hSlider, 'Value'));
      
      for iDay = 1:numel(hStart)
        startTimes    = get(hStart(iDay), 'UserData');
        if numel(startTimes) >= iSession
          startTimes(iSession)  = [];
        end
        
        set(hStart(iDay), 'UserData', startTimes);
      end
      
      for iDay = 1:numel(hDuration)
        durations     = get(hDuration(iDay), 'UserData');
        if numel(durations) >= iSession
          durations(iSession)   = [];
        end
                
        set(hDuration(iDay), 'UserData', durations);
      end
      
      set(hSlider, 'Value', max(1, iSession-1));
      executeCallback(hSlider, '', event);
    end
    
    %----- Allow keys to push buttons
    function buttonKeypress(handle, event, submitter)
      % Allow Enter to press buttons
      if strcmpi(event.Key, 'return')
        if isempty(event.Modifier)
          executeCallback(handle, '', event);
          
        % Allow alt+Enter to jump to submit button
        elseif nargin > 2 && ~isempty(regexpi(event.Modifier, '^(alt|control)$'))
          uicontrol(submitter);
        end
      end
    end
    
    %----- Commit/dismiss dialogs
    function dispatchKeypress(handle, event, submitter)
      % Allow alt+Enter to jump to submit button
      if      strcmpi(event.Key, 'return')                                    ...
          &&  numel(event.Modifier) == 1                                      ...
          &&  ~isempty(regexpi(event.Modifier{1}, '^(alt|control)$', 'once'))
        uicontrol(submitter);
      end
    end
    
    %----- Select an appropriate validation callback
    function fcn = deduceValidator(name)
      if ~isempty(regexpi(name, 'age$', 'once'))
        fcn   = @TrainingRegiment.validateAge;
      elseif ~isempty(regexpi(name, 'date', 'once'))
        fcn   = @TrainingRegiment.validateDate;
      elseif ~isempty(regexpi(name, 'weight', 'once'))
        fcn   = @TrainingRegiment.validateWeight;
      elseif ~isempty(regexpi(name, 'water', 'once'))
        fcn   = @TrainingRegiment.validateLiquid;
      elseif ~isempty(regexpi(name, 'experiment|Bank$', 'once'))
        fcn   = @TrainingRegiment.validateFile;
      elseif ~isempty(regexp(name, 'Factor$', 'once'))
        fcn   = @TrainingRegiment.validateMazeQuantities;
      elseif ~isempty(regexp(name, 'Files$', 'once'))
        fcn   = @TrainingRegiment.validateString;
      elseif ~isempty(regexp(name, TrainingRegiment.RGX_HASNAME, 'once'))
        fcn   = @TrainingRegiment.validateName;
      elseif ~isempty(regexpi(name, 'Method$', 'once'))
        fcn   = @TrainingRegiment.validateList;
      else
        fcn   = '';
      end
    end
    
    %----- Convert validated data to recorded values
    function data = deduceData(name, handle)

      % Special case for table data
      if isa(handle, 'matlab.ui.control.Table')
        data    = get(handle, 'Data');
        return;
      end

      
      value     = get(handle, 'String');
      
      if ~isempty(regexpi(name, 'date', 'once'))
        input   = regexp(value, TrainingRegiment.RGX_DATE, 'tokens', 'once');
        if isempty(input)
          data  = '';
        else
          data  = [str2double(input{3}), str2double(input{1}), str2double(input{2})];
        end
      elseif ~isempty(regexp(name, 'experiment|File$|Bank$', 'once'))
        data    = value;
      elseif ~isempty(regexp(name, TrainingRegiment.RGX_HASNAME, 'once'))
        data    = value;
      elseif ~isempty(regexp(name, 'Files$', 'once'))
        data    = cell(size(value,1), 1);
        for iData = numel(data):-1:1
          data{iData}   = regexp(value(iData, 1:end), '\S(.*\S|$)', 'match', 'once');
          if isempty(data{iData})
            data(iData) = [];
          end
        end
      elseif ~isempty(regexp(name, 'Method$', 'once'))
        data    = get(handle, 'UserData');
        data{end} = get(handle, 'Value');
      elseif iscell(value)
        fcn     = get(handle, 'UserData');
        if iscell(fcn)
          data  = fcn{get(handle, 'Value')};
        else
          data  = fcn(get(handle, 'Value'));
        end
      else
        data    = eval( TrainingRegiment.getNumber(value) );
      end
    end
    
    
    %----- Callback to programatically restart Matlab
    function fcnRestartMatlab(handle, event)
      TrainingRegiment.enableFigureClosing();
      
      startDir  = fileparts(which('startup'));
      startCmd  = sprintf('matlab -r "cd(''%s''); startup" &', startDir);
      system(startCmd);
      exit();
    end
    
    %----- Callback for performance plot axis range adjustment
    function fcnSlideLimit(handle, event, hAxis, what, minOrMax, regularizer)
      
      % Get the new value for the limit
      value             = get(handle, 'Value');
      if nargin > 5
        value           = regularizer(value);
      end
      limits            = get(hAxis, what);
      limits(minOrMax)  = value;
      
      % Ensure that limits remain a valid interval
      if limits(1) >= limits(2)
        if minOrMax == 1
          limits(1)     = limits(2) - 1;
        else
          limits(2)     = limits(1) + 1;
        end
      end
      set(hAxis, what, limits);
      
      % Ensure that slider limits cover the required range
      value             = limits(minOrMax);
      shouldAdjust      = false;
      if get(handle, 'Min') > value
        set(handle, 'Min', value);
        shouldAdjust    = true;
      end
      if get(handle, 'Max') < value
        set(handle, 'Max', value);
        shouldAdjust    = true;
      end
      if shouldAdjust
        range           = get(handle, 'Max') - get(handle, 'Min');
        set(handle, 'SliderStep', [1, range/2]/range);
      end
      set(handle, 'Value', value);
      
    end
    
    %----- Callback that flags user interaction as successful
    function fcnSubmit(handle, event)
      if isempty(get(handle, 'UserData'))
        set(handle, 'UserData', true);
      end
      uiresume(findParent(handle, 'figure'));
    end
    
    %----- Callback that exits without success
    function fcnCancel(handle, event, submitter)
      if nargin > 2
        set(submitter, 'UserData', []);
      end
      uiresume(findParent(handle, 'figure'));
    end

    %----- Callback that exits without success and closes the associated figure
    function fcnCloseFigure(handle, event)
      close(findParent(handle, 'figure'));
    end
    
    %----- Callback to set background of editor to red on user override
    function fcnSyncOverride(handle, event)
      if get(event.AffectedObject, 'UserData')
        set(event.AffectedObject, 'BackgroundColor', [1 0 0]);
      else
        set(event.AffectedObject, 'BackgroundColor', [1 1 1]);
      end
    end
    
    %----- Toggle checkboxes; if any item is unchecked, set all to 'on'
    function fcnToggleCheckbox(handle, event, hCheck)
      selection     = get(hCheck, 'Value');
      if iscell(selection)
        selection   = cell2mat(selection);
      end
      state         = ~all(selection);
      set(hCheck, 'Value', state);
    end
    
    %----- Prompts the user for a string to set as the control text
    function fcnSetString(handle, event, prompt, title)
      answer        = inputdlg(prompt, title, 1, {get(handle,'String')});
      if ~isempty(answer)
        set(handle, 'String', answer{:});
      end
    end

    %----- Change a property of the given uicontrol based on contents of another
    function fcnSetProperty(hCheck, event, checkProp, checkFcn, hSet, setProp, trueValue, falseValue)
      if checkFcn(get(hCheck, checkProp))
        set(hSet, setProp, trueValue);
      else
        set(hSet, setProp, falseValue);
      end
    end

    %----- Copy a property value to the system clipboard
    function fcnCopyToClipboard(handle, event, hSource, sourceProp, hIndex, indexProp)
      
      value     = get(TrainingRegiment.aIfBisEmpty(handle,hSource), sourceProp);
      if nargin > 5
        index   = get(TrainingRegiment.aIfBisEmpty(handle,hIndex) , indexProp);
        value   = value{index};
      end
      
      clipboard('copy', value);
      
    end
    
    %----- Runs the given function on property values
    function fcnRunFunction(handle, event, hSource, sourceProp, hIndex, indexProp, fcn)

      value     = get(TrainingRegiment.aIfBisEmpty(handle,hSource), sourceProp);
      if nargin > 5
        index   = get(TrainingRegiment.aIfBisEmpty(handle,hIndex) , indexProp);
        value   = value{index};
      end
      
      if iscell(value)
        for index = 1:numel(value)
          fcn(value{index});
        end
      else
        fcn(value);
      end
      
    end
    
    %----- Sets the state of associated buttons according to whether a file exists
    function fcnCheckFile(handle, event, hAction, hAssociate)
      
      filePath    = get(handle, 'String');
      iFile       = get(handle, 'Value');

      for iAssoc = 1:numel(hAssociate)
        assocPath = get(hAssociate(iAssoc), 'UserData');
        set(hAssociate(iAssoc), 'String', sprintf('Open %d figure(s)', numel(assocPath{iAssoc})));
        if isempty(assocPath{iAssoc})
          set(hAssociate(iAssoc), 'Enable', 'off');
        else
          set(hAssociate(iAssoc), 'Enable', 'on');
        end
      end
      
      if exist(filePath{iFile}, 'file')
        set(handle, 'BackgroundColor', [1 1 1]);
        set(hAction, 'Enable', 'on');
      else
        set(handle, 'BackgroundColor', TrainingRegiment.WEIRD_COLOR);
        set(hAction, 'Enable', 'off');
      end
      
    end
    
    
    %----- Loads the given file in the base workspace
    function loadInBaseWS(filePath)

      fprintf('** Loading %s\n', filePath);
      evalin('base', sprintf('load(''%s'')', filePath));
      commandwindow;
      
    end
    
    %----- Returns a if b is empty, otherwise b
    function x = aIfBisEmpty(a, b)
      if isempty(b)
        x     = a;
      else
        x     = b;
      end
    end
      
    %----- Vector of date info
    function stamp = dateStamp()
      stamp   = clock;
      stamp   = stamp(1:3);
    end
    
    %----- Standard form of 6-element date vector
    function t = date2vec(t)
      t = padarray(t, [0 6-numel(t)], 0, 'post');
    end
    
    %----- Data tip for formatted statistics
    function txt = formatStatistic(obj, event, format, scale)
      pos   = get(event, 'Position');
      if numel(pos) > 2
        txt = sprintf(format, pos(2), pos(3) * scale);
      else
        txt = sprintf(format, pos(2) * scale);
      end
    end

    
    %----- Obtain list of branches and current branch in repository
    function [branches, iCurrent] = getRepositoryInfo()
      
      [status, info]      = system('git branch');
      if status ~= 0
        branches          = {''};
        iCurrent          = 1;
        return;
      end
      
      branches            = regexp(deblank(info), '\n', 'split');
      branches            = cellfun(@strtrim, branches, 'UniformOutput', false);
      iCurrent            = find(strncmp(branches, '*', 1), 1, 'first');
      if isempty(iCurrent)
        branches{end+1}   = '';
        iCurrent          = numel(branches);
      else
        branches{iCurrent}= strtrim(branches{iCurrent}(2:end));
      end
      
    end
    
    %----- Make all open figures close-able
    function enableFigureClosing(handles)
      
      if nargin < 1
        handles   = findall(0, 'Type', 'figure');
      end
      set(handles, 'CloseRequestFcn', 'closereq');
      
    end
    
  end
  
end
