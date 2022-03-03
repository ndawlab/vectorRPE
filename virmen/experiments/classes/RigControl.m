classdef RigControl < handle
  
  %----- Constants
  properties (Constant)

    COMM_INTERVAL       = 0.05;         % Time between network communications, in seconds
    
    GUI_MONITOR         = 1;
    GUI_COLOR           = [1 1 1];
    GUI_COLOR2          = [1 1 1] * 0.5;
    GUI_FONT            = 12;
    MAX_NUMROWS         = 10;
    MAX_NUMCOLS         = 10;
    STARTBAR_HEIGHT     = 45;

    MARKER_SIZE         = 4;
    
    COLOR_BUTTON        = [1   1   1  ]*0.95;
    COLOR_VALID         = [145 235 0  ]/255;
    COLOR_PENDING       = [64  182 255]/255;
    COLOR_PROBLEM       = [1   0   0  ];

    COLOR_WALL          = [1 1 1] * 0.2;
    COLOR_FLOOR         = [250 248 232]/255;
    COLOR_TARGET        = [199 222 175]/255;
    COLOR_CUEPOS        = [1 1 1] * 0.6;
    COLOR_VISCUE        = [255 196 0  ]/255;
    COLOR_MOUSE         = [0 0 0];

    CUE_X               = cos(0:0.5:2*pi);
    CUE_Y               = sin(0:0.5:2*pi);
    
    MOUSE_LENGTH        = 6;
    MOUSE_TRANGE        = [             [0:0.5:1.8 1.9:0.3:3]   ...
                            pi                                  ...
                            flip(2*pi - [0:0.5:1.8 1.9:0.3:3])  ...
                          ];
    MOUSE_X             = RigControl.MOUSE_LENGTH/3             ...
                       .* sin(RigControl.MOUSE_TRANGE)          ...
                       .* sin(RigControl.MOUSE_TRANGE/2)        ...
                        ;
    MOUSE_Y             = RigControl.MOUSE_LENGTH/2             ...
                       .* cos(RigControl.MOUSE_TRANGE)          ...
                        ;
    MOUSE_COORD         = [RigControl.MOUSE_X; RigControl.MOUSE_Y];
    
    RGX_TARGET          = '^[Cc]hoice';
    RGX_FLOOR           = 'Floor$';
    RGX_WALL            = 'Walls?$';
    
  end
  
  %----- Private data
  properties (Access = protected, Transient)
    default               % Default content of various objects
    rigMap                % Index of the rig GUI for the corresponding channel
  end
  
  %----- Public data
  properties (SetAccess = protected, Transient)
    rig                   % Rig information
    
    figGUI                % Figure for GUI
    numRows               % Number of rows of rig panels
    numCols               % Number of columns of rig panels

    hMenu
    cntGUI
    cntRig
    camRig
    hRig
  end
  properties (SetAccess = protected)
    pager                 % Message receiving and transmission system
    channel               % Index of pager channels for the corresponding rig
  end

  %_____________________________________________________________________________
  methods

    %----- Structure version to store an object of this class to disk
    function frozen = saveobj(obj)

      % Use class metadata to determine what properties to save
      metadata      = metaclass(obj);
      
      % Store all mutable and non-transient data
      for iProp = 1:numel(metadata.PropertyList)
        property    = metadata.PropertyList(iProp);
        if ~property.Transient && ~property.Constant
          frozen.(property.Name)  = obj.(property.Name);
        end
      end
   
    end
    
    %----- Constructor; typically no need to provide arguments
    function obj = RigControl(startComms)
      
      % Initial values for GUI components
      obj.figGUI                    = [];
      obj.numRows                   = 1;
      obj.numCols                   = 2;
      obj.hMenu                     = [];
      obj.cntGUI                    = [];
      obj.cntRig                    = [];
      obj.hRig                      = [];
      
      % Storage structure for rig information
      obj.default.rig.channel       = [];
      obj.default.rig.vr            = struct([]);
      obj.default.rig.animal        = struct([]);

      % Initial data
      obj.rig                       = repmat(obj.default.rig, obj.numRows, obj.numCols);
      obj.rigMap                    = [];
      
      % Start communications unless for special cases like loading from disk
      if nargin < 1 || startComms
        obj.setPager(IPPager);
      else
        obj.pager                   = [];
      end

    end
    
    %----- Destructor
    function delete(obj)
      
      if ~isempty(obj.pager)
        delete(obj.pager);
      end
      
      if ~isempty(obj.figGUI)
        for iRig = 1:numel(obj.camRig)
          obj.camRig(iRig).video.stop();
        end
        
        delete(obj.figGUI);
      end
      
    end
    
    %----- Create GUI
    function drawGUI(obj)

      % If a figure already exists, recreate it
      if ~isempty(obj.figGUI)
        delete(obj.figGUI);
      end
      
      % Obtain screen configuration
      screenSize              = get(0, 'Monitor');
      if size(screenSize,1) < 2
        % HACK to side-step Matlab bugs in monitor position retrieval
        screenSize            = get(0, 'ScreenSize');
      elseif RigControl.GUI_MONITOR < 0
        screenSize            = screenSize(size(screenSize,1) + 1 + RigControl.GUI_MONITOR, :);
      else
        screenSize            = screenSize(RigControl.GUI_MONITOR, :);
      end
      
      % Set up a full screen figure
      obj.figGUI              = figure( 'OuterPosition'     , screenSize + [0 1 0 -1]*RigControl.STARTBAR_HEIGHT  ...
                                      , 'Name'              , 'Behavioral Rig Control'    ...
                                      , 'NumberTitle'       , 'off'                       ...
                                      , 'MenuBar'           , 'none'                      ...
                                      , 'Color'             , RigControl.GUI_COLOR        ...
                                      , 'Visible'           , 'off'                       ...
                                      );
  
      % Set up menus for configuration
      obj.hMenu               = {};
      obj.hMenu{end+1}        = uimenu( obj.figGUI                                        ...
                                      , 'Label'         , 'GUI &Layout'                   ...
                                      , 'Callback'      , @obj.setGUILayout               ...
                                      );
               
      % Create panels per rig
      obj.cntGUI              = uix.GridFlex( 'Parent'            	, obj.figGUI                      ...
                                            , 'Position'            , [0 0 1 1]                       ...
                                            , 'BackgroundColor'     , RigControl.GUI_COLOR2           ...
                                            , 'Spacing'             , 10                              ...
                                            );
                            
      obj.camRig              = struct();
      obj.cntRig              = cell(obj.numRows, obj.numCols);
      for iRig = 1:numel(obj.cntRig)
        obj.cntRig{iRig}      = uix.Grid( 'Parent'              , obj.cntGUI                      ...
                                        , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                        , 'Spacing'             , 5                               ...
                                        , 'SizeChangedFcn'      , { @RigControl.resizeWideVsTall  ...
                                                                  , 1                                             ... aspectRatio
                                                                  , {'Widths', [-2 -1], 'Heights', [30 -2 -1]   } ... wide
                                                                  , {'Widths', [-2 -1], 'Heights', [30 -1 -1]}    ... tall
                                                                  , 4                                             ... children
                                                                  }                               ...
                                        );
        obj.drawRigPanel(iRig);
      end
      
      set(obj.cntGUI                    , 'Widths'              , -ones(1, obj.numCols)           ...
                                        , 'Heights'             , -ones(1, obj.numRows)           ...
                                        );


      % Make GUI visible after layout has been performed
      set(obj.figGUI, 'Visible', 'on');
                                      
    end
    
  end
  
  %_____________________________________________________________________________
  methods (Access = protected)
    
    %----- Set the pager object
    function setPager(obj, pager)
      
      if ~isempty(obj.pager)
        delete(obj.pager);
      end
      obj.pager     = pager;
      
      % Register encoding formats
      registerBehavioralEncodings(obj.pager);
      
      % Register handlers for various types of incoming info
      obj.pager.addCommandReceiver  ('e', @obj.updateExperiment);
      obj.pager.addCommandReceiver  ('i', @obj.updateTrialInitiation);
      obj.pager.addCommandReceiver  ('t', @obj.updateTrialTermination);
      obj.pager.addBroadcastReceiver('p', @obj.updatePosition);
      obj.pager.addBroadcastReceiver('c', @obj.updateCues);
      
      obj.pager.addBroadcastReceiver('W', {@obj.updateButtonControl, 'btnFreebie'});
      obj.pager.addBroadcastReceiver('D', {@obj.updateButtonControl, 'btnDraw'   });
      obj.pager.addBroadcastReceiver('F', {@obj.updateButtonControl, 'btnForfeit'});
      obj.pager.addBroadcastReceiver('G', {@obj.updateValueControl, 'sldGain'  , 'labGain'  });
      obj.pager.addBroadcastReceiver('M', {@obj.updateValueControl, 'sldMaze'  , 'labMaze'  });
      obj.pager.addBroadcastReceiver('R', {@obj.updateValueControl, 'sldReward', 'labReward'});
      
      % Start heartbeat to periodically handle communications
      obj.pager.startHeartbeat(RigControl.COMM_INTERVAL);
      
    end
    

    %----- Dialog box for setting up GUI layout
    function setGUILayout(obj, handle, event)
      
      answer        = inputdlg( { 'Number of rows:'   , 'Number of columns:' }    ...
                              , 'Configure Layout'                                ...
                              , 1                                                 ...
                              , { num2str(obj.numRows), num2str(obj.numCols) }    ...
                              );
                            
      if ~isempty(answer)
        obj.numRows = max(1, min(RigControl.MAX_NUMROWS, str2double(answer{1})));
        obj.numCols = max(1, min(RigControl.MAX_NUMCOLS, str2double(answer{2})));
        
        if obj.numRows > size(obj.rig,1)
          obj.rig(end+1:obj.numRows, :) = obj.default.rig;
        end
        if obj.numCols > size(obj.rig,2)
          obj.rig(:, end+1:obj.numCols) = obj.default.rig;
        end
        
        obj.drawGUI();
      end
      
    end
    
    %----- Draws a rig monitoring and control panel
    function drawRigPanel(obj, iRig)
      
      % Connection information
      obj.camRig(iRig).btnComm    = uicontrol   ( 'Parent'              , obj.cntRig{iRig}                ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , 'Connect to ...'                ...
                                                , 'BackgroundColor'     , RigControl.COLOR_BUTTON         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'Callback'            , {@obj.connectToRig, iRig}       ...
                                                );
      
      
      % Video display
      obj.camRig(iRig).canvas     = uicomponent ( uiflowcontainer ( 'v0'                                      ...
                                                                  , 'Parent'          , obj.cntRig{iRig}      ...
                                                                  , 'BackgroundColor' , RigControl.GUI_COLOR  ...
                                                                  )                                           ...
                                                , 'Style'               , 'Canvas'                            ...
                                                );
      
      import uk.co.caprica.vlcj.player.MediaPlayerFactory;
      canvas                      = get(obj.camRig(iRig).canvas, 'JavaPeer');
      mediaPlayerFactory          = MediaPlayerFactory;
      videoSurface                = mediaPlayerFactory.newVideoSurface(canvas);
      obj.camRig(iRig).video      = mediaPlayerFactory.newEmbeddedMediaPlayer();
      obj.camRig(iRig).video.setVideoSurface(videoSurface);
