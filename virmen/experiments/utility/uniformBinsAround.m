%%
%   Bin centers for a uniform division of the range xMin to xMax into nBins
function [centers] = uniformBinsAround(nBins, xMiddle, dx)

  half      = floor( nBins/2 );
  centers   = linspace(xMiddle - half*dx, xMiddle + half*dx, 2*half + 1);

end
