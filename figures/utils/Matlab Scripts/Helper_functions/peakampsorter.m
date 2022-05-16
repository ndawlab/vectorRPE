function order=peakampsorter(mat)

[maxval,maxind] = max(mat,[],2);

[~, maxorderL] = sort(maxval(maxind<=30));
[~, maxorderR] = sort(maxval(maxind>30));

% ordslop = sortrows([maxind (1:size(mat,1))']);
% order=ordslop(:,2);

numunits = (1:size(mat,1))'; 
Lunits = numunits(maxind<=30);
Runits = numunits(maxind>30);

order = [Lunits(maxorderL)' Runits(maxorderR)'];

