
import gym
import numpy as np

from stable_baselines.common.policies import CnnPolicy, MlpLstmPolicy, CnnLstmPolicy
from stable_baselines.common.vec_env import DummyVecEnv, SubprocVecEnv
from stable_baselines import A2C
from stable_baselines.common import set_global_seeds
from stable_baselines.common.env_checker import check_env
from stable_baselines.common.callbacks import CheckpointCallback
from stable_baselines.common.callbacks import EvalCallback, StopTrainingOnRewardThreshold
from stable_baselines.logger import configure
from stable_baselines.common.callbacks import BaseCallback
from stable_baselines.common.evaluation import evaluate_policy
import pdb 
from stable_baselines.bench import Monitor
import os
import subprocess
from stable_baselines.common.vec_env import VecEnv

import os
import zipfile
import io

def get_params_from_zip(load_path):
    model_file = zipfile.ZipFile(load_path + '.zip', "r")
    parameter_bytes = model_file.read("parameters")
    parameter_buffer = io.BytesIO(parameter_bytes)
    parameters = dict(np.load(parameter_buffer))
    model_file.close()
    return parameters

def evaluate_policy_more(model, env, n_eval_episodes=10, 
                    render=False, callback=None, reward_threshold=None,
                    return_episode_rewards=False):
    """
    Runs policy for `n_eval_episodes` episodes and returns average reward.
    This is made to work only with one env.

    :param model: (BaseRLModel) The RL agent you want to evaluate.
    :param env: (gym.Env or VecEnv) The gym environment. In the case of a `VecEnv`
        this must contain only one environment.
    :param n_eval_episodes: (int) Number of episode to evaluate the agent
    :param deterministic: (bool) Whether to use deterministic or stochastic actions
    :param render: (bool) Whether to render the environment or not
    :param callback: (callable) callback function to do additional checks,
        called after each step.
    :param reward_threshold: (float) Minimum expected reward per episode,
        this will raise an error if the performance is not met
    :param return_episode_rewards: (bool) If True, a list of reward per episode
        will be returned instead of the mean.
    :return: (float, float) Mean reward per episode, std of reward per episode
        returns ([float], [int]) when `return_episode_rewards` is True
    """
    if isinstance(env, VecEnv):
        assert env.num_envs == 1, "You must pass only one environment when using this function"

    episode_rewards, episode_lengths, ep_tow_counts = [], [], []
    for _ in range(n_eval_episodes):
        obs = env.reset()
        done, state = False, None
        episode_reward = 0.0
        episode_length = 0
        tow_counts = np.zeros((2,))
        while not done:
            action, state = model.predict(obs, state=state)
            obs, reward, done, info = env.step(action)
            episode_reward += reward
            tow_counts = np.maximum(tow_counts, info[0]['tow_counts']) # weird bug that needs to copy the output so that it will track tow_counts
            
            if callback is not None:
                callback(locals(), globals())
            episode_length += 1
            if render:
                env.render()
        ep_tow_counts.append( tow_counts) 
        episode_rewards.append(episode_reward)
        episode_lengths.append(episode_length)

    mean_reward = np.mean(episode_rewards)
    std_reward = np.std(episode_rewards)

    if reward_threshold is not None:
        assert mean_reward > reward_threshold, 'Mean reward below threshold: '\
                                         '{:.2f} < {:.2f}'.format(mean_reward, reward_threshold)
    if return_episode_rewards:
        return np.squeeze(episode_rewards), np.squeeze(episode_lengths), np.squeeze(ep_tow_counts)
    return mean_reward, std_reward
from stable_baselines.common.vec_env import VecEnv

