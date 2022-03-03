function target = mergeSimilar(target, source, id)

  % Get lists of fields in source to merge 
  sourceFields    = setdiff(fieldnames(source)', {id});
  hasField        = isfield(target, sourceFields);

  % Loop through source and merge into target
  targetIDs       = {target.(id)};
  for iSource = 1:numel(source)
    iTarget           = findfirst(targetIDs, source(iSource).(id), @strcmp);
    if iTarget > 0
      for iField = 1:numel(sourceFields)
        field     = sourceFields{iField};
        if ~hasField(iField)
          target(iTarget).(field)   = source(iSource).(field);
        elseif ischar(target(iTarget).(field))
          if ~strcmp(target(iTarget).(field), source(iSource).(field))
            error('mergeSimilar:sanity', 'Incompatible values %s ~= %s encountered.', target(iTarget).(field), source(iSource).(field));
          end
        else
          target(iTarget).(field)   = [target(iTarget).(field), source(iSource).(field)];
        end
      end
    else
      iTarget     = numel(target) + 1;
      for field = sourceFields
        target(iTarget).(field{:})  = source(iSource).(field{:});
      end
      target(iTarget).(id)          = source(iSource).(id);
    end
  end

end
