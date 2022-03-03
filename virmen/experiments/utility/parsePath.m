%% PARSEPATH    Consistent file path/name/extension parsing across operating systems.
function [path, name, ext] = parsePath(path)

  tokens    = regexp(path, '^(.*?)[/\\]*([^/\\]*?)([.][^/\\.]*)?$', 'tokens', 'once');
  if iscell(path)
    tokens  = cat(1, tokens{:});
    path    = tokens(:,1);
    name    = tokens(:,2);
    ext     = tokens(:,3);
  else
    path    = tokens{1};
    name    = tokens{2};
    ext     = tokens{3};
  end

end
