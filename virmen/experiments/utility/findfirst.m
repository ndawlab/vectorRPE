function [position] = findfirst(array, varargin)
% FINDFIRST   Returns the index of the first item matching the given
%             criteria. Zero is returned in case there are no matching items.
%
% Examples:
%
%   findfirst(array, value, [comparator = @eq], [outcome = true], [indexRange|veto = []])
%   findfirst(array, @isnan, [outcome = true], [indexRange|veto = []])

  position  = findhelper(array, false, varargin{:});
  
end
