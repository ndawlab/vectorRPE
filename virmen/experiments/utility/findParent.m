function handle = findParent(handle, type)

  while ~isempty(handle) && ~strcmp(get(handle,'Type'), type)
    handle  = get(handle, 'Parent');
  end

end
