% process_all_sessions
% period: 'cue','outcome','all'

function [rel_contrib_all,Fstat_all,R2_all,sesscellnum,term_names,res_cell_predicted,B_all,pred_inds_cell_all] = process_all_sessions_tmp_4cues_ConfDiscm_ConIps(res_cell,period,approach,onpcaflag)

if nargin<4
    onpcaflag=0;
end

numsessions = length(res_cell);
switch period
    case 'cue'
        pred_types_cell = {'event','continuous','continuous','whole-trial','whole-trial'};
    case 'outcome'
        pred_types_cell = {'event','event'};
    case 'all'
        pred_types_cell = {'event','continuous','continuous','whole-trial','whole-trial','whole-trial','event','event'};
end


rel_contrib_all = [];
Fstat_all = [];
sesscellnum = [];
R2_all = [];
B_all = {};
pred_inds_cell_all = {};
rng('default')
lens_sides = 'LLRLLLLRRRRRLRRLLLLRRLR';
lens_sides_num = ones(size(lens_sides)); 
lens_sides_num(lens_sides=='R')=2;

for sessctr = 1:numsessions
    [pred_allmat,pred_inds_cell,term_names,trials_inds_cell] = make_predictor_matrix_tmp_4cues_ConfDisc_ConIps(res_cell(sessctr),period,lens_sides_num(sessctr));
    numtrials = length(trials_inds_cell);
    neural_act_mat = cell(numtrials,1);
    for k=1:numtrials
        neural_act_mat{k,1} = res_cell(sessctr).whole_trial_activity{k}(trials_inds_cell{k},:);
    end
    
    disp(['Now processing session #',num2str(sessctr),' of ',num2str(numsessions)])
    if ~strcmp(period,'outcome')
        if ~onpcaflag
            [relative_contrib,Fstat_mat,R2_vec,predicted_gcamp,B_vec,~,pred_inds_cell_opt] = process_encoding_model_v2  (pred_allmat, pred_inds_cell, neural_act_mat, pred_types_cell,approach);
        else
            [relative_contrib,Fstat_mat,R2_vec,predicted_gcamp,B_vec] = process_encoding_model_onpca(pred_allmat, pred_inds_cell, neural_act_mat, pred_types_cell,approach);
            
        end
    else
        [relative_contrib,Fstat_mat,R2_vec,predicted_gcamp] = process_reward_response(pred_allmat, double(res_cell(sessctr).is_succ_gd), neural_act_mat,approach);
    end
    
    rel_contrib_all = [rel_contrib_all;relative_contrib];
    Fstat_all       = [Fstat_all;Fstat_mat];
    R2_all = [R2_all ;R2_vec];
    B_all{end+1} = B_vec;
    pred_inds_cell_all{end+1} = pred_inds_cell_opt;
    numcells = size(relative_contrib,1);
    sesscellnum = [sesscellnum;[ones(numcells,1)*sessctr (1:numcells)']];
    
    if ~strcmp(period,'outcome')
        res_cell_predicted(sessctr) = res_cell(sessctr);
        for k=1:numtrials
            res_cell_predicted(sessctr).whole_trial_activity{k} = nan(size(res_cell_predicted(sessctr).whole_trial_activity{k}));
            for cellctr=1:numcells
                if k<=length(predicted_gcamp{cellctr}) && ~isempty(predicted_gcamp{cellctr}{k});
                    res_cell_predicted(sessctr).whole_trial_activity{k}(trials_inds_cell{k},cellctr) = predicted_gcamp{cellctr}{k};
                end
            end
        end
    else
        res_cell_predicted = [];
    end
    
end






