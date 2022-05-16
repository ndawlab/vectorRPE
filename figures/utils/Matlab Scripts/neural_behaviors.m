
%%%% Cue Period Variables:
% get relative contributions and Fstatistic:
warning off all
load folder_list base_folder folder_fulltraces folder_interim folder_shuffled
load res_cell_ac_sfn


if ~exist('relcon_fstat_data.mat','file')
    [rel_contrib_all,Fstat_all,R2_all,sesscellnum,term_names] = process_all_sessions(res_cell_ac_sfn,'cue','norefit');
    save([folder_interim,'relcon_fstat_data.mat'],'rel_contrib_all','Fstat_all','R2_all','sesscellnum','term_names')
end

% get Fstatistic of shuffled data:
if ~exist('all_shuff_fstat_mats_FO.mat','file')
    parfor shuffctr = 1:1000
        warning off all
        cur_filename = [folder_shuffled,'res_cell_acsfn_shuffbins_3s_new_fstat',num2str(shuffctr),'_FO.mat'];
        if ~exist(cur_filename,'file')
            tic
            aa=load([folder_shuffled,'res_cell_acsfn_shuffbins_3s_',num2str(shuffctr),'.mat']);
            [~,Fstat_all] = process_all_sessions(aa.res_cell_acsfn_shuffbins_3s,'cue','norefit');
            savetofile(Fstat_all,cur_filename,'Fstat_all');
            disp(num2str([shuffctr  toc]))
        end
    end
    for shuffctr = 1:1000
        cur_filename = [folder_shuffled,'res_cell_acsfn_shuffbins_3s_new_fstat',num2str(shuffctr),'_FO.mat'];
        cur_shuf_fstat = load(cur_filename);
        all_shuff_fstat_mats(:,:,shuffctr) = cur_shuf_fstat.Fstat_all;
    end
    save([folder_interim,'all_shuff_fstat_mats_FO.mat'],'all_shuff_fstat_mats')
else
    load all_shuff_fstat_mats_FO
end

load relcon_fstat_data
pval_mat = zeros(size(Fstat_all,1),size(Fstat_all,2));
for cellctr = 1:size(Fstat_all,1)
    for varctr = 1: size(Fstat_all,2)
        pval_mat(cellctr,varctr) = mean(Fstat_all(cellctr,varctr)<squeeze(all_shuff_fstat_mats(cellctr,varctr,:)));
    end
end


%%%% Outcome Period:
% get relative contributions and Fstatistic:
load res_cell_ac_sfn

if ~exist('relcon_fstat_data_outcome.mat','file')
    [rel_contrib_all_rw,Fstat_all_rw] = process_all_sessions(res_cell_ac_sfn,'outcome','norefit');
    save([folder_interim,'relcon_fstat_data_outcome.mat'],'rel_contrib_all_rw','Fstat_all_rw')
end

% get F-statistic of shuffled data:
if ~exist('all_shuff_fstat_mats_FO_outcome.mat','file')
    parfor shuffctr = 1:1000
        warning off all
        cur_filename = [folder_shuffled,'res_cell_acsfn_shuffbins_3s_new_fstat',num2str(shuffctr),'_FO_outcome.mat'];
        if ~exist(cur_filename,'file')
            tic
            aa=load([folder_shuffled,'res_cell_acsfn_shuffbins_3s_',num2str(shuffctr),'.mat']);
            [~,Fstat_all_rw] = process_all_sessions(aa.res_cell_acsfn_shuffbins_3s,'outcome','norefit');
            savetofile(Fstat_all_rw,cur_filename,'Fstat_all_rw');
            disp(num2str([shuffctr  toc]))
        end
    end
    for shuffctr = 1:1000
        cur_filename = [folder_shuffled,'res_cell_acsfn_shuffbins_3s_new_fstat',num2str(shuffctr),'_FO_outcome.mat'];
        cur_shuf_fstat = load(cur_filename);
        all_shuff_fstat_mats_rw(:,:,shuffctr) = cur_shuf_fstat.Fstat_all_rw;
    end
    save([folder_interim,'all_shuff_fstat_mats_FO_outcome.mat'],'all_shuff_fstat_mats_rw')
else
    load all_shuff_fstat_mats_FO_outcome
end

