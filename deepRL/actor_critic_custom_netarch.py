
import gym

import numpy as np
from stable_baselines.common.policies import CnnPolicy, LstmPolicy, RecurrentActorCriticPolicy, MlpLstmPolicy, CnnLstmPolicy, nature_cnn
from stable_baselines.common.policies import ActorCriticPolicy
from stable_baselines.common.vec_env import DummyVecEnv, SubprocVecEnv
from stable_baselines import A2C
from stable_baselines.common import set_global_seeds
from stable_baselines.common.env_checker import check_env
from stable_baselines.common.callbacks import CheckpointCallback
from stable_baselines.common.callbacks import EvalCallback, StopTrainingOnRewardThreshold
from stable_baselines.logger import configure
from   stable_baselines.common.callbacks import BaseCallback
from stable_baselines.common.evaluation import evaluate_policy
import pdb 
from stable_baselines.bench import Monitor
import os
import subprocess

import pickle
import pdb

import tensorflow as tf
from stable_baselines.common.tf_util import batch_to_seq, seq_to_batch
from stable_baselines.common.tf_layers import conv, linear, conv_to_fc, lstm
from gym.envs.registration import register
register(
    id='vrgym-v0',
    entry_point='gym_vr.envs:VRShapingEnv',
)

log_path = './logs/buggymodelscope/'
env_id = 'vrgym-v0'
tb_log_name = 'test_try'

# load_path = './logs/VA_maze_v4/final_model'
save_freq = 10000 # PREVIOUSLY 1e5 AND SHOULD CHANGE BACK
# how often interim weights are saved



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
        env = Monitor(env, log_path + 'tensorboard2/' + str(rank)) # need this on to turn on old school monitoring of eplen, ep_rewmean 
    
        return env
    return _init


def nature_cnn_best_rewinput(processed_obs, **kwargs):
    """
    CNN from Nature paper.

    :param scaled_images: (TensorFlow Tensor) Image input placeholder
    :param kwargs: (dict) Extra keywords parameters for the convolutional layers of the CNN
    :return: (TensorFlow Tensor) The CNN output layer
    """
    scaled_images = processed_obs[:, :-1, :, :]
    rew_info =  processed_obs[:,-1, :2, 0]


    activ = tf.nn.relu
    layer_1 = activ(conv(scaled_images, 'c1', n_filters=64, filter_size=8 , stride=2, init_scale=np.sqrt(2), **kwargs))
    layer_2 = activ(conv(layer_1, 'c2', n_filters=32, filter_size=2 , stride=1, init_scale=np.sqrt(2), **kwargs))
    layer_3 = activ(conv(layer_2, 'c3', n_filters=64, filter_size=3 , stride=2, init_scale=np.sqrt(2), **kwargs))
    layer_3 = conv_to_fc(layer_3)
    return tf.concat([activ(linear(layer_3, 'fc1', n_hidden=128, init_scale=np.sqrt(2))), rew_info], axis = 1)


checkpoint_callback = CheckpointCallback(save_freq=int(save_freq), save_path=log_path + 'checkpoints/',
                                         name_prefix='rl_model') 

num_cpu = 2

# policy_kwargs = dict(n_lstm=64, cnn_extractor = nature_cnn_best_rewinput)


