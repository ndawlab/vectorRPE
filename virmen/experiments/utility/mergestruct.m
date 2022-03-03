function target = mergestruct(target, source, default, ignoreMissing, deep)

  % If not a structure, just copy
  if ~isstruct(target) || ~isstruct(source)
    target  = source;
    return;
  end

  % Default arguments
  if nargin < 3 || isempty(default)
    default       = struct();
  end
  if nargin < 4
    ignoreMissing = false;
  end
  if nargin < 5
    deep          = true;
  end
  
  % Get lists of fields according to target and source
  targetFields    = fieldnames(target)';
  sourceFields    = fieldnames(source)';
  
  % All fields missing in source can be initialized to a default if provided
  missingFields   = setdiff(targetFields, sourceFields);
  nTarget         = numel(target);
  nTotal          = max(numel(target), numel(source));
  extras          = nTarget + 1:nTotal;
  for field = missingFields
    if isfield(default, field{:})
      [target(extras).(field{:})] = deal(default.(field{:}));
    end
  end
  
  
  % Loop through fields in source and merge into target
  for field = sourceFields
    missing       = ~isfield(target, field{:});
    
    % Option to disregard fields that are not already in target
    if ignoreMissing && missing
      continue;
      
    % Deep merge of each field
    elseif deep
      % Pre-populate with default when available
      if missing
        extras    = 1:nTotal;
      else
        extras    = nTarget + 1:nTotal;
      end
      if isfield(default, field{:})
        for index = extras
          target(index).(field{:})  = default.(field{:});
        end
        fDefault  = default.(field{:});
      else
        [target(extras).(field{:})] = deal(struct([]));
        fDefault  = default;
      end
      
      for index = 1:numel(source)
        target(index).(field{:})                            ...
                  = mergestruct ( target(index).(field{:})  ...
                                , source(index).(field{:})  ...
                                , fDefault                  ...
                                , ignoreMissing             ...
                                , deep                      ...
                                );
      end
      
    % Shallow merge of each field
    else
      for index = 1:numel(source)
        target(index).(field{:})    = source(index).(field{:});
      end
    end
  end

end
