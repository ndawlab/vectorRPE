import numpy as np


class VectorRPEAgent(object):
    def __init__(self, num_features, lr, gamma):
        """
        Initializer, stores various parameters.

        Parameters
        ----------
        num_features (int): Number of feature channels in the feature-specific RPE model.
        lr (float): Learning rate paramter.
        gamma (float): Temporal discounting parameter
        """

        self.num_features = num_features
        self.alpha = lr
        self.gamma = gamma
        self.weights = np.zeros(num_features)

    def val(self, state_vec):
        """
        Return the value estimate for a certain state.

        Parameters
        ----------
        state_vec (np.ndarray): Feature representation of a state.

        Returns
        -------
        Value of the inputted state vector given the current weight values.
        """
        return np.dot(state_vec, self.weights)

    def compute_delta_feat(self, state_vec, succ_vec, reward):
        """
        Computes the per-feature prediction error term for the weight update.

        Parameters
        ----------
        state_vec (np.ndarray): Initial state vector.
        succ_vec (np.ndarray): Successor state vector.
        reward (float): Reward earned for transitioning from `state_vec` to `succ_vec`.

        Returns
        -------
        Vector encoding the per-feature channel prediction errors.
        """
        delta_features = np.zeros(self.num_features)
        for i in range(self.num_features):
            delta_features[i] = reward / self.num_features
            delta_features[i] += self.weights[i] * (self.gamma * succ_vec[i] - state_vec[i])

        return delta_features

    def compute_delta(self, state_vec, succ_vec, reward):
        """
        Computes the total (scalar) prediction error for the weight update.

        Parameters
        ----------
        state_vec (np.ndarray): Initial state vector.
        succ_vec (np.ndarray): Successor state vector.
        reward (float): Reward earned for transitioning from `state_vec` to `succ_vec`.

        Returns
        -------
        Scalar prediction error (sum of the per-feature prediction errors).
        """
        return np.sum(self.compute_delta_feat(state_vec, succ_vec, reward))

    def learn(self, state_vec, succ_vec, reward, ret_da=True):
        """
        Given a transition from a state to a successor state, perform an update to the weights.

        Parameters
        ----------
        state_vec (np.ndarray): Initial state vector.
        succ_vec (np.ndarray): Successor state vector.
        reward (float): Reward earned for transitioning from `state_vec` to `succ_vec`.
        ret_da (boolean): If True, return the per-feature prediction errors used to perform the update.

        Returns
        -------
        If ret_da is True, the per-feature prediction errors induced by the update. Otherwise, None.
        """
        delta_feat = self.compute_delta_feat(state_vec, succ_vec, reward)
        delta = np.sum(delta_feat)
        self.weights += self.alpha * delta * state_vec

        if ret_da:
            return delta_feat


def phi_tabular(state, max_state):
    if state > max_state:
        raise Exception('For this simple example, states can only be integers between 0 and max_state')

    state_vec = np.zeros(max_state + 1)
    state_vec[state] = 1

    return state_vec


if __name__ == '__main__':
    # Tabular example
    max_state = 5
    lr = 0.05
    gamma = 0.95
    vrpe = VectorRPEAgent(max_state + 1, lr, gamma)

    num_trials = 10000
    rewards = [0 for i in range(max_state)]
    rewards.append(1)

    curr_state = 0
    for t in range(num_trials):
        next_state = curr_state + 1
        vrpe.learn(phi_tabular(curr_state, max_state), phi_tabular(next_state, max_state), rewards[next_state])

        if next_state == max_state:
            curr_state = 0
        else:
            curr_state = next_state

    print('Tabular weights:', vrpe.weights)
