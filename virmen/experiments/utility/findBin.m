function [bin, varargout] = findBin(x, xCenters, varargin)
% FINDBIN   Locates the bin in xCenters in which x falls. 
%
%   If out of range, returns a negative answer unless a third argument is
%   provided and is false. In the latter case containment checking is
%   turned off.
%
%   Note that the left edges of bins are inclusive and the right edges are
%   exclusive. 


  % If there is only one bin then it's a weird case where we don't know
  % what the bin width is
  if length(xCenters) < 2
    if nargin < 3 || varargin{1}
      error('Unable to determine containment since there is only one bin.');
    end
    
    bin   = ones(size(x));
    if nargout > 1
      varargout{1}  = true(size(x));
    end
    return;
  end
  
  dx      = xCenters(2) - xCenters(1);
  bin     = 1 + floor((x - xCenters(1) + dx/2) / dx);
  
  % Special case to check for range (default on)
  if nargin < 3 || varargin{1}

    outOfRange      = ( x < xCenters(1) - dx/2 | x >= xCenters(end) + dx/2 );
    bin(outOfRange) = -1;
    if nargout > 1
      varargout{1}  = ~outOfRange;
    end
    
  elseif nargout > 1
    varargout{1}    = true(size(x));
  end

end
