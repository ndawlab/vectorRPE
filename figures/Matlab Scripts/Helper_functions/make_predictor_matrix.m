% arguments: res_cell        - a structure contating all trials in a given recording session
%            period          - % 'cue': cue period, 'outcome': outcome period, 'all': start of cue period to end of outcome period
%
% outputs:   pred_allmat      - cell array corresponding to a matrix of predictors, each term corresponds to one trial where rows are timepoints and columns are the differnet behavioral predictors
%            pred_inds_cell   - cell array where each term has a vector of indices of the predictors that belong to a specific behavioral variable
%            term_names       - names of the behavioral variables that correspond to the indices in the 'pred_inds_cell' array
%            trials_inds_cell - vectors of timepoint indices used in each trial, corrspodning to the period selected for analysis

% [zeros(1,15) 34 0 0 12 1 0 0 34 zeros(1,6) 0 0 0 0 1 0 0 7 0 1]

function [pred_allmat,pred_inds_cell,term_names,trials_inds_cell] = make_predictor_matrix(res_cell,period)

if nargin<2
    period = 'cue';
end

lCue    = res_cell.mazeVars.lCue;    % 220; Cue segment length

if ~isfield(res_cell.mazeVars,'lMemory')
    lMemory = 80; % backward compatibility
else
    lMemory = res_cell.mazeVars.lMemory; %  80; Delay segment length
end

end_delay_pos = lCue+lMemory-10;

numtrials = length(res_cell.whole_trial_activity);
load('spline_basis30_int.mat');

