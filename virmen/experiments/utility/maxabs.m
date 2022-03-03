function [value, index] = maxabs(array, varargin)

  [~, index]  = max(abs(array), varargin{:});
  value       = array(index);

end

