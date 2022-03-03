classdef ImageComparer < handle

  %------- Constants
  properties (Constant)
    
    DISP_QUANTILE   = [0.01 0.95]       % Quantile range of histogram display
    IMG_QUANTILE    = [0.1 0.8]         % Quantile range of image data to use
    IMG_BORDER      = [0 0]             % Number of pixels in the x,y borders to omit from analysis
    HIST_NBINS      = 100               % Number of bins for pixel values histogram
    DMETRIC_POWER   = 4                 % Exponent for metric value change axis
    ONLINE_INTERVAL = 0.5               % Minimum number of seconds between calls

    GUI_MONITOR     = 1
    GUI_POS         = [-350 44 350 900]
%     GUI_POS         = [-400 44 400 -50]
    GUI_COLOR       = [1 1 1]
    GUI_FONT        = 10
    GUI_MARKER      = 4

    ONLINE_COLOR    = [51 160 255] / 255
    OFFLINE_COLOR   = [1 1 1] * 0.9
    PAST_COLOR      = [1 1 1] * 0.7
    REF_COLOR       = reshape([1 0 0], 1, 1, [])
    IMG_COLOR       = reshape([0 1 0], 1, 1, [])
    NAN_COLOR       = reshape([0 0 0], 1, 1, [])
    
  end
  
  %------- Private data
  properties (Access = protected)
    ui              = struct()          % User interface component handles
    lastCall        = []                % For throttling fcnSetImage
    listener        = []
    listenee        = []
  end
  
  %------- Public data
  properties (SetAccess = protected)
    figGUI          = []                % Figure handle for GUI
    refImage                            % Original reference image
    rawImage        = []                % Current image data (grayscale)
    refData                             % Normalized reference image 
    refMask                             % Reference image mask
    refMean                             % Mean pixel value in reference image
    refStd                              % Pixel value standard deviation in reference image
    pixBins                             % Binning for pixel values
    dispNSigmas                         % Standard deviations for image display
    imgNSigmas                          % Standard deviations for image normalization
  end

  %________________________________________________________________________
  methods
    
    %----- Constructor
    function obj = ImageComparer(refFile)

      % Load reference image and convert it to a red mask
      obj.setRefImage(refFile);
      obj.drawGUI();
      
    end
    
    %----- Destructor
    function delete(obj)
      
      if ~isempty(obj.listener)
        delete(obj.listener);
      end
      
      obj.closeGUI();
      
    end
    
    %----- Sets the reference image 
    function setRefImage(obj, refFile)

      % Load reference image and convert it to a red mask
      refInfo           = imfinfo(refFile);
      refStack          = zeros(refInfo(1).Height, refInfo(1).Width);
      for iFrame = 1:numel(refInfo)
        refStack(:,:,iFrame)  = imread(refFile, iFrame);
      end
      obj.refImage      = mean(refStack(:,:,1:end), 3);
      clear('refStack');
      
      % Compute standard deviation range for fast normalization
      obj.refMean       = mean(obj.refImage(:));
      obj.refStd        = std(obj.refImage(:));
      refQuantile       = quantile(obj.refImage(:), [obj.DISP_QUANTILE, obj.IMG_QUANTILE]);
      obj.dispNSigmas   = (refQuantile(1:2) - obj.refMean) / obj.refStd;
      obj.imgNSigmas    = (refQuantile(3:4) - obj.refMean) / obj.refStd;
      
      % Compute binning for pixel values
      obj.pixBins       = linspace(obj.dispNSigmas(1), obj.dispNSigmas(2)*2, ImageComparer.HIST_NBINS);
      if numel(obj.pixBins) > 2
        obj.pixBins     = ( obj.pixBins(1:end-1) + obj.pixBins(2:end) )/2;
      else
        obj.pixBins     = [-1 1];
      end
      
      % Update it in the GUI if already drawn
      if ~isempty(obj.figGUI)
        obj.updateRefImage();
      end
      
    end
    
    %----- Sets the current image to be compared to the reference
    function setImage(obj, image)

%       profile on;
      obj.rawImage  = image;
      obj.updateImage();