for k=1:numtrials
    
    clear pred_curmat
    
    if ~strcmp(period,'outcome')
        lim1 = find(res_cell.ypos_cell_gd{k}>0,1,'first');
        lim2 = find(res_cell.ypos_cell_gd{k}<lCue,1,'last');
        if strcmp(period,'all')
            lim2 = size(res_cell.whole_trial_activity{k},1)-15;
        end
        
        curinds = lim1:lim2;
        curinds_posl = lim1:min(length(res_cell.ypos_cell_gd{k}),lim2);
        
        trials_inds_cell{k} = curinds;
        
        cur_Succ_isGood_cell{k}     = zeros(length(curinds),1) + double(res_cell.is_succ_gd(k)==1);
        prev_Succ_isGood_cell{k}    = zeros(length(curinds),1) + double(res_cell.prev_issucc_gd(k)==1);
        
        
        %make Cue predictors
        cur_left_cues  = res_cell.lr_cue_onset{k}(curinds,1);
        cur_right_cues = res_cell.lr_cue_onset{k}(curinds,2);
        clear left_cuesKernel right_cuesKernel
        for spctr = 1:size(spline_basis,2)
            w = conv(cur_left_cues ,spline_basis(:,spctr));
            left_cuesKernel(:,spctr) = w(1:length(cur_left_cues));
            
            w = conv(cur_right_cues,spline_basis(:,spctr));
            right_cuesKernel(:,spctr) = w(1:length(cur_right_cues));
            
        end
        
        pred_curmat{1,1} = left_cuesKernel;
        pred_curmat{1,2}= right_cuesKernel;
        
        
        %make position predictor
        cur_pos  = [res_cell.allpos_cell_gd{k}(curinds_posl,1:2) sin(res_cell.allpos_cell_gd{k}(curinds_posl,3)) cos(res_cell.allpos_cell_gd{k}(curinds_posl,3))];
        cur_pos(cur_pos(:,2)>end_delay_pos,2) = cur_pos(cur_pos(:,2)>end_delay_pos,2)+ abs(cur_pos(cur_pos(:,2)>end_delay_pos,1)); %unfold arm into y position
        if length(curinds)>length(curinds_posl)
            cur_pos = [cur_pos;zeros(length(curinds)-length(curinds_posl),4)];
        end
        cur_pos_orig = cur_pos;
        
        
        %make velocity predictors
        cur_veloc = [res_cell.allveloc_cell_gd{k}(curinds_posl,1:2) sin(res_cell.allveloc_cell_gd{k}(curinds_posl,3)) cos(res_cell.allveloc_cell_gd{k}(curinds_posl,3))];
        if length(curinds)>length(curinds_posl)
            cur_veloc = [cur_veloc;zeros(length(curinds)-length(curinds_posl),4)];
        end
        
        
        if k==1
            orig_pred_ctr = size(pred_curmat,2);
            cue_terms = 1:orig_pred_ctr;
            pos_terms        = [];
            kinematics_terms = [];
            accuracy_terms   = [];
            previous_reward_terms   = [];
            
            term_names =     {'cue','pos','kinematics','accuracy','previous_reward',};
            
            if ~strcmp(period,'cue')
                reward_terms = [];
                end_of_trial_terms = [];
                term_names{end+1} = 'reward';
                term_names{end+1} = 'end_of_trial';
            end
            
        end
        
        pred_ctr = orig_pred_ctr ;
        
        % add view angle to kinematics
        pred_ctr = pred_ctr + 1; if k==1; kinematics_terms(end+1) = pred_ctr; end;
        pred_curmat{1,pred_ctr} = cur_pos_orig(:,[3 4]);
        
        % add speed and acceleration to kinematics
        pred_ctr = pred_ctr + 1; if k==1; kinematics_terms(end+1) = pred_ctr; end;
        filter_len = min(floor(length(cur_veloc(:,1))/3)-1,31);
        flim_ = floor(filter_len/2);
        base_speed = sqrt(cur_veloc(:,1).^2+cur_veloc(:,2).^2);
        cur_speed = filtfilt(normpdf(-flim_:flim_,0,3),1,base_speed);
        cur_acc = [0;diff(cur_speed)];
        pred_curmat{1,pred_ctr} = [cur_speed cur_acc];
        
        %add position predictor
        pred_ctr = pred_ctr + 1; if k==1; pos_terms(end+1) = pred_ctr; end;
        pred_curmat{1,pred_ctr} = cur_pos_orig(:,2);
        
        
        base_onesvec = ones(size(cur_pos_orig,1),1);
        
        %add accuracy (current reward)
        pred_ctr = pred_ctr + 1; if k==1; accuracy_terms(end+1) = pred_ctr; end;
        pred_curmat{1,pred_ctr} = base_onesvec.*cur_Succ_isGood_cell{k};
        
        %add previous reward
        pred_ctr = pred_ctr + 1; if k==1; previous_reward_terms(end+1) = pred_ctr; end;
        pred_curmat{1,pred_ctr} = base_onesvec.*prev_Succ_isGood_cell{k};
        
    else
        if k==1
            reward_terms = [];
            end_of_trial_terms = [];
            term_names = {'reward','end_of_trial'};
        end
        
        pred_ctr = 0 ;
        cur_pos = zeros(30,1);        
        trials_inds_cell{k} = size(res_cell.whole_trial_activity{k},1)-44:size(res_cell.whole_trial_activity{k},1)-15;
    end
    
    if ~strcmp(period,'cue')
        %add reward
        pred_ctr = pred_ctr + 1; if k==1; reward_terms(end+1) = pred_ctr; end;
        cur_reward_kernel  = zeros(size(cur_pos,1),size(spline_basis,2));
        cur_reward_kernel(end-29:end,:) = spline_basis;
        pred_curmat{1,pred_ctr} = cur_reward_kernel*res_cell.is_succ_gd(k);
        
        pred_ctr = pred_ctr + 1; if k==1; end_of_trial_terms(end+1) = pred_ctr; end;
        cur_end_of_trial_kernel  = zeros(size(cur_pos,1),size(spline_basis,2));
        cur_end_of_trial_kernel (end-29:end,:) = spline_basis;
        pred_curmat{1,pred_ctr} = cur_reward_kernel;
        
    end
    
    pred_allmat{k,1} = cell2mat(pred_curmat);
end


for l=1:length(term_names)
    eval(['cur_terms = ',term_names{l},'_terms;'])
    cur_pred_inds=[];
    for l2=1:length(cur_terms)
        numprev = size(cell2mat(pred_curmat(1,1:cur_terms(l2)-1)),2);
        cur_pred_inds = [cur_pred_inds numprev+(1:size(pred_curmat{1,cur_terms(l2)},2))];
    end
    pred_inds_cell{l} = cur_pred_inds;
end




