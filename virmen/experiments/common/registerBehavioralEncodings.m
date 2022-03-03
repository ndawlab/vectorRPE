function pager = registerBehavioralEncodings(pager)

  %-----------------------------------------------------------------------------
  %   Broadcasts
  %-----------------------------------------------------------------------------

  % Experiment info
  pager.addEncoding('e' , 'animal'      , @int8     ... name
                        , 'experiment'  , @int8     ... Virmen MAT file
                        , 'maze'        , @uint8    ... maze ID
                   );
  
  % Trial initiation info
  pager.addEncoding('i' , 'trial'       , @uint8    ... [index, type, mazeID]
                        , 'start'       , @uint8    ... start [hour, minute, second]
                        , 'cue'         , @single   ... [x;y] positions of all cues
                   );
                 
  % (x,y) position and view angle
  pager.addEncoding('p' , @single);
  
  % Cue is visible
  pager.addEncoding('c' , @int64);
  
  % Trial termination info
  pager.addEncoding('t' , 'trial'       , @uint16     ... [index, type, correct]
                        , 'performance' , @single     ...
                        , 'reward'      , @single     ...
                   );
  
  
  %-----------------------------------------------------------------------------
  %   Commands 
  %-----------------------------------------------------------------------------
  
  % Set rotational gain
  pager.addEncoding('G' , @single);
  % Set trial drawing method
  pager.addEncoding('D' , @uint8);
  % Set maze ID
  pager.addEncoding('M' , @uint8);
  % Set reward factor
  pager.addEncoding('R' , @single);  
  
  pager.addEncodes( 'E'             ... request experiment information
                  , 'F'             ... forfeit current trial
                  , 'W'             ... give free rewards to animal
                  , 'S'             ... start run
                  , 'P'             ... stop run
                  );

end
