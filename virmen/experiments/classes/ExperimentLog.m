%% Book-keeping tool for ViRMEn experiments.
%
% Creating an object of this class starts collecting data for a log file
% that contains details of the maze configuration (including dynamically
% changed parameters) throughout the course of the experiment.
%
% Each log file is specific to an animal and a training day. Within the day
% there can be multiple temporally discontinuous sessions, and each session
% can have several blocks. The latter is defined by a change in maze
% parameters e.g. difficulty level or even the type of maze.
%
% Trial data is kept in blocks, where every block stores the index to
% thenew
% version structure; this index is incremented whenever some significant
% structure of the experiment has changed. The session structure specifies
% the list of blocks and overall information like start and duration.
%
% IMPORTANT:
%   Since ViRMEn performs behavioral updates in discrete frames, timestamps
%   are recorded based on vr.dt, which is the duration of the *previous*
%   frame. This means that the stored time is the *start* of the current
%   frame (relative to the start of the trial). If the user wants to record
%   other events he/she should then use the ViRMEn iteration number
%   vr.iterations instead of independent timestamps, particularly when it is 
%   not meaningful to subdivide events that happen within the frame e.g.
%   because it will anyway only take effect on the next ViRMEn iteration.
%
%
% The constructor takes a structure object whose fields determines what
% will be stored in the log. The following fields are required:
%   animal            : Animal data for informative purposes
%   logPath           : Output path of the log file
%   label             : Short label to identify the maze type
%   sessionIndex      : Index of session to log to; will continue an 
%                       existing session/log file if it exists
%   versionInfo       : Cell array of strings corresponding to fields in
%                       vr.exper.variables that contain version numbers to
%                       be saved for the current maze; should be
%                       incremented whenever some fundamental structure of
%                       the maze or experiment code has changed.
%   mazeData          : Cell array of strings, each of which corresponds to
%                       a field (in the vr structure) that is presumed to
%                       contain maze defining info and is therefore copied
%                       to the log as an identifying feature.
%   trialData         : Cell array of strings, each of which corresponds to
%                       a field (in the vr structure) of per-trial data to
%                       be logged. 
%   protocolData      : Cell array of strings, each of which corresponds to
%                       a field (in the vr.protocol structure) of per-trial
%                       data to be logged.
%   savePerNTrials    : Interval in terms of number of trials to save the
%                       logged data to disk. If set to inf, data will not
%                       be logged automatically and you have to explicitly 
%                       call the save() function.
%   totalTrials       : Total number of trials for storage preallocation.
%   repositoryLog     : If provided, should be the path to a text file with
%                       e.g. repository information to be logged per block.
%
% The following functions should be called by the user to log various types
% of information in the course of the experiment:
%   save()            : This is automatically called at the specified
%                       savePerNTrials. However it should also be called
%                       explicitly by the user at the end of an experiment,
%                       e.g. in the ViRMen terminationCodeFun() function,
%                       so as to flush remaining data to disk.
%   logStart()        : Call this at the beginning of each trial to log the
%                       time.
%   logTick()         : Call this in the ViRMen runtimeCodeFun() so that
%                       position and velocity data can be stored per
%                       iteration. IMPORTANT: This should be called at
%                       *every* iteration including the ones where
%                       logStart() and logEnd() have been called.
%                       Furthermore it should always be called after those
%                       functions, so that e.g. the start of a new entry
%                       for the next trial can be performed before logging
%                       data into it.
%   logEnd()          : Call this at the end of each trial, i.e. probably
%                       somewhere in the ViRMen runtimeCodeFun() function,
%                       to store data for that trial. Remember that this
%                       should be done before changing trial information
%                       variables.
%   logExtras()       : Call this to handle blocking inputs like comments
%                       after the end of a trial (e.g. inter-trial
%                       interval). If a finite savePerNTrials is specified,
%                       the log object can be saved to disk in this call.
%   toggleComment()   : Call this to toggle the user comment input state.
%                       This will cycle in the order
%                         [no comment -> current -> future]
%                       of the trial to 'attach' the comment to. Note that
%                       prompting for user input of the comment (at the
%                       Matlab prompt) should only occur at the end of the
%                       trial i.e. where you call the logExtras() function,
%                       so as not to interrupt behavior for the current
%                       trial.
%   ask()             : Prompt the user for additional information,
%                       typically at the beginning or end of the
%                       experiment. Note that this acts immediately and
%                       will block running of the experiment if called
%                       during a run.
%
classdef ExperimentLog < handle

  %------- Constants
  properties (Constant)
    COMMENT_AT      = [nan 0 1]     % Order of toggles for the comment prompting status
    COMMENT_STATUS  = { 'Cancelling request to comment.'                  ...
                      , 'Will prompt for a comment for this trial.'       ...
                      , 'Will prompt for a comment for the next trial.'   ...
                      };

    FIGURE_FILE     = '%s_%d.fig';
    
    SPATIAL_COORDS  = [1 2 4];      % Columns of vr.position and vr.velocity to store
    SENSOR_COORDS   = 1:5;          % Columns of raw sensor readout to store
