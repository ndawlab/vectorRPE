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

env = gym.make('vrgym-v0')

check_env(env)

policy_kwargs = dict(features_extractor_class= NatureCNN, features_extractor_kwargs=dict(features_dim=128), 
                     shared_lstm = True, enable_critic_lstm = False)

model = RecurrentPPO("CnnLstmPolicy", env, verbose =1, policy_kwargs = policy_kwargs, learning_rate = 2.5e-4, n_steps=140)


######################################


# import gym

# from stable_baselines3 import A2C

# env = gym.make("CartPole-v1")

# model = A2C("MlpPolicy", env, verbose=1)
# model.learn(total_timesteps=10_000)

# obs = env.reset()
# for i in range(1000):
#     action, _state = model.predict(obs, deterministic=True)
#     obs, reward, done, info = env.step(action)
#     env.render()
#     if done:
#       obs = env.reset()

