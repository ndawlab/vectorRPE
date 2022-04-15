%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%    Ben Engelhard, Princeton University (2019).
%
%    This program is provided free without any warranty; you can redistribute it and/or modify it under the terms of the GNU General Public License version 3 as published by the Free Software Foundation.
%    If this code is used, please cite: B Engelhard et al. Specialized coding of sensory, motor, and cognitive variables in midbrain dopamine neurons. Nature, 2019.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% process_reward_response.m
%%%
%%% Description: obtain the relative contribution and the nested model f statistic assocaited with the reward response of the neurons 
%
% arguments: pred_allmat       - cell array correspoding to a matrix of behavioral predictors, each term is a trial and contains a matrix where rows are timepoints and columns the spline predictors. the first 7
%                                columns correspond to the spline predictors for rewarded trials, and the last 7 columns the spline predictors for all trials.
%            is_rewarded_trial - a vector with the same length as the number of trails, where '1' denotes a rewarded trials and 0 an unrewarded trial.
%            neural_act_mat    - cell array correspoding to a matrix of activity traces, each term is a trial and contains a matrix where rows are timepoints and columns are traces correspoding to different
%                                neurons. Timepoints where the neuronal activity is not defined (e.g. a the imaging became unstable) are filled with NaNs (Currently it is assumed that before the first NaN
%                                activity was always defined, and after the first NaN activity is never defined).
%            approach          - 'norefit': calculate regression weights with the full model, then zero the weights correspoding to the predictors being dropped. 'refit' : calculate regression weights
%                                without the weights correspoding to the predictors being dropped (partial model).
%
% outputs:   relative_contrib - a matrix where rows are behavioral variables and columns are neurons. each term is the relative contribution of the behavioral variable to the neural activity.
%            Fstat_mat        - a matrix where rows are behavioral variables and columns are neurons. each term is the F-statistic associated with the nested model comparison where the predicted variable is the
%                               activity of the neuron, the full model is the model containing the predictors from al behavioral variables, and the partial model is the model containing the predictors from all
%                               variables except the one being tested. The value of this statistic shoudl be compared to a distirbution of staitsitc values obtained by erforing the same oprateion on shuffled 
%                               data, directly using the p-value assocaited with the statistic is not valid given the autocorrelations in the data.

function [relative_contrib,Fstat_mat,full_R2_vec, B_all] = process_reward_response(pred_allmat, is_rewarded_trial, neural_act_mat,approach)
if nargin<5
    approach = 'norefit';
end

numcells = size(neural_act_mat{1},2);
numtrials_all = length(pred_allmat);

% find for each neuron trials where activity is defined, and also the length of each trial
defined_mat = zeros(numtrials_all,numcells);
trial_length_vec = zeros(numtrials_all,1);

for trctr=1:numtrials_all
    defined_mat(trctr,:) = ~sum(isnan(neural_act_mat{trctr}));
    trial_length_vec (trctr) = size(neural_act_mat{trctr},1);
    allpointstypes{trctr,1} = ones(trial_length_vec (trctr),1)*is_rewarded_trial(trctr);
end


num_cv_folds = 5;

full_R2_vec = zeros(numcells,1);
partial_R2_vec = zeros(numcells,1);
predictors_all = cell2mat(pred_allmat);
activity_all = cell2mat(neural_act_mat);
allpointstypes_all = cell2mat(allpointstypes);
for cellctr = 1:numcells
    non_nans_inds = ~isnan(activity_all(:,cellctr));
    cur_isrw = allpointstypes_all(non_nans_inds);
    total_points = length(cur_isrw);
    rw_points = sum(cur_isrw);
    nrw_points = total_points - rw_points;
    cur_weights = (cur_isrw*nrw_points + ~cur_isrw*rw_points)/(rw_points+nrw_points);
    mdl1_w = fitlm(predictors_all(non_nans_inds,:),activity_all(non_nans_inds,cellctr),'Intercept',false,'Weights',cur_weights);
    [~, Fstat] = coefTest(mdl1_w, [eye(21) zeros(21)]);
    Fstat_mat(cellctr,:) = Fstat;
    
    cur_good_trials = 1:find(defined_mat(:,cellctr),1,'last');
    num_trials_per_fold = floor(length(cur_good_trials)/num_cv_folds);
    
    temp_neural_act = cell2mat(neural_act_mat(cur_good_trials));
    cur_neural_act_mat = mat2cell(temp_neural_act(:, cellctr),trial_length_vec(cur_good_trials),1);
    
    cur_random_vector = randperm(length(cur_good_trials));
    
    for foldctr = 1:num_cv_folds
        kf_inds{foldctr} = num_trials_per_fold*(foldctr-1)+1:min(num_trials_per_fold*foldctr,length(cur_good_trials));
        test_trials_folds{foldctr} = cur_random_vector(kf_inds{foldctr});
        train_trials_folds{foldctr} = setdiff(cur_random_vector,test_trials_folds{foldctr});
    end
    
    
    [cur_R2,cur_predicted,curB] = get_CV_R2(pred_allmat(cur_good_trials,:),cur_neural_act_mat,test_trials_folds,train_trials_folds,trial_length_vec(cur_good_trials),[],approach,is_rewarded_trial);
    full_R2_vec(cellctr,1) = cur_R2;
    partial_R2_vec(cellctr,1) =  get_CV_R2(pred_allmat(cur_good_trials,:),cur_neural_act_mat,test_trials_folds,train_trials_folds,trial_length_vec(cur_good_trials),1:21,approach,is_rewarded_trial);
    if nargout>=4
        B_all{cellctr} = curB;
    end
end

cur_R2_diff = (full_R2_vec - partial_R2_vec)./full_R2_vec;
cur_R2_diff(cur_R2_diff<0)=0;
cur_R2_diff(cur_R2_diff>1)=1;
relative_contrib = cur_R2_diff;



