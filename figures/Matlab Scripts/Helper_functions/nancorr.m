function [r,p,wasnan] = nancorr(x,y)

if nargin==2
    wasnan=0;
    bad1 = find(isnan(x));
    bad2 = find(isnan(y));
    bad1_inf = find(isinf(x));
    bad2_inf = find(isinf(y));
    
    goodind = setdiff(1:length(x),[bad1(:)' bad2(:)' bad1_inf(:)' bad2_inf(:)']);
    if length(goodind)<length(x)
        wasnan=1;
    end
    if isempty(goodind)
        r=0;
        p=1;
        wasnan=2;
    else
        [r,p] = corr(x(goodind),y(goodind));
    end
elseif nargin ==1 %matrix
    wasnan = sum(isnan(x));
    rmat = zeros(size(x,2));
    pmat = zeros(size(x,2));    
    for i=1:size(x,2)
        for j=i+1:size(x,2)
            vec1 = x(:,i);
            vec2 = x(:,j);
            
            bad1 = find(isnan(vec1));
            bad2 = find(isnan(vec2));
            bad1_inf = find(isinf(vec1));
            bad2_inf = find(isinf(vec2));
            
            goodind = setdiff(1:length(vec1),[bad1(:)' bad2(:)' bad1_inf(:)' bad2_inf(:)']);
            [r,p] = corr(vec1(goodind),vec2(goodind));
            rmat(i,j) = r;
            pmat(i,j) = p;
            
            
        end
    end
    
    r = rmat+rmat'+eye(size(x,2));
    p = pmat+pmat';
    
%     disp('')
    
end



