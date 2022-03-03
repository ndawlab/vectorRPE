%%
function [value] = rget(handles, property, fixName, fixValue)

  fixPrev       = rset(handles, fixName, fixValue);
  
  if iscell(property) && numel(property) == numel(handles)
    value       = cell(size(handles));
    for iH = 1:length(handles)
      value{iH} = get(handles(iH), property{iH});
    end
  else
    value       = get(handles, property);
  end
  
  rset(handles, fixName, fixPrev);

end
