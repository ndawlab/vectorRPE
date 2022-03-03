import gym
from gym import error, spaces, utils
from gym.utils import seeding
import numpy as np
import matlab.engine
# from gym.utils import # something is missing here! dammit this is why i need git!
import multiprocessing as mp
import scipy.io
import random
import pdb
import time
import os 


class VRShapingEnv(gym.Env):
#  metadata = {'render.modes': ['human']} #not sure what this is... 

  def __init__(self):
    # self.seed()
    # Define action and observation space
    # They must be gy   m.spaces objects
    self.action_space = spaces.Discrete(3)
    # Example for using image as input:
    self.observation_space = spaces.Box(low=0, high=1, shape=
                    (69, 120, 1), dtype=np.float) # original (1080,1920) (540, 960)(68, 120, 1)
 
    self.eng = matlab.engine.start_matlab()
    self.eng.initializeVR(nargout=0) # self.tow_pos = 
    # self.l_tow = np.squeeze(self.tow_pos[0])
    # self.r_tow = np.squeeze(self.tow_pos[1])
    self.curr_y_pos = 0.0
    self.tow_counts = np.zeros((2,))

    self.trial = 0
    self.thread_id = mp.current_process().pid
    self.start_time = time.time()
    self.post_trial_curr_step = 0
    self.POST_TRIAL_STEP = 8

    path = r'C:\\Users\\witten_goat\\Documents\\tankmousevr\\rachel\\stimulus_trains_PoissonBlocks_cnnlstm_full_transient_unique.mat'
    if time.time() - os.path.getmtime(path) > 3600: # created more than an hour ago. prevents multiple threads to re-generate
      self.eng.generate_stimuli(nargout=0)


  def step(self, action):
    done = False
    reward_signal = np.zeros((1, 120))

    movement_py = [0, 0, -1, 0, 12.5]
    if action < 2:
      movement_py[3] = (1 + action * -2) 



    if self.post_trial_curr_step:
      screen = np.zeros((69, 120, 1))
      reward = 0
      self.post_trial_curr_step += 1
      if self.post_trial_curr_step > self.POST_TRIAL_STEP:
        done = True
        self.eng.virmenEndTrial(self.trial, self.thread_id, nargout=1)
        self.trial = self.trial + 1
        
      return (screen, reward, done, {'tow_counts':self.tow_counts,'y_pos':self.curr_y_pos} )


    movement = matlab.double(movement_py)
    vr_status, self.curr_y_pos, self.tow_pos = self.eng.virmenEngine_step(movement, nargout=3)
    reward =  np.max((0, vr_status  - 1)) # vr status = 0:in_trial, -1:end_trial, 1,2: reward outcome
    if self.tow_pos == -1: # intertrial 
      self.tow_counts = np.zeros((2,))
      # self.tow_counts[0] = -1
    else:
      self.l_tow = np.squeeze(self.tow_pos[0])  
      self.r_tow = np.squeeze(self.tow_pos[1]) 
      self.tow_counts[1] = np.sum((self.curr_y_pos + 10) >= self.r_tow)
      self.tow_counts[0] = np.sum((self.curr_y_pos + 10) >= self.l_tow) # towers appear 10 steps behind 

    if vr_status == -1: # according to virmen, we are in set up trial
      self.post_trial_curr_step = 1
      screen = np.zeros((69, 120, 1))


    else:
      # gets the output 
      # 
      screen = self.eng.virmenGetFrame(1, nargout =1)
      screen = np.array(screen._data).reshape(screen.size[::-1]).T
      # gives one-hot with first two entries denoting no-rew, rew
      rew_info =  np.eye(120)[int(vr_status - 1)]
      screen = np.expand_dims(np.vstack((screen, rew_info)) , 2)

    return (screen, reward, done, {'tow_counts':self.tow_counts,'y_pos':self.curr_y_pos} )
  
  def close(self):
    self.eng.drawnow(nargout=0)
    self.eng.virmenOpenGLRoutines(2, nargout=0)


  def reset(self):

    
    screen = np.zeros((69, 120, 1))
    self.eng.virmen_renderWorld(nargout = 0)
    curr_time = time.time()
    self.curr_y_pos = 0
    self.post_trial_curr_step = 0


    if ((curr_time - self.start_time) > 10000) and self.eng.check_save_progress(nargout = 1): # around 3 hours. i'll want to test that this actually clears the memory and can actually clear the process

      self.eng.drawnow(nargout = 0)
      self.eng.virmenOpenGLRoutines(2, nargout = 0)
      self.eng.quit()
      self.eng = matlab.engine.start_matlab()
      path = r'C:\\Users\\witten_goat\\Documents\\tankmousevr\\rachel\\stimulus_trains_PoissonBlocks_cnnlstm_small_transient_unique.mat'
      if curr_time - os.path.getmtime(path) > 3600: # created more than an hour ago. prevents multiple threads to re-generate
        self.eng.generate_stimuli(nargout=0)
      self.eng.initializeVR(nargout=0) #self.tow_pos = 
      self.eng.virmen_renderWorld(nargout = 0)
      # self.l_tow = np.squeeze(self.tow_pos[0])
      # self.r_tow = np.squeeze(self.tow_pos[1])
      

      self.start_time = time.time() # restart counter.

    return screen

  def render(self, mode='human', close=False):
    # screen = self.eng.virmenGetFrame(1, nargout =1) # np.array()

    # screen = np.expand_dims(np.array(screen._data).reshape(screen.size[::-1]).T, 2)    

    return

def get_images(self):
    screen = np.vstack((self.eng.virmenGetFrame(1, nargout =1), np.zeros((1,120)))) 

    screen = np.expand_dims(np.array(screen._data).reshape(screen.size[::-1]).T, 2)    
    return screen


def seed(self, seed=None):
    self.np_random, seed = seeding.np_random(seed)
    return [seed]