class Custom_CnnLstm(RecurrentActorCriticPolicy):

	def __init__(self, sess, ob_space, ac_space, n_env, n_steps, n_batch, n_lstm=128, reuse=False, layer_norm=False, cnn_extractor=nature_cnn_best_rewinput, feature_extraction="cnn", **_kwargs):
		
		super(Custom_CnnLstm, self).__init__(sess, ob_space, ac_space, n_env, n_steps, n_batch, 
									  	     state_shape=(2 * n_lstm, ), reuse = reuse, scale=(feature_extraction == "cnn"))
	
		# pdb.set_trace()
		with tf.variable_scope("model", reuse=reuse):

			if feature_extraction == "cnn":
				latent = cnn_extractor(self.processed_obs, **_kwargs) # hits ValueError here with pdb
				latent = tf.layers.flatten(latent)
			else:
				latent = tf.layers.flatten(self.processed_obs)
			
			net_arch=['lstm', dict(pi=[40], vf=[40])]
			policy_only_layers = []  # Layer sizes of the network that only belongs to the policy network
			value_only_layers = []  # Layer sizes of the network that only belongs to the value network

	        # Iterate through the shared layers and build the shared parts of the network
			lstm_layer_constructed = False
			# pdb.set_trace()
			for idx, layer in enumerate(net_arch):
				if isinstance(layer, int): # Check that this is a shared layer
					layer_size = layer
					latent = tf.tanh(linear(latent, "shared_fc{}".format(idx), layer_size, init_scale=np.sqrt(2)))
				elif layer == "lstm":
					if lstm_layer_constructed:
						raise ValueError("The net_arch parameter must only contain one occurrence of 'lstm'!")
					input_sequence = batch_to_seq(latent, self.n_env, n_steps)
					masks = batch_to_seq(self.dones_ph, self.n_env, n_steps)
					rnn_output, self.snew = lstm(input_sequence, masks, self.states_ph, 'lstm1', n_hidden=n_lstm, layer_norm=layer_norm)
					latent = seq_to_batch(rnn_output)
					lstm_layer_constructed = True
				else:
					assert isinstance(layer, dict), "Error: the net_arch list can only contain ints and dicts"
					if 'pi' in layer:
						assert isinstance(layer['pi'], list), "Error: net_arch[-1]['pi'] must contain a list of integers."
						policy_only_layers = layer['pi']

					if 'vf' in layer:
						assert isinstance(layer['vf'], list), "Error: net_arch[-1]['vf'] must contain a list of integers."
						value_only_layers = layer['vf']
					break  # From here on the network splits up in policy and value network

	        # Build the non-shared part of the policy-network
			latent_policy = latent
			for idx, pi_layer_size in enumerate(policy_only_layers):
				if pi_layer_size == "lstm":
					raise NotImplementedError("LSTMs are only supported in the shared part of the policy network.")
				assert isinstance(pi_layer_size, int), "Error: net_arch[-1]['pi'] must only contain integers."
				latent_policy = tf.tanh(linear(latent_policy, "pi_fc{}".format(idx), pi_layer_size, init_scale=np.sqrt(2)))

	        # Build the non-shared part of the value-network
			latent_value = latent
			for idx, vf_layer_size in enumerate(value_only_layers):
				if vf_layer_size == "lstm":
					raise NotImplementedError("LSTMs are only supported in the shared part of the value function "
	                                              "network.")
				assert isinstance(vf_layer_size, int), "Error: net_arch[-1]['vf'] must only contain integers."
				latent_value = tf.tanh(linear(latent_value, "vf_fc{}".format(idx), vf_layer_size, init_scale=np.sqrt(2)))

			if not lstm_layer_constructed:
				raise ValueError("The net_arch parameter must contain at least one occurrence of 'lstm'!")

			self._value_fn = linear(latent_value, 'vf', 1)
	        # TODO: why not init_scale = 0.001 here like in the feedforward
			self._proba_distribution, self._policy, self.q_value = \
				self.pdtype.proba_distribution_from_latent(latent_policy, latent_value)
	
		self._setup_init()

	def step(self, obs, state=None, mask=None, deterministic=False):
		if deterministic:
			return self.sess.run([self.deterministic_action, self.value_flat, self.snew, self.neglogp],
                                 {self.obs_ph: obs, self.states_ph: state, self.dones_ph: mask})
		else:
			return self.sess.run([self.action, self.value_flat, self.snew, self.neglogp],
                                 {self.obs_ph: obs, self.states_ph: state, self.dones_ph: mask})

	def proba_step(self, obs, state=None, mask=None):
		return self.sess.run(self.policy_proba, {self.obs_ph: obs, self.states_ph: state, self.dones_ph: mask})

	def value(self, obs, state=None, mask=None):
		return self.sess.run(self.value_flat, {self.obs_ph: obs, self.states_ph: state, self.dones_ph: mask})
    

#CNN retrain 

if __name__ == "__main__":
    env = SubprocVecEnv([make_env('vrgym-v0', i) for i in range(num_cpu)])

    model = A2C(Custom_CnnLstm, env, verbose =1, 
        learning_rate = 2.5e-4, n_steps=140,
        tensorboard_log=log_path + 'tensorboard/')
    # model = A2C.load(load_path, env, verbose = 1,
    #     learning_rate = 2.5e-4, n_steps=140, 
    #     tensorboard_log=log_path + 'tensorboard/')
    model.learn(int(1000)) # ,callback = checkpoint_callback)
    model.save(log_path + '/final_model')