%     SENSOR_COORDS   = 1:7;          % Columns of raw sensor readout to store
    SENSOR_DATASIZE = 'int16';      % Data type slpecifier for raw sensor readout
    
    DEFAULT_PREALLOCSIZE  = 10000   % Default size of arrays to preallocate
    PREALLOCATED_FIELDS   = { 'position'      ...
                            , 'velocity'      ...
                            , 'sensorDots'    ...
                            , 'collision'     ...
                            , 'time'          ...
%                             , 'Licks'    ...
                            }
  end
  
  %------- Private data
  properties (Access = protected, Transient)
    trialInfo                       % Storage structure for per-trial info
    emptyTrial                      % Preallocated storage structure for per-trial info
    console                         % Function to print status messages
    preallocSize                    % Size of arrays to preallocate
  end
  
  %------- Public data
  properties (SetAccess = protected, Transient)
    logFile                         % Log file that is being written to
    blockData                       % Data to be logged per block; a change starts a new block
    trialData                       % Data to be logged per trial
    protocolData                    % Data to be logged per trial from vr.protocol
    savePerNTrials                  % Log backup frequency

    newBlocks                       % Indices of blocks that have been recorded in the lifetime of this object
    writeIndex                      % Index that current trial will be written into
    writeCounter                    % Number of trials elapsed after last write, for saving to disk
    doComment                       % Index of COMMENT_AT state, which decides whether or not to query the user
    startComment                    % Comment to be logged at start of the next trial
    endComment                      % Comment to be logged at end of the current trial

    blockStart                      % tic value recorded when newBlock() is called
    trialEnded                      % >=1 if logEnd() has been called for the current trial but before the next logStart()
  end
  
  properties (SetAccess = protected)
    animal                          % Animal data for informative purposes
    label                           % Short label to identify the maze type
    session                         % Schedule info and list of trial blocks run during this session
    block                           % Blocks of trials with common maze configuration
    version                         % Versioning info (summary of maze details)
    currentTrial                    % The trial being currently recorded into
    currentIt                       % The trial time index being currently recorded into
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
    end
    
    %----- Constructor
    function obj = ExperimentLog(vr, cfg, console, preallocSize)

      % User configuration
      if nargin < 3
        obj.console           = [];
      else
        obj.console           = console;
      end
      if nargin < 4
        obj.preallocSize      = ExperimentLog.DEFAULT_PREALLOCSIZE;
      else
        obj.preallocSize      = preallocSize;
      end
      obj.blockData           = cfg.blockData;
      obj.trialData           = cfg.trialData;
      if isfield(cfg, 'protocolData')
        obj.protocolData      = cfg.protocolData;
      else
        obj.protocolData      = {};
      end
      obj.savePerNTrials      =  100; %cfg.savePerNTrials;
      obj.newBlocks           = [];
      obj.writeCounter        = 0;
      obj.doComment           = 1;
      obj.startComment        = '';
      obj.endComment          = '';
      
      % Session info
      obj.session(cfg.sessionIndex).start   = clock;
      obj.session(cfg.sessionIndex).end     = [];
      obj.session(cfg.sessionIndex).blocks  = [1 1];

      % Version info
      versioning.name         = vr.exper.name;
      for iVer = 1:numel(cfg.versionInfo)
        versioning.(cfg.versionInfo{iVer})  ...
                              = eval( vr.exper.variables.(cfg.versionInfo{iVer}) );
      end
      
      % Store repository log file if provided
      if isfield(cfg, 'repositoryLog')
        repositoryLog         = [ parsePath(mfilename('fullpath')) filesep cfg.repositoryLog ];
        logFID                = fopen(repositoryLog);
        versioning.repository = fgetl(logFID);
        fclose(logFID);
      end
      
      % Store all maze related info
      versioning.rig          = class2struct(RigParameters);
      versioning.variables    = vr.exper.variables;
      versioning.code         = vr.exper.experimentCode;
      versioning.worlds       = cellfun(@summarizeVirmenWorld, vr.exper.worlds);
      for iDef = 1:numel(cfg.mazeData)
        versioning.(cfg.mazeData{iDef})         = vr.(cfg.mazeData{iDef});
      end
      
      % Create a trial information storage structure
      obj.trialInfo.comment   = '';
      obj.trialInfo.duration  = nan;
      obj.trialInfo.virmen_cputime_sync = zeros(0,2);
      
      %lick information
      if RigParameters.hasLickMeter
          obj.trialInfo.lickvector = zeros(0,1,'single');
          obj.trialInfo.lickvector_TS = zeros(0,1,'single');
          obj.trialInfo.localtime_licktime_sync = zeros(0,2,'single');
      end
      
      for iInfo = 1:numel(obj.trialData)
        obj.trialInfo.(obj.trialData{iInfo})    = [];
      end
      for iInfo = 1:numel(obj.protocolData)
        obj.trialInfo.(obj.protocolData{iInfo}) = [];
      end

      % Data automatically collected from ViRMEn
      obj.trialInfo.viStart   = uint32(0);
      obj.trialInfo.start     = nan;
      obj.trialInfo.position  = nan(0, numel(ExperimentLog.SPATIAL_COORDS));
      obj.trialInfo.velocity  = nan(0, numel(ExperimentLog.SPATIAL_COORDS));
      obj.trialInfo.sensorDots= zeros(0, numel(ExperimentLog.SENSOR_COORDS), ExperimentLog.SENSOR_DATASIZE);