load relcon_fstat_data_outcome
pval_mat_rw = zeros(size(Fstat_all_rw,1),1);
for cellctr = 1:size(Fstat_all_rw,1)
    pval_mat_rw(cellctr,1) = mean(Fstat_all_rw(cellctr,1)<squeeze(all_shuff_fstat_mats_rw(cellctr,1,:)));
end

pval_mat_all = [pval_mat pval_mat_rw];
sig_all = pval_mat_all*size(pval_mat_all,2)<0.01;
save([folder_interim,'vars_sig_all.mat'],'sig_all')

rel_contrib = [rel_contrib_all rel_contrib_all_rw];
term_names{end+1} = 'reward_response';
save([folder_interim,'relcon_all.mat'],'rel_contrib','sesscellnum','term_names')




%%% get averaged activity

for l=1:length(res_cell_ac_sfn)
    [meanstr,stdstr,lenstr,centersstr]=get_avg_activity_behavior(res_cell_ac_sfn(l));
    alltlstr(l).meanstr = meanstr;
    alltlstr(l).stdstr = stdstr;
    alltlstr(l).lenstr = lenstr;
    alltlstr(l).centersstr = centersstr;
end

clear meanstr_all stdstr_all lenstr_all centersstr_all
allfields = fieldnames(alltlstr(1).meanstr);
for k=1:length(allfields)
    meanstr_all.(allfields{k})=[];
    stdstr_all.(allfields{k})=[];
    lenstr_all.(allfields{k})=[];
    centersstr_all.(allfields{k})=[];
end
for l=1:length(alltlstr)
    meanstr = alltlstr(l).meanstr;
    stdstr = alltlstr(l).stdstr;
    lenstr = alltlstr(l).lenstr;
    centersstr = alltlstr(l).centersstr;
    for k=1:length(allfields)
        meanstr_all.(allfields{k})=[meanstr_all.(allfields{k});meanstr.(allfields{k})];
        stdstr_all.(allfields{k})=[stdstr_all.(allfields{k});stdstr.(allfields{k})];
        lenstr_all.(allfields{k})=[lenstr_all.(allfields{k});lenstr.(allfields{k})];
        centersstr_all.(allfields{k})=[centersstr_all.(allfields{k});centersstr.(allfields{k})];
    end
    
end

load vars_sig_all sig_all
load relcon_all rel_contrib sesscellnum term_names

% term_names  = {'cue','pos','kinematics','accuracy','previous_reward','reward_response'}
sig_match = {'Lcues','cue';'Rcues','cue';'pos','pos';'va','kinematics';'spd','kinematics';'acc','kinematics';...
    'pos_crw','accuracy';'pos_ncrw','accuracy';'pos_prw','previous_reward';'pos_nprw','previous_reward';'rw_resp','reward_response';'nrw_resp','reward_response'};

plot_order = [3 5 6 4 1 2 7 8 9 10 11 12];

for k=1:length(allfields)
    sig_cell{k} = find(sig_all(:,strmatch(sig_match{strmatch(allfields{k},sig_match(:,1),'exact'),2},term_names)));
end

measure_names = {'meanstr','stdstr','lenstr','centersstr'};

for l=1:length(measure_names )
    for k=1:length(allfields)
        eval([measure_names{l},'_all_sig.',allfields{k},' = ',measure_names{l},'_all.',allfields{k},'(sig_cell{k},:);'])
    end
end


%make heatmaps of all significant neruons for each variable

lens_sides = 'LLRLLLLRRRRRLRRLLLLRRLR';

lenside_all(lens_sides(sesscellnum(:,1))=='L') = 1;
lenside_all(lens_sides(sesscellnum(:,1))=='R') = 2;

%%
figure
subplot(2,2,3)
numcells = size(meanstr_all_sig.pos,1);
mr = meanstr_all_sig.pos;
mr=mr-repmat(min(mr,[],2),1,size(mr,2));
mr=mr./repmat(max(mr,[],2),1,size(mr,2));
order=slopesorter(mr);
pos_order = order;
pos_heatmap = mr(order,:);
imagesc(centersstr_all.pos(1,:),1:numcells ,pos_heatmap); shg
xlabel('Position (cm)')
ylabel('Neurons')
title(['Position tuning, n=',num2str(numcells)])
set(gca,'YTick',[])




