A vector reward prediction error model explains dopaminergic heterogeneity
============================


This repo contains the code needed to reproduce the model and figures from the manuscript: `Lee et al. 2022 <https://www.biorxiv.org/content/10.1101/2022.02.28.482379v1>`_. The data needed to run the figure notebook will be available on figshare upon publication. 

This repository is being actively updated and organized. Data will be available on Figshare upon publication or by request. 

Remaining work include: 

- more detailed instructions on requirements for running deepRL network with ViRMEn task

- [done] details on data structures and how they're formatted

- requirement files for figure analyses and deep RL agent

- all helper functions from Engelhard 2019 paper needed to run MATLAB scripts 

Author
^^^^^^
Rachel Lee (rslee [at] princeton.edu)

Project Organization
^^^^^^^^^^^^^^^^^^^^
::

    │
    ├── deepRL                       <- Source code for deep RL network, requires Stable Baselines 2.10.0
    │   ├── custom_cnn_lstm.py       <- Script for training deep RL network 
    │   ├── evalute_policies.ipynb   <- Notebook for evaluating trained deep RL network 
    │   ├── evaluate_policy.py       <- Helper functions for evaluating deep RL network 
    │
    ├── figures                      <- Notebooks for recreating figure panels for the manuscript
    │   ├── Figure 2.ipynb           <- Psychometric curves for mouse and Vector RPEs, Scalar value from model plotted against trial difficulties 
    │   ├── Figure 3.ipynb           <- Vector RPE units and DAnergic neurons response during the cue period. 
    │   ├── Figure 4.ipynb           <- Vector RPEs reflected incidental high-dimensional visual inputs
    │   ├── Figure 5.ipynb           <- Cue responses in model and DAergic neurons reflected RPEs with respect to cues, rather than simply their presence.
    │   ├── Figure 6.ipynb           <- Vector RPE units and DAergic neurons response during outcome period. 
    │   ├── utils                    <- Matlab scripts and functions for recreating figure panels. 
    │
    ├── gym_vr                       <- Stable Baselines Custom Environment, requires gym 0.14.0 and setting up a custom environment 
    │
    ├── virmen                       <- Source code for ViRMEn graphic engine for simulating VR task 
    │
    
    
Installation Requirements 
^^^^^^^^^^^^

ViRMEnand the deep RL code can only be run on a Windows 10 Desktop with Python 3.7+ and MATLAB 2017+. ViRMEn source code is self-contained in the folder, based on the `ViRMEn package <http://pni.princeton.edu/pni-software-tools/virmen-download>`_ (version 2016-2-12). The ``deepRL`` source code for the network requires the `Stable Baselines package <https://stable-baselines.readthedocs.io/en/master/guide/install.html>`_ (version 2.10.0). In order to run the deep RL network with the VR task from ViRMEn, you must set up the custom environment ``gym_vr``, which requires the `Open AI gym package <https://github.com/openai/gym>`_ (version 0.14.0) and following these `instructions <https://www.gymlibrary.ml/pages/environment_creation/#example-custom-environment>`_. You will also need to be able to call MATLAB from python, using `Matlab Engine API for Python <https://www.mathworks.com/help/matlab/matlab-engine-for-python.html?s_tid=CRUX_lftnav>`_. 

To install the code for replicating the figures, you will need Python 3.7+, numpy, matplotlib, and scipy. You may also need MATLAB 2017+ in order to replicate the code for analyzing the original neural data from `Engelhard et al. 2019  <https://www.nature.com/articles/s41586-019-1261-9>`_

Installation 
^^^^^^^^^^^^

To install the code through Github, open a terminal and run:

.. code-block:: bash

    git clone https://github.com/ndawlab/vectorRPE

For convenience, we recommend setting up a virtual environment before running the code, to avoid any unpleasant version control issues or interactions with other projects you're working on. 

To install the deep RL network to run on the virmen task, please follow this set of instructions

1. Ensure that you have the installation requirements. In particular: 

