classdef PoissonStimulusTrain_distalCues < handle
  
  %------- Constants
  properties (Constant)
    CHOICES           = Choice.all()    % All available choices
  end
  
  %------- Private data
  properties (Access = protected, Transient)
    default           % Defaults for various data formats
  end

  %------- Public data
  properties (SetAccess = protected)
    cfgIndex          % Index of the currently configured stimulus type
    bankIndex         % Index of the currently selected pan-session stimulus bank
    trialIndex        % Index of the currently selected trial

    selTrials         % Indices to perSession (positive) / panSession (negative) entries, in the requested mixed sequence
    targetNTrials     % Number of trials to pre-generate per session
    trialDuplication  % Duplication factor for per-session trials
    trialDispersion   % The amount of stagger (in units of number of trials) when mixing trial sequences
    
    config            % Stimulus train configuration
    panSession        % Pan-session bank of stimulus trains
  end
  
  properties (SetAccess = protected, Transient)
    perSession        % Per-session stimulus trains
    quasiRand         % Quasi-random number stream for mixing trials
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
    function obj = PoissonStimulusTrain_distalCues(targetNTrials, trialDuplication, trialDispersion)
      
      % Stimulus configuration data structure
      obj.default.cfg.lCue          = nan;
      obj.default.cfg.lMemory       = nan;
      obj.default.cfg.cueVisAt      = nan;
      obj.default.cfg.maxNumCues    = nan;
      obj.default.cfg.minCueSep     = nan;
      obj.default.cfg.densityPerM   = nan;
      obj.default.cfg.meanRatio     = nan;
      obj.default.cfg.meanSalient   = nan;
      obj.default.cfg.meanDistract  = nan;
      obj.default.cfg.nPanSession   = [];
      
      % Stimulus train data structure
      obj.default.stim.cuePos       = cell(size(PoissonStimulusTrain_distalCues.CHOICES));
      obj.default.stim.cueCombo     = nan(numel(PoissonStimulusTrain_distalCues.CHOICES), 0);
      obj.default.stim.nSalient     = nan;
      obj.default.stim.nDistract    = nan;
      obj.default.stim.index        = nan;
      
      % Stimulus trains
      obj.cfgIndex                  = [];
      obj.bankIndex                 = [];
      obj.trialIndex                = 0;
      obj.config                    = repmat(obj.default.cfg  , 0);
      obj.panSession                = cell(0);
      obj.perSession                = repmat(obj.default.stim , 0);
      if nargin > 0
        obj.setTrialMixing(targetNTrials, trialDuplication, trialDispersion);
      end
      
      obj.quasiRand                 = qrandstream(scramble(haltonset(1, 'Skip', 1e3, 'Leap', 1e2), 'RR2'));
      
    end

    %----- Sets the number and mixture of trials drawn by configure()
    function setTrialMixing(obj, targetNTrials, trialDuplication, trialDispersion)
      
      if ~isempty(obj.perSession)
        error('setTrialMixing:precondition', 'This can only be called prior to generation of any trials via configure().');
      end
      
      obj.targetNTrials             = targetNTrials;
      obj.trialDuplication          = trialDuplication;
      obj.trialDispersion           = trialDispersion;      
      
    end
    
    %----- Pre-generate (if necessary) stimulus trains for a given configuration
    function modified = configure(obj, lCue, cueVisAt, cueDensityPerM, cueMeanRatio, maxNumCues, cueMinSeparation, numPanSession,lMemory)
      
      if isempty(obj.targetNTrials)
        error('configure:precondition', 'This can only be called after the number of trials to generate is set via the constructor or setTrialMixing().');
      end
      
      % Return value is true if non-transient changes have been made
      modified                      = false;
      
      % Try to locate an existing configuration of the desired type
      obj.cfgIndex                  = 1;
      while obj.cfgIndex <= numel(obj.config)
        if      obj.config(obj.cfgIndex).lCue         == lCue               ...
            &&  obj.config(obj.cfgIndex).cueVisAt     == cueVisAt           ...
            &&  obj.config(obj.cfgIndex).maxNumCues   == maxNumCues         ...
            &&  obj.config(obj.cfgIndex).minCueSep    == cueMinSeparation   ...
            &&  obj.config(obj.cfgIndex).densityPerM  == cueDensityPerM     ...
            &&  obj.config(obj.cfgIndex).meanRatio    == cueMeanRatio       ...
            &&  obj.config(obj.cfgIndex).lMemory      == lMemory
          break;
        end
        obj.cfgIndex                = obj.cfgIndex + 1;
      end
      
      % Generate a new configuration if necessary
      if obj.cfgIndex > numel(obj.config)
        modified                    = true;
        cueMeanCount                = cueDensityPerM * (lCue/100);
        cfg                         = obj.default.cfg;
        cfg.lCue                    = lCue;
        cfg.lMemory                 = lMemory;
        cfg.cueVisAt                = cueVisAt;
        cfg.maxNumCues              = maxNumCues;
        cfg.minCueSep               = cueMinSeparation;
        cfg.meanRatio               = cueMeanRatio;
        cfg.densityPerM             = cueDensityPerM;
        cfg.meanDistract            = cueMeanCount / (1 + exp(cueMeanRatio));
        cfg.meanSalient             = cueMeanCount - cfg.meanDistract;
        obj.config(obj.cfgIndex)    = cfg;
      else
        cfg                         = obj.config(obj.cfgIndex);
      end
      
      
      % Draw per-session trials for this configuration if necessary
      if      obj.cfgIndex > size(obj.perSession,1)           ...
          ||  isempty(obj.perSession(obj.cfgIndex,1).index)   ...
          ||  isnan(obj.perSession(obj.cfgIndex,1).index)
        for iTrial = ceil(obj.targetNTrials/obj.trialDuplication):-1:1
          obj.perSession(obj.cfgIndex, iTrial)  = obj.poissonTrains(cfg, iTrial);
        end
      end
        
      
      % Try to locate an existing bank of pan-session trials
      obj.bankIndex                 = findfirst(obj.config(obj.cfgIndex).nPanSession, numPanSession);
      if obj.bankIndex < 1
        modified                    = true;
        obj.bankIndex               = numel(obj.config(obj.cfgIndex).nPanSession) + 1;
        obj.config(obj.cfgIndex).nPanSession(obj.bankIndex)   ...
                                    = numPanSession;

        % Draw pan-session trials if necessary
        obj.panSession{obj.cfgIndex, obj.bankIndex}           = repmat(obj.default.stim,0);
        for iTrial = numPanSession:-1:1
          obj.panSession{obj.cfgIndex, obj.bankIndex}(iTrial) = obj.poissonTrains(cfg, -iTrial);
        end
      end
      
      % Generate a mixture of trials for this session
      obj.selTrials                 = obj.mixTrials ( 1:size(obj.perSession, 2)   ...
                                                    , -1:-1:-numPanSession        ...
                                                    );

      % Restart trial index
      obj.trialIndex                = 0;
      
    end

    %----- Obtain the currently set configuration
    function [cfg, numPanSession] = currentConfig(obj)
      
      cfg               = obj.config(obj.cfgIndex);
      numPanSession     = numel(obj.panSession{obj.cfgIndex, obj.bankIndex});
      
    end
    
    %----- Restart from first trial
    function restart(obj)
      obj.trialIndex    = 0;
    end
    
    %----- Obtain stimulus train for the currently set configuration
    function trial = nextTrial(obj)
      
      % Increment trial index and handle special case of no more trials
      obj.trialIndex    = obj.trialIndex + 1;
      if obj.trialIndex > numel(obj.selTrials)
        trial           = [];
        return;
      end
      
      % If there are trials remaining, return them
      index             = obj.selTrials(obj.trialIndex);
      if index < 0
        trial           = obj.panSession{obj.cfgIndex, obj.bankIndex}(-index);
      else
        trial           = obj.perSession(obj.cfgIndex, index);
      end
      
    end
    
  end
    
    
  %________________________________________________________________________
  methods (Access = protected)
    
    %----- Generate salient and distractor Poisson distributed stimulus trains
    function stim = poissonTrains(obj, cfg, index)

      % Canonical order of trains as salient first, distractor second
      stim                      = obj.default.stim;
      stim.index                = index;
      meanNumCues               = [cfg.meanSalient, cfg.meanDistract];
      
      if isfinite(cfg.cueVisAt)
        cueOffset               = cfg.cueVisAt;
      else
        cueOffset               = 0;
      end

      % Distribute cues on each side of the maze
      nCues                     = [];
      cuePos                    = [];
      cueSide                   = [];
      
      % Mazes must have at least one cue
      % mazes without memory period must have cue at the end on target side
      goodTrialFlag = 0;
      while ~goodTrialFlag
        for iSide = 1:numel(meanNumCues)
          % Draw a Poisson count of towers within available length
          nCues(iSide)          = poissrnd(meanNumCues(iSide));
          while nCues(iSide) > cfg.maxNumCues
            nCues(iSide)        = poissrnd(meanNumCues(iSide));
          end
          
          % Distribute cues uniformly in effective length
          lEffective            = cfg.lCue - cueOffset - (nCues(iSide) - 1) * cfg.minCueSep;
          stim.cuePos{iSide}    = cueOffset + sort(rand(1, nCues(iSide))) * lEffective    ...
            + (0:nCues(iSide) - 1) * cfg.minCueSep  ;
          cueRange              = numel(cuePos) + (1:numel(stim.cuePos{iSide}));
          cuePos(cueRange)      = stim.cuePos{iSide};
          cueSide(cueRange)     = iSide;
        end
        if cfg.lMemory < 10 % mazes without memory period must have cue at the end on target side
          goodTrialFlag = ~(isempty(cuePos) || max(cuePos) < cfg.lCue-10);
        else
          goodTrialFlag = ~isempty(cuePos);
        end
      end
      
      % Store canonical (bit pattern) representation of cue presence
      [~, index]                = sort(cuePos);
      cueSide                   = cueSide(index);
      stim.cueCombo             = false(numel(PoissonStimulusTrain_distalCues.CHOICES), numel(cueSide));
      for iSide = 1:size(stim.cueCombo, 1)
          for iSlot = 1:numel(cueSide)
              stim.cueCombo(cueSide(iSlot), iSlot)  = true;
          end
      end

      % Make sure the correct side has more cues
      if nCues(2) > nCues(1)
        stim.cuePos             = flip(stim.cuePos);
        stim.cueCombo           = flipud(stim.cueCombo);
      end
      stim.nSalient             = nCues(1);
      stim.nDistract            = nCues(2);

    end
  
    %----- Generate a balanced mixture of trials 
    function mix = mixTrials(obj, perSession, panSession)
      