%       obj.camRig(iRig).video.playMedia('D:\Downloads\Videos\Lost.Girl.S05E07.HDTV.x264-2HD.mp4','');


      % Performance plots
      obj.camRig(iRig).cntMetric  = uix.GridFlex( 'Parent'              , obj.cntRig{iRig}                ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                , 'Spacing'             , 5                               ...
                                                , 'SizeChangedFcn'      , {@obj.resizeMetricPlots, iRig}  ...
                                                );
      obj.camRig(iRig).axsTrials  = axes        ( 'Parent'              , RigControl.makeContainer(obj.camRig(iRig).cntMetric)  ...
                                                , 'YLim'                , [0 1]                           ...
                                                );
      xlabel(obj.camRig(iRig).axsTrials, 'Trial'            , 'FontSize', RigControl.GUI_FONT);
      ylabel(obj.camRig(iRig).axsTrials, 'Fraction correct' , 'FontSize', RigControl.GUI_FONT);

      obj.camRig(iRig).linPerf    = cell(1, ChoiceExperimentStats.NUM_CHOICES+1);
      for iChoice = 1:numel(obj.camRig(iRig).linPerf)
        obj.camRig(iRig).linPerf{iChoice} = line( 'Parent'              , obj.camRig(iRig).axsTrials      ...
                                                , 'XData'               , []                              ...
                                                , 'YData'               , []                              ...
                                                , 'Color'               , [0 0 0]                         ...
                                                , 'LineWidth'           , 1.5                             ...
                                                );
        if isempty(ChoiceExperimentStats.MARKERS{iChoice})
          set(obj.camRig(iRig).linPerf{iChoice} , 'Marker'              , 'none'                          ...
                                                , 'LineStyle'           , '-'                             ...
                                                );
        else
          set(obj.camRig(iRig).linPerf{iChoice} , 'Marker'              , ChoiceExperimentStats.MARKERS{iChoice}  ...
                                                , 'MarkerSize'          , RigControl.MARKER_SIZE          ...
                                                , 'MarkerFaceColor'     , [0 0 0]                         ...
                                                , 'LineStyle'           , 'none'                          ...
                                                );
        end
      end
      
      obj.camRig(iRig).axsDaily   = axes        ( 'Parent'              , RigControl.makeContainer(obj.camRig(iRig).cntMetric)  ...
                                                , 'YLim'                , [0 1]                           ...
                                                );
      xlabel(obj.camRig(iRig).axsDaily, 'Past'    , 'FontSize', RigControl.GUI_FONT);
      ylabel(obj.camRig(iRig).axsDaily, 'Correct' , 'FontSize', RigControl.GUI_FONT);


      % Animal selector
      obj.camRig(iRig).btnAni     = uicontrol   ( 'Parent'              , obj.cntRig{iRig}                ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , 'TRAIN animal ...'              ...
                                                , 'BackgroundColor'     , RigControl.COLOR_BUTTON         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'FontWeight'          , 'bold'                          ...
                                                , 'Enable'              , 'off'                           ...
                                                , 'UserData'            , false                           ...
                                                , 'Callback'            , {@obj.execTrainAnimal, iRig}    ...
                                                );

      % Maze trajectory 
      obj.camRig(iRig).axsMaze    = axes        ( 'Parent'              , obj.cntRig{iRig}                ...
                                                , 'Box'                 , 'on'                            ...
                                                , 'XLim'                , [-50 50]                        ...
                                                , 'YLim'                , [-50 250]                       ...
                                                , 'DataAspectRatio'     , [1 1 1]                         ...
                                                );
      xlabel(obj.camRig(iRig).axsMaze, 'x (cm)');
      ylabel(obj.camRig(iRig).axsMaze, 'y (cm)');
      
      % Maze object templates
      obj.camRig(iRig).mouse      = RigControl.drawMouse(obj.camRig(iRig).axsMaze);
      obj.camRig(iRig).cues       = {};

      % Run information and experiment control
      obj.camRig(iRig).cntExper   = uix.Grid    ( 'Parent'              , obj.cntRig{iRig}                ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                , 'Spacing'             , 5                               ...
                                                , 'Padding'             , 10                              ...
                                                );
                                    uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'text'                          ...
                                                , 'String'              , 'Run started:'                  ...
                                                , 'HorizontalAlignment' , 'right'                         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                );
                                    uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'text'                          ...
                                                , 'String'              , 'Trial started:'                ...
                                                , 'HorizontalAlignment' , 'right'                         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                );
                                    uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'text'                          ...
                                                , 'String'              , 'Rewarded:'                     ...
                                                , 'HorizontalAlignment' , 'right'                         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                );
      obj.camRig(iRig).btnFreebie = uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , 'Free rewards'                  ...
                                                , 'BackgroundColor'     , RigControl.COLOR_BUTTON         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'Callback'            , {@obj.setFreeRewards, iRig}     ...
                                                );
      obj.camRig(iRig).btnDraw    = uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , '(Trial drawing)'               ...
                                                , 'BackgroundColor'     , RigControl.COLOR_BUTTON         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'Callback'            , {@obj.setTrialDrawing, iRig}    ...
                                                );
      obj.camRig(iRig).btnForfeit = uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'pushbutton'                    ...
                                                , 'String'              , 'Forfeit'                       ...
                                                , 'BackgroundColor'     , RigControl.COLOR_BUTTON         ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'Callback'            , {@obj.setForfeitTrial, iRig}    ...
                                                );
      obj.camRig(iRig).txtRun     = uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'text'                          ...
                                                , 'String'              , '(duration)'                    ...
                                                , 'HorizontalAlignment' , 'left'                          ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                );
      obj.camRig(iRig).txtTrial   = uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'text'                          ...
                                                , 'String'              , '(duration)'                    ...
                                                , 'HorizontalAlignment' , 'left'                          ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                );
      obj.camRig(iRig).txtReward  = uicontrol   ( 'Parent'              , obj.camRig(iRig).cntExper       ...
                                                , 'Style'               , 'text'                          ...
                                                , 'String'              , '### mL'                        ...
                                                , 'HorizontalAlignment' , 'left'                          ...
                                                , 'FontSize'            , RigControl.GUI_FONT             ...
                                                , 'BackgroundColor'     , RigControl.GUI_COLOR            ...
                                                );

      [obj.camRig(iRig).sldGain, obj.camRig(iRig).labGain]                                                ...
                                  = RigControl.makeSpinner( obj.camRig(iRig).cntExper                     ...
                                                          , 'rotation gain'                               ...
                                                          , javax.swing.SpinnerNumberModel(2.5,2.5,5,0.5) ...
                                                          , {@obj.setRotationGain, iRig}                  ...
                                                          , '#.#'                                         ...
                                                          );
      [obj.camRig(iRig).sldMaze, obj.camRig(iRig).labMaze]                                                ...
                                  = RigControl.makeSpinner( obj.camRig(iRig).cntExper                     ...
                                                          , 'maze ID'                                     ...
                                                          , javax.swing.SpinnerNumberModel(1,1,1,1)       ...
                                                          , {@obj.setMazeID, iRig}                        ...
                                                          , '#'                                           ...
                                                          );
      [obj.camRig(iRig).sldReward, obj.camRig(iRig).labReward]                                            ...
                                  = RigControl.makeSpinner( obj.camRig(iRig).cntExper                     ...
                                                          , 'reward factor'                               ...
                                                          , javax.swing.SpinnerNumberModel(1,1,2,0.2)     ...
                                                          , {@obj.setRewardFactor, iRig}                  ...
                                                          , '#.#'                                         ...
                                                          );
      set(obj.camRig(iRig).cntExper, 'Widths', [-2 -3]);
                                            
    end
    
    %----- Callback for when the performance display area is resized
    function resizeMetricPlots(obj, container, event, iRig)
      
      % Unfortunately uix does not behave gracefully for pre-formatting containers
      if ~RigControl.resizeWideVsTall ( container, event, 4                       ...
                                      , {'Widths', [-4 -1], 'Heights', [-1]   }   ... wide
                                      , {'Widths', [-1]   , 'Heights', [-4 -1]}   ... tall
                                      , 2                                         ... children
                                      )
        return;
      end
      
    end
    
    
    %----- Draw maze layout
    function drawRigMaze(obj, iRig, mazeID)
      
      % Only draw if the maze has changed
      currentMaze         = get(obj.camRig(iRig).axsMaze, 'UserData');
      if isequal(currentMaze, mazeID)
        return;
      end
      set(obj.camRig(iRig).axsMaze, 'UserData', mazeID);
      
      
      % Compute layout for current maze ID
      obj.rig(iRig).vr    = configureMaze(obj.rig(iRig).vr, mazeID, false);
      objects             = obj.rig(iRig).vr.exper.worlds{obj.rig(iRig).vr.currentWorld}.objects;
      
      % Clear axes before drawing
      cla(obj.camRig(iRig).axsMaze);
      
      % Loop through world objects
      for iObj = 1:numel(objects)
        % Draw walls
        if ~isempty(regexp(class(objects{iObj}), RigControl.RGX_WALL, 'once'))
          [objX,objY]     = objects{iObj}.coords2D();
          line( 'XData'     , objX                      ...
              , 'YData'     , objY                      ...
              , 'Parent'    , obj.camRig(iRig).axsMaze  ...
              , 'LineWidth' , 2                         ...
              , 'Color'     , RigControl.COLOR_WALL     ...
              );
            
        % Draw floors with targets in a different color
        elseif ~isempty(regexp(class(objects{iObj}), RigControl.RGX_FLOOR, 'once'))
          if isempty(regexp(objects{iObj}.name, RigControl.RGX_TARGET, 'once'))
            color         = RigControl.COLOR_FLOOR;
          else
            color         = RigControl.COLOR_TARGET;
          end
          
          [objX,objY]     = objects{iObj}.coords2D();
          uistack(patch ( 'XData'     , objX(1:4)                 ...
                        , 'YData'     , objY(1:4)                 ...
                        , 'Parent'    , obj.camRig(iRig).axsMaze  ...
                        , 'LineStyle' , 'none'                    ...
                        , 'FaceColor' , color                     ...
                        )                                         ...
                  , 'bottom');
        end
      end
      
      % Draw representation of mouse
      obj.camRig(iRig).mouse  = RigControl.drawMouse(obj.camRig(iRig).axsMaze);
      
      % Set extents of display
      axis(obj.camRig(iRig).axsMaze, 'tight', 'manual');
      
    end

    %----- Draw cue positions in maze
    function drawMazeCues(obj, iRig, cuePos)
      
      delete(obj.camRig(iRig).cues);
      obj.camRig(iRig).cues         = cell(1, size(cuePos,2));
      
      for iCue = 1:size(cuePos,2)
        obj.camRig(iRig).cues{iCue} = patch ( 'XData'     , RigControl.CUE_X + cuePos(1,iCue) ...
                                            , 'YData'     , RigControl.CUE_Y + cuePos(2,iCue) ...
                                            , 'LineWidth' , 1.5                               ...
                                            , 'FaceColor' , 'none'                            ...
                                            , 'EdgeColor' , RigControl.COLOR_CUEPOS           ...
                                            , 'Parent'    , obj.camRig(iRig).axsMaze          ...
                                            );
      end
      
    end
    
    
    %----- Connect the given panel to a particular rig
    function connectToRig(obj, handle, event, iRig)

      % Query user for IP address
      if ~isempty(obj.rig(iRig).channel)
        rigIP       = obj.pager.channel(obj.rig(iRig).channel).host;
      else
        rigIP       = '';
      end
      answer        = inputdlg( { 'IP address of rig Virmen computer:' }  ...
                              , 'Connect to rig'                          ...
                              , 1                                         ...
                              , { rigIP }                                 ...
                              );             
      if isempty(answer)
        return;
      end
      
      % Unassign any previous channels
      if ~isempty(obj.rig(iRig).channel)
        obj.rigMap(obj.rig(iRig).channel) = 0;
      end
      
      % Allow user to "disconnect" by entering an empty string
      if isempty(answer{:})
        set ( obj.camRig(iRig).btnComm                                  ...
            , 'String'          , 'Connect to ...'                      ...
            , 'BackgroundColor' , RigControl.COLOR_BUTTON               ...
            );
      
        return;
      end
      
      set ( obj.camRig(iRig).btnComm                                    ...
          , 'String'          , ['( Connecting to ' answer{:} ' )']     ...
          , 'BackgroundColor' , RigControl.COLOR_PROBLEM                ...
          );
      set(obj.camRig(iRig).btnAni , 'String', 'TRAIN animal ...', 'Enable', 'off');
      
      % Reset trial performance data
      for iChoice = 1:numel(obj.camRig(iRig).linPerf)
        set(obj.camRig(iRig).linPerf{iChoice}, 'XData', [], 'YData', []);
      end
        
      % Set up communications with the rig and record the channel
      obj.rig(iRig)           = obj.default.rig;
      obj.rig(iRig).channel   = obj.pager.addChannel(answer{:}, false);
      obj.rigMap(obj.rig(iRig).channel) = iRig;
      
      % Wait for two-way confirmation, retrying as necessary
      obj.pager.requestTwoWayComms( obj.rig(iRig).channel               ...
                                  , {@obj.initRigCommunications, iRig}  ...
                                  , {}                                  ...
                                  , {@obj.retryForRig, iRig}            ...
                                  );
      
    end
    
    %----- Called upon success of setting up two-way communcations
    function initRigCommunications(obj, pager, event, iRig)
      % Update GUI to reflect connection status
      set ( obj.camRig(iRig).btnComm                                ...
          , 'String'  , pager.channel(obj.rig(iRig).channel).host   ...
          );
      
      % Request info about the experiment in order to proceed
      pager.command ( event.channel                         ...
                    , {@obj.validRigCommunications, iRig}   ...
                    , {}                                    ...
                    , {@obj.retryForRig, iRig}              ...
                    , 'E'                                   ...
                    );
    end

    %----- Called upon success of requesting rig info
    function validRigCommunications(obj, pager, event, iRig)
      set(obj.camRig(iRig).btnComm, 'BackgroundColor', RigControl.COLOR_PENDING);
    end
    
    %----- Retries so long as the same channel is assigned to the given rig GUI
    function yes = retryForRig(obj, pager, event, iRig)
      yes = ( obj.rigMap(event.channel) == iRig );
    end
    
    %----- 
    function updateExperiment(obj, pager, event)

      % Ensure a valid rig
      iRig  = obj.rigMap(event.channel);
      if iRig < 1
        return;
      end
      
      set(obj.camRig(iRig).btnComm, 'BackgroundColor', RigControl.COLOR_VALID);
      obj.camRig(iRig).video.playMedia('http://128.112.219.26:8080','');
      
      % Load the experiment and relevant parameters
      vr                              = load(IPPager.toString(event.message.experiment));
      vr.exper.userdata.trainee.name  = IPPager.toString(event.message.animal);
      vr.exper.userdata.trainee.color = [];
      code                            = vr.exper.experimentCode();
      obj.rig(iRig).vr                = code.setup(vr);

      % Display the selected animal and maze
      set ( obj.camRig(iRig).btnAni                                     ...
          , 'String'  , [ 'TRAIN '                                      ...
                          obj.rig(iRig).vr.exper.userdata.trainee.name  ...
                        ] ...
          , 'Enable'  , 'on'                                            ...
          , 'UserData', false                                           ...
          );
      title ( obj.camRig(iRig).axsMaze                        ...
            , strrep(obj.rig(iRig).vr.exper.name, '_', ' ')   ...
            , 'FontSize', RigControl.GUI_FONT                 ...
            );
      
      % Set allowed range of mazes
      set ( obj.camRig(iRig).sldMaze                                                    ...
          , 'Model' , javax.swing.SpinnerNumberModel( event.message.maze                ...
                                                    , 1, numel(obj.rig(iRig).vr.mazes)  ...
                                                    , 1                                 ...
                                                    )                                   ...
          );

      % Update experiment display
      set(obj.camRig(iRig).axsMaze, 'UserData', []);
      obj.drawRigMaze(iRig, event.message.maze);
      set(obj.camRig(iRig).axsTrials, 'XLim', [1 obj.rig(iRig).vr.protocol.totalTrials]);
      
    end
    
    %----- 
    function updatePosition(obj, pager, event)
      % Ensure a valid rig
      iRig  = obj.rigMap(event.channel);
      if iRig < 1
        return;
      end
      
      RigControl.moveMouse(obj.camRig(iRig).mouse, event.message);
    end
    
    %----- 
    function updateCues(obj, pager, event)
    end
    
    %----- 
    function updateTrialInitiation(obj, pager, event)
      
      % Ensure a valid rig
      iRig  = obj.rigMap(event.channel);
      if iRig < 1
        return;
      end
      
      % Update maze display
      obj.drawRigMaze(iRig, event.message.trial(end));