- **OS**: ViRMEm is currently only supported on Windows 10 Desktop with Python 3.7+. Note that Stable Baselines is not officially supported on PC, but we were able to configure it for a PC. 
- **CPU**: CPU must be able to support cuda for TensorFlow. 
- **GPU**: ViRMEn uses OpenGL for rendering graphics, which requires, at minimum, GPU set up for 1024x768 resolution at 120 Hz. The recommended GPU for running ViRMEn are NVIDIA Quadro GPUs. You may try using a lower-end GPU, which likely will lead to ViRMEn rendering the VR environment with less fidelity or in B&W. GPU is also needed for parallel training for the Stable Baseline agent (We used 8 parallel environments). 
- **Software**: You will need MATLAB 2017+ to run ViRMEn and Python 3.7+ to run Stable Baselines. We used `Stable Baselines <https://stable-baselines.readthedocs.io/en/master/guide/install.html>`_ (version 2.10.0) with Tensorflow (version 1.14.0) (Note: as of bioRxiv publication, Stable Baselines 2.X does not support Tensorflow2.X, and Stable Baselinse3.X, which does use Tensorflow 2.X, did not support the particular deep RL architecture used in this paper). You will also need `Matlab Engine API for Python <https://www.mathworks.com/help/matlab/matlab-engine-for-python.html?s_tid=CRUX_lftnav>`_. 

These are PC configurations in which we were able to replicate our training regimen: 

    **Configuration 1** 

    - GPU: NVIDIA GForce GTX 1600
    - CPU: Intel (R) Core (TM) i7-6800K @ 3.40 Hz (6 coes) 
    - RAM: 128 Gb
    - Around 24 hours to train 20 million timesteps with 8 parallel environments


    **Configuration 2**
    
    - GPU: NVIDIA Quadro K620
    - CPU: Intel (R) Core (TM) i7-7700 @ 3.60 Hz
    - RAM: 32 GB

2. First make sure that ViRMEn works. After cloning the repo, run ``virmen\deepRL_files\test_mem_leak.m``. If working correctly, ViRMEn should launch, you should be able to see the virtual agent run down the maze, and MATLAB should output the final decision of the agent. 

3. Install `Stable Baselines <https://stable-baselines.readthedocs.io/en/master/guide/install.html>`_ (version 2.10.0) and Tensorflow 1.14.0. Check that the installation works well by running the `CartPole problem.  <https://stable-baselines.readthedocs.io/en/master/guide/quickstart.html>`_ You do not need OpenMPI for our agent's deep RL architecture. 

4. Install Gym and Custom Gym Environment ``vr_gym``    

::

    git clone https://github.com/openai/gym.git
    cd gym
    pip install -e .

Next, move the ``gym_vr`` folder from this repo into ``gym\gym\envs`` folder. You will want to follow `these instructions <https://www.gymlibrary.ml/pages/environment_creation/#example-custom-environment>`_ to properly register for the environment. 

5. Download `Matlab Engine API for Python <https://www.mathworks.com/help/matlab/matlab-engine-for-python.html?s_tid=CRUX_lftnav>`_. Make sure to add and save the entire ``virmen`` path from this repo. 

6. Check that the the custom gym environment works by running in python 

::

    import gym
    from gym.envs.registration import register
    register(
        id='vrgym-v0',
        entry_point='gym_vr.envs:VRShapingEnv',
    )
    env = gym.make('vrgym-v0')
    

If you received an error ``gym.error.NameNotFound: Environment `vrgym` doesn't exist.`` then you likely did not register the custom environment correctly. 

If you received an error related to the MATLAB code, you may need to add the correct pathway in MATLAB or ensure that all the pathways in ViRMEn are correctly specified and saved. 

7. To run and train the network, you'll want to run ``deepRL\custom_cnn_lstm.py``. It is recommended to also have ``tensorboard (version 1.14.0)`` to keep track of the agent's performance. After training, you can use ``evaluate_policies.ipynb`` to evaluate the trained network with frozen weights. 




Data Availability and Description 
^^^^^^^^^^^^
Data will be available upon publication on Figshare or by request beforehand. 

Data should be downloaded and placed in the `data` folder of this repository. Contents of data folder is organized as such: 

