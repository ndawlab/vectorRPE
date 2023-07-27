import numpy as np
from VectorRPEAgent import VectorRPEAgent

np.random.seed(865612)  # Consistency


def build_phi_simple(num_states):
    """
    Automatically constructs a function variable that can be called to compute the feature decomposition of a
    given state.

    Parameters
    ----------
    num_states (int): Max number of states in the environment.

    Returns
    -------
    A function that accepts a state and returns a feature-vector for that state.
    """
    def phi_simple(state):
        state_vec = np.zeros(num_states)
        state_vec[state] = 1

        return state_vec

    return phi_simple


def softmax(vals, beta):
    """
    Computes the softmax distribution given a `beta` temperature parameter and a vector of values `vals`.
    Parameters
    ----------
    vals (np.ndarray): NumPy array of values.
    beta (float): Softmax inverse temperature.

    Returns
    -------
    Softmax distribution over `vals` induced by `beta`.
    """
    return np.exp(vals / beta) / np.sum(np.exp(vals / beta))


debug = False

# Bandit parameters
num_bandits = 2
bandit_probs = np.array([0.7, 0.1])

# Task parameters
num_trials = 20000
block_switch_interval = 5000
left_states = [3, 4, 5]  # state 0: start, state 1: rewarded, state 2: unrewarded, state 3: premotor
right_states = [left_states[-1] + 1 + i for i in range(len(left_states))]
state_paths = [left_states, right_states]
num_states = 3 + len(left_states) + len(right_states)
trial_len = 2 + len(left_states)

# Agent parameters
lr = 0.1
gamma = 0.95
sftmx_temp = 0.25

simple_features = num_states
simple_agent = VectorRPEAgent(simple_features, lr, gamma)
phi_simple = build_phi_simple(num_states)

da_simple = np.empty(num_trials, dtype=object)
states = np.empty(num_trials, dtype=object)

actions = np.zeros(num_trials)   # nan not a valid action
rewards = np.zeros(num_trials)
reward_trials = []
trial_times = np.zeros(num_trials + 1) - 1  # -1 obvious if something has gone wrong

# Simulate
tdx = 0
epoch = np.zeros(num_trials)
epoch_type = 0

trial_start_probability = 0.2
outcome_delay_probability = 0.05
for trial in range(num_trials):
    trial_da_simple = []
    trial_states = []
    if trial > 0 and trial % block_switch_interval == 0:
        bandit_probs = bandit_probs[::-1]
        epoch_type = 1 - epoch_type

    # Log epoch type
    epoch[trial] = epoch_type

    # Step zero: "lever presentation", starts with a random ITI
    state = 0
    trial_states.append(state)

    simple_state_rep = phi_simple(state)
    trial_da_simple.append(simple_agent.compute_delta_feat(np.zeros(simple_features), simple_state_rep, 0))

    while np.random.uniform(0, 1) >= trial_start_probability:  # random ITI, fixed probability for trial to start
        trial_da_simple.append(simple_agent.learn(simple_state_rep, simple_state_rep, 0))
        trial_states.append(state)

    # Step one: pick a bandit
    action = np.random.choice(2, p=softmax(bandit_probs, sftmx_temp))
    actions[trial] = action

    # Step two: propagate along paths
    for i in range(len(left_states)):
        simple_succ_state_rep = phi_simple(state_paths[action][i])
        trial_da_simple.append(simple_agent.learn(simple_state_rep, simple_succ_state_rep, 0))

        trial_states.append(state_paths[action][i])

        # Update
        simple_state_rep = simple_succ_state_rep

    # Step two and a half: chill out at the final path state for some time (variable outcome delivery)
    while np.random.uniform(0, 1) >= outcome_delay_probability:
        trial_da_simple.append(simple_agent.learn(simple_state_rep, simple_state_rep, 0))
        trial_states.append(trial_states[-1])

    # Step three: move to relevant reward state
    rew_prob = bandit_probs[action]
    if np.random.uniform(0, 1) < rew_prob:
        reward = 1
    else:
        reward = 0

    rewards[trial] = reward

    if reward == 1:
        reward_trials.append(trial)
        state = 1  # reward state
    elif reward == 0:
        state = 2  # unrewarded state
    else:
        quit()

    simple_succ_state_rep = phi_simple(state)

    # Learn
    trial_da_simple.append(simple_agent.learn(simple_state_rep, simple_succ_state_rep, reward))
    trial_states.append(state)

    # Store DA
    da_simple[trial] = trial_da_simple
    states[trial] = trial_states

if not debug:
    np.savez('./data/parker/RPE/DA.npz', da_simple=da_simple, reward_mags=bandit_probs,
             temp=sftmx_temp, actions=actions, trial_times=trial_times, block_switch_interval=block_switch_interval,
             epoch=epoch, rewards=rewards, reward_trials=reward_trials, states=states)