%       obj.trialInfo.Licks     = zeros(0, size(vr.LickData,2), 'single');
      obj.trialInfo.collision = false(0);
      obj.trialInfo.time      = nan(0);
      obj.trialInfo.iterations= uint32(0);
      
      % Impose alphabetical order of data
      obj.label               = cfg.label;
      obj.version             = orderfields(versioning);
      obj.trialInfo           = orderfields(obj.trialInfo);
      
      % Preallocated storage structure for logging current trial
      obj.emptyTrial          = obj.trialInfo;
      for field = ExperimentLog.PREALLOCATED_FIELDS
        if islogical(obj.emptyTrial.(field{:}))
          obj.emptyTrial.(field{:})                         ...
              = false ( obj.preallocSize                    ...
                      , size(obj.emptyTrial.(field{:}),2)   ...
                      );
        else
          obj.emptyTrial.(field{:})                         ...
              = zeros ( obj.preallocSize                    ...
                      , size(obj.emptyTrial.(field{:}),2)   ...
                      , 'like', obj.emptyTrial.(field{:})   ...
                      );
        end
      end

      % Create a block information storage structure
      obj.animal              = rmfield(cfg.animal, {'session','data'});
      obj.block               = struct([]);
      obj.logFile             = obj.makeOrContinueLog(cfg.logFile);

      obj.blockStart          = vr.timeElapsed;
      obj.trialEnded          = 0;
      obj.newBlock(vr, 500);
     

    end
    % just returns the write counter to check if it's a good time to save. 
    function writeCounter = getWriteCounter(obj)
        writeCounter = obj.writeCounter; 
    end
        
    %----- Writes data stored in this object to disk
    % The argument compact should be set to true (default false) for the
    % final write to disk, as this will strip unfilled trials (not
    % done during the periodic save for speed reasons).
    function log = save(obj, compact, timeNow, pid, plots)
%         global curlickbuffer curlickbuffer_timestamps size_hardware_lickbuffer new_lickdata_ctr sync_localtime_licktime
%         if RigParameters.hasLickMeter
%             %lick information
%             obj.currentTrial.lickvector    = flipud(curlickbuffer(1:size_hardware_lickbuffer*new_lickdata_ctr));
%             obj.currentTrial.lickvector_TS = flipud(curlickbuffer_timestamps(1:size_hardware_lickbuffer*new_lickdata_ctr));
%             obj.currentTrial.localtime_licktime_sync = sync_localtime_licktime(1:new_lickdata_ctr,:);
%             new_lickdata_ctr=0;
% %             disp('save 312')
%         end
        
      % If it exists, truncate unused preallocated space for the last trial
      if obj.writeIndex > 0 && ~isnan(obj.currentTrial.duration)
        obj.currentTrial.time(obj.currentIt+1:end,:)        = [];
        obj.currentTrial.sensorDots(obj.currentIt+1:end,:)  = [];
