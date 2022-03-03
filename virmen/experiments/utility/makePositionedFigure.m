function figHandle = makePositionedFigure(position, monitor, positionMode, varargin)

  % Default arguments
  if nargin < 2
    monitor           = 1;
  end
  if nargin < 3
    positionMode      = 'OuterPosition';
  end


  % Get the screen coordinates to reference the figure position against
  screenSize          = get(0, 'MonitorPosition');
  if monitor < 0
    monitor           = size(screenSize, 1) + monitor+1;
  end
  screenSize          = screenSize(min(monitor,end), :);
  
  % Convert position to relative coordinate if necessary
  position(1:2)       = standardCoordinate(position(1:2), screenSize(3:4)) + screenSize(1:2);
  position(3:4)       = standardCoordinate(position(3:4), screenSize(3:4));
  
  % Create and return the figure
  figHandle           = figure( positionMode, position  ...
                              , varargin{:}             ...
                              );
  
end

function coordinate = standardCoordinate(coordinate, range)

  if nargin < 3
    origin                = 0;
  end

  for iCoord = 1:numel(coordinate)
    if coordinate(iCoord) < 0
      coordinate(iCoord)  = range(iCoord) + coordinate(iCoord)+1;
    elseif abs(coordinate(iCoord)) <= 1
      coordinate(iCoord)  = range(iCoord) * coordinate(iCoord);
    end
  end

end
