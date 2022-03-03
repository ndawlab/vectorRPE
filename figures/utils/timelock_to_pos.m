
% we'll want a NORMALIZED and timelocked to position matrix sent in, then
% just apply slopesorter
% matrix should be NUM_FEATS x TIME_STEPS (ie 64 x timesteps) 
% also should include the xticks in 

load('/Users/sasha/Documents/towers_mice/data/logs/va_maze/norm_pos_pes.mat')
% starting at timestep 75

numcells = 64;


POS_SEN_START = 0; 
figure;
[order,slopvec]=slopesorter(norm_pes,0); 


imagesc(num_steps_xticks,1:numcells ,norm_pes(order_possen,:)); 
xlabel('Position')
ylabel('Vector RPE')
title('Slope sorted RPE (Normalized within features) timelocked to position')

    