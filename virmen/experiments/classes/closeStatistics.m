function closeStatistics()

  handles = findall(0, 'Type', 'figure', 'Name', 'ViRMEn Experiment Statistics');
  close(handles);

end