# Tanh_2 gives us the ACTION features, Tanh_3 gives us the VALUE features
# concat_2 still gives us the overall features 
def get_a2c_model_data(model, env, n_eval_episodes=10, by_ep = False, obses_ep_saved = 10):
    if isinstance(env, VecEnv):
        assert env.num_envs == 1, "You must pass only one environment when using this function"

    actions, rewards, obses, feats, featsPI, featsV, terms, vs, tow_counts = [], [], [], [], [], [], [], [], []
    episode_lengths = np.zeros((n_eval_episodes))
    [graph, sess] = model.get_graph_and_sess()
    state_ph_shape = graph.get_tensor_by_name("input_1/states_ph:0").shape
    dones_ph_shape = graph.get_tensor_by_name("input_1/dones_ph:0").shape
    for ep in range(n_eval_episodes):
        obs = env.reset()
        done = np.zeros((dones_ph_shape))
        state = np.zeros((state_ph_shape))
        episode_length = 0

        while not done:

            if ep < obses_ep_saved:
                obses.append(obs)
            feats.append(graph.get_tensor_by_name("model/concat_2:0").eval(
                {"input/Ob:0":obs, "input_1/dones_ph:0":done
                , "input_1/states_ph:0":state}, session = sess))
            featsPI.append(graph.get_tensor_by_name("model/Tanh_2:0").eval(
                {"input/Ob:0":obs, "input_1/dones_ph:0":done
                , "input_1/states_ph:0":state}, session = sess))
            featsV.append(graph.get_tensor_by_name("model/Tanh_3:0").eval(
                {"input/Ob:0":obs, "input_1/dones_ph:0":done
                , "input_1/states_ph:0":state}, session = sess))
            vs.append(model.value(obs, state = state, mask = done))
            action, state = model.predict(obs, state=state)
            actions.append(action)
            obs, reward, done, info = env.step(action)
            rewards.append(reward)
            terms.append(done[0])
            tows = np.copy(info[0]['tow_counts'])
            tow_counts.append(tows)
            episode_length += 1
            


        episode_lengths[ep] = episode_length
    all_metrics = [actions, rewards, feats, featsPI, featsV, terms, vs, tow_counts]
    if by_ep:
        ep_idx = np.cumsum(episode_lengths)[:-1].astype(int)
        [actions, rewards, feats, featsPI, featsV, terms, vs, tow_counts] = [np.split(np.squeeze(x), ep_idx, axis = 0) for x in all_metrics]
        obses = np.split(np.squeeze(obses), ep_idx[:obses_ep_saved], axis = 0)
    else:
        [actions, rewards, feats, featsPI, featsV,terms, vs, tow_counts] = [np.squeeze(x) for x in all_metrics]
        obses = np.squeeze(obses)
    return [actions, rewards, obses, feats, featsPI, featsV, terms, vs, tow_counts, episode_lengths]

        

# Relu_3 is feature output (not including the rewinfo for the custom cnn lstm. for that, it's Reshape_1) 
# concat_1 is the lstm output for cnnlstm; concat_2 for custom cnn lstm 
def get_model_data(model, env, n_eval_episodes=10, by_ep = False, obses_ep_saved = 10):
    if isinstance(env, VecEnv):
        assert env.num_envs == 1, "You must pass only one environment when using this function"

    actions, rewards, obses, feats, terms, vs, tow_counts, ypositions = [], [], [], [], [], [], [], []
    episode_lengths = np.zeros((n_eval_episodes))
    [graph, sess] = model.get_graph_and_sess()
    state_ph_shape = graph.get_tensor_by_name("input_1/states_ph:0").shape
    dones_ph_shape = graph.get_tensor_by_name("input_1/dones_ph:0").shape
    for ep in range(n_eval_episodes):
        obs = env.reset()
        done = np.zeros((dones_ph_shape))
        state = np.zeros((state_ph_shape))
        episode_length = 0

        while not done:

            if ep < obses_ep_saved:
                obses.append(obs)
            feats.append(graph.get_tensor_by_name("model/concat_2:0").eval(
                {"input/Ob:0":obs, "input_1/dones_ph:0":done
                , "input_1/states_ph:0":state}, session = sess))
            # cnn_feats.append(graph.get_tensor_by_name("model/Relu_3:0").eval(
            #     {"input/Ob:0":obs, "input_1/dones_ph:0":done
            #     , "input_1/states_ph:0":state}, session = sess))
            vs.append(model.value(obs, state = state, mask = done))
            action, state = model.predict(obs, state=state)
            actions.append(action)
            obs, reward, done, info = env.step(action)
            rewards.append(reward)
            terms.append(done[0])
            tows = np.copy(info[0]['tow_counts'])
            tow_counts.append(tows)
            episode_length += 1
            


        episode_lengths[ep] = episode_length
    all_metrics = [actions, rewards, feats, terms, vs, tow_counts, ypositions]
    if by_ep:
        ep_idx = np.cumsum(episode_lengths)[:-1].astype(int)
        [actions, rewards, feats, terms, vs, tow_counts, ypositions] = [np.split(np.squeeze(x), ep_idx, axis = 0) for x in all_metrics]
        obses = np.split(np.squeeze(obses), ep_idx[:obses_ep_saved], axis = 0)
    else:
        [actions, rewards, feats, terms, vs, tow_counts, ypositions] = [np.squeeze(x) for x in all_metrics]
        obses = np.squeeze(obses)
    return [actions, rewards, obses, feats,  terms, vs, tow_counts, episode_lengths, ypositions]
        