%         obj.currentTrial.Licks(obj.currentIt+1:end,:)       = [];
        obj.currentTrial.duration                           = timeNow - obj.currentTrial.start;
%         obj.currentTrial.virmen_cputime_sync                = [cputime timeNow]; 
        obj.block(end).trial(obj.writeIndex)                = obj.currentTrial;
        
        
      end

      
      % Store the final duration of the block, which can include part of
      % the last trial if the trial was discarded (terminated before
      % logExtras() was called)
      obj.session(end).end      = clock;
      obj.block(end).duration   = timeNow - obj.blockStart;
      log                       = saveobj(obj);
      
      if nargin > 1 && compact
        % Truncate the storage structure to the number of filled trials,
        % keeping in mind that the current trial might not have been
        % completed and so should be discarded
        if obj.writeIndex > 0 && isnan(obj.currentTrial.duration)
          lastIndex             = obj.writeIndex - 1;

        else
          lastIndex             = obj.writeIndex;
        end
        log.block(end).trial(lastIndex+1:end) = [];
        
        % Reduce precision for storage
        for iBlock = 1:numel(log.block)
          log.block(iBlock).trial = reducePrecision(log.block(iBlock).trial);
        end
      end

       
%       if obj.writeIndex > 1
%           obj.block(end).trial(obj.writeIndex -1)
%           obj.block(end).trial(obj.writeIndex) 
%           keyboard
%       end

      
%       obj.logFile = strcat(obj.logFile(1:end-4),'_',num2str(pid), '.mat');
%       makepath(obj.logFile);
      % TO DELETE
      save(obj.logFile, 'log');
      obj.writeCounter          = 0;
      
      % For user's convenience
      log.logFile               = obj.logFile;
      
      
      % Save figures if provided by user
      if nargin > 5
        isMissing               = ~isgraphics(plots);
        if sum(isMissing) > 0
          warning('ExperimentLog:save', '%d figure(s) to be saved are missing, will be skipped.', sum(isMissing));
          plots                 = plots(~isMissing);
        end
        if isempty(plots)
          return;
        end
        
        % Use a counter so as not to overwrite figures
        [path, name]            = parsePath(obj.logFile);
        iFig                    = 1;
        while exist(fullfile(path, sprintf(obj.FIGURE_FILE,name,iFig)), 'file')
          iFig                  = iFig + 1;
        end
        
        figFile                 = fullfile(path, sprintf(obj.FIGURE_FILE,name,iFig));
        savefig(plots, figFile);
      end
      
    end
    
    %----- Toggle the comment entry state
    function toggleComment(obj)
      obj.doComment     = mod(obj.doComment, numel(obj.COMMENT_AT)) + 1;
      % fprintf('----???  %s\n', obj.COMMENT_STATUS{obj.doComment});
    end

    %----- Add custom session info that the user will be prompted for
    function ask(obj, name, prompt, default, converter, numLines)
      
      if nargin < 4
        default   = '';
      end
      if nargin < 6
        numLines  = 1;
      end
      
      input       = inputDialog(name, prompt, default, true, numLines);
      if isempty(input)
        return;
      end
      
      if nargin > 4 && ~isempty(converter)
        obj.block(end).(name) = converter(input);
      else
        obj.block(end).(name) = input;
      end
      
    end
    
    %----- To be called at the start of each trial to store the time
    function prevTrialDuration = logStart(obj, vr)
        global curlickbuffer curlickbuffer_timestamps size_hardware_lickbuffer new_lickdata_ctr sync_localtime_licktime
        if RigParameters.hasLickMeter
            %lick information
            obj.currentTrial.lickvector    = flipud(curlickbuffer(1:min(size_hardware_lickbuffer*new_lickdata_ctr,length(curlickbuffer))));
            obj.currentTrial.lickvector_TS = flipud(curlickbuffer_timestamps(1:min(size_hardware_lickbuffer*new_lickdata_ctr,length(curlickbuffer))));
            obj.currentTrial.localtime_licktime_sync = sync_localtime_licktime(1:new_lickdata_ctr,:);
            new_lickdata_ctr=0;
        end

        % Record duration of the *previous* trial including inter-trial interval
        if obj.writeIndex > 0
            prevTrialDuration         = vr.timeElapsed - obj.currentTrial.start;
            
            % Have to store the trial info again because extra info can have
            % been logged in the ITI
            obj.currentTrial.time(obj.currentIt+1:end,:)        = [];

        obj.currentTrial.sensorDots(obj.currentIt+1:end,:)  = [];
