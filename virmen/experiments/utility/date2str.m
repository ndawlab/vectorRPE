function str = date2str(date)

%   str   = sprintf('%02d/%02d/%04d', date(2), date(3), date(1));
  str   = sprintf('%04d/%02d/%02d', date(1), date(2), date(3));

end