%       figure ; hold on;
      
      % Keep track of assigned slots
      mix             = nan(1, obj.targetNTrials + numel(panSession));
      
      % Fill with pan-session trials
      mix             = obj.randomlyAssignTrials(mix, panSession);
%       plot(1:numel(mix),mix,'sb','markersize',3);

      % Fill with per-session duplicates
      numDups         = obj.trialDuplication - 1;
      while numDups > 0
        % Special case where a subset of trials should be mixed in
        if numDups < 1
          % Generate a random selection with roughly the desired yield
          numSubs     = round( numDups * numel(perSession) );
          select      = qrand(obj.quasiRand, numel(perSession)) < numSubs/numel(perSession);
          % Correct the number of selected items
          select      = obj.adjustSelectCount(select, numSubs);
          
          mix         = obj.randomlyAssignTrials(mix, perSession(select));
%           plot(1:numel(mix),mix,'dg','markersize',3);
          
        % Much easier if every trial needs to be assigned
        else
          mix         = obj.randomlyAssignTrials(mix, perSession);
%           plot(1:numel(mix),mix,'or','markersize',3);
        end
        numDups       = numDups - 1;
      end
%       unassigned      = isnan(mix);
      
      % Fill remaining slots with original sequence of trials
      iTrial          = 0;
      for iSlot = 1:numel(mix)
        if isnan(mix(iSlot))
          iTrial      = iTrial + 1;
          mix(iSlot)  = iTrial;
        end
      end
      
