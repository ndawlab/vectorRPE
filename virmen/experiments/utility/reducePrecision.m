function obj = reducePrecision(obj)

  if isstruct(obj)
    for field = fieldnames(obj)'
      for index = 1:numel(obj)
        obj(index).(field{:}) = reducePrecision(obj(index).(field{:}));
      end
    end
    
  elseif iscell(obj)
    for index = 1:numel(obj)
      obj{index}  = reducePrecision(obj{index});
    end
    
%   elseif isenum(obj)
%     obj       = uint8(obj);
    
  elseif isa(obj, 'double')
    obj = single(obj);
    
  end

end
