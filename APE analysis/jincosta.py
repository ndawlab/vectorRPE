import numpy as np
import math
import scipy.stats as stats

from VectorRPEAgent import VectorRPEAgent
from ScalarRPEAgent import ScalarRPEAgent

np.random.seed(865612)  # Consistency


def build_phi_chunked_graded(press_thresh, num_copies, is_weighted, prop_first=0, scale=1):
    """
    Constructs a function that accepts a state and returns its feature decomposition.

    Parameters
    ----------
    press_thresh (int): Threshold number of presses required to sample the bandit.
    num_copies (int): Number of times the base feature vector is replicated in the neuronal population.
    is_weighted (boolean): If True, the representation will be chunked so that the extra copies of the base
        representation vector will either redudantly encode the first or last press, with the specific proportion
        decided by the `prop_first` variable.
    prop_first (float): If is_weighted is True, then `prop_first` determines the proportion of chunked neurons
        that will encode the first press. The remainder will encode the last press. If is_weighted is False, this
        does nothing.
    scale (float): Neuron tuning is implemented as a Gaussian centered on some value with scale `scale`.

    Returns
    -------
    A function that returns a feature-based state decomposition given a state.
    """
    def phi_chunked_graded(press_count, is_musc):
        num_neurons = 1 + 2*press_thresh  # start + premotor and motor for each press
        phi_base = np.zeros((1, num_neurons))

        # Build base phi vector
        for i in range(num_neurons):
            if press_count == 0:
                mean = press_count
            elif not is_musc:
                mean = press_count * 2 - 1
            else:
                mean = press_count * 2

            phi_base[0, i] = stats.norm(loc=mean, scale=scale).pdf(i)

        if not is_weighted:  # Unchunked
            phi = np.tile(phi_base, (num_copies, 1))
        else:  # Chunked
            phi = np.zeros((num_copies, num_neurons))
            for i in range(num_copies):
                if i == 0:
                    phi[i, :] = phi_base
                else:
                    first_press_neurons = math.ceil(prop_first * num_neurons)
                    phi[i, :first_press_neurons] = phi_base[0, 1]  # first premotor neuron
                    phi[i, first_press_neurons:] = phi_base[0, -2]  # the "last press" is actually the 2nd last state

        return phi.flatten()
    return phi_chunked_graded


def scal_state(press_count, is_musc):
    """
    Returns the current state for the scalar model given the press count and a premotor flag.

    Parameters
    ----------
    press_count (int): Agent's press count.
    is_musc (boolean): Is or is not the premotor phase of the action.

    Returns
    -------
    Scalar state in the task.
    """
    if not is_musc:
        return 2*press_count - 1
    else:
        return 2*press_count


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
press_counts = np.zeros(num_bandits, dtype=int)
bandit_rewards = np.array([1, 0])
press_thresh = 3

# Task parameters
num_trials = 5000
block_switch_interval = 10000

# Agent parameters
lr = 0.05
gamma = 0.5
sftmx_temp = 0.25
prop_first = 0.6
is_chunked = True
tuning_scale = 0.3

num_states = 1 + (2 * press_thresh)
num_copies = 3
chunked_features = (1 + 2*press_thresh) * num_copies

chgl_ag = VectorRPEAgent(chunked_features, lr, gamma)  # chunked graded left agent
chgr_ag = VectorRPEAgent(chunked_features, lr, gamma)  # chunked graded right agent

sl_ag = ScalarRPEAgent(num_states, lr, gamma)  # scalar left agent
sr_ag = ScalarRPEAgent(num_states, lr, gamma)  # scalar right agent

phi_chunked_graded = build_phi_chunked_graded(press_thresh, num_copies, is_chunked, prop_first, scale=tuning_scale)

daL = np.empty(num_trials, dtype=object)
daR = np.empty(num_trials, dtype=object)
scal_daL = np.empty(num_trials, dtype=object)
scal_daR = np.empty(num_trials, dtype=object)

actions = np.empty(num_trials, dtype=object)
states = np.empty(num_trials, dtype=object)

staterepsL = np.empty(num_trials, dtype=object)
staterepsR = np.empty(num_trials, dtype=object)

epoch = np.zeros(num_trials)
trial_type = 0

