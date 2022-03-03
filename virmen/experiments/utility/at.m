function [y] = at(x, i, noCellStr)
% AT  Smart(er) array addressing.
%
%   Strings are treated as singletones unless the provided index i is a
%   non-singleton vector, or not 1.
%
%   Otherwise returns x{i} for cell arrays and x(i) for other types of arrays.

  if nargin < 3
    noCellStr = false;
  end

  if (ischar(x) || (noCellStr && iscellstr(x))) && numel(i) == 1 && i == 1
    y   = x;
  elseif isempty(x)
    y   = x;
  elseif iscell(x)
    y   = x{i};
  else
    y   = x(i);
  end
  
end
