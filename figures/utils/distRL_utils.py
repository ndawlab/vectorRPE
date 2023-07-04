import numpy as np
import time
import matplotlib.pyplot as plt
import time
import seaborn as sns
from numpy import linalg as LA
import pickle
import matplotlib
from scipy.stats import zscore
from scipy.io import loadmat, savemat
from matplotlib import gridspec
import os
import scipy

########## EXPECTILE IMPUTATION ###########

# CODE FROM DABNEY


def expectile_loss(samples, expectiles, taus):
    n_atoms = len(samples)
    deltas = samples[None, :] - expectiles[:, None]
    tau_factors = taus[:, None] * \
        (deltas > 0) + (1. - taus[:, None]) * (deltas <= 0)
    return np.einsum("ij,ij", deltas**2, tau_factors) / n_atoms


def expectile_grad(samples, expectiles, taus):
    n_atoms = len(samples)
    deltas = samples[None, :] - expectiles[:, None]
    tau_factors = taus[:, None] * \
        (deltas > 0) + (1. - taus[:, None]) * (deltas <= 0)
    return np.einsum("ij,ij->i", -2 * deltas, tau_factors) / n_atoms


def expectile_hess(samples, expectiles, taus):
    n_atoms = len(samples)
    deltas = samples[None, :] - expectiles[:, None]
    tau_factors = taus[:, None] * \
        (deltas > 0) + (1. - taus[:, None]) * (deltas <= 0)
    return np.diag(np.sum(2*tau_factors, -1)) / n_atoms


def get_expectiles(samples, taus):
    expectiles_init = np.zeros(len(taus))

    def func(e): return expectile_loss(
        samples=samples, expectiles=e, taus=taus)

    def grad(e): return expectile_grad(
        samples=samples, expectiles=e, taus=taus)
    def hess(e): return expectile_hess(
        samples=samples, expectiles=e, taus=taus)

    result = scipy.optimize.minimize(
        func, x0=expectiles_init, method="L-BFGS-B", jac=grad, hess=hess)
    return result["x"]


def imputation_loss(samples, expectiles, taus):
    return expectile_grad(samples, expectiles, taus)


def imputation_grad(samples, expectiles, taus):
    n_atoms = len(samples)
    deltas = samples[None, :] - expectiles[:, None]
    tau_factors = taus[:, None] * \
        (deltas > 0) + (1. - taus[:, None]) * (deltas <= 0)
    return -2*tau_factors / n_atoms


def fit_samples(expectiles, taus):
    success = False
    trial = 0
    while trial < 10 and not success:
        samples_init = np.random.uniform(low=expectiles.min() - 1e-2,
                                         high=expectiles.max() + 1e-2,
                                         size=len(expectiles))

        def fcn(e): return imputation_loss(
            samples=e, expectiles=expectiles, taus=taus)
        def jac(e): return imputation_grad(
            samples=e, expectiles=expectiles, taus=taus)
        result = scipy.optimize.root(
            fcn, jac=jac, x0=samples_init, method="lm")
        samples = result["x"]
        success = result["success"]
        trial += 1
    return samples


def expectile_grad_loss(expectiles, taus, dist):
    # computes the gradient of the expectile loss function
    # returns a vector, one value for each expectile
    delta = dist[np.newaxis, :] - expectiles[:, np.newaxis]
    indic = np.array(delta <= 0., dtype=np.float32)
    grad = -2. * np.abs(taus[:, np.newaxis] - indic) * delta
    return np.mean(grad, axis=1)


def check_convergence(sol):
    # make sure optimization has converged
    if not sol['success']:
        print(sol['message'])


def infer_dist(expectiles=None, taus=None, dist=None):
    """
    Given two of the following three values (reversal_points, taus, and dist), we can always infer the third
    :param reversal_points: vector of expectiles
    :param taus: vector, with values between 0 and 1
    :param dist: the distribution for which we want to compute expectiles, or which we want to impute
    """
    # infer expectiles
    if expectiles is None:
        def fn_to_solve(x): return expectile_grad_loss(x, taus, dist)
        taus[taus < 0.] = 0.
        taus[taus > 1.] = 1.
        sol = scipy.optimize.root(
            fn_to_solve, x0=np.quantile(dist, taus), method='lm')

    # infer taus
    elif taus is None:
        def fn_to_solve(x): return expectile_grad_loss(expectiles, x, dist)
        sol = scipy.optimize.root(fn_to_solve, x0=np.linspace(
            0.01, 0.99, len(expectiles)), method='lm')

    # impute distribution
    elif dist is None:
        def fn_to_solve(x): return expectile_grad_loss(expectiles, taus, x)
        sol = scipy.optimize.root(fn_to_solve, x0=expectiles, method='lm',
                                  options={'maxiter': 100000})

    check_convergence(sol)

    # return the optimized value
    return sol['x']


########## TESTS ###########
"""
plot_all_PEs plots PEs for each dist unit
        pes_to_plot: averaged pes, shaped num_dist x num_trails
"""


def plot_all_PEs(pes_avg_to_plot, alpha_plus, alpha_minus):
    num_dists = pes_avg_to_plot.shape[0]
    for dist_i in np.arange(num_dists):
        plt.figure()
        plt.title('Avg PEs for dist unit {} \n Alpha_plus = {:.6f} Alpha_minus = {:.6f}'.format
                  (dist_i, alpha_plus[dist_i], alpha_minus[dist_i]))
        plt.xlabel('Trial')
        plt.ylabel('Trial Avg PE')
        plt.plot(pes_avg_to_plot[dist_i, :])


"""
plot_value_across_trials plots avged value across trials, per Lowet et al (review paper) Figure 2C,D,G,H
    vs_avg_to_plot: averaged value across trials, shaped num_dists x num_trials
"""


def plot_value_across_trials(vs_avg_to_plot):
    num_dists = vs_avg_to_plot.shape[0]
    dist_colors = sns.color_palette("coolwarm", num_dists)
    for dist_i in np.arange(num_dists):
        plt.plot(vs_avg_to_plot[dist_i, :], color=dist_colors[dist_i])
    plt.xlabel('Trial')
    plt.ylabel('AvgValue')


def get_alphas(tau, avg):

    alpha_plus = tau * avg
    alpha_minus = avg - alpha_plus
    assert np.sum(np.hstack([alpha_plus, alpha_minus])
                  < 0) == 0, 'alphas must all be positive'
    assert all(alpha_plus / (alpha_plus + alpha_minus) >=
               0), 'tau = alpha_plus/ [alpha_plus + alpha_minus] must span [0, 1]'
    assert all(alpha_plus / (alpha_plus + alpha_minus) <=
               1),  'tau = alpha_plus/ [alpha_plus + alpha_minus] must span [0, 1]'

    return alpha_plus, alpha_minus
