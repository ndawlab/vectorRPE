%%
% 
function [yes] = ispositive(x)

  yes           = false(size(x));
  yes( x > 0 )  = true;
  
end
