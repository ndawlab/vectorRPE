%% Programatically "press" a button
function executeCallback(handle, callback, event, varargin)

  if nargin < 2 || isempty(callback)
    callback  = 'Callback';
  end
  if nargin < 3
    event     = [];
  end

  fcn         = get(handle, callback);
  if iscell(fcn)
    fcn{1}(handle, event, fcn{2:end}, varargin{:});
  elseif ~isempty(fcn)
    fcn(handle, event, varargin{:});
  end
  
end
