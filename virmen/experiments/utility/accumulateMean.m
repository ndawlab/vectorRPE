%%
%   Online computation of mean.
function [newMean, newWeight] = accumulateMean(currentMean, currentWeight, x, weight)

  if weight == 0
    newMean     = currentMean;
    newWeight   = currentWeight;
  else
    newWeight   = weight + currentWeight;
    newMean     = currentMean         ...
                + (x - currentMean)   ...
                * weight              ...
                / newWeight           ...
                ;
  end

end

