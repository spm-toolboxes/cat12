function [varargout] = cat_surf_info(P,readsurf,gui,verb,useavg)
% ______________________________________________________________________
% Extact surface information from filename.
%
% sinfo = cat_surf_info(P,readsurf,gui,verb)
%
%   P         .. surface filename
%   readsurf  .. read gifti or Freesurfer file to get more information
%   gui       .. interactive hemisphere selection
%   verb      .. verbose
%
% sinfo(i). 
%   fname     .. full filename
%   pp        .. filepath
%   ff        .. filename
%   ee        .. filetype
%   exist     .. exist file?
%   fdata     .. structure from dir command
%   ftype     .. filetype [0=no surface,1=gifti,2=freesurfer]
%   statready .. ready for statistic (^s#.*.gii) [0|1]
%   side      .. hemisphere [lh|rh|lc|rc|mesh] 
%   name      .. subject/template name
%   datatype  .. [-1=unknown|0=nosurf|1=mesh|2=data|3=surf]
%                only defined for readsurf==1 and surf=mesh+sidata
%   dataname  .. datafieldname [central|thickness|intensity...]
%   texture   .. textureclass [central|sphere|thickness|...]
%   label     .. labelmap
%   resampled .. resampled data [0|1] 
%   template  .. template or individual mesh [0|1] 
%   name      .. name of the dataset
%   roi       .. roi data
%   nvertices .. number vertices
%   nfaces    .. number faces
%   Pmesh     .. underlying meshfile
%   Psphere   .. sphere mesh
%   Pspherereg.. registered sphere mesh
%   Pdefects  .. topology defects mesh
%   Pdata     .. datafile
%   preside   .. prefix before hemi info (i.e. after smoothing)
%   posside   .. string after hemi info
%   smoothed  .. smoothing size
%   Phull     .. convex hull mesh
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
% $Id$

%#ok<*RGXP1>

  if ~exist('P','var'), P=''; end
  if ~exist('useavg','var'), useavg=1; end
  if strcmp(P,'selftest')
    pps = {
      fullfile(fileparts(mfilename('fullpath')),'templates_surfaces')
      fullfile('User','08.15','T1 T2','subs','mri')
      };
    ffs = {
      'lh.central.freesurfer'
      'lh.mymask'
      'output'
      'lh.texture.sub1.sub2'
      'lh.tex1.tex2.resampled.sub1.sub2'
      '08.15'
      's15mm.lh.tex03.33.resampled.S01.mri'
      's5mm.lh.t1.t2-3_3.resampled.S01_-.kdk.mri'
      'rh.s33mmtexture.S01.native.mri'
      'rh'
      'rh.'
      'rh.sphere.reg.sub1'
      'rc.defects.038.37.477'
      'lc.s33mmtexture.S01.native.mri'
      'rc.texture.sub1.sub2'
      };
    ees = {
      ''
      ... '.gii'
      ... '.annot'
      };
    varargout = cell(numel(pps),numel(ffs),numel(ees)); 
    for ppsi = 1:numel(pps)
      for ffsi = 1:numel(ffs)
        for eesi = 1:numel(ees)
          varargout{1}(ppsi,ffsi,eesi) = cat_surf_info(fullfile(pps{ppsi},[ffs{ffsi} ees{eesi}]),0,0,1);
        end
      end
    end
    return; 
  end
  
  
  
  if nargin<2, readsurf = 0; end
  if nargin<3, gui  = 0; end
  if nargin<4, verb = 0; end

  P = cellstr(P);
  
  sinfo = struct(...
    'fname','',...      % full filename
    'pp','',...         % filepath
    'ff','',...         % filename
    'ee','',...         % filetype
    'exist','',...      % exist
    'fdata','',...      % datainfo (filesize)
    'ftype','',...      % filetype [0=no surface,1=gifti,2=freesurfer]
    'statready',0,...   % ready for statistic (^s#.*.gii)
    'side','',...       % hemishphere
    'name','',...       % subject/template name
    'datatype','',...   % datatype [0=nosurf/file|1=mesh|2=data|3=surf] with surf=mesh+data
    'dataname','',...   % datafieldname [central|thickness|s3thickness...]
    'texture','',...    % textureclass [central|sphere|thickness|...]
    'label','',...      % labelmap
    'resampled','',...  % dataspace
    'resampled_32k','',...
    'template','',...   % individual surface or tempalte
    'roi','',...        % roi data
    'nvertices',[],...  % number vertices
    'nfaces',[],...     % number faces
    'Pmesh','',...      % meshfile
    'Psphere','',...    % meshfile
    'Pspherereg','',... % meshfile
    'Pdefects','',...   % meshfile
    'Ppial','',...      % meshfile
    'Pwhite','',...     % meshfile
    'Player4','',...    % meshfile
    'Pdata','',...      % datafile
    'preside','', ...
    'posside','' ...
  );

  if isempty(P{1}), varargout{1}=sinfo; return; end
  
  for i=1:numel(P)
    [pp,ff,ee] = spm_fileparts(P{i});
    if strcmp(ee,'.dat')
      P{i} = spm_file(P{i},'ext','.gii');
    end
    sinfo(i).fdata = dir(P{i});
    
    sinfo(i).fname = P{i};
    sinfo(i).exist = exist(P{i},'file') > 0; 
    sinfo(i).pp = pp;
    switch ee
      case {'.xml','.txt','.html','.csv'}
        sinfo(i).ff = ff;
        sinfo(i).ee = ee;
        sinfo(i).ftype = 0;
        continue
      case '.gii'
        sinfo(i).ff = ff;
        sinfo(i).ee = ee;
        sinfo(i).ftype = 1;
        if sinfo(i).exist && readsurf
          S = gifti(P{i});
        end
      case '.annot'
        sinfo(i).ff = ff;
        sinfo(i).ee = ee;
        sinfo(i).ftype = 1;
        sinfo(i).label = 1; 
        if sinfo(i).exist && readsurf
          clear S; 
          try
            S = cat_io_FreeSurfer('read_annotation',P{1}); 
          catch
            cat_io_cprintf('warn',sprintf('Warning: Error while reading annotation file: \n  %s\n',P{1}));
          end
        end
        if exist('S','var')
          sinfo(i).ftype = 2;
        end
      otherwise
        sinfo(i).ff = [ff ee];
        sinfo(i).ee = '';
        sinfo(i).ftype = 0;
        if sinfo(i).exist && readsurf
        % this files are not specified by ending so we will just try to read something
          clear S; 
          try %#ok<TRYNC>
            S = cat_io_FreeSurfer('read_surf',P{1}); 
            if ~isstruct(S) || ~isfield(S,'faces') || (size(S.faces,2)~=3 || size(S.faces,1)<10000)
              clear S; 
            end
          end
          try %#ok<TRYNC>
            S.cdata = cat_io_FreeSurfer('read_surf_data',P{1});
            if size(S.face,2)==3 || size(S.face,1)<10000
              S = rmfield(S,'cdata'); 
            end
          end
          if ~exist('S','var')
            cat_io_cprintf('warn',sprintf('Warning: Error while reading surface file: \n  %s\n',P{1}));
          end
        end
        if exist('S','var')
          sinfo(i).ftype = 2;
        end
    end
    
    
    noname = sinfo(i).ff; 
    
    % smoothed data
    sinfo(i).statready = ~isempty(regexp(noname,'^s(?<smooth>\d+)\..*')); 
    
    % side
    if     cat_io_contains(noname,'lh.'),   sinfo(i).side='lh';   sidei = strfind(noname,'lh.');
    elseif cat_io_contains(noname,'rh.'),   sinfo(i).side='rh';   sidei = strfind(noname,'rh.');
    elseif cat_io_contains(noname,'cb.'),   sinfo(i).side='cb';   sidei = strfind(noname,'cb.');
    elseif cat_io_contains(noname,'mesh.'), sinfo(i).side='mesh'; sidei = strfind(noname,'mesh.');
    elseif cat_io_contains(noname,'lc.'),   sinfo(i).side='lc';   sidei = strfind(noname,'lc.');
    elseif cat_io_contains(noname,'rc.'),   sinfo(i).side='rc';   sidei = strfind(noname,'rc.');
    else
      
      % skip for volume files
      if strcmp(ee,'.nii')
        continue
      end
      
      % if SPM.mat exist use that for side information
      % Torben Lund Mail 20240409: issues with reading some SPM.mat files that did not include the right  
      if ~isempty(pp) && exist(fullfile(pp,'SPM.mat'),'file')
        try %#ok<TRYNC>
          load(fullfile(pp,'SPM.mat'),'SPM'); % this will give a warning if the var SPM does not exist 
        end
        if exist('SPM','var') 
          if isfield(SPM,'xY') && isfield (SPM.xY,'VY') && isfield(SPM.xY.VY(1),'fname')
            [~,ff2]   = spm_fileparts(SPM.xY.VY(1).fname);        
            
            % find mesh string
            hemi_ind = strfind(ff2,'mesh.');
            if ~isempty(hemi_ind)
              sinfo(i).side = ff2(hemi_ind(1):hemi_ind(1)+3);
            else
              % find lh|rh string
              hemi_ind = [strfind(ff2,'lh.') strfind(ff2,'rh.') strfind(ff2,'lc.') strfind(ff2,'rc.')];
              sinfo(i).side = ff2(hemi_ind(1):hemi_ind(1)+1);
            end
            
            sidei = []; % handle this later
          else
            cat_io_cprintf('warn',sprintf('Warning: Error SPM.mat does not include required fields: \n  %s\n',P{1}));
          end
        end
      else
        if gui
          if cat_get_defaults('extopts.expertgui')
            sinfo(i).side = spm_input('Hemisphere',1,'lh|rh|lc|rc|cb|mesh');
          else
            sinfo(i).side = spm_input('Hemisphere',1,'lh|rh|mesh');
          end
        else
          sinfo(i).side = 'mesh'; 
        end
        sidei = strfind(noname,[sinfo(i).side '.']);
      end
    end
    if isempty(sidei), sidei = strfind(noname,sinfo(i).side); end
    if sidei>0
      sinfo(i).preside = noname(1:sidei-1);
      sinfo(i).posside = noname(sidei+numel(sinfo(i).side)+1:end);
    else
      sinfo(i).posside = noname;
    end

    % smoothed
    if isempty(sinfo(i).preside)
      sinfo(i).smoothed = 0; 
    else
      sinfo(i).smoothed = max([0,double(cell2mat(textscan(sinfo(i).preside,'s%dmm.')))]);
    end

    % datatype
    if sinfo(i).exist && readsurf
      switch num2str([isfield(S,'vertices'),isfield(S,'cdata')],'%d%d')
        case '00',  sinfo(i).datatype  = 0;
        case '01',  sinfo(i).datatype  = 1;
        case '10',  sinfo(i).datatype  = 2;
        case '11',  sinfo(i).datatype  = 3;
      end
    else
      sinfo(i).datatype = -1;
    end
   
    
    % resampled
    sinfo(i).resampled     = ~isempty(strfind(sinfo(i).posside,'.resampled')) && ...
                              isempty(strfind(sinfo(i).posside,'.resampled_32k'));
    sinfo(i).resampled_32k = ~isempty(strfind(sinfo(i).posside,'.resampled_32k'));
    % template
    sinfo(i).template      = cat_io_contains(lower(sinfo(1).ff),'.template'); 
    % CG20210226: This caused crashes in cat_surf_surf2roi.m for some files
%    if sinfo(i).template,  sinfo(i).resampled = 1; end
    

    % name / texture
    %  -----------------------------------------------------------------
    % ... name extraction is a problem, because the name can include points
    % and also the dataname / texture can include points ...
    resi = [strfind(sinfo(i).posside,'template.'),... 
            strfind(sinfo(i).posside,'resampled.'),...
            strfind(sinfo(i).posside,'resampled_32k.'),...
            strfind(sinfo(i).posside,'sphere.reg.')]; 
    if ~isempty(resi)
      sinfo(i).name = cat_io_strrep(sinfo(i).posside(max(resi):end),...
        {'template.','resampled.','resampled_32k.','sphere.reg'},''); %sinfo(i).posside,
      if ~isempty(sinfo(i).name) && sinfo(i).name(1)=='.', sinfo(i).name(1)=[]; end
      sinfo(i).texture = sinfo(i).posside(1:min(resi)-2);
    else
      % without no template/resampled string
      doti = strfind(sinfo(i).posside,'.');
      if numel(doti)==0 
      % if not points exist that the string is the name
        sinfo(i).name    = '';
        sinfo(i).texture = sinfo(i).posside;
      elseif isscalar(doti) 
      % if one point exist that the first string is the dataname and the second the subject name 
        sinfo(i).name    = sinfo(i).posside(doti+1:end);
        sinfo(i).texture = sinfo(i).posside(1:doti-1);
      else
      % this is bad
        sinfo(i).name    = sinfo(i).posside(min(doti)+1:end);
        sinfo(i).texture = sinfo(i).posside(1:min(doti)-1);
      end
    end
    if verb
      fprintf('%50s: s%04.1f %2s ',sinfo(i).ff,sinfo(i).smoothed,sinfo(i).side);
      cat_io_cprintf([0.2 0.2 0.8],'%15s',sinfo(i).texture);
      cat_io_cprintf([0.0 0.5 0.2],'%15s',sinfo(i).name);
      fprintf('%4s\n',sinfo(i).ee);
    end
    % dataname
    sinfo(i).dataname  = cat_io_strrep(sinfo(i).posside,{sinfo(i).name,'template.','resampled.','resampled_32k.'},''); 
    if ~isempty(sinfo(i).dataname) && sinfo(i).dataname(end)=='.', sinfo(i).dataname(end)=[]; end
    
    % if texture is empty use dataname, otherwise texture is more reliable and should
    % be used instead of dataname 
    if isempty(sinfo(i).texture)
      sinfo(i).texture = sinfo(i).dataname;
    else
      sinfo(i).dataname = sinfo(i).texture;
    end
    
    % ROI
    sinfo(i).roi = ~isempty(strfind(sinfo(i).posside,'.ROI'));
    

    
    % find Mesh and Data Files
    %  -----------------------------------------------------------------
    sinfo(i).Pmesh = '';
    sinfo(i).Pdata = '';
    % here we know that the gifti is a surf
    if sinfo(i).statready 
      sinfo(i).Pmesh = sinfo(i).fname;
      sinfo(i).Pdata = sinfo(i).fname;
    end
    % if we have read the gifti than we can check for the fields
    if isempty(sinfo(i).Pmesh) && sinfo(i).exist && readsurf && isfield(S,'vertices')
      sinfo(i).Pmesh = sinfo(i).fname; 
    end
    if isempty(sinfo(i).Pdata) && sinfo(i).exist && readsurf && isfield(S,'cdata')
      sinfo(i).Pdata = sinfo(i).fname;
    end
    
    % check whether cdata field and mesh structure exist for gifti data
    if strcmp(sinfo(i).ee,'.gii') && sinfo(i).exist && readsurf && (isempty(sinfo(i).Pdata) || isempty(sinfo(i).Pmesh))
      S = gifti(sinfo(i).fname);
      if isfield(S,'cdata') && isfield(S,'faces') && isfield(S,'vertices')
        sinfo(i).Pmesh = sinfo(i).fname;
        sinfo(i).Pdata = sinfo(i).fname;
      end
    end
    
    % if the dataname is central we got a mesh or surf datafile
    if isempty(sinfo(i).Pdata) || isempty(sinfo(i).Pmesh) 
      Pcentral = fullfile(sinfo(i).pp,[strrep(sinfo(i).ff,['.' sinfo(i).texture],'.central') sinfo(i).ee]);
      switch sinfo(i).texture
        %case {'defects'} % surf
        %  sinfo(i).Pmesh = sinfo(i).fname;
        %  sinfo(i).Pdata = sinfo(i).fname;
        case {'central','white','pial','inner','outer','sphere','hull','core','layer4'} % only mesh
          sinfo(i).Pmesh = sinfo(i).fname;
          sinfo(i).Pdata = '';
        case {'pbt','thickness','thicknessfs','thicknessmin','thicknessmax',...
              'gyrification','frac','depth','sqrtdepth','GWMdepth','WMdepth','CSFdepth',...
              'depthWM','depthGWM','depthCSF','depthWMg','inwardGI','outwardGI','generalizedGI',...
              'area','defects','lGI','toroGI',...
              'intlayer4','intwhite','intpial',...
              'gyruswidth','gyruswidthWM','sulcuswidth'} % only thickness
          sinfo(i).Pdata = sinfo(i).fname;
          if strcmp(sinfo(i).ee,'.gii') && sinfo(i).ftype == 1 && exist(sinfo(i).fname,'file') 
            S = gifti(sinfo(i).fname);
            if isfield(S,'vertices') && isfield(S,'faces')
              sinfo(i).Pmesh = sinfo(i).fname;
            end
          end
          Pcentral = fullfile(sinfo(i).pp,[strrep(sinfo(i).ff,['.' sinfo(i).texture],'.central') '.gii']);
          if exist(Pcentral,'file') && ~useavg
            sinfo(i).Pmesh = Pcentral;
          end
        otherwise
          sinfo(i).Pdata =sinfo(i).fname;
          if exist(Pcentral,'file') && ~useavg
            sinfo(i).Pmesh = Pcentral;
          elseif strcmp(sinfo(i).ee,'.gii') && sinfo(i).ftype == 1 && exist(sinfo(i).fname,'file')
            S = gifti(sinfo(i).fname);
            if isfield(S,'vertices') && isfield(S,'faces')
              sinfo(i).Pmesh = sinfo(i).fname;
            end
          end
      end
    end
    % if we still dont know what kind of datafile, we can try to find a
    % mesh surface
    if isempty(sinfo(i).Pmesh) 
      if strcmp(ee,'.gii') && isempty(sinfo(i).side)
        sinfo(i).Pmesh = sinfo(i).fname;
        sinfo(i).Pdata = sinfo(i).fname;
      else
        % template mesh handling !!!
        Pmesh = char(cat_surf_rename(sinfo(i),'dataname','central','ee','.gii'));
        if exist(Pmesh,'file')
          sinfo(i).Pmesh = Pmesh;
          sinfo(i).Pdata = sinfo(i).fname;
        end
      end
    end
    % if we got still no mesh than we can use SPM.mat information or average mesh
    % ...
    if isempty(sinfo(i).Pmesh) %&& sinfo(i).ftype==1
      try 
        if ischar(SPM.xVol.G)
          % data or analysis moved or data are on a different computer?
          if ~exist(SPM.xVol.G,'file')
            [pp2,ff2,xx2] = spm_fileparts(SPM.xVol.G);
            % rename old Template name from previous versions
            ff2 = strrep(ff2,'Template_T1_IXI555_MNI152_GS',cat_get_defaults('extopts.shootingsurf'));
            if cat_io_contains(ff2,'.central.freesurfer') || cat_io_contains(ff2,['.central.' cat_get_defaults('extopts.shootingsurf')])
              if cat_io_contains(pp2,'templates_surfaces_32k') 
                SPM.xVol.G = fullfile(fileparts(mfilename('fullpath')),'templates_surfaces_32k',[ff2 xx2]);
              else
                SPM.xVol.G = fullfile(fileparts(mfilename('fullpath')),'templates_surfaces',[ff2 xx2]);
              end
            end
          end

          sinfo(i).Pmesh = SPM.xVol.G;
        else
          % 32k mesh?
          if SPM.xY.VY(1).dim(1) == 32492 || SPM.xY.VY(1).dim(1) == 64984
            sinfo(i).Pmesh = fullfile(fileparts(mfilename('fullpath')),'templates_surfaces_32k',...
              [sinfo(i).side '.central.freesurfer.gii']);
          else
            sinfo(i).Pmesh = fullfile(fileparts(mfilename('fullpath')),'templates_surfaces',...
              [sinfo(i).side '.central.freesurfer.gii']);
          end
        end
      catch
        % 32k mesh? 
        switch sinfo(i).ee
          case '.gii'
            if sinfo(i).exist && ~readsurf
              S = gifti(P{i});
            end
          case '.annot'
            if sinfo(i).exist && ~readsurf
              clear S; 
              try
                S = cat_io_FreeSurfer('read_annotation',P{1}); 
              catch
                cat_io_cprintf('warn',sprintf('Warning: Error while reading annotation file: \n  %s\n',P{1}));
              end
            end
        end
        
        if exist('S','var') && isfield(S,'cdata') && (length(S.cdata) == 32492 || length(S.cdata) == 64984)
          sinfo(i).Pmesh = fullfile(fileparts(mfilename('fullpath')),'templates_surfaces_32k',...
            [sinfo(i).side '.central.freesurfer.gii']);
        elseif exist('S','var') && isfloat(S) && (length(S) == 32492 || length(S) == 64984)
          sinfo(i).Pmesh = fullfile(fileparts(mfilename('fullpath')),'templates_surfaces_32k',...
            [sinfo(i).side '.central.freesurfer.gii']);
        else
          if sinfo(1).resampled_32k
            str_32k = '_32k';
          else
            str_32k = '';
          end
          sinfo(i).Pmesh = fullfile(fileparts(mfilename('fullpath')),['templates_surfaces' str_32k],...
            [sinfo(i).side '.central.freesurfer.gii']);
        end
      end
      sinfo(i).Pdata = sinfo(i).fname;
    end

    [ppm,ffm,eem]        = fileparts(sinfo(i).Pmesh);
    % RD202203 new garbage:   if ~strcmp(eem,'.gii'), eem = [eem '.gii']; end
    ffm                  = cat_io_strrep(ffm,{'thickness','central','white','pial','inner','outer','sphere','hull','core','layer4'},'central');
    % RD202203 new garbage:  ffm                  = cat_io_strrep(ffm,{'.resampled_32k','.resampled'},'');
    sinfo(i).Phull       = fullfile(ppm,strrep(strrep([ffm eem],'.central.','.hull.'),'.gii',''));
    sinfo(i).Pcore       = fullfile(ppm,strrep(strrep([ffm eem],'.central.','.core.'),'.gii',''));
    sinfo(i).Psphere     = fullfile(ppm,strrep([ffm eem],'.central.','.sphere.'));
    sinfo(i).Pspherereg  = fullfile(ppm,strrep([ffm eem],'.central.','.sphere.reg.'));
    sinfo(i).Pdefects    = fullfile(ppm,strrep([ffm eem],'.central.','.defects.'));
    sinfo(i).Player4     = fullfile(ppm,strrep([ffm eem],'.central.','.layer4.'));
    sinfo(i).Pwhite      = fullfile(ppm,strrep([ffm eem],'.central.','.white.'));
    sinfo(i).Ppial       = fullfile(ppm,strrep([ffm eem],'.central.','.pial.'));

    if ~exist(sinfo(i).Pdefects,'file'), sinfo(i).Pdefects = ''; end

    %{
    RD202203 new garbage
    if sinfo(i).resampled_32k || sinfo(i).resampled
      % in case of resampled data we have to use the freesurfer spheres ? 
      if sinfo(1).resampled_32k
        str_32k = '_32k';
      else
        str_32k = '';
      end
      sinfo(i).Psphere = fullfile(fileparts(mfilename('fullpath')),['templates_surfaces' str_32k],...
            [sinfo(i).side '.sphere.freesurfer.gii']);
      sinfo(i).Pspherereg = fullfile(fileparts(mfilename('fullpath')),['templates_surfaces' str_32k],...
            [sinfo(i).side '.sphere.reg.freesurfer.gii']);          
    end
    %}
    
    % check if files exist and if they have the same structure (size)
    Pmesh_data = dir(sinfo(i).Pmesh);
    FN = {'Phull','Pcore','Psphere','Pspherereg','Pwhite','Ppial','Player4'};
    for fni = 1:numel(FN)
      if exist(sinfo(i).(FN{fni}) ,'file')
        Pdata = dir(sinfo(i).(FN{fni}));
        if isempty(Pmesh_data) || isempty(Pdata) || abs(Pmesh_data.bytes - Pdata.bytes)>1500 % data saved by CAT tools may vary a little bit
          sinfo(i).(FN{fni})  = '';
        end
      else
        sinfo(i).(FN{fni})  = '';
      end
    end
    


    
    if sinfo(i).exist && readsurf
      if isfield(S,'vertices') 
        sinfo(i).nvertices = size(S.vertices,1);
      else
        if ~isempty(sinfo(i).Pmesh) && exist(sinfo(i).Pmesh,'file')
          S2 = gifti(sinfo(i).Pmesh);
          if ~isstruct(S), clear S; end
          if isfield(S2,'vertices'), S.vertices = S2.vertices; else, S.vertices = []; end
          if isfield(S2,'faces'),    S.faces    = S2.faces;    else, S.faces = []; end
        end
        if isfield(S,'vertices')
          sinfo(i).nvertices = size(S.vertices,1);
        elseif isfield(S,'cdata')
          sinfo(i).nvertices = size(S.cdata,1);
        else 
          sinfo(i).nvertices = nan;
        end
      end
      if isfield(S,'faces'),    sinfo(i).nfaces    = size(S.faces,1); end
      if isfield(S,'cdata'),    sinfo(i).ncdata    = size(S.cdata,1); end
    end

    [ppx,ffx] = spm_fileparts(pp); 
    sinfo(i).catxml = fullfile(ppx,strrep(ffx,'surf','report'),['cat_' sinfo(i).name '.xml']);
    if ~exist(sinfo(i).catxml,'file'), fullfile(pp,['cat_' sinfo(i).name '.xml']); end 
    if ~exist(sinfo(i).catxml,'file'), sinfo(i).catxml = ''; end 
    
    if nargout>1
      varargout{2}{i} = S; 
    else
      clear S
    end
  end
  varargout{1} = sinfo; 
end