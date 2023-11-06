%plot cues

% numcells = size(meanstr_all_sig.Rcues,1);
% mrL = meanstr_all_sig.Lcues;
% mrR = meanstr_all_sig.Rcues;
% mrContra = mrR;
% mrIpsi   = mrL;
% mrContra(lenside_all(sig_cell{1})==2,:) = mrL(lenside_all(sig_cell{1})==2,:);
% mrIpsi  (lenside_all(sig_cell{1})==2,:) = mrR(lenside_all(sig_cell{1})==2,:);
% load('/Users/sasha/Documents/towers_mice/data/logs/VA_maze/pes_lcuercue2.mat')

numcells = size(mrContra,1);
num_steps_xticks = -5:24; % ypos(1:end-1); 
num_steps = length(num_steps_xticks);




% MIN-MAX NORM
% (x - min(x)) / max(x - min(x)) ie (x - min(x)) / (max(x) - min(x))
mr_mean_C = repmat(min([mrContra mrIpsi],[],2),1,num_steps);
mrContra = mrContra - mr_mean_C;
mrIpsi = mrIpsi  -mr_mean_C;
mr_peak_C = repmat(max([mrContra mrIpsi],[],2),1,num_steps);
mrContra = mrContra./mr_peak_C;
mrIpsi  =  mrIpsi./mr_peak_C;


% ZSCORE NORM 
% mrContra = zscore(mrContra')';
% mrIpsi = zscore(mrIpsi')';


% PEAK NORM AT TIME 0 

% cue_occur_idx = find(num_steps_xticks == 0);
% mr_mean_C = repmat(min([mrContra mrIpsi],[],2),1,num_steps);
% mrContra = mrContra - mr_mean_C;
% mrIpsi = mrIpsi  -mr_mean_C;
% 
% mr_peak_C = repmat(max([mrContra(1:end, cue_occur_idx) mrIpsi(1:end, cue_occur_idx)],[],2),1,num_steps);
% mrContra = mrContra./mr_peak_C;
% mrIpsi  =  mrIpsi./mr_peak_C;
% 


% SUBTRACT AVG ACTIVITY (NEURAL ONLY) 
% from paper: In the case of cues, the averaging
% is across cue occurrences, and the average baseline activity was
% subtracted (in the second preceding the cue occurrence). The numbers of
% significant and total neurons for that variable and maze are indicated at
% the top of each heat map.
% answering the TODO: I will take out the averaging before timestep so I
% avoid this problem. 

% mr_mean_contra = repmat(mean([mean(mrContra(:,1:15),2) mean(mrIpsi(:,1:15),2)],2),1,size(mrContra,2));
% mrContra=mrContra - mr_mean_contra;
% mrIpsi=mrIpsi - mr_mean_contra;

order=peaksorter([mrContra mrIpsi]);
% sort at cue appearance
% order=peaksorter([mrContra(:, find(num_steps_xticks == 0)) mrIpsi(:, find(num_steps_xticks == 0))]);

% order=peaksorter([mrContra(1:end, end) mrIpsi(1:end, end)]);



imedg1 = min([mrContra(:)' mrIpsi(:)']);
imedg2 = max([mrContra(:)' mrIpsi(:)']);
figure; 
subplot(1,2,1)
imagesc(num_steps_xticks,1:numcells ,mrContra(order,:),[imedg1 imedg2]); shg
% xlabel('Timesteps from cue onset')
xlabel('Position')
ylabel('Vector RPE')
title('Left Cue')
% set(gca,'YTick',[])
subplot(1,2,2)
imagesc(num_steps_xticks,1:numcells ,mrIpsi(order,:),[imedg1 imedg2]); shg
% xlabel('Timesteps from cue onset')
xlabel('Position')
title('Right Cue')
% set(gca,'YTick',[])


