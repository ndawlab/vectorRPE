function yes = isInRectangle(rectangle, position)

  % Position vector from center of rectangle
  location    = position(1:2) - rectangle.center;
  
  % Distance along canonical axes of rectangle
  distance1   = abs( dot(location, rectangle.axis1) );
  distance2   = abs( dot(location, rectangle.axis2) );

  % Containment check
  yes         = (distance1 <= rectangle.width1) && (distance2 <= rectangle.width2);

end
