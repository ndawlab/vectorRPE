import gym
from gym import error, spaces, utils
from gym.utils import seeding
import numpy as np
import matlab.engine
from gym.utils import seeding
import multiprocessing as mp
import scipy.io
import random
import pdb


class VRShapingEnv2(gym.Env):
#  metadata = {'render.modes': ['human']} #not sure what this is... 

  def __init__(self):
    # self.seed()
    # Define action and observation space
    # They must be gy   m.spaces objects
    self.action_space = spaces.Discrete(3)
    # Example for using image as input:
    self.observation_space = spaces.Box(low=0, high=255, shape=
                    (68, 120, 1), dtype=np.uint8) # original (1080,1920) (540, 960)

    self.trial_hallway = 0 # using numbers here so I can increment by 3 
    self.screens = scipy.io.loadmat('./screens/all_screens.mat')
    self.curr_screen = self.screens['opening']
    self.trialType = random.randrange(2)


  def step(self, action):
    done = 0
    reward = 0
    if self.trial_hallway == 0:
      print('something is wrong, reset should be called first')
    if self.trial_hallway < 4:
      if action < 2:# if it's left/right, you don't move
        screen = self.curr_screen
      else: # action 3 is to move forward
        self.trial_hallway += 1
        if self.trial_hallway < 4: # just progressing
          screen=self.screens['step' + str(trial_hallway)]
          self.curr_screen = screen
        else: # now at the end of the hallway
          screen = self.screens['Cue' + str(self.trialType)]
          self.curr_screen = screen

    elif self.trial_hallway == 4:
      if action == 3:
        screen = self.curr_screen
      else:
        screen = np.zeros((68, 120))
        trial_hallway = 0
        done = 1
        reward = int(action == self.trialType)
        self.trialType = random.randrange(2) # pick new trial





    return (screen, reward, done, {})
  


  def reset(self):
    # dummy movement
    screen = self.screens['opening']
    self.curr_screen = screen
    self.trial_start = False
    self.trial_hallway = 1
    return screen



def seed(self, seed=None):
    self.np_random, seed = seeding.np_random(seed)
    return [seed]
