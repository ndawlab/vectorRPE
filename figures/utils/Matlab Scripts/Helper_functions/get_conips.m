function [mrContra, mrIpsi] = get_conips(mrL,mrR,cue_lenside)




mrContra = mrL;
mrIpsi = mrR;
mrContra(cue_lenside==2,:) = mrL(cue_lenside==2,:);
mrIpsi(cue_lenside==2,:) = mrR(cue_lenside==2,:);