%       plot(1:numel(mix),mix,'+k','markersize',3,'linewidth',1);
%       idx = 1:numel(mix);
%       h = bar(idx(unassigned), 1:iTrial, 'y', 'linestyle','none');
%       uistack(h,'bottom');

      % Sanity check
      if iTrial > perSession(end)
        error('mixTrials:sanity', 'Assigned invalid index %d > %d of trials.', iTrial, perSession(end));
      end
      
    end
    
    %----- Helper for mixTrials() to randomly disperse indices
    function mix = randomlyAssignTrials(obj, mix, indices)
      
      if isempty(indices)
        return;
      end
      
      % Initialize with central locations for the given indices
%       target      = obj.trialDispersion/2                       ...
%                   + ( numel(mix) - obj.trialDispersion )        ...
%                   * sort(qrand(obj.quasiRand, numel(indices)))  ...
%                   ;
      target      = 1 + numel(mix) * sort(qrand(obj.quasiRand, numel(indices)));
                
      % Disperse targets (rolled out pass for speed)
      shift       = randn(1, numel(indices)) * obj.trialDispersion;
      
      % Prevent collisions of slot assignments
      for iIdx = 1:numel(indices)
        slot      = round( target(iIdx) + shift(iIdx) );
        while     slot < 1            ...
              ||  slot > numel(mix)   ...
              ||  ~isnan(mix(slot))
          slot    = round( target(iIdx) + randn() * obj.trialDispersion );
        end
        mix(slot) = indices(iIdx);
      end
      
    end
    
  end
  
  
  %________________________________________________________________________
  methods (Static)

    %----- Load object from disk
    function obj = loadobj(frozen)

      %====================================================================
      % Fix for switching from count -> density (per meter)
      if isfield(frozen.config, 'meanCount')
        for iCfg = 1:numel(frozen.config)
          frozen.config(iCfg).densityPerM = frozen.config(iCfg).meanCount / (frozen.config(iCfg).lCue/100);
        end
        frozen.config   = rmfield(frozen.config, 'meanCount');
      end
      %====================================================================
      
      % Start from default constructor
      obj               = PoissonStimulusTrain_distalCues();
      
      % Merge all fields from the frozen copy into the new object
      for field = fieldnames(frozen)'
        if strcmp(field{:}, 'config')
          default       = obj.default.cfg;
        elseif strcmp(field{:}, 'panSession')
          default       = obj.default.stim;
        else
          default       = struct();
        end
        
        obj.(field{:})  = mergestruct ( obj.(field{:})      ...
                                      , frozen.(field{:})   ...
                                      , default             ...
                                      );
      end
            
    end
    
    %----- Helper for mixTrials() to randomly (un)select items
    function select = adjustSelectCount(select, numTarget)
      
      numSelected           = sum(select);
      if numSelected > numTarget
        targetValue         = true;
        increment           = -1;
      else
        targetValue         = false;
        increment           = 1;
      end
      
      while numSelected ~= numTarget
        indices             = randi([1, numel(select)]);
        for index = indices
          if select(index) == targetValue
            select(index)   = ~targetValue;
            numSelected     = numSelected + increment;
          end
        end
      end

    end
    
  end
  
end
