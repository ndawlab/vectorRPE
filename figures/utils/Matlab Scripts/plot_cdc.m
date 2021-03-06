
clear all
load cues_order
load vars_sig_all sig_all
load res_cell_ac_sfn
warning off 

clear trials_ln_cell
for l=1:23
    numtrials = length(res_cell_ac_sfn(l).ypos_cell_gd);
    for k=1:numtrials
        trials_ln_cell{l}(k,1) = size(res_cell_ac_sfn(l).whole_trial_activity{k},1);
    end
end


res_cell_ac_sfn_z=res_cell_ac_sfn;

res_cell_ac_sfn_z=res_cell_ac_sfn;
for l=1:23
    res_cell_ac_sfn_z(l).whole_trial_activity =...
        mat2cell(nanzscore(cell2mat(res_cell_ac_sfn(l).whole_trial_activity)),trials_ln_cell{l},size(res_cell_ac_sfn(l).whole_trial_activity{1},2));
end


if ~exist('tmp_cue_kernels_4cues_ConfDiscm_ConIps_z.mat','file')
    [rel_contrib_all,Fstat_all,R2_all,sesscellnum,term_names,res_cell_predicted,B_all,pred_inds_cell_all] = process_all_sessions_tmp_4cues_ConfDiscm_ConIps(res_cell_ac_sfn_z,'cue','norefit');

    save tmp_cue_kernels_4cues_ConfDiscm_ConIps_z
else
    load tmp_cue_kernels_4cues_ConfDiscm_ConIps_z
end

clear all_cue_betas
curcellctr = 1;
for l=1:length(B_all)
    for k=1:length(B_all{l})
        all_cue_betas(curcellctr,:) = B_all{l}{k}(2:44)';
        curcellctr=curcellctr+1;
    end
end

all_cue_betas_ordered = all_cue_betas;
% order is as such: 
% 1: Contra Cue (Contralateral evidence so far) 
% 2: Contra Cue (Neutral evidence so far) 
% 3: Contra cue (Ipsilateral evidence so far) 
% 4: Ipsi Cue (Contralateral evidence so far) 
% 5: Ipsi Cue  (Neutral evidence so far) 
% 6: Ipsi Cue  (Ipsilateral evidence so far) 



colormat = [1 0 0;
    0 1 0;
    0 0 1;
    0 0 0;
    0 1 1;
    1 0 1;
    1 1 0]
%%

cue_units = find(sig_all(:,1));
num_contra = 62; 
contra_units = cue_units(cues_order(1:num_contra));

load('spline_basis30_int.mat')

cue_betas_contraCueContraEv = all_cue_betas_ordered(:,1:7)*spline_basis';
cue_betas_contraCueIpsiEv = all_cue_betas_ordered(:,15:21)*spline_basis'; 
figure;
errorpatch((1:30)/15,mean(cue_betas_contraCueContraEv(contra_units,:)),std(cue_betas_contraCueContraEv(contra_units,:))/sqrt(num_contra),colormat(1,:));
hold on
errorpatch((1:30)/15,mean(cue_betas_contraCueIpsiEv(contra_units,:)),std(cue_betas_contraCueIpsiEv(contra_units,:))/sqrt(num_contra),colormat(2,:));

% with everything 
figure
for l=1:6
    hold on
    cur_spp = all_cue_betas_ordered(contra_units,(l-1)*7+1:l*7)*spline_basis';
    errorpatch((1:30)/15,mean(cur_spp),std(cur_spp)/sqrt(num_contra),colormat(l,:));
end
    
legend('Contra cue, Contra evidence So far','','Contra cues, Neutral evidence so far',...
            '','Contra Cue, Ipsi evidence So far ','','Ipsi cues, Contra evidence so far',...
           '','Ipsi cues, Neutral evidence so far','','Ipsi cues, Ipsi evidence so far')
    

set(gca,'FontSize',14)
ylabel('Kernel amplitude');
xlabel('Time from cue onset (msec)')
title(['Cue kernels for all contra-Cue-responsive neurons (n=', num2str(num_contra), ')'])


%%% with con/ipsi only 
means_cell = {};
sems_cell = {};
figure 
for l=1:6
    if l == 2 || l == 5
        continue
    end
    
    hold on
    cur_spp = all_cue_betas_ordered(contra_units,(l-1)*7+1:l*7)*spline_basis';
    errorpatch((1:30)/15,mean(cur_spp),std(cur_spp)/sqrt(num_contra),colormat(l,:));
    means_cell{l} = mean(cur_spp);
    sems_cell{l} = std(cur_spp)/sqrt(num_contra);
end




legend('Contra cues, Contra evidence','','Contra cues, Ipsi evidence','','Ipsi cues, Contra evidence','','Ipsi cues, Ipsi evidence')
    

set(gca,'FontSize',14)
ylabel('Kernel amplitude');
xlabel('Time from cue onset (msec)')
title(['Cue kernels for all contra-ue-responsive neurons (n=', num2str(num_contra), ')'])

time_vector = (1:30)/15;
