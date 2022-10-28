
import gym
from gym import error, spaces, utils
from gym.utils import seeding
import numpy as np
from numpy import expand_dims
import matlab.engine
import multiprocessing as mp
import scipy.io
import random
import pdb
import time
import os
import matplotlib.pyplot as plt



eng = matlab.engine.start_matlab()

eng.initializeVR(nargout=0) 
eng.virmen_renderWorld(nargout = 0)
screen = eng.virmenGetFrame(1, nargout =1)

# screen = np.array(screen._data).reshape(screen.size[::-1]).T

screen = expand_dims(np.array(screen), axis = 0)


screen
plt.imshow(screen)
plt.show()


# screen = np.expand_dims(np.vstack((screen, np.zeros(120))) , 2)


screen.shape


