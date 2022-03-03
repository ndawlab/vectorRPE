function terminateLog(vr)

fclose(vr.fid);

% %read file & display results
% vr.fid = fopen([vr.pathname '\' vr.filename '.dat'],'r');
% data = fread(vr.fid,[5 inf],'double');
% 
% fclose(vr.fid);
% 
% data(:,find(data(5,:)==0))=[];
% 
% if ~isempty(data)
% 
%     numLeft=size(data(4,find(data(2,:)==1)),2);
%     numLeftCorrect=sum(data(4,find(data(2,:)==1)));
%     
%     numRight=size(data(4,find(data(2,:)==2)),2);
%     numRightCorrect=sum(data(4,find(data(2,:)==2)));
%     
%     numTotal=size(data,2);
%     numTotalCorrect=sum(data(4,:));
%     
%     numTurnedLeft=numLeftCorrect+numRight-numRightCorrect;
%     numTurnedRight=numTotal-numTurnedLeft;
%     
%     fprintf(['\nleft-turn trials: ' num2str(numLeft) '\n' ...
%         'correct trials:' num2str(numLeftCorrect) '\n' ...
%         'correct ratio:' num2str(numLeftCorrect/numLeft) '\n\n']);
%     
%     fprintf(['right-turn trials: ' num2str(numRight) '\n' ...
%         'correct trials:' num2str(numRightCorrect) '\n' ...
%         'correct ratio:' num2str(numRightCorrect/numRight) '\n\n']);
%     
%     fprintf(['total trials: ' num2str(numTotal) '\n' ...
%         'correct trials:' num2str(numTotalCorrect) '\n' ...
%         'correct ratio:' num2str(numTotalCorrect/numTotal) '\n\n']);
%     
%     fprintf(['turned left:' num2str(numTurnedLeft) '\n' ...
%         'turned right:' num2str(numTurnedRight) '\n\n']);
     
end