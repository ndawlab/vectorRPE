function vr = initializeLog(vr,pathName)

startMP285RemoteMode='n';

% create file at specified location

vr.animalID=input('animalID? ','s');
if strcmp(vr.animalID, 'ttt');
    vr.filename=[vr.animalID '-' datestr(now,'yymmdd-HHMM')];
    vr.numberOfFOVs=1;
else
    vr.trainingSession=input('Training block? ','s');
    vr.filename=[vr.animalID '-' datestr(now,'yymmdd') '-' vr.trainingSession];
    vr.numberOfFOVs=str2double(input('Number of views? ', 's'));
    if vr.numberOfFOVs>1
        while startMP285RemoteMode~='y'
            startMP285RemoteMode=input('Started MP285 control remote mode? ', 's');
        end
    end
end

% FOV
vr.sequenceOfFOVs=generateFOVSequence(vr);

vr.folderPath = [pathName '\' vr.animalID '\' datestr(now,'yymmdd')];
if exist(vr.folderPath, 'dir')==0
    mkdir(vr.folderPath);
end
    
% save copy of vr.exper with the log
exper = copyVirmenObject(vr.exper); %#ok<NASGU>
save([vr.folderPath '\' vr.filename '.mat'],'exper');

vr.fid = fopen([vr.folderPath '\' vr.filename '.dat'],'w+');

%first trial info
%fwrite(vr.fid, [vr.trialNUM vr.trialSequence(vr.trialNUM) vr.sequenceOfFOVs(vr.trialNUM)],'double');
fwrite(vr.fid, [vr.trialNUM vr.currentWorld vr.sequenceOfFOVs(vr.trialNUM)],'double');

end