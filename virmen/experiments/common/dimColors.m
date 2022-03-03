function [coloring] = dimColors(surfaces, subset, scaleFactor)

  coloring                      = cell(numel(scaleFactor) + 1, numel(subset));
  for iSet = 1:numel(subset)
    for iSF = 1:numel(scaleFactor)
      coloring{iSF,iSet}        = surfaces(:, subset{iSet});
      coloring{iSF,iSet}(1:3,:) = coloring{iSF,iSet}(1:3,:) * scaleFactor(iSF);
    end

    % Always keep a copy of the original
    coloring{end,iSet}          = surfaces(:, subset{iSet});
  end

end