# Simulate
initiation_prob = 0.2
seq_press_prob = 0.9
musc_init = False  # False indicates that a premotor phase has not been passed (muscles have not been initialized)
for trial in range(num_trials):
    if trial % block_switch_interval == 0 and trial > 0:  # Check for reversal
        bandit_rewards = bandit_rewards[::-1]
        trial_type = 1 - trial_type

    epoch_trial = trial_type

    # Reset things that should be reset
    press_counts[:] = 0
    trial_daL = []
    trial_daR = []
    trial_scal_daL = []
    trial_scal_daR = []
    trial_actions = []
    trial_states = []
    trial_staterepsL = []
    trial_staterepsR = []

    # Lever presentation
    l_state = phi_chunked_graded(press_counts[0], musc_init)
    r_state = phi_chunked_graded(press_counts[1], musc_init)
    scal_l_state = scal_state(press_counts[0], musc_init)
    scal_r_state = scal_state(press_counts[1], musc_init)

    trial_daL.append(chgl_ag.compute_delta_feat(np.zeros(chunked_features), l_state, 0))
    trial_daR.append(chgr_ag.compute_delta_feat(np.zeros(chunked_features), r_state, 0))
    trial_scal_daL.append(sl_ag.val(scal_l_state))
    trial_scal_daR.append(sr_ag.val(scal_r_state))
    trial_states.append(press_counts.tolist())
    trial_staterepsL.append(l_state)
    trial_staterepsR.append(r_state)

    # Trial initiation wait
    while np.random.uniform(0, 1) >= initiation_prob:
        trial_daL.append(chgl_ag.learn(l_state, l_state, 0))
        trial_daR.append(chgr_ag.learn(r_state, r_state, 0))
        trial_scal_daL.append(sl_ag.learn(scal_l_state, scal_l_state, 0))
        trial_scal_daR.append(sr_ag.learn(scal_r_state, scal_r_state, 0))
        trial_states.append(press_counts.tolist())
        trial_staterepsL.append(l_state)
        trial_staterepsR.append(r_state)

    # Pressing
    while np.max(press_counts) < press_thresh or musc_init:
        action = -1
        if musc_init:  # Pre-motor phase has been passed
            action = next_action

            next_l_state = phi_chunked_graded(press_counts[0], musc_init)
            next_r_state = phi_chunked_graded(press_counts[1], musc_init)
            next_scal_l_state = scal_state(press_counts[0], musc_init)
            next_scal_r_state = scal_state(press_counts[1], musc_init)

            musc_init = False

        elif np.random.uniform(0, 1) >= seq_press_prob:  # Wait
            next_l_state = l_state
            next_r_state = r_state
            next_scal_l_state = scal_l_state
            next_scal_r_state = scal_r_state

        else:  # Pick an action and execute
            next_action = np.random.choice(2, p=softmax(bandit_rewards, sftmx_temp))
            press_counts[next_action] += 1

            next_l_state = phi_chunked_graded(press_counts[0], musc_init)
            next_r_state = phi_chunked_graded(press_counts[1], musc_init)
            next_scal_l_state = scal_state(press_counts[0], musc_init)
            next_scal_r_state = scal_state(press_counts[1], musc_init)

            musc_init = True

        # Learn
        l_reward = int(action == 0)
        r_reward = int(action == 1)

        trial_daL.append(chgl_ag.learn(l_state, next_l_state, l_reward))
        trial_daR.append(chgr_ag.learn(r_state, next_r_state, r_reward))
        trial_scal_daL.append(sl_ag.learn(scal_l_state, next_scal_l_state, l_reward))
        trial_scal_daR.append(sr_ag.learn(scal_r_state, next_scal_r_state, r_reward))
        trial_states.append(press_counts.tolist())
        trial_staterepsL.append(next_l_state)
        trial_staterepsR.append(next_r_state)
        trial_actions.append(action)

        l_state = next_l_state
        r_state = next_r_state
        scal_l_state = next_scal_l_state
        scal_r_state = next_scal_r_state

    daL[trial] = trial_daL
    daR[trial] = trial_daR
    scal_daL[trial] = trial_scal_daL
    scal_daR[trial] = trial_scal_daR
    states[trial] = trial_states
    actions[trial] = trial_actions
    staterepsL[trial] = trial_staterepsL
    staterepsR[trial] = trial_staterepsR


if not debug:
    if is_chunked:
        filename = 'DA_chunked'
    else:
        filename = 'DA_unchunked'

    np.savez('./data/jincosta/%s.npz' % filename, reward_mags=bandit_rewards, temp=sftmx_temp,
             chunk_grad_L=daL, chunk_grad_R=daR, states=states, actions=actions, num_copies=num_copies,
             prop_first=prop_first, fr_schedule=press_thresh, epoch=epoch, gamma=gamma, tuning_scale=tuning_scale,
             is_chunked=is_chunked, scal_daL=scal_daL, scal_daR=scal_daR, staterepsL=staterepsL, staterepsR=staterepsR)












