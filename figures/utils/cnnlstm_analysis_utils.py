
import matplotlib.pyplot as plt
import matplotlib
import numpy as np
import pandas as pd
from mpl_toolkits.mplot3d import Axes3D
import os
import zipfile
import io


#### DATA MANIPULATION


def get_params_from_zip(load_path):
    model_file = zipfile.ZipFile(load_path + '.zip', "r")
    parameter_bytes = model_file.read("parameters")
    parameter_buffer = io.BytesIO(parameter_bytes)
    parameters = dict(np.load(parameter_buffer))
    model_file.close()
    return parameters

def split_by_ep_len(feature, episode_lengths):
    idx = np.cumsum(episode_lengths)[:-1].astype(int)
    return np.split(feature, idx, axis = 0)


def extract_field(trial_struc, fieldname):
    if fieldname == 'cueCombo': # special case
        return [np.vstack(cue_info) for cue_info in trial_struc[fieldname][0]]
    else:
        return np.squeeze(np.vstack(trial_struc[fieldname][0]))


#### BINING BY POSITION


"""
bin_data_by_ypos: bins data by yposition given some 1D data that is the same size as ypositions.
inputs >> data_: data that is a list of 1D data, with length num_trials
          ypositions: ypositions for each point of data grouped by trials
          pos_bins: marks the bins for yposition
output >> binned_data: a (num_trials x num_bins) matrix that averages the data within each bin.
                       nan if nothing in the bin so we can nanmean correctly
"""
def bin_data_by_ypos(data_, ypositions, pos_bins):
    num_trials = len(ypositions)
    num_bins = len(pos_bins) - 1
    ypos_bins_ = [np.digitize(ypositions[trial], pos_bins) for trial in np.arange(num_trials)]


    binned_data = np.full((num_trials, num_bins), np.nan)

    for (trial, data_slice) in enumerate(data_):
        trial_bins = np.unique(ypos_bins_[trial])
        binned_data[trial, trial_bins]  = np.array([np.mean(data_slice[ypos_bins_[trial] == i], 0) for i in trial_bins]).T
    return binned_data


"""
bin_data_by_ypos2: bins data by yposition given some 1D data that is the same size as ypositions. averages ACROSS all trials, not just within trial
inputs >> data_: data that is a list of 1D data, with length num_trials
          ypositions: ypositions for each point of data grouped by trials
          pos_bins: marks the bins for yposition
          trials: the trials to bin over. default is all trials. enter indices to slice accordingly
output >> binned_data: a (num_trials x num_bins) matrix that averages the data within each bin.
                       nan if nothing in the bin so we can nanmean correctly
"""
def bin_data_by_ypos2(data_, ypositions, pos_bins, trials = None):
    if trials == None:
         trials = np.arange(len(data_))
    num_trials = len(ypositions)
    num_bins = len(pos_bins) - 1
    ypos_bins_ = [np.digitize(ypositions[trial], pos_bins) for trial in np.arange(num_trials)]

    binned_data = [] # empty to start
    for trial in trials:
        data_slice = data_[trial]
        binned_trial = [data_slice[ypos_bins_[trial] == bin_i] for bin_i in np.arange(1,num_bins + 1)]

        if len(binned_data) == 0:
            binned_data = np.array(binned_trial)
        else:
            binned_data = np.array([np.hstack((binned_data[i],binned_trial[i])) for i in np.arange(num_bins)])
    # average at the end
    avg_binned_data = np.array([np.mean(trial_vals) for trial_vals in binned_data])
    return avg_binned_data




"""
plot_binned_data: plots binned data (num_trials, num_bins) matrix with mean and std and a label

"""

def plot_binned_data(data, label = '', ax = None, color = None, ypos = []):
    if ax == None:
        ax = plt.gca()
    if len(ypos) == 0:
        ypos = np.arange(0, 0.638 * data.shape[1], 0.638)
    ax.plot(ypos, np.nanmean(data, 0), label = label, color = color)
    # ax.errorbar(ypos_range, np.nanmean(data, 0), stats.sem(data, axis =0, nan_policy = 'omit'),  color = color, label = label, linestyle='None', marker='o', capsize=3)
    ax.set_xlabel('Position')