%         obj.currentTrial.Licks(obj.currentIt+1:end,:)  = [];
        obj.currentTrial.duration                           = prevTrialDuration;
        obj.currentTrial.virmen_cputime_sync                = [cputime vr.timeElapsed];
        obj.block(end).trial(obj.writeIndex)                = obj.currentTrial;
%         disp('logStart 433')
%         

      else
        prevTrialDuration         = nan;
      end
        
      % Start a new block if block-level conditions have changed
%       for iInfo = 1:numel(obj.blockData)
%         if ~isequaln(obj.block(end).(obj.blockData{iInfo}), vr.(obj.blockData{iInfo}))
%           obj.newBlock(vr);
%           break;
%         end
%       end
      
      % Proceed to next write
      obj.writeIndex              = obj.writeIndex + 1;
      obj.trialEnded              = 0;
      obj.currentTrial            = obj.emptyTrial;
      obj.currentIt               = 0;
      
      % Initialize movement logging
      obj.currentTrial.start      = vr.timeElapsed;
      obj.currentTrial.viStart    = uint32(vr.iterations);

      % If a comment has been provided, enter it
      if ~isempty(obj.startComment)
        obj.currentTrial.comment  = obj.startComment;
        obj.startComment          = '';
      end
      
    end
    
    %----- To be called during behavior to record position and velocity
    function logTick(obj, vr, sensorDots, Licks)
%       global new_lickdata_ctr 
      % Do nothing if no trial has been started
      if obj.writeIndex < 1
        return;
      end
      obj.currentIt       = obj.currentIt + 1;

      % These continue to be stored even during the inter-trial interval
      obj.currentTrial.time(obj.currentIt,1)          = vr.timeElapsed - obj.currentTrial.start;
      if nargin > 2 && ~isempty(sensorDots)
        obj.currentTrial.sensorDots(obj.currentIt,:)  = sensorDots(ExperimentLog.SENSOR_COORDS);
      end
%        if nargin > 3 && ~isempty(Licks)
%            if new_lickdata_ctr            
%                obj.currentTrial.Licks(obj.currentIt,:)  = getLicks();
%            end
%       end
      
      if obj.trialEnded <= 1      % Should log the final position at end of trial
        obj.currentTrial.position(obj.currentIt,:)    = vr.position(ExperimentLog.SPATIAL_COORDS);
        obj.currentTrial.velocity(obj.currentIt,:)    = vr.velocity(ExperimentLog.SPATIAL_COORDS);
        obj.currentTrial.collision(obj.currentIt,1)   = vr.collision;
        if obj.trialEnded == 1
          obj.trialEnded  = obj.trialEnded + 1;
        end
      end
        
    end

    %----- To be called at the end of each trial to store per-trial data
    function logEnd(obj, vr)

      % Mark end of trial (before inter-trial-interval)
      obj.trialEnded    = 1;
      obj.currentTrial.iterations = obj.currentIt + 1;    % Last point
      
      % The following variables are truncated before ITI
      obj.currentTrial.position(obj.currentTrial.iterations+1:end,:)  = [];
      obj.currentTrial.velocity(obj.currentTrial.iterations+1:end,:)  = [];
      obj.currentTrial.collision(obj.currentTrial.iterations+1:end,:) = [];

      % Record all requested data -- this is done at the end as there may
      % be quantities that are only updated by the end of the trial
      for iInfo = 1:numel(obj.trialData)
        obj.currentTrial.(obj.trialData{iInfo})     = vr.(obj.trialData{iInfo});
      end
      for iInfo = 1:numel(obj.protocolData)
        obj.currentTrial.(obj.protocolData{iInfo})  = vr.protocol.(obj.protocolData{iInfo});
      end
    
      % If a comment has been provided, enter it
      if ~isempty(obj.endComment)
        obj.currentTrial.comment  = strjoin({obj.currentTrial.comment, obj.endComment}, '\n');
        obj.endComment            = '';
      end
      
    end
    
    %----- To be called at the end of each trial to handle blocking input
    function logExtras(obj, vr, rewardFactor, trial, pid)
