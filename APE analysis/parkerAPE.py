import numpy as np
from VectorRPEAgent import VectorRPEAgent
from ScalarRPEAgent import ScalarRPEAgent

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
gamma = 0.5
sftmx_temp = 0.25

simple_features = num_states
left_agent = VectorRPEAgent(simple_features, lr, gamma)
right_agent = VectorRPEAgent(simple_features, lr, gamma)

left_scal_agent = ScalarRPEAgent(num_states, lr, gamma)
right_scal_agent = ScalarRPEAgent(num_states, lr, gamma)

phi_simple = build_phi_simple(num_states)
da_left = np.empty(num_trials, dtype=object)
da_right = np.empty(num_trials, dtype=object)
scal_da_left = np.empty(num_trials, dtype=object)
scal_da_right = np.empty(num_trials, dtype=object)

states = np.empty(num_trials, dtype=object)

actions = np.zeros(num_trials)   # nan not a valid action
rewards = np.zeros(num_trials) - 1
reward_trials = []
trial_times = np.zeros(num_trials + 1) - 1  # -1 obvious if something has gone wrong

# Simulate
tdx = 0
epoch = np.zeros(num_trials)
epoch_type = 0

trial_start_probability = 0.2
outcome_delay_probability = 0.05
for trial in range(num_trials):
    trial_da_left = []
    trial_da_right = []
    trial_scal_da_left = []
    trial_scal_da_right = []
    trial_states = []

    if trial > 0 and trial % block_switch_interval == 0:
        bandit_probs = bandit_probs[::-1]
        epoch_type = 1 - epoch_type

    # Log epoch type
    epoch[trial] = epoch_type

    # Step zero: "lever presentation"
    state = 0
    simple_state_rep = phi_simple(state)
    trial_states.append(state)

    trial_da_left.append(left_agent.compute_delta_feat(np.zeros(simple_features), simple_state_rep, 0))
    trial_da_right.append(right_agent.compute_delta_feat(np.zeros(simple_features), simple_state_rep, 0))
    trial_scal_da_left.append(left_scal_agent.val(state))
    trial_scal_da_right.append(right_scal_agent.val(state))

    while np.random.uniform(0, 1) >= trial_start_probability:  # random ITI, fixed probability for trial to start
        trial_da_left.append(left_agent.learn(simple_state_rep, simple_state_rep, 0))
        trial_da_right.append(right_agent.learn(simple_state_rep, simple_state_rep, 0))
        trial_scal_da_left.append(left_scal_agent.learn(state, state, 0))
        trial_scal_da_right.append(right_scal_agent.learn(state, state, 0))
        trial_states.append(state)

    # Step one: pick a bandit
    action = np.random.choice(2, p=softmax(bandit_probs, sftmx_temp))
    actions[trial] = action

    # Step two: propagate along paths
    left_reward = int(action == 0)
    right_reward = int(action == 1)
    for i in range(len(left_states)):
        simple_succ_state_rep = phi_simple(state_paths[action][i])

        if i == 1:  # on the second step we have performed the action and so gotten the "action reward"
            trial_da_left.append(left_agent.learn(simple_state_rep, simple_succ_state_rep, left_reward))
            trial_da_right.append(right_agent.learn(simple_state_rep, simple_succ_state_rep, right_reward))
            trial_scal_da_left.append(left_scal_agent.learn(state, state_paths[action][i], left_reward))
            trial_scal_da_right.append(right_scal_agent.learn(state, state_paths[action][i], right_reward))
        else:
            trial_da_left.append(left_agent.learn(simple_state_rep, simple_succ_state_rep, 0))
            trial_da_right.append(right_agent.learn(simple_state_rep, simple_succ_state_rep, 0))
            trial_scal_da_left.append(left_scal_agent.learn(state, state_paths[action][i], 0))
            trial_scal_da_right.append(right_scal_agent.learn(state, state_paths[action][i], 0))

        trial_states.append(state_paths[action][i])

        # Update
        simple_state_rep = simple_succ_state_rep
        state = state_paths[action][i]

    # Step two and a half in the RPE version makes sense, but the APE model doesn't care about reward
    # and so does not care about variability in reward *timing*, so we don't bother implementing it

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
        trial_states.append(state)
    elif reward == 0:
        state = 2  # unrewarded state
    else:
        quit()

    simple_succ_state_rep = phi_simple(state)

    # Learn
    trial_da_left.append(left_agent.learn(simple_state_rep, simple_succ_state_rep, 0))
    trial_da_right.append(right_agent.learn(simple_state_rep, simple_succ_state_rep, 0))
    trial_scal_da_left.append(left_scal_agent.learn(state_paths[action][-1], state, 0))
    trial_scal_da_right.append(right_scal_agent.learn(state_paths[action][-1], state, 0))

    # Store DA
    da_left[trial] = trial_da_left
    da_right[trial] = trial_da_right
    scal_da_left[trial] = trial_scal_da_left
    scal_da_right[trial] = trial_scal_da_right
    states[trial] = trial_states

if not debug:
    np.savez('./data/parker/APE/DA.npz', da_left=da_left, da_right=da_right,
             reward_mags=bandit_probs,
             temp=sftmx_temp, actions=actions,
             trial_times=trial_times,
             block_switch_interval=block_switch_interval, epoch=epoch, rewards=rewards, reward_trials=reward_trials,
             states=states, scal_da_left=scal_da_left, scal_da_right=scal_da_right)
