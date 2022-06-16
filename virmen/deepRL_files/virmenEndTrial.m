function choice = virmenEndTrial(trial, pid) % , log_path, is_play)
global vr
% vr.ChoiceMade is already called. I only need InterTrial
% information. I added logging information here
%       if(char(vr.choice)== 'R')
%           fileID = fopen(strcat('./logs/cnnlstm256_hintstart_noeradestart/right_trials.txt'), 'a');
%           fprintf(fileID, strcat('\n', string(datetime), mat2str(vr.cueCombo), 'rewarded:', num2str(vr.choice== vr.trialType)));
%           fclose(fileID);
%
%       end


%       % pulled from intertrial
% % % LOGGING
vr.logger.logEnd(vr)
vr.logger.logExtras(vr, vr.rewardFactor, trial, pid);
% % % % 
% %
vr.state              = BehavioralState.SetupTrial;
if ~RigParameters.hasDAQ
    vr.worlds{vr.currentWorld}.backgroundColor  = [0 0 0];
end


vr.protocol.recordChoice( vr.choice                                   ...
    ,vr.rewardFactor * RigParameters.rewardSize);   ...
    %                               , vr.trialWeight);                               ...
%                              , vr.excessTravel < vr.maxExcessTravel        ...
%                               , vr.logger.trialLength()                     ...
%                               , cellfun(@numel, vr.cuePos)                  ...
%                               );

choice = char(vr.choice);

% prepare next trial bu running set up trial ahead of time. 
vr.iterations = vr.iterations + 1;

% Switch worlds, if necessary
if vr.currentWorld ~= vr.oldWorld
    vr.oldWorld = vr.currentWorld;
end

% Set transparency options, if necessary
if vr.oldColorSize ~= size(vr.worlds{vr.currentWorld}.surface.colors,1)
    vr.oldColorSize = size(vr.worlds{vr.currentWorld}.surface.colors,1);
    drawnow;
    virmenOpenGLRoutines(3,vr.oldColorSize);
end

% Set world background color, if necessary
if ~all(vr.oldBackgroundColor==vr.worlds{vr.currentWorld}.backgroundColor)
    vr.oldBackgroundColor = vr.worlds{vr.currentWorld}.backgroundColor;
    drawnow;
    virmenOpenGLRoutines(4,vr.oldBackgroundColor);
end



% Run custom code on each engine iteration
try
    vr = vr.code.runtime(vr);
catch ME
    drawnow;
    virmenOpenGLRoutines(2);
    err = struct;
    err.message = ME.message;
    err.stack = ME.stack(1:end-1);
    return
end

end
