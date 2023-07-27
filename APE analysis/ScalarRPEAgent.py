import numpy as np


class ScalarRPEAgent(object):
    def __init__(self, num_states, lr, gamma):
        """
        Initializer, stores various parameters.

        Parameters
        ----------
        num_states (int): Total number of states in the environment.
        lr (float): Learning rate parameter.
        gamma (float): Temporal discounting factor.
        """
        self.alpha = lr
        self.gamma = gamma
        self.num_states = num_states
        self.V = np.zeros(num_states)  # value function

    def val(self, state):
        """
        Returns the value estimate associated with state `state`.

        Parameters
        ----------
        state (int): The desired state.

        Returns
        -------
        The value estimate for state `state`.
        """
        return self.V[state]

    def compute_delta(self, state, succ, reward):
        """
        Returns the prediction error term for the value update given a transition from `state` to `succ` that received
        `reward` reward.

        Parameters
        ----------
        state (int): The initial state.
        succ (int): The successor state.
        reward (float): The earned reward.

        Returns
        -------
        The prediction error term for the update to V(state).
        """
        return reward + self.gamma * self.V[succ] - self.V[state]

    def learn(self, state, succ, reward, ret_da=True):
        """
        Given a transition from `state` to `succ`, earning `reward` reward, update the estimated value of `state`.

        Parameters
        ----------
        state (int): The initial state.
        succ (int): The successor state.
        reward (float): The earned reward.
        ret_da (boolean): If True, return the prediction error term associated with this update.

        Returns
        -------
        If ret_da is True, the prediction error term is returned. Otherwise, None.
        """
        delta = self.compute_delta(state, succ, reward)
        self.V[state] += self.alpha * delta

        if ret_da:
            return delta


if __name__ == '__main__':
    num_states = 5
    lr = 0.3
    gamma = 0.95

    sa = ScalarRPEAgent(num_states, lr, gamma)

    num_trials = 1000
    for i in range(num_trials):
        for state in range(1, 5):
            reward = int(state == 4)

            sa.learn(state - 1, state, reward)

    print(sa.V)