"""
find_cue_locs:
"""
def find_cue_locs(binned_data, cueType, cuePositions, pos_bins, cue_bin_range):
    num_trials = len(cuePositions)
    num_bins = len(pos_bins) - 1
    cue_bins_ = [np.digitize(trial_cues[cueType], pos_bins)[0] for trial_cues in cuePositions]
    data_by_cue_type = []

    for (t, trial_cue_bins) in enumerate(cue_bins_):
    # only try to get the cues if there are cues in this trial
        if len(trial_cue_bins):
            # get the data positioned at cue
            cue_region_after = [binned_data[t, np.arange(cue_idx, int(min(binned_data.shape[1] - 1, cue_idx + cue_bin_range[1] + 1)))]
                                                                            for cue_idx in trial_cue_bins]
            cue_region_before = [binned_data[t, np.arange(int(max(0, cue_idx - cue_bin_range[0])), cue_idx) ]
                                                                            for cue_idx in trial_cue_bins]
            # fill in any missing data for the last cue
            cue_region_after[-1] = np.hstack((cue_region_after[-1], np.full((cue_bin_range[1] + 1 - len(cue_region_after[-1]),),np.nan)))
            cue_region_before[0] = np.hstack((np.full((cue_bin_range[0]  - len(cue_region_before[0]),),np.nan), cue_region_before[0]))

            # put it all together
            data_by_cue_type.append(np.hstack(([np.vstack(cue_region_i) for cue_region_i in [cue_region_before, cue_region_after]])))



    return np.vstack(data_by_cue_type)



"""
find_cue_locs:
"""
def find_cue_locs_unbinned(binned_data, cueType, cuePositions, pos_bins, cue_bin_range):
    num_trials = len(cuePositions)
    num_bins = len(pos_bins) - 1
    cue_bins_ = [np.digitize(trial_cues[cueType], pos_bins)[0] for trial_cues in cuePositions]
    data_by_cue_type = []

    for (t, trial_cue_bins) in enumerate(cue_bins_):
    # only try to get the cues if there are cues in this trial
        if len(trial_cue_bins):
            # get the data positioned at cue
            cue_region_after = [binned_data[t, np.arange(cue_idx, int(min(binned_data.shape[1] - 1, cue_idx + cue_bin_range[1] + 1)))]
                                                                            for cue_idx in trial_cue_bins]
            cue_region_before = [binned_data[t, np.arange(int(max(0, cue_idx - cue_bin_range[0])), cue_idx) ]
                                                                            for cue_idx in trial_cue_bins]
            # fill in any missing data for the last cue

            cue_region_after[-1] = np.hstack((cue_region_after[-1], np.full((cue_bin_range[1] + 1 - len(cue_region_after[-1]),),np.nan)))
            cue_region_before[0] = np.hstack((np.full((cue_bin_range[0]  - len(cue_region_before[0]),),np.nan), cue_region_before[0]))

            # put it all together
            data_by_cue_type.append(np.hstack(([np.vstack(cue_region_i) for cue_region_i in [cue_region_before, cue_region_after]])))



    return np.vstack(data_by_cue_type)

"""
given some raw activity, timelock to cues (cue type determined by the cueOnset)
in this version, activity is given by ALL units, then it takes the num_unit needed.
"""
def timelock_to_cue(activity, cueOnset, num_unit):
    num_steps_after = 25
    num_steps_before = 5
    all_act_after_cue = []
    for (t, trial_cue_idx) in enumerate(cueOnset):
        if len(trial_cue_idx):
            trial_act = activity[t][:,num_unit]
            act_after_cue = [trial_act[max(0,idx - num_steps_before):min(idx+num_steps_after , len(trial_act))] for idx in trial_cue_idx]

            act_after_cue[0] = np.hstack((np.full((num_steps_before + num_steps_after - len(act_after_cue[0]),),np.nan), act_after_cue[0]))
            act_after_cue[-1] =  np.hstack((act_after_cue[-1], np.full((num_steps_before + num_steps_after - len(act_after_cue[-1]),),np.nan)))
            all_act_after_cue.append(np.vstack(act_after_cue))
    return np.vstack(all_act_after_cue)

