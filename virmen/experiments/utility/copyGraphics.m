function [copyHandle] = copyGraphics(objHandle, targetHandle, position, offset, units)
% COPYGRAPHICS    Copies a graphical object with smarter preservation of
%                 properties.


  %-----  Basic copy function
  copyHandle      = copyobj(objHandle, targetHandle);
  origUnits       = get(objHandle, 'Units');
  set ( objHandle , 'Units', units );
  set ( copyHandle, 'Units', units );
  
  
  %----- Now apply absolute positioning
  origPos         = get(objHandle, position);
  set ( copyHandle                                        ...
      , 'ActivePositionProperty'                          ...
      , get(objHandle, 'ActivePositionProperty')          ...
      , position, [origPos(1:2) + offset, origPos(3:4)]   ...
      );  
    
  %-----  Preserve relative placements (must be done with absolute units)  
  if ~strcmpi(position, 'Position')
    origInner     = get(objHandle, 'Position'     );
    origOuter     = get(objHandle, 'OuterPosition');
    copyPos       = get(copyHandle, 'OuterPosition');
    set ( copyHandle, 'Position'          ...
        , copyPos + origInner-origOuter   ...
        );
  end

  % OMG OMG OMG Matlab shuffles this after setting Position
%   copyPos         = get(copyHandle, 'OuterPosition');

  
  %-----  Preserve associated objects
  copyTitle       = get(copyHandle, 'Title');
  origTitle       = get(objHandle , 'Title');
  copyProperty(copyTitle, origTitle, 'Position', 'HorizontalAlignment', 'VerticalAlignment');
  
  
  %-----  Reset properties of the original object
  set(objHandle, 'Units', origUnits);
  
end

function [] = copyProperty(copyHandle, origHandle, varargin)

  for iArg = 1:numel(varargin)
    property  = varargin{iArg};
    set( copyHandle, property, get(origHandle, property) );
  end

end

