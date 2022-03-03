%% IPPAGER  Provides lazy communications between two Matlab sessions via network (UDP protocol).
%
%   IPPager objects communicate lazily in the sense that message
%   transmission and reception are designed to be as non-blocking as
%   possible, even at cost of packet losses. Connections can also be lost
%   without interrupting execution, appearing as just a lack of pending
%   messages.
%
% ===============
%  CONFIGURATION
% ===============
%
%   The communication lines are bidirectional and should be set up via
%   addChannel() after construction. Channels can then be addressed by
%   the index returned by this function, for the purposes of targeted
%   message passing. The special value of NaN for functions expecting
%   channel index input will be taken as applying to all registered
%   channels. 
%
% ========================
%  DATA ENCODING/DECODING
% ========================
%
%   All data transmission is performed as byte arrays. The first
%   byte is reserved to identify the data format, and must be an
%   alphabetical character which the user sets up via addEncoding(). Three
%   methods are possible to do this, for example:
%     addEncoding('d', @double)
%       --  The data format 'd' will be interpreted as a array of doubles.
%     addEncoding('s', 'a', @double, 'b', @int)
%       --  The data format 's' will be interpreted as a struct with fields
%           a and b, of types double and int arrays respectively.
%     addEncodes('x', 'y', 'z', ...)
%       --  This registers x, y, z and so forth as valid format codes with
%           no additional data items, and is a shortcut for calling
%           addEncoding('x') etc.
%
%   Once set up, the format codes can be used with the message
%   transmission functions described below like:
%     broadcast('d', 1:10);
%     broadcast('s', struct('a', {1.5}, 'b', {10}));
%   The message reception callback functions are assigned to a particular
%   encoding format and will be called with an argument converted to the
%   specified array or struct (from the raw byte data).
%
%   IMPORTANT limitation:
%     For speed and package size considerations, the length of structure
%     field variables must not exceed 255 items. If an array exceeding this
%     size is provided, it will be truncated with a warning message.
%
% ======================
%  MESSAGE TRANSMISSION
% ======================
%
%   Sending of messages are performed in either of two modes by the
%   following functions:
%     broadcast()   : Data is sent asynchronously and with no reception
%                     checks. If another broadcast() is called when the
%                     previous one has not yet finished transmitting data,
%                     it is ignored in order not to arrive at a situation
%                     with build up of bottlenecks. The user is responsible
%                     for sending and handling a time stamp for the
%                     transmitted data, as UDP does not guarantee the order
%                     of arrival of packets.
%     command()     : Data is sent asynchronously but with acknowledgment
%                     checking and re-transmission (up to MAX_RETRIES) in
%                     case no acknowledgment is received within
%                     RETRY_INTERVAL. If another command() is issued while
%                     the previous one has yet to succeed, it will still be
%                     executed, the reasoning being that commands will be
%                     sent with low enough frequency that this does not
%                     become a problem; however hasPendingCommand() can be
%                     used by the user to avoid this. The user must provide
%                     two callback functions to handle the cases of success
%                     (acknowledgment received) and failure (all other
%                     cases). In case an acknowledgment is received when a
%                     failure has already been reported, the success
%                     callback will still be called but flagging the
%                     situation as stale.
%   Execution of commands will be performed by the receiver only when a
%   receipt of the command acknowledgment is received. In this way it is
%   not possible for commands to be executed without the sender obtaining
%   an acknowledgment of it; however it is possible that the command is NOT
%   executed even when acknowledged, in the case where the receipt is lost.
%
%   Both broadcast() and command() functions takes a list of channels
%   (specified by index) to which the message should be transmitted to.
%   Providing an empty list for the channels argument will default to
%   sending to all channels.
%
%   Note that the same encoding format can be used in both broadcast() and
%   command() modes. The mode used by the sender will dictate the type of
%   reception (described below) that is performed.
%
% ===================
%  MESSAGE RECEPTION
% ===================
%
%   Reception of messages are performed by the user provided callback
%   functions post construction via:
%     addBroadcastReceiver()  : These callbacks simply receive the data
%                               packet and an event structure that contains
%                               the channel index of the transmitter.
%     addCommandReceiver()    : These callbacks receive the data packet,
%                               and an event structure that contains the
%                               channel index of the transmitter and two
%                               indices identifying the command: a command
%                               count, and a retry number (0 = first time).
%
%   IPPager tries to ensure that command callbacks are executed at most one
%   per received command, even if multiple re-transmissions occur for some
%   reason. This is done by assigning each command an index (incremented
%   per command) and keeping an account of which commands have already been
%   executed. Note that to save bandwidth the command count rolls over as
%   it is represented by a single byte, but presumably no sane system would
%   have a backlog of 256 commands and conflicts would not typically occur.
%

