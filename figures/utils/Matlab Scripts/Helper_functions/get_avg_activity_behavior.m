%assume res_cell is a single session
function [meanstr,stdstr,lenstr,centersstr] = get_avg_activity_behavior(res_cell)

if isfield(res_cell.mazeVars,'lCue')
    lCue = res_cell.mazeVars.lCue;
else
    lCue = 220;
end

numtrials = length(res_cell.lr_cue_onset);
numcells = size(res_cell.whole_trial_activity{1},2);

%Left cues
allLcuesmat = [];
for k=1:numtrials
    curLcues = find(res_cell.lr_cue_onset{k}(:,1));
    for l=1:length(curLcues)
        if curLcues(l)>15 
            allLcuesmat  = cat(3,allLcuesmat,res_cell.whole_trial_activity{k}(curLcues(l)-15:curLcues(l)+30,:));
        end
    end
end

%Right cues
allRcuesmat = [];
for k=1:numtrials
    curRcues = find(res_cell.lr_cue_onset{k}(:,2));
    for l=1:length(curRcues) 
        if curRcues(l)>15 
            allRcuesmat  = cat(3,allRcuesmat,res_cell.whole_trial_activity{k}(curRcues(l)-15:curRcues(l)+30,:));
        end
    end
end


if ~isempty(allLcuesmat)
    %summarize left and right cue responses
    for cctr=1:numcells
        meanstr.Lcues(cctr,:) = nanmean(allLcuesmat(:,cctr,:),3)'    ;
        meanstr.Rcues(cctr,:) = nanmean(allRcuesmat(:,cctr,:),3)'    ;
        stdstr.Lcues(cctr,:)  = nanstd (allLcuesmat(:,cctr,:),[],3)' ;
        stdstr.Rcues(cctr,:)  = nanstd (allRcuesmat(:,cctr,:),[],3)' ;
        lenstr.Lcues(cctr,:)  = sum(~isnan(allLcuesmat(:,cctr,:)),3)';
        lenstr.Rcues(cctr,:)  = sum(~isnan(allRcuesmat(:,cctr,:)),3)';
    end
    
    centersstr.Lcues = repmat((-15:30)/15,numcells,1);
    centersstr.Rcues = repmat((-15:30)/15,numcells,1);
end

%position
pos_x = 0:5:lCue;
pos_y_mat = zeros(length(pos_x),numtrials,numcells);
for k=1:numtrials
    curypos = res_cell.ypos_cell_gd{k};
    for cctr=1:numcells
        cury = res_cell.whole_trial_activity{k}(1:end-45,cctr);
        hh = [curypos cury];
        hh_unique = unique(hh(:,1));
        clear hh_u_y
        for l=1:length(hh_unique)
            hh_u_y(l) = mean(hh(hh(:,1)==hh_unique(l),2));
        end
        if sum(isnan(hh_u_y))
            if sum(isnan(hh_u_y))==length(hh_u_y)
                pos_y_mat(:,k,cctr) = nan;
            else
                goodinds = find(~isnan(hh_u_y));
                first_xposind = find(pos_x>hh_unique(goodinds(1)),1,'first');
                last_xposind  = find(pos_x<hh_unique(goodinds(end)),1,'last');
                cur_interpos = interp1(hh_unique(goodinds ),hh_u_y(goodinds ),pos_x(first_xposind:last_xposind));
                pos_y_mat(:,k,cctr) = nan;
                pos_y_mat(first_xposind:last_xposind,k,cctr) = cur_interpos;
            end
        else
            pos_y_mat(:,k,cctr) = interp1(hh_unique,hh_u_y,pos_x);
        end
    end
end

for cctr=1:numcells
    meanstr.pos(cctr,:) = nanmean(pos_y_mat(:,:,cctr),2)'      ;
    stdstr.pos(cctr,:)  = nanstd (pos_y_mat(:,:,cctr),[],2)' ;
    lenstr.pos(cctr,:)  = sum(~isnan(pos_y_mat(:,:,cctr)),2)';
end

centersstr.pos = repmat(pos_x,numcells,1);

%kinematics

% view angle, speed and acceleration


xi_va_all = -1.1:.1:1.2;
xi_va_centers = (xi_va_all(1:end-1)+xi_va_all(2:end))/2;

xi_spd_all = 0:3:70;
xi_spd_centers = (xi_spd_all(1:end-1)+xi_spd_all(2:end))/2;

xi_acc_all = -1.1:.1:1.2;
xi_acc_centers = (xi_acc_all(1:end-1)+xi_acc_all(2:end))/2;

centersstr.va = repmat(xi_va_centers,numcells,1);
centersstr.spd = repmat(xi_spd_centers,numcells,1);
centersstr.acc = repmat(xi_acc_centers,numcells,1);

