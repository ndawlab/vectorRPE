function yes = isgui(obj)

  yes   = ~isempty(obj) & ( isobject(obj) | ishghandle(obj) );

end
