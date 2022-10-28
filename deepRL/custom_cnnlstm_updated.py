import gym
import numpy as np
import pdb 

import torch as th
from torch import nn

from stable_baselines3 import PPO
from stable_baselines3.common.preprocessing import is_image_space
from stable_baselines3.common.policies import ActorCriticPolicy
from stable_baselines3.common.torch_layers import (
    BaseFeaturesExtractor,
    CombinedExtractor,
    FlattenExtractor,
    MlpExtractor,
    NatureCNN,
)
from sb3_contrib import RecurrentPPO
from sb3_contrib.ppo_recurrent.policies import RecurrentActorCriticPolicy
from stable_baselines3.common.logger import configure
from stable_baselines3.common.callbacks import CheckpointCallback
from stable_baselines3.common.vec_env import DummyVecEnv, SubprocVecEnv
from stable_baselines3.common.monitor import Monitor
from stable_baselines3.common.env_checker import check_env
import os
import subprocess

import pickle

from gym.envs.registration import register
register(
    id='vrgym-v0',
    entry_point='gym_vr.envs:VRShapingEnv',
)

log_path = './logs/sb3_simple/'
env_id = 'vrgym-v0'
tb_log_name = 'test_try'

# load_path = './logs/VA_maze_v4/final_model'
save_freq = 1e5# PREVIOUSLY 1e5 AND SHOULD CHANGE BACK



# restore = './logs/cnn_towers-debugged_full_best/'

# weight_dict = pickle.load(open(restore + 'final_weights.p', 'rb'))

configure(log_path + 'tensorboard2/', ['stdout', 'log', 'csv', 'tensorboard']) # need this to log to tensorboard 

def make_env(env_id, rank):
    """
    Utility function for multiprocessed env.
    
    :param env_id: (str) the environment ID
    :param num_env: (int) the number of environment you wish to have in subprocesses
    :param seed: (int) the inital seed for RNG
    :param rank: (int) index of the subprocess
    """
    def _init():
        env = gym.make(env_id)
        check_env(env)
        env = Monitor(env, log_path + 'tensorboard2/' + str(rank)) # need this on to turn on old school monitoring of eplen, ep_rewmean 
    
        return env
    return _init


checkpoint_callback = CheckpointCallback(save_freq=int(save_freq), save_path=log_path + 'checkpoints/',
                                         name_prefix='rl_model') 


num_cpu = 2

# class RecurrentActorCriticCnnPolicy(RecurrentActorCriticPolicy):
#     # def __init__(self, sess, ob_space, ac_space, n_env, n_steps, n_batch, n_lstm=128, reuse=False, **_kwargs):
#     #     super().__init__(sess, ob_space, ac_space, n_env, n_steps, n_batch, n_lstm, reuse,
#     #                      net_arch=['lstm', dict(vf=[40], pi=[40])],
#     #                      cnn_extractor=nature_cnn_best_rewinput, **_kwargs)

#     def __init__(self, *args, **kwargs):
#         super(RecurrentActorCriticCnnPolicy, self).__init__(features_extractor_class = nature_cnn_best_rewinput,
#                                                             net_arch=['lstm', dict(pi=[64], vf=[64])],
#                                                             lstm_hidden_size = 128, n_lstm_layers = 1, shared_lstm = True)

policy_kwargs = dict(features_extractor_class= NatureCNN, features_extractor_kwargs=dict(features_dim=128))

#CNN retrain 

if __name__ == "__main__":
    env = SubprocVecEnv([make_env('vrgym-v0', i) for i in range(num_cpu)])

    model = RecurrentPPO("CnnLstmPolicy", env, verbose =1, policy_kwargs = policy_kwargs, learning_rate = 2.5e-4, n_steps=140, tensorboard_log=log_path + 'tensorboard/')
    # model = A2C.load(load_path, env, verbose = 1,#  policy_kwargs = policy_kwargs,  
    #     learning_rate = 2.5e-4, n_steps=140, 
    #     tensorboard_log=log_path + 'tensorboard/')
    model.learn(int(1000),callback = checkpoint_callback)
    model.save(log_path + '/final_model')