%%
%   Creates a column vector with n elements initialized to x
function [vec] = colvec(x, n)

  if nargin > 1
    vec   = x .* ones(n, 1);
  elseif iscolumn(x)
    vec   = x;
  else
    vec   = x(:);
  end
          
end