"""
given some raw activity, timelock to cues (cue type determined by the cueOnset)
This function is specialized for idealRPEs since not just the last cue can be
"""
def timelock_to_cue_i(activity_i, cueOnset):
    num_steps_after = 25
    num_steps_before = 5
    all_act_after_cue = []
    for (t, trial_cue_idx) in enumerate(cueOnset):
        if len(trial_cue_idx):
            trial_act = activity_i[t]
            act_after_cue = [trial_act[max(0,idx - num_steps_before):min(idx+num_steps_after , len(trial_act))] for idx in trial_cue_idx]

            act_after_cue[0] = np.hstack((np.full((num_steps_before + num_steps_after - len(act_after_cue[0]),),np.nan), act_after_cue[0]))
            after_cue_limit = (trial_cue_idx + num_steps_after) > len(trial_act) # determine the cues that go too far (might not just be the last cue)
            for cueOnset_i in np.where(after_cue_limit)[0]:
                act_after_cue[cueOnset_i] =  np.hstack((act_after_cue[cueOnset_i], np.full((num_steps_before + num_steps_after - len(act_after_cue[cueOnset_i]),),np.nan)))
            all_act_after_cue.append(np.vstack(act_after_cue))
    return np.vstack(all_act_after_cue)


"""
bin_data_by_vpos: bins data by vposition given a series of data
inputs >> data: data that is a matrix of data with rows num_timesteps * num_trials and columns of num_features
          vpositions: vpositions that has same number of rows
          bin_size: size of the view angle bins
output >> va_bins: the bins of view angle for the binned data
          binned_data: a (num_bins x num_features ) vector that averages data within the bin
"""
def bin_data_by_vpos(data, vpositions, bin_size = 0.05):
    va_bins = np.arange(np.min(vpositions), np.max(vpositions)+ bin_size, bin_size)
    vpos_bin_idx = np.digitize(vpositions, va_bins)

    binned_data = np.array([np.mean(data[vpos_bin_idx == i],0) for i in np.unique(vpos_bin_idx)]).T

    if bin_size != 0.05:
        return (va_bins, binned_data)
    else:
        return binned_data


"""
autocorr calculates mean-corrected dot product across time of a matrix
inputs> mat: matrix with ROWS of observations across time.(so timesteps x shape)
"""
def covar_mat(mat):
    mat = np.vstack([mat_i - np.mean(mat_i) for mat_i in mat])
    return mat.dot(mat.T)
#### IPEs #####



"""
get_ipes: computes the ideal RPE PEs and Value given a value function and sequence of belief states.
          outputs the ideal RPEs and values as a sequence

val_fn: the value function computed with the ideal RPEs. Shaped num_states x steps_per_trial
        num_states is the possible belief states the agent can be in
bs:    sequence of belief states. Shaped steps_per_trial x num_trials
"""
def get_ipes(val_fn, bs):

    stepspertrial = bs.shape[0]
    ntrials = bs.shape[1]
    ipes = np.zeros((ntrials, stepspertrial))
    ivalues = np.zeros((ntrials, stepspertrial))

    for trial in np.arange(ntrials):

        ipes[trial,0] = val_fn[bs[0, trial], 1] - val_fn[0,0] # first step
        ivalues[trial,0] = val_fn[0, 0]
        for step in np.arange(1,stepspertrial):
            ipes[trial, step] = val_fn[bs[step, trial],step + 1]-val_fn[bs[step-1, trial],step] # 2nd step
            ivalues[trial, step] = val_fn[bs[step-1, trial], step]

    return ipes, ivalues

"""
value_iteration: performs value iteration given some belief state (the absolute value of difference of towers)
                 and psychometric curve
"""
# value iteration to compute reward probability given running abs diff at each step
# steps 2-141 are following each 14cm state, step 1 is prior to trial starting
def value_iteration(bs, pcorr):
    V = np.zeros((141,7)) # 141 steps x 7 possible abs running count diffs b (0-6) at each step
    V[140,:] = pcorr
    # backward induction
    for level in np.flip(np.arange(139)):
        for state in np.arange(7):
            succs = bs[bs[:,level] == state,level+1] # running counts at next steps
            psucc = np.array([np.mean(succs == x) if np.sum(succs == x) > 0 else 0 for x in np.arange(7)]) # how likely we reach each state
            V[level+1,state] = np.dot(psucc, V[level+2,:])  # bellman


	# final case: expectation before seeing anything
    succs = bs[:,0]
    psucc = np.array([np.mean(succs == x) for x in np.arange(7)])
    V[0,0] = np.dot(psucc, V[1,:])

    return V.T
