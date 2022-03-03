classdef Choice < uint32
  
  enumeration
    L(1)
    R(2)
    nil(inf)
  end
  
  methods (Static)
    
    function choices = all()
      choices = setdiff(enumeration('Choice'), Choice.nil)';
    end
    
    function num = count()
      num = numel(enumeration('Choice'));
    end
    
  end
  
end
