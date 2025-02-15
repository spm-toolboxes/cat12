function cat_io_report(job,qa,subj,createerr)
% ______________________________________________________________________
% CAT error report to write the main processing parameter, the error
% message, some image parameter and add a picture of the original 
% image centered by its AC.
%
% This function is called in cat_run_newcatch.
%
%   cat_io_report(job,qa,subj[,createerr])
%
%   job         .. SPM job structure
%   qa          .. CAT quality assurance structure
%   subj        .. subject index
%
%
%   createerr   .. variable that create errors for debugging!
%                  different try-catch blocks to localize the error
%                  without using an error variable that is not allowed 
%                  in old Matlab Versions. 
%           1   .. early error in data preparation
%           2   .. preprocessing option error
%           3   .. preprocessing parameter error
%           4   .. general figure creation error
%           5   .. ?
%           6   .. printing error
%           7   .. ?
%           8   .. general figure creation error
%           9   .. error changing to SPM gray colorbar 
%       10-11   .. display error of original image / histogram
%       20-21   .. display error of modified image / histogram
%       30-31   .. display error of segmented image / histogram
%       40-41   .. display error of cortical surfaces / colorbar
%
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
% $Revision$  $Date$
  
%#ok<*AGROW>

  % close diagy 
  diary off;

  dbs = dbstatus; debug = 0; 
  for dbsi=1:numel(dbs), 
    if any(strcmp(dbs(dbsi).name,{'cat_io_report','cat_run_newcatch'}));
      debug = 1; break; 
    end;
  end
  
  if ~exist('createerr','var'); createerr = 0; end
  createerrtxt  = {}; 
  lasthours     = 10; if debug, lasthours = inf; end % only display data 
  str           = [];
  hhist         = zeros(3,1);
  haxis         = zeros(3,1);
   
  warning off; %#ok<WNOFF> % there is a div by 0 warning in spm_orthviews in linux
  global cat_err_res; 
 

  % preparation of specific varialbes that are include in cat_run_job and cat_main
  % --------------------------------------------------------------------  
  try
    % preprocessing subdirectories
    [mrifolder, reportfolder, surffolder] = cat_io_subfolders(job.data{subj},job);
    
    % setting template files
    [pp,ff] = spm_fileparts(job.data{subj});

    Pn  = fullfile(pp,mrifolder,['n' ff '.nii']); 
    Pm  = fullfile(pp,mrifolder,['m' ff '.nii']); 
    Pp0 = fullfile(pp,mrifolder,['p0' ff '.nii']); 

    VT0 = spm_vol(job.data{subj}); % original 
    if exist(Pn,'file'), VT1 = spm_vol(Pn); end %else VT0.mat = nan(4,4); end % intern
    [pth,nam] = spm_fileparts(VT0.fname); 

    tc = [cat(1,job.tissue(:).native) cat(1,job.tissue(:).warped)]; 

    % do dartel
    do_dartel = 1;      % always use dartel/shooting normalization
    if do_dartel
      need_dartel = any(job.output.warps) || ...
        job.output.bias.warped || job.output.bias.dartel || ...
        job.output.label.warped || job.output.label.dartel || ...
        any(any(tc(:,[4 5 6]))) || job.output.jacobian.warped || ...
        job.output.surface || job.output.ROI || ...
        any([job.output.te.warped,job.output.pc.warped,job.output.atlas.warped]);
      if ~need_dartel
        do_dartel = 0;
      end
    end

    if createerr==1, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
    
    % Find all templates and distinguish between Dartel and Shooting 
    % written to match for Template_1 or Template_0 as first template.  
    template = strrep(job.extopts.darteltpm{1},',1','');
    [templatep,templatef,templatee] = spm_fileparts(template);
    numpos = min([strfind(templatef,'Template_1'),strfind(templatef,'Template_0')]) + 8;
    if isempty(numpos)
      error('CAT:cat_main:TemplateNameError', ...
      ['Could not find the string "Template_1" (Dartel) or "Template_0" (Shooting) \n'...
       'that indicates the first file of the Dartel/Shooting template. \n' ...
       'The given filename is "%s" \n' ...
       ],templatef);
    end

    job.extopts.templates = cat_vol_findfiles(templatep,[templatef(1:numpos) '*' templatef(numpos+2:end) templatee],struct('depth',1)); 
    %%
 % 201812 -error in chimps   job.extopts.templates(cellfun('length',job.extopts.templates)~=numel(template)) = []; % furhter condition maybe necessary
    [template1p,template1f] = spm_fileparts(job.extopts.templates{1}); %#ok<ASGLU>
    if do_dartel 
      if (numel(job.extopts.templates)==6 || numel(job.extopts.templates)==7)
        % Dartel template
        if ~isempty(strfind(template1f,'Template_0')), job.extopts.templates(1) = []; end   
        do_dartel=1;
      elseif numel(job.extopts.templates)==5 
        % Shooting template
        do_dartel=2; 
      else
        templates = '';
        for ti=1:numel(job.extopts.templates)
          templates = sprintf('%s  %s\n',templates,job.extopts.templates{ti});
        end
        error('CAT:cat_main:TemplateFileError', ...
         ['Could not find the expected number of template. Dartel requires 6 Files (Template 1 to 6),\n' ...
          'whereas Shooting needs 5 files (Template 0 to 4). %d templates found: \n%s'],...
          numel(job.extopts.templates),templates);
      end
    end
  catch
    createerrtxt = [createerrtxt; {'Error:cat_io_report:CATpre','Error in cat_io_report data preparation.'}]; 
    cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
  end
    
    
    
  
  
    
