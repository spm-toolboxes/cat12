function varargout = cat_vol_imcalc(Vi,Vo,f,flags,varargin)
%__________________________________________________________________________
% Similar to SPM function with some small differences for better use as 
% internal function. 
% Yo can be aligned as second output and then no "size warning - use first
% input image properties" is given and no progress bar is display. 
%__________________________________________________________________________
%
% Perform algebraic functions on images
% FORMAT [Vo, Yo] = cat_vol_imcalc(Vi, Vo, f [,flags [,extra_vars...]])
% Vi            - struct array (from spm_vol) of images to work on
%                 or a char array of input image filenames
% Vo (input)    - struct array (from spm_vol) containing information on
%                 output image
%                 ( pinfo field is computed for the resultant image data, )
%                 ( and can be omitted from Vo on input.  See spm_vol     )
%                 or output image filename
% f             - MATLAB expression to be evaluated
% flags         - cell array of flags: {dmtx,mask,interp,dtype}
%                 or structure with these fieldnames
%      dmtx     - Read images into data matrix?
%                 [defaults (missing or empty) to 0 - no]
%      mask     - implicit zero mask?
%                 [defaults (missing or empty) to 0]
%                  ( negative value implies NaNs should be zeroed )
%      interp   - interpolation hold (see spm_slice_vol)
%                 [defaults (missing or empty) to 0 - nearest neighbour]
%      dtype    - data type for output image (see spm_type)
%                 [defaults (missing or empty) to 4 - 16 bit signed shorts]
% extra_vars... - additional variables which can be used in expression
%
% Vo (output)   - spm_vol structure of output image volume after
%                 modifications for writing
% Yo            - output image 
%__________________________________________________________________________
%
% cat_vol_imcalc performs user-specified algebraic manipulations on a set of
% images, with the result being written out as an image. 
% The images specified in Vi, are referred to as i1, i2, i3,...  in the
% expression to be evaluated, unless the dmtx flag is setm in which
% case the images are read into a data matrix X, with images in rows.
%
% Computation is plane by plane, so in data-matrix mode, X is a NxK
% matrix, where N is the number of input images [prod(size(Vi))], and K
% is the number of voxels per plane [prod(Vi(1).dim(1:2))].
%
% For data types without a representation of NaN, implicit zero masking
% assumes that all zero voxels are to be treated as missing, and treats
% them as NaN. NaN's are written as zero, for data types without a
% representation of NaN.
%
% With images of different sizes and orientations, the size and orientation
% of the reference image is used. Reference is the first image, if
% Vo (input) is a filename, otherwise reference is Vo (input). A
% warning is given in this situation. Images are sampled into this
% orientation using the interpolation specified by the interp parameter.
%__________________________________________________________________________
%
% Example expressions (f):
%
%    i)  Mean of six images (select six images)
%        f = '(i1+i2+i3+i4+i5+i6)/6'
%   ii)  Make a binary mask image at threshold of 100
%        f = 'i1>100'
%   iii) Make a mask from one image and apply to another
%        f = '(i1>100).*i2'
%        (here the first image is used to make the mask, which is applied
%         to the second image - note the '.*' operator)
%   iv)  Sum of n images
%        f = 'i1 + i2 + i3 + i4 + i5 + ...'
%   v)   Sum of n images (when reading data into data-matrix)
%        f = 'sum(X)'
%   vi)  Mean of n images (when reading data into data-matrix)
%        f = 'mean(X)'
%__________________________________________________________________________
%
% Furthermore, additional variables for use in the computation can be
% passed at the end of the argument list. These should be referred to by
% the names of the arguments passed in the expression to be evaluated. 
% E.g. if c is a 1xn vector of weights, then for n images, using the (dmtx)
% data-matrix version, the weighted sum can be computed using:
%       Vi = spm_vol(spm_select(inf,'image'));
%       Vo = 'output.img'
%       Q  = cat_vol_imcalc(Vi,Vo,'c*X',{1},c)
% Here we've pre-specified the expression and passed the vector c as an
% additional variable (you'll be prompted to select the n images).
%__________________________________________________________________________
% Copyright (C) 1998-2011 Wellcome Trust Centre for Neuroimaging

% John Ashburner & Andrew Holmes
% Id: spm_imcalc.m 6043 2014-06-13 14:31:48Z volkmar 
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
% $Id$ 

%-Parameters & arguments
%==========================================================================
if nargin < 3
    spm_jobman('interactive','','spm.util.imcalc');
    return;
end

%-Flags
%--------------------------------------------------------------------------
if nargin < 4, flags = {}; end
if iscell(flags)
    if length(flags) < 5, verb   = []; else verb   = flags{5}; end
    if length(flags) < 4, dtype  = []; else dtype  = flags{4}; end
    if length(flags) < 3, interp = []; else interp = flags{3}; end
    if length(flags) < 2, mask   = []; else mask   = flags{2}; end
    if length(flags) < 1, dmtx   = []; else dmtx   = flags{1}; end
else
    if isfield(flags,'dmtx'),   dmtx   = flags.dmtx;   else dmtx   = []; end
    if isfield(flags,'mask'),   mask   = flags.mask;   else mask   = []; end
    if isfield(flags,'interp'), interp = flags.interp; else interp = []; end
    if isfield(flags,'dtype'),  dtype  = flags.dtype;  else dtype  = []; end
    if isfield(flags,'verb'),   verb   = flags.verb;   else verb   = []; end
end
if ischar(dtype),   dtype  = spm_type(dtype); end
if isempty(interp), interp = 0; end
if isempty(mask),   mask   = 0; end
if isempty(dmtx),   dmtx   = 0; end
if isempty(verb),   verb   = 0; end
if isempty(dtype),  dtype  = spm_type('int16'); end

if verb
  spm('FnBanner',mfilename);
end

%-Input images
%--------------------------------------------------------------------------
if ~isstruct(Vi), Vi = spm_vol(char(Vi)); end

if isempty(Vi), error('no input images specified'), end

if isstruct(Vo)
    Vchk   = [Vo; Vi(:)];
    refstr = 'output';
else
    Vchk   = Vi(:);
    refstr = '1st';
end
[sts, str] = spm_check_orientations(Vchk, false);
if verb
   if ~sts
       for i=1:size(str,1)
           fprintf('Warning: %s - using %s image.\n',strtrim(str(i,:)),refstr);
       end
   end
end



%-Output image
%--------------------------------------------------------------------------
if ischar(Vo)
    [p, n, e] = spm_fileparts(Vo);
    Vo = struct('fname',   fullfile(p, [n, e]),...
                'dim',     Vi(1).dim(1:3),...
                'dt',      [dtype spm_platform('bigend')],...
                'pinfo',   [Inf Inf Inf]',...
                'mat',     Vi(1).mat,...
                'n',       1,...
                'descrip', 'spm - algebra');
end

%-Process any additional variables
%--------------------------------------------------------------------------
if nargin > 4
    reserved = {'Vi','Vo','f','flags','interp','mask','dmtx','varargin',...
        'dtype','reserved','e','n','Y','p','B','X','i','j','M','d'};
    for i=5:nargin
        if isstruct(varargin{i-4}) && ...
                isempty(setxor(fieldnames(varargin{i-4}),{'name','value'}))
            for j=1:numel(varargin{i-4})
                if any(strcmp(varargin{i-4}(j).name,reserved))
                    error(['additional parameter (',varargin{i-4}(j).name,...
                        ') clashes with internal variable.'])
                end
                eval([varargin{i-4}(j).name,'=varargin{i-4}(j).value;']);
            end
        else
            if any(strcmp(inputname(i),reserved))
                error(['additional parameter (',inputname(i),...
                    ') clashes with internal variable.'])
            end
            eval([inputname(i),' = varargin{i-4};']);
        end
    end
end


%-Computation
%==========================================================================
n = numel(Vi);
Y = zeros(Vo.dim(1:3));

%-Start progress plot
%--------------------------------------------------------------------------
if verb
  spm_progress_bar('Init',Vo.dim(3),f,'planes completed');
end
 
%-Loop over planes computing result Y
%--------------------------------------------------------------------------
for p = 1:Vo.dim(3)
    B = spm_matrix([0 0 -p 0 0 0 1 1 1]);

    if dmtx, X = zeros(n,prod(Vo.dim(1:2))); end
    for i = 1 + isempty(strfind(f,'i1')):n % use i1 only to get the resolution properties
        M = inv(B * inv(Vo.mat) * Vi(i).mat);
        d = spm_slice_vol(Vi(i), M, Vo.dim(1:2), [interp,NaN]);
        if (mask < 0), 
          if (mask <-1),
            [D,I] = cat_vbdist(single(~(isnan(d))),true(size(d))); clear D;  %#ok<ASGLU>
            d = d(I); clear I;
          end
          d(isnan(d)) = 0; 
        end
        if (mask > 0) && ~spm_type(Vi(i).dt(1),'nanrep'), d(d==0)=NaN; end
        if dmtx, X(i,:) = d(:)'; else eval(sprintf('i%d=d;',i)); end
    end
    
    try
        eval(['Yp = ' f ';']);
    catch
        l = lasterror;
        error('%s\nCan''t evaluate "%s".',l.message,f);
    end
    if prod(Vo.dim(1:2)) ~= numel(Yp)
        error(['"',f,'" produced incompatible image.']); end
    if (mask < 0), Yp(isnan(Yp)) = 0; end
    Y(:,:,p) = reshape(Yp,Vo.dim(1:2));

    if verb
      spm_progress_bar('Set',p);
    end
end

%-Write output image
%--------------------------------------------------------------------------
if nargout <= 1
  if exist(Vo.fname,'file'); delete(Vo.fname); end
  varargout{1} = spm_write_vol(Vo,Y); 
elseif nargout == 2
  if isfield(Vo,'dat');
    switch Vo.dt(1)
      case 2,   Vo.dat = cat_vol_ctype(Y,'uint8');  
      case 4,   Vo.dat = cat_vol_ctype(Y,'int16'); 
      case 8,   Vo.dat = cat_vol_ctype(Y,'int32'); 
      case 16,  Vo.dat = single(Y); 
      case 64,  Vo.dat = double(Y); 
      case 256, Vo.dat = cat_vol_ctype(Y,'int8'); 
      case 512, Vo.dat = cat_vol_ctype(Y,'uint16'); 
      case 768, Vo.dat = cat_vol_ctype(Y,'uint32'); 
    end
  end
  varargout{1} = Vo; 
  varargout{2} = Y; 
end
%-End
%--------------------------------------------------------------------------
if verb
  spm_progress_bar('Clear')
end
