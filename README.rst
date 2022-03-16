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
