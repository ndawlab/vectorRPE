function initializeVR()
    

%     runCohortExperiment ( 'C:\Data\Ben\PoissonBlocksC'  ... dataPath
%                           , 'Poisson Blocks Shaping C'             ... experName
%                           , 'Cohort6'                           ... cohortName
%                           , numDataSync                             ... numDataSync
%                           , varargin{:}                             ...
%                           );

    numDataSync = [];
    experName = 'Poisson Blocks Shaping C';
%     datapath  =  'C:\Data\Ben\PoissonBlocksC';
datapath = '.\Data';
disp(strcat('Saving at:',datapath))


    % load all the info. i will load this as a struct in 


    % set vr 

    vr_initial.rotation_transform=0;

      % Load training schedule
    vr_initial.regiment     = TrainingRegiment( experName                     ...
                                        , strcat(datapath, '\PoissonBlocksShapingC_Cohort6_Bezos2.mat')                             ...
                                        , '', numDataSync               ...
                                        );
    vr_initial.regiment.sort();   % Alphabetical order of animals
    rng('shuffle')
 
saved_info = load('C:\Users\rslee\Documents\GitHub\vectorRPE\virmen\deepRL_files\train_info_cnnlstm_full_transient_unique.mat');
% todo: include this in the python call? it's just long :/ 
    vr_initial.trainee  = saved_info.info;

    load(vr_initial.trainee.experiment);

    % set experiment 

    exper.userdata                  = vr_initial;

    % i've edited this to change the view angle. 
    exper.movementFunction        = @moveArduino_FAKE_forward; % this overrides the movement function in exper
    exper.transformationFunction= @transformPerspectiveMex; % also overrides the transform function. this determines how the image is projected

%     start experiment
    
    
    vr = virmenEngine_start(exper); 
%     tow_positions = vr.cuePos;
    


end



