function target = replaceEmptyStruct(target, source, deep)

  % If not a structure, do nothing
  if ~isstruct(target) || ~isstruct(source)
    return;
  end
  
  % Default arguments
  if nargin < 3
    deep          = true;
  end
  
  % Get lists of fields according to target and source
  targetFields    = fieldnames(target)';
  sourceFields    = fieldnames(source)';
  checkFields     = intersect(targetFields, sourceFields);
  
  % Loop through fields in target and look for empty structs
  for field = checkFields
    % Recursive call
    if deep
      for index = 1:numel(target)
        if ~isstruct(target(index).(field{:}))
          % Do nothing if not a structure
        elseif isempty(target(index).(field{:}))
          target(index).(field{:})                                    ...
                  = replaceEmptyStruct( source.(field{:})             ...
                                      , source, deep                  ...
                                      );
        else
          target(index).(field{:})                                    ...
                  = replaceEmptyStruct( target(index).(field{:})      ...
                                      , source, deep                  ...
                                      );
        end
      end
      
    % Shallow replacement
    else
      for index = 1:numel(target)
        if isempty(target(index).(field{:})) && isstruct(target(index).(field{:}))
          target(index).(field{:})  = source.(field{:});
        end
      end
    end
  end

end
