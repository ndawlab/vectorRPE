function order=slopesorter_2mat(mat1,mat2,invert)
if nargin<3
    invert=0;
end

for l=1:size(mat1,1)
    goodi = find(~isnan(mat1(l,:)));
    mm=mat1(l,goodi);
%     [fog,gof] = fit((1:size(mat,2))',mat(l,:)','poly1');
    [fog,gof] = fit(goodi',mm','poly1');
    slopvec1(l,1)=fog.p1;    
end
for l=1:size(mat2,1)
    goodi = find(~isnan(mat2(l,:)));
    mm=mat2(l,goodi);
%     [fog,gof] = fit((1:size(mat,2))',mat(l,:)','poly1');
    [fog,gof] = fit(goodi',mm','poly1');
    slopvec2(l,1)=fog.p1;    
end

[maxval,maxind] = max(abs([slopvec1 slopvec2]));
slopvec=slopvec1;
slopvec(maxind==2) = slopvec2(maxind==2);

ordslop = sortrows([slopvec (1:size(mat1,1))']);
order=ordslop(:,2);
if invert
    posslope = ordslop(:,1)>=0;
    negslope = ordslop(:,1)<0;
    order(posslope) = flipud(order(posslope));
    order(negslope) = flipud(order(negslope));
end