%         global curlickbuffer curlickbuffer_timestamps size_hardware_lickbuffer new_lickdata_ctr sync_localtime_licktime
        % at the start of a new block 
%        fileID = fopen( strcat(obj.logFile(1:end-4),'_trials.txt'), 'w');
%             fprintf(fileID, num2str(trial));
%             fclose(fileID);

        if ~isfile(obj.logFile) && obj.writeCounter == 0 
%             obj.logFile = strcat(obj.logFile(1:end-4),'_',num2str(pid), '_trials.txt');
%             fileID = fopen(obj.logFile, 'w');
%             fprintf(fileID, 'time   trial\n');
%             fclose(fileID);
            currtime = clock;
            obj.logFile = strcat(obj.logFile(1:end-4),'_',num2str(currtime(4)), num2str(currtime(5)), '.mat');

        end

        
        if trial > 0 && mod(trial, 500) == 0 % if it's not the first trial
%             fileID = fopen(obj.logFile, 'a');
%             fprintf(fileID, strcat(string(datetime), ' at trial=', num2str(trial), '\n'));
%             fclose(fileID);
            obj.newBlock(vr,  500);
        end

        obj.writeIndex = cast(mod(trial, 500), 'uint16') + 1;

        

      % Do nothing if no trial is currently being logged
%       if obj.writeIndex < 1
%         return;
%       end

      % Duration is saved in case there is no next trial
      obj.currentTrial.duration = vr.timeElapsed - obj.currentTrial.start;
