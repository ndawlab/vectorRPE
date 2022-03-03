%%
%   Creates a row vector with n elements initialized to x
function [vec] = rowvec(x, n)

  if nargin > 1
    vec   = x .* ones(1, n);
  elseif isrow(x)
    vec   = x;
  else
    vec   = x(:)';
  end
          
end