#### OTHER ####
"""
Given the tower difference for each trial, get the indices for
        ep_towdelt (ie absolute difference) and
        ep_towdiff (just tower difference, L - R )
"""
def get_ep_tow_idx(ep_tow):
    ep_towdiff = ep_tow[:,0] - ep_tow[:,1]
    ep_towdelt = np.abs(ep_towdiff)
    ep_towdelt_idx = [np.where(ep_towdelt == delt)[0] for delt in np.arange(7)]
    ep_towdiff_idx = [np.where(ep_towdiff == delt)[0] for delt in np.arange(-6,7)]

    return (ep_towdelt_idx, ep_towdiff_idx)

# todo: will need to fix for multiple trials...also this is POSITION not TIME
def plot_cues(ax, cuePos_trial, colors = ['k', 'r']):
    for cueType, cueTypeColor in zip(cuePos_trial, colors):
        for cue in np.squeeze(cueType):
            ax.axvline(x = cue, color = cueTypeColor)


#### PCA UTILS ####
def get_singular_vals(feats):
        """
        gets singular values from features
        input: feat: features with datapoints x features
        output: PC's: PC's in column form, ordered
                singular values: (1 x features )
        """
        C = np.cov(feats, rowvar = False)
        U, S, V = np.linalg.svd(C)
        return (U, S)
def get_var_captured(S, ax = None, var_limits = [0.5, 0.9, 0.98], ):
    """
    """

    var_captured = np.hstack((0,np.cumsum(S)/np.sum(S)))
    for v in var_limits:
        PC_needed = (next(x[0] for x in enumerate(var_captured) if x[1] > v))

        if ax: # if an axis is provided, then print out
            print('You need {:d} PCs to capture {:.0f}% of the variance'.format(PC_needed, v * 100))
            ax.axvline(PC_needed, color = 'k', alpha = 0.5)
    if ax:
        ax.plot(var_captured)
        ax.set_xlabel('ith Singular Value')
        ax.set_title('Percent Variance Captured')
        ax.set_ylabel('% Variance captured')
        ax.axhline(0.5, color = 'k', alpha = 0.5)
        ax.axhline(0.9, color = 'k', alpha = 0.5)
    return (var_captured, PC_needed)
def get_pca_proj(feats, pc):
    """
    gets the pca projection
    input: feat: the features, with datapoints x features
           pc: the PC's (i.e. U from the PCA)
    """
    feats0 = feats - np.mean(feats,0)
    proj = feats0 @ pc
    return proj


def plot_proj(proj, num_dim = 2):
    """
    plot projections
    input: proj: the projections (should be num_time_points x num_pcs_projected)
           num_dim: number of dimensions. by default 2, but can be made 3
    """
    if num_dim == 2:
        plt.plot(proj[:,0], proj[:,1], 'o')
    elif num_dim == 3:
        fig = plt.figure()
        ax = fig.add_subplot(111, projection='3d')
        ax.scatter(proj[:,0], proj[:,1], proj[:,2])
    else:
        print("number of dim invalid")




### WEIGHT ANALYSES

def get_top_weights(weights):
    return np.argsort(np.abs(weights), axis = 0)[::-1]

def compare_weight_diff(w, col):
    return np.sum(np.abs(w.T - w[:,col].T), axis = 1)


"""
calculates d prime for multiple neurons, given high reward expectation (hre) responses, and
                low reward expectation (lre) responses
input: hre_response: num_trials in hre x num_neurons
       lre_response: num_trials in lre x num_neurons
output: d_prime 1 x num_neurons
"""
def get_d_prime(lre_response, hre_response):
    mean_diff = np.mean(lre_response,0) - np.mean(hre_response,0)
    std_correction = np.sqrt(0.5 * (np.std(lre_response,0) ** 2 + np.std(hre_response,0) ** 2))
    return mean_diff / std_correction


