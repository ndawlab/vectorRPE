
class VRShapingEnv2(gym.Env): # abstract towers counting task (visionless) 
#  metadata = {'render.modes': ['human']} #not sure what this is... 

  def __init__(self):
    # self.seed()
    # Define action and observation space
    # They must be gy   m.spaces objects
    self.action_space = spaces.Discrete(3)
    # Example for using image as input:
    self.observation_space = spaces.Box(low=0, high=1, shape=
                    (68, 120, 1), dtype=np.float) # original (1080,1920) (540, 960)

    self.trial_hallway = 0 # using numbers here so I can increment by 3 
    self.screens = scipy.io.loadmat('./screens/all_screens.mat')
    


  def step(self, action):
    done = 0
    reward = 0

    if self.trial_hallway < 4:
      if action < 2:# if it's left/right, you don't move
        screen = self.curr_screen
      else: # action 3 is to move forward
        self.trial_hallway += 1
        if self.trial_hallway < 4: # just progressing
          screen = self.screens['step' + str(self.trial_hallway)]
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

    # this is the two screen version!
    # done = 1
    # reward = int(action == self.trialType)

    # screen = self.curr_screen

    return (np.expand_dims(screen, 2), reward, done, {})
  


  def reset(self):
    screen = self.screens['opening']
    self.curr_screen = screen
    self.trial_hallway = 0
    self.trialType = random.randrange(2) # pick new trial


    # this is the two maze version 
    # self.trialType = random.randrange(2)
    # screen = self.screens['Cue' + str(self.trialType)]
    # self.curr_screen = screen
    return np.expand_dims(screen, 2)

def get_images(self):
    screen = self.curr_screen  
    return screen


def seed(self, seed=None):
    self.np_random, seed = seeding.np_random(seed)
    return [seed]


class VRShapingEnv3(gym.Env): #visionless improved 
#  metadata = {'render.modes': ['human']} #not sure what this is... 

  def __init__(self):
    # self.seed()
    # forward, left, right only 
    self.track_len = 8
    self.tower_len = 5
    self.tower_prob = 0.3
    self.action_space = spaces.Discrete(3)
    # Example for using image as input:
    self.observation_space = spaces.Box(low=-1, high=2, shape=
                    (4, ), dtype=np.int64) # (HAS_ADVANCED, LAST_ACTION, LTOW, RTOW)
    self.curr_step = 0
    self.has_advanced = 0 # 0/1 for whether or not the agent has advanced
    self.towers = np.zeros((2, self.track_len))
    self.correct_side = 0    


  def step(self, action):
    done = False
    reward = 0
    self.has_advanced = 0

    if self.curr_step < 4:
      if action < 2:# if it's left/right, you don't move
        screen = self.towers[:, self.curr_step]
      else: # move forward
        self.curr_step += 1
        screen = self.towers[:, self.curr_step]
        self.has_advanced = 1


    elif self.curr_step == 4:
      if action == 3: # you can't move forward anymore, so you stay in place. 
        screen = self.towers[:, self.curr_step]

      else:
        screen = np.zeros((2, ))
        self.has_advanced = 1
        done = True
        if self.correct_side >= 0:
          reward = int(action == self.correct_side)
        else: # edge case of -1
          reward = 1

    screen = np.hstack((self.has_advanced, action, screen)) # (HAS_ADVANCED, LAST_ACTION, LTOW, RTOW)
    return (screen, reward, done, {})
  


  def reset(self):
    self.towers[:, :self.tower_len] = np.reshape(np.random.binomial(1, self.tower_prob, 2 * self.tower_len), (2, self.tower_len))
    num_towers = np.sum(self.towers, 1)
    
    if num_towers[0] == num_towers[1]:
      self.correct_side = -1; # special case, always right! np.random.binomial(1, 0.5)
    else:
      self.correct_side = np.argmax(num_towers)
    self.curr_step = 0 
    screen = np.hstack((0, -1, self.towers[:, self.curr_step])) # (HAS_ADVANCED, LAST_ACTION, LTOW, RTOW)
    return screen



def seed(self, seed=None):
    self.np_random, seed = seeding.np_random(seed)
    return [seed]


