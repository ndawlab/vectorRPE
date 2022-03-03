function num = time2num(dateVector)

  if nargin < 1
    dateVector  = clock;
  end
  
  num = dateVector(4) + ( dateVector(5) + dateVector(6)/60 )/60;

end
