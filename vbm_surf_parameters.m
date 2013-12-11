function vbm_surf_parameters(vargin)
%vbm_surf_extract to extract surface parameters such as
% gyrification and cortical complexity.
%_______________________________________________________________________
% Christian Gaser
% $Id: vbm_surf_parameters.m 475 2013-04-19 08:32:39Z gaser $

rev = '$Rev: 475 $';

if nargin == 1
  P = char(vargin.data_surf);
  GI = vargin.GI;
  FD = vargin.FD;
else
  error('Not enough parameters.');
end

opt.debug     = cg_vbm_get_defaults('extopts.debug');
opt.CATDir    = fullfile(spm('dir'),'toolbox','vbm12','CAT');   
  
% add system dependent extension to CAT folder
if ispc
  opt.CATDir = [opt.CATDir '.w32'];
elseif ismac
  opt.CATDir = [opt.CATDir '.maci64'];
elseif isunix
  opt.CATDir = [opt.CATDir '.glnx86'];
end  


for i=1:size(P,1)

  [pp,ff,ex]   = spm_fileparts(deblank(P(i,:)));
    
  name = [ff ex];
  
  PGI     = fullfile(pp,strrep(name,'central','gyrification'));
  PFD     = fullfile(pp,strrep(name,'central','fractaldimension'));
  Psphere = fullfile(pp,strrep(name,'central','sphere'));
  
  if GI
    %% gyrification index based on absolute mean curvature
    str = '  Extract gyrification index'; fprintf('%s:%s',str,repmat(' ',1,67-length(str)));
    cmd = sprintf('CAT_DumpCurv "%s" "%s" 0 0 1',P(i,:),PGI);
    [ST, RS] = system(fullfile(opt.CATDir,cmd)); check_system_output(ST,RS,opt.debug);
  end
  
  if FD
    %% fractal dimension using spherical harmonics
    str = '  Extract fractal dimension'; fprintf('%s:%s',str,repmat(' ',1,67-length(str)));
    cmd = sprintf('CAT_FractalDimension -sphere "%s" -nosmooth "%s" "%s" "%s"',Psphere,deblank(P(i,:)),Psphere,PFD);
    [ST, RS] = system(fullfile(opt.CATDir,cmd)); check_system_output(ST,RS,opt.debug);
  end

end

end

function check_system_output(status,result,debugON)
  if status==1 || ...
     ~isempty(strfind(result,'ERROR')) || ...
     ~isempty(strfind(result,'Segmentation fault'))
    error('VBM:system_error',result); 
  end
  if nargin > 2
    if debugON, disp(result); end
  end
end