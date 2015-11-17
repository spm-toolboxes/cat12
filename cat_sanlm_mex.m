function cat_sanlm_mex(in, v, f)
% FORMAT cat_sanlm_mex(in, v, f)
% 
% Spatial Adaptive Non Local Means Denoising Filter
%
% v - size of search volume (M in paper)
% f - size of neighborhood (d in paper)
%
% *                          Details on SANLM filter                        
% ***************************************************************************
% *  The SANLM filter is described in:                                      *
% *                                                                         *
% *  Jose V. Manj—n, Pierrick Coupe, Luis Mart’-bonmat’, Montserrat Robles  *
% *  and D. Louis Collins.                                                  *
% *  Adaptive Non-Local Means Denoising of MR Images with Spatially Varying *
% *  Noise Levels. Journal of Magnetic Resonance Imaging, 31,192-203, 2010. *                                                       
% *                                                                         *
% ***************************************************************************/
%
%
% Christian Gaser
% $Id$

rev = '$Rev$';

disp('Compiling cat_sanlm_mex.c')

pth = fileparts(which(mfilename));
p_path = pwd;
cd(pth);
mex -O cat_sanlm_mex.c sanlm_float.c 
cd(p_path);

cat_sanlm_mex(in, v, f);

return