subplot(2,2,1) %pos
cla

order=pos_order;
cellnum = 56;
mr = meanstr_all_sig.pos;
% mr=mr-repmat(min(mr,[],2),1,size(mr,2));
% norm_rate = repmat(max(mr,[],2),1,size(mr,2));
% mr=mr./norm_rate;

sr = stdstr_all_sig.pos;
lr = lenstr_all_sig.pos;
pos_ex = mr(order(cellnum),:);
pos_ex_se = sr(order(cellnum),:)./sqrt(lr(order(cellnum),:)); % ./norm_rate(order(cellnum),:);
errorpatch(centersstr_all.pos(1,:),pos_ex, pos_ex_se,[0.2 0.2 0.2],2,-1); shg
xlabel('Position (cm)')
ylabel('\DeltaF/F')
title(['Position tuning , cell ',num2str(cellnum)])
curx = centersstr_all.pos(1,:);
curylow = mr(order(cellnum),:)-sr(order(cellnum),:)./sqrt(lr(order(cellnum),:));
curyhigh = mr(order(cellnum),:)+sr(order(cellnum),:)./sqrt(lr(order(cellnum),:));
axis([min(curx) max(curx) min(curylow)-0.05 max(curyhigh)+0.05])
set(gca,'Fontsize',14,'FontName','Arial')


subplot(2,2,4)
cur_lenside_sig = lenside_all(sig_cell{4});
numcells = size(meanstr_all_sig.va,1);
mr = meanstr_all_sig.va;
for o=1:size(mr,1)
    if sum(~isnan(mr(o,:)))>12
        mr(o,~isnan(mr(o,:))) = filtfilt(normpdf(-1:1,0,1)/sum(normpdf(-1:1,0,1)),1,mr(o,~isnan(mr(o,:))));
    end
end
mr=mr-repmat(min(mr,[],2),1,size(mr,2));
mr=mr./repmat(max(mr,[],2),1,size(mr,2));
mr(cur_lenside_sig==2,:) = fliplr(mr(cur_lenside_sig==2,:));    % negative is contra, positive is ipsi
order=peaksorter(mr);
va_order = order;
va_heatmap = mr(order,:);
imagesc(centersstr_all.va(1,:),1:numcells ,va_heatmap); shg

xlabel('Orientation (rad)')
title(['Orientation, n=',num2str(numcells)])
set(gca,'YTick',[])

subplot(2,2,2) % orientation
cla
order=va_order;
cellnum = 116;

curx = centersstr_all.va(1,:);
cur_va_mean = meanstr_all_sig.va;
cur_va_std = stdstr_all_sig.va;
cur_va_len = lenstr_all_sig.va;
cur_va_mean(cur_lenside_sig==2,:) = fliplr(cur_va_mean(cur_lenside_sig==2,:));
cur_va_std(cur_lenside_sig==2,:) = fliplr(cur_va_std(cur_lenside_sig==2,:));
cur_va_len(cur_lenside_sig==2,:) = fliplr(cur_va_len(cur_lenside_sig==2,:));

mr = cur_va_mean(order(cellnum),:);
sr = cur_va_std(order(cellnum),:);
lr = cur_va_len(order(cellnum),:);
if sum(~isnan(mr))>12
    mr(~isnan(mr)) = filtfilt(normpdf(-1:1,0,1)/sum(normpdf(-1:1,0,1)),1,mr(~isnan(mr)));
end

va_ex=mr-repmat(min(mr,[],2),1,size(mr,2));
norm_rate = repmat(max(mr,[],2),1,size(mr,2));
va_ex_se = sr./sqrt(lr)./norm_rate;

errorpatch(curx,va_ex, va_ex_se,[0.2 0.2 0.2],2,-1); shg
ylabel('\DeltaF/F')
curylow = mr-sr./sqrt(lr);
curyhigh  = mr+sr./sqrt(lr);
axis([min(curx) max(curx) min(curylow)-0.05 max(curyhigh)+0.05])
xlabel('Orientation (rad)')
title(['Orientation , cell ',num2str(cellnum)])
set(gca,'Fontsize',14,'FontName','Arial')


%% cues