%% display and print result if possible
%  ---------------------------------------------------------------------
 
 
  % CAT GUI parameter:
  % --------------------------------------------------------------------  
    
    if ~isfield(cat_err_res,'res') || ~isfield(cat_err_res.res,'do_dartel')
      if exist('do_dartel','var'), cat_err_res.res.do_dartel = do_dartel; else cat_err_res.res.do_dartel = 1; end
    end
    if ~isfield(cat_err_res.res,'stime'),  cat_err_res.res.stime = clock; end
    if ~isfield(cat_err_res.res,'tpm'),    cat_err_res.res.tpm(1).fname = job.opts.tpm{1}; end
    if ~isfield(cat_err_res.res,'Affine'), cat_err_res.res.Affine = eye(4); end
    if ~isfield(cat_err_res.res,'lkp'),    cat_err_res.res.lkp    = 1:6; end
    if ~isfield(cat_err_res.res,'mg'),     cat_err_res.res.mg     = nan(6,1); end
    if ~isfield(cat_err_res.res,'mn'),     cat_err_res.res.mn     = nan(1,6); end
    if ~isfield(cat_err_res.res,'Affine'), cat_err_res.res.Affine = eye(4); end
    if ~isfield(cat_err_res,'obj') || ~isfield(cat_err_res.obj,'Affine'), cat_err_res.obj.Affine = eye(4); end
    
    [ver_cat, rev_cat] = cat_version;
    ver_cat = ver_cat(4:end); % remove leading CAT
    [namspmv,rev_spm] = spm('Ver');
    QAS.software.version_spm = rev_spm;
    A = ver;
    for i=1:length(A)
      if strcmp(A(i).Name,'MATLAB')
        QAS.software.version_matlab = A(i).Version; 
      end
    end
    clear A
    
    if ispc,      OSname = 'WIN';
    elseif ismac, OSname = 'MAC';
    else          OSname = 'LINUX';
    end
    
    qa.software.system               = OSname;
    qa.software.version_cat          = ver_cat;
    if ~isfield(qa.software,'version_segment')
      qa.software.version_segment    = rev_cat;
    end
    qa.software.revision_cat         = rev_cat;
    try
      qa.qualitymeasures.res_vx_vol  = sqrt(sum(VT0.mat(1:3,1:3).^2));
    catch
      qa.qualitymeasures.res_vx_vol  = nan(1,3);
    end
    try
      qa.qualitymeasures.res_vx_voli = sqrt(sum(VT1.mat(1:3,1:3).^2));
    catch
      qa.qualitymeasures.res_vx_voli = nan(1,3);
    end
    qa.qualityratings.res_RMS      = mean(qa.qualitymeasures.res_vx_vol.^2).^0.5;
    qa.qualityratings.NCR          = nan; 
    qa.qualityratings.ICR          = nan; 
    qa.qualityratings.IQR          = nan;
    qa.subjectmeasures.EC_abs      = nan;
    qa.subjectmeasures.vol_abs_CGW = nan(1,4);
    qa.subjectmeasures.vol_rel_CGW = nan(1,4);
    qa.subjectmeasures.vol_TIV     = nan;
    str = cat_main_reportstr(job,cat_err_res.res,qa);
    str = str{1}; 
  

  %% image parameter
  % --------------------------------------------------------------------
  try
    %%
    Ysrc = spm_read_vols(VT0); 
    imat = spm_imatrix(VT0.mat);
    deg  = char(176); 
    str2 = [];
    str2 = [str2 struct('name','\bfImagedata','value','')];
    str2 = [str2 struct('name','  Datatype','value',spm_type(VT0.dt(1)))];
    str2 = [str2 struct('name','  AC (mm)','value',sprintf('% 10.1f  % 10.1f  % 10.1f ',imat(1:3)))];
    str2 = [str2 struct('name','  Rotation (rad)','value',sprintf('% 10.2f%s  % 10.2f%s % 10.2f%s ',...
      imat(4) ./ (pi/180), deg, imat(5) ./ (pi/180), deg, imat(6) ./ (pi/180), deg ))];
    str2 = [str2 struct('name','  Voxel size (mm)','value',sprintf('% 10.2f  % 10.2f  % 10.2f ',imat(7:9)))];
    
    if createerr==3, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end

    %%
    if isfield(cat_err_res,'res')
      %str2 = [str2 struct('name','  HDl | HDh | BG )','value',sprintf('% 10.2f  % 10.2f  % 10.2f', ...
      %  mean(cat_err_res.res.mn(cat_err_res.res.lkp==4 & cat_err_res.res.mg'>0.3)), ...
      %  mean(cat_err_res.res.mn(cat_err_res.res.lkp==5 & cat_err_res.res.mg'>0.3)), ...
      %  mean(cat_err_res.res.mn(cat_err_res.res.lkp==6 & cat_err_res.res.mg'>0.4))) )];
      iaffine = spm_imatrix(cat_err_res.res.Affine); 
      str2 = [str2 struct('name','\bfAffine','value','')];
      str2 = [str2 struct('name','  Translation (mm)','value',sprintf('% 10.1f  % 10.1f  % 10.1f ',iaffine(1:3)))];
      str2 = [str2 struct('name','  Rotation','value',sprintf('% 10.2f%s % 10.2f%s % 10.2f%s ',...
        iaffine(4) ./ (pi/180), deg, iaffine(5) ./ (pi/180), deg, iaffine(6) ./ (pi/180), deg))];
      str2 = [str2 struct('name','  Scaling','value',sprintf('% 10.2f  % 10.2f  % 10.2f ',iaffine(7:9)))];
      str2 = [str2 struct('name','  Shear','value',sprintf('% 10.2f  % 10.2f  % 10.2f' ,iaffine(10:12)))];
      if all(~isnan(cat_err_res.res.mn))
        str2 = [str2 struct('name','\bfSPM tissues peaks','value','')];
        str2 = [str2 struct('name','  CSF | GM | WM ','value',sprintf('% 10.2f  % 10.2f  % 10.2f', ...
          cat_stat_nanmean(cat_err_res.res.mn(cat_err_res.res.lkp==3 & cat_err_res.res.mg'>0.3)), ...
          cat_stat_nanmean(cat_err_res.res.mn(cat_err_res.res.lkp==1 & cat_err_res.res.mg'>0.3)), ...
          cat_stat_nanmean(cat_err_res.res.mn(cat_err_res.res.lkp==2 & cat_err_res.res.mg'>0.3))) )];
        str2 = [str2 struct('name','  HDl | HDh | BG ','value',sprintf('% 10.2f  % 10.2f  % 10.2f', ...
          cat_stat_nanmean(cat_err_res.res.mn(cat_err_res.res.lkp==4 & cat_err_res.res.mg'>0.3)), ...
          cat_stat_nanmean(cat_err_res.res.mn(cat_err_res.res.lkp==5 & cat_err_res.res.mg'>0.3)), ...
          cat_stat_nanmean(cat_err_res.res.mn(cat_err_res.res.lkp==6 & cat_err_res.res.mg'>0.4))) )];
      end
    elseif isfield(cat_err_res,'obj')
      iaffine = spm_imatrix(cat_err_res.obj.Affine); 
      str2 = [str2 struct('name','\bfAffine','value','')];
      str2 = [str2 struct('name','  Translation','value',sprintf('% 10.1f  % 10.1f  % 10.1f ',iaffine(1:3)))];
      str2 = [str2 struct('name','  Rotation','value',sprintf('% 10.2f%s % 10.2f%s % 10.2f%s ', ...
        iaffine(4) ./ (pi/180), deg, iaffine(5) ./ (pi/180), deg, iaffine(6) ./ (pi/180), deg))];
      str2 = [str2 struct('name','  Scaling','value',sprintf('% 10.2f  % 10.2f  % 10.2f ',iaffine(7:9)))];
      str2 = [str2 struct('name','  Shear','value',sprintf('% 10.2f  % 10.2f  % 10.2f ',iaffine(10:12)))];
      str2 = [str2 struct('name','\bfIntensities','value','')];
      str2 = [str2 struct('name','  min | max','value',sprintf('% 10.2f  % 10.2f ',min(Ysrc(:)),max(Ysrc(:))))];
      str2 = [str2 struct('name','  mean | std','value',sprintf('% 10.2f  % 10.2f ',cat_stat_nanmean(Ysrc(:)),cat_stat_nanstd(Ysrc(:))))];
    else
      str2 = [str2 struct('name','\bfIntensities','value','')];
      str2 = [str2 struct('name','  min | max','value',sprintf('% 10.2f  % 10.2f ',min(Ysrc(:)),max(Ysrc(:))))];
      str2 = [str2 struct('name','  mean | std','value',sprintf('% 10.2f  % 10.2f ',cat_stat_nanmean(Ysrc(:)),cat_stat_nanstd(Ysrc(:))))];
      str2 = [str2 struct('name','  isinf | isnan','value',sprintf('% 10.0f  % 10.0f ',sum(isinf(Ysrc(:))),sum(isnan(Ysrc(:)))))];
    end  
        

    % adding one space for correct printing of bold fonts
    for si=1:numel(str)
      str(si).name   = [str(si).name  '  '];  str(si).value  = [str(si).value  '  '];
    end
    for si=1:numel(str2)
      str2(si).name  = [str2(si).name '  '];  str2(si).value = [str2(si).value '  '];
    end
  catch
    createerrtxt = [createerrtxt; {'Error:cat_io_report:CATgui','Error in cat_io_report GUI parameter report creation > incomple image parameters.'}]; 
    cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
  end

  
  
  
 
%% Figure
%  ---------------------------------------------------------------------
  try
    VT0 = spm_vol(job.data{subj}); % original 
  
    nprog = ( isfield(job,'printPID') && job.printPID ) || ... PID field
          ( isempty(findobj('type','Figure','Tag','CAT') ) && ... no menus
            isempty(findobj('type','Figure','Tag','Menu') ) );
    fg  = spm_figure('FindWin','Graphics'); 
    set(0,'CurrentFigure',fg)
    if isempty(fg)
      if nprog
        fg = spm_figure('Create','Graphics','visible','off'); 
      else
        fg = spm_figure('Create','Graphics','visible','on'); 
      end;
    else
      if nprog, set(fg,'visible','off'); end
    end
  
    set(fg,'windowstyle','normal');
    spm_figure('Clear','Graphics'); 
    switch computer
      case {'PCWIN','PCWIN64'}, fontsize = 8;
      case {'GLNXA','GLNXA64'}, fontsize = 8;
      case {'MACI','MACI64'},   fontsize = 9;
      otherwise,                fontsize = 9;
    end
    ax=axes('Position',[0.01 0.75 0.99 0.24],'Visible','off','Parent',fg);

    text(0,0.99,  ['Segmentation: ' spm_str_manip(VT0.fname,'k60d') '       '],...
      'FontSize',fontsize+1,'FontWeight','Bold','Interpreter','none','Parent',ax);


    % check colormap name
    cm = job.extopts.colormap; 

    % SPM_orthviews seems to allow only 60 values
    % It further requires a modified colormaps with lower values that the
    % colorscale and small adaptation for the values. 
    hlevel     = 240; 
    volcolors  = 60;  % spm standard 
    surfcolors = 128; 
    switch lower(cm)
      case {'bcgwhw','bcgwhn'} % cat colormaps with larger range
        cmap  = [
          cat_io_colormaps([cm 'ov'],volcolors); 
          flipud(cat_io_colormaps([cm 'ov'],volcolors))
          jet(surfcolors)];
        mlt = 2; 
      case {'jet','hsv','hot','cool','spring','summer','autumn','winter','gray','bone','copper','pink'}
        cmap  = [
          eval(sprintf('%s(%d)',cm,volcolors));
          flipud(eval(sprintf('%s(%d)',cm,volcolors)));
          jet(surfcolors)]; 
        mlt = 1; 
      otherwise
        cmap = [
          eval(sprintf('%s(%d)',cm,volcolors));
          flipud(eval(sprintf('%s(%d)',cm,volcolors)));
          jet(surfcolors)]; 
        mlt = 1; 
    end
    colormap(cmap); 
    spm_orthviews('Redraw');

    htext = zeros(5,2,2);
    for i=1:size(str,2)   % main parameter
      htext(1,i,1) = text(0.01,0.98-(0.045*i), str(i).name  ,'FontSize',fontsize, 'Interpreter','tex','Parent',ax);
      htext(1,i,2) = text(0.51,0.98-(0.045*i), str(i).value ,'FontSize',fontsize, 'Interpreter','tex','Parent',ax);
    end
    htext(2,i,1) = text(0.01,0.52-(0.045*1), '\bfCAT preprocessing error:  ','FontSize',fontsize, 'Interpreter','tex','Parent',ax);
    for i=1:size(qa.error,1) % error message
      errtxt = strrep([qa.error{i} '  '],'_','\_');
      htext(2,i,1) = text(0.01,0.52-(0.045*(i+2)), errtxt ,'FontSize',fontsize, 'Interpreter','tex','Parent',ax,'Color',[0.8 0 0]);
    end
    for i=1:size(str2,2) % image-parameter
      htext(2,i,1) = text(0.51,0.52-(0.045*i), str2(i).name  ,'FontSize',fontsize, 'Interpreter','tex','Parent',ax);
      htext(2,i,2) = text(0.75,0.52-(0.045*i), str2(i).value ,'FontSize',fontsize, 'Interpreter','tex','Parent',ax);
    end
    pos = [0.01 0.34 0.48 0.32; 0.51 0.34 0.48 0.32; ...
           0.01 0.01 0.48 0.32; 0.51 0.01 0.48 0.32];
    spm_orthviews('Reset');

    if createerr==4, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end

    
   
    %% Yo - original image in original space
    %  -----------------------------------------------------------------
    %  using of SPM peak values didn't work in some cases (5-10%), 
    %  so we have to load the image and estimate the WM intensity 
    try
      %%
      % there appear too many annoying warning under windows for some reasons which I don't know
      warning off; hho = spm_orthviews('Image',VT0,pos(1,:)); warning on
      spm_orthviews('Caption',hho,{'*.nii (Original)'},'FontSize',fontsize,'FontWeight','Bold');
      Ysrcs    = single(Ysrc+0); spm_smooth(Ysrcs,Ysrcs,repmat(0.2,1,3));
      haxis(1) = axes('Position',[pos(1,1:2) + [pos(1,3)*0.58 0],pos(1,3)*0.38,pos(1,4)*0.35] ); 
      [y,x]    = hist(Ysrcs(:),hlevel); y = y ./ max(y)*100; %clear Ysrcs;
      if exist(Pp0,'file'), Pp0data = dir(Pp0); Pp0data = etime(clock,datevec(Pp0data.datenum))/3600 < lasthours; else, Pp0data = 0; end
%%
      if createerr==10, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
      ch  = cumsum(y)/sum(y); 
      if Pp0data, Vp0 = spm_vol(Pp0); end
      if Pp0data && all(Vp0.dim == size(Ysrcs))
        Yp0  = spm_read_vols(Vp0);
        mth  = find(x>=cat_stat_nanmean(Ysrcs(Yp0(:)>2.7 & Yp0(:)<3.3)), 1 ,'first');
      else
        mth  = find(ch>0.95,1,'first');
      end
      %spm_orthviews('window',hho,[x(find(ch>0.02,1,'first')) x(mth) + (mlt-1)*diff(x([find(ch>0.02,1,'first'),mth]))]); hold on;
      spm_orthviews('Zoom');
      spm_orthviews('Reposition',[0 0 0]); 
      spm_orthviews('Redraw');
      % colorbar
      try 
        %%
        bd   = [find(ch>0.01,1,'first'),mth];
        ylims{1} = [min(y(round(numel(y)*0.1):end)),max(y(round(numel(y)*0.1):end)) * 4/3];
        xlims{1} = x(bd) + [0,(4/3-1)*diff(x([find(ch>0.02,1,'first'),mth]))]; M = x>=xlims{1}(1) & x<=xlims{1}(2);
        hdata{1} = [x(M) fliplr(x(M)); max(eps,min(ylims{1}(2),y(M))) zeros(1,sum(M)); [x(M) fliplr(x(M))]];
        hhist(1) = fill(hdata{1}(1,:),hdata{1}(2,:),hdata{1}(3,:),'EdgeColor',[0.0 0.0 1.0],'LineWidth',1);
        if createerr==11, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
        %caxis(xlims{1} .* [1,1.5*(2*volcolors+surfcolors)/volcolors]) 
        caxis(xlims{1} + [0,((2*2*volcolors+surfcolors)/volcolors)*diff(x([find(ch>0.02,1,'first'),mth]))]); %; .* [1,1.5*(2*volcolors+surfcolors)/volcolors]) 
        ylim(ylims{1}); xlim(xlims{1}); box on; grid on; 
      catch
        createerrtxt = [createerrtxt; {'Error:cat_io_report:dispYoHist','Error in displaying the color histogram of the original image.'}]; 
        cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});  
        if hhist(1)>0, delete(hhist(1)); hhist(1)=0; end
        xlim([0,1]),ylim([0,1]); grid off; 
        text(pos(1,1) + pos(1,3)*0.35,pos(1,2) + pos(1,4)*0.55,'HIST ERROR','FontSize',20,'color',[0.8 0 0]);
      end
    catch
      createerrtxt = [createerrtxt; {'Error:cat_io_report:dispYo','Error in displaying the original image.'}]; 
      cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
    end
    

    

    %% Ym - normalized image in original space
    mtxt = 'm*.nii (part. processed.)'; 
    if exist(Pn,'file'), Pndata = dir(Pn); Pndata = etime(clock,datevec(Pndata.datenum))/3600 < lasthours; else Pndata = 0; end
    if exist(Pm,'file'), Pmdata = dir(Pm); Pmdata = etime(clock,datevec(Pmdata.datenum))/3600 < lasthours; else Pmdata = 0; end
    if ~Pmdata && Pndata, Pm = Pn; Pmdata = Pndata; mtxt = 'n*.nii (part. processed.)'; end
    if Pmdata
      try
        hhm = spm_orthviews('Image',spm_vol(Pm),pos(2,:));
        spm_orthviews('Caption',hhm,{mtxt},'FontSize',fontsize,'FontWeight','Bold');
        haxis(2) = axes('Position',[pos(2,1:2) + [pos(2,3)*0.58 0],pos(1,3)*0.38,pos(1,4)*0.35] );
        Yms = spm_read_vols(spm_vol(Pm)); spm_smooth(Yms,Yms,repmat(0.2,1,3));
        [y,x] = hist(Yms(:),hlevel);  y = y ./ max(y)*100;
        ch    = cumsum(y)/sum(y); 
        if createerr==20, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
        if Pp0data, Vp0 = spm_vol(Pp0); end
        if Pp0data && all(Vp0.dim == size(Yms))
          Yp0 = spm_read_vols(spm_vol(Pp0));
          mth = find(x>=cat_stat_nanmean(Yms(Yp0(:)>2.9 & Yp0(:)<3.1)), 1 ,'first');
        else
          mth = find(ch>0.95,1,'first');
        end
        spm_orthviews('window',hhm,[x(find(ch>0.02,1,'first')) x(mth) + (mlt-1)*diff(x([find(ch>0.02,1,'first'),mth]))]); hold on;
        spm_orthviews('Zoom'); % redraw Yo
        clear Yms;
        try
          % colorbar
          if createerr==21, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
          bd  = [find(ch>0.01,1,'first'),mth]; 
          ylims{2} = [min(y(round(numel(y)*0.1):end)),max(y(round(numel(y)*0.1):end)) * 4/3]; 
          xlims{2} = x(bd) + [0,(4/3-1)*diff(x([find(ch>0.02,1,'first'),mth]))]; M = x>=xlims{2}(1) & x<=xlims{2}(2);
          hdata{2} = [x(M) fliplr(x(M)); max(eps,min(ylims{2}(2),y(M))) zeros(1,sum(M)); [x(M) fliplr(x(M))]];
          hhist(2) = fill(hdata{2}(1,:),hdata{2}(2,:),hdata{2}(3,:),'EdgeColor',[0.0 0.0 1.0],'LineWidth',1);
          %caxis(xlims{2} .* [1,1.5*(2*volcolors+surfcolors)/volcolors]) 
          caxis(xlims{2} + [0,((2*2*volcolors+surfcolors)/volcolors)*diff(x([find(ch>0.02,1,'first'),mth]))]); %; .* [1,1.5*(2*volcolors+surfcolors)/volcolors]) 
          ylim(ylims{2}); xlim(xlims{2}); box on; grid on; 
          if round(x(mth))==1
            xlim([0 4/3]); 
            set(gca,'XTick',0:1/3:4/3,'XTickLabel',{'BG','CSF','GM','WM','BV/HD'});
          end
        catch
          createerrtxt = [createerrtxt; {'Error:cat_io_report:dispYmHist','Error in displaying the color histogram of the processed image.'}]; 
          cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
          if hhist(2)>0, delete(hhist(2)); hhist(2)=0; end
          xlim([0,1]),ylim([0,1]); grid off; 
          if haxis(2)>0, 
          else  text(pos(2,1) + pos(2,3)*0.35,pos(2,2) + pos(2,4)*0.55,'HIST ERROR','FontSize',20,'color',[0.8 0 0]);
          end
        end
      catch
        createerrtxt = [createerrtxt; {'Error:cat_io_report:dispYo','Error in displaying the processed image.'}]; 
        cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
      end
    end
    
    
    
    %% Yp0 - segmentation in original space
    if exist(Pp0,'file'), Pp0data = dir(Pp0); Pp0data = etime(datevec(Pp0data.datenum),cat_err_res.stime)/3600 > 0; else Pp0data = 0; end
    if Pp0data || (isfield(cat_err_res,'init') && isfield(cat_err_res.init,'Yp0'))
      try
        %%
        if isfield(cat_err_res.init,'Yp0') && exist(Pn,'file')
          Vp0     = spm_vol(Pn); 
          Yp0     = single(cat_vol_resize(cat_err_res.init.Yp0,'dereduceBrain',cat_err_res.init.BB));
          if isa(cat_err_res.init.Yp0,'uint8')
            if max( Yp0(:)) == round(255/5*3)
              Yp0 = Yp0 / 255 * 5;
            elseif max( Yp0(:)) > 100
              Yp0 = Yp0 / 255 * 5;
            end 
          end
        else
          % here we load the Yp0 that is only code with WM == 3
          Vp0     = spm_vol(Pp0);  
          Yp0     = spm_read_vols(spm_vol(Pp0)); 
        end
        
        
        % create V structure that include the image
        Vp0       = rmfield(Vp0,'private');
        Vp0.dt    = [2 0]; 
        Vp0.dat   = cat_vol_ctype(Yp0 / 5 * 255);
        Vp0.dim   = size(Yp0);
        Vp0.pinfo = repmat([5/255;0],1,size(Yp0,3));
        hhp0      = spm_orthviews('Image',Vp0,pos(3,:));
        
        if createerr==30, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
        spm_orthviews('Caption',hhp0,'p0*.nii (Segmentation)','FontSize',fontsize,'FontWeight','Bold');
        spm_orthviews('window',hhp0,[0,6]);
        spm_orthviews('Zoom'); 
        
        
        % smooth version for histogram
        Yp0s  = Yp0; 
        spm_smooth(Yp0s,Yp0s,repmat(0.5,1,3));
        [y,x] = hist(Yp0s(:),0:1/30:6); clear Yms; y = y ./ max(y)*100; clear Yp0s; 
        y     = min(y,max(y(2:end))); % ignore background
       
        try
          %% colorbar
          if createerr==31, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
          haxis(3) = axes('Position',[pos(3,1:2) + [pos(3,3)*0.58 0.01],pos(1,3)*0.38,pos(1,4)*0.35]  );
          xlims{3} = [0 4]; 
          ylims{3} = [min(y) max(y)] .* [0 4/3];  M = x <= xlims{3}(2);
          hdata{3} = [x(M) fliplr(x(M));  max(eps,min(ylims{3}(2),y(M))) zeros(1,sum(M));  [x(M) fliplr(x(M))]];
          hhist(3) = fill( hdata{3}(1,:) , hdata{3}(2,:) , hdata{3}(3,:), 'EdgeColor',[0.0 0.0 1.0], 'LineWidth',1);
          caxis(xlims{3} .* [1,1.5*(2*volcolors+surfcolors)/volcolors]) 
          ylim(ylims{3}); xlim(xlims{3}); box on; grid on; 
          set(gca,'XTick',0:1:4,'XTickLabel',{'BG','CSF','GM','WM','(WMH)'});
        catch
          createerrtxt = [createerrtxt; {'Error:cat_io_report:dispYp0Hist','Error in displaying the color histogram of the segmented image.'}]; 
          cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
          if hhist(3)>0, delete(hhist(3)); hhist(3)=0; end
          xlim([0,1]),ylim([0,1]); grid off;
          if haxis(3)>0, text(0.5,0.5,'HIST ERROR','FontSize',20,'color',[0.8 0 0]);
          else text(pos(3,1) + pos(3,3)*0.35,pos(3,2) + pos(3,4)*0.55,'HIST ERROR','FontSize',20,'color',[0.8 0 0]);
          end
        end
      catch
        createerrtxt = [createerrtxt; {'Error:cat_io_report:dispYp0','Error in displaying the segmented image.'}]; 
        cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
      end
    end
    if createerr==8, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
    try, spm_orthviews('redraw'); end

    
    %% surface or histogram
    if isfield(cat_err_res,'obj') && isfield(cat_err_res.obj,'Affine')
      Affine = cat_err_res.obj.Affine; 
    elseif isfield(cat_err_res,'res') && isfield(cat_err_res.res,'Affine')
      Affine = cat_err_res.res.Affine; 
    else
      Affine = eye(4);
    end
    imat = spm_imatrix(Affine); Rigid = spm_matrix([imat(1:6) 1 1 1 0 0 0]); clear imat;
    
    Pthick = fullfile(pp,surffolder,sprintf('lh.thickness.%s',ff));
    if exist(Pthick,'file'), Pthickdata = dir(Pthick); Pthickdata = etime(datevec(Pthickdata.datenum),cat_err_res.stime)/3600 > 0; else Pthickdata = 0; end
    if Pthickdata
      hCS = subplot('Position',[0.5 0.05 0.55 0.25],'visible','off'); 
      try 
        hSD = cat_surf_display(struct('data',{Pthick},'readsurf',0,'expert',2,...
          'multisurf',1,'view','s','parent',hCS,'verb',0,'caxis',[0 6],'imgprint',struct('do',0)));
        
        for ppi = 1:numel(hSD{1}.patch)
          V = (Rigid * ([hSD{1}.patch(ppi).Vertices, ones(size(hSD{1}.patch(ppi).Vertices,1),1)])' )'; 
          V(:,4) = []; hSD{1}.patch(ppi).Vertices = V;
        end
        
        if createerr==40, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
        colormap(cmap);  set(hSD{1}.colourbar,'visible','off'); 
        cc{3} = axes('Position',[0.62 0.02 0.3 0.01],'Parent',fg); image((volcolors*2+1:1:volcolors*2+surfcolors));
        set(cc{3},'XTick',1:(surfcolors-1)/6:surfcolors,'XTickLabel',{'0','1','2','3','4','5','          6 mm'},...
          'YTickLabel','','YTick',[],'TickLength',[0 0],'FontSize',fontsize,'FontWeight','Bold');
      catch
        createerrtxt = [createerrtxt; {'Error:cat_io_report:dispSurf','Error in displaying the cortical surface(s).'}]; 
        cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
      end
    end
  catch
    createerrtxt = [createerrtxt; {'Error:cat_io_report:Fig','Error in CAT report figure creation!'}]; 
    cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
  end
  spm_orthviews('Zoom'); 
  %spm_orthviews('BB'); % update BB to avoid problems with different resolution 
  
  
  %% TPM overlay with brain/head and head/background surfaces
  global st;
  warning('off','MATLAB:subscripting:noSubscriptsSpecified')
  showTPMsurf = 1; % ... also in default mode 
  if job.extopts.expertgui>0 - showTPMsurf
    try
      Phull = {cat_surf_create_TPM_hull_surface(job.opts.tpm)};
      for id=1
        spm_orthviews('AddContext',id); % need the context menu for mesh handling
    
        try
          spm_ov_mesh('display',id,Phull);
        catch
          fprintf('Please update to a newer version of spm12 for using this contour overlay\n');
          try
            spm_update
          catch
            fprintf('Update to the newest SPM12 version failed. Please update manually.\n');
          end
        end
    
        % apply affine scaling for gifti objects
        for ix=1:numel(Phull) 
          % load mesh
          try spm_ov_mesh('display',id,Phull(ix)); end 
    
          %% apply affine scaling for gifti objects (inv(cat_err_res.res.Affine)
          V = (inv(Affine) * ([st.vols{id}.mesh.meshes(ix).vertices,...
               ones(size(st.vols{id}.mesh.meshes(ix).vertices,1),1)])' )';
          V(:,4) = [];
          M0 = st.vols{id}.mesh.meshes(1:ix-1);
          M1 = st.vols{id}.mesh.meshes(ix);
          M1 = subsasgn(M1,struct('subs','vertices','type','.'),single(V));
          st.vols{id}.mesh.meshes = [M0,M1];
        end
    
        %% change line style
        hM = findobj(st.vols{id}.ax{1}.cm,'Label','Mesh');
        UD = get(hM,'UserData');
        UD.width = 0.75; 
        UD.style = repmat({'b--'},1,numel(Phull));
        set(hM,'UserData',UD);
        try spm_ov_mesh('redraw',id); end
        spm_orthviews('redraw',id);
    
        %% TPM legend
        %ccl{1} = axes('Position',[pos(1,1:2) 0 0] + [0.33 -0.005 0.02 0.02],'Parent',fg);
        %cclp = plot(ccl{1},([0 0.4;0.6 1])',[0 0; 0 0],'b-'); text(ccl{1},1.2,0,'TPM fit');
        %set( cclp,'LineWidth',0.75); axis(ccl{1},'off')
      end
    end
  end
  
  
  %% report error
  try 
    if exist('ax','var') && size(createerrtxt,1)>0
      %%
      text(0.01,0.52 - (0.045*(size(qa.error,1)+2)), '\bfcat\_io\_report error:  ' ,'FontSize',fontsize, 'Interpreter','tex','Parent',ax);
      for i=1:size(createerrtxt,1)
        createerrtxt2{i,2} = strrep([createerrtxt{i,2} '  '],'_','\_');
        text(0.01,0.52 - (0.045*(size(qa.error,1)+2)) - (0.045*i), createerrtxt2{i,2} ,'FontSize',fontsize, 'Interpreter','tex','Parent',ax,'Color',[0.8 0 0]);
      end
    end
  catch
    createerrtxt = [createerrtxt; {'Error:cat_io_report:dispErr','Error in displaying the errors of cat_io_report'}]; 
    cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
  end
  
    
  
  %% print group report file 
  try
    fg = spm_figure('FindWin','Graphics');
    set(0,'CurrentFigure',fg)
    fprintf(1,'\n'); 

    % print subject report file as standard PDF/PNG/... file
    job.imgprint.type  = 'pdf';
    job.imgprint.dpi   = 100;
    job.imgprint.fdpi  = @(x) ['-r' num2str(x)];
    job.imgprint.ftype = @(x) ['-d' num2str(x)];
    job.imgprint.fname     = fullfile(pth,reportfolder,['catreport_' nam '.' job.imgprint.type]); 
    job.imgprint.fnamej    = fullfile(pth,reportfolder,['catreportj_' nam '.jpg']); 

    fgold.PaperPositionMode = get(fg,'PaperPositionMode');
    fgold.PaperPosition     = get(fg,'PaperPosition');
    fgold.resize            = get(fg,'resize');

    % it is necessary to change some figure properties especialy the fontsizes 
    if createerr==6, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
    set(fg,'PaperPositionMode','auto','resize','on','PaperPosition',[0 0 1 1]);
    for hti = 1:numel(htext), if htext(hti)>0, set(htext(hti),'Fontsize',fontsize*0.8); end; end
    
    % pdf is not working yet with Octave
    if strcmpi(spm_check_version,'octave')
      print(fg, job.imgprint.ftype('jpeg'), job.imgprint.fnamej); 
    else
      print(fg, job.imgprint.ftype(job.imgprint.type), job.imgprint.fdpi(job.imgprint.dpi), job.imgprint.fname); 
      print(fg, job.imgprint.ftype('jpeg')           , job.imgprint.fdpi(job.imgprint.dpi), job.imgprint.fnamej); 
      for hti = 1:numel(htext), if htext(hti)>0, set(htext(hti),'Fontsize',fontsize); end; end
      set(fg,'PaperPositionMode',fgold.PaperPositionMode,'resize',fgold.resize,'PaperPosition',fgold.PaperPosition);
    end
    fprintf('Print ''Graphics'' figure to: \n  %s\n',job.imgprint.fname);

  catch
    createerrtxt = [createerrtxt; {'Error:cat_io_report:print','Error printing CAT error report.'}]; 
    cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
  end
      
      
  %% reset colormap to the simple SPM like gray60 colormap
  if exist('hSD','var')
    % if there is a surface than we have to use the gray colormap also here
    % because the colorbar change!
    try 
      cat_surf_render2('ColourMap',hSD{1}.axis,gray(128));
      cat_surf_render2('Clim',hSD{1}.axis,[0 6]);
      if createerr==41, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
      axes(cc{3}); image(0:60); 
      set(cc{3},'XTick',max(1,0:10:60),'XTickLabel',{'0','1','2','3','4','5','          6 mm'},...
        'YTickLabel','','YTick',[],'TickLength',[0 0],'FontSize',fontsize,'FontWeight','Bold');
    catch
      createerrtxt = [createerrtxt; {'Error:cat_io_report:surfcolmap','Error in displaying surface colormap.'}]; 
      cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
    end
  end

  try
    %% %cmap = gray(60); colormap(cmap); 
    % RD202101: This part would has to be replaced completelly with a
    %           dynamic peak estimation and setting for the original image
    cmap(1:volcolors,:) = gray(volcolors); 
    cmap(volcolors+1:2*volcolors,:) = flipud(pink(volcolors)); 
    cmap(volcolors*2+1:volcolors*2+surfcolors,:) = jet(surfcolors); 
    colormap(fg,cmap); %caxis([0,numel(cmap)]); 
  
    %if exist('hho' ,'var'), spm_orthviews('window',hho ,[0,6]); end % not fixed ! ... 
    %if exist('hhm' ,'var'), spm_orthviews('window',hhm ,[0,3/4]); end
    if exist('hhp0','var'), spm_orthviews('window',hhp0,[0,4]);   end

    % update histograms - switch from color to gray
    if exist('hhist','var')
      %%
      if hhist(1)>0 && haxis(1)>0, set(hhist(1),'cdata',(hdata{1}(3,:)' - min(hdata{1}(3,:))) / diff([min(hdata{1}(3,:)),max(hdata{1}(3,:))]) ); caxis(haxis(1),[0 4]); end
      if createerr==9, error(sprintf('error:cat_io_report:createerr_%d',createerr),'Test'); end
      if hhist(2)>0 && haxis(2)>0, set(hhist(2),'cdata',(hdata{2}(3,:)' - min(hdata{2}(3,:))) / diff([min(hdata{2}(3,:)),max(hdata{2}(3,:))])); caxis(haxis(2),[0 4]); end
      if hhist(3)>0 && haxis(3)>0, set(hhist(3),'cdata',(hdata{3}(3,:)' - min(hdata{3}(3,:))) / diff([min(hdata{3}(3,:)),max(hdata{3}(3,:))])); caxis(haxis(3),[0 4]); end
    end
  catch
    createerrtxt = [createerrtxt; {'Error:cat_io_report','Error in changing colormap.'}]; 
    cat_io_cprintf('err','%30s: %s\n',createerrtxt{end,1},createerrtxt{end,2});
  end
  %warning on;  %#ok<WNON>

  if job.extopts.expertgui>0 - showTPMsurf && exist('hM','var') && ...
    isfield(st,'vol') && iscell(st.vols) && numel(st.vols)>=id && ...
    isfield(st.vols{id},'ax') && iscell(st.vols{id}.ax) && isfield(st.vols{id}.ax{1},'cm')
    id = 1; 
    hM = findobj(st.vols{id}.ax{1}.cm,'Label','Mesh');
    UD = get(hM,'UserData');
    UD.width = 0.75; 
    UD.style = repmat({'r--'},1,numel(Phull));
    set(hM,'UserData',UD);
    try spm_ov_mesh('redraw',id); end
  end  
  
  warning('ON','MATLAB:subscripting:noSubscriptsSpecified')
  
end