def run_down_track(model, env, n_eval_episodes=10, by_ep = False):


    actions, rewards, obses, feats, terms, vs, tow_counts, ypositions = [], [], [], [], [], [], [], []
    episode_lengths = np.zeros((n_eval_episodes))
    [graph, sess] = model.get_graph_and_sess()
    state_ph_shape = graph.get_tensor_by_name("input_1/states_ph:0").shape
    dones_ph_shape = graph.get_tensor_by_name("input_1/dones_ph:0").shape
    for ep in range(n_eval_episodes):
        obs = env.reset()
        done = np.zeros((dones_ph_shape))
        state = np.zeros((state_ph_shape))

        episode_length = 0
        curr_y_pos = 0

        while not done:
            obses.append(obs)
            feats.append(graph.get_tensor_by_name("model/concat_2:0").eval(
                {"input/Ob:0":obs, "input_1/dones_ph:0":done
                , "input_1/states_ph:0":state}, session = sess))
            vs.append(model.value(obs, state = state, mask = done))
            action, state = model.predict(obs, state=state)
            if curr_y_pos < 85:
                action = [3]
            else:
                action = [0] # always turn left for now 

            actions.append(action)
            obs, reward, done, info = env.step(action)

            rewards.append(reward)
            terms.append(done[0])
            tows = np.copy(info[0]['tow_counts'])
            curr_y_pos = np.copy(info[0]['y_pos'])
            ypositions.append(curr_y_pos)
            tow_counts.append(tows)
            episode_length += 1
              


        episode_lengths[ep] = episode_length
    all_metrics = [actions, rewards, obses, feats, terms, vs, tow_counts, ypositions]
    if by_ep:
        ep_idx = np.cumsum(episode_lengths)[:-1].astype(int)
        [actions, rewards, obses, feats, terms, vs, tow_counts, ypositions] = [np.split(np.squeeze(x), ep_idx, axis = 0) for x in all_metrics]
    else:
        [actions, rewards, obses, feats, terms, vs, tow_counts, ypositions] = [np.squeeze(x) for x in all_metrics]
    return [actions, rewards, obses, feats, terms, vs, tow_counts, episode_lengths, ypositions]

    
    



# for stable baselines
# model.action_proba gives you the action probabilities
# "model/vf/add:0" or model.value gives you the value
# "model/Relu_3:0" should give you the features. Might want to double check this 
# 'model/q' is an artifact to be used in other models. should ignore

def make_env(env_id, rank, seed=0):
    """
    Utility function for multiprocessed env.
    
    :param env_id: (str) the environment ID
    :param num_env: (int) the number of environment you wish to have in subprocesses
    :param seed: (int) the inital seed for RNG
    :param rank: (int) index of the subprocess
    """
    def _init():
        env = gym.make(env_id)
        env.seed(seed + rank)
    
        return env
    set_global_seeds(seed)
    return _init






# num_cpu = 1

# policy_kwargs = dict(n_lstm=64, cnn_extractor = supervised_utils.nature_cnn_best)


# if __name__ == "__main__":
#     env = SubprocVecEnv([make_env('vrgym-v0', i) for i in range(num_cpu)])
#     model = A2C(CnnLstmPolicy, env, verbose =1, policy_kwargs = policy_kwargs,  
#             learning_rate = 2.5e-4, n_steps=180)

#     mean_reward, std_reward = evaluate_policy(model, env, n_eval_episodes=100)

#     print(f"mean_reward:{mean_reward:.2f} +/- {std_reward:.2f}")