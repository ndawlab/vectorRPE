%%
%   Function version of if ... else ... end statement. The syntax is 
%       conditional(test1, yes1, test2, yes2, ..., testN, yesN, allNo)
%   If all tests fail then the return value is allNo.
%
function [answer] = conditional(varargin)

  if nargin < 3 || mod(nargin, 2) ~= 1
    error('An odd number of arguments and at least three must be provided.');
  end

  % Default to no, which can be a singleton
  answer            = varargin{end};
  querySize         = arraysize(varargin{1});
  if numobj(answer) == 1 && numel(varargin{1}) > 1
    answer          = repmat(answer, querySize);
  end
  
  % Check the other tests in first-come order
  numTests          = floor(nargin / 2);
  doCheck           = true(querySize);
  for iT = 1:numTests
    test            = varargin{2*iT - 1};
    if ~islogical(test)
      error('Tests must be logical arrays.');
    end

    pass            = doCheck & test;
    yes             = varargin{2*iT};
    if numel(pass) == 1
      if pass
        answer      = yes;
      end
    elseif numobj(yes) > 1
      answer(pass)  = yes(pass);
    elseif pass
      answer(pass)  = yes;
    end
    doCheck(pass)   = false;
  end

end
