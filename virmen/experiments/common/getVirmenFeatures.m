function varargout = getVirmenFeatures(feature, vr, varargin)

  featIndex             = cell(size(varargin));
  objects               = vr.worlds{vr.currentWorld}.objects;
  for iArg = 1:numel(varargin)
    if iscell(varargin{iArg})
      indices           = getIndices(objects, feature, varargin{iArg}{1});
      for iOpt = 2:numel(varargin{iArg})
        indices(iOpt,:) = getIndices(objects, feature, varargin{iArg}{iOpt});
      end
    else
      indices           = getIndices(objects, feature, varargin{iArg});
    end
    featIndex{iArg}     = indices;
  end

  if nargout == numel(varargin)
    varargout           = featIndex;
  else
    varargout           = {featIndex};
  end
  
end

function featIndex = getIndices(objects, feature, name)

  % Determine the index of the object(s) with the given name
  names             = regexp(name, '+', 'split');
  featIndex         = [];
  for iObj = 1:numel(names)
    if isfield(objects.indices, names{iObj})
      % determine the indices of the first and last feature of the object
      objIndex      = objects.indices.(names{iObj});
      firstLast     = objects.(feature)(objIndex,:);

      % return array of all feature indices belonging to the object
      indices       = firstLast(1):firstLast(2);
      featIndex(end + (1:numel(indices))) = indices;
    end
  end
  
end
