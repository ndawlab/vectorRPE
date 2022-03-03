A vector reward prediction error model explains dopaminergic heterogeneity
============================


This repo contains the code needed to reproduce the model and figures from the manuscript: `Lee et al. 2022 <https://www.biorxiv.org/content/10.1101/2022.02.28.482379v1>`_. The data needed to run the figure notebook will be available on figshare upon publication. 

Author
^^^^^^
Rachel Lee (rslee [at] princeton.edu)

Project Organization
^^^^^^^^^^^^^^^^^^^^
::

    │
    ├── figures                      <- Notebooks for recreating figure panels for the manuscript
    │   ├── Figure 2.ipynb           <- Psychometric curves for mouse and Vector RPEs, Scalar value from model plotted against trial difficulties 
    │   ├── Figure 3.ipynb           <- Vector RPE units and DAnergic neurons response during the cue period. 
    │   ├── Figure 4.ipynb           <- Vector RPEs reflected incidental high-dimensional visual inputs
    │   ├── Figure 5.ipynb           <- Cue responses in model and DAergic neurons reflected RPEs with respect to cues, rather than simply their presence.
    │   ├── Figure 6.ipynb           <- Vector RPE units and DAergic neurons response during outcome period. 
    │   ├── utils                    <- Matlab scripts and functions for recreating figure panels. 
    │
    ├── virmen                       <- Source code for ViRMEn graphic engine for simulating VR task 
    │
    ├── deepRL                       <- Source code for deep RL code, based on Stable Baselines Version <TODO: fill in> 
    │
    ├── vrenv                        <- Stable Baselines environment <TODO: discuss how to donwload> 
    │
    ├── requirements.txt             <- Python packages used in this project.
    
    
Installation Requirements 
^^^^^^^^^^^^

ViRMEn and the deep RL code can only be run on a windows desktop. ViRMEn source code is self-contained in the folder, and the version we use is the 2016-2-12 found `here <http://pni.princeton.edu/pni-software-tools/virmen-download>`_. The deep RL source code requires the `Stable Baselines package <https://stable-baselines.readthedocs.io/en/master/guide/install.html>`_ <TODO: version info for stable baselines>. 

Installation 
^^^^^^^^^^^^

To install the code through Github, open a terminal and run:

.. code-block:: bash

    pip install git+https://github.com/ndawlab/vectorRPE.git

Alternately, you can clone the repository and install locally:

.. code-block:: bash

    git clone https://github.com/ndawlab/vectorRPE
    cd vectorRPE
    pip install -e .

For convenience, we recommend setting up a virtual environment before running the code, to avoid any unpleasant version control issues or interactions with other projects you're working on. 