%       profile viewer;
      
    end
    
    %----- Callback version of setImage() that can be set as a CData listener
    function fcnSetImage(obj, handle, event)
      
      % Throttling
      if ~isempty(obj.lastCall) && toc(obj.lastCall) < obj.ONLINE_INTERVAL
        return;
      end
      
      obj.lastCall  = tic;
      newData       = get(event.AffectedObject, 'CData');
      if numel(newData) > 1
        obj.setImage(newData');
      end
      
    end
    
    %----- Programatically close GUI window
    function closeGUI(obj)
      if ~isempty(obj.figGUI) && ishghandle(obj.figGUI)
        delete(obj.figGUI);
      end
    end
    
    %----- Attach this object as a CData listener
    function listenTo(obj, imgHandle)
      
      % Can only listen to one thing at a time
      if ~isempty(obj.listener)
        delete(obj.listener);
        obj.listener  = [];
      end
      
      % Activate the toggle button
      obj.listenee    = imgHandle;
      set(obj.ui.btnOnline, 'Enable', 'on', 'Value', 0);
      executeCallback(obj.ui.btnOnline);
      
    end
    
  end
  
  %________________________________________________________________________
  methods (Access = protected)
    
    %----- Draw GUI
    function drawGUI(obj)
      
      % Recreate the GUI figure if it already exists
      if ~isempty(obj.figGUI) && ishghandle(obj.figGUI)
        delete(obj.figGUI);
      end

      % Compute position of figure
      obj.figGUI      = makePositionedFigure( obj.GUI_POS, obj.GUI_MONITOR, 'OuterPosition'       ...
                                            , 'Name'            , 'Online image vs. reference'    ...
                                            , 'NumberTitle'     , 'off'                           ...
                                            , 'Color'           , obj.GUI_COLOR                   ...
                                            , 'Menubar'         , 'none'                          ...
                                            , 'Toolbar'         , 'figure'                        ...
                                            , 'Visible'         , 'on'                            ...
                                            );
%                                             , 'CloseRequestFcn' , ''                              ...
                                          
      % Various display regions
      obj.ui.axsRef   = axes( 'Parent'              , obj.figGUI                      ...
                            , 'Units'               , 'normalized'                    ...
                            , 'YDir'                , 'reverse'                       ...
                            , 'XTickLabel'          , {}                              ...
                            , 'YTickLabel'          , {}                              ...
                            , 'XLim'                , [1 size(obj.refImage,2)]        ...
                            , 'YLim'                , [1 size(obj.refImage,1)]        ...
                            , 'Box'                 , 'on'                            ...
                            , 'Layer'               , 'top'                           ...
                            , 'Position'            , [0.01 0.65 0.88 0.35]           ...
                            , 'DataAspectRatio'     , [1 1 1]                         ...
                            , 'FontSize'            , obj.GUI_FONT                    ...
                            );
      colormap(obj.ui.axsRef, 'gray');
      obj.ui.axsImage = axes( 'Parent'              , obj.figGUI                      ...
                            , 'Units'               , 'normalized'                    ...
                            , 'YDir'                , 'reverse'                       ...
                            , 'XTickLabel'          , {}                              ...
                            , 'YTickLabel'          , {}                              ...
                            , 'XLim'                , [1 size(obj.refImage,2)]        ...
                            , 'YLim'                , [1 size(obj.refImage,1)]        ...
                            , 'Box'                 , 'on'                            ...
                            , 'Layer'               , 'top'                           ...
                            , 'Position'            , [0.01 0.295 0.88 0.35]          ...
                            , 'DataAspectRatio'     , [1 1 1]                         ...
                            , 'FontSize'            , obj.GUI_FONT                    ...
                            );
      obj.ui.axsHist  = axes( 'Parent'              , obj.figGUI                      ...
                            , 'Units'               , 'normalized'                    ...
                            , 'YTickLabel'          , {}                              ...
                            , 'YGrid'               , 'on'                            ...
                            , 'Box'                 , 'on'                            ...
                            , 'Layer'               , 'top'                           ...
                            , 'Position'            , [0.63 0.13 0.34 0.15]            ...
                            , 'FontSize'            , obj.GUI_FONT                    ...
                            );
      xlabel(obj.ui.axsHist, 'Pixel value / \sigma', 'FontSize', obj.GUI_FONT);
      obj.ui.axsDCorr = axes( 'Parent'              , obj.figGUI                      ...
                            , 'Units'               , 'normalized'                    ...
                            , 'XGrid'               , 'on'                            ...
                            , 'YGrid'               , 'on'                            ...
                            , 'Box'                 , 'on'                            ...
                            , 'Layer'               , 'top'                           ...
                            , 'Position'            , [0.14 0.13 0.44 0.15]           ...
                            , 'FontSize'            , obj.GUI_FONT                    ...
                            );
%                             , 'XLim'                , [-1 1]                          ...
%                             , 'YLim'                , [-1 1]                          ...
      xlabel(obj.ui.axsDCorr, 'Max. correlation'              , 'FontSize', obj.GUI_FONT);
      ylabel(obj.ui.axsDCorr, 'Pearson''s correlation (\rho)' , 'FontSize', obj.GUI_FONT);
      obj.ui.axsTCorr = axes( 'Parent'              , obj.figGUI                      ...
                            , 'Units'               , 'normalized'                    ...
                            , 'XTickLabel'          , {}                              ...
                            , 'YGrid'               , 'on'                            ...
                            , 'Box'                 , 'on'                            ...
                            , 'Layer'               , 'top'                           ...
                            , 'Position'            , [0.14 0.01 0.84 0.06]            ...
                            , 'FontSize'            , obj.GUI_FONT                    ...
                            );
%       xlabel(obj.ui.axsTCorr, sprintf('\\Sigma\\rho^{%.3g}', ImageComparer.DMETRIC_POWER), 'FontSize', obj.GUI_FONT);
      ylabel(obj.ui.axsTCorr, '\rho', 'FontSize', obj.GUI_FONT);

      % Info display handles
      obj.ui.hRef     = imagesc ( 'Parent'          , obj.ui.axsRef                   ...
                                );
      obj.ui.hImage   = imagesc ( 'Parent'          , obj.ui.axsImage                 ...
                                );
      if exist('enhanceCopying', 'file')
        enhanceCopying(obj.figGUI);
      end
      
      % Image comparison metrics
      obj.ui.prevTCorr= line( 'Parent'              , obj.ui.axsTCorr                 ...
                            , 'XData'               , []                              ...
                            , 'YData'               , []                              ...
                            , 'Color'               , obj.PAST_COLOR                  ...
                            , 'LineWidth'           , 1                               ...
                            );
      obj.ui.currTCorr= line( 'Parent'              , obj.ui.axsTCorr                 ...
                            , 'XData'               , []                              ...
                            , 'YData'               , []                              ...
                            , 'Marker'              , 'o'                             ...
                            , 'MarkerFaceColor'     , [0 0 0]                         ...
                            , 'MarkerSize'          , obj.GUI_MARKER                  ...
                            , 'LineWidth'           , 1                               ...
                            );
      obj.ui.prevDCorr= line( 'Parent'              , obj.ui.axsDCorr                 ...
                            , 'XData'               , []                              ...
                            , 'YData'               , []                              ...
                            , 'Color'               , obj.PAST_COLOR                  ...
                            , 'Marker'              , 'o'                             ...
                            , 'MarkerFaceColor'     , obj.PAST_COLOR                  ...
                            , 'MarkerSize'          , obj.GUI_MARKER-1                ...
                            , 'LineStyle'           , 'none'                          ...
                            );
      obj.ui.currDCorr= line( 'Parent'              , obj.ui.axsDCorr                 ...
                            , 'XData'               , []                              ...
                            , 'YData'               , []                              ...
                            , 'Marker'              , 'o'                             ...
                            , 'MarkerFaceColor'     , [0 0 0]                         ...
                            , 'MarkerSize'          , obj.GUI_MARKER                  ...
                            , 'LineWidth'           , 1                               ...
                            );
                          
      % Pixel value histograms
      obj.ui.linRef   = line( 'Parent'              , obj.ui.axsHist                  ...
                            , 'Color'               , obj.REF_COLOR                   ...
                            , 'LineWidth'           , 1                               ...
                            );
      obj.ui.linImg   = line( 'Parent'              , obj.ui.axsHist                  ...
                            , 'Color'               , obj.IMG_COLOR                   ...
                            , 'LineWidth'           , 1                               ...
                            );

      % User controls
      obj.ui.btnOnline= uicontrol ( 'Parent'              , obj.figGUI                ...
                                  , 'Style'               , 'togglebutton'            ...
                                  , 'Units'               , 'normalized'              ...
                                  , 'Min'                 , 0                         ...
                                  , 'Max'                 , 1                         ...
                                  , 'Value'               , 0                         ...
                                  , 'Enable'              , 'off'                     ...
                                  , 'Callback'            , @obj.toggleOnline         ...
                                  , 'Position'            , [0.91 0.4 0.07 0.15]      ...
                                  , 'FontSize'            , obj.GUI_FONT+1            ...
                                  , 'FontWeight'          , 'bold'                    ...
                                  );
                          
      % Show reference image
      obj.updateRefImage();

    end

    %----- Updates image and reference data according to the desired normalization
    function updateImageNorm(obj)
      
      % Recompute quantities for the reference histogram
      [obj.refData, ~, obj.refMask]     ...
            = obj.rescaleImage(obj.refImage, obj.REF_COLOR, obj.imgNSigmas);

      % Update info also for the data histogram
      obj.updateImage();
      
    end
      
    %----- Updates reference image data
    function updateRefImage(obj)

      [refDisplay, refFreq] = obj.rescaleImage(obj.refImage, [], obj.dispNSigmas, obj.refMean, obj.refStd);
      set(obj.ui.hRef   , 'CData', refDisplay);
      set(obj.ui.axsHist, 'XLim' , obj.pixBins([1 end]), 'YLim' , [0 1.5*max(refFreq)]);
      set(obj.ui.linRef , 'XData', obj.pixBins         , 'YData', refFreq);
      
      obj.updateImageNorm();
      
      set(obj.ui.axsRef  , 'XLim', [1 size(obj.refImage,2)], 'YLim', [1 size(obj.refImage,1)]);
      set(obj.ui.axsImage, 'XLim', [1 size(obj.refImage,2)], 'YLim', [1 size(obj.refImage,1)]);
    end
    
    %----- Updates image data according to the given range
    function updateImage(obj)

      % Load the input image if available
      if isempty(obj.rawImage) || numel(obj.refData) ~= numel(obj.rawImage)
        imgMask                   = 0;

      else
        [imgData,pixFreq,imgMask] = obj.rescaleImage(obj.rawImage, obj.IMG_COLOR, obj.imgNSigmas);
      
        % Update pixel values histogram
        set(obj.ui.linImg, 'XData', obj.pixBins, 'YData', pixFreq);
        
        % Compute image comparison metric and relative value to previous
        metric                    = corr(obj.refData(:), imgData(:));
        metricX                   = get(obj.ui.prevTCorr, 'XData');
        metricY                   = get(obj.ui.prevTCorr, 'YData');
        if isempty(metricX)
          refTime                 = 0;
          dMetric                 = 0;
        else
          refTime                 = metricX(end);
          dMetric                 = metric - metricY(end);
        end
        
        % Update time series of correlation 
        metricX(end+1)            = refTime + abs(dMetric).^ImageComparer.DMETRIC_POWER;
        metricY(end+1)            = metric;
        set(obj.ui.prevTCorr, 'XData', metricX     , 'YData', metricY     );
        set(obj.ui.currTCorr, 'XData', metricX(end), 'YData', metricY(end));
        
        % Update scatter plot of correlation vs. minimum
        metricX                   = get(obj.ui.prevDCorr, 'XData');
        metricY                   = get(obj.ui.prevDCorr, 'YData');
        if isempty(metricX)
          metricX(end+1)          = metric;
        else
          metricX(end+1)          = max(metric, metricX(end));
        end
        metricY(end+1)            = metric;
        set(obj.ui.prevDCorr, 'XData', metricX     , 'YData', metricY     );
        set(obj.ui.currDCorr, 'XData', metricX(end), 'YData', metricY(end));
        
      end
      
      % Combine with reference
      imgMask                     = imgMask + obj.refMask;
      
      % Update displays
      set ( obj.ui.hImage                           ...
          , 'CData'     , imgMask                   ...
          );
      
    end
    
    %----- Rescales a given image so that the specified number of standard
    %      deviations around the mean is mapped to a [0, 1] range
    function [rescaled, pixelFreq, mask] = rescaleImage(obj, original, rgbScale, range, imgMean, imgStd)
      
      rescaled              = double(original(:,:,:));
      if nargin < 5
        imgMean             = mean(rescaled(:));
        imgStd              = std(rescaled(:));
      end
      
      rescaled              = ( rescaled - imgMean ) / imgStd;
      if nargout > 1
        % Generate histogram of pixel value counts
        pixelFreq           = hist( rescaled(:), obj.pixBins ) / numel(rescaled);
      end
      
      belowRange            = any( rescaled < range(1) , 3 );
      aboveRange            = any( rescaled > range(2) , 3 );
      rescaled              = ( rescaled - range(1) ) / ( range(2) - range(1) );
      rescaled(belowRange)  = 0;
      rescaled(aboveRange)  = 1;
      
      if nargout > 2
        rescaled            = 1 - rescaled;
        mask                = bsxfun(@times, rescaled, reshape(rgbScale, 1, 1, []));
      end

    end

    %----- Toggle listening status
    function toggleOnline(obj, handle, event)

      status  = get(obj.ui.btnOnline, 'Value');
      
      if status == 0
        % If currently off, turn it on
        set ( obj.ui.btnOnline                                                                      ...
            , 'String'          , '<html><center>O<br/>N<br/>L<br/>I<br/>N<br/>E</center></html>'   ...
            , 'BackgroundColor' , obj.ONLINE_COLOR                                                  ...
            );
        obj.listener  = addlistener(obj.listenee, 'CData', 'PostSet', @obj.fcnSetImage);
        
      else
        % If currently on, turn it off
        set ( obj.ui.btnOnline                                                                      ...
            , 'String'          , '<html><center>I<br/>D<br/>L<br/>E</center></html>'               ...
            , 'BackgroundColor' , obj.OFFLINE_COLOR                                                 ...
            );
        delete(obj.listener);
        obj.listener  = [];
        
      end
    end
    
  end
  
  %________________________________________________________________________
  methods (Static)
    
  end

end
