function str = incr2str(incr)

  if incr < 0
    str   = '- ';
  else
    str   = '+ ';
  end
  str     = [str num2str(abs(incr))];

end
