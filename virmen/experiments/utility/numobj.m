function [num] = numobj(x, noCellStr)
%  NUMOBJ    Like numel(), but treats strings as a singleton.

  if nargin < 2
    noCellStr = false;
  end

  if ischar(x) || (noCellStr && iscellstr(x))
    num       = 1;
  else
    num       = numel(x);
  end
  
end