%       obj.currentTrial.virmen_cputime_sync = [vr.timeElapsed cputime]; 
%       disp('logExtras 545')
%       
%       disp(num2str(new_lickdata_ctr))
%       if RigParameters.hasLickMeter
%           % save Lick information
%           obj.currentTrial.lickvector    = curlickbuffer(1:size_hardware_lickbuffer*new_lickdata_ctr);
%           obj.currentTrial.lickvector_TS = curlickbuffer_timestamps(1:size_hardware_lickbuffer*new_lickdata_ctr);
%           obj.currentTrial.localtime_licktime_sync = sync_localtime_licktime(1:new_lickdata_ctr,:);
%           new_lickdata_ctr=0;
%       end
      
      % Store current trial in its final position in the block
      obj.block(end).trial(obj.writeIndex)  = obj.currentTrial;

      % Accumulate per-block quantities
      if nargin > 4
        obj.block(end).rewardMiL  = obj.block(end).rewardMiL + rewardFactor * RigParameters.rewardSize;
      end

     
      % If a specified number of trials has elapsed, write to disk
      obj.writeCounter    = obj.writeCounter + 1;

      if obj.writeCounter >= obj.savePerNTrials 
        tic
        obj.save(false, vr.timeElapsed,  pid);
        toc
      end

    end
    
    %----- Accessors
    function addStartComment(obj, comment)
      obj.startComment  = strjoin({obj.startComment, comment}, '\n');
    end
    function addEndComment(obj, comment)
      obj.endComment    = strjoin({obj.endComment, comment}, '\n');
    end

    %----- Returns the relative iteration number such that the start of
    %      the current trial corresponds to 1
    function iterNumber = iterationStamp(obj, vr)
      if isempty(obj.currentTrial)
        iterNumber  = 0;
      else
        iterNumber  = vr.iterations               ...
                    - obj.currentTrial.viStart    ...
                    + 1                           ...
                    ;
      end
    end
    
    %----- Returns the start time of the current trial
    function start = trialStart(obj)
      start   = obj.currentTrial.start;
    end
    
    %----- Returns the length of the trial (so far, and not including
    %      inter-trial interval)
    function length = trialLength(obj)
      length  = obj.currentTrial.time(min( end, size(obj.currentTrial.position,1) ));
    end
    
    %----- Compute the total distance logged
    function distance = distanceTraveled(obj)
      displacement  = diff(obj.currentTrial.position(1:obj.currentIt,1:2), 1);
      distance      = sum( sqrt(sum(displacement.^2, 2)) );
    end
    
  end
  
  %________________________________________________________________________
  methods (Access = protected)
    
    %----- Helper function to optionally continue an old log 
    function [logFile] = makeOrContinueLog(obj, logFile)

      % If no log exists, construct a new one
      if ~exist(logFile, 'file')
        if ~isempty(obj.console)
          obj.console.log('Creating log file %s', logFile);
        end
        return;
      end
      

      % If the log exists, check if version index needs to be incremented
      oldLog                = load(logFile, 'log');
      oldLog                = oldLog.log;
      if ~isequaln(oldLog.version(end), obj.version(end))
        % Concatenate version info if it differs
        obj.version         = [oldLog.version, obj.version];
      
      elseif   ~isequal(oldLog.version(end).code, obj.version(end).code)                    ...
            || ~isequaln(oldLog.version(end).worlds, obj.version(end).worlds)
        % Sanity check to force user to update versions when too much differs
        fprintf ( [ '\n\n ********************  SANITY CHECK ********************\n\n'      ...
                    'World structure(s) seem to have changed significantly from\n    %s\n'  ...
                    'Please update version numbers properly to continue.\n\n\n'             ...
                  ]                                                                         ...
                , logFile                                                                   ...
                );
        logFile             = [];
        vr.experimentEnded  = true;
        return;
      end
      
      
      % Merge old data into this log object
      if ~isempty(obj.console)
        obj.console.log('Continuing log in %s', logFile);
      end
      obj.block             = concatstruct(oldLog.block, obj.block);
      
      % Decide whether or not to continue an existing session
      sessionIndex          = numel(obj.session);
      if sessionIndex < numel(oldLog.session)
        fprintf ( [ '\n\n ********************  SANITY CHECK ********************\n\n'          ...
                    'Cannot start session %d when session %d (> %d) has already been recorded.' ...
                  ]                                                                             ...
                , sessionIndex, numel(oldLog.session), sessionIndex                             ...
                );
        logFile             = [];
        vr.experimentEnded  = true;
        return;
      end

      % Copying old info may overwrite all sessions if continuing
      obj.session(1:numel(oldLog.session))  = oldLog.session;
      if sessionIndex > numel(oldLog.session)
        % This is a new session with only one block (the latest)
        obj.session(end).blocks             = numel(obj.block) * [1 1];
      else
        % Continue old session by appending this block to the list
        obj.session(end).blocks(2)          = numel(obj.block);
      end
      
    end

    %----- Helper function to start a new block
    function newBlock(obj, vr, totalTrials)

      % If totalTrials is *not* provided, this is a within-session
      % construction of a new block (due to maze changes etc.), in which
      % case we clean up the previous block and copy its settings
      if nargin < 3
        % Truncate the storage structure to the number of filled trials,
        % keeping in mind that the current trial might not have been
        % completed and so should be discarded
        if obj.writeIndex > 0 && isnan(obj.currentTrial.duration)
          lastIndex             = obj.writeIndex - 1;
        else
          lastIndex             = obj.writeIndex;
        end
        
        obj.block(end).duration = vr.timeElapsed - obj.blockStart;
        totalTrials             = numel(obj.block(end).trial);
        obj.block(end).trial    = obj.block(end).trial(1:lastIndex);
      end

      obj.block(end+1).trial                  = repmat(obj.trialInfo, 1, totalTrials);
      obj.block(end).versionIndex             = numel(obj.version);
      if numel(obj.block) > 1
        obj.block(end).firstTrial             = obj.block(end-1).firstTrial + numel(obj.block(end-1).trial);
      else
        obj.block(end).firstTrial             = 1;
      end
      obj.block(end).start                    = clock;
      obj.block(end).duration                 = 0;
      obj.block(end).versionIndex             = 1;
      obj.block(end).rewardMiL                = 0;
      for iInfo = 1:numel(obj.blockData)
        obj.block(end).(obj.blockData{iInfo}) = vr.(obj.blockData{iInfo});
      end
      
      % Update session info
      obj.writeIndex                          = 0;
      obj.session(end).blocks(2)              = numel(obj.block);
      obj.newBlocks(end+1)                    = numel(obj.block);
      obj.blockStart                          = vr.timeElapsed;

    end
    
  end
  
end
