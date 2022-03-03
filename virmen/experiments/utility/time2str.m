function str = time2str(time)

  hour    = floor(time);
  minute  = round((time - hour) * 60);
  str     = sprintf('%02d:%02d', hour, minute);

end
