%%
function [previousValue] = rset(handles, property, value)

  previousValue   = get(handles, property);
  
  if iscell(value) && numel(value) == numel(handles)
    for iH = 1:length(handles)
      set(handles(iH), property, value{iH});
    end
  else
    set(handles, property, value);
  end

end
