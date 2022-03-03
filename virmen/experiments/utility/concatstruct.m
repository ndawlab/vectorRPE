function target = concatstruct(target, source)

  index = numel(target) + 1;
  for field = fieldnames(source)'
    target(index).(field{:}) = source.(field{:});
  end

end
