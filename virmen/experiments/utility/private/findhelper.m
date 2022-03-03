%%
function [position] = findhelper(array, inReverse, varargin)

  narginchk(3, inf);
  sequence                = 1:numel(array);

  % Special case with index range as input
  if      numel(varargin) > 1         ...
      &&  ~islogical(varargin{end})   ...
      &&  isnumeric(varargin{end})
    select                = false(size(array));
    select(varargin{end}) = true;
    sequence              = sequence(select);
    varargin(end)         = [];
  end

  % Handle searching from the end
  if inReverse
    sequence              = flip(sequence);
  end
  
  % Check if a test function is provided, or a value
  if isfunction(varargin{1})
    position              = findByFunction(array, sequence, varargin{:});
  else
    position              = findByValue(array, sequence, varargin{:});
  end
  
end


function [position] = findByFunction(array, sequence, comparator, outcome, veto)

  if nargin < 5
    if nargin > 3 && numel(outcome) > 1
      veto        = outcome;
      outcome     = true;
    else
      veto        = [];
    end
  end
  if nargin < 4
    outcome       = true;
  end
  
  position        = 0;
  if iscell(array)
    for pos = sequence
      if      (comparator(array{pos}) == outcome)   ...
          &&  (isempty(veto) || ~veto(array{pos}))
        position  = pos;
        break;
      end
    end
    
  else
    for pos = sequence
      if      (comparator(array(pos)) == outcome)   ...
          &&  (isempty(veto) || ~veto(array(pos)))
        position  = pos;
        break;
      end
    end
  end

end

function [position] = findByValue(array, sequence, value, comparator, outcome, veto)

  %---- Default comparator and desired test outcome
  if nargin < 6
    if nargin > 4 && numel(outcome) > 1
      veto      = outcome;
      outcome   = true;
    else
      veto      = [];
    end
  end
  if nargin < 4
    outcome     = true;
    comparator  = conditional(ischar(value), @strcmp, @eq);
  elseif nargin < 5 && ~isfunction(comparator)
    outcome     = comparator;
    comparator  = conditional(ischar(value), @strcmp, @eq);
  elseif nargin < 5
    outcome     = true;
  end

  
  %-----  Search for values
  position      = zeros(arraysize(value));
  if ~iscell(array)
    for iV = 1:numel(value)
      for pos = sequence
        if      (comparator(array(pos), value(iV)) == outcome)  ...
            &&  (isempty(veto) || ~veto(array(pos)))
          position(iV)  = pos;
          break;
        end
      end
    end
    
  elseif numobj(value) == 1
    for pos = sequence
      if      (comparator(array{pos}, value) == outcome)  ...
          &&  (isempty(veto) || ~veto(array{pos}))
        position        = pos;
        break;
      end
    end
    
  else
    for iV = 1:numel(value)
      for pos = sequence
        if      (comparator(array{pos}, value{iV}) == outcome)  ...
            &&  (isempty(veto) || ~veto(array{pos}))
          position(iV)  = pos;
          break;
        end
      end
    end
  end
end
