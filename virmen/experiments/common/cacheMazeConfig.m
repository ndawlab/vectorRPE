%% Cache various properties of the loaded world (maze configuration), for speed.
function vr = cacheMazeConfig(vr, forceVisibility)

  maze                = vr.mazes(vr.mazeID);
  if nargin < 2
    forceVisibility   = false;
  end

  % Store default visibility of objects
  vr.visibilityMask   = true(size(vr.worlds{vr.currentWorld}.surface.visible));
  for name = fieldnames(maze.visible)'
    vr.visibilityMask(vr.(name{:}))                     ...
                      = forceVisibility                 ...
                      | (maze.visible.(name{:}) == 1)   ...
                      | (maze.visible.(name{:}) == 2)   ...
                      ;
  end
  
  % Store color variations
  for var = fieldnames(maze.color)'
    vr.(['clr_' var{:}])  = dimColors ( vr.worlds{vr.currentWorld}.surface.colors   ...
                                      , vr.(var{:})(vr.currentWorld,:)              ...
                                      , maze.color.(var{:})                         ...
                                      );
  end
  
end
