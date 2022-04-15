%assume res_cell is a single session
function [meanstr,stdstr,lenstr,centersstr] = tmp_get_avg_activity_behavior_cue_rw(res_cell)

if isfield(res_cell.mazeVars,'lCue')
    lCue = res_cell.mazeVars.lCue;
else
    lCue = 220;
end

% previous reward
was_prevrw = find(res_cell.prev_issucc_gd);
was_not_prevrw = find(~res_cell.prev_issucc_gd);

% lens_side to get contra/ipsi output instead of Left/Right
lens_sides = 'LLRLLLLRRRRRLRRLLLLRRLR';
lens_sides_num = ones(size(lens_sides)); 
lens_sides_num(lens_sides=='R')=2;


numtrials = length(res_cell.lr_cue_onset);
numcells = size(res_cell.whole_trial_activity{1},2);

%Left cues: num_timesteps (in activity) X num_cells X num_instances (of cues) 
allCcuesmat = [];
% allLcuesmat_Nrw = [];
for k=1:numtrials
    curLcues = find(res_cell.lr_cue_onset{k}(:,1));
    for l=1:length(curLcues)
        if curLcues(l)>15 
            allCcuesmat  = cat(3,allCcuesmat,res_cell.whole_trial_activity{k}(curLcues(l)-15:curLcues(l)+30,:));
        end
    end
end

%Right cues: num_timesteps (in activity) X num_cells X num_instances (of cues) 
allIcuesmat = [];
% allRcuesmat_Nrw = [];
for k=1:numtrials
    curRcues = find(res_cell.lr_cue_onset{k}(:,2));
    for l=1:length(curRcues) 
        if curRcues(l)>15 
            allIcuesmat  = cat(3,allIcuesmat,res_cell.whole_trial_activity{k}(curRcues(l)-15:curRcues(l)+30,:));
        end
    end
end



if ~isempty(allCcuesmat)
    %summarize left and right cue responses
    for cctr=1:numcells
        meanstr.Ccues(cctr,:) = nanmean(allCcuesmat(:,cctr,:),3)'    ;
        meanstr.Icues(cctr,:) = nanmean(allIcuesmat(:,cctr,:),3)'    ;
        stdstr.Ccues(cctr,:)  = nanstd (allCcuesmat(:,cctr,:),[],3)' ;
        stdstr.Icues(cctr,:)  = nanstd (allIcuesmat(:,cctr,:),[],3)' ;
        lenstr.Ccues(cctr,:)  = sum(~isnan(allCcuesmat(:,cctr,:)),3)';
        lenstr.Icues(cctr,:)  = sum(~isnan(allIcuesmat(:,cctr,:)),3)';
    end
    
    centersstr.Ccues = repmat((-15:30)/15,numcells,1);
    centersstr.Icues = repmat((-15:30)/15,numcells,1);
end





