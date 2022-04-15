
clear all
load cues_order
load vars_sig_all sig_all
load res_cell_ac_sfn

clear trials_ln_cell
for l=1:23
    numtrials = length(res_cell_ac_sfn(l).ypos_cell_gd);
    for k=1:numtrials
        trials_ln_cell{l}(k,1) = size(res_cell_ac_sfn(l).whole_trial_activity{k},1);
    end
end


res_cell_ac_sfn_z=res_cell_ac_sfn;




if ~exist('tmp_cue_kernels_4cues_ConfDiscmNoNeutral_ConIps_z.mat','file')
[rel_contrib_all,Fstat_all,R2_all,sesscellnum,term_names,res_cell_predicted,B_all,pred_inds_cell_all] = process_all_sessions_tmp_4cues_ConfDiscm_ConIps(res_cell_ac_sfn_z,'cue','norefit');

save tmp_cue_kernels_4cues_ConfDiscmNoNeutral_ConIps_z
else
    load tmp_cue_kernels_4cues_ConfDiscmNoNeutral_ConIps_z
end

clear all_cue_betas
curcellctr = 1;
for l=1:length(B_all)
    for k=1:length(B_all{l})
        all_cue_betas(curcellctr,:) = B_all{l}{k}(2:30)';
        curcellctr=curcellctr+1;
    end
end

all_cue_betas_ordered = all_cue_betas;

load('spline_basis30_int.mat');
cue_betas_contraCueconrtaEv = all_cue_betas_ordered(:,8:14)*spline_basis'; % 15:21 for neutral cues 
cue_betas_contraCueipsiEv = all_cue_betas_ordered(:,1:7)*spline_basis';
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

hold on
errorpatch((1:30)/15,mean(cue_betas_contraCueconrtaEv(contra_units,:)),std(cue_betas_contraCueconrtaEv(contra_units,:))/sqrt(num_contra),colormat(1,:));
hold on
errorpatch((1:30)/15,mean(cue_betas_contraCueipsiEv(contra_units,:)),std(cue_betas_contraCueipsiEv(contra_units,:))/sqrt(num_contra),colormat(2,:));

means_cell_simple{1} = mean(cue_betas_contraCueconrtaEv(contra_units,:));
means_cell_simple{2} = mean(cue_betas_contraCueipsiEv(contra_units,:));

sems_cell_simple{1} = std(cue_betas_contraCueconrtaEv(contra_units,:))/sqrt(num_contra);
sems_cell_simple{2} = std(cue_betas_contraCueipsiEv(contra_units,:))/sqrt(num_contra);
figure
for l=1:4
    hold on
    cur_spp = all_cue_betas_ordered(contra_units,(l-1)*7+1:l*7)*spline_basis';
    errorpatch((1:30)/15,mean(cur_spp),std(cur_spp)/sqrt(num_contra),colormat(l,:));
end
    
legend('Contra cues, Contra evidence','','Contra cues, Ipsi evidence','','Ipsi cues, Contra evidence','','Ipsi cues, Ipsi evidence')
    

set(gca,'FontSize',14)
ylabel('Kernel amplitude');
xlabel('Time from cue onset (msec)')
title(['Cue kernels for all contra-ue-responsive neurons (n=', num2str(num_contra), ')'])


%%%
means_cell = {};
sems_cell = {};
figure 
for l=1:4
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

