function touchFile(filePath)

  import java.io.File;
  import java.lang.System;
  jFile   = java.io.File(filePath);
  jFile.setLastModified(java.lang.System.currentTimeMillis);

end
