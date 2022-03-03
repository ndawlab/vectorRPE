% BINOINTERVAL    Binomial parameter estimates and confidence intervals using Jeffreys method.
%
% Usage:
%   [phat,pci] = binointerval(x,n)
%   [phat,pci] = binointerval(x,n,alpha)
%
% binointerval() computes the maximum likelihood estimate, phat, of the
% probability of success in a given binomial trial, based on the number of
% successes, x, observed in n independent trials.
%
% The 95% confidence intervals, pci, can also be returned by
% binointerval(). They are computed using Jeffreys method, which is an
% equal-tailed (probabilities of the interval lying above or below the true
% value are both close to equal) interval obtained from a Bayesian
% derivation.
%
% A different confidence interval can be specified via the parameter alpha,
% which as per the binofit() convention returns 100(1 - alpha)% confidence
% intervals. For example, alpha = 0.01 yields 99% confidence intervals.
%
% binointerval() is written as a MEX function. To compile it, extract the
% archive to some directory in your Matlab path, and execute:
%   cd private
%   mex -c -O Gamma.cpp
%   cd ..
%   mex -O binointerval.cc private\Gamma.o*
%
%
% Authors:
%   Ported by Sue Ann Koay <koay@princeton.edu>
%   from code originally written by Andrea Bocci <andrea.bocci@cern.ch>
%   and using public domain functions from John D. Cook <info@johndcook.com>