classdef IPPager < handle
  
  %----- Constants
  properties (Constant)
    
    PORT                = 50001:50100           % Range of UDP ports utilized for communications
    TALK_TIMEOUT        = 0.05                  % Timeout for all communications, in seconds
    RETRY_INTERVAL      = 1                     % Retry if no acknowledgment of a sent command is obtained within this number of seconds
    MIN_THROTTLE        = 0.04                  % Minimum interval between broadcasts, for throttling
    MAX_THROTTLE        = 1                     % Maximum interval between broadcasts, for throttling
    INIT_THROTTLE       = 0.1                   % Initial interval between broadcasts, for throttling
    PING_INTERVAL       = 0.5                   % Interval between pings sent to each registered channel
    PONG_NBYTES         = 2                     % Number of bytes to use for past pongs in a ping acknowledgment
    PING_LEEWAY         = 8 * IPPager.PONG_NBYTES * IPPager.PING_INTERVAL + 1     % Maximal amount of time (in seconds) to allow before considering a ping as lost
    RTT_RANGE           = [0.01 IPPager.PING_LEEWAY]                              % GUI range for round trip time
    MAX_RETRIES         = 100                   % Maximum number of times that any command will be resent
    MAX_PACKET_SIZE     = 512                   % Maximum size of data packets
    RTT_SMOOTHING       = 0.1                   % Round-trip time exponential smoothing factor
    BYTE_BITS           = ( 2.^(0:7) )'         % For computing bit representations

    DATA_FCN            = @int8
    DATA_STR            = func2str(IPPager.DATA_FCN)
    MAX_INDEX           = IPPager.DATA_FCN(inf)
    INDEX_OFFSET        = 1 - double(IPPager.DATA_FCN(-inf))
    NUM_INDEX           = IPPager.INDEX_OFFSET + double(IPPager.MAX_INDEX);
    MSG_STOP            = IPPager.DATA_FCN(-inf)
    
    PRE_PING            = IPPager.DATA_FCN('\')
    PRE_PONG            = IPPager.DATA_FCN('/')
    PRE_BROADCAST       = IPPager.DATA_FCN(':')
    PRE_COMMAND         = IPPager.DATA_FCN('!')
    PRE_REPLY           = IPPager.DATA_FCN('~')
    PRE_RECEIPT         = IPPager.DATA_FCN('=')
    PRE_FAILURE         = IPPager.DATA_FCN('*')
    PRE_FIXEDLENGTH     = { IPPager.PRE_PING      ...
                          , IPPager.PRE_PONG      ...
                          };
    
    ID_TALKTOME         = IPPager.PRE_BROADCAST
    ID_VERIFY           = IPPager.PRE_COMMAND
    ID_RESERVED         = { IPPager.PRE_BROADCAST ...
                          , IPPager.PRE_COMMAND   ...
                          , IPPager.PRE_REPLY     ...
                          , IPPager.PRE_RECEIPT   ...
                          , IPPager.PRE_FAILURE   ...
                          }
    ID_SYSTEM           = { IPPager.ID_TALKTOME   ...
                          , IPPager.ID_VERIFY     ...
                          };
                        
    MAGIC_WORD          = '>IP><Pager|'
    
    STATS_MONITOR       = 1;
    STATS_POS           = [-250 -450 250 350];
    STATS_FONT          = 11;
    STATS_NSEC          = 5;            % Number of seconds per statistics "clock" revolution
    STATS_FADE          = 0.5;          % Duration (in seconds) of port activity indication
    STATS_COLOR         = struct( 'tooLong'     , {[168 106 204]/255}   ...
                                , 'broadcasts'  , {[155 217 0  ]/255}   ...
                                , 'commands'    , {[235 0   0  ]/255}   ...
                                , 'acknowledged', {[245 188 0  ]/255}   ...
                                , 'retried'     , {[207 99  99 ]/255}   ...
                                , 'unreplied'   , {[207 99  99 ]/255}   ...
                                , 'failed'      , {[207 99  99 ]/255}   ...
                                , 'received'    , {[0   121 217]/255}   ...
                                , 'refused'     , {[87  144 194]/255}   ...
                                , 'malformed'   , {[87  144 194]/255}   ...
                                , 'truncated'   , {[87  144 194]/255}   ...
                                                                        ...
                                , 'inactive'    , {[1 1 1] * 0.9}       ...
                                );
%                                 , 'pings'       , {[170 134 184]/255}   ...
%                                 , 'blocked'     , {[174 201 105]/255}   ...
    GUI_COLOR           = [1 1 1];
    ANNOT_COLOR         = [1 1 1] * 0.7;
    
  end
  
  %----- Private data
  properties (Access = protected, Transient)
    default                           % Default content of various objects
    encodeIDMap                       % Hash map for lookup of encoding formats
    cmdIndex                          % Index of last command SENT (starts from 1)
    buffer                            % Input buffer
    
    figStats                          % Figure for statistics display
    hStats                            % Handles for statistics objects
  end
  
  %----- Public data
  properties (SetAccess = protected, Transient)
    encoding                          % Registered data encoding formats                  
    statistics                        % Number of transmissions, by category
    pacemaker                         % Timer to execute heartbeat function, if so configured

    sockIndex                         % Index of last used UDP socket
    socket                            % UDP sockets for in/outbound transmissions
    
    started                           % Date and time at which this object was created
  end
  properties (SetAccess = protected)
    channel                           % Registered communication lines
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
    
    %----- Constructor
    function obj = IPPager()

      % Data encoding format specification
      obj.default.encoding.id           = IPPager.DATA_FCN(0);
      obj.default.encoding.struct       = [];
      obj.default.encoding.fields       = [];
      obj.default.encoding.formatStr    = {};
      obj.default.encoding.formatFcn    = {};
      obj.default.encoding.formatMax    = {};
      obj.default.encoding.broadcast    = {};
      obj.default.encoding.command      = {};

      % Command sending callbacks
      obj.default.command.info.retries  = 0;
      obj.default.command.timer         = [];
      obj.default.command.successFcn    = {};
      obj.default.command.failureFcn    = {};
      obj.default.command.retryFcn      = {};
      
      % Data for each channel
      obj.default.channel.host          = '';
      obj.default.channel.address       = cell(size(IPPager.PORT));
      obj.default.channel.isTwoWay      = false;
      obj.default.channel.command       = cell(1, IPPager.MAX_INDEX);   % Command TO this channel yet to be acknowledged, indexed by cmdIndex
      obj.default.channel.dispatch      = cell(1, IPPager.MAX_INDEX);   % Command FROM this channel yet to be dispatched, indexed according to sender
      obj.default.channel.lastBroadcast = -inf;                         % tic value for the last broadcast
      obj.default.channel.throttle      = IPPager.INIT_THROTTLE;        % Throttled interval between broadcasts
      obj.default.channel.rtt           = nan;                          % Estimated round-trip time for messages sent to this channel
      obj.default.channel.pingIndex     = IPPager.NUM_INDEX;            % Local index of keep-alives sent TO this channel
      obj.default.channel.pinged        = zeros(1, IPPager.NUM_INDEX, 'uint64');   % tic of keep-alives sent TO this channel
      obj.default.channel.ponged        = zeros(1, IPPager.NUM_INDEX, 'uint64');   % tic of when pings sent FROM this channel have been acknowledged
      
      % Initial values for various data
      obj.cmdIndex                      = IPPager.DATA_FCN(0);
      obj.encodeIDMap                   = zeros(1, IPPager.MAX_INDEX);
      obj.encoding                      = repmat(obj.default.encoding, 0);
      obj.pacemaker                     = [];
      obj.started                       = clock;

      % Communications sockets and settings
      obj.channel                       = obj.default.channel;          % First channel reserved for unknown hosts
      obj.buffer                        = java.nio.ByteBuffer.allocate(IPPager.MAX_PACKET_SIZE);
      obj.sockIndex                     = 0;
      obj.socket                        = cell(size(IPPager.PORT));
      for iPort = 1:numel(IPPager.PORT)
        obj.socket{iPort}               = java.nio.channels.DatagramChannel.open();
        obj.socket{iPort}.configureBlocking(false);
        obj.socket{iPort}.bind(java.net.InetSocketAddress(IPPager.PORT(iPort)));
      end
      
      % Stored transmission statistics
      obj.statistics.tooLong            = 0;              % Number of transmissions aborted because they are too long
%       obj.statistics.pings              = 0;              % Number of pings/pongs sent
      obj.statistics.broadcasts         = 0;              % Number of broadcasts sent
%       obj.statistics.blocked            = 0;              % Number of broadcasts not sent because a previous transmission is still ongoing
      obj.statistics.commands           = 0;              % Number of commands sent
      obj.statistics.acknowledged       = 0;              % Number of acknowledgments received
      obj.statistics.retried            = 0;              % Number of commands retried
      obj.statistics.unreplied          = 0;              % Number of commands sent but no reply received
      obj.statistics.failed             = 0;              % Number of commands sent but a failure notification received
      obj.statistics.received           = 0;              % Number of transmissions received
      obj.statistics.refused            = 0;              % Number of transmissions received but not processed because they are from an unknown sender
      obj.statistics.malformed          = 0;              % Number of transmissions received that don't have the correct format
      obj.statistics.truncated          = 0;              % Number of transmissions received that look to be truncated
      
      obj.figStats                      = [];
      obj.hStats                        = [];
    
      % Reserved command IDs -- be careful to avoid using some types of
      % member functions from the constructor as this has caused some
      % strange un-debuggable crash
      for iID = 1:numel(IPPager.ID_SYSTEM)
        obj.encoding(end+1)             = IPPager.makeEncoding( IPPager.ID_SYSTEM{iID}  ...
                                                              , obj.default.encoding    ...
                                                              , IPPager.DATA_FCN        ...
                                                              );
        obj.encodeIDMap(IPPager.ID_SYSTEM{iID}) = numel(obj.encoding);
      end

      % Register system functions (somehow findEncoding can be used)
      obj.encoding(obj.findEncoding(IPPager.ID_TALKTOME)).command{end+1}  = @obj.twoWayRequestCallback;
      
    end
    
    %----- Destructor
    function delete(obj)

      if ~isempty(obj.pacemaker)
        stop(obj.pacemaker);
        delete(obj.pacemaker);
      end
      
      for iSocket = 1:numel(obj.socket)
        obj.socket{iSocket}.close();
      end
        
      for iChannel = 1:numel(obj.channel)
        for iCmd = 1:numel(obj.channel(iChannel).command)
          if      ~isempty(obj.channel(iChannel).command{iCmd})       ...
              &&  ~isempty(obj.channel(iChannel).command{iCmd}.timer)
            stop(obj.channel(iChannel).command{iCmd}.timer);
            delete(obj.channel(iChannel).command{iCmd}.timer);
          end
        end
      end
      
      if ~isempty(obj.figStats)
        delete(obj.figStats);
      end
      
    end
    
    
    %----- Setup a timer to execute the heartbeat function regularly
    function startHeartbeat(obj, pulseInterval, doShowStatistics)
      
      if isempty(obj.pacemaker)
        obj.pacemaker   = timer ( 'BusyMode'      , 'queue'                 ...
                                , 'ExecutionMode' , 'fixedRate'             ...
                                , 'StartDelay'    , pulseInterval           ...
                                , 'Period'        , pulseInterval           ...
                                , 'TimerFcn'      , @obj.heartbeat          ...
                                );
      else
        set(obj.pacemaker       , 'StartDelay'    , pulseInterval           ...
                                , 'Period'        , pulseInterval           ...
                                );
      end

      if nargin < 3 || doShowStatistics
        set(obj.pacemaker, 'StartFcn', @obj.showStatistics);
      else
        set(obj.pacemaker, 'StartFcn', '');
      end

      start(obj.pacemaker);
      
    end
    
    %----- Stop the timer that executes the heartbeat function
    function stopHeartbeat(obj)
      if ~isempty(obj.pacemaker)
        stop(obj.pacemaker);
      end
    end
    
    
    %----- Finds the index of a registered communications channel
    function index = findChannel(obj, hostName)
      
      for index = 2:numel(obj.channel)
        if strcmp(obj.channel(index).host, hostName)
          return;
        end
      end
      
      % First channel is reserved for unidentified sources
      index   = 1;
      
    end
    
    %----- Finds the index of a registered data encoding format
    function index = findEncoding(obj, id, enforcePresence, enforceValidity)

      % ID must be in the allowed range
      if id < 1 || id > IPPager.MAX_INDEX
        if nargin < 4 || enforceValidity
          error('findEncoding:invalidID', 'Encoding ID (value = %d) must be in the allowed range 1-%d.', id, IPPager.MAX_INDEX);
        else
          index   = [];
          return;
        end
      end

      index       = obj.encodeIDMap(id);
      if index > 0
        return;
      end
      
      if nargin > 2 && enforcePresence
        error('findEncoding:noSuchID', 'Encoding ID "%s" does not exist.', id);
      end
      index       = [];
      
    end
    
    %----- Adds a communications channel, or returns the index if already registered
    function [index, exists] = addChannel(obj, hostName, twoWayComms, varargin)
      
      index                       = obj.findChannel(hostName);
      if index < 2
        exists                    = false;
        obj.channel(end+1)        = obj.default.channel;
        obj.channel(end).host     = hostName;
        index                     = numel(obj.channel);
        
        % Create address objects for all configured ports
        host                      = java.net.InetAddress.getByName(hostName);
        for iPort = 1:numel(obj.channel(end).address)
          obj.channel(end).address{iPort}   = java.net.InetSocketAddress(host, IPPager.PORT(iPort));
        end
        

        if nargin < 3 || twoWayComms
          obj.requestTwoWayComms(index, varargin{:});
        end
      else
        exists                    = true;
      end
      
    end
    
    %----- Sends a request through the given channel to set up two-way
    %      communications, i.e. the other IPPager should add this one to
    %      its channel list; success/failure callbacks can be specified
    function requestTwoWayComms(obj, iChannel, successFcn, failureFcn, retryFcn)
      
      if nargin > 2
        success   = {@obj.setTwoWayCallback, successFcn};
      else
        success   = @obj.setTwoWayCallback;
      end
      if nargin > 3
        failure   = failureFcn;
      else
        failure   = @IPPager.doNothingCallback;
      end
      if nargin < 5
        retryFcn  = {};
      end
      
      obj.command ( iChannel                      ...
                  , success                       ...
                  , failure                       ...
                  , retryFcn                      ...
                  , IPPager.ID_TALKTOME           ...
                  , IPPager.MAGIC_WORD            ...
                  );
      
    end
    
    %----- Returns the data encoding format by ID
    function encoding = getEncoding(obj, id)
      encoding  = obj.encoding(obj.findEncoding(id, true));
    end
    
    %----- Adds a data encoding format
    function addEncoding(obj, id, varargin)
    
      if ~isempty(obj.findEncoding(id))
        if findfirst(IPPager.ID_RESERVED, id, @isequal) > 0
          error('addEncoding:reservedID', 'Encoding ID "%s" is reserved for system use.', id);
        end
        error('addEncoding:repeatedID', 'Encoding ID "%s" already exists.', id);
      end
      
      obj.encoding(end+1) = IPPager.makeEncoding(id, obj.default.encoding, varargin{:});
      obj.encodeIDMap(id) = numel(obj.encoding);
      
    end

    %----- Adds a message specifiers with no associated data items
    function addEncodes(obj, varargin)

      for iArg = 1:numel(varargin)
        if ~isempty(obj.findEncoding(varargin{iArg}))
          if findfirst(IPPager.ID_RESERVED, id, @isequal) > 0
            error('addEncodes:reservedID', 'Encoding ID "%s" is reserved for system use.', id);
          end
          error('addEncodes:repeatedID', 'Encoding ID "%s" already exists.', varargin{iArg});
        end
      
        obj.encoding(end+1)             = IPPager.makeEncoding(varargin{iArg}, obj.default.encoding);
        obj.encodeIDMap(varargin{iArg}) = numel(obj.encoding);
      end
      
    end
    
    %----- Adds a broadcast receiver callback
    function addBroadcastReceiver(obj, encodingID, receiver)
      iEncode       = obj.findEncoding(encodingID, true);
      obj.encoding(iEncode).broadcast{end+1}  = receiver;
    end
    
    %----- Adds a command receiver callback
    function addCommandReceiver(obj, encodingID, receiver)
      iEncode       = obj.findEncoding(encodingID, true);
      obj.encoding(iEncode).command{end+1}    = receiver;
    end
    
    %----- Clears ALL broadcast receiver callbacks
    function clearBroadcastReceivers(obj)
      for iEncode = 1:numel(obj.encoding)
        obj.encoding(iEncode).broadcast = {};
      end
    end
    
    %----- Clears ALL command receiver callbacks
    function clearCommandReceivers(obj)
      for iEncode = 1:numel(obj.encoding)
        obj.encoding(iEncode).command   = {};
      end
    end
    
    %----- Shortcut to clear all receiver callbacks
    function clearReceivers(obj)
      obj.clearBroadcastReceivers();
      obj.clearCommandReceivers();
    end
    
    %----- Decode a message assuming that the appropriate format has been configured
    function info = decode(obj, packet, info, iPort)
      % Encoded packets comprise of a header followed by data bytes. Packets
      % have the following format, where | separates bytes:
      %
      %     |method|(etc)|id|length|...(data)...|
      %
      % method  : character denoting the type of transmission.
      % (etc)   : for methods other than broadcast, this consists of two
      %           bytes denoting the command and retry counts.
      % id      : user-configured character identifying the encoding format.
      % length  : one or more bytes denoting the length of data arrays; the
      %           format of this is dependent on whether the encoding is a
      %           simple array or a struct.
      
      if nargin < 3
        info          = struct();
      end
      info.iEncode    = [];
      info.numBytes   = nan;
      info.message    = [];
      
      % Minimum length of packet accounting for header
      if numel(packet) < 2
        obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Packet is too short to contain a proper header: %s', num2str(packet));
        return;
      end
      
      % Check header for sanity
      info.method     = packet(1);
      if findfirst(IPPager.PRE_FIXEDLENGTH, info.method, @isequal) > 0
        % Special case for fixed-length system messages
        info.iEncode  = 0;
        info.encoding = packet(1);
        info.message  = packet(2:end);
        return;
      elseif isequal(info.method, IPPager.PRE_BROADCAST)
        iStart        = 2;
      elseif findfirst(IPPager.ID_RESERVED, info.method, @isequal) < 1
        obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Invalid transmission method for data: %s', num2str(packet));
        return;
      elseif numel(packet) < 4
        obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Packet is too short to contain a non-broadcast header: %s', num2str(packet));
        return;
      else
        info.command  = packet(2);
        info.retries  = packet(3);
        iStart        = 4;
      end
      
      % Decode data according to encoding format
      info.encoding   = packet(iStart);
      iEncode         = obj.findEncoding(info.encoding, false, false);
      if isempty(iEncode)
          obj.report(iPort, 'malformed', 'decode:invalidEncoding', 'Invalid encoding "%s" for packet: %s', info.encoding, num2str(packet));
        return;
      end
      encoding        = obj.encoding(iEncode);
      iStart          = iStart + 1;

      %-------------------------------------------------------------------------
      % Structure
      if ~isempty(encoding.struct)
        if numel(packet) < iStart
          obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Packet is too short to contain a proper struct header: %s', num2str(packet));
          return;
        end
        
        % Obtain lengths of data arrays and perform sanity checks
        iHeader       = findfirst(packet, IPPager.MSG_STOP, @eq, iStart:numel(packet));
        info.message  = encoding.struct;
        if iHeader < iStart + 2
          keyboard
          obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Invalid header for data: %s', num2str(packet));
          return;
        end
        numItems      = int64(packet(iStart:iHeader-1));
        if numel(numItems) ~= numel(encoding.fields)
          obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Wrong length %d of header for "%s" encoded data: %s', numel(numItems), encoding.id, num2str(packet));
          return;
        end
        
        % Check for data truncation e.g. if input buffer is too small
        info.numBytes = sum(numItems) + iHeader;
        if info.numBytes ~= numel(packet)
          obj.report(iPort, 'truncated', 'decode:wrongPacketSize', 'Wrong length %d (should be %d) for packet, may have been truncated.', numel(packet), info.numBytes);
          return;
        end
        
        % Typecast pieces of the packet into the expected fields
        iStart        = iHeader + 1;
        for iField = 1:numel(encoding.fields)
          info.message.(encoding.fields{iField})  ...
                      = typecast( IPPager.DATA_FCN(packet(iStart:iStart + numItems(iField) - 1))  ...
                                , encoding.formatStr{iField}                                      ...
                                );
          iStart      = iStart + numItems(iField);
        end
        
      %-------------------------------------------------------------------------
      % Simple array
      elseif ~isempty(encoding.formatFcn)
        if numel(packet) < iStart
          obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Packet is too short to contain a proper array header: %s', num2str(packet));
          return;
        end
        
        % Check for data truncation e.g. if input buffer is too small
        info.numBytes = int64(packet(iStart)) + iStart;
        if info.numBytes ~= numel(packet)
          obj.report(iPort, 'truncated', 'decode:wrongPacketSize', 'Wrong length %d (should be %d) for packet, may have been truncated.', numel(packet), info.numBytes);
          return;
        end
        
        info.message  = typecast(IPPager.DATA_FCN(packet(iStart+1:end)), encoding.formatStr);
        
      %-------------------------------------------------------------------------
      % ID only
      else
        if numel(packet) >= iStart
          obj.report(iPort, 'malformed', 'decode:invalidPacket', 'Packet is too long for an ID only transmission: %s', num2str(packet));
          return;
        end
        
        info.message  = [];
      end

      % Flag successful decoding
      info.iEncode    = iEncode;
      
    end
    

    %----- Message broadcasting without reception confirmation
    function numBytes = broadcast(obj, channels, encodingID, varargin)
      
      if isempty(channels)
        channels        = 2:numel(obj.channel);
      end
      
      % Throttling: make sure that a minimum amount of time has elapsed
      % since the last broadcast
      mask              = true(size(channels));
      for iChannel = 1:numel(channels)
        mask(iChannel)  = ( toc(obj.channel(channels(iChannel)).lastBroadcast)  ...
                          >     obj.channel(channels(iChannel)).throttle        ...
                          );
      end
      
      iEncode           = obj.findEncoding(encodingID, true);
      packet            = obj.encode(obj.encoding(iEncode), IPPager.PRE_BROADCAST, varargin{:});
      numBytes          = obj.transmit(channels, packet, 'broadcasts', mask);
      obj.channel(channels(mask)).lastBroadcast   = tic;
      
    end    
    
    %----- Command transmission with retries and acknowledgment waiting; a
    %      null retryFcn defaults to retrying until RigControl.MAX_RETRIES 
    function numBytes = command(obj, channels, successFcn, failureFcn, retryFcn, encodingID, varargin)

      % Argument shortcuts
      if isempty(channels)
        channels  = 2:numel(obj.channel);
      end
      if isempty(retryFcn)
        retryFcn            = @IPPager.retryUntilMaxTimes;
      end
      
      % Book a command index
      obj.cmdIndex          = IPPager.increment(obj.cmdIndex, IPPager.DATA_FCN(1), IPPager.MAX_INDEX);
      
      % Store command information structure
      command               = obj.default.command;
      command.info.encoding = IPPager.DATA_FCN(encodingID);
      command.info.command  = obj.cmdIndex;
      command.successFcn    = successFcn;
      command.failureFcn    = failureFcn;
      command.retryFcn      = retryFcn;
      
      % Encode command packet
      command.info.iEncode  = obj.findEncoding(encodingID, true);
      packet                = obj.encode(obj.encoding(command.info.iEncode), [IPPager.PRE_COMMAND obj.cmdIndex 0], varargin{:});

      % Register commands sent to various channels
      for iChannel = channels
        obj.channel(iChannel).command{obj.cmdIndex}               = command;
        obj.channel(iChannel).command{obj.cmdIndex}.info.channel  = iChannel;
        obj.channel(iChannel).command{obj.cmdIndex}.packet        = packet;
        obj.channel(iChannel).command{obj.cmdIndex}.timer                       ...
                            = timer ( 'BusyMode'      , 'queue'                 ...
                                    , 'ExecutionMode' , 'fixedSpacing'          ...
                                    , 'StartDelay'    , IPPager.RETRY_INTERVAL  ...
                                    , 'Period'        , IPPager.RETRY_INTERVAL  ...
                                    , 'TasksToExecute', inf                     ...
                                    , 'TimerFcn'      , @obj.retryCommand       ...
                                    , 'UserData'      , [iChannel,obj.cmdIndex] ...
                                    );
        start(obj.channel(iChannel).command{obj.cmdIndex}.timer);
      end

      
      % Transmit command to all requested channels
      numBytes              = obj.transmit(channels, packet, 'commands', [], true);
      

      % IMPORTANT:
      %   Code after obj.transmit() is unsafe because reception of an
      %   acknowledgment can interrupt the execution of the rest of this
      %   function (via datagram reception callback), in which case the
      %   values of variables seen here are stale
      
    end
    
    %----- Function to be called regularly to check for and dispatch
    %      incoming communications
    function heartbeat(obj, varargin)
      
      try 
        
      obj.pingChannels();
      obj.receiveTransmission();
      
      if ~isempty(obj.figStats)
        obj.drawStatistics();
      end
      
      catch err
        displayException(err);
      end
      
    end

    %----- Create statistics display
    function showStatistics(obj, varargin)

      % If creating a new figure, figure out where it should go
      if isempty(obj.figStats)
        oldFig                = [];
        
        % Obtain screen configuration
        screenSize            = get(0, 'Monitor');
        if size(screenSize,1) < 2
          % HACK to side-step Matlab bugs in monitor position retrieval
          screenSize          = get(0, 'ScreenSize');
        elseif IPPager.STATS_MONITOR < 0
          screenSize          = screenSize(size(screenSize,1) + 1 + IPPager.STATS_MONITOR, :);
        else
          screenSize          = screenSize(IPPager.STATS_MONITOR, :);
        end
        
        figPos                = IPPager.STATS_POS;
        for iCoord = 1:2
          if figPos(iCoord) < 0
            figPos(iCoord)    = figPos(iCoord) + screenSize(2 + iCoord);
          end
          figPos(iCoord)      = figPos(iCoord) + screenSize(iCoord);
        end

      % If a figure already exists, recreate it at the same location
      else
        % Set the figure handle to null first so that the timer function
        % does not crash upon trying to use deleted objects
        oldFig                = obj.figStats;
        obj.figStats          = [];
        set(oldFig, 'Visible', 'off');
        
        figPos                = get(oldFig, 'OuterPosition');
      end
      
      
      % Set up a figure in the configured location
      fig                     = figure( 'OuterPosition'     , figPos                      ...
                                      , 'Name'              , 'IPPager'                   ...
                                      , 'NumberTitle'       , 'off'                       ...
                                      , 'MenuBar'           , 'none'                      ...
                                      , 'Color'             , IPPager.GUI_COLOR           ...
                                      , 'CloseRequestFcn'   , @obj.closeStatistics        ...
                                      );
                                    

      % Set up objects for statistics display
      obj.hStats              = struct();
      categories              = fieldnames(obj.statistics);
      
      obj.hStats.lstConn      = uicontrol ( 'Parent'          , fig                       ...
                                          , 'Style'           , 'popupmenu'               ...
                                          , 'Units'           , 'normalized'              ...
                                          , 'Position'        , [0.05 0.77 0.65 0.08]     ...
                                          , 'String'          , {'(no connections)'}      ...
                                          , 'FontSize'        , IPPager.STATS_FONT        ...
                                          , 'BackgroundColor' , IPPager.GUI_COLOR         ...
                                          );
      obj.hStats.axsStats     = axes( 'Parent'          , fig                             ...
                                    , 'Units'           , 'normalized'                    ...
                                    , 'Position'        , [0.4 0.07 0.55 0.65]            ...
                                    , 'YTick'           , 1:numel(categories)             ...
                                    , 'YTickLabel'      , categories                      ...
                                    , 'YLim'            , 0.5 + [0 numel(categories)]     ...
                                    , 'YDir'            , 'reverse'                       ...
                                    , 'XTick'           , []                              ...
                                    , 'XLim'            , [0 20]                          ...
                                    , 'FontSize'        , IPPager.STATS_FONT - 1          ...
                                    );
      xlabel(obj.hStats.axsStats, 'N. packets', 'FontSize', IPPager.STATS_FONT);
      
      for iStat = 1:numel(categories)
        count                             = obj.statistics.(categories{iStat});
        obj.hStats.patStat(iStat)         = patch ( 'Parent'    , obj.hStats.axsStats     ...
                                                  , 'XData'     , [0 0 count count]       ...
                                                  , 'YData'     , iStat + [-0.4 0.4 0.4 -0.4]             ...
                                                  , 'FaceColor' , IPPager.STATS_COLOR.(categories{iStat}) ...
                                                  , 'LineWidth' , 2                       ...
                                                  , 'EdgeColor' , 'none'                  ...
                                                  );
        obj.hStats.txtStat(iStat)         = text( 0, iStat                                ...
                                                , sprintf(' %g', count)                   ...
                                                , 'Parent'        , obj.hStats.axsStats   ...
                                                , 'FontSize'      , IPPager.STATS_FONT-2  ...
                                                , 'FontWeight'    , 'bold'                ...
                                                , 'Color'         , IPPager.GUI_COLOR     ...
                                                );
      end

      
      % Set up objects for heartbeat indicator
      if isempty(obj.pacemaker)
        pulseInterval         = 0.1;
      else
        pulseInterval         = get(obj.pacemaker,'Period');
      end
      obj.hStats.axsPulse     = axes( 'Parent'          , fig                             ...
                                    , 'Units'           , 'normalized'                    ...
                                    , 'Position'        , [0.75 0.72 0.2 0.14]            ...
                                    , 'YTick'           , []                              ...
                                    , 'XTick'           , []                              ...
                                    , 'YLim'            , [-1.5 2]                        ...
                                    , 'XLim'            , [-2 2]                          ...
                                    , 'XColor'          , IPPager.GUI_COLOR               ...
                                    , 'YColor'          , IPPager.GUI_COLOR               ...
                                    , 'Box'             , 'off'                           ...
                                    );
                                line( 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'XData'           , 1.2 * cos(0:0.05:pi)            ...
                                    , 'YData'           , 1.2 * sin(0:0.05:pi)            ...
                                    , 'LineWidth'       , 1                               ...
                                    , 'Color'           , IPPager.ANNOT_COLOR             ...
                                    );
                                text( -1.4, 0                                             ...
                                    , sprintf('%.3gms', 1000*IPPager.MIN_THROTTLE)        ...
                                    , 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'FontSize'        , IPPager.STATS_FONT-4            ...
                                    , 'FontWeight'      , 'bold'                          ...
                                    , 'Color'           , IPPager.ANNOT_COLOR             ...
                                    , 'Rotation'        , 90                              ...
                                    , 'HorizontalAlignment' , 'left'                      ...
                                    , 'VerticalAlignment'   , 'bottom'                    ...
                                    );
                                text( 1.4, 0                                              ...
                                    , sprintf('%.3gs', IPPager.MAX_THROTTLE)              ...
                                    , 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'FontSize'        , IPPager.STATS_FONT-4            ...
                                    , 'FontWeight'      , 'bold'                          ...
                                    , 'Color'           , IPPager.ANNOT_COLOR             ...
                                    , 'Rotation'        , -90                             ...
                                    , 'HorizontalAlignment' , 'right'                      ...
                                    , 'VerticalAlignment'   , 'bottom'                    ...
                                    );
                                line( 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'XData'           , [-2 2]                          ...
                                    , 'YData'           , [-0.5 -0.5]                     ...
                                    , 'LineWidth'       , 2                               ...
                                    , 'Color'           , IPPager.ANNOT_COLOR * 1.2       ...
                                    );
                                text( -2, -0.7                                            ...
                                    , sprintf('%.3gms', 1000*IPPager.RTT_RANGE(1))        ...
                                    , 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'FontSize'        , IPPager.STATS_FONT-4            ...
                                    , 'FontWeight'      , 'bold'                          ...
                                    , 'Color'           , IPPager.ANNOT_COLOR             ...
                                    , 'HorizontalAlignment' , 'left'                      ...
                                    , 'VerticalAlignment'   , 'top'                       ...
                                    );
                                text( 2, -0.7                                             ...
                                    , sprintf('%.3gs', IPPager.RTT_RANGE(2))              ...
                                    , 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'FontSize'        , IPPager.STATS_FONT-4            ...
                                    , 'FontWeight'      , 'bold'                          ...
                                    , 'Color'           , IPPager.ANNOT_COLOR             ...
                                    , 'HorizontalAlignment' , 'right'                     ...
                                    , 'VerticalAlignment'   , 'top'                       ...
                                    );
      obj.hStats.linPulse     = line( 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'XData'           , [0 0 nan]                       ...
                                    , 'YData'           , [0 1 nan]                       ...
                                    , 'LineWidth'       , 1.5                             ...
                                    , 'Color'           , [0 0 0]                         ...
                                    );
      obj.hStats.linRTT       = line( 'Parent'          , obj.hStats.axsPulse             ...
                                    , 'XData'           , 2                               ...
                                    , 'YData'           , -0.5                            ...
                                    , 'LineStyle'       , 'none'                          ...
                                    , 'Marker'          , 's'                             ...
                                    , 'MarkerSize'      , 4                               ...
                                    , 'Color'           , [1 0 0]                         ...
                                    , 'MarkerFaceColor' , [1 0 0]                         ...
                                    );

                                  
      % Set up objects for activity indicator
      activityPos             = [0.04 0.88 0.92 0.1];
      aspectRatio             = ( figPos(3)*activityPos(3) ) / ( figPos(4)*activityPos(4) );
      nCols                   = floor( sqrt(aspectRatio * numel(IPPager.PORT)) );
      nRows                   = ceil( numel(IPPager.PORT) / nCols );
      obj.hStats.axsAct       = axes( 'Parent'          , fig                             ...
                                    , 'Units'           , 'normalized'                    ...
                                    , 'Position'        , activityPos                     ...
                                    , 'YTick'           , []                              ...
                                    , 'XTick'           , []                              ...
                                    , 'YLim'            , [0.5 0.5+nRows]                 ...
                                    , 'XLim'            , [0.5 0.5+nCols]                 ...
                                    , 'YDir'            , 'reverse'                       ...
                                    , 'XColor'          , IPPager.GUI_COLOR               ...
                                    , 'YColor'          , IPPager.GUI_COLOR               ...
                                    , 'Box'             , 'off'                           ...
                                    );
                                  
      obj.hStats.rctPort      = zeros(size(IPPager.PORT));
      obj.hStats.ticPort      = zeros(2, 0, 'uint64');
      col                     = 1;
      row                     = 1;
      for iPort = 1:numel(IPPager.PORT)
        obj.hStats.rctPort(iPort) = patch ( 'Parent'    , obj.hStats.axsAct               ...
                                          , 'XData'     , col + [-1 -1 1  1] * 0.4        ...
                                          , 'YData'     , row + [-1  1 1 -1] * 0.4        ...
                                          , 'FaceColor' , IPPager.STATS_COLOR.inactive    ...
                                          , 'EdgeColor' , 'none'                          ...
                                          );
        col                   = col + 1;
        if col > nCols
          col                 = 1;
          row                 = row + 1;
        end
      end
      
      % Delete the old figure and set the new one
      if ~isempty(oldFig)
        delete(oldFig);
      end
      obj.figStats            = fig;

    end
    
  end
  
  
  %_____________________________________________________________________________
  methods (Access = protected)
    
    %----- Callback to close statistics display
    function closeStatistics(obj, varargin)
      
      if ~isempty(obj.figStats)
        delete(obj.figStats);
        obj.figStats  = [];
        obj.hStats    = [];
      end
      
    end
    
    %----- Update statistics display
    function drawStatistics(obj)
      
      try 
        
      % Update list of channels
      if numobj(get(obj.hStats.lstConn, 'String')) ~= numel(obj.channel)
        connections     = cell(size(obj.channel));
        connections{1}  = sprintf('%d channel(s) ...', numel(obj.channel) - 1);
        for iChannel = 2:numel(obj.channel)
          connections{iChannel}   ...
                        = IPPager.getHostName(obj.channel(iChannel).address{1});
        end
        
        set(obj.hStats.lstConn, 'String', connections);
        set(obj.hStats.linRTT , 'YData' , -0.5*ones(1,numel(obj.channel)));
      end

      % Update packet counts
      categories        = fieldnames(obj.statistics);
      maxCount          = 0;
      for iStat = 1:numel(categories)
        count           = obj.statistics.(categories{iStat});
        if iStat > 3
          maxCount      = max(maxCount, count);
        end
        
        set ( obj.hStats.patStat(iStat)           ...
            , 'XData'     , [0;0;count;count]     ...
            );
        set ( obj.hStats.txtStat(iStat)           ...
            , 'String'    , sprintf(' %g', count) ...
            );
      end
      
      % Extend axis range to fit counts (other than broadcasts which can be too many)
      countLim        = get(obj.hStats.axsStats, 'XLim');
      if maxCount > countLim(2)
        countLim(2)   = ceil(maxCount * 1.5);
        set(obj.hStats.axsStats, 'XLim', countLim);
      end

      
      % Rotate indicator according to speed throttles, and pulse its color
      pulseX              = nan(3, numel(obj.channel));
      pulseY              = nan(3, numel(obj.channel));
      pulseX(1,:)         = 0;
      pulseY(1,:)         = 0;
      rttX                = nan(1, numel(obj.channel));
      for iChannel = 2:numel(obj.channel)
        pulseAng          = ( obj.channel(iChannel).throttle - IPPager.MIN_THROTTLE ) ...
                          / ( IPPager.MAX_THROTTLE           - IPPager.MIN_THROTTLE ) ...
                          * pi                                                        ...
                          ;
%         pulseAng          = max(min(pulseAng, pi), 0);
        pulseX(2,iChannel-1)  = sin(pulseAng);
        pulseY(2,iChannel-1)  = cos(pulseAng);
        
        rttX(iChannel-1)  = ( obj.channel(iChannel).rtt - IPPager.RTT_RANGE(1) )      ...
                          / ( IPPager.RTT_RANGE(2)      - IPPager.RTT_RANGE(1) )      ...
                          * 4 - 2                                                     ...
                          ;
        rttX(iChannel-1)  = max(min(rttX(iChannel-1), 2), -2);
      end
      
      set ( obj.hStats.linPulse                   ...
          , 'XData'       , pulseX(:)             ...
          , 'YData'       , pulseY(:)             ...
          );
      set ( obj.hStats.linRTT                     ...
          , 'XData'       , rttX                  ...
          );
        
        
      % Turn off activity indicators after the configured period
      for iPort = size(obj.hStats.ticPort,2):-1:1
        if toc(obj.hStats.ticPort(2,iPort)) > IPPager.STATS_FADE
          set(obj.hStats.rctPort(obj.hStats.ticPort(1,iPort)), 'FaceColor', IPPager.STATS_COLOR.inactive);
          obj.hStats.ticPort(:,iPort) = [];
        end
      end
      
      catch err
        displayException(err);
        keyboard;
      end
      
    end
    

    %----- Callback to handle a two-way communications request
    function twoWayRequestCallback(obj, pager, event)
      
      if strcmp(IPPager.toString(event.message), IPPager.MAGIC_WORD)
        iChannel  = obj.addChannel(IPPager.getHostName(event.from), false);
        obj.channel(iChannel).isTwoWay    = true;
      end
      
    end
    %----- Callback when a given channel has established two-way communications 
    function setTwoWayCallback(obj, pager, event, callback)
      
      obj.channel(event.channel).isTwoWay = true;
      if nargin > 3
        IPPager.execute(callback, pager, event);
      end
      
    end
    
    
    %----- Send pings to all registered channels
    function pingChannels(obj)
      
      packet        =  [IPPager.PRE_PING 0];
      for iChannel = 2:numel(obj.channel)
        % Ping at specific intervals
        if    toc(obj.channel(iChannel).pinged(obj.channel(iChannel).pingIndex))  ...
            < IPPager.PING_INTERVAL
          continue;
        end
        
        % Send the next ping from this channel
        pingIndex   = IPPager.increment ( obj.channel(iChannel).pingIndex   ...
                                        , 1, IPPager.NUM_INDEX              ...
                                        );
        packet(end) = IPPager.index2byte(pingIndex);
        numBytes    = obj.transmit(iChannel, packet, '', true);

        % Register it only if successful
        if numBytes > 0
          obj.channel(iChannel).pingIndex   = pingIndex;
          obj.channel(iChannel).pinged(obj.channel(iChannel).pingIndex)     ...
                    = tic;
        end
      end
      
    end
    
    %----- Upon reception of a ping, send an acknowledgment
    function receivePing(obj, event)
      % pings sent to a given channel are identified by an index that for
      % bandwidth reasons is encoded as a single byte. This means that
      % after 256 pings, the next ping index will wrap around to 1, and we
      % need to deal with the ping/pong system assuming that all
      % information is stored in circular buffers.
      %
      % Acknowledgments to pings (a.k.a. pongs) are sent whenever a ping
      % is received, and consists of 3 bytes, the first one being the
      % received ping index, and the next being a bit field
      % specifying whether or not the previous 16 pings have been
      % acknowledged (for redundancy against packet losses; see
      % http://gafferongames.com/networking-for-game-programmers/reliability-and-flow-control/).
      % Any given ping therefore has 17 chances of being acknowledged
      % assuming that it has been received, the latest possible acknowledgment
      % occuring at 16T seconds (plus network lag) since it has been sent,
      % where T is the interval between pings. In order not to be
      % contaminated by old data in the ring buffers, we therefore consider
      % all pings older than 16T + leeway as lost.
      

      % Construct a history of past pongs
      iPing             = IPPager.byte2index(event.message);
      history           = false(8, IPPager.PONG_NBYTES);
      range             = IPPager.history(iPing, numel(history), IPPager.NUM_INDEX);
      
      for iPong = 1:numel(range)
        history(iPong)  = toc(obj.channel(event.channel).ponged(range(iPong))) < IPPager.PING_LEEWAY;
      end
      
      % Prepare a pong packet of the appropriate size
      packet            = zeros(1, 2 + IPPager.PONG_NBYTES, IPPager.DATA_STR);
      packet(1)         = IPPager.PRE_PONG;
      packet(2)         = event.message;
      for iByte = 1:IPPager.PONG_NBYTES
        packet(2+iByte) = IPPager.bits2byte(history(:, iByte));
      end
      
      % If transmission is successful, mark the received ping as ponged
      if obj.transmit(event.channel, packet, '', true) > 0
        obj.channel(event.channel).ponged(iPing)  = tic;
      end
      
    end
    
    %----- Upon receiving pongs, compute RTT and update throttling if necessary
    function receivePong(obj, event)
      
      % Get the list of acknowledged pings
      iPing             = IPPager.byte2index(event.message(1));
      history           = IPPager.byte2bits(event.message(2:end));
      range             = IPPager.history(iPing, numel(history), IPPager.NUM_INDEX);

      % Update the round-trip time for all acknowledged pings
      obj.updateRTT(event.channel, iPing);
      for iHist = 1:numel(history)
        if history(iHist)
          obj.updateRTT(event.channel, range(iHist));
        end
      end

    end
    
    %----- Update round-trip time for a given channel
    function updateRTT(obj, iChannel, iPing)
      rtt                         = toc(obj.channel(iChannel).pinged(iPing));
      if rtt > IPPager.PING_LEEWAY
        % Only consider acknowledgments within a valid time limit
      elseif isfinite(obj.channel(iChannel).rtt)
        obj.channel(iChannel).rtt =      IPPager.RTT_SMOOTHING * rtt    ...
                                  + (1 - IPPager.RTT_SMOOTHING)         ...
                                  * obj.channel(iChannel).rtt           ...
                                  ;
      else
        obj.channel(iChannel).rtt = rtt;
      end
    end
    
    
    %----- Set activity indicator for given sockets
    function indicateActivity(obj, sockIndex, type)
      if ~isempty(obj.figStats)
        set(obj.hStats.rctPort(sockIndex), 'FaceColor', IPPager.STATS_COLOR.(type));
        
        range                       = size(obj.hStats.ticPort,2) + ( 1:numel(sockIndex) );
        obj.hStats.ticPort(1,range) = sockIndex;
        obj.hStats.ticPort(2,range) = tic;
      end
    end
    
    %----- Write to all specified channels
    function numBytes = transmit(obj, channels, packet, type, mask, verbose)

      % Input check and default arguments
      if numel(packet) > IPPager.MAX_PACKET_SIZE
        obj.report([], 'tooLong', 'transmit:packetTooLong', 'Packet (%d bytes) is too long to transmit; consider increasing IPPager.MAX_PACKET_SIZE.', numel(packet));
        return;
      end
      if isempty(channels)
        channels      = 2:numel(obj.channel);
      end
      if nargin < 5 || isempty(mask)
        mask          = true(size(channels));
      end
      if nargin < 6
        verbose       = false;
      end
      

      % Cycle to the next transmission port
      obj.sockIndex   = obj.sockIndex + 1;
      if obj.sockIndex > numel(obj.socket)
        obj.sockIndex = 1;
      end
      if ~isempty(type)
        obj.report(obj.sockIndex, type);
      end

      % Setup buffer to transmit
      buffer          = java.nio.ByteBuffer.wrap(packet);
      numBytes        = zeros(size(channels));
      
      % If a channel index is provided, use the configured channels
      if isnumeric(channels)
        for iChannel = 1:numel(channels)
          if ~mask(iChannel)
            continue;
          end
          
          address             = obj.channel(channels(iChannel)).address{obj.sockIndex};
          numBytes(iChannel)  = obj.socket{obj.sockIndex}.send(buffer, address);
          buffer.rewind();
          
          if verbose
            fprintf ( '   #%d ( %15s:%-5d )  <--  %4d byte(s)\n'    ...
                    , iChannel                                      ...
                    , IPPager.getHostName(address)                  ...
                    , address.getPort()                             ...
                    , numBytes(end)                                 ...
                    );
          end
        end
        
      % If a specific internet address is provided, use it
      else
        for iChannel = 1:numel(channels)
          if ~mask(iChannel)
            continue;
          end
          
          numBytes(iChannel)  = obj.socket{obj.sockIndex}.send(buffer, channels(iChannel));
          buffer.rewind();
          
          if verbose
            fprintf ( '      ( %15s:%-5d )  <--  %4d byte(s)\n'     ...
                    , IPPager.getHostName(channels(iChannel))       ...
                    , channels(iChannel).getPort()                  ...
                    , numBytes(end)                                 ...
                    );
          end
        end
      end
      
    end
    
    %----- Retry a command if no acknowledgment is received
    function retryCommand(obj, timer, event)
      
      % If the number of retries has been exceeded, report a failure
      index           = get(timer, 'UserData');
      command         = obj.channel(index(1)).command{index(2)};
      if ~IPPager.evaluate(command.retryFcn, obj, command.info)
        obj.report([], 'unreplied');
        obj.acknowledgeCommand(command.info, 'failureFcn');
        return;
      end
      
      % Increment number of retries and adjust the command packet 
      packet          = command.packet;
      packet(3)       = command.info.retries;
      obj.channel(index(1)).command{index(2)}.info.retries  ...
                      = command.info.retries + 1;
      
      % Re-transmit command 
      obj.transmit(index(1), packet, 'retried', [], true);
      
    end
    
    %----- Handles received packets according to the messaging mode and encoding 
    function receiveTransmission(obj)

      for iPort = 1:numel(obj.socket)
      
        % Read a UDP packet, if available
        info.from                   = obj.socket{iPort}.receive(obj.buffer);
        if isempty(info.from)
          continue;
        end
        obj.report(iPort, 'received');

        packet                      = obj.buffer.array();
        packet                      = packet(1:obj.buffer.position());
        obj.buffer.clear();

        % Some event information to be passed to the receivers
        info.channel                = obj.findChannel(IPPager.getHostName(info.from));

        % Decode packet and check that it is valid
        info                        = obj.decode(packet, info, iPort);
        if isempty(info.iEncode)
          fprintf('  ??%d??  [%s]\n', iPort, num2str(packet));
          continue;
        end
        if    ~isequal(info.method, IPPager.PRE_PING)         ...
          &&  ~isequal(info.method, IPPager.PRE_PONG)         ...
          &&  ~isequal(info.method, IPPager.PRE_BROADCAST)
          IPPager.printPacket(info);
        end

        % The only transmissions allowed from unknown senders is a request
        % for bilateral communications
        if      info.channel > 1                              ...
            ||  isequal(info.encoding, IPPager.ID_TALKTOME)   ...
            ||  isequal(info.method, IPPager.PRE_RECEIPT)
          obj.dispatchTransmission(info, iPort);
        else
          obj.report(iPort, 'refused');
        end
        
      end
      
    end
    
    %----- Handles received packets according to the messaging mode and encoding 
    function dispatchTransmission(obj, info, iPort)
      
      switch info.method
        %-----------------------------------------------------------------------
        % Received a ping
        case IPPager.PRE_PING
          obj.receivePing(info);
        
        %-----------------------------------------------------------------------
        % Received a pong
        case IPPager.PRE_PONG
          obj.receivePong(info);
          
        %-----------------------------------------------------------------------
        % Received a broadcast
        case IPPager.PRE_BROADCAST

          % Propagate message to all reception callbacks
          for iCast = 1:numel(obj.encoding(info.iEncode).broadcast)
            IPPager.execute(obj.encoding(info.iEncode).broadcast{iCast}, obj, info);
          end
          
        %-----------------------------------------------------------------------
        % Received a command
        case IPPager.PRE_COMMAND
          
          % Reception packet
          info.acknowledgment     = [info.command info.retries IPPager.ID_VERIFY 1 info.encoding];
          info.dispatched         = false;
          prevCommand             = obj.channel(info.channel).dispatch{info.command};
          
          % If there is an old pending dispatch in the slot, send a failure
          % message to the sender
          if IPPager.isDifferentCommand(prevCommand, info, false)
            obj.transmit(prevCommand.from, [IPPager.PRE_FAILURE prevCommand.acknowledgment], 'failed', [], true);

          % Register the new command only if not already dispatched
          elseif isempty(prevCommand) || ~prevCommand.dispatched
            % Register command to be dispatched
            obj.channel(info.channel).dispatch{info.command}  = info;
            % Send a reply acknowledging the command
            obj.transmit(info.from, [IPPager.PRE_REPLY info.acknowledgment], 'acknowledged', [], true);
          end
          
          

        %-----------------------------------------------------------------------
        % Received an acknowledgment of a command
        case IPPager.PRE_REPLY

          if IPPager.isAcknowledgment(obj.channel(info.channel).command{info.command}.info, info.message)
            % Send a receipt to the acknowledger of the command
            obj.transmit(info.from, [IPPager.PRE_RECEIPT info.command info.retries IPPager.ID_VERIFY numel(info.message) info.message], 'acknowledged', [], true);

            % Forward success acknowledgment to all callbacks
            obj.acknowledgeCommand(info, 'successFcn');
          end
          
          
        %-----------------------------------------------------------------------
        % Received a receipt for a sent command acknowledgment
        case IPPager.PRE_RECEIPT

          % Only execute a command once
          command   = obj.channel(info.channel).dispatch{info.command};
          if ~isempty(command) && ~command.dispatched && IPPager.isAcknowledgment(command, info.message)
            
            % Issue command to all reception callbacks
            for iCast = 1:numel(obj.encoding(command.iEncode).command)
              IPPager.execute(obj.encoding(command.iEncode).command{iCast}, obj, command);
            end

            % Flag dispatch as executed
            obj.channel(info.channel).dispatch{info.command}.dispatched = true;
          end
          
          
        %-----------------------------------------------------------------------
        % Received a command reception failure
        case IPPager.PRE_FAILURE

          command   = obj.channel(info.channel).dispatch{info.command};
          if ~command.dispatched && IPPager.isSameCommand(command, info, true)
            
            % Forward failure acknowledgment to all callbacks
            obj.report(iPort, 'failed');
            obj.acknowledgeCommand(info, 'failureFcn');
            
            % Flag dispatch as executed
            obj.channel(info.channel).dispatch{info.command}.dispatched = true;
          end
          

        otherwise
          error('receiveTransmission:invalidMethod', 'Encountered invalid transmission method "%s".', method);
      end

    end

    %----- Record transmission counts and failures
    function report(obj, sockIndex, category, varargin)

      if ~isempty(sockIndex) && ~isempty(obj.figStats)
        obj.indicateActivity(sockIndex, category);
      end

      obj.statistics.(category) = obj.statistics.(category) + 1;
      if ~isempty(varargin)
        warning(varargin{:});
      end
      
    end
    
    %----- Sends command acknowledgment to all specified callbacks
    function acknowledgeCommand(obj, info, callback)
      
      if ~isempty(obj.channel(info.channel).command{info.command}.timer)
        % Turn off retry timer if it is still running
        stop(obj.channel(info.channel).command{info.command}.timer);
        delete(obj.channel(info.channel).command{info.command}.timer);
        obj.channel(info.channel).command{info.command}.timer = [];
      end
      
      % Execute callback
      IPPager.execute ( obj.channel(info.channel).command{info.command}.(callback)  ...
                      , obj                                                         ...
                      , obj.channel(info.channel).command{info.command}.info        ...
                      );
      
    end
    
    
    %----- Returns a float-encodable time stamp with precision to 1s and neglecting the year
    function stamp = timestamp(obj)
      
      stamp     = clock;
      if stamp(1) ~= obj.started(1)
        warning ( 'IPPager:timestamp'                                                     ...
                , [ 'The year has changed to %d since this object was created in %d.'     ...
                    ' Time comparisons will probably not operate correctly'               ...
                    ' and you should restart the application!'                            ...
                  ]                                                                       ...
                , stamp(1), obj.started(1)                                                ...
                );
        obj.started = clock;    % To prevent multiple warnings
      end
      
      stamp(1)  = 0;
      stamp     = datenum(stamp);
      
    end
    
  end

  
  %_____________________________________________________________________________
  methods (Static)

    %----- Structure conversion to load an object of this class from disk
    function obj = loadobj(frozen)
      
      % Start from default constructor
      obj               = IPPager();

      % Merge all fields from the frozen copy into the new object
      for field = fieldnames(frozen)'
        obj.(field{:})  = mergestruct ( obj.(field{:})      ...
                                      , frozen.(field{:})   ...
                                      , obj.default         ...
                                      );
      end
      
      % Re-request two-way communications
      checkComms        = [];
      for iChannel = 2:numel(obj.channel)
        if obj.channel(iChannel).isTwoWay
          obj.channel(iChannel).isTwoWay  = false;
          checkComms(end+1)               = iChannel;
          obj.requestTwoWayComms(iChannel);
        end
      end
      
      % Wait for system to handle communication requests
      for iWait = 0:IPPager.MAX_RETRIES
        obj.heartbeat();
        for iCheck = numel(checkComms):-1:1
          if obj.channel(checkComms(iCheck)).isTwoWay
            checkComms(iCheck)  = [];
          end
        end
        
        if isempty(checkComms)
          break;
        end
        pause(IPPager.RETRY_INTERVAL / 10);
      end
      
    end
    
    %----- Generates the requested type of data encoding format 
    function encoding = makeEncoding(id, encoding, varargin)
    
      encoding.id                     = IPPager.DATA_FCN(id);
      
      % Nothing to do if this is an ID-only encoding
      if isempty(varargin)
      
      % If more than one argument is provided, treat as structure specification
      elseif numel(varargin) > 1
        encoding.struct               = struct();
        for iArg = 1:2:numel(varargin)
          field                       = varargin{iArg};
          fcn                         = varargin{iArg + 1};
          encoding.struct.(field)     = fcn([]);
          encoding.formatFcn{end+1}   = fcn;
          encoding.formatStr{end+1}   = func2str(fcn);
          encoding.formatMax{end+1}   = IPPager.maxMessageLength(fcn);
        end
        
        % Ensure canonical order of fields
        [encoding.fields, order]      = sort(fieldnames(encoding.struct));
        encoding.formatFcn            = encoding.formatFcn(order);
        encoding.formatStr            = encoding.formatStr(order);
        encoding.formatMax            = encoding.formatMax(order);
        
      % If one argument is provided, assume that it is a format converter
      elseif ~isfunction(varargin{1})
        error('addEncoding:arguments', 'Invalid argument list, see class documentation.');
        
      % Treat as a simple array
      else
        encoding.formatFcn            = varargin{1};
        encoding.formatStr            = func2str(encoding.formatFcn);
        encoding.formatMax            = IPPager.maxMessageLength(varargin{1});
      end
      
    end
    
    %----- Encode a message in the given format
    function packet = encode(encoding, prefix, message)

      % Header
      packet              = [prefix, encoding.id];
      
      % Structure
      if ~isempty(encoding.struct)
        data              = {};
        numData           = 0;
        iStart            = numel(packet) + 1;
        packet(end + numel(encoding.fields) + 1)  = IPPager.MSG_STOP;

        % First collect data cast to the transmission format
        for iField = 1:numel(encoding.fields)
          datum           = message.(encoding.fields{iField});
          if numel(datum) > encoding.formatMax{iField}
            warning ( 'encode:dataTooLong'                                                          ...
                    , 'Array length %d for field %s too long, will be truncated to %d items.'       ...
                    , numel(datum), encoding.fields{iField}, encoding.formatMax{iField}             ...
                    );
            datum         = datum(1:encoding.formatMax{iField});
          end
          data{iField}    = typecast( encoding.formatFcn{iField}(datum)   ...
                                    , IPPager.DATA_STR                    ...
                                    );
          
          numData         = numData + numel(data{iField});
          packet(iStart)  = numel(data{iField});
          iStart          = iStart + 1;
        end
        
        % Concatenate data after length specifications
        packet(iStart + numData)  = inf;
        iStart            = iStart + 1;
        for iField = 1:numel(data)
          packet(iStart:iStart + numel(data{iField}) - 1) = data{iField};
          iStart          = iStart + numel(data{iField});
        end        
      
      % Simple array
      elseif ~isempty(encoding.formatFcn)
        if numel(message) > encoding.formatMax
          warning ( 'encode:dataTooLong'                                        ...
                  , 'Array length %d too long, will be truncated to %d items.'  ...
                  , numel(message), encoding.formatMax                          ...
                  );
          message         = message(1:encoding.formatMax);
        end
        encoded           = typecast(encoding.formatFcn(message), IPPager.DATA_STR);
        packet            = [packet, numel(encoded), encoded];
        
      % ID only
      elseif nargin > 2
        error('encode:improperMessage', 'Encoding "%s" should not have data items attached.', encoding.id);
      end
        
    end
    
    %----- Returns true if the two commands are different, i.e. the new one
    %      is not a retry of the old
    function yes = isDifferentCommand(old, new, checkSource)
      
      yes   = ~isempty(old)                                 ...
           && ( new.command   ~= old.command                ...
             || new.encoding  ~= old.encoding               ...
             || (checkSource && ~old.from.equals(new.from)) ...
              );
%            || new.retries   <  old.retries      ...   % Could happen due to packet delays
      
    end
    %----- Returns true if the two commands are the same
    function yes = isSameCommand(old, new, checkSource)
      
      yes   = ~isempty(old)                                 ...
           && new.command   == old.command                  ...
           && new.encoding  == old.encoding                 ...
           && (~checkSource || old.from.equals(new.from))   ...
            ;
      
    end
    %----- Returns true if the message is an acknowledgment of the command
    function yes = isAcknowledgment(command, message)
      
      yes   = ~isempty(command)                     ...
           && isequal(message, command.encoding)    ...
            ;
      
    end
    
    %----- Maximum number of items that can fit into an encoded length
    function count = maxMessageLength(dataType)
      count = floor( double(IPPager.MAX_INDEX) / numel(typecast(dataType(0), IPPager.DATA_STR)) );
    end
    
    
    %----- Execute a function with the given arguments
    function execute(fcn, varargin)
      
      if isempty(fcn)
        % Nothing to do
      elseif iscell(fcn)
        fcn{1}(varargin{:}, fcn{2:end});
      else
        fcn(varargin{:});
      end
      
    end

    %----- Execute a function with the given arguments
    function value = evaluate(fcn, varargin)
      
      if isempty(fcn)
        % Nothing to do
        value = [];
      elseif iscell(fcn)
        value = fcn{1}(varargin{:}, fcn{2:end});
      else
        value = fcn(varargin{:});
      end
      
    end
    
    
    %----- Enables retries until a maximum number of times
    function yes = retryUntilMaxTimes(pager, info)
      yes = info.retries < IPPager.MAX_RETRIES;
    end

    %----- Enables retries until the next command is issued
    function yes = retryUntilNextCommand(pager, info)
      yes = ( info.command == pager.cmdIndex );
    end
    
    
    %----- Test function to use as callbacks
    function printmeCallback(varargin)
      varargin{:}
%       keyboard;
    end
    
    %----- Callback that does nothing
    function doNothingCallback(varargin)
    end

    
    %----- Converts a byte message (column vector) to a Matlab string
    function str = toString(message)
      str = char(message');
    end
    
    %----- Returns Matlab string for the host name of a Java InetAddress
    function host = getHostName(address)
      if isempty(address)
        host  = '';
      else
        host  = char(address.getAddress().getHostAddress());
      end
    end
    
    %----- Human friendly display for a decoded transmission packet
    function printPacket(info)

      switch info.method
        case IPPager.PRE_PING
          method    = 'ping';
        case IPPager.PRE_PONG
          method    = 'pong';
        case IPPager.PRE_BROADCAST
          method    = 'broadcast';
        case IPPager.PRE_COMMAND
          method    = 'command';
        case IPPager.PRE_REPLY
          method    = 'reply';
        case IPPager.PRE_RECEIPT
          method    = 'receipt';
        case IPPager.PRE_FAILURE
          method    = 'FAILURE';
      end
      
      if isequal(info.encoding, IPPager.ID_VERIFY)
        encoding    = 'verify';
      elseif isequal(info.encoding, IPPager.ID_TALKTOME)
        encoding    = 'talk';
      else
        encoding    = info.encoding;
      end
      
      if isstruct(info.message)
        fprintf('  #%d  |%10s|%-6s|\n', info.channel, method, encoding);
        for field = fieldnames(info.message)'
          fprintf('          %30s : %s\n', field{:}, num2str(info.message.(field{:})'));
        end
      elseif numel(info.message) < 2
        fprintf('  #%d  |%10s|%-6s|[  %s  ]\n', info.channel, method, encoding, info.message);
      else
        fprintf('  #%d  |%10s|%-6s|\n', info.channel, method, encoding);
      end

    end
    
    %----- Convert a given index to a byte-encoded number
    function byte = index2byte(index)
      byte  = index - IPPager.INDEX_OFFSET;
    end
    %----- Convert a byte-encoded index to a Matlab index
    function index = byte2index(byte)
      index = double(byte) + IPPager.INDEX_OFFSET;
    end
    
    %----- Convert a given bit field to a byte
    function byte = bits2byte(bits)
      byte  = sum(IPPager.BYTE_BITS .* bits) + 1 - IPPager.INDEX_OFFSET;
    end
    %----- Convert a byte to a bit field
    function bits = byte2bits(byte)
      bits            = false(numel(IPPager.BYTE_BITS), numel(byte));
      for iByte = 1:numel(byte)
        bits(:,iByte) = bitand(double(byte(iByte)) - 1 + IPPager.INDEX_OFFSET, IPPager.BYTE_BITS) > 0;
      end
    end
    
    %----- Increment with wrap around
    function index = increment(index, minIndex, maxIndex)
      if index < maxIndex
        index   = index + 1;
      else
        index   = minIndex;
      end
    end

    %----- Index range with wrap around
    function range = history(refIndex, numPast, maxIndex)
      range         = refIndex - numPast:refIndex - 1;
      if range(1) < 1
        wrap        = 1:1 - range(1);
        range(wrap) = range(wrap) + maxIndex;
      end
    end
    
  end
  
end
