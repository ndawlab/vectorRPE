#include <mex.h>

#include <iostream>


void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
  //----- Parse arguments
  if (nrhs != 2) {
    std::cout << "Usage:  correlation = lincorr(x, y)" << std::endl;
    return;
  }

  //----- Computations
  double              cxx       = 0;
  double              cyy       = 0;
  double              cxy       = 0;
  const int           n         = mxGetNumberOfElements(prhs[0]);
  const double*       x         = mxGetPr(prhs[0]);
  const double*       y         = mxGetPr(prhs[1]);

  double              mx        = 0;
  double              my        = 0;

  // Online covariance calculation
  for (int i = 0; i < n;)
  {
    const double      dx        = ( x[i] - mx );
    const double      dy        = ( y[i] - my );
    ++i;

    mx               += dx / i;
    my               += dy / i;
    cxx              += dx * dx;
    cyy              += dy * dy;
    cxy              += dx * dy;
  }

  //----- Output values 
  const double        corr      = n > 1
                                ? cxy / sqrt( cxx * cyy )
                                : 0
                                ;
  plhs[0]             = mxCreateDoubleScalar(corr);
}
