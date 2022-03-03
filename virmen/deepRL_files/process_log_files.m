% concat with 
% log63 (1) - (6) 400
% log64

trials = [log1.block(1).trial, log1.block(2).trial, ...
    log2.block(2).trial, log2.block(3).trial, log2.block(4).trial, ...
    log2.block(5).trial,  log2.block(6).trial, log2.block(7).trial, log2.block(8).trial(1:300),...
    log3.block(1).trial(301:500), log3.block(2).trial];
num_trials = length(trials); 

for i = 1:num_trials
    trials(i).choice = char(trials(i).choice);
    trials(i).trialType = char(trials(i).trialType);
end


% micePos = log.block(1).trial(1).position(:,2);
% cuePos = cell2mat(log.block(1).trial(1).cuePos(1));
% 
% cue_step = zeros(1,length(cuePos));
% 
% for i = 1:length(cuePos)
%     [~, cue_step(i)] =  min(abs(micePos-cuePos(i)));
% 
%     
% end
%%

trialType = [trials.trialType];
choices = [trials.choice];

histogram(categorical(trialType))

ep_tow = zeros(num_trials, 2);

for i = 1:num_trials
    ep_tow(i, :) = sum(trials(i).cueCombo,2);
end

ep_tow_diff = ep_tow(:,2) - ep_tow(:,1);

eq_tow_trialType = trialType(ep_tow_diff == 0);
eq_tow_choice = choices(ep_tow_diff == 0)
