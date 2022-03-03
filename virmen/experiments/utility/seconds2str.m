function str = seconds2str(time, showHour, format)

  if nargin < 2
    showHour  = true;
  end

  if showHour
    hour      = floor(time / 60 / 60);
    time      = time - hour * 60 * 60;
  end
  minute      = floor(time / 60);
  second      = round(time - minute * 60);
  
  if showHour
    if nargin < 3
      format  = '%02d:%02d:%02d';
    end
    str       = sprintf(format, hour, minute, second);
  else
    if nargin < 3
      format  = '%02d:%02d';
    end
    str       = sprintf(format, minute, second);
  end

end
