classdef OutputSynchronizer < handle
  
  %------- Constants
  properties (Constant)
    HANDSHAKE_PORT  = 60000         % For initializing a connection
    PORT            = 60001:60002   % Available TCP/IP ports for communications
    HELLO           = '!hello!'     % Message used to indicate start of a new info block
    BYEBYE          = '!bye!'       % Message used to indicate termination of communications
    HAS_SCANIMG     = '!scan!'      % Message used to indicate that the client has ScanImage

    RGX_IMAGE       = '[.](tif)$'   % Regular expression to match reference image files
    
    GUI_MONITOR     = 1
    GUI_POS         = [-650 44 300 200]
    GUI_COLOR       = [1 1 1] * 0.95
    GUI_FONT        = 11
    
    COLOR_HANDSHAKE = [84  175 255]/255
    COLOR_CONNECT   = [154 235 127]/255
    COLOR_ERROR     = [1 0 0 ]
    COLOR_CONTROL   = [1 1 1] * 0.9412
    
    SCANIMAGE       = struct( 'main'      , {'MAIN CONTROLS'}     ...
                            , 'channel'   , {'Channel 1'}         ...
                            )
%                             , 'fileName'  , {'loggingFileStem'}   ...
%                             , 'dirName'   , {'DIR...'}            ...
  end
  
  %------- Private data
  properties (Access = protected)
    default   = struct            % Default fields for data structures
    figGUI    = []                % Figure handle for GUI
    ui        = struct            % Handles to various user interface components
    
    leftover  = ''                % Partial data from last transmission
  end
  
  %------- Public data
  properties (SetAccess = protected)
    server                        % Empty if this object is a client, otherwise the handshake socket
    socket                        % Open TCP/IP sockets
    dataTags                      % Sequence of data file tags
    scanImage                     % ScanImage handles, if they exist
    imgCompare    = []            % ScanImage online comparison tool
  end

  %________________________________________________________________________
  methods
    
    %----- Constructor
    function obj = OutputSynchronizer(serverIPAddress, dataTags)

      % Server mode
      if nargin < 1
        obj.server        = tcpip ( '0.0.0.0'               , obj.HANDSHAKE_PORT  ...
                                  , 'NetworkRole'           , 'server'            ...
                                  , 'BytesAvailableFcnCount', 2                   ...
                                  );
        obj.socket        = {};
        obj.scanImage     = false(0);
        obj.serverGUI();

      % Client mode
      else
        obj.server        = [];
        obj.socket        = {tcpip( serverIPAddress, obj.HANDSHAKE_PORT             ...
                                  , 'NetworkRole'           , 'client'              ...
                                  , 'BytesAvailableFcn'     , @obj.fcnNegotiatePort ...
                                  , 'BytesAvailableFcnCount', 2                     ...
                                  )};
        obj.dataTags      = dataTags(:);
        
        % ScanImage control
        obj.findScanImage();
        
        obj.clientGUI();
      end
      
    end
    
    %----- Destructor
    function delete(obj)
      obj.fcnCloseImageCompare([], []);
      obj.closeGUI();
      
      if ~isempty(obj.server)
        fclose(obj.server);
        delete(obj.server);
      end
      for iChannel = 1:numel(obj.socket)
        if strcmp(get(obj.socket{iChannel}, 'Status'), 'open')
          fwrite(obj.socket{iChannel}, sprintf('%s\n', obj.BYEBYE));
        end
        fclose(obj.socket{iChannel});
        delete(obj.socket{iChannel});
      end
    end
    
    %----- Server mode only: wait for the specified number of connections
    function waitForConnections(obj, numChannels)
      for iChannel = numel(obj.socket) + (1:numChannels)
        executeCallback(obj.ui.channel(iChannel).btnAddRem);
      end
    end
    
    %----- Verify that the connected channels are open, or invalidate them
    function checkConnections(obj)
      
      % Client mode
      if isempty(obj.server)
        if ~isempty(obj.socket) && ~strcmp(get(obj.socket{1}, 'Status'), 'open')
          obj.disconnectServer();
        end
        
      % Server mode
      else
        for iChannel = 1:numel(obj.socket)
          if ~strcmp(get(obj.socket{iChannel}, 'Status'), 'open')
            obj.fcnRemoveChannel([], [], iChannel);
          end
        end
      end
      
    end
    
    %----- Server mode only: Send synchronization info to all clients
    function sync(obj, scanImageFlag, varargin)
      
      if isempty(obj.server)
        error('OutputSynchronizer:sync', 'sync() can only be used when in server mode.');
      end
      
      obj.checkConnections();
      
      message = sprintf('%s\n', varargin{:});
      for iChannel = 1:numel(obj.socket)
        if isempty(scanImageFlag) || obj.scanImage(iChannel) == scanImageFlag
          fwrite(obj.socket{iChannel}, message);
        end
      end
      set(obj.ui.lstInfo, 'String', varargin);
      
    end
    
  end
  
  %________________________________________________________________________
  methods (Access = protected)

    %----- Find ScanImage GUI handles
    function found = findScanImage(obj)
      
      obj.scanImage               = struct();
      for field = fieldnames(OutputSynchronizer.SCANIMAGE)'
        handle                    = findall(0, 'Type', 'figure', 'Name', OutputSynchronizer.SCANIMAGE.(field{:}));
        if numel(handle) ~= 1
          found                   = false;
          obj.scanImage           = [];
          return;
        end
        obj.scanImage.(field{:})  = handle;
      end
      
      obj.scanImage.image         = findall(obj.scanImage.channel, 'Type', 'image');
      if isempty(obj.scanImage.image)
        obj.scanImage.image       = findall(obj.scanImage.channel, 'Type', 'surface');
      end
      obj.scanImage.hSI           = evalin('base', 'hSI');
      obj.scanImage.hSICtl        = evalin('base', 'hSICtl');
      found                       = true;
      
    end

    %----- Programatically close GUI window
    function closeGUI(obj)
      if ~isempty(obj.figGUI) && ishghandle(obj.figGUI)
        delete(obj.figGUI);
      end
    end
    
    %----- (Re-)create GUI window 
    function createGUIFigure(obj, name)
      
      % Recreate the GUI figure if it already exists
      obj.closeGUI();
      
      % Compute position of figure
      obj.figGUI    = makePositionedFigure( obj.GUI_POS, obj.GUI_MONITOR, 'OuterPosition'   ...
                                          , 'Name'        , name                            ...
                                          , 'NumberTitle' , 'off'                           ...
                                          , 'Color'       , obj.GUI_COLOR                   ...
                                          , 'Menubar'     , 'none'                          ...
                                          , 'Toolbar'     , 'none'                          ...
                                          , 'Visible'     , 'on'                            ...
                                          );
      obj.ui       = struct();
      
    end
    
    %----- Display GUI for a server
    function serverGUI(obj)
      
      obj.createGUIFigure('Information Server');
      obj.ui.cntInfo      = uigridcontainer ( 'v0'                                      ...
                                            , 'Parent'              , obj.figGUI        ...
                                            , 'Units'               , 'normalized'      ...
                                            , 'Position'            , [0 0.4 1 0.6]     ...
                                            , 'EliminateEmptySpace' , 'off'             ...
                                            , 'GridSize'            , [1 1]             ...
                                            , 'Margin'              , 4                 ...
                                            );
      obj.ui.lstInfo      = uicontrol ( 'Parent'              , obj.ui.cntInfo          ...
                                      , 'Style'               , 'listbox'               ...
                                      , 'FontSize'            , obj.GUI_FONT            ...
                                      , 'HorizontalAlignment' , 'left'                  ...
                                      );
      obj.ui.cntChannel   = uigridcontainer ( 'v0'                                                    ...
                                            , 'Parent'              , obj.figGUI                      ...
                                            , 'Units'               , 'normalized'                    ...
                                            , 'Position'            , [0 0 1 0.4]                     ...
                                            , 'EliminateEmptySpace' , 'off'                           ...
                                            , 'GridSize'            , [numel(obj.PORT), 2]            ...
                                            , 'HorizontalWeight'    , [5 1]                           ...
                                            , 'Margin'              , 4                               ...
                                            );
      
      obj.ui.channel      = struct([]);
      for iChannel = 1:numel(obj.socket)
        obj.drawChannel(obj.ui.cntChannel, iChannel);
      end
      obj.drawChannel(obj.ui.cntChannel, numel(obj.socket) + 1);
      
    end

    %----- Display GUI for a client
    function clientGUI(obj)
      
      obj.createGUIFigure('Data Synchronizer');
      obj.ui.cntInfo      = uigridcontainer ( 'v0'                                      ...
                                            , 'Parent'              , obj.figGUI        ...
                                            , 'Units'               , 'normalized'      ...
                                            , 'Position'            , [0 0 1 1]         ...
                                            , 'EliminateEmptySpace' , 'off'             ...
                                            , 'GridSize'            , [2 1]             ...
                                            , 'VerticalWeight'      , [7 1]             ...
                                            , 'Margin'              , 4                 ...
                                            );
      obj.ui.lstInfo      = uicontrol ( 'Parent'              , obj.ui.cntInfo          ...
                                      , 'Style'               , 'listbox'               ...
                                      , 'FontSize'            , obj.GUI_FONT            ...
                                      , 'HorizontalAlignment' , 'left'                  ...
                                      , 'Callback'            , @obj.processSyncInfo    ...
                                      );
      obj.ui.btnServer    = uicontrol ( 'Parent'              , obj.ui.cntInfo          ...
                                      , 'Style'               , 'pushbutton'            ...
                                      , 'FontSize'            , obj.GUI_FONT            ...
                                      , 'HorizontalAlignment' , 'center'                ...
                                      , 'BackgroundColor'     , obj.COLOR_HANDSHAKE     ...
                                      , 'String'              , 'Connecting...'         ...
                                      , 'Enable'              , 'inactive'              ...
                                      , 'Callback'            , @obj.reconnectServer    ...
                                      );
      
      % Open handshake connection
      drawnow;
      executeCallback(obj.ui.btnServer);
        
    end
    
    %----- Client only: Re-establish connection with server
    function reconnectServer(obj, handle, event)
      
      fclose(obj.socket{end});
      % Open handshake connection
      try
        fopen(obj.socket{end});
      catch err
        obj.disconnectServer();
      end
      
    end
    
    %----- Client only: Disconnect server
    function disconnectServer(obj)
      fclose(obj.socket{end});
      set ( obj.ui.btnServer                        ...
          , 'String'          , 'RECONNECT...'      ...
          , 'BackgroundColor' , obj.COLOR_ERROR     ...
          , 'Enable'          , 'on'                ...
          );
    end
    
    %----- Draw a row for channel information
    function drawChannel(obj, container, iChannel)
      
      obj.ui.channel(iChannel).edtAddress                                ...
                    = uicontrol ( 'Parent'              , container       ...
                                , 'Style'               , 'edit'          ...
                                , 'HorizontalAlignment' , 'center'        ...
                                , 'BackgroundColor'     , [1 1 1]         ...
                                , 'FontSize'            , obj.GUI_FONT    ...
                                , 'Enable'              , 'inactive'      ...
                                );
      obj.ui.channel(iChannel).btnAddRem                                  ...
                    = uicontrol ( 'Parent'              , container       ...
                                , 'Style'               , 'pushbutton'    ...
                                , 'FontSize'            , obj.GUI_FONT*2  ...
                                , 'FontWeight'          , 'bold'          ...
                                );
                              
                              
      if iChannel > numel(obj.socket)
        set ( obj.ui.channel(iChannel).edtAddress                        ...
            , 'BackgroundColor' , obj.GUI_COLOR                           ...
            );
        set ( obj.ui.channel(iChannel).btnAddRem                         ...
            , 'String'          , '+'                                     ...
            , 'Callback'        , @obj.fcnAddChannel                      ...
            );
      else
        set ( obj.ui.channel(iChannel).edtAddress                        ...
            , 'String'          , sprintf('%s:%d', obj.socket{iChannel}.RemoteHost, obj.socket{iChannel}.RemotePort)  ...
            );
        set ( obj.ui.channel(iChannel).btnAddRem                         ...
            , 'String'          , '-'                                     ...
            , 'Callback'        , {@obj.fcnRemoveChannel, iChannel}       ...
            );
      end
      
    end
    
    %----- Callback to negotiate a communications port
    function fcnNegotiatePort(obj, socket, event)

      port          = fread(socket, socket.BytesAvailable);
      port          = str2double(char(port(1:end-1)));
      
      % Make sure port range is sensible
      if port < obj.PORT(1) || port > obj.PORT(end)
        return;
      end
      
      % Wait for reconnection on the assigned port
      fclose(obj.socket{1});
      set ( obj.socket{1}                               ...
          , 'RemotePort'        , port                  ...
          , 'BytesAvailableFcn' , {@obj.fcnCommunicate, @obj.fcnClient}   ...
          );
      fopen(obj.socket{1});
      
      % Received connection, display info
      set ( obj.ui.btnServer                      ...
          , 'String'          , sprintf('%s:%d', obj.socket{1}.RemoteHost, obj.socket{1}.RemotePort)  ...
          , 'BackgroundColor' , [1 1 1]           ...
          , 'Enable'          , 'inactive'        ...
          );
        
      % Notify the server that the client has ScanImage
      if ~isempty(obj.scanImage)
        fwrite(obj.socket{1}, sprintf('%s\n', obj.HAS_SCANIMG));
      end
      
    end
    
    %----- Callback to remove a channel
    function fcnRemoveChannel(obj, handle, event, iChannel)
      
      % Close communications
      if strcmp(get(obj.socket{iChannel}, 'Status'), 'open')
        fwrite(obj.socket{iChannel}, sprintf('%s\n', obj.BYEBYE));
      end
      fclose(obj.socket{iChannel});
      delete(obj.socket{iChannel});

      % Remove all associated entries
      for jChannel = iChannel:numel(obj.ui.channel)
        delete(obj.ui.channel(jChannel).edtAddress);
        delete(obj.ui.channel(jChannel).btnAddRem );
      end
      obj.ui.channel(iChannel:end)  = [];
      obj.socket(iChannel)          = [];
        
      % Redraw remaining channels
      for jChannel = iChannel:numel(obj.ui.channel)
        obj.drawChannel(obj.ui.cntChannel, jChannel);
      end
      obj.drawChannel(obj.ui.cntChannel, numel(obj.socket) + 1);
      
    end
    
    %----- Callback to add a channel
    function fcnAddChannel(obj, handle, event)
      
      if numel(obj.socket) >= numel(obj.PORT)
        errordlg( sprintf('The maximum number of connection ports (%d) has already been used.', numel(obj.PORT)) ...
                , 'Too many connections'                                                                          ...
                );
        return;
      end
      
      % Temporary display to indicate that we're waiting for a connection
      iChannel                = numel(obj.socket) + 1;
      set(obj.ui.channel(iChannel).btnAddRem , 'Enable', 'off', 'Callback', '');
      set(obj.ui.channel(iChannel).edtAddress, 'String', 'Waiting for handshake...', 'BackgroundColor', obj.COLOR_HANDSHAKE);
      drawnow;
      
      % Start a server object that waits for a connection to be established
      fopen(obj.server);

      % Grab the IP address and assign a dedicated port
      set(obj.ui.channel(iChannel).edtAddress, 'String', 'Waiting for connection...', 'BackgroundColor', obj.COLOR_CONNECT);
      drawnow;

      obj.socket{iChannel}    = tcpip ( obj.server.RemoteHost, obj.PORT(iChannel)         ...
                                      , 'NetworkRole'       , 'server'                    ...
                                      , 'BytesAvailableFcn' , {@obj.fcnCommunicate, @obj.fcnServer, iChannel}   ...
                                      );
      obj.scanImage(iChannel) = false;
      
      % Transmit the dedicated port and wait for reconnection
      fwrite(obj.server, sprintf('%d\n', obj.PORT(iChannel)));
      fclose(obj.server);
      fopen(obj.socket{iChannel});
      
      % Received connection, display info
      set ( obj.ui.channel(iChannel).edtAddress                             ...
          , 'BackgroundColor' , [1 1 1]                                     ...
          , 'String'          , sprintf('%s:%d', obj.socket{iChannel}.RemoteHost, obj.socket{iChannel}.RemotePort)  ...
          );
      set ( obj.ui.channel(iChannel).btnAddRem                              ...
          , 'String'          , '-'                                         ...
          , 'Callback'        , {@obj.fcnRemoveChannel, iChannel}           ...
          , 'Enable'          , 'on'                                        ...
          );

      % Add another row for new connections
      obj.drawChannel(obj.ui.cntChannel, numel(obj.socket) + 1);
        
    end
    
    %----- Callback to handle communications 
    function fcnCommunicate(obj, socket, event, dispatcher, varargin)
      
      if socket.BytesAvailable < 1
        return;   % No clue why this can happen sometimes
      end
      
      % packet can contain multiple transmissions due to the TCP/IP
      % buffering protocol
      packet        = char(fread(socket, socket.BytesAvailable)');
      message       = regexp([obj.leftover packet], '\n', 'split');

      % The last line must either be empty (packet ends with \n), or it is
      % a partial bit of the next incoming stream
      obj.leftover  = message{end};
      
      for iMessage = 1:numel(message)-1
        dispatcher(message{iMessage}, varargin{:});
      end
      
    end
    
    %----- Client mode callback to handle communications from the server
    function fcnClient(obj, message)
      
      if strcmp(message, obj.HELLO)
        % Server is transmitting a new info block 
        set(obj.ui.lstInfo, 'String', {});
        set(obj.scanImage.hSICtl.hGUIData.mainControlsV4.pbSetSaveDir, 'BackgroundColor', obj.COLOR_CONTROL);
        set(obj.scanImage.hSICtl.hGUIData.mainControlsV4.baseName    , 'BackgroundColor', [1 1 1]);

      elseif strcmp(message, obj.BYEBYE)
        % Server has cut connection
        obj.disconnectServer();

      else
        % Part of info block
        info  = get(obj.ui.lstInfo, 'String');
        
        % Assume that first input contains target name and directory
        if isempty(info)
          info            = [message; obj.dataTags];
          [dir,name,ext]  = parsePath(message);
          if ~exist(dir, 'dir')
            mkdir(dir);
          end
          
          obj.scanImage.hSI.hScan2D.logFilePath   = dir;
          obj.scanImage.hSI.hScan2D.logFileStem   = name;
          obj.scanImage.basename                  = name;
          
          set(obj.scanImage.hSICtl.hGUIData.mainControlsV4.pbSetSaveDir, 'BackgroundColor', obj.COLOR_CONNECT);
          set(obj.scanImage.hSICtl.hGUIData.mainControlsV4.baseName    , 'BackgroundColor', obj.COLOR_CONNECT);
        else
          info            = [info; message];
        end
        
        set(obj.ui.lstInfo, 'String', info, 'Value', 1);
      end
      
    end
    
    %----- Server mode callback to handle communications from the client
    function fcnServer(obj, message, iChannel)
      
      if strcmp(message, obj.BYEBYE)
        % Client has cut connection
        obj.fcnRemoveChannel([], [], iChannel);
        
      elseif strcmp(message, obj.HAS_SCANIMG)
        % Client has ScanImage
        obj.scanImage(iChannel) = true;
      end
      
    end
    
    %----- Callback to raise the GUI figure
    function fcnRaiseGUI(obj, handle, event)
      if ~isempty(obj.figGUI) && ishghandle(obj.figGUI)
        figure(obj.figGUI);
      end
    end
    
    %----- Callback to delete online image comparison tool
    function fcnCloseImageCompare(obj, handle, event)
      
      if ~isempty(obj.imgCompare)
        delete(obj.imgCompare);
        obj.imgCompare  = [];
      end
      
    end
  
    %----- Copy data from listbox to clipboard
    function processSyncInfo(obj, handle, event)
      
      % Only consider double-click events
      figHandle   = findParent(handle, 'figure');
      if ~strcmpi(get(figHandle, 'SelectionType'), 'open')
        return;
      end

      % Obtain current selection
      items       = get(handle, 'String');
      item        = items{get(handle, 'Value')};
      
      if isempty(regexp(item, obj.RGX_IMAGE, 'once'))
        % If it is not a reference image, try to parse it as a output path
        [path, name, ext] = parsePath(item);

        if ~isempty(path)
          % If it is a valid path, open it, creating if necessary
          if ~exist(path, 'dir')
            mkdir(path);
          end
          if exist(item, 'file')
            system(['explorer /select,"' item '"']);
          else
            system(['explorer ' path]);
          end
%           item    = [name ext];     % to be copied to clipboard
        
        else
          % Otherwise append it to the output basename
          obj.scanImage.hSI.hScan2D.logFileStem     ...
                  = [obj.scanImage.basename item];
        end
%         clipboard('copy', item);
        
      elseif ~isempty(obj.scanImage)
        % For reference images, pass them to ImageComparer
        if isempty(obj.imgCompare)
          obj.imgCompare  = ImageComparer(item);
        else
          obj.imgCompare.setRefImage(item);
        end

        set ( obj.imgCompare.figGUI                                 ...
            , 'CloseRequestFcn'     , @obj.fcnCloseImageCompare     ...
            , 'WindowButtonDownFcn' , @obj.fcnRaiseGUI              ...
            );
        obj.imgCompare.listenTo(obj.scanImage.image);
      end

    end
    
  end
  
  %________________________________________________________________________
  methods (Static)
    
  end
  
end
