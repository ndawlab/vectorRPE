classdef PoissonStimulusTrain_discrete2 < handle
  
  %------- Constants
  properties (Constant)
    CHOICES           = Choice.all()    % All available choices
    
    MAX_RETRIES       = 100             % Maximum number of attempts to find a nearby index
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
    function obj = PoissonStimulusTrain_discrete2(targetNTrials, trialDuplication, trialDispersion)
      
      % Stimulus configuration data structure
      obj.default.cfg.lCue           = nan;
      obj.default.cfg.cueVisAt       = nan;
      obj.default.cfg.maxNumCues     = nan;
      obj.default.cfg.minCueSep      = nan;
      obj.default.cfg.densityPerM    = nan;
      obj.default.cfg.meanRatio      = nan;
      obj.default.cfg.meanSalient    = nan;
      obj.default.cfg.meanDistract   = nan;
      obj.default.cfg.nPanSession    = [];
      obj.default.cfg.FracEdgeTrials = nan;
      obj.default.cfg.EdgeProbDef    = nan;
        
      % Stimulus train data structure
      obj.default.stim.cuePos       = cell(size(PoissonStimulusTrain_discrete2.CHOICES));
      obj.default.stim.cueCombo     = nan(numel(PoissonStimulusTrain_discrete2.CHOICES), 0);
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
    function modified = configure(obj, lCue, cueVisAt, cueDensityPerM, cueMeanRatio, maxNumCues, cueMinSeparation, numPanSession, FracEdgeTrials, EdgeProbDef)
      
      if isempty(obj.targetNTrials)
        error('configure:precondition', 'This can only be called after the number of trials to generate is set via the constructor or setTrialMixing().');
      end
      
      % Return value is true if non-transient changes have been made
      modified                      = false;
      
      % Try to locate an existing configuration of the desired type
      obj.cfgIndex                  = 1;
      while obj.cfgIndex <= numel(obj.config)
%           &&  obj.config(obj.cfgIndex).maxNumCues   == maxNumCues         
        if      obj.config(obj.cfgIndex).lCue         == lCue               ...
            &&  obj.config(obj.cfgIndex).cueVisAt     == cueVisAt           ...
            &&  obj.config(obj.cfgIndex).maxNumCues   == maxNumCues         ...
            &&  obj.config(obj.cfgIndex).minCueSep    == cueMinSeparation   ...
            &&  obj.config(obj.cfgIndex).densityPerM  == cueDensityPerM     ...
            &&  obj.config(obj.cfgIndex).meanRatio    == cueMeanRatio       ...
            &&  obj.config(obj.cfgIndex).FracEdgeTrials == FracEdgeTrials   ...
            &&  obj.config(obj.cfgIndex).EdgeProbDef == EdgeProbDef            
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
        cfg.cueVisAt                = cueVisAt;
%         cfg.maxNumCues              = maxNumCues;
        cfg.maxNumCues              = maxNumCues;
        cfg.minCueSep               = cueMinSeparation;
        cfg.meanRatio               = cueMeanRatio;
        cfg.densityPerM             = cueDensityPerM;
        cfg.meanDistract            = cueMeanCount / (1 + exp(cueMeanRatio));
        cfg.meanSalient             = cueMeanCount - cfg.meanDistract;
        cfg.FracEdgeTrials          = FracEdgeTrials;
        cfg.EdgeProbDef             = EdgeProbDef;
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
      maxNumCues                = floor(cfg.lCue/cfg.minCueSep);
      
      if isfinite(cfg.cueVisAt)
        cueOffset               = cfg.cueVisAt;
      else
        cueOffset               = 0;
      end

      % Distribute cues on each side of the maze
      nCues                     = [];
      cuePos                    = [];
      cueSide                   = [];
      while isempty(cuePos)     % Mazes must have at least one cue
