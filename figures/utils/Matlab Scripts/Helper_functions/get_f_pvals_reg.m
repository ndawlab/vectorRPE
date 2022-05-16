% X: the matrix of predictors (without the constant term)
% y: the dependent variable
% preds_to_test_cell: a cell with the indexes of predictors to be tested, for example {[1 2],[3 5],6}

function [Fp_vec,F_vec]=get_f_pvals_reg(X,y,preds_to_test_cell)

X = [ones(size(X,1),1) X];
n = size(X,1);  % number of observations
% y = tbl.MPG;
% X = [ones(n, 1), tbl.Acceleration, tbl.Cylinders, tbl.Horsepower];
k = size(X,2);             % number of variables (including constant)

b = X \ y;                 % estimate b with least squares
u = y - X * b;             % calculates residuals
s2 = u' * u / (n - k);     % estimate variance of error term (assuming homoskedasticity, independent observations)
BCOV = inv(X'*X) * s2;     % get covariance matrix of b assuming homoskedasticity of error term etc...
bse = diag(BCOV).^.5;      % standard errors


clear Fp_vec
for l=1:length(preds_to_test_cell)
        preds_to_test_cell{l} = preds_to_test_cell{l}+1; %because of the constant

%     R = [0, 0, 1, 0;
%         0, 0, 0, 1];
    R = zeros(length(preds_to_test_cell{l}),k);
    for l2 = 1:length(preds_to_test_cell{l})
        R(l2, preds_to_test_cell{l}(l2))=1;
    end
    
%     r = [0;0];
    r = zeros(length(preds_to_test_cell{l}),1);          % Testing restriction: R * b = r
    
    num_restrictions = size(R, 1);
    F = (R*b - r)'*inv(R * BCOV * R')*(R*b - r) / num_restrictions;   % F-stat (see Hiyashi for reference)
    F_vec(l) = F;
    Fp_vec(l) = 1 - fcdf(F, num_restrictions, n - k);  % F p-val
    
end