all_veloc = [];
all_va= [];
all_gcamp = [];
all_speed= [];
all_accl = [];
for k=1:length(res_cell.whole_trial_activity)
    cues = find(res_cell.allpos_cell_gd{k}(:,2)>0,1,'first');
    cuee = find(res_cell.allpos_cell_gd{k}(:,2)<lCue,1,'last');
    all_veloc = [all_veloc;res_cell.allveloc_cell_gd{k}(cues:cuee,:)];
    all_va = [all_va;res_cell.allpos_cell_gd{k}(cues:cuee,3)];
    all_gcamp = [all_gcamp;res_cell.whole_trial_activity{k}(cues:cuee,:)];
    
    cur_veloc = res_cell.allveloc_cell_gd{k};
    filter_len = min(floor(length(cur_veloc(:,1))/3)-1,31);
    flim_ = floor(filter_len/2);
    cur_speed = filtfilt(normpdf(-flim_:flim_,0,3),1,sqrt(cur_veloc(:,1).^2+cur_veloc(:,2).^2));
    cur_acc = [0;diff(cur_speed)];
    
    all_speed= [all_speed;cur_speed(cues:cuee)];
    all_accl = [all_accl ;cur_acc(cues:cuee)];
    
end


for k=1:length(xi_va_all)-1
    curinds = find(all_va>=xi_va_all(k) & all_va<xi_va_all(k+1));
    meanstr.va(:,k) = nanmean(all_gcamp(curinds,:))';
    stdstr.va(:,k) = nanstd(all_gcamp(curinds,:))';
    lenstr.va(:,k) = sum(~isnan(all_gcamp(curinds,:)))';
end
for k=1:length(xi_spd_all)-1
    curinds = find(all_speed>=xi_spd_all(k) & all_speed<xi_spd_all(k+1));
    meanstr.spd(:,k) = nanmean(all_gcamp(curinds,:))';
    stdstr.spd(:,k) = nanstd(all_gcamp(curinds,:))';
    lenstr.spd(:,k) = sum(~isnan(all_gcamp(curinds,:)))';
end
for k=1:length(xi_va_all)-1
    curinds = find(all_accl>=xi_acc_all(k) & all_accl<xi_acc_all(k+1));
    meanstr.acc(:,k) = nanmean(all_gcamp(curinds,:))';
    stdstr.acc(:,k) = nanstd(all_gcamp(curinds,:))';
    lenstr.acc(:,k) = sum(~isnan(all_gcamp(curinds,:)))';
end


%prev_reward
%position and prev rw

was_prevrw = find(res_cell.prev_issucc_gd);
was_not_prevrw = find(~res_cell.prev_issucc_gd);

for cctr=1:numcells
    meanstr.pos_prw(cctr,:) = nanmean(pos_y_mat(:,was_prevrw,cctr),2)'      ;
    stdstr.pos_prw(cctr,:)  = nanstd (pos_y_mat(:,was_prevrw,cctr),[],2)' ;
    lenstr.pos_prw(cctr,:)  = sum(~isnan(pos_y_mat(:,was_prevrw,cctr)),2)';
    
    meanstr.pos_nprw(cctr,:) = nanmean(pos_y_mat(:,was_not_prevrw,cctr),2)'      ;
    stdstr.pos_nprw(cctr,:)  = nanstd (pos_y_mat(:,was_not_prevrw,cctr),[],2)' ;
    lenstr.pos_nprw(cctr,:)  = sum(~isnan(pos_y_mat(:,was_not_prevrw,cctr)),2)';
end
centersstr.pos_prw = repmat(pos_x,numcells,1);
centersstr.pos_nprw = repmat(pos_x,numcells,1);

%position and cur rw
is_currw = find(res_cell.is_succ_gd);
is_not_currw = find(~res_cell.is_succ_gd);

for cctr=1:numcells
    meanstr.pos_crw(cctr,:) = nanmean(pos_y_mat(:,is_currw,cctr),2)'      ;
    stdstr.pos_crw(cctr,:)  = nanstd (pos_y_mat(:,is_currw,cctr),[],2)' ;
    lenstr.pos_crw(cctr,:)  = sum(~isnan(pos_y_mat(:,is_currw,cctr)),2)';
    
    meanstr.pos_ncrw(cctr,:) = nanmean(pos_y_mat(:,is_not_currw,cctr),2)'      ;
    stdstr.pos_ncrw(cctr,:)  = nanstd (pos_y_mat(:,is_not_currw,cctr),[],2)' ;
    lenstr.pos_ncrw(cctr,:)  = sum(~isnan(pos_y_mat(:,is_not_currw,cctr)),2)';
end

centersstr.pos_crw = repmat(pos_x,numcells,1);
centersstr.pos_ncrw = repmat(pos_x,numcells,1);


disp('')

% rw response
clear allrwmat
for k=1:numtrials
    allrwmat(:,:,k) = res_cell.whole_trial_activity{k}(end-60:end-15,:) ;
end

meanstr.rw_resp  = nanmean(allrwmat(:,:,is_currw),3)'    ;
stdstr.rw_resp   = nanstd (allrwmat(:,:,is_currw),[],3)' ;
lenstr.rw_resp   = sum(~isnan(allrwmat(:,:,is_currw)),3)';

meanstr.nrw_resp  = nanmean(allrwmat(:,:,is_not_currw),3)'    ;
stdstr.nrw_resp   = nanstd (allrwmat(:,:,is_not_currw),[],3)' ;
lenstr.nrw_resp   = sum(~isnan(allrwmat(:,:,is_not_currw)),3)';

centersstr.rw_resp  = repmat(-15:30,numcells,1)/15;
centersstr.nrw_resp = repmat(-15:30,numcells,1)/15;