::

    │   
    ├── logs                         <- outputs from trained deep RL network 
    │   ├── rl_model_20800000_steps  <- trained weights of RL agent
    |   ├── 5000t_mosttrain_db.p     <- 5000 trials of trained RL agent, data outputted from evaluate_policies.ipynb
    │   ├── trianinfo_db.mat         <- 5000 trials of trained RL agent, data outputted from ViRMEn
    |   ├── pes.p                    <- Vector RPEs calcuated using the trained weights and features from 5000 trials
    |   ├── no_va                    <- outputs from the same trained deep RL network running in a maze without cues 
    |   |    ├── 5000t_mosttrain_nova_db.p 
    │   |    ├── trianinfo_nova_db.mat      
    |   |    ├── pes_nova.p                 
    |   |    ├── 1000t_obses_nova_db.p     <- Video frames from the first 1000 trials of the trained deep RL agent running in a maze without cues 
    │   |    ├── emptymaze_runthru.mat     <- Video frames (obses) and Y positions (ypos) of an agent running down an empty maze
    │
    ├── neuralData                             <- neural data from Engelhard et al. 2019 paper re-analyzed for Lee et al. 2022 
    │   ├── res_cell_ac_sfn.mat                <- raw neural data of 303 neurons recorded across 23 sessions 
    │   ├── shuffled_data                      <- folder with 1000 instances of shuffled raw neural data, * denotes each instance
    │   │    ├── res_cell_acsfn_shuffbins_3s_*.mat                     <- 1000 instances of shuffled neural data, same format as res_cell_ac_sfn.mat
    │   │    ├── res_cell_acsfn_shuffbins_3s_new_fstat*_FO.mat         <- F-statistics for shuffled data of 303 neurons wrt to 5 behavioral variables during cue period
    │   │    ├── res_cell_acsfn_shuffbins_3s_new_fstat*_FO_outcome.mat <- F-statistics for shuffled data of 303 neurons wrt to reward
    │   ├── psycho_neural.mat                  <- psychometric curve for mice behavior (see Figure 2B)
    │   ├── neural_behaviors.mat               <- processed neural data showing neurons modulated by behavioral variables (see Figure 3D-F) 
    │   ├── ben_cdc_kernels_contracueunits.mat <- kernels for neural response to confirmatory and disconfirmatory contralateral cues (see Figure 5C)
    



Data structures are organized as such: 
**********************

**From the deep RL agent:**

(1) ``rl_model_20800000_steps``: 

Contains a subset of the trained weights of the deep RL model after 2,080,000 timesteps (approximately 130,000 trials). Cut-off for training was determined when agent performed at 80% or higher correct choices. Four weights are included:  

``model/pi/w:0``: The weights for the actor policy

``model/pi/b:0``: The bias weights for the actor policy

``model/vf/w:0``: The weights for the critic's value

``model/vf/b:0``: The biase weights for the critic's value


TODO: add all weights? 


(2) ``data/logs/5000t_mosttrain_db.p`` and  ``data/logs/5000t_mosttrain_nova_db.p`` : 

This data structure is outputted from `evalute_policies.ipynb` and contains various task variables and layers from the trained deepRL agent performing 5000 trials with weights frozen at ``rl_model_20800000_steps``. The data is set up as a list of trials, with each entry the data for the particular trial. 

Dataset includes (in this order): 

- ``actions``: actions of the agent (1: Left 2: Right 3: Forward). Note that actions during cue region (see Figure 2a) changes agent's view angle and actions after cue region allows the agent to decide to left or right arm. 

- ``rewards``: 0 = no reward at this timestep, 1 = reward at this timestep

- ``feats``: LSTM features (64 units) of the trained deep RL network

- ``terms``: 0 = trials has not ended, 1 = trial has ended

- ``vs``: scalar value from the deep RL agent 

- ``tow_counts``: tower counts on left and right side at each timepoint of the trial

- ``episode_lengths``: length of each trial. Note that the episode lengths vary because agent can choose the forward action after cue region, which is a null action that means the agent does not choose left OR right arm yet. 


TODO: take out the yposition!!! it's empty and I don't use it anymore. and left/right movement is CORRECTLY described. 

(3) ``train_info_db.mat`` and ``trianinfo_nova_db.mat``:

