function order=peaksorter(mat)

[maxval,maxind] = max(mat,[],2);

ordslop = sortrows([maxind (1:size(mat,1))']);
order=ordslop(:,2);