% algorithm: order all pvals : p(1) ... p(m)
% find minimal k such tnat p(k)>alpha/(m+1-k)
% reject 1:k-1 and not k:m

% inputs: pvals_vec: a vector of all the p-values that were obtained
%         alpha: the significance level for the multiple comparisons test (e.g. 0.05, 0.01)

% outputs: pcrit: a threshold value below which the obtained pvalues are significant
%          adj_pvals: the pvalues adjusted by the multiple comparisons test

function [pcrit,adj_pvals] = find_holmbonferroni(pvals_vec,alpha)
if nargin<2
    alpha = 0.05;
end
pvals_vec=pvals_vec(:);

[psorted,sortinds] = sort(pvals_vec);
m=length(pvals_vec);
testvec = alpha./(m+1-(1:m));
testvec =testvec (:);
critind = find(psorted>testvec,1,'first');
if isempty(critind)
    pcrit=2;
elseif critind ==1
    pcrit=-1;
else
   pcrit = mean(psorted(critind-1:critind));    
end

p_adj_notsorted=[];
adjvec = min([(m-(1:m)+1).*psorted';ones(1,m)]);
for l=1:m
    p_adj_notsorted(l) = max(adjvec(1:l));
end

adj_pvals(sortinds) = p_adj_notsorted;






