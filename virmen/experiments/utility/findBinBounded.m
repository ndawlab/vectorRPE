%%
function [bin] = findBinBounded(x, xCenters)
  
  bin   = findBin(x, xCenters, false);
  bin   = max(bin, 1);
  bin   = min(bin, length(xCenters));
  
end
