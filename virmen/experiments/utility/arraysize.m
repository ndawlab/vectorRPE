function [sz] = arraysize(x, noCellStr)
%  ARRAYSIZE    Like size(), but treats strings as a singleton.

  if nargin < 2
    noCellStr = false;
  end

  if ischar(x) || (noCellStr && iscellstr(x))
    sz        = [1 1];
  else
    sz        = size(x);
  end
  
end