%       obj.drawMazeCues(iRig, reshape(event.message.cue,2,[]));
      
      % Update trial information
      trialStart    = sprintf('%02d:%02d:%02d', event.message.start);
      set ( obj.camRig(iRig).txtTrial   ...
          , 'String'    , trialStart    ...
          , 'UserData'  , trialStart    ...
          );

      % Set running flag
      set ( obj.camRig(iRig).btnAni                                     ...
          , 'String'  , [ 'STOP '                                       ...
                          obj.rig(iRig).vr.exper.userdata.trainee.name  ...
                        ] ...
          , 'Enable'  , 'on'                                            ...
          , 'UserData', true                                            ...
          );
      
    end
    
    %----- 
    function updateTrialTermination(obj, pager, event)
      
      % Ensure a valid rig
      iRig  = obj.rigMap(event.channel);
      if iRig < 1
        return;
      end
      
      % Trial info
      iTrial            = event.message.trial(1);
      iChoice           = [event.message.trial(2), ChoiceExperimentStats.NUM_CHOICES+1];
      isCorrect         = event.message.trial(3);
      
      % Update performance data
      for iPerf = 1:numel(iChoice)
        xTrial          = get(obj.camRig(iRig).linPerf{iChoice(iPerf)}, 'XData');
        yPerf           = get(obj.camRig(iRig).linPerf{iChoice(iPerf)}, 'YData');
        xTrial(end+1)   = iTrial;
        yPerf(end+1)    = event.message.performance(iPerf);
        set ( obj.camRig(iRig).linPerf{iChoice(iPerf)}  ...
            , 'XData'   , xTrial                        ...
            , 'YData'   , yPerf                         ...
            );
      end
      
      % Update received rewards
      set(obj.camRig(iRig).txtReward, 'String', sprintf('%.3g mL', event.message.reward))

      % Set running flag
      set ( obj.camRig(iRig).btnAni                                     ...
          , 'String'  , [ 'STOP '                                       ...
                          obj.rig(iRig).vr.exper.userdata.trainee.name  ...
                        ] ...
          , 'Enable'  , 'on'                                            ...
          , 'UserData', true                                            ...
          );
      
    end
    
    %----- 
    function updateButtonControl(obj, pager, event, control)
      
      % Ensure a valid rig
      iRig  = obj.rigMap(event.channel);
      if iRig < 1
        return;
      end
      
      set ( obj.camRig(iRig).(control)                                        ...
          , 'Value'           , event.message                                 ...
          , 'BackgroundColor' , RigControl.toJColor(RigControl.COLOR_VALID)   ...
          );
        
    end
    
    %----- 
    function updateValueControl(obj, pager, event, control, label)
      
      % Ensure a valid rig
      iRig  = obj.rigMap(event.channel);
      if iRig < 1
        return;
      end
      
      set ( obj.camRig(iRig).(control)                                    ...
          , 'Value'       , event.message                                 ...
          );
      set ( obj.camRig(iRig).(label)                                      ...
          , 'Background'  , RigControl.toJColor(RigControl.COLOR_VALID)   ...
          );
        
    end
    
    %----- 
    function uncolor(obj, pager, event)
    end
    
    %----- 
    function setFreeRewards(obj, handle, event, iRig)
    end
    
    %----- 
    function setTrialDrawing(obj, handle, event, iRig)
    end
    
    %----- 
    function setForfeitTrial(obj, handle, event, iRig)
    end
    
    %----- 
    function setRotationGain(obj, handle, event, iRig)
    end
    
    %----- 
    function setMazeID(obj, handle, event, iRig)
    end
    
    %----- 
    function setRewardFactor(obj, handle, event, iRig)
    end
    
    %-----
    function execTrainAnimal(obj, handle, event, iRig)
      
      % Check if an experiment is already running
      isRunning   = get(obj.camRig(iRig).btnAni, 'UserData');
      if isRunning
        obj.pager.command(obj.rig(iRig).channel, {}, {}, @IPPager.retryUntilNextCommand, 'P');
      else
        obj.pager.command(obj.rig(iRig).channel, {}, {}, @IPPager.retryUntilNextCommand, 'S');
      end
      
    end
    
  end
  
  %_____________________________________________________________________________
  methods (Static)

    %----- Returns an equivalent Java color object
    function color = toJColor(rgb)
      color = java.awt.Color(rgb(1), rgb(2), rgb(3));
    end

    %----- Creates an intermediate uicontainer for axes
    function container = makeContainer(parent)
      container = uicontainer ( 'Parent'          , parent                  ...
                              , 'BackgroundColor' , RigControl.GUI_COLOR    ...
                              );
    end
    
    %----- Apply custom layouts for wide vs. tall containers
    function done = resizeWideVsTall(container, event, aspectRatio, wideSettings, tallSettings, minChildren)

      if nargin > 5 && numel(get(container, 'Children')) < minChildren
        done        = false;
        return;
      end
      
      containerPos  = rget(container, 'Position', 'Units', 'pixels');
      if containerPos(3) > aspectRatio * containerPos(4)
        set(container, wideSettings{:});
      else
        set(container, tallSettings{:});
      end
      
      done          = true;
      
    end
    
    %----- Create a JSpinner and label
    function [spinner, label, container] = makeSpinner(parent, title, model, callback, numberForm)
      
      font          = java.awt.Font   ( get(0, 'DefaultTextFontName')                   ...
                                      , java.awt.Font.PLAIN                             ...
                                      , RigControl.GUI_FONT + 4                         ...
                                      );
      container     = uigridcontainer ( 'v0'                                            ...
                                      , 'Parent'          , parent                      ...
                                      , 'GridSize'        , [1 2]                       ...
                                      , 'HorizontalWeight', [2 3]                       ...
                                      , 'BackgroundColor' , RigControl.GUI_COLOR        ...
                                      );
      spinner       = uicomponent ( container                                           ...
                                  , 'Style'               , 'JSpinner'                  ...
                                  , 'Model'               , model                       ...
                                  , 'Font'                , font                        ...
                                  , 'Background'          , java.awt.Color.white        ...
                                  , 'StateChangedCallback', callback                    ...
                                  );
      label         = uicomponent ( container                                           ...
                                  , 'Style'               , 'JLabel'                    ...
                                  , 'Text'                , [' ' title]                 ...
                                  , 'Font'                , font                        ...
                                  , 'Background'          , java.awt.Color.white        ...
                                  );
      
      if nargin > 4 && ~isempty(numberForm)
        editor      = javaObject('javax.swing.JSpinner$NumberEditor', get(spinner, 'JavaPeer'), numberForm);
        set(spinner, 'Editor', editor);
      else
        editor      = get(spinner, 'Editor');
        textField   = editor.getTextField();
        textField.setHorizontalAlignment(textField.RIGHT);
      end
      
    end

    %----- Representation of mus musculus
    function mouse = drawMouse(axes)
      mouse   = patch ( 'XData'     , RigControl.MOUSE_X      ...
                      , 'YData'     , RigControl.MOUSE_Y      ...
                      , 'FaceColor' , RigControl.COLOR_MOUSE  ...
                      , 'Parent'    , axes                    ...
                      );
    end
    function moveMouse(mouse, pos)
      sinAng        = sin(pos(3));
      cosAng        = cos(pos(3));
      rotation      = [  cosAng, sinAng   ...
                      ; -sinAng, cosAng   ...
                      ];

      coords        = rotation * RigControl.MOUSE_COORD;
      set( mouse, 'XData', coords(1,:) + pos(1), 'YData', coords(2,:) + pos(2) );
    end
    
  end
  
end
