function order=slopesorter(mat,invert)
if nargin<2
    invert=0;
end

for l=1:size(mat,1)
    goodi = find(~isnan(mat(l,:)));
    mm=mat(l,goodi);
%     [fog,gof] = fit((1:size(mat,2))',mat(l,:)','poly1');
    [fog,gof] = fit(goodi',mm','poly1');
    slopvec(l,1)=fog.p1;    
end

ordslop = sortrows([slopvec (1:size(mat,1))']);
order=ordslop(:,2);
if invert
    posslope = ordslop(:,1)>=0;
    negslope = ordslop(:,1)<0;
    order(posslope) = flipud(order(posslope));
    order(negslope) = flipud(order(negslope));
end