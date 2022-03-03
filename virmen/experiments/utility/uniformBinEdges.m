%%
%   Bin edges for a uniform division of the range xMin to xMax into nBins
function [edges] = uniformBinEdges(nBins, xMin, xMax, integral, logarithmic)

  if nBins < 1
    edges   = [];
    
  elseif nargin > 4 && logarithmic
    xMin    = log(xMin);
    xMax    = log(xMax);
    dx      = (xMax - xMin) / nBins;
    edges   = exp( xMin:dx:(xMax + dx/10) );

  else
    dx      = (xMax - xMin) / nBins;
    if nargin > 3 && integral
      dx    = round(dx);
    end
    
    edges   = xMin:dx:(xMax + dx/10);
  end
  
end
