function index = day2index(date)

  if nargin < 1
    date  = now;
  end

  index   = weekday(date);
  index   = mod(index - 2,7) + 1;   % Monday should be day 1

end
