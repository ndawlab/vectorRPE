function  res = rpe_analysis(res_cell,use_prev_rw,do_zscore,cueweights_cell)

if nargin<2
    use_prev_rw=0;
end
if nargin<3
    do_zscore=0;
end
if nargin<4
    cueweights_cell = [];
    cueweight_bins = 1;
else
    cueweight_bins = length(cueweights_cell{1});
end
edges = 10:210/(cueweight_bins):220;

dprime=[];
sesscellnum = [];
for fctr = 1:length(res_cell)
    
    numtrials = length(res_cell(fctr).ypos_cell_gd);
    numcells = size(res_cell(fctr).whole_trial_activity{1},2);
    
    sesscellnum = [sesscellnum;[ones(numcells,1)*fctr (1:numcells)']];
    %make  response matrix
    clear outcome_resp
    for l=1:numtrials
        outcome_resp(:,:,l) = res_cell(fctr).whole_trial_activity{l}(end-60:end-15,:);
    end
    outcome_resp2 = outcome_resp- repmat(mean(outcome_resp(1:15,:,:)),46,1,1);
    outcome_resp2 = outcome_resp2(16:end,:,:);
    
    if do_zscore
        sizes_or = size(outcome_resp2);
        
        zmat = nanzscore(reshape(permute(outcome_resp2,[1 3 2]),[sizes_or(1)*sizes_or(3) sizes_or(2)]));
        outcome_resp2 = permute(reshape(zmat,[sizes_or(1) sizes_or(3) sizes_or(2)]),[1 3 2]);
    end
    
    %find hard and easy trials
    cur_is_succ = res_cell(fctr).is_succ_gd';
    good_trials = find(cur_is_succ);
    outcome_resp2 = outcome_resp2(:,:,good_trials);
    if ~use_prev_rw %trials difficulty
        clear sumC
        for l=1:numtrials
            for k=1:cueweight_bins
                curstartbin = find(res_cell(fctr).ypos_cell_gd{l}>edges(k),1,'first');
                curendbin = find(res_cell(fctr).ypos_cell_gd{l}<edges(k+1),1,'last');
                sumC(l,:,k) = sum(res_cell(fctr).lr_cue_onset{l}(curstartbin:curendbin,:));
            end
        end
        if cueweight_bins>1
            sumC_wt = sum(sumC.*repmat(permute(cueweights_cell{fctr}(2:cueweight_bins+1),[3 2 1]),numtrials,2),3);
        else
            sumC_wt  = sum(sumC,3);
        end
        difT_wt = diff(sumC_wt,[],2);
        
        AdifT_wt = abs(difT_wt);
        %         AdifT_wt  = abs(diff(cell2mat(res_cell(fctr).total_numcues')',[],2));
        AdifT_wt = AdifT_wt(good_trials);
        % median split
%         [~,ads] = sort(AdifT_wt);
%         
%         hard_trials_inds = ads(1:ceil(size(ads)/2));
%         easy_trials_inds = ads(ceil(size(ads)/2)+1:end);
        %split by thirds 
        hard_trials_inds = find(AdifT_wt < 5);
        easy_trials_inds = find(AdifT_wt > 10);
        
    else %previous outcome
        cur_prev_succ = res_cell(fctr).prev_issucc_gd(good_trials);
        hard_trials_inds = find(~cur_prev_succ);
        easy_trials_inds = find(cur_prev_succ);
    end
    
    
    easy_mat_all = outcome_resp2(:,:,easy_trials_inds);
    hard_mat_all = outcome_resp2(:,:,hard_trials_inds);
    
    easy_mat_cell{fctr} = easy_mat_all;
    hard_mat_cell{fctr} = hard_mat_all;
    
    outcome_resp_mean = permute(mean(outcome_resp2),[3 2 1]);
    outcome_resp_mean_hard =  outcome_resp_mean(hard_trials_inds,:);
    outcome_resp_mean_easy =  outcome_resp_mean(easy_trials_inds,:);
    
    cur_dprime =(nanmean(outcome_resp_mean_hard)-nanmean(outcome_resp_mean_easy))./sqrt(0.5*(nanvar(outcome_resp_mean_hard)+nanvar(outcome_resp_mean_easy)));
    
    dprime = [dprime; cur_dprime'];

end

res.easy_mat_cell = easy_mat_cell;
res.hard_mat_cell = hard_mat_cell;
res.dprime = dprime;
res.sesscellnum = sesscellnum;