class VRShapingEnv4(gym.Env): # vision per frame fractional towers 
#  metadata = {'render.modes': ['human']} #not sure what this is... 

  def __init__(self):
    # self.seed()
    # Define action and observation space
    # They must be gy   m.spaces objects
    self.action_space = spaces.Discrete(6)
    # Example for using image as input:
    self.observation_space = spaces.Box(low=0, high=1, shape=
                    (68, 120, 1), dtype=np.float) # original (1080,1920) (540, 960)(68, 120, 1)
 
    self.eng = matlab.engine.start_matlab()
    self.tow_pos = self.eng.initializeVR(nargout=1)
    self.l_tow = np.squeeze(self.tow_pos[0])
    self.r_tow = np.squeeze(self.tow_pos[1])
    self.curr_y_pos = 0.0
    self.tow_counts = np.zeros((2,))
    self.watching_tow = np.zeros((2,))

    self.trial = 0
    self.thread_id = mp.current_process().pid
    self.start_time = time.time()


  def step(self, action):
    done = False
    reward = 0

    if action < 3:
      movement_py = [0, 0, 0, 0, 12.5]
      movement_py[3] = (-1 + action) * 5
    else:
      movement_py = [0, 0, -1, 0, 12.5]
      movement_py[3] = (-4 + action) * 5

    # if action < 2:
    #   movement_py = [0, 0, 0, 0, 12.5]
    #   movement_py[3] = (2 * action - 1) * 10
    # else:
    #   movement_py = [0, 0, -60, 0, 12.5]



    movement = matlab.double(movement_py)
    vr_status, self.curr_y_pos, self.tow_pos = self.eng.virmenEngine_step(movement, nargout=3)
    if self.tow_pos == -1: # intertrial 
      self.tow_counts = np.zeros((2,))
      # self.tow_counts[0] = -1
    else:
      self.l_tow = np.squeeze(self.tow_pos[0])  
      self.r_tow = np.squeeze(self.tow_pos[1]) 

      self.tow_counts[1] = np.sum(self.curr_y_pos >= self.r_tow)
      self.tow_counts[0] = np.sum(self.curr_y_pos >= self.l_tow) # towers appear 10 steps behind 

      # fractional towers

      self.watching_tow[1] = np.sum((self.curr_y_pos <= self.r_tow) & (self.r_tow <= self.curr_y_pos + 10))
      self.watching_tow[0] = np.sum((self.curr_y_pos <= self.l_tow) & (self.l_tow <= self.curr_y_pos + 10))
    if vr_status != -1:
      # start end of trial calls so that you can log the  action 
      done = True
      reward = vr_status
      screen = np.zeros((68, 120, 1))
      self.eng.virmenEndTrial(self.trial, self.thread_id, nargout=0)

      self.trial = self.trial + 1
    else:
      # gets the output 
      # 
      screen = self.eng.virmenGetFrame(1, nargout =1) # np.array()

      screen = np.expand_dims(np.array(screen._data).reshape(screen.size[::-1]).T, 2)

    return (screen, reward, done, {'tow_counts':self.tow_counts,'watching_tow': self.watching_tow, 'y_pos':self.curr_y_pos} )
  
  def close(self):
    self.eng.drawnow(nargout=0)
    self.eng.virmenOpenGLRoutines(2, nargout=0)


  def reset(self):
    # dummy movement
    # no_movement = matlab.double([0, 0, 0, 0, 12.5])
    # self.eng.virmenEngine_step(no_movement, nargout=0)
    
    screen = self.eng.virmenGetFrame(1, nargout =1) # np.array()

    screen = np.expand_dims(np.array(screen._data).reshape(screen.size[::-1]).T, 2)
    curr_time = time.time()
    self.curr_y_pos = 0
    if curr_time - self.start_time > 10000: # around 6 hours. i'll want to test that this actually clears the memory and can actually clear the process

      self.eng.drawnow(nargout = 0)
      self.eng.virmenOpenGLRoutines(2, nargout = 0)
      self.eng.quit()
      self.eng = matlab.engine.start_matlab()
      self.tow_pos = self.eng.initializeVR(nargout=1)
      self.l_tow = np.squeeze(self.tow_pos[0])
      self.r_tow = np.squeeze(self.tow_pos[1])
      

      self.start_time = time.time() # restart counter.

    return screen

  def render(self, mode='human', close=False):
    # screen = self.eng.virmenGetFrame(1, nargout =1) # np.array()

    # screen = np.expand_dims(np.array(screen._data).reshape(screen.size[::-1]).T, 2)    

    return

def get_images(self):
    screen = self.eng.virmenGetFrame(1, nargout =1) # np.array()

    screen = np.expand_dims(np.array(screen._data).reshape(screen.size[::-1]).T, 2)    
    return screen


def seed(self, seed=None):
    self.np_random, seed = seeding.np_random(seed)
    return [seed]