This data structure is outputted by ViRMEn at the same time as `evaluate_policies.ipynb` and contains additional task variables when the trained deepRL agent performed 5000 trials with the weights frozen at ``rl_model_20800000_steps``. The data is opened as a dictionary in python, and you can use my helper functions in ``cnnlstm_analysis_utils.p`` to extract each field (See `Figure 3.ipynb` for example). 

The relevant task variables include: 

- ``choice``: Agent's choice in each trial

- ``trialType``: The trial type, or the correct side with more towers. Outputs as ``L``, ``R``. Note that in the case there are even left and right towers, there is a 50/50 chance for ``L`` or ``R``. 

- ``position``: A N_timesteps x 3 matrix with the first column the x position (cm) of the agent at every time step, the second column the y position (cm) of the agent at every time step, and the third column the view angle (radians) of the agent at every time step for N timesteps total. 

- ``cueCombo``: 2 X M indicator matrix that gives the order of cues appearing left (first row) and right (second row), for M = max number of cues on either side. 

- ``cuePos``: Vector that gives the position of cues appearing in cm. 

- ``cueOnset``: 2 x M matrix that gives the timestep the left cues (first row) and right cues (second row) appeared in. Note that timestep is given in 1-indexing and also off by 1 timestep, so needs to be corrected by subtracting 2 when working in Python (see Figure 3C code in ``Figure 3.ipynb``). 


**For the neural analyses:**

(1) ``res_cell_ac_sfn`` and shuffled data ``res_cellacsfn_shuffbins_3s_*.mat``: 1 x 23 struct array, each entry for the 23 sessions recorded for `Engelhard et al. 2019 paper. <https://www.nature.com/articles/s41586-019-1261-9>`_ Each instance of the shuffled data is created by shuffling non-overlapping 3-s bins (to maintain the autocorrelation of the signal). See `Engelhard et al. 2019 paper's <https://www.nature.com/articles/s41586-019-1261-9>`_ Methods > Calculation of the relative contributions of behavioural variables to neural activity for more information on the shuffled data. 

Relevant fields include: 

- ``folder``: mouse #/date for the given session.

- ``good_tr``: ``1 x num_trials`` row vector indicates which are the good trials in which the mice were engaged in the task; that is, for all the fields below suffixed with ``_gd``, approximately 15% of trials per session were dropped if mice were not sufficiently engaged in the task, typically near the end of the session when the animal's performance decreased (See  `Engelhard et al. 2019 paper's <https://www.nature.com/articles/s41586-019-1261-9>`_ Methods > Session and Trial Selection for the exact critereon for dropping trials). 

- ``whole_trial_activity``: ``num_trials x 1`` cell array, each cell an ``num_timesteps x num_neurons`` matrix containing the whole trial activity of neurons recorded. Note that when ``NaN`` values appear when neuron becomes unstable and we were no longer able to record meaningful neural activity. 

- ``lr_cue_onset``: ``num_trials x 1`` cell array, each cell an ``num_timesteps x 2`` indicator matrix for when left (first column) and right (second column) appears. 

- ``all_choice_gd``: ``1 x num_trials`` row vector indicating mice's choice for the given session. 1 = left choice 2 = right choice.

- ``prev_choice_gd``: Same as ``all_choice_gd`` but for previous trial's choice. Note this is the *true* previous choice, taking into account that trials are dropped in ``all_choice_gd``. 

- ``is_succ_gd``: ``1 x num_trials`` indicator row vector for whether or not mice were rewarded. 

- ``prev_issucc_gd``: Same as ``is_succ_gd`` but for reward on previous trial. Note this is the *true* previous reward, taking into account that trials are dropped in ``is_succ_gd``. 

- ``allpos_cell_gd``: ``num_trials x 1`` cell array, each cell an ``num_timesteps x 3`` matrix containing the x-position (first column), y-position (second column), and view angle (third column) of the mouse. 

- ``allveloc_cell_gd``: Same as ``allpos_cell_gd``, but for x-direction, y-direction, and view angle velocity. 

- ``total_numcues``: ``num_trials x 1`` cell array, each cell a ``2 x 1`` matrix for total left and right cues. 

- ``prev_numcues``: Same as ``total_numcues`` but for previous trial's cues. Note that this takes into account that trials are dropped in ``total_numcues``. 





            