# must be FEAT x TIMESTEPS
norm_within_feat = lambda feat_by_bins: np.vstack([(row_feat - np.min(row_feat))/(np.max(row_feat) - np.min(row_feat)) for row_feat in feat_by_bins])
sort_by_max_loc = lambda act: np.argsort(np.argmax(act,1))
sort_by_max = lambda act: np.argsort(np.max(act,1))

### PARULA MAP
cm_data = [[0.2422, 0.1504, 0.6603],
[0.2444, 0.1534, 0.6728],
[0.2464, 0.1569, 0.6847],
[0.2484, 0.1607, 0.6961],
[0.2503, 0.1648, 0.7071],
[0.2522, 0.1689, 0.7179],
[0.254, 0.1732, 0.7286],
[0.2558, 0.1773, 0.7393],
[0.2576, 0.1814, 0.7501],
[0.2594, 0.1854, 0.761],
[0.2611, 0.1893, 0.7719],
[0.2628, 0.1932, 0.7828],
[0.2645, 0.1972, 0.7937],
[0.2661, 0.2011, 0.8043],
[0.2676, 0.2052, 0.8148],
[0.2691, 0.2094, 0.8249],
[0.2704, 0.2138, 0.8346],
[0.2717, 0.2184, 0.8439],
[0.2729, 0.2231, 0.8528],
[0.274, 0.228, 0.8612],
[0.2749, 0.233, 0.8692],
[0.2758, 0.2382, 0.8767],
[0.2766, 0.2435, 0.884],
[0.2774, 0.2489, 0.8908],
[0.2781, 0.2543, 0.8973],
[0.2788, 0.2598, 0.9035],
[0.2794, 0.2653, 0.9094],
[0.2798, 0.2708, 0.915],
[0.2802, 0.2764, 0.9204],
[0.2806, 0.2819, 0.9255],
[0.2809, 0.2875, 0.9305],
[0.2811, 0.293, 0.9352],
[0.2813, 0.2985, 0.9397],
[0.2814, 0.304, 0.9441],
[0.2814, 0.3095, 0.9483],
[0.2813, 0.315, 0.9524],
[0.2811, 0.3204, 0.9563],
[0.2809, 0.3259, 0.96],
[0.2807, 0.3313, 0.9636],
[0.2803, 0.3367, 0.967],
[0.2798, 0.3421, 0.9702],
[0.2791, 0.3475, 0.9733],
[0.2784, 0.3529, 0.9763],
[0.2776, 0.3583, 0.9791],
[0.2766, 0.3638, 0.9817],
[0.2754, 0.3693, 0.984],
[0.2741, 0.3748, 0.9862],
[0.2726, 0.3804, 0.9881],
[0.271, 0.386, 0.9898],
[0.2691, 0.3916, 0.9912],
[0.267, 0.3973, 0.9924],
[0.2647, 0.403, 0.9935],
[0.2621, 0.4088, 0.9946],
[0.2591, 0.4145, 0.9955],
[0.2556, 0.4203, 0.9965],
[0.2517, 0.4261, 0.9974],
[0.2473, 0.4319, 0.9983],
[0.2424, 0.4378, 0.9991],
[0.2369, 0.4437, 0.9996],
[0.2311, 0.4497, 0.9995],
[0.225, 0.4559, 0.9985],
[0.2189, 0.462, 0.9968],
[0.2128, 0.4682, 0.9948],
[0.2066, 0.4743, 0.9926],
[0.2006, 0.4803, 0.9906],
[0.195, 0.4861, 0.9887],
[0.1903, 0.4919, 0.9867],
[0.1869, 0.4975, 0.9844],
[0.1847, 0.503, 0.9819],
[0.1831, 0.5084, 0.9793],
[0.1818, 0.5138, 0.9766],
[0.1806, 0.5191, 0.9738],
[0.1795, 0.5244, 0.9709],
[0.1785, 0.5296, 0.9677],
[0.1778, 0.5349, 0.9641],
[0.1773, 0.5401, 0.9602],
[0.1768, 0.5452, 0.956],
[0.1764, 0.5504, 0.9516],
[0.1755, 0.5554, 0.9473],
[0.174, 0.5605, 0.9432],
[0.1716, 0.5655, 0.9393],
[0.1686, 0.5705, 0.9357],
[0.1649, 0.5755, 0.9323],
[0.161, 0.5805, 0.9289],
[0.1573, 0.5854, 0.9254],
[0.154, 0.5902, 0.9218],
[0.1513, 0.595, 0.9182],
[0.1492, 0.5997, 0.9147],
[0.1475, 0.6043, 0.9113],
[0.1461, 0.6089, 0.908],
[0.1446, 0.6135, 0.905],
[0.1429, 0.618, 0.9022],
[0.1408, 0.6226, 0.8998],
[0.1383, 0.6272, 0.8975],
[0.1354, 0.6317, 0.8953],
[0.1321, 0.6363, 0.8932],
[0.1288, 0.6408, 0.891],
[0.1253, 0.6453, 0.8887],
[0.1219, 0.6497, 0.8862],
[0.1185, 0.6541, 0.8834],
[0.1152, 0.6584, 0.8804],
[0.1119, 0.6627, 0.877],
[0.1085, 0.6669, 0.8734],
[0.1048, 0.671, 0.8695],
[0.1009, 0.675, 0.8653],
[0.0964, 0.6789, 0.8609],
[0.0914, 0.6828, 0.8562],
[0.0855, 0.6865, 0.8513],
[0.0789, 0.6902, 0.8462],
[0.0713, 0.6938, 0.8409],
[0.0628, 0.6972, 0.8355],
[0.0535, 0.7006, 0.8299],
[0.0433, 0.7039, 0.8242],
[0.0328, 0.7071, 0.8183],
[0.0234, 0.7103, 0.8124],
[0.0155, 0.7133, 0.8064],
[0.0091, 0.7163, 0.8003],
[0.0046, 0.7192, 0.7941],
[0.0019, 0.722, 0.7878],
[0.0009, 0.7248, 0.7815],
[0.0018, 0.7275, 0.7752],
[0.0046, 0.7301, 0.7688],
[0.0094, 0.7327, 0.7623],
[0.0162, 0.7352, 0.7558],
[0.0253, 0.7376, 0.7492],
[0.0369, 0.74, 0.7426],
[0.0504, 0.7423, 0.7359],
[0.0638, 0.7446, 0.7292],
[0.077, 0.7468, 0.7224],
[0.0899, 0.7489, 0.7156],
[0.1023, 0.751, 0.7088],
[0.1141, 0.7531, 0.7019],
[0.1252, 0.7552, 0.695],
[0.1354, 0.7572, 0.6881],
[0.1448, 0.7593, 0.6812],
[0.1532, 0.7614, 0.6741],
[0.1609, 0.7635, 0.6671],
[0.1678, 0.7656, 0.6599],
[0.1741, 0.7678, 0.6527],
[0.1799, 0.7699, 0.6454],
[0.1853, 0.7721, 0.6379],
[0.1905, 0.7743, 0.6303],
[0.1954, 0.7765, 0.6225],
[0.2003, 0.7787, 0.6146],
[0.2061, 0.7808, 0.6065],
[0.2118, 0.7828, 0.5983],
[0.2178, 0.7849, 0.5899],
[0.2244, 0.7869, 0.5813],
[0.2318, 0.7887, 0.5725],
[0.2401, 0.7905, 0.5636],
[0.2491, 0.7922, 0.5546],
[0.2589, 0.7937, 0.5454],
[0.2695, 0.7951, 0.536],
[0.2809, 0.7964, 0.5266],
[0.2929, 0.7975, 0.517],
[0.3052, 0.7985, 0.5074],
[0.3176, 0.7994, 0.4975],
[0.3301, 0.8002, 0.4876],
[0.3424, 0.8009, 0.4774],
[0.3548, 0.8016, 0.4669],
[0.3671, 0.8021, 0.4563],
[0.3795, 0.8026, 0.4454],
[0.3921, 0.8029, 0.4344],
[0.405, 0.8031, 0.4233],
[0.4184, 0.803, 0.4122],
[0.4322, 0.8028, 0.4013],
[0.4463, 0.8024, 0.3904],
[0.4608, 0.8018, 0.3797],
[0.4753, 0.8011, 0.3691],
[0.4899, 0.8002, 0.3586],
[0.5044, 0.7993, 0.348],
[0.5187, 0.7982, 0.3374],
[0.5329, 0.797, 0.3267],
[0.547, 0.7957, 0.3159],
[0.5609, 0.7943, 0.305],
[0.5748, 0.7929, 0.2941],
[0.5886, 0.7913, 0.2833],
[0.6024, 0.7896, 0.2726],
[0.6161, 0.7878, 0.2622],
[0.6297, 0.7859, 0.2521],
[0.6433, 0.7839, 0.2423],
[0.6567, 0.7818, 0.2329],
[0.6701, 0.7796, 0.2239],
[0.6833, 0.7773, 0.2155],
[0.6963, 0.775, 0.2075],
[0.7091, 0.7727, 0.1998],
[0.7218, 0.7703, 0.1924],
[0.7344, 0.7679, 0.1852],
[0.7468, 0.7654, 0.1782],
[0.759, 0.7629, 0.1717],
[0.771, 0.7604, 0.1658],
[0.7829, 0.7579, 0.1608],
[0.7945, 0.7554, 0.157],
[0.806, 0.7529, 0.1546],
[0.8172, 0.7505, 0.1535],
[0.8281, 0.7481, 0.1536],
[0.8389, 0.7457, 0.1546],
[0.8495, 0.7435, 0.1564],
[0.86, 0.7413, 0.1587],
[0.8703, 0.7392, 0.1615],
[0.8804, 0.7372, 0.165],
[0.8903, 0.7353, 0.1695],
[0.9, 0.7336, 0.1749],
[0.9093, 0.7321, 0.1815],
[0.9184, 0.7308, 0.189],
[0.9272, 0.7298, 0.1973],
[0.9357, 0.729, 0.2061],
[0.944, 0.7285, 0.2151],
[0.9523, 0.7284, 0.2237],
[0.9606, 0.7285, 0.2312],
[0.9689, 0.7292, 0.2373],
[0.977, 0.7304, 0.2418],
[0.9842, 0.733, 0.2446],
[0.99, 0.7365, 0.2429],
[0.9946, 0.7407, 0.2394],
[0.9966, 0.7458, 0.2351],
[0.9971, 0.7513, 0.2309],
[0.9972, 0.7569, 0.2267],
[0.9971, 0.7626, 0.2224],
[0.9969, 0.7683, 0.2181],
[0.9966, 0.774, 0.2138],
[0.9962, 0.7798, 0.2095],
[0.9957, 0.7856, 0.2053],
[0.9949, 0.7915, 0.2012],
[0.9938, 0.7974, 0.1974],
[0.9923, 0.8034, 0.1939],
[0.9906, 0.8095, 0.1906],
[0.9885, 0.8156, 0.1875],
[0.9861, 0.8218, 0.1846],
[0.9835, 0.828, 0.1817],
[0.9807, 0.8342, 0.1787],
[0.9778, 0.8404, 0.1757],
[0.9748, 0.8467, 0.1726],
[0.972, 0.8529, 0.1695],
[0.9694, 0.8591, 0.1665],
[0.9671, 0.8654, 0.1636],
[0.9651, 0.8716, 0.1608],
[0.9634, 0.8778, 0.1582],
[0.9619, 0.884, 0.1557],
[0.9608, 0.8902, 0.1532],
[0.9601, 0.8963, 0.1507],
[0.9596, 0.9023, 0.148],
[0.9595, 0.9084, 0.145],
[0.9597, 0.9143, 0.1418],
[0.9601, 0.9203, 0.1382],
[0.9608, 0.9262, 0.1344],
[0.9618, 0.932, 0.1304],
[0.9629, 0.9379, 0.1261],
[0.9642, 0.9437, 0.1216],
[0.9657, 0.9494, 0.1168],
[0.9674, 0.9552, 0.1116],
[0.9692, 0.9609, 0.1061],
[0.9711, 0.9667, 0.1001],
[0.973, 0.9724, 0.0938],
[0.9749, 0.9782, 0.0872],
[0.9769, 0.9839, 0.0805]]
from matplotlib.colors import LinearSegmentedColormap

parula_map = LinearSegmentedColormap.from_list('parula', cm_data)