for l=1:23
    numtrials = length(res_cell_ac_sfn(l).ypos_cell_gd);
    for k=1:numtrials
        trials_ln_cell{l}(k,1) = size(res_cell_ac_sfn(l).whole_trial_activity{k},1);
    end
end


res_cell_ac_sfn_z=res_cell_ac_sfn;
for l=1:23
    res_cell_ac_sfn_z(l).whole_trial_activity =...
        mat2cell(nanzscore(cell2mat(res_cell_ac_sfn(l).whole_trial_activity)),trials_ln_cell{l},size(res_cell_ac_sfn(l).whole_trial_activity{1},2));
end

if ~exist('tmp_cue_kernels_4cues_ConIps_z.mat','file')
    [rel_contrib_all,Fstat_all,R2_all,sesscellnum,term_names,res_cell_predicted,B_all,CovB_mat,pred_inds_cell_all] = process_all_sessions_tmp_4cues_ConIps(res_cell_ac_sfn_z,'cue','norefit');

save tmp_cue_kernels_4cues_ConIps_z
else
    load tmp_cue_kernels_4cues_ConIps_z
end
clear all_cue_betas all_cue_cov
all_cue_cov = {};
curcellctr = 1;
for l=1:length(B_all)
    for k=1:length(B_all{l})
        all_cue_betas(curcellctr,:) = B_all{l}{k}(2:22)'; % 22 (for spline of 7's) 43
        all_cue_cov{curcellctr} = CovB_mat{l}{k}(2:22, 2:22);
        curcellctr=curcellctr+1;
    end
end


all_cue_betas_ordered = all_cue_betas;

load('spline_basis30_int.mat');
cue_betas_LeftCue = all_cue_betas_ordered(:,8:14)*spline_basis';
cue_betas_RightCue = all_cue_betas_ordered(:,1:7)*spline_basis';% 21 for splines of 21

for ctr = 1:length(all_cue_cov)
    cue_sem_LeftCue(ctr,:) = sqrt(diag(spline_basis * all_cue_cov{ctr}(1:7, 1:7) * spline_basis'));
    cue_sem_RightCue(ctr,:) = sqrt(diag(spline_basis * all_cue_cov{ctr}(8:14,8:14) * spline_basis'));
end


cue_lenside = lenside_all(sig_all(:,1));
% 
% mrC = cue_betas_contraCueconrtaEv(find(sig_all(:,1)),:);
% mrI = cue_betas_contraCueipsiEv(find(sig_all(:,1)),:); 

[mrContra, mrIpsi] = get_conips(cue_betas_LeftCue(find(sig_all(:,1)),:), cue_betas_RightCue(find(sig_all(:,1)),:), cue_lenside);
[mrContraSEM, mrIpsiSEM] = get_conips(cue_sem_LeftCue(find(sig_all(:,1)),:), cue_sem_RightCue(find(sig_all(:,1)),:), cue_lenside);





numcells = size(mrIpsi,1);
num_timesteps = size(mrIpsi,2);

mr_mean_C = repmat(min([mrContra mrIpsi],[],2),1,num_timesteps);
mrContra = mrContra - mr_mean_C;
mrIpsi = mrIpsi  -mr_mean_C;
[val, argmax] = max([mrContra mrIpsi],[],2); 
% mr_peak_loc = repmat(ceil(argmax/num_timesteps), 1, num_timesteps);
mr_peak_C = repmat(val,1,num_timesteps);
mrContra = mrContra./mr_peak_C;
mrIpsi  =  mrIpsi./mr_peak_C;

order= peaksorter([mrContra mrIpsi]);
cues_order=order;

% 



imedg1 = min([mrContra(:)' mrIpsi(:)']);
imedg2 = max([mrContra(:)' mrIpsi(:)']);


figure;
subplot(1,2,1)
imagesc((1:30)/15,1:numcells ,mrContra(order,:),[imedg1 imedg2]); shg % 
xlabel('Time from cue (s)')
title(['Contra Cue n=',num2str(numcells)])
set(gca,'YTick',[])
subplot(1, 2,2)
imagesc((1:30)/15,1:numcells ,mrIpsi(order,:),[imedg1 imedg2]); shg
xlabel('Time from cue (s)')
title('Ipsi Cue')
set(gca,'YTick',[])