%         for iSide = 1:numel(meanNumCues)
%           % Draw a Poisson count of towers within available length
%           nCues(iSide)          = poissrnd(meanNumCues(iSide));
%           while nCues(iSide) > cfg.maxNumCues
%             nCues(iSide)        = poissrnd(meanNumCues(iSide));
%           end
% 
%           % Distribute cues uniformly in effective length
%           lEffective            = cfg.lCue - (nCues(iSide) - 1) * cfg.minCueSep;
%           stim.cuePos{iSide}    = sort(rand(1, nCues(iSide))) * lEffective    ...
%                                 + (0:nCues(iSide) - 1) * cfg.minCueSep        ...
%                                 ;
%           cueRange              = numel(cuePos) + (1:numel(stim.cuePos{iSide}));
%           cuePos(cueRange)      = stim.cuePos{iSide};
%           cueSide(cueRange)     = iSide;
%         end
        
        %% Here we draw a Poisson count of towers for each side, we then distribute ALL of them uniformly on the effective length 
        %% (which is the total length of the Cue portion of the corridor minus all the refractory periods, we then add the refractory 
        %% periods. After that we randomly choose which towers belong to which side from a uniform distribution accoding to the Poisson-sampled
        %% number of towers fo reach side.
        %%aditionally, we might want to oversample the edges to get a better
        %%psychometric curve. In that case, we use parameters for
        %%oversampling (FracEdgeTrials: pctg of trials that will be overlaid edge trials,
        %%and EdgeProbDef: the starting point of an "edge")

        isEdgeTrial = rand< cfg.FracEdgeTrials;
        if ~isEdgeTrial %normal case
            nCuesTotal = sum(nCues);
            while nCuesTotal > maxNumCues || nCuesTotal==0
                for iSide = 1:numel(meanNumCues)
                    % Draw a Poisson count of towers within available length
                    nCues(iSide)        = poissrnd(meanNumCues(iSide));
                end
                nCuesTotal = sum(nCues);
            end
        else %edge trial case
            x_skell = -50:50;
            skellam_pdf = exp(-sum(meanNumCues))*((meanNumCues(1)/meanNumCues(2)).^(x_skell/2)).*besseli(x_skell,2*sqrt(prod(meanNumCues)));
            skellam_cdf = sum(triu(gallery('circul',skellam_pdf)));
            x_skell_edge_ind = find(skellam_cdf >(1-cfg.EdgeProbDef),1,'first');

            possible_diff_cues_inds = x_skell_edge_ind:find(x_skell==maxNumCues);                    
            cur_probs = skellam_pdf(possible_diff_cues_inds)/sum(skellam_pdf(possible_diff_cues_inds));
            cur_cdf = sum(triu(gallery('circul',cur_probs)));
            diff_nCues_ind = possible_diff_cues_inds(find(cur_cdf>rand,1,'first'));
            diff_cCues = x_skell(diff_nCues_ind);
            possible_nCues1 = diff_cCues:maxNumCues;
            cond_pdf = poisspdf(possible_nCues1 ,meanNumCues(1)).*poisspdf(0:(maxNumCues-diff_cCues),meanNumCues(2));
            cond_pdf = cond_pdf/sum(cond_pdf); 
            cond_cdf = sum(triu(gallery('circul',cond_pdf)));
            nCues(1) = possible_nCues1(find(cond_cdf>rand,1,'first'));
            nCues(2) = nCues(1)-diff_cCues;

        end
        nCuesTotal=sum(nCues);
        
        lEffective = cfg.lCue - cueOffset - (nCuesTotal - 1) * cfg.minCueSep;
        stim_cuePos_all = cueOffset + sort(rand(1, nCuesTotal)) * lEffective    ...
            + (0:nCuesTotal - 1) * cfg.minCueSep;
        % shift by a random number (uniform across length of visible stimuli , which is cfg.lCue - cueOffset) with wraparound.
        % that way we avoid clutering at the edges of the cue distribution in space.
        rand_shift = rand*(cfg.lCue - cueOffset);
        stim_cuePos_all=stim_cuePos_all+rand_shift;
        stim_cuePos_all(stim_cuePos_all>cfg.lCue) = stim_cuePos_all(stim_cuePos_all>cfg.lCue)- (cfg.lCue - cueOffset);
        rand_cues_assign=randperm(nCuesTotal );
        already_assigned=0;
        for iSide = 1:numel(meanNumCues)
            cur_assign = rand_cues_assign(already_assigned+1:already_assigned+nCues(iSide));
            stim.cuePos{iSide}    = sort(stim_cuePos_all(cur_assign));
            already_assigned=already_assigned+nCues(iSide);
            cueRange              = numel(cuePos) + (1:numel(stim.cuePos{iSide}));
            cuePos(cueRange)      = stim.cuePos{iSide};
            cueSide(cueRange)     = iSide;
        end
        
      end
%      disp([num2str(nCues(:)'),' ',num2str(isEdgeTrial),' ;'])

	  % Store canonical (bit pattern) representation of cue presence
      [~, index]                = sort(cuePos);
      cueSide                   = cueSide(index);
      stim.cueCombo             = false(numel(PoissonStimulusTrain_discrete2.CHOICES), numel(cueSide));
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
        iTry      = 1;
        while     slot < 1            ...
              ||  slot > numel(mix)   ...
              ||  ~isnan(mix(slot))
          slot    = round( target(iIdx) + randn() * obj.trialDispersion );
          iTry    = iTry + 1;
          
          % If maximum number of attempts has been exceeded, locate the nearest available slot
          if iTry > obj.MAX_RETRIES
            candidate   = find(isnan(mix));
            [~,iCand]   = min( abs(candidate - round(target(iIdx))) );
            slot        = candidate(iCand);
            break;
          end
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
      obj               = PoissonStimulusTrain_discrete2();
      
      % Merge all fields from the frozen copy into the new object
      for field = fieldnames(frozen)'
        if strcmp(field{:}, 'config')
          default       = obj.default.cfg;
        elseif strcmp(field{:}, 'panSession')
          default       = obj.default.stim;
        else
          default       = struct();
        end
        
        obj.(field{:})  = mergestruct ( obj.(field{:})                  ...
                                      , frozen.(field{:})               ...
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
