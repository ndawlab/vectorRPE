A vector reward prediction error model explains dopaminergic heterogeneity
============================


This repo contains the code needed to reproduce the model and figures from the manuscript: `Lee et al. 2022 <https://www.biorxiv.org/content/10.1101/2022.02.28.482379v1>`_. The data needed to run the figure notebook will be available on figshare upon publication. 

This repository is being actively updated and organized. Data will be available on Figshare upon publication or by request. 
Remaining work include: 
- more detailed instructions on requirements for running deepRL network with ViRMEn task
- details on data structures and how they're formatted
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

ViRMEn and the deep RL code can only be run on a Windows 10 Desktop with Python 3.7+. ViRMEn source code is self-contained in the folder, based on the `ViRMEn package <http://pni.princeton.edu/pni-software-tools/virmen-download>`_ (version 2016-2-12). The ``deepRL`` source code for the network requires the `Stable Baselines package <https://stable-baselines.readthedocs.io/en/master/guide/install.html>`_ (version 2.10.0). In order to run the deep RL network with the VR task from ViRMEn, you must set up the custom environment ``gym_vr``, which requires the `Open AI gym package <https://github.com/openai/gym>`_ (version 0.14.0) and following these `instructions <https://www.gymlibrary.ml/pages/environment_creation/#example-custom-environment>`_. 

Installation 
^^^^^^^^^^^^

To install the code through Github, open a terminal and run:

.. code-block:: bash

    git clone https://github.com/ndawlab/vectorRPE

For convenience, we recommend setting up a virtual environment before running the code, to avoid any unpleasant version control issues or interactions with other projects you're working on. 


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
    |   ├── pes.p                    <- Vector RPEs calcuated using the trained weights and features from 5000 trials. 
    |   ├── no_va                    <- outputs from the same trained deep RL network running in a maze without cues 
    |   |    ├── 5000t_mosttrain_nova_db.p 
    │   |    ├── trianinfo_nova_db.mat      
    |   |    ├── pes_nova.p                 
    |   |    ├── 1000t_obses_nova_db.p     <- Video frames from the first 1000 trials of the trained deep RL agent running in a maze without cues. 
    │   |    ├── emptymaze_runthru.mat     <- Video frames (obses) and Y positions (ypos) of an agent running down an empty maze. 
    │
    ├── neuralData                  
    │   ├── res_cell_ac_sfn           <- neural data from Engelhard et al. 2019 paper re-analyzed for Lee et al. 2022. 


Data structures are organized as such: 
**********************

**For deep RL agent's outputs:**

(1) ``rl_model_20800000_steps``: 

Contains a subset of the trained weights of the deep RL model after 2,080,000 timesteps (approximately 130,000 trials). Cut-off for training was determined when agent performed at 80% or higher correct choices. Four weights are recorded: 

``model/pi/w:0``: The weights for the actor policy

``model/pi/b:0``: The bias weights for the actor policy

``model/vf/w:0``: The weights for the critic's value

``model/vf/b:0``: The biase weights for the critic's value


TODO: add all weights? 


(2) ``data/logs/5000t_mosttrain_db.p`` and  ``data/logs/5000t_mosttrain_nova_db.p`` : 

This data structure is outputted from `evalute_policies.ipynb` and contains various task variables and layers from the trained deepRL agent performing 5000 trials with weights frozen at ``rl_model_20800000_steps``. The data is set up as a list of trials, with each entry the data for the particular trial. 

Dataset includes (in this order): 

- ``actions``: actions of the agent (1: Left 2: Right 3: Forward). Note that actions during cue region (see Figure 2a) changes agent's view angle and actions after cue region allows the agent to decide to left or right arm)

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


**For neural data:**

(1) ``res_cell_ac_sfn``: 1 x 23 struct array, each entry for the 23 sessions recorded for `Engelhard et al. 2019 paper. <https://www.nature.com/articles/s41586-019-1261-9>`_ 

Relevant fields include: 

- ``folder``: mouse #/date for the given session.

- ``good_tr``: ``1 x num_trials`` of the trial indices that are included if they meet some bar of good behavior. Note that all fields suffixed with ``_gd`` means that certain trials are dropped if they do not meet some bar of good behavior. 

- ``whole_trial_activity``: ``num_trials x 1`` cell array, each cell an ``num_timesteps x num_neurons `` matrix containing the whole trial activity of neurons recorded. Note that when ``NaN`` values appear when neuron becomes unstable and we were no longer able to record meaningful neural activity. 

- ``lr_cue_onset``: ``num_trials x 1`` cell array, each cell an ``num_timesteps x 2`` indicator matrix for when left (first column) and right (second column) appears. 

- ``all_choice_gd``: ``1 x num_trials`` row vector indicating mice's choice for the given session. 1 = left choice 2 = right choice.

- ``prev_choice_gd``: Same as ``all_choice_gd`` but for previous trial's choice. Note this is the *true* previous choice, taking into account that trials are dropped in ``all_choice_gd``. 

- ``is_succ_gd``: ``1 x num_trials`` indicator row vector for whether or not mice were rewarded. 

- ``prev_issucc_gd``: Same as ``is_succ_gd`` but for reward on previous trial. Note this is the *true* previous reward, taking into account that trials are dropped in ``is_succ_gd``. 

- ``allpos_cell_gd``: ``num_trials x 1`` cell array, each cell an ``num_timesteps x 3`` matrix containing the x-position (first column), y-position (second column), and view angle (third column) of the mouse. 

- ``allveloc_cell_gd``: Same as ``allpos_cell_gd``, but for x-direction, y-direction, and view angle velocity. 

- ``total_numcues``: ``num_trials x 1`` cell array, each cell a ``2 x 1`` matrix for total left and right cues. 

- ``prev_numcues``: Same as ``total_numcues`` but for previous trial's cues. Note that this takes into account that trials are dropped in ``total_numcues``. 




TODO: check with Ben on what the behavioral bar for dropping trials in _gd– if i recall correctly, it's when mice performance dropped to a degree they go to an easier maze. 


            

