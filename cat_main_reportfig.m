function cat_main_reportfig(Ym,Yp0,Yl1,Psurf,job,qa,res,str)
% ______________________________________________________________________
% 
% Display CAT report in the SPM grafics window and save a PDF and JPG
% file in the report directory.
%
%   cat_main_reportfig(Ym,Yp0,Psurf,job,res,str);
%
%   Ym      .. intensity normalized image
%   Yp0     .. segmentation label map
%   Psurf   .. central surface file
%   job     .. SPM/CAT parameter structure
%   res     .. SPM result structure
%   str     .. Parameter strings (see cat_main_reportstr)
%   Yl1     .. Label map for ventricle and WMHs
%   qa      .. WMH handling
%
%   special options via:
%   job.extopts.colormap .. colormap 
%   job.extopts.report
%    .useoverlay  .. different p0 overlays
%                    (0 - no, 1 - red mask, 2 - atlas [default] ... )
%    .type        .. volume/surface print layout 
%                    (1 - Yo,Ym,Yp0,CS-top, 2 - Yo,Yp0,CS-left-right-top)
%    .color       .. 
%   See also cat_main_reportstr and cat_main_reportcmd.
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
% $Id$
  
  %#ok<*TRYNC,*AGROW,*ASGLU>
 % warning off; %#ok<WNOFF> % there is a div by 0 warning in spm_orthviews in linux
  dbs = dbstatus; debug = 0; for dbsi=1:numel(dbs), if strcmp(dbs(dbsi).name,mfilename); debug = 1; break; end; end 
  
  global st; % global variable of spm_orthviews
  
  fg  = spm_figure('FindWin','Graphics'); 
  set(0,'CurrentFigure',fg)
  
  % remove CAT12 figure background image from start
  try
    fgc = get(fg,'Children');
    if ~isempty(fgc)
      fgcc = get(fgc,'Children');
      if ~isempty(fgcc)
        % remove figure elements to prevent further interations
        delete(fgcc);
        spm_figure('Clear',fg)
        
        % run the reportfig function the first time to fully clear the 
        % changes by the cat start figure
        cat_main_reportfig(Ym,Yp0,Yl1,[],job,qa,res,str)
      end
    end
  end

  def.extopts.report.useoverlay   = 2;  % different p0 overlays, described below in the Yp0 print settings
                                        % (0 - no, 1 - red mask, 2 - blue BG, red BVs, WMHs [default] ... )
  def.extopts.report.type         = 2;  % (1 - Yo,Ym,Yp0,CS-top, 2 - Yo,Yp0,CS-left-right-top) 
  def.extopts.report.color        = cat_get_defaults('extopts.report.color'); 
                                        % background gray level that focus on: white, black, gray
                                        % [] - current figure, 0.95 - light gray
  def.extopts.expertgui           = cat_get_defaults('extopts.expertgui'); 
  def.extopts.WMHC                = cat_get_defaults('extopts.WMHC'); 
  def.extopts.print               = 2; 
  %def.extopts.report.thickvar     = 0;  % 0 - thickness, 1 - thickness corrected by global mean 
  %def.extopts.report.orthviewbox  = 0;  % 0 - off, 1 - on; % not ready
  %if job.extopts.report.orthviewbox && cm(1)=='b', for ai=1:3, st.vols{1}.ax{2}.ax.Visible = 'off'; end; end
  job = cat_io_checkinopt(job,def); 
  
  if isempty(job.extopts.report.color)
    job.extopts.report.color = get(fg,'color'); 
  elseif numel(job.extopts.report.color)==1
    job.extopts.report.color = ones(1,3) * job.extopts.report.color; 
  end
  if job.extopts.expertgui && isempty(job.extopts.report.color)
    job.extopts.report.color = [0.95 0.95 0.95]; 
  end
  
  % ratings for colorful ouput of longitudinal results (see also cat_main_reportstr) 
  QMC         = cat_io_colormaps('marks+',17);
  QMCt        = [cat_io_colormaps('hotinv',30);cat_io_colormaps('cold',30)]; QMCt = QMCt([11:30,32:end-9],:); 
  color       = @(QMC,m)  QMC(max(1,min(size(QMC,1),round(((m-1)*3)+1))),:);
  colort      = @(QMC,m)  QMC(max(1,min(size(QMC,1),round((m)))),:);
  marks2str   = @(mark,str) sprintf('\\color[rgb]{%0.2f %0.2f %0.2f}%s',color(QMC,real(mark)),str);
  marks2strt  = @(mark,str) sprintf('\\color[rgb]{%0.2f %0.2f %0.2f}%s',colort(QMCt,real(mark*4 + 21)),str);
  mark2rps    = @(mark) min(100,max(0,105 - real(mark)*10)) + isnan(real(mark)).*real(mark);
 
  VT  = res.image(1); 
  VT0 = res.image0(1);
  % this block is to handle the surface only output of longitudinal reports 
  if isempty( VT0 ) || isempty(fieldnames(VT0))
    if ~isempty(Psurf) && isfield(Psurf,'Pthick')
      [pth,nam,ee] = spm_fileparts(Psurf(1).Pthick); 
      if ~strcmp(ee,'.gii'), nam = ee(2:end); else, [tmp,nam] = spm_fileparts(nam); end
      VT0.fname = Psurf(1).Pthick;
      dispvol   = 0; 
    else
      cat_io_cprintf('err','Found no volume or surface. Skip printing.\n');
      return;
    end
  else
    [pth,nam] = spm_fileparts(VT0.fname); 
    dispvol   = 1; 
  end
    
  % in case of SPM input segmentation we have to add the name here to have a clearly different naming of the CAT output 
  if isfield(res,'spmpp'), nam = ['c1' nam]; end % no changes in VT0!
   
  % definition of subfolders
  [mrifolder, reportfolder, surffolder, labelfolder] = cat_io_subfolders(VT0.fname,job);
  
  nprog = ( isfield(job,'printPID') && job.printPID ) || ... PID field
          ( isempty(findobj('type','Figure','Tag','CAT') ) && ... no menus
            isempty(findobj('type','Figure','Tag','Menu') ) );
  if isempty(fg)
    if nprog
      fg = spm_figure('Create','Graphics','visible','off'); 
    else
      fg = spm_figure('Create','Graphics','visible','on'); 
    end
  else
    if nprog, set(fg,'visible','off'); end
  end
  set(fg,'windowstyle','normal'); 
  try, spm_figure('Clear',fg); end
  switch computer
    case {'PCWIN','PCWIN64'}, fontsize = 8;
    case {'GLNXA','GLNXA64'}, fontsize = 8;
    case {'MACI','MACI64'},   fontsize = 9.5;
    otherwise,                fontsize = 9.5;
  end
  % the size of the figure is adapted to screen size but we must also update the font size
  PaperSize = get(fg,'PaperSize');
  spm_figure_scale = get(fg,'Position'); spm_figure_scale = spm_figure_scale(4)*PaperSize(2)/1000; 
  fontsize = fontsize * spm_figure_scale; 

  % get axis
  try
    ax = axes('Position',[0.01 0.75 0.98 0.24],'Visible','off','Parent',fg);
  catch
    error('Do not close the SPM Graphics window during preprocessing');
  end

  % set backgroundcolor
  if ~isempty(job.extopts.report.color)
    set(fg,'color',job.extopts.report.color);
    if isempty(job.extopts.colormap) || strcmp(job.extopts.colormap,'BCGWHw')
      if any( job.extopts.report.color < 0.4 ) 
        job.extopts.colormap = 'BCGWHn';
      elseif any( job.extopts.report.color < 0.95 ) 
        job.extopts.colormap = 'BCGWHg';
      end
    end
    if any( job.extopts.report.color < 0.4 )
      fontcolor = [1 1 1]; 
    else
      fontcolor = [0 0 0]; 
    end
  else
    fontcolor = [0 0 0]; 
  end
  % check colormap name
  cm = job.extopts.colormap;
  switch lower(cm)
    case {'jet','hsv','hot','cool','spring','summer','autumn','winter',...
        'gray','bone','copper','pink','bcgwhw','bcgwhn','bcgwhg'}
    otherwise
      cat_io_cprintf(job.color.warning,'WARNING:Unknown Colormap - use default.\n'); 
      cm = 'gray';
  end
  
  % some sans serif fonts we prefere
  if exist('ax','var')
    fontname = get(ax,'fontname');
  end
  if strcmpi(spm_check_version,'octave')
    fontname = 'Helvetica'; 
  else
    fonts  = listfonts; 
    pfonts = {'Verdana','Arial','Helvetica','Tebuchet MS','Tahoma','Geneva','Microsoft Sans Serif'};
    for pfi = 1:numel(pfonts)
      ffonti = [];
      try
        ffonti = find(cellfun('isempty',strfind(fonts,pfonts{pfi},'ForceCellOutput',1))==0,1,'first'); 
      end
      if ~isempty( ffonti )
        fontname  = fonts{ffonti};
        break
      end
    end   
  end
  
 
  
  
  
  
  %% colormap labels 
  %  ----------------------------------------------------------------------
  %  var in:  
  %      out:  ytickm, yticklabelm, yticklabelo, yticklabeli, cmap, cmmax
  
  % SPM_orthviews work with 60 values. 
  % For the surface we use a larger colormap.
  surfcolors = 128; 
  % In the longitudinal report we use another colormap without white rather
  % than green to make it clear that these are changes and not thickness values. 
  if isfield(res,'long')
    cmap3 = flipud(cat_io_colormaps('BWR',surfcolors));
  else
    cmap3 = jet(surfcolors); 
  end
  % #################
  % T1 vs T2/PD labeling
  % ################
  switch lower(cm)
    case {'bcgwhw','bcgwhn','bcgwhg'} 
      % CAT colormap with larger range colorrange from 0 (BG) to 1 (WM) to 2 (HD).  
      ytick        = [1,5:5:60];
      if isfield(job.extopts,'inv_weighting') && job.extopts.inv_weighting
        Tth = [cat_stat_kmeans(Ym(Yp0(:)>0.5 & Yp0(:)<1.5),2,0),...
               cat_stat_kmeans(Ym(Yp0(:)>1.5 & Yp0(:)<2.5),5,0),...
               cat_stat_kmeans(Ym(Yp0(:)>2.5 & Yp0(:)<3.5),2,0)]; 
        [x,od] = sort(Tth); tiss = {' CSF',' GM',' WM'};   
        yticklabel = {' BG',' ',tiss{od(1)},'    ',tiss{od(2)},'    ',tiss{od(3)},' ',' ',' ',' ',' ',' Vessels/Head '};
      else
        yticklabel = {' BG',' ',' CSF',' CGM',' GM',' GWM',' WM',' ',' ',' ',' ',' ',' Vessels/Head '};
      end
      yticklabelo  = {' BG',' ','    ','    ','   ','    ',' ~WM  ',' ',' ',' ',' ',' ',' Vessels/Head '};
      yticklabeli  = {' BG',' ','    ','    ','   ','    ','         ',' ',' ',' ',' ',' ',' Vessels/Head '};
      cmap         = [cat_io_colormaps([cm 'ov'],60);flipud(cat_io_colormaps([cm 'ov'],60));cmap3]; 
      cmmax        = 2;
    case {'gray'} 
      % CAT colormap with larger range colorrange from 0 (BG) to 1 (WM) to 2 (HD).  
      ytick        = [1,15:15:60];
      if isfield(job.extopts,'inv_weighting') && job.extopts.inv_weighting
        Tth = [cat_stat_kmeans(Ym(Yp0(:)>0.5 & Yp0(:)<1.5),2,0),...
               cat_stat_kmeans(Ym(Yp0(:)>1.5 & Yp0(:)<2.5),5,0),...
               cat_stat_kmeans(Ym(Yp0(:)>2.5 & Yp0(:)<3.5),2,0)]; 
        [x,od] = sort(Tth); tiss = {' CSF',' GM',' WM'};  
        yticklabel = {' BG',tiss{od(1)},tiss{od(2)},tiss{od(3)},' Vessels/Head '};
      else
        yticklabel = {' BG',' CSF',' GM',' WM',' Vessels/Head '};
      end
      yticklabelo  = {' BG','    ','   ',' WM',' Vessels/Head '};
      yticklabeli  = {' BG','    ','   ','   ',' Vessels/Head '};
      cmap         = [eval(sprintf('%s(60)',cm));flipud(eval(sprintf('%s(60)',cm)));cmap3]; 
      cmmax        = 7/6;
    case {'jet','hsv','hot','cool','spring','summer','autumn','winter','bone','copper','pink'}
      % default colormaps 
      ytick        = [1 20 40 60]; 
      yticklabel   = {' BG',' CSF',' GM',' WM'};
      yticklabelo  = {' BG','    ','   ',' WM'};
      yticklabeli  = {' BG','    ','   ','   '};
      cmap         = [eval(sprintf('%s(60)',cm));flipud(eval(sprintf('%s(60)',cm)));cmap3]; 
      cmmax        = 1;
    otherwise
      cat_io_cprintf(job.color.warning,'WARNING:Unknown Colormap - use default.\n'); 
  end
  
  % For the segmentation map an overlay color map is used that is
  % independent of the first colormap.
  ytickp0      = [    1,   13.5,  17.5,   30,   45,     52,    56,      60];
  if job.extopts.expertgui>1
    yticklabelp0 = {' BG',' HD',' CSF',' GM',' WM',' WMHs',' Ventricle',' Vessels/Dura->CSF'};
  else
    yticklabelp0 = {' BG',' HD',' CSF',' GM',' WM',' WMHs',' ',' Vessels/Dura->CSF'};
  end
  %if job.extopts.WMHC<1
  %  yticklabelp0{end-2} = ' \color[rgb]{1,0,1}no WMHC!';
  if isfield(qa,'subjectmeasures') && isfield(qa.subjectmeasures, 'vol_rel_WMH') 
    if job.extopts.WMHC<2 
      if qa.subjectmeasures.vol_rel_WMH>0.01 || ...
        (qa.subjectmeasures.vol_abs_WMH / qa.subjectmeasures.vol_abs_CGW(3) )>0.02
        yticklabelp0{end-2} = ' \color[rgb]{1,0,1}uncorrected WMHs=GM!';
      else
        yticklabelp0{end-2} = ' no/small WMHs';
      end
    elseif job.extopts.WMHC==2 
      if qa.subjectmeasures.vol_rel_WMH>0.01 || ...
         qa.subjectmeasures.vol_abs_WMH / qa.subjectmeasures.vol_rel_CGW(3)>0.02
        yticklabelp0{end-2} = ' \color[rgb]{1,0,1}WMHs->WM';
      else
        yticklabelp0{end-2} = ' no/small WMHs->WM';
      end
    else
      if qa.subjectmeasures.vol_rel_WMH>0.01 || ...
         qa.subjectmeasures.vol_abs_WMH / qa.subjectmeasures.vol_rel_CGW(3)>0.02
        yticklabelp0{end-2} = ' \color[rgb]{1,0,1}WMHs';
      else
        yticklabelp0{end-2} = ' no/small WMHs';
      end
    end
  end
  
  if strcmpi(spm_check_version,'octave')
    colormap(cmap);
  else
    colormap(fg,cmap);
  end
  try spm_orthviews('Redraw'); end
  %  ----------------------------------------------------------------------

  
  
  
  %% print header and parameters
  %  ----------------------------------------------------------------------
  warning('off','MATLAB:tex')

  % print header
  npara  = '\color[rgb]{0  0   0}'; 
  cpara  = '\color[rgb]{0  0   1}'; 
  if isfield(res,'spmpp') && res.spmpp, SPMCATstr = [cpara 'SPM-']; else, SPMCATstr = 'CAT-'; end
  hd = text(0,0.99,  [SPMCATstr 'Segmentation: ' npara strrep( strrep( spm_str_manip(VT0.fname,'k80d'),'\','\\'), '_','\_') '       '],...
    'FontName',fontname,'FontSize',fontsize+1,'color',fontcolor,'FontWeight','Bold','Interpreter','tex','Parent',ax);

  % replace tex color settings 
  if mean(fontcolor)>0.5
    for stri = 1:numel(str)
      for stri2 = 1:numel(str{stri})
        colstrb = strfind(str{stri}(stri2).value,'\color[rgb]{');
        for ci = numel(colstrb):-1:1
          colstre = colstrb(ci) + 10 + find( str{stri}(stri2).value(colstrb(ci) + 12 : end) == '}' ,1,'first');
          colval  = cell2mat(textscan( str{stri}(stri2).value(colstrb(ci) + 12 : colstre),'%f %f %f')); 
          if all( colval <= [0.1 0.5 1] ) && colval(3)>0 % replace blue by brighter and bolder values
            str{stri}(stri2).value = sprintf('%s%s%s',str{stri}(stri2).value(1:colstrb(ci)-1),...
              sprintf('\\bf\\color[rgb]{%f %f %f}',min(1,[0.1 0.7 1.0] + colval)),str{stri}(stri2).value(colstre+2:end)); 
          elseif mean( colval ) < 0.1 
            str{stri}(stri2).value = sprintf('%s%s%s',str{stri}(stri2).value(1:colstrb(ci)-1),...
              '\color[rgb]{1 1 1}',str{stri}(stri2).value(colstre+2:end));
          end
        end
      end
    end
  end
  
  % print parameters
  htext = zeros(5,2,2);
  for i=1:size(str{1},2)   % main parameter
    htext(1,i,1) = text(0.01,0.98-(0.055*i), str{1}(i).name  ,'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','none','Parent',ax);
    htext(1,i,2) = text(0.51,0.98-(0.055*i), str{1}(i).value ,'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
  end
  if isfield(res,'long') 
    % Adaption for longitudinal reports, where we focus on changes between 
    % timepoints or scanners in case of test-retest data.
    % As far as we have some additional plots here also the creation of the 
    % text/table is here and not in cat_main_reportstr. 
    
    
    %% image and processing quality normalized to the best value 
    %  --------------------------------------------------------------------
    
    % measures to display
    if isfield(res.long,'change_qar_IQR')
      IQR  = res.long.change_qar_IQR; 
    else
      IQR  = nan; 
    end
    ZSCORE  = (res.long.vres.zscore - max(res.long.vres.zscore)); 
    RMSE = (min(res.long.vres.RMSEidiff) - res.long.vres.RMSEidiff )';
    
    % text to display (header + main measures)
    if isfield(res.long,'qar_IQR')
      IQRE = (max(res.long.qar_IQR) - min(res.long.qar_IQR)) + 0.5; 
    else
      IQRE = nan; 
    end
    htext(2,1,1) = text(0.01,0.48 - (0.055 * 1), '\bfImage and preprocessing quality changes (best to worst):', ...
      'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
    if isfield(res.long,'qar_IQR')
      lstr{1}(1) = struct('name','\bf\color[rgb]{.6 0  0}IQR:' , ...
        'value',  marks2str(min(res.long.qar_IQR),   sprintf('%0.2f%%' ,mark2rps(min(res.long.qar_IQR) )) ), ... ,mark2grad(min(res.long.qar_IQR)
        'value2', marks2str( (IQRE - 0.5) * 2 + 0.5, sprintf('%+0.2fpp',mark2rps(IQRE) - 100)));
    else
      lstr{1}(1) = struct('name','','value','','value2','');
    end
    
    % only plot ZSCORE and RMSE if more than two timepoints are available
    if ~isnan(ZSCORE)
      if numel(res.long.files) > 2
        val  = min(res.long.vres.zscore) - max(res.long.vres.zscore); 
        val2 = marks2str(min(10.5,max(val * 100 + 0.5)),sprintf('%+0.3f',val)); 
        cstr = '\bf\color[rgb]{0 0.6 0}ZSCORE:';
      else
        val2 = ''; 
        cstr = 'ZSCORE:';
      end
      lstr{1}(2) = struct('name',cstr ,...
        'value', marks2str( min(10.5,max(0.5,(0.98 - min(res.long.vres.zscore))*100+0.5)) , sprintf('%0.3f',min(res.long.vres.zscore)) ), ...
        'value2',val2); 
      if numel(res.long.files) > 2
        val  = max(res.long.vres.RMSEidiff) - min(res.long.vres.RMSEidiff);
        val2 = marks2str( min(10.5,max(0.5,max(0,val-0.05)*100+0.5)),sprintf('%+0.3f',val)); 
        cstr = '\bf\color[rgb]{0 .3 .7}RMSE:'; 
      else
        val2 = ''; 
        cstr = 'RMSE:'; 
      end
      lstr{1}(3) = struct('name',cstr, ...
        'value' ,marks2str( min(10.5,max(0.5,max(0,max(res.long.vres.RMSEidiff) - 0.05)*50+0.5))  , ...
           sprintf('%0.3f',max(res.long.vres.RMSEidiff)) ), ...
        'value2',val2); 
    end
    for i=1:size(lstr{1},2)  % qa-measurements
      htext(2,i+1,1) = text(0.01,0.47-(0.055*(i+1)), lstr{1}(i).name  , ...
        'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
      htext(2,i+1,2) = text(0.135,0.47-(0.055*(i+1)), lstr{1}(i).value , 'HorizontalAlignment','right', ......
        'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
      htext(2,i+1,3) = text(0.14,0.47-(0.055*(i+1)), lstr{1}(i).value2, 'HorizontalAlignment','left', ......
        'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
    end
    
    % create figure
    mdiff  = min([ ZSCORE; (mark2rps(IQRE) - 100)/100; RMSE]); 
    mlim   = min(-0.05,-ceil(abs(mdiff)*20)/20); 
    tcmap  = [0.6 0 0; 0 .6 0; 0 0.3 0.7; 0.5 0.5 0.5]; 
    marker = {'^','s','>','o'}; 
    leg    = {}; 
    axi(1) = axes('Position',[0.24,0.745,0.22,0.095],'Parent',fg); cp(1) = gca; hold on; 
    set(axi(1),'Color',job.extopts.report.color,'YAxisLocation','right','box','on','XAxisLocation','bottom'); 
    % plot QC boxes
    if 0 %mlim < -0.04
      fb = fill(cp{1},[0 numel(res.long.files) numel(res.long.files) 0]+0.5,-[ 40  40  0  0]/1000,'green');
      set(fb,'Facecolor',[0.8 1.0 0.8],'LineStyle','none','FaceAlpha',0.5); leg = [leg {':)'}];
      if mlim < -0.04
        fb = fill(cp{1},[0 numel(res.long.files) numel(res.long.files) 0]+0.5,-[ 80  80  40   40]/1000,'yellow');
        set(fb,'Facecolor',[1.0 1.0 0.8],'LineStyle','none','FaceAlpha',0.5); leg = [leg {':|'}];
      end
      if mlim < -0.08
        fb = fill(cp{1},[0 numel(res.long.files) numel(res.long.files) 0]+0.5,[mlim mlim -0.04 -0.04],'red');
        set(fb,'Facecolor',[1.0 0.8 0.8],'LineStyle','none','FaceAlpha',0.5); leg = [leg {':('}];
      end
    end
    if ~any(isnan(ZSCORE)) && numel(res.long.files) > 2
      leg    = [leg {'dIQR/100','dZSCORE','dRMSE'}];
    else
      leg    = [leg {'dIQR/100'}]; 
    end
    % plot lines
    pt = plot( axi(1), IQR/100 ); set(pt,'Color',tcmap(1,:),'Marker',marker{2}, ...
      'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
    if ~any(isnan(ZSCORE)) && numel(res.long.files) > 2
      pt = plot( axi(1), ZSCORE ); set(pt,'Color',tcmap(2,:),'Marker',marker{1}, ...
        'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
      pt = plot( axi(1), RMSE); set(pt,'Color',tcmap(3,:),'Marker',marker{3}, ...
        'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
    end
    % final settings
    ylim( [mlim 0]); xlim([0.9 numel(res.long.files)+0.1]); 
    set(cp(1),'Fontsize',fontsize*0.8,'xtick',max(1,0:round(numel(res.long.files)/100)*10:numel(res.long.files)), ...
      'ytick',mlim:max(0.01,round((abs(mlim)/5)*200)/200):0,...
      'XAxisLocation','origin');
    lh(1) = legend(leg,'Location','southoutside','Orientation','horizontal','box','off','FontSize',fontsize*.8); grid on; 
    
    
    
    
    %% morphmetric parameter normalized to the first value 
    %  --------------------------------------------------------------------
    if isfield(res.long,'vol_rel_CGW')
      leg          = {'dGMV','dWMV','dCSFV'};
      val2f        = @(valr,vala) marks2strt(valr  * 100,sprintf('%+0.2f',vala)); 
      htext(3,1,1) = text(0.51,0.48-(0.055), '\bfGlobal tissue volumes and their maximum change:', ...
        'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);

      % rGMV
      li          = 1;
      valr        = max(diff(res.long.vol_rel_CGW(:,2))); 
      vala        = max(diff(res.long.vol_abs_CGW(:,2))); 
      lstr{2}(li) = struct('name','\bf\color[rgb]{0 0.6 0}GMV:', ...
        'value' ,  sprintf('%0.0fml' , res.long.vol_abs_CGW(1,2)), ...
        'value2',  [val2f(valr,vala) 'ml'] ); 

      % rWMV
      li          = li + 1;
      valr        = max(diff(res.long.vol_rel_CGW(:,3))); 
      vala        = max(diff(res.long.vol_abs_CGW(:,3))); 
      lstr{2}(li) = struct('name','\bf\color[rgb]{0.6 0 0}WMV:', ...
        'value' ,  sprintf('%0.0fml' , res.long.vol_abs_CGW(1,3)), ...
        'value2',  [val2f(valr,vala) 'ml'] );

      % rCSFV
      li          = li + 1;
      valr        = max(diff(res.long.vol_rel_CGW(:,1)));
      vala        = max(diff(res.long.vol_abs_CGW(:,1)));
      lstr{2}(li) = struct('name','\bf\color[rgb]{0 .3 0.7}CSFV:', ...
        'value',   sprintf('%0.0fml' , res.long.vol_abs_CGW(1,1)), ...
        'value2',  [val2f(valr,vala) 'ml'] );

      % WMHs 
      % ###########################    
      if any( res.long.vol_abs_WMH )
        li          = li + 1;
        leg         = [leg,{'dWMHs'}];
        val         = max(diff(res.long.vol_abs_WMH));
        lstr{2}(li) = struct('name','\bf\color[rgb]{0.8 0.4 0.8}WMHs:', ...
          'value',   sprintf('%0.0fml' , res.long.vol_abs_WMH(1,1)), ...
          'value2',  [val2f(max(diff( res.long.vol_abs_WMH ./ res.long.vol_TIV')),val) 'ml'] );
      end

      % TIV (looks boring in adult but not in children)
      li          = li + 1;
      leg         = [leg,{'dTIV'}];
      valr        = mean(diff(res.long.vol_TIV) ./ mean(res.long.vol_TIV));
      vala        = mean(diff(res.long.vol_TIV));
      lstr{2}(li) = struct('name','\bf\color[rgb]{.5 .5 .5}TIV:' ,...
        'value',   sprintf('%0.0fml' , res.long.vol_TIV(1,1)) , ...
        'value2',  [val2f(valr,vala) 'ml'] );

      % TSA
      if isfield(res.long,'surf_TSA')
        li          = li + 1;
        leg         = [leg,{'TSA/1k'}];
        valr        = mean(diff(res.long.surf_TSA) ./ mean(res.long.surf_TSA));
        vala        = mean(diff(res.long.surf_TSA));
        lstr{2}(li) = struct('name','\bf\color[rgb]{.7 .2 .7}TSA:', ...
          'value' ,  sprintf('%0.0fsqmm',res.long.surf_TSA(1,1)), ...
          'value2',  [val2f(valr,vala) 'sqmm']);  
  %      marks2str(min(10.5,max(val * 100 + 0.5)),sprintf('%+0.3fmm',val)));
      end

      % thickness
      if isfield(res.long,'dist_thickness')
        li          = li + 1;
        leg         = [leg,{'dGMT*1k'}];
        val         = mean(res.long.change_dist_thickness(2:end,1));
        lstr{2}(li) = struct('name','\bf\color[rgb]{.3 .0 .7}GMT:', ...
          'value' ,  sprintf('%0.2fmm',res.long.dist_thickness(1,1)), ...
          'value2',  [val2f(val,val) 'mm']);  
  %      marks2str(min(10.5,max(val * 100 + 0.5)),sprintf('%+0.3fmm',val)));
      end

      mod = 0.003 * (isfield(res.long,'surf_TSA') + isfield(res.long,'dist_thickness'));
      for i=1:size(lstr{2},2)  % morphometric measurements
        htext(3,i+1,1) = text(0.52,0.47-((0.055-mod)*(i+1)), lstr{2}(i).name  , ...
          'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
        htext(3,i+1,2) = text(0.64,0.47-((0.055-mod)*(i+1)), lstr{2}(i).value , 'HorizontalAlignment','right', ...
          'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
        htext(3,i+1,3) = text(0.645,0.47-((0.055-mod)*(i+1)), lstr{2}(i).value2 ,'HorizontalAlignment','left', ...
          'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
      end
    
      %% figure
      tcmap  = [0 0.3 0.7; 0 .6 0; 0.6 0 0; 0.5 0.5 0.5; 0.3 0.0 0.7; 0.7 0.2 0.7; 0.8 0.4 0.8]; 
      marker = {'<','^','>','o','d','s'}; 
      axi(2) = axes('Position',[0.75,0.745,0.22,0.095],'Parent',fg); cp(2) = gca; hold on;
      set(axi(2),'Color',job.extopts.report.color,'YAxisLocation','right','XAxisLocation','bottom','box','on'); 
      % plot tissue values
      for ti = [2 3 1]
        pt = plot( axi(2), ( res.long.vol_abs_CGW(:,ti) - repmat( res.long.vol_abs_CGW(1,ti) , size(res.long.vol_abs_CGW,1) , 1) )');
        set(pt,'Color',tcmap(ti,:),'Marker',marker{ti},...
          'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
      end
      % plot WMH
      if any( res.long.vol_abs_WMH )
        pt = plot( axi(2), res.long.vol_abs_WMH - res.long.vol_abs_WMH(1));
        set(pt,'Color',tcmap(6,:),'LineStyle','-','Marker',marker{4}, ...
          'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
      end
      % plot TIV 
      pt = plot( axi(2), res.long.vol_TIV - res.long.vol_TIV(1));
      set(pt,'Color',tcmap(4,:),'LineStyle','-','Marker',marker{4}, ...
        'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
      % plot TSA
      if isfield(res.long,'surf_TSA')
        pt = plot( axi(2), res.long.surf_TSA - res.long.surf_TSA(1));
        set(pt,'Color',tcmap(5,:),'LineStyle','-','Marker',marker{5}, ...
          'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
      end
      % plot thickness
      if isfield(res.long,'change_dist_thickness')
        pt = plot( axi(2), res.long.change_dist_thickness(:,1) * 1000);
        set(pt,'Color',tcmap(6,:),'LineStyle','-','Marker',marker{6}, ...
          'MarkerFaceColor',job.extopts.report.color,'MarkerSize',max(3,6 - numel(res.long.files)/10));
      end
      %mlim = max( 20 , ceil( max( max( abs( [ diff( res.long.vol_abs_CGW(:,1:3) ,1 ); diff( res.long.vol_TIV ) ] ) )) / 20 ) * 20);
      mlim = max( 20 , ceil( max( max( abs( [ ...
        [res.long.vol_abs_CGW(:,1:3) - repmat( res.long.vol_abs_CGW(1,1:3) , size(res.long.vol_abs_CGW,1) , 1)], ...
        [res.long.vol_TIV - res.long.vol_TIV(1)]  ] ) )) * 1.2 / 20 ) * 20);
      if isfield(res.long,'surf_TSA')
        mlim = max( mlim , ceil( max( max( abs( res.long.surf_TSA - res.long.surf_TSA(1) ) )) * 1.2 / 20 ) * 20);
      end
      if isfield(res.long,'change_dist_thickness')
        mlim = max( mlim , ceil( max( max( res.long.change_dist_thickness(:,1) * 1000 )) * 1.2 / 20 ) * 20);
      end
      ylim([-mlim mlim]); xlim([0.9 numel(res.long.files)+0.1]); 
      set(cp(2),'Fontsize',fontsize*0.8,'xtick',max(1,0:round(numel(res.long.files)/100)*10:numel(res.long.files)), ...
        'ytick',-mlim:round(mlim*2 / 4):mlim,'XAxisLocation','top');
      lh(2) = legend(leg,'Location','southoutside','Orientation','horizontal','box','off','FontSize',fontsize*0.8); grid on; 
    end
   
    

  else
    for i=1:size(str{2},2)  % qa-measurements
      htext(2,i,1) = text(0.01,0.45-(0.055*i), str{2}(i).name  ,'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
      htext(2,i,2) = text(0.33,0.45-(0.055*i), str{2}(i).value ,'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
    end
    for i=1:size(str{3},2)  % subject-measurements
      htext(3,i,1) = text(0.51,0.45-(0.055*i), str{3}(i).name  ,'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
      htext(3,i,2) = text(0.70,0.45-(0.055*i), str{3}(i).value ,'FontName',fontname,'FontSize',fontsize,'color',fontcolor,'Interpreter','tex','Parent',ax);
    end
  end
  
  %% position values of the orthview/surface subfigures
  pos = {[0.008 0.375 0.486 0.35]; [0.506 0.375 0.486 0.35]; ...
         [0.008 0.010 0.486 0.35]; [0.506 0.010 0.486 0.35]};
  try spm_orthviews('Reset'); end

  % BB box is not optimal for all images
  disptype = 'affine'; 
  warning('off','MATLAB:handle_graphics:exceptions:SceneNode')
  if isfield(res,'Affine')
    switch disptype
      case 'affine'
        dispmat = res.Affine; 
        warning('off')
        try spm_orthviews('BB', res.bb*0.95 ); end
        warning('on')
      case 'rigid'
        % this does not work so good... AC has a little offset ...
        aff = spm_imatrix(res.Affine);  scale = aff(7:9); 
        try spm_orthviews('BB', res.bb ./ mean(scale)); end
        dispmat = R; 
    end
  else
    dispmat = eye(4);
  end
  
  
  
  %  ----------------------------------------------------------------------
  %  Yo - original image in original space
  %  ----------------------------------------------------------------------
  %  Using of SPM peak values didn't work in some cases (5-10%), so we have 
  %  to load the image and estimate the WM intensity. 
  if dispvol
    if isfield(res,'long')
      try
        %% create SPM volume plots
        if isfield(res,'Vmnw')
          Ymn = res.Vmnw.dat(:,:,:); 
        else
          Ymn = res.Vmn.dat(:,:,:); 
        end
        WMth  = cat_stat_kmeans(Ymn(Ymn(:)>0)) * 3; 
        if isfield(res,'Vmnw')
          hho   = spm_orthviews('Image',res.Vmn,pos{1}); 
          T1txt = sprintf('GM tissue changes (FWHM %d mm)',res.long.smoothvol);
        else
          hho   = spm_orthviews('Image',res.Vmn,pos{1}); 
          T1txt = 'High variant regions'; 
        end
        spm_orthviews('Caption',hho,T1txt,'FontName',fontname,'FontSize',fontsize-1,'color',fontcolor,'FontWeight','Bold');
        spm_orthviews('window',hho,[0 single(WMth)*cmmax]); 
        % rang = (0:6)'; hoti = [rang,flip(rang,1)*0,flip(rang,1)]; hoti(1,:) = [0 0 0]; 
        %rang = (0:10)'; hoti = [rang,flip(rang,1),flip(rang,1)*0] .* repmat(min(max(rang),rang*2)/2,1,3) / max(rang) * 1; hoti(1,:) = [0 0 0];
        if isfield(res,'Vidiffw')
          Vidiff  = res.Vidiff; Vidiff.dat = Vidiff.dat * 100; 
          BCGWH   = [cat_io_colormaps('hotinv',35);cat_io_colormaps('cold',35)]; BCGWH = BCGWH(6:65,:); 
          BCGWH   = BCGWH.^1.1 * 2; % less transparent for high values
          maxdiff = max(1,round(std(Vidiff.dat(:)))) * 10; 
          spm_orthviews('addtruecolourimage',hho,Vidiff, BCGWH,0.4,maxdiff,-maxdiff); 
        else
          hoti = cat_io_colormaps('hot',10); 
          spm_orthviews('addtruecolourimage',hho,res.Vrdiff,hoti,0.4,0.5,0.4); 
        end
        spm_orthviews('redraw');
      end
      try
        % SPM colorbar settings
        warning('off','MATLAB:warn_r14_stucture_assignment');
        set(st.vols{1}.blobs{1}.cbar,'Position', [st.vols{1}.ax{3}.ax.Position(1) st.vols{1}.ax{1}.ax.Position(2) 0.01 0.13] ); 
        set(st.vols{1}.blobs{1}.cbar,'YAxisLocation', 'right','FontSize', fontsize-2,'FontName',fontname,'xcolor',fontcolor,'ycolor',fontcolor); 
        set(st.vols{1}.blobs{1}.cbar,'NextPlot','add'); % avoid replacing of labels
        set(st.vols{1}.blobs{1}.cbar,'HitTest','off'); % avoid replacing of labels
        % I create a copy of the colorbar that is not changed by SPM and 
        % remove the old one that is redrawn by SPM otherwise.
        st.vols{1}.blobs1cbar = copyobj(st.vols{1}.blobs{1}.cbar,fg);
        st.vols{1}.blobs{1}   = rmfield(st.vols{1}.blobs{1},'cbar'); 
      end
      try
        %% create glassbrain images
        glassbr       = cat_plot_glassbrain( res.Vmn ); 
        glassbrain    = cat_plot_glassbrain( res.Vidiff ); 
        glassbrainmax = max( maxdiff / 5, ceil(mean(abs(glassbrain{1}(:))) + 4*std(glassbrain{1}(:)) ));  % ########## need dynamic adaptions in extrem cases
        [glassbr,gbrange]  = cat_plot_glassbrain( res.Vmn ); 
        
        % position of each glassbrain view and its colormap
        gbpos{1} = [ st.vols{1}.ax{3}.ax.Position(3)+0.015, st.vols{1}.ax{1}.ax.Position(2)+0.00 ,0.11, 0.09]; 
        gbpos{2} = [ st.vols{1}.ax{3}.ax.Position(3)+0.015, st.vols{1}.ax{1}.ax.Position(2)+0.09 ,0.11, 0.07];
        gbpos{3} = [ st.vols{1}.ax{3}.ax.Position(3)+0.115, st.vols{1}.ax{1}.ax.Position(2)+0.09 ,0.12, 0.07];
        gbpos{4} = [ st.vols{1}.ax{3}.ax.Position(3)+0.125, st.vols{1}.ax{1}.ax.Position(2)+0.00 ,0.005,0.09]; 

        %% plot glassbrains
        for gbi=1:4
          %%
          if strcmpi(spm_check_version,'octave')
            axes('Position',gbpos{gbi},'Parent',fg);     
            gbcc{gbi} = gca; 
          else
            gbcc{gbi} = axes('Position',gbpos{gbi},'Parent',fg);     
          end
          
          if isfield(res,'Vidiffw')
            gbo = image(gbcc{gbi},max( 60 + 60 + 1 , min( 60+60+surfcolors, (glassbrain{gbi} / glassbrainmax ) * ...
              surfcolors/2 + 	60 + 60 + surfcolors/2))); hold on;
          else
            gbo = image(gbcc{gbi},max( 60 + 60 + 1, min( 60+60+surfcolors/2-1, - (glassbrain{gbi} / glassbrainmax ) * ...
              surfcolors/2 + 	60 + 60 + surfcolors/2))); hold on;
          end
          if gbi<4
            set(gbo,'AlphaDataMapping','scaled','AlphaData',glassbr{gbi}>0.25 & get(gbo,'CData')>(60 + 60) );
            contour(gbcc{gbi},log(max(0,glassbr{gbi})),[0.5 0.5],'color',repmat(0.2,1,3));
            axis equal off;
          else
            set(gbcc{gbi},'XTickLabel','','XTick',[],'TickLength',[0.01 0],'YAxisLocation','right',...
              'YTick',max(1,0:surfcolors/2:surfcolors),'YTickLabel',{num2str([glassbrainmax; 0; -glassbrainmax] ,'%+0.0f')},...
              'FontSize', fontsize*0.8,'FontName',fontname,'xcolor',fontcolor,'ycolor',fontcolor);
          end
         
        end
      end
    else
      if ~isfield(VT0,'dat')
        VT0 = spm_vol(VT0.fname);
      end
      try Yo  = single(VT0.private.dat(:,:,:)); end
      if isfield(res,'spmpp')
        VT0x = res.image0(1); 
      else
        VT0x = VT0;
      end

      if exist('Yo','var')

        if any(size(Yo)~=size(Yp0))
          try Yo = single(VT.private.dat(:,:,:)); end
          if isfield(res,'spmpp')
            VT0x = spm_vol(res.image(1).fname); 
          else
            if exist(VT.fname,'file')
              VT0x = spm_vol(VT.fname);
            else
              VT0x = VT0; 
              VT0x.fname = spm_file(VT0x.fname,'prefix','x'); 
            end
          end
        end

        % remove outlier to make it orthviews easier
        if isfield(res.ppe,'affreg') && isfield(res.ppe.affreg,'highBG') && res.ppe.affreg.highBG 
          Yo = cat_stat_histth(Yo,[0.999999 0.9999],struct('scale',[0 255])); 
        elseif isfield(job.extopts,'histth')
          Yo = cat_stat_histth(Yo,job.extopts.histth,struct('scale',[0 255])); 
        else
          Yo = cat_stat_histth(Yo,[0.999 0.999],struct('scale',[0 255])); 
        end
        Yo = cat_vol_ctype(Yo);
        VT0x.dt(1) = spm_type('uint8');
        VT0x.pinfo = repmat([1;0],1,size(Yo,3));
        VT0x.dat(:,:,:) = Yo; 

        if isfield(job.extopts,'inv_weighting') && job.extopts.inv_weighting
          Tth  = [cat_stat_kmeans(Yo(Yp0(:)>0.5 & Yp0(:)<1.5),2,0),...
                  cat_stat_kmeans(Yo(Yp0(:)>1.5 & Yp0(:)<2.5),5,0),...
                  cat_stat_kmeans(Yo(Yp0(:)>2.5 & Yp0(:)<3.5),2,0)]; 
          WMth = min(max(Tth),median(Tth)*2);
          wstr = 'PD/T2';
        else
          WMth = cat_stat_kmeans(Yo(Yp0(:)>2.8 & Yp0(:)<3.2),2,0); clear Yo; 
          wstr = 'T1';
        end
        T1txt = ['*.nii (Original ' wstr ')']; 
        %if ~debug, clear Yo; end

        VT0x.mat = dispmat * VT0x.mat; 
        try
          hho = spm_orthviews('Image',VT0x,pos{1});
          spm_orthviews('Caption',hho,{T1txt},'FontName',fontname,'FontSize',fontsize-1,'color',fontcolor,'FontWeight','Bold');
          spm_orthviews('window',hho,[0 single(WMth)*cmmax]); 
        end
        %%

        try % sometimes creation of axes fails for unknown reasons
          if strcmpi(spm_check_version,'octave')
            axes('Position',[st.vols{1}.ax{3}.ax.Position(1) st.vols{1}.ax{1}.ax.Position(2) 0.01 0.13],'Parent',fg);     
            cc{1} = gca; 
          else
            cc{1} = axes('Position',[st.vols{1}.ax{3}.ax.Position(1) st.vols{1}.ax{1}.ax.Position(2) 0.01 0.13],'Parent',fg);     
          end
          image((60:-1:1)','Parent',cc{1});

          if isfield(job.extopts,'job.extopts.inv_weighting') && job.extopts.inv_weighting
            set(cc{1},'YTick',ytick,'YTickLabel',fliplr(yticklabeli),'XTickLabel','','XTick',[],'TickLength',[0 0],...
              'FontName',fontname,'FontSize',fontsize-2,'FontWeight','normal','YAxisLocation','right','xcolor',fontcolor,'ycolor',fontcolor);
          else  
            set(cc{1},'YTick',ytick,'YTickLabel',fliplr(yticklabelo),'XTickLabel','','XTick',[],'TickLength',[0 0],...
              'FontName',fontname,'FontSize',fontsize-2,'FontWeight','normal','YAxisLocation','right','xcolor',fontcolor,'ycolor',fontcolor);
          end
        catch
          cc = {}; 
        end
      else
        cat_io_cprintf('warn','WARNING: Can''t display original file "%s"!\n',VT.fname); 
      end
    end
  


  
    %  ----------------------------------------------------------------------
    %  Ym - normalized image in original space
    %  ----------------------------------------------------------------------
    p0id = 3 - ( job.extopts.report.type>1 || isfield(res,'spmpp') );
    if p0id > 2 
      %%
      Vm        = res.image(1); 
      Vm.fname  = ''; 
      Vm.dt     = [spm_type('FLOAT32') spm_platform('bigend')];
      Vm.dat(:,:,:) = single(Ym); % intensity normalized 
      Vm.pinfo  = repmat([1;0],1,size(Ym,3));
      Vm.mat    = dispmat * Vm.mat; 
      try
        hhm = spm_orthviews('Image',Vm,pos{2}); % intensity normalized is to long, in particular the image here is affine normalized
        spm_orthviews('Caption',hhm,{['m*.nii (Normalized ' wstr ')']},'FontName',fontname,'FontSize',fontsize-1,'color',fontcolor,'FontWeight','Bold');
        spm_orthviews('window',hhm,[0 cmmax]);

        % new histogram
        if strcmpi(spm_check_version,'octave')
          axes('Position',[st.vols{2}.ax{3}.ax.Position(1) st.vols{2}.ax{1}.ax.Position(2) 0.01 0.13],'Parent',fg);
          cc{2} = gca; 
        else
          cc{2} = axes('Position',[st.vols{2}.ax{3}.ax.Position(1) st.vols{2}.ax{1}.ax.Position(2) 0.01 0.13],'Parent',fg);
        end
        image((60:-1:1)','Parent',cc{2});
        set(cc{2},'YTick',ytick,'YTickLabel',fliplr(yticklabel),'XTickLabel','','XTick',[],'TickLength',[0 0],...
          'FontName',fontname,'FontSize',fontsize-2,'color',fontcolor,'FontWeight','normal','YAxisLocation','right',...
          'xcolor',fontcolor,'ycolor',fontcolor);
      end
    end



    %  ----------------------------------------------------------------------
    %  Yp0 - segmentation in original space
    %  ----------------------------------------------------------------------
    %  Use different kind of overlays to visualize the segmentation: 
    %   0 - old default 
    %       (only brain tissue with the standard colormap)
    %   1 - default + head 
    %       (bad handling of PVE head values)
    %
    %   2 - color overlay for head and brain (DEFAULT)
    %       subversion with different background color (22-pink,222-green)
    %       (good for skull stripping but worst representation of brain tissues) 
    %   3 - color overlay for head and brain (inverse head) 
    %       (good for skull stripping but worst representation of brain tissues) 
    %
    %   4 - black background + gray head + cat brain colors
    %       (miss some details in CSF tissues)
    %   5 - white background + gray head + cat brain colors (inverse head) 
    %       (more similar to other backgrounds)
    % 
    %  Currently, no overlay and overlay 2 are the best supported options. 
    %  Other options are only for internal test or development and can maybe
    %  removed in future (RD 20190110).
    if isfield(res,'long')
      %%
      try
        hhp0    = spm_orthviews('Image',res.Vmnw,pos{2});
        Vidiff  = res.Vidiffw; Vidiff.dat = Vidiff.dat * 100; 
        BCGWH   = [cat_io_colormaps('hotinv',35);cat_io_colormaps('cold',35)]; BCGWH = BCGWH(6:65,:); 
        BCGWH   = BCGWH.^1.1 * 2; % less transparent for high values
        maxdiff = max(1,round(std(Vidiff.dat(:)))) * 10; 
        spm_orthviews('window',hhp0,[0 single(WMth)*cmmax]);
        spm_orthviews('addtruecolourimage',hhp0,Vidiff, BCGWH,0.4,maxdiff,-maxdiff); 
        spm_orthviews('redraw');
        if ~all(all(dispmat==eye(4)))
          spm_orthviews('Reposition',[-25 0 0]);
        end
        if 1
          spm_orthviews('Caption',hhp0,sprintf('WM tissue changes (FWHM %d mm)',res.long.smoothvol),'FontName',fontname,'FontSize',fontsize-1,'color',fontcolor,'FontWeight','Bold');
        end
      end
      try
        set(st.vols{p0id}.blobs{1}.cbar,'Position', [st.vols{p0id}.ax{3}.ax.Position(1) st.vols{p0id}.ax{1}.ax.Position(2) 0.01 0.13] ); 
        warning('off','MATLAB:warn_r14_stucture_assignment');
        set(st.vols{p0id}.blobs{1}.cbar,'YAxisLocation', 'right','FontSize', fontsize-2,'FontName',fontname,'xcolor',fontcolor,'ycolor',fontcolor); 
        set(st.vols{p0id}.blobs{1}.cbar,'NextPlot','add'); % avoid replacing of labels
        set(st.vols{p0id}.blobs{1}.cbar,'HitTest','off'); % avoid replacing of labels
        % I create a copy of the colorbar that is not changed by SPM and remove
        % the old one that is redrawn by SPM otherwise.
        st.vols{p0id}.blobs1cbar = copyobj(st.vols{p0id}.blobs{1}.cbar,fg);
        st.vols{p0id}.blobs{1}   = rmfield(st.vols{p0id}.blobs{1},'cbar'); 
        spm_orthviews('redraw');
      end
      ov_mesh = 0;
      try, spm_orthviews('AddContext',1); end 
    %%  try
        % create glassbrain images
        if isfield(res,'Vidiffw')
          glassbrain        = cat_plot_glassbrain( res.Vidiffw );  
          glassbrainmax     = max( maxdiff / 5,  ceil(mean(abs(glassbrain{1}(:))) + 4*std(glassbrain{1}(:))) );  % maxdiff / 5;  % ########## need dynamic adaptions in extrem cases
        else
          Vrdiff            = res.Vrdiff;
          Vrdiff.dat(:,:,:) = max(0,abs(Vrdiff2.dat(:,:,:)) - 0.4); 
          glassbrain        = cat_plot_glassbrain( Vrdiff );  
          glassbrainmax     = 1; 
        end
        
        % glassbrain positions
        gbpos{1} = [ pos{2}(1) + st.vols{p0id}.ax{3}.ax.Position(3)+0.015, st.vols{p0id}.ax{1}.ax.Position(2)+0.00 ,0.11, 0.09]; 
        gbpos{2} = [ pos{2}(1) + st.vols{p0id}.ax{3}.ax.Position(3)+0.015, st.vols{p0id}.ax{1}.ax.Position(2)+0.09 ,0.11, 0.07];
        gbpos{3} = [ pos{2}(1) + st.vols{p0id}.ax{3}.ax.Position(3)+0.115, st.vols{p0id}.ax{1}.ax.Position(2)+0.09 ,0.12, 0.07];
        gbpos{4} = [ pos{2}(1) + st.vols{p0id}.ax{3}.ax.Position(3)+0.125, st.vols{p0id}.ax{1}.ax.Position(2)+0.00 ,0.005,0.09]; 

        % plot
        for gbi=1:4
          if strcmpi(spm_check_version,'octave') 
            axes('Position',gbpos{gbi},'Parent',fg);     
            gbcc{4+gbi} = gca; 
          else
            gbcc{4+gbi} = axes('Position',gbpos{gbi},'Parent',fg);     
          end
          gbp0 = image(gbcc{4+gbi},max(1 , min( 60+60+surfcolors, (glassbrain{gbi} / glassbrainmax) * ...
            surfcolors/2 + 	60 + 60 + surfcolors/2))); hold on;
          caxis([-glassbrainmax glassbrainmax]); 
          if gbi<4
            set(gbp0,'AlphaDataMapping','scaled','AlphaData',glassbr{gbi}>0.25 & get(gbp0,'CData')>(60 + 60) );
            contour(gbcc{4+gbi},log(max(0,glassbr{gbi})),[0.5 0.5],'color',repmat(0.2,1,3));
            axis equal off;
          else
            set(gbcc{4+gbi},'XTickLabel','','XTick',[],'TickLength',[0.01 0],'YAxisLocation','right',...
              'YTick',1:surfcolors/2:surfcolors,'YTickLabel',{num2str([glassbrainmax; 0; -glassbrainmax] ,'%+0.0f')},...
              'FontSize', fontsize*0.8,'FontName',fontname,'xcolor',fontcolor,'ycolor',fontcolor);
          end
        end
        spm_orthviews('redraw');
      %end
    else

      VO         = res.image(1); 
      VO.fname   = ''; 
      VO.dt      = [spm_type('FLOAT32') spm_platform('bigend')];

      % create main brackground image
      if isempty(Yl1)
        job.extopts.report.useoverlay = 0; 
      elseif max(Yl1(:)) == 1
        job.extopts.report.useoverlay = 3; 
      end
      switch job.extopts.report.useoverlay
        case 0 % old default that shows only brain tissues
          VO.dat(:,:,:) = single(Yp0/3);
        case 3 % show brain and head tissues ???
          VO.dat(:,:,:) = single(Yp0/3) + ...
            max(0,min(2, 2 - Ym )) .* (Yp0<0.5 & Ym<1/2) + ...
            max(0,min(2, 2 - Ym )) .* (Yp0<0.5 & Ym>1/2);
        otherwise % show brain and head tissues for refined atlas overlay
          VO.dat(:,:,:) = single(Yp0/3) + ...
          min(0.4,     Ym/2 ) .* (Yp0<0.5 & Ym<1/2) + ...
          min(2.0, 2 + Ym/2 ) .* (Yp0<0.5 & Ym>1/2);
      end

      % affine normalization 
      VO.pinfo  = repmat([1;0],1,size(Yp0,3));
      VO.mat    = dispmat * VO.mat; 
      % remove existing subplot in case of debugging
      if exist('hhp0','var')
        try, spm_orthviews('Delete', hhp0); end  %#ok<NODEF>
        clear hhp0;
      end
      % create new figure
      try 
        hhp0 = spm_orthviews('Image',VO,pos{p0id});
        spm_orthviews('window',hhp0,[0 1.3]);
      end

      % CAT atlas labeling
      LAB = job.extopts.LAB;
      NS  = @(Ys,s) Ys==s | Ys==s+1;
      if job.extopts.report.useoverlay>1 && ~strcmpi(spm_check_version,'octave')
        try spm_orthviews('window',hhp0,[0 2]); end
        V2 = VO;
        switch job.extopts.report.useoverlay
          case 1 % classic red mask
            V2.dat(:,:,:) = min(59,min(1,Yp0/3) + 60*(smooth3((abs(Yp0 - Ym*3)>0.6).*cat_vol_morph(abs(Yp0 - Ym*3)>0.8,'d',2).*(Yp0>0.5))>0.5)); 
            try spm_orthviews('addtruecolourimage',hhp0,V2, [0.05 0.4 1; gray(58); 0.8 0.2 0.2],0.5,3,0); end
          case {2,22,222} % red mask high contrast (default)

            % basic head/brain tissue colormapping
            switch job.extopts.report.useoverlay 
              case 22 % pink head  
                BCGWH = pink(15); fx = 4; 
              case 222 % green head 
                BCGWH = [0 0.1 0.05; 0.05 0.2 0.1; 0.1 0.3 0.2; 0.15 0.4 0.3; summer(11)]; fx = 3; 
              otherwise % blue head 
                BCGWH = [0 0 0;  0.03 0.12 0.25; 0.05 0.18 0.40; cat_io_colormaps('blue',12)];fx = 3;
            end
            % background correction
            Yhd  = Yp0==0; 
            BGth = cat_stat_kmeans( Ym(Yhd(:)) , 5); Ym(Yhd) = (Ym(Yhd) - BGth(1)) / ( 1 - BGth(1) ); clear Ybg; 
            % create image
            V2.dat(:,:,:) = min(0.49,Ym/fx).*(Yp0<0.5) + (Yp0/3+0.5).*(Yp0>0.5); 

            % meninges/blood vessels: GM > CSF 
            if ~job.extopts.inv_weighting
              Ychange = 60*(smooth3( ...
                ((Ym*3 - Yp0)>0.4) .* (Yp0<1.25) .* ~NS(Yl1,LAB.VT) .* ...
                cat_vol_morph(abs(Ym*3 - Yp0)>0.5,'d',2) .* ...
                (Yp0>0.5))>0.5);
            else
              Ychange = 60*(smooth3( ...
                ((Yp0 - Ym*3)>0.4) .* (Yp0<1.25) .* ~NS(Yl1,LAB.VT) .* ...
                cat_vol_morph(abs(Yp0 - Ym*3)>0.5,'d',2) .* ...
                (Yp0>0.5))>0.5);
            end
            V2.dat(Ychange & Ym<1.33/3) = 58/30;
            V2.dat(Ychange & Ym>1.33/3) = 59/30;
            V2.dat(Ychange & Ym>1.66/3) = 60/30; 
            clear Ychange; 

            % WMHs
            if job.extopts.WMHC > 1 || ( isfield(qa,'subjectmeasures') && ( ...
              (qa.subjectmeasures.vol_rel_WMH>0.01 || qa.subjectmeasures.vol_rel_WMH/qa.subjectmeasures.vol_rel_WMH>0.02)))
              V2.dat(NS(Yl1,LAB.HI)) = 52/30;
            end

            % ventricles
            if job.extopts.expertgui > 1
              V2.dat(NS(Yl1,LAB.VT) & Yp0<1.5) = 55/30;
              V2.dat(NS(Yl1,LAB.VT) & Yp0>1.5) = 56/30;
              V2.dat(NS(Yl1,LAB.VT) & Yp0>2.5) = 57/30;
              vent3 = repmat([0.3 0.3 0.5],3,1); 
              vent3 = max(0,min(1,vent3 .* repmat([1;2;3],1,3))); 
            else
              vent3 = repmat([0.8 0.0 0.0],3,1); 
            end

            % colormap of WMHs
            g29 = gray(39); g29(1:7,:) = []; g29(end-3:end,:) = [];
            if job.extopts.WMHC > 0 && job.extopts.WMHC < 2
              if qa.subjectmeasures.vol_rel_WMH>0.01 || ...
                qa.subjectmeasures.vol_rel_WMH/qa.subjectmeasures.vol_rel_WMH>0.02
                if job.extopts.WMHC == 2
                  wmhc9 = cat_io_colormaps('magenta',9);
                else
                  wmhc9 = cat_io_colormaps('magentadk',9);
                end
              else
                wmhc9 = gray(20); wmhc9(1:10,:) = []; wmhc9(end,:) = []; 
                wmhc9 = flipud(wmhc9);
              end
            else
              wmhc9 = cat_io_colormaps('orange',9);
            end

            % colormap of blood vessels
            if ~job.extopts.inv_weighting
              bv3 = [0.4 0.2 0.2; 0.6 0.2 0.2; 1 0 0];
            else
              bv3 = [0.4 0.4 0.4; 0.5 0.5 0.5; 0.6 0.6 0.6];
            end

            % display also the detected blood vessels
            V2.dat(NS(Yl1,LAB.BV))      = 60/30; 
            
            % mapping
            try spm_orthviews('addtruecolourimage',hhp0,V2, [BCGWH; g29; wmhc9; vent3; bv3],1,2,0); end 

          case 3 % red mask
            Ychange = 60*(smooth3((abs(Yp0 - Ym*3)>0.6).*cat_vol_morph(abs(Yp0 - Ym*3)>0.8,'d',2) .* (Yp0>0.5))>0.5);
            BCGWH = pink(15); BCGWH = min(1,BCGWH + [zeros(13,3);repmat((1:2)'/2,1,3)]); 
            V2.dat(:,:,:) = min(0.5,Ym/3).*(Yp0<0.5) + (Yp0/4*1.4+0.5).*(Yp0>0.5) + Ychange; 
            try spm_orthviews('addtruecolourimage',hhp0,V2, [flipud(BCGWH);gray(44);1 0 0],1,2,0); end
          case 4 % gray - color (black background)
            BCGWH = cat_io_colormaps('BCGWHwov',60); BCGWH(46:end,:) = []; 
            V2.dat(:,:,:) = min(0.5,Ym/3).*(Yp0<0.5) + (Yp0/4*1.4+0.5).*(Yp0>0.5); 
            try spm_orthviews('addtruecolourimage',hhp0,V2, [gray(16);BCGWH],1,2,0); end
          case 5 % gray - color (white background)
            BCGWH = cat_io_colormaps('BCGWHnov',60); BCGWH(46:end,:) = []; 
            V2.dat(:,:,:) = min(0.5,Ym/3).*(Yp0<0.5) + (Yp0/4*1.4+0.5).*(Yp0>0.5);
            try spm_orthviews('addtruecolourimage',hhp0,V2, [flipud(gray(16));BCGWH],1,2,0); end
        end
        % the colormap deactivation is a bit slow but I know no way to improve that 
        if job.extopts.report.useoverlay > 1, set([st.vols{p0id}.blobs{1}.cbar,get(st.vols{p0id}.blobs{1}.cbar,'children')],'Visible','off'); end
        if isfield(res,'long'), set([st.vols{1}.blobs{1}.cbar,get(st.vols{1}.blobs{1}.cbar,'children')],'Visible','off'); end
        try spm_orthviews('redraw'); end
      else
        try spm_orthviews('window',hhp0,[0 cmmax]); end
      end

      % Yp0 legend 
      try
        spm_orthviews('window',hhp0,[0 cmmax]);
        if all(all(dispmat==eye(4)))
          % set new BB based on the segmentation 
          V2 = VO; 
          V2.dat(:,:,:) = Yp0; 
          bb = spm_get_bbox( V2 , .5);
          spm_orthviews('BB',bb*1.2);
        else
          spm_orthviews('Reposition',[-25 0 0]); 
        end
        if ~isfield(res,'long')
          spm_orthviews('Caption',hhp0,'p0*.nii (Segmentation)','FontName',fontname,'FontSize',fontsize-1,'color',fontcolor,'FontWeight','Bold');
        end
      end
      try
        if job.extopts.report.useoverlay > 1 
        %% make SPM colorbar invisible (cannot delete it because SPM orthviews needs it later)  
          set(st.vols{p0id}.blobs{1}.cbar,'Position', [st.vols{p0id}.ax{3}.ax.Position(1) st.vols{p0id}.ax{1}.ax.Position(2) 0.01 0.13] ); 
          warning('off','MATLAB:warn_r14_stucture_assignment');
          set(st.vols{p0id}.blobs{1}.cbar,'YTick', ytickp0/30,'XTick', [],'YTickLabel', yticklabelp0,'XTickLabel', {},'TickLength',[0 0]);
          set(st.vols{p0id}.blobs{1}.cbar,'YAxisLocation', 'right','FontSize', fontsize-2,'FontName',fontname,'xcolor',fontcolor,'ycolor',fontcolor); 
          set(st.vols{p0id}.blobs{1}.cbar,'NextPlot','add'); % avoid replacing of labels
          set(st.vols{p0id}.blobs{1}.cbar,'HitTest','off'); % avoid replacing of labels
        else
          if strcmpi(spm_check_version,'octave')
            axes('Position',[st.vols{p0id}.ax{3}.ax.Position(1) st.vols{p0id}.ax{1}.ax.Position(2) 0.01 0.13],'Parent',fg);
            cc{p0id} = gca; 
          else
            cc{p0id} = axes('Position',[st.vols{p0id}.ax{3}.ax.Position(1) st.vols{p0id}.ax{1}.ax.Position(2) 0.01 0.13],'Parent',fg);
          end
          image((60:-1:1)','Parent',cc{p0id});
          set(cc{p0id},'YTick',ytick,'YTickLabel',fliplr(yticklabel),'XTickLabel','','XTick',[],'TickLength',[0 0],...
            'FontName',fontname,'FontSize',fontsize-2,'color',fontcolor,'YAxisLocation','right','xcolor',fontcolor,'ycolor',fontcolor);
         end
  %       if isfield(res,'long')
  %         set(st.vols{1}.blobs{1}.cbar,'Position', [st.vols{1}.ax{3}.ax.Position(1) st.vols{1}.ax{1}.ax.Position(2) 0.01 0.13] ); 
  %         set(st.vols{1}.blobs{1}.cbar,'YAxisLocation', 'right','FontSize', fontsize-2,'FontName',fontname,'xcolor',fontcolor,'ycolor',fontcolor); 
  %         set(st.vols{1}.blobs{1}.cbar,'NextPlot','add'); % avoid replacing of labels
  %         set(st.vols{1}.blobs{1}.cbar,'HitTest','off'); % avoid replacing of labels
  %       end
      end
      %if ~debug, clear Yp0; end


      %{
      if job.extopts.expertgui>1
        %%
        ppe_seg{2} = {'CSF', 'GM', 'WM', 'TIV'; 
          sprintf('%0.0f',res.ppe.SPMvols0(1)),  sprintf('%0.0f',res.ppe.SPMvols0(2)),  sprintf('%0.0f',res.ppe.SPMvols0(3)),  sprintf('%0.0f',sum(res.ppe.SPMvols0(1:3)),'%0.0f'); 
          sprintf('%0.0f',res.ppe.SPMvols1(1)),  sprintf('%0.0f',res.ppe.SPMvols1(2)),  sprintf('%0.0f',res.ppe.SPMvols1(3)),  sprintf('%0.0f',sum(res.ppe.SPMvols1(1:3)),'%0.0f'); 
          '','','','';
          'DT','DT''','ll2','ll1';
          res.ppe.reg.dt, res.ppe.reg.rmsgdt, res.ppe.reg.ll(end,2), res.ppe.reg.ll(end,1); 
        };
        for idi = 2 
          ppeax{idi} = axes('Position',[st.vols{p0id}.ax{3}.ax.Position(1)+0.03 st.vols{p0id}.ax{1}.ax.Position(2) 0.2 0.1],'Parent',fg); axis off; 
          for i = 1:size(ppe_seg{idi},1)
            for j = 1:size(ppe_seg{idi}{i},2)
             % lg{idi+1} = text( j*0.25, 1 - i*0.1 , ppe_seg{idi}{i,j}, 'Parent', ppeax{idi}); %, ...
             %   'FontName', fontname, 'Fontsize', fontsize-2, 'Color', fontcolor);
            end
          end
        end
        %,0,stxt,'Parent',ppepos{idi},'FontName',fontname,'Fontsize',fontsize-2,'color',fontcolor,'Interpreter','none','Parent',ax);
      end
      %}


      %  ----------------------------------------------------------------------
      %  TPM overlay with brain/head and head/background surfaces
      %  ----------------------------------------------------------------------
      % RD20200727: res.Affine shows the final affine mapping but more relevant 
      %             for error handling is the intial affine registration before 
      %             the US that is now saved as res.Affine0. 
      %             However mapping both is to much if they are to similar, so 
      %             you have so quantify and evaluate the difference to add the
      %             second map when it is relevant ...
      %             You may also create a warning (in cat_main) and just look
      %             for the warning (or res.FIELD created there). 

      % just remove old things in debugging mode
      if 1 %debug 
        warning('off','MATLAB:subscripting:noSubscriptsSpecified')
        for idi = 1:numel(st.vols)
          if isfield( st.vols{idi}, 'mesh'), st.vols{idi} = rmfield( st.vols{idi} ,'mesh'); end
        end
      end

      % test mesh display
      idi   = 1; 
      try
        Phull = cat_surf_create_TPM_hull_surface(res.tpm, job.extopts.species , ...
          min( job.extopts.gcutstr , ~isfield(res,'spmpp') && ~(isfield(res,'spmpp') && res.spmpp) >0 ) );
      catch
        Phull = ''; 
      end
      try, spm_orthviews('AddContext',idi); end % need the context menu for mesh handling
      try
        warning('off','MATLAB:subscripting:noSubscriptsSpecified');
        if ~isempty(Phull)
          spm_ov_mesh('display',idi,{Phull});
          ov_mesh = 1;
        else
          ov_mesh = 0;
        end
      catch
        fprintf('Please update to a newer version of spm12 for using this contour overlay\n');
        ov_mesh = 0;
      end
    end    

    % test mesh display
    if ~isfield(res,'long')
      idi   = 1; 
      try
        try
          Phull = cat_surf_create_TPM_hull_surface(res.tpm, job.extopts.species , ...
            max(0,min( job.extopts.gcutstr , ~isfield(res,'spmpp') && ~(isfield(res,'spmpp') && res.spmpp) )>0 ));
        catch
          Phull = '';
        end
      end
      try, spm_orthviews('AddContext',idi); end % need the context menu for mesh handling
      try
        warning('off','MATLAB:subscripting:noSubscriptsSpecified');
        if ~isempty(Phull)
          spm_ov_mesh('display',idi,{Phull});
          ov_mesh = 1 & ~isfield(res,'long');
        else
          ov_mesh = 0; 
        end
      catch
        fprintf('Please update to a newer version of spm12 for using this contour overlay\n');
        ov_mesh = 0;
      end
    end
    
    % display mesh
    if ov_mesh

      % load mesh
      warning('off','MATLAB:subscripting:noSubscriptsSpecified');
      try, spm_ov_mesh('display', idi, Phull); end

      % apply registration (AC transformation) for all hull objects
      V = (dispmat * inv(res.Affine) * ([st.vols{idi}.mesh.meshes(1).vertices,...
           ones(size(st.vols{idi}.mesh.meshes(1).vertices,1),1)])' )'; V(:,4) = [];%#ok<MINV>
      V = subsasgn(st.vols{idi}.mesh.meshes(1), struct('subs','vertices','type','.'),single(V));
      st.vols{idi}.mesh.meshes = V; clear V; 

      %% change line style
      hM = findobj(st.vols{idi}.ax{1}.cm,'Label','Mesh');
      UD = get(hM,'UserData'); 
      UD.width = 0.75;
      if strcmp(cm,'gray')
        UD.style = repmat({'r--'},1,numel(Phull)); 
      elseif any( job.extopts.report.color < 0.4 ) 
        UD.style = repmat({'w--'},1,numel(Phull)); 
      else
        UD.style = repmat({'b--'},1,numel(Phull));
      end
      set(hM,'UserData',UD); clear hM
      warning('off','MATLAB:subscripting:noSubscriptsSpecified');
      spm_ov_mesh('redraw',idi); 
      try spm_orthviews('redraw',idi); end

      %% TPM overlay legend
      try
        ccl{1} = axes('Position',[st.vols{1}.ax{3}.ax.Position(1) st.vols{1}.ax{3}.ax.Position(2)-0.04 0.017 0.02],'Parent',fg);
        cclp   = plot(ccl{1},([0 0.4;0.6 1])',[0 0; 0 0],UD.style{1}(1:2)); 
        lg{1}  = text(1.2,0,'Brain/skull TPM overlay','Parent',ccl{1},'FontName',fontname,'Fontsize',fontsize-2,'color',fontcolor);
        set(cclp,'LineWidth',0.75); axis(ccl{1},'off')
      end
    end
  end
  
  
  %% ----------------------------------------------------------------------
  %  central / inner-outer surface overlay
  %  ----------------------------------------------------------------------
  if exist('Psurf','var') && ~isempty(Psurf) && ov_mesh && ~isfield(res,'long') 
    % ... cleanup this part of code when finished ...
    
    Psurf2 = Psurf;

    % create temporary boundary surfaces for the report
    if ~exist(Psurf2(2).Pwhite,'file') && ~exist(Psurf2(2).Ppial,'file')
      tempsurf = 1; 

      surfs = {'Pwhite','Ppial'}; sx = [-0.5 0.5]; 
      for surfi = 1:2  % boundary surfaces
        for si = 1:2   % brain sides
          cmd = sprintf('CAT_Central2Pial "%s" "%s" "%s" %0.1f', ...
            Psurf2(si).Pcentral, Psurf2(si).Pthick,Psurf2(si).(surfs{surfi}),sx(surfi)); 
          cat_system(cmd,0);
        end
      end
    else
      tempsurf = 0; 
    end

    % phite/pial surface in segmentation view number 2 or 3
    if exist(Psurf2(1).Pwhite,'file') && exist(Psurf2(1).Ppial,'file'), ids = 1:p0id; else, ids = []; end % job.extopts.expertgui==2 && 
    for ix=1:numel(Psurf2) 
      Psurf2(end+1).Pcentral = Psurf2(ix).Pwhite; 
      Psurf2(end+1).Pcentral = Psurf2(ix).Ppial; 
    end
    Psurf2(1:numel(Psurf)) = []; 
  
    for idi = 1:p0id % render in each volume
      try spm_orthviews('AddContext',idi); end % need the context menu for mesh handling

      if any(idi==ids), nPsurf = numel(Psurf2); else, nPsurf = numel(Psurf); end
      for ix=1:nPsurf
        % load mesh
        if ov_mesh
          warning('off','MATLAB:subscripting:noSubscriptsSpecified');
          if any(idi==ids)
            spm_ov_mesh('display',idi,Psurf2(ix).Pcentral);
          else
            spm_ov_mesh('display',idi,Psurf(ix).Pcentral);
          end
        else
          continue
        end

        % apply affine scaling for gifti objects
        V = (dispmat * ([st.vols{idi}.mesh.meshes(end).vertices,...
             ones(size(st.vols{idi}.mesh.meshes(end).vertices,1),1)])' )';
        V(:,4) = [];
        M0 = st.vols{idi}.mesh.meshes(1:end-1);
        M1 = st.vols{idi}.mesh.meshes(end);
        M1 = subsasgn(M1,struct('subs','vertices','type','.'),single(V));
        st.vols{idi}.mesh.meshes = [M0,M1];
      end

       % change line style
      hM = findobj(st.vols{idi}.ax{1}.cm,'Label','Mesh');
      UD = get(hM,'UserData');
      UD.width = [repmat(0.5,1,numel(UD.width) - nPsurf)  repmat(0.5,1,nPsurf)]; 
      UD.style = [repmat({'b--'},1,numel(UD.width) - nPsurf) repmat({'k-'},1,nPsurf)];
      set(hM,'UserData',UD); clear UD hM
      warning('off','MATLAB:subscripting:noSubscriptsSpecified');
      if ov_mesh, try, spm_ov_mesh('redraw',idi); end; end

      % layer legend
      try
        if any(idi==ids), stxt = 'white/pial'; else, stxt = 'central surface'; end
        ccl{idi+1} = axes('Position',[st.vols{idi}.ax{3}.ax.Position(1) st.vols{idi}.ax{3}.ax.Position(2)-0.05+0.005*(idi~=1) 0.017 0.02],'Parent',fg);
        plot(ccl{idi+1},[0 1],[0 0],'k-'); axis(ccl{idi+1},'off')
        lg{idi+1} = text(1.2,0,stxt,'Parent',ccl{idi+1},'FontName',fontname,'Fontsize',fontsize-2,'color',fontcolor);
      end

    end
    
    % cleanup
    if tempsurf
      for xi=1:numel(Psurf)
        delete(Psurf(xi).Ppial);
        delete(Psurf(xi).Pwhite);
      end
    end
  
    % remove menu
    %if ~debug, spm_orthviews('RemoveContext',idi); end 
  end



  %%  ----------------------------------------------------------------------
  %  3D surfaces
  %  ----------------------------------------------------------------------
  if job.extopts.print>1 
    if exist('Psurf','var') && ~isempty(Psurf)
      if 1 %~strcmpi(spm_check_version,'octave') && opengl('info')
        boxwidth = 0.1; 
        if job.extopts.report.type <= 1
          %% classic top view
          %  --------------------------------------------------------------
          %  + large clear view of one big brain
          %  - missing information of interesting lower and median regions
          sidehist = 1; %job.extopts.expertgui>1; 
          try
            id1  = find( cat_io_contains({Psurf(:).Pcentral},'lh.') ,1, 'first'); 
            spm_figure('Focus','Graphics'); 
            % this is strange but a 3:4 box property results in a larger brain scaling 
            hCS = subplot('Position',[0.52 0.037*(~sidehist) 0.42 0.31+0.02*sidehist],'visible','off'); 
            if ~strcmpi(spm_check_version,'octave'), renderer = get(fg,'Renderer'); else, renderer = 'volume'; end

            % only add contours if OpenGL is found (to prevent crashing on clusters)
            if strcmpi(renderer,'opengl')
              hSD = cat_surf_display(struct('data',Psurf(id1).Pthick,'readsurf',0,'expert',2,...
                'multisurf',1,'view','s','menu',0,...
                'parent',hCS,'verb',0,'caxis',[0 6],'imgprint',struct('do',0)));


              % rigid reorientation + isotropic scaling
              imat = spm_imatrix(res.Affine); Rigid = spm_matrix([imat(1:6) ones(1,3)*mean(imat(7:9)) 0 0 0]); clear imat;
              for ppi = 1:numel(hSD{1}.patch)
                V = (Rigid * ([hSD{1}.patch(ppi).Vertices, ones(size(hSD{1}.patch(ppi).Vertices,1),1)])' )'; 
                V(:,4) = []; hSD{1}.patch(ppi).Vertices = V;
              end

              % remove old colormap and add own 
              if strcmpi(spm_check_version,'octave'), colormap(cmap);
              else, colormap(fg,cmap); end
              set(hSD{1}.colourbar,'visible','off');
            else
              %%
              for i = 1:numel(Psurf)
                if i == 1 
                  id1 = find( cat_io_contains({Psurf(:).Pcentral},'lh.') ,1, 'first'); 
                  CS = gifti( Psurf(id1).Pcentral ); 
                  T  = cat_io_FreeSurfer('read_surf_data',Psurf(id1).Pthick ); 
                  CS.cdata = T;
                else 
                  id1 = find( cat_io_contains({Psurf(:).Pcentral},'rh.') ,1, 'first'); 
                  S  = gifti( Psurf(id1).Pcentral ); 
                  T  = cat_io_FreeSurfer('read_surf_data',Psurf(id1).Pthick ); 
                  CS.faces    = [ CS.faces; S.faces + size(CS.vertices,1) ]; 
                  CS.vertices = [ CS.vertices; S.vertices ];
                  CS.cdata    = [ CS.cdata; T ];
                  clear S; 
                end
              end
              CS = export(CS,'patch');
              hSD{i} = cat_surf_renderv(CS,[],struct('rot','t','interp',1,'h',hCS));
            end
            
            if ~sidehist
              if strcmpi(spm_check_version,'octave')
                axes('Position',[0.58 0.022 0.3 0.007],'Parent',fg); image((121:1:120+surfcolors),'Parent',cc{4});
                cc{4} = gca; 
              else
                cc{4} = axes('Position',[0.58 0.022 0.3 0.007],'Parent',fg); image((121:1:120+surfcolors),'Parent',cc{4});
              end
              set(cc{4},'XTick',1:(surfcolors-1)/6:surfcolors,'xcolor',fontcolor,'ycolor',fontcolor,'XTickLabel',...
                 {'0','1','2','3','4','5','               6 mm'},...
                'YTickLabel','','YTick',[],'TickLength',[0 0],'FontName',fontname,'FontSize',fontsize-2,'FontWeight','normal');
            else
              %% histogram

              % colormap
              if strcmpi(spm_check_version,'octave')
                axes('Position',[0.965 0.03 0.01 0.28],'Parent',fg); image(flip(121:1:120+surfcolors)','Parent',cc{4});
                cc{4} = gca; 
              else
                cc{4} = axes('Position',[0.965 0.03 0.01 0.28],'Parent',fg); image(flipud(121:1:120+surfcolors)','Parent',cc{4});
              end
              set(cc{4},'YAxisLocation','right','YTick',1:(surfcolors-1)/6:surfcolors,'YTickLabel',{'6','5','4','3','2','1','0'},...
                'XTickLabel','','XTick',[],'FontName',fontname,'FontSize',fontsize-2,'xcolor',fontcolor,'ycolor',fontcolor,'FontWeight','normal');
              
              %% histogram line
              if strcmpi(spm_check_version,'octave')
                axes('Position',[0.936 0.03 0.03 0.28],'Parent',fg,'Visible', 'off','tag', 'cat_surf_results_hist', ...
                'xcolor',fontcolor,'ycolor',fontcolor);
                cc{5} = gca; 
              else
                cc{5} = axes('Position',[0.936 0.03 0.03 0.28],'Parent',fg,'Visible', 'off','tag', 'cat_surf_results_hist', ...
                  'xcolor',fontcolor,'ycolor',fontcolor);
              end
              side  = hSD{1}.cdata;
              [d,h] = hist( side(~isinf(side(:)) & ~isnan(side(:)) &  side(:)<6 & side(:)>0) ,  hrange);
              d = d./numel(side);
              d = d./max(d);
              
              % print histogram
              hold(cc{5},'on');  
              for bi = 1:numel(d)
                b(bi) = barh(cc{5},h(bi),-d(bi),boxwidth); 
                set(b(bi),'Facecolor',cmap3(bi,:),'Edgecolor',fontcolor); 
              end
              ylim([0,6]); xlim([-1 0]);
            end
          catch
            cat_io_cprintf('warn','WARNING: Can''t display surface!\n',VT.fname);   
          end
        elseif job.extopts.report.type >= 2
          spm_figure('Focus','Graphics'); 
          id1    = find( cat_io_contains({Psurf(:).Pcentral},'lh.') ,1, 'first'); 
          id2    = find( cat_io_contains({Psurf(:).Pcentral},'rh.') ,1, 'first'); 
          % this is strange but a 3:4 box property result in a larger brain scaling 
          hCS{1} = subplot('Position',[0.34 0.07 0.32 0.27],'Parent',fg,'visible','off'); PCS{1} = Psurf(id1).Pthick; sview{1} = 't';
          hCS{2} = subplot('Position',[0.02 0.18 0.30 0.17],'Parent',fg,'visible','off'); PCS{2} = Psurf(id1).Pthick; sview{2} = 'l';
          hCS{3} = subplot('Position',[0.68 0.18 0.30 0.17],'Parent',fg,'visible','off'); PCS{3} = Psurf(id2).Pthick; sview{3} = 'r';
          hCS{4} = subplot('Position',[0.02 0.01 0.30 0.17],'Parent',fg,'visible','off'); PCS{4} = Psurf(id1).Pthick; sview{4} = 'r';
          hCS{5} = subplot('Position',[0.68 0.01 0.30 0.17],'Parent',fg,'visible','off'); PCS{5} = Psurf(id2).Pthick; sview{5} = 'l';
          if ~strcmpi(spm_check_version,'octave'), renderer = get(fg,'Renderer'); else, renderer = 'volume'; end
 
          % only add contours if OpenGL is found (to prevent crashing on clusters)
          if isfield(res,'long')
            [~,~,ee] = spm_fileparts(Psurf(id1).Pthick); 
            if strcmp(ee,'.gii')
              S         = gifti(Psurf(id1).Pthick); 
              cdata     = S.cdata; 
            else
              cdata     = cat_io_FreeSurfer('read_surf_data',Psurf(id1).Pthick); 
            end
            maxdiff     = max(.02, 4 * ceil(std(cdata(:))*8)/8); 
            srange      = [-maxdiff maxdiff]; 
            boxwidth    = diff(srange)/40 / 2; % 0.05; 
          else
            srange      = [0 6]; 
            boxwidth    = diff(srange)/30 / 2; % 0.1; 
          end
          %% hrange      = srange(1) + boxwidth/2:boxwidth:srange(2);
          if job.output.surface > 10, addcb = 1; else, addcb = 0; end
          if strcmpi(renderer,'opengl')
            try
              i=1; hSD{i} = cat_surf_display(struct('data',PCS{i},'readsurf',0,'expert',2,...
                'multisurf',1 + 2*addcb,'view',sview{i},'menu',0,'parent',hCS{i},'verb',0,'caxis',srange,'imgprint',struct('do',0))); 
            end

            for i = 2:numel(hCS)
              try
                hSD{i} = cat_surf_display(struct('data',PCS{i},'readsurf',0,'expert',2,...
                  'multisurf',0 + 3*addcb,'view',sview{i},'menu',0,'parent',hCS{i},'verb',0,'caxis',srange,'imgprint',struct('do',0))); 
              end
            end
            
            % rigid reorientation + isotropic scaling
            if isfield(res,'Affine')
              imat = spm_imatrix(res.Affine); Rigid = spm_matrix([imat(1:6) ones(1,3)*mean(imat(7:9)) 0 0 0]); clear imat;
            else
              Rigid = eye(4);
            end
            if exist('hSD','var')
              for i = 1:numel(hSD)
                for ppi = 1:numel(hSD{i}{1}.patch)
                  try
                    V = (Rigid * ([hSD{i}{1}.patch(ppi).Vertices, ones(size(hSD{i}{1}.patch(ppi).Vertices,1),1)])' )'; 
                    V(:,4) = []; hSD{i}{1}.patch(ppi).Vertices = V;
                  end
                end
              end
              for i = 1:numel(hSD), colormap(fg,cmap);  set(hSD{i}{1}.colourbar,'visible','off'); end
            end
          else
            try
              if 1
                % just the first draft
                for i = 1:numel(Psurf)
                  if i == 1 
                    id1 = find( cat_io_contains({Psurf(:).Pcentral},'lh.') ,1, 'first'); 
                    CS = gifti( Psurf(id1).Pcentral ); 
                    T  = cat_io_FreeSurfer('read_surf_data',Psurf(id1).Pthick ); 
                    CS.cdata = T;
                    CSl = CS; 
                  else 
                    id1 = find( cat_io_contains({Psurf(:).Pcentral},'rh.') ,1, 'first'); 
                    S  = gifti( Psurf(id1).Pcentral ); 
                    T  = cat_io_FreeSurfer('read_surf_data',Psurf(id1).Pthick ); 
                    CS.faces    = [ CS.faces; S.faces + size(CS.vertices,1) ]; 
                    CS.vertices = [ CS.vertices; S.vertices ];
                    CS.cdata    = [ CS.cdata; T ];
                    CSr = S; CSr.cdata = T; 
                    clear S; 
                  end
                end
                CS  = export(CS,'patch');
                CSl = export(CSl,'patch');
                CSr = export(CSr,'patch');
              else
                % ###### this is not working yet #######
                % the idea is to refine the surface to quaranty a minimum 
                % resolution but the thickness data mapping is not working
                % yet ...
                side = {'lh.','rh.'}; 
                for si = 1:numel(side)
                  id1 = find( cat_io_contains({Psurf(:).Pcentral},side{si}) ,1, 'first'); 
                  % quaranty 1 mm mesh resolution
                  Pcentral = sprintf('%s.gii',tempname);    
                  CSo = gifti(Psurf(id1).Pcentral);
                  cmd = sprintf('CAT_RefineMesh "%s" "%s" %0.2f 0',Psurf(id1).Pcentral,Pcentral,1);
                  cat_system(cmd,0);
                  CSx = gifti(Pcentral);
                  CSx = export(CSx,'patch');
                  delete(Pcentral); 
                  T   = cat_io_FreeSurfer('read_surf_data',Psurf(id1).Pthick ); 
                  CSx.cdata = cat_surf_fun('cdatamapping',CSx,CSo,T,struct('scale',1));
                  if si==1, CSl = CSx; else, CSr = CSx; end 
                end
                CS.faces    = [ CSl.faces;    CSr.faces + size(CSl.vertices,1) ]; 
                CS.vertices = [ CSl.vertices; CSr.vertices ];
                CS.cdata    = [ CSl.cdata;	  CSr.cdata ];
              end
              
              %%
              imat = spm_imatrix(res.Affine); Rigid = spm_matrix([imat(1:6) ones(1,3)*mean(imat(7:9)) 0 0 0]); clear imat;
              V = (Rigid * ([CS.vertices,  ones(size(CS.vertices ,1),1)])' )'; V(:,4) = []; CS.vertices  = V;
              V = (Rigid * ([CSl.vertices, ones(size(CSl.vertices,1),1)])' )'; V(:,4) = []; CSl.vertices = V;
              V = (Rigid * ([CSr.vertices, ones(size(CSr.vertices,1),1)])' )'; V(:,4) = []; CSr.vertices = V;

              if strcmpi(spm_check_version,'octave'), colormap(cmap); 
              else, colormap(fg,cmap); end
              
              % The interpolation value controls quality and speed, the normal report + 
              % surface-rendering takes about 70s, whereas this renderer takes 60 to 160s.  
              % round(interp) controls the main mesh interpolation level with equal
              % subdivision of one face by 4 faces, but the value also sets the sampling
              % size of the rendering images and a value of 1.4 means 1.4 more pixel in 
              % each dimension. Values of 1.0 - 1.4 are quite fast (but not fine enough 
              % for standard zoom-in) and 2.4 (120s) suits better.   
              interp = 2.45; 
              
              hSD{1}{1} = cat_surf_renderv(CS ,[],struct('view',sview{1},'mat',spm_imatrix(res.Affine),'h',hCS{1},'interp',interp)); 
              cat_surf_renderv(CSl,[],struct('view',sview{2},'mat',spm_imatrix(res.Affine),'h',hCS{2},'interp',interp*0.9));
              cat_surf_renderv(CSr,[],struct('view',sview{3},'mat',spm_imatrix(res.Affine),'h',hCS{3},'interp',interp*0.9));
              cat_surf_renderv(CSl,[],struct('view',sview{4},'mat',spm_imatrix(res.Affine),'h',hCS{4},'interp',interp*0.9));
              cat_surf_renderv(CSr,[],struct('view',sview{5},'mat',spm_imatrix(res.Affine),'h',hCS{5},'interp',interp*0.9));

            catch
              cat_io_cprintf('err','Error in non OpenGL surface rendering.\n');
            end
          end
          
          
          %% To do: filter thickness values on the surface ...
          
          % sometimes hSD is not defined here because of mysterious errors on windows systems
          if ~exist('hSD','var'), return; end

          if ~isfield(hSD{1}{1},'cdata'), return; end

          % colormap
          side  = hSD{1}{1}.cdata; 
          
          % histogram 
          if strcmpi(spm_check_version,'octave')
            axes('Position',[0.36 0.0245 0.28 0.030],'Parent',fg,...
              'visible','off', 'tag','cat_surf_results_hist', ...
              'xcolor',fontcolor,'ycolor',fontcolor); 
            cc{5} = gca; 
          else
            cc{5} = axes('Position',[0.36 0.0245 0.28 0.030],'Parent',fg,...
              'visible','off', 'tag','cat_surf_results_hist', ...
              'xcolor',fontcolor,'ycolor',fontcolor); 
          end
          % boxes
          if isfield(res,'long')
            [d,h] = hist( side(~isinf(side(:)) & ~isnan(side(:)) ), ...&  side(:)<srange(2) & side(:)>srange(1)) , ...
                      srange(1)+boxwidth/2:boxwidth:srange(2)-boxwidth/2); 
          else
            [d,h] = hist( side(~isinf(side(:)) & ~isnan(side(:)) &  side(:)<srange(2) & side(:)>srange(1)) , ...
                      srange(1)+boxwidth/2:boxwidth:srange(2)-boxwidth/2);    
          end
          dmax  = max(d) * 1.2; % 15% extra for the line plot (use thickness phantom to set this value)
          % histogram line
          [dl,hl] = hist( side(~isinf(side(:)) & ~isnan(side(:)) &  side(:)<srange(2) & side(:)>srange(1)) , ...
            srange(1)+boxwidth/2:boxwidth/10:srange(2)-boxwidth/2); %hl = hl + 0.02/2; 
          try dl = smooth(dl,2); catch, dl = (dl + [0 dl(1:end-1)] + [dl(2:end) 0])/3; end % smooth requires Curve Fitting Toolbox
          dl = dl / (dmax/10); % 10 times smaller boxes
          % boxplot values
          q0 = median(side); q1 = median(side(side<q0)); q2 = median(side(side>q0)); 
          d = d / dmax;
          if 0%isfield(res,'long') % make outlier vissible in the histogram
            hx  = srange(1)+boxwidth/2:boxwidth:srange(2)-boxwidth/2; 
            hlx = srange(1)+boxwidth/10:boxwidth/10:srange(2)-boxwidth/2; 
            d   = min(1, d  .* max(0,2.^((abs(hx  * 20).^1)))); 
            dl  = min(1, dl .* max(0,2.^((abs(hlx * 20).^1)))); 
          end
          
          
          %% print histogram
          hold(cc{5},'on');  
          for bi = 1:numel(d)
            outlier0 = h(bi) < q0 - 3*(q0-q1)  &  d(bi)>0.01  &  d(bi)>0.9*d(min(numel(d),bi+1)); 
            outlier1 = h(bi) > q0 + 3*(q2-q0)  &  d(bi)>0.01  &  d(bi)>0.9*d(max(1,bi-1));
            b(bi) = bar(cc{5},h(bi),d(bi),boxwidth); 
            if outlier0 || outlier1, ecol = [1 0 0]; else, ecol = fontcolor; end % mark outlier
            set(b(bi),'Facecolor',cmap3(min(surfcolors,round(bi * surfcolors/numel(d) )),:),'Edgecolor',ecol)
          end
          try
            line(cc{5},hl,dl,'color',mean([fontcolor;[0.9 0.3 0.3]]));
            outlier0 = hl < q0 - 3*(q0-q1) &  d(bi)/max(d)>0.01; 
            outlier1 = hl > q0 + 3*(q2-q0) &  d(bi)/max(d)>0.01;
            if ~isempty(outlier0), line(cc{5},hl( outlier0 ),dl( outlier0 ),'color',[1 0 0 ]); end
            if isfield(res,'long')
              if ~isempty(outlier1), line(cc{5},hl( outlier1 ),dl( outlier1 ),'color',[0 0 1 ]); end
            else
              if ~isempty(outlier1), line(cc{5},hl( outlier1 ),dl( outlier1 ),'color',[1 0 0 ]); end
            end
            xlim(srange); ylim([0 1]);
          end
          
          
          %% print colormap and boxplot on top of the bar/line histogramm to avoid that the line run into it 
          cc{4} = axes('Position',[0.36 0.018 0.28 0.007],'Parent',fg); xlim([1 surfcolors]); 
          image((121:1:120+surfcolors),'Parent',cc{4}); hold on; 
         
          try
            if isfield(res,'long')
              if     srange(2)>2.00, cfontcolor = [0.8 0 0]; 
              elseif srange(2)>1.00, cfontcolor = [0.4 0 0];
              else                 , cfontcolor = fontcolor; 
              end 
              set(cc{4},'XTick',1:(surfcolors-1)/4:surfcolors,'xcolor',cfontcolor,'ycolor',fontcolor,'XTickLabel',...
                   {sprintf('%.2f',srange(1)),sprintf('%.2f',srange(1)/2),'0',...
                    sprintf('%+.2f',srange(2)/2),...
                    sprintf('                                                  %+.2f %s changes (smoothed %d times)',...
                    srange(2),res.long.measure,round(res.long.smoothsurf))},...
                  'YTickLabel','','YTick',[],'TickLength',[0.01 0],'FontName',fontname,'FontSize',fontsize-2,'FontWeight','normal'); 
            else
              set(cc{4},'XTick',1:(surfcolors-1)/6:surfcolors,'xcolor',fontcolor,'ycolor',fontcolor,'XTickLabel',...
                  {'0','1','2','3','4','5',[repmat(' ',1,10) '6 mm']},...
                  'YTickLabel','','YTick',[],'TickLength',[0.01 0],'FontName',fontname,'FontSize',fontsize-2,'FontWeight','normal'); 
            end
          
            % boxplot
            % sometimes it's crashing on windows systems for no reason...
            try
              if isfield(res,'long')
                %%
                line(cc{4},surfcolors/2 + surfcolors/2 * [(q0 - 1.5*(q0-q1)) q1 ], [ 1 1] , 'Color',[0 0 0],'LineWidth',0.75); 
                line(cc{4},surfcolors/2 + surfcolors/2 * [q2 (q0 + 1.5*(q2-q0)) ], [ 1 1] , 'Color',[0 0 0],'LineWidth',0.75); 
                fill(cc{4},surfcolors/2 + surfcolors/2 * [q1 q2 q2 q1], [ 0.8 0.8 1.2 1.2],[1 1 1],'LineWidth',0.5,'FaceAlpha',0.7); 
                line(cc{4},surfcolors/2 + surfcolors/2 * repmat(mean(side),1,2), [ 0.6 1.4 ] , 'Color',[0 0 0],'LineWidth',0.75); 
                line(cc{4},surfcolors/2 + surfcolors/2 * repmat(q0,1,2), [ 0.6 1.4 ] , 'Color',[1 0 0],'LineWidth',1.5); 
              else
                line(cc{4},(surfcolors-1)/6 * [(q0 - 1.5*(q0-q1)) q1 ], [ 1 1] , 'Color',[0 0 0],'LineWidth',0.75); 
                line(cc{4},(surfcolors-1)/6 * [q2 (q0 + 1.5*(q2-q0)) ], [ 1 1] , 'Color',[0 0 0],'LineWidth',0.75); 
                fill(cc{4},(surfcolors-1)/6 * [q1 q2 q2 q1], [ 0.8 0.8 1.2 1.2],[1 1 1],'LineWidth',0.5,'FaceAlpha',0.7); 
                line(cc{4},(surfcolors-1)/6 * repmat(mean(side),1,2), [ 0.6 1.4 ] , 'Color',[0 0 0],'LineWidth',0.75); 
                line(cc{4},(surfcolors-1)/6 * repmat(q0,1,2), [ 0.6 1.4 ] , 'Color',[1 0 0],'LineWidth',1.5); 
              end
            end
            hold off; 
          end        
      else
        cat_io_cprintf('warn','WARNING: Surface rending without openGL is deactivated to prevent zoombie processes on servers!\n',VT.fname);   
% render warning on figure        
      end
    end
  end


if 1
  %%  ----------------------------------------------------------------------
  %  print subject report file as standard PDF/PNG/... file
  %  ----------------------------------------------------------------------
  %  vars in:  fg, htext, cc, st
  %  vars out: -
  
  job.imgprint.type   = 'pdf';
  job.imgprint.dpi    = 300;
  job.imgprint.fdpi   = @(x) ['-r' num2str(x)];
  job.imgprint.ftype  = @(x) ['-d' num2str(x)];
  
  [pth1,pth2] = spm_fileparts(pth); 
  if strcmp(pth2,mrifolder), pth = pth1; end % remove mri nameing
    
  pth_reportfolder = fullfile(pth,reportfolder);
  [stat, val] = fileattrib(pth_reportfolder);
  if stat, pth_reportfolder = val.Name; end
  if ~exist(pth_reportfolder,'dir'), mkdir(pth_reportfolder); end 
  if isfield(res,'long')
    longstr = 'long';                 % catLONGreport
    nam     = strrep(nam,'mean_',''); % remove the mean 
  else
    longstr = ''; 
  end
  if ~isfield(job,'imgprint') || ~isfield(job.imgprint,'fname')
    job.imgprint.fname  = fullfile(pth_reportfolder,['cat' longstr 'report_'  nam '.' job.imgprint.type]); 
  end
  if ~isfield(job,'imgprint') || ~isfield(job.imgprint,'fnamej')
    job.imgprint.fnamej = fullfile(pth_reportfolder,['cat' longstr 'reportj_' nam '.jpg']);
  end

  % save old settings of the SPM figure
  fgold.PaperPositionMode = get(fg,'PaperPositionMode');
  fgold.PaperPosition     = get(fg,'PaperPosition');
  fgold.resize            = get(fg,'resize');

  % it is necessary to change some figure properties especially the fontsizes 
  set(fg,'PaperPositionMode','auto','resize','on','PaperPosition',[0 0 1 1]);
  try, set(hd,'FontName',fontname,'Fontsize',get(hd,'Fontsize')/spm_figure_scale*0.8); end
  try, spm_orthviews('Caption',hho,{T1txt},'FontName',fontname,'FontSize',(fontsize-1)/spm_figure_scale*0.8,'FontWeight','Bold'); end
  try, spm_orthviews('Caption',hhm,{['m*.nii (Normalized ' wstr ')']},...
      'FontName',fontname,'FontSize',(fontsize-1)/spm_figure_scale*0.8,'FontWeight','Bold'); end
  if ~isfield(res,'long')
    try, spm_orthviews('Caption',hhp0,'p0*.nii (Segmentation)','FontName',fontname,'FontSize',(fontsize-1)/spm_figure_scale*0.8,'FontWeight','Bold'); end
  else
    try, spm_orthviews('Caption',hhp0,sprintf('WM tissue changes (FWHM %d mm)',res.long.smoothvol),'FontName',fontname,'FontSize',(fontsize-1)/spm_figure_scale*0.8,'FontWeight','Bold'); end
  end
  if exist('axi','var')
    for hti = 1:numel(axi), try, set(axi(hti),'FontName',fontname,'Fontsize',get(axi(hti),'Fontsize')/spm_figure_scale*0.8); end; end
  end
  if exist('cp','var')
    for hti = 1:numel(cp), try, set(cp(hti),'FontName',fontname,'Fontsize',get(cp(hti),'Fontsize')/spm_figure_scale*0.8); end; end
  end
  if exist('lh','var')
    for hti = 1:numel(lh), try, set(lh(hti),'FontName',fontname,'Fontsize',get(lh(hti),'Fontsize')/spm_figure_scale*0.8); end; end
  end
  if exist('gbcc','var')
    for hti = [4,8], try, set(gbcc{hti},'FontName',fontname,'Fontsize',get(gbcc{hti},'Fontsize')/spm_figure_scale*0.8); end; end
  end  
  for hti = 1:numel(htext), try, set(htext(hti),'FontName',fontname,'Fontsize',get(htext(hti),'Fontsize')/spm_figure_scale*0.8); end; end
  if exist('cc','var') % sometimes cc does not exist of anything fails before
    for hti = 1:numel(cc),   try, set(cc{hti}  , 'FontName', fontname, 'Fontsize', get(cc{hti}  , 'Fontsize')/spm_figure_scale*0.8); end; end
  end
  if exist('ccl','var') % sometimes lg does not exist of anything fails before
    for hti = 1:numel(ccl), try, set(ccl{hti}  ,'FontName',fontname,'Fontsize',get(ccl{hti}  ,'Fontsize')/spm_figure_scale*0.8); end; end
  end
  if exist('lg','var') % sometimes lg does not exist of anything fails before
    for hti = 1:numel(lg), try, set(lg{hti}   ,'FontName',fontname,'Fontsize',get(lg{hti}   ,'Fontsize')/spm_figure_scale*0.8); end; end
  end
  if job.extopts.report.useoverlay > 1
    try
      set(st.vols{p0id}.blobs{1}.cbar,'FontName',fontname,'Fontsize',get(st.vols{p0id}.blobs{1}.cbar,'Fontsize')/spm_figure_scale*0.8); 
    end
  end
  warning('off','MATLAB:hg:patch:RGBColorDataNotSupported');
  
  % the PDF is is an image because openGL is used but -painters would not look good for surfaces ... 
  try % does not work in headless mode without java
    if ~isempty(job.imgprint.fname)
      print(fg, job.imgprint.ftype(job.imgprint.type), job.imgprint.fdpi(job.imgprint.dpi), job.imgprint.fname); 
    end
    if ~isempty(job.imgprint.fnamej)
      print(fg, job.imgprint.ftype('jpeg'), job.imgprint.fdpi(job.imgprint.dpi), job.imgprint.fnamej);
    end
  end

  %% reset font settings
  try, set(hd,'FontName',fontname,'Fontsize',get(hd,'Fontsize')*spm_figure_scale/0.8); end
  try, spm_orthviews('Caption',hho,{T1txt},'FontName',fontname,'FontSize',fontsize-1,'FontWeight','Bold'); end
  if ~isfield(res,'long')
    try, spm_orthviews('Caption',hhm,{['m*.nii (Normalized ' wstr ')']},'FontName',fontname,'FontSize',fontsize-1,'FontWeight','Bold'); end
    try, spm_orthviews('Caption',hhp0,'p0*.nii (Segmentation)','FontName',fontname,'FontSize',fontsize-1,'FontWeight','Bold'); end
  else
    try, spm_orthviews('Caption',hhp0,sprintf('WM tissue changes (FWHM %d mm)',res.long.smoothvol),'FontName',fontname,'FontSize',fontsize-1,'FontWeight','Bold'); end
  end
  for hti = 1:numel(htext), try, set(htext(hti),'FontName',fontname,'Fontsize',get(htext(hti),'Fontsize')*spm_figure_scale/0.8); end; end
  if exist('axi','var')
    for hti = 1:numel(axi  ), try, set(axi(hti),'FontName',fontname,'Fontsize',get(axi(hti),'Fontsize')*spm_figure_scale/0.8); end; end
  end
  if exist('cp','var')
    for hti = 1:numel(cp   ), try, set(cp(hti),'FontName',fontname,'Fontsize',get(cp(hti),'Fontsize')*spm_figure_scale/0.8); end; end
  end
  if exist('lh','var')
    for hti = 1:numel(lh), try, set(lh(hti),'FontName',fontname,'Fontsize',get(lh(hti),'Fontsize')*spm_figure_scale/0.8); end; end
  end
  if exist('gbcc','var') 
    for hti = [4,8], try, set(gbcc{hti},'FontName',fontname,'Fontsize',get(gbcc{hti},'Fontsize')*spm_figure_scale/0.8); end; end
  end
  try, for hti = 1:numel(cc),    try, set(cc{hti}   ,'FontName',fontname,'Fontsize',get(cc{hti}   ,'Fontsize')*spm_figure_scale/0.8); end; end; end
  try, for hti = 1:numel(ccl),   set(ccl{hti}  ,'FontName',fontname,'Fontsize',get(ccl{hti}  ,'Fontsize')*spm_figure_scale/0.8); end; end
  if exist('lg','var') % sometimes lg does not exist of anything fails before
    for hti = 1:numel(lg),    try, set(lg{hti}   ,'FontName',fontname,'Fontsize',get(lg{hti}   ,'Fontsize')*spm_figure_scale/0.8); end; end
  end
  if job.extopts.report.useoverlay > 1 && ~isfield(res,'long')
    try
      set(st.vols{p0id}.blobs{1}.cbar,'FontName',fontname,'Fontsize',get(st.vols{p0id}.blobs{1}.cbar,'Fontsize')*spm_figure_scale/0.8);
      % I create a copy of the colorbar that is not changed by SPM and remove
      % the old one that is redrawn by SPM otherwise.
      st.vols{p0id}.blobs1cbar = copyobj(st.vols{p0id}.blobs{1}.cbar,fg);
      st.vols{p0id}.blobs{1}   = rmfield(st.vols{p0id}.blobs{1},'cbar'); 
    end
  end
  
  % restore old SPM figure settings
  set(fg,'PaperPositionMode',fgold.PaperPositionMode,'resize',fgold.resize,'PaperPosition',fgold.PaperPosition);
  clear fgold
  
  % be verbose ... but just one row to work in the retrospective batch mode
  try
    if ~isempty(job.imgprint.fname)
      fprintf('  %s\n',job.imgprint.fname); %Print ''Graphics'' figure to: \n  
    end
    if isempty(job.imgprint.fname) && ~isempty(job.imgprint.fnamej)
      fprintf('  %s\n',job.imgprint.fname); % Print ''Graphics'' figure to: \n
    end
  end
end



  %  ----------------------------------------------------------------------
  %  reset colormap to the simple SPM like gray60 colormap
  %  ----------------------------------------------------------------------
  %  vars in:  WMth, hho, hhm, hhp0, job, showTPMsurf, Psurf, st
  %  vars out: -
  
  %  gray colormap 
  cmap(1:60,:) = gray(60); cmap(61:120,:) = flipud(pink(60)); 
  cmap(121:120+surfcolors,:) = cmap3; 
  if strcmpi(spm_check_version,'octave')
    colormap(cmap); clear cmap;
  else
    colormap(fg,cmap); clear cmap;
  end
    
  % update intensity scaling for gray colormap 
  if ~isfield(res,'long')
    WMfactor0 = single(WMth) * 8/6; 
    WMfactor1 = 8/6; 

    % update the colormap in the SPM orthview windows
    warning('off','MATLAB:subscripting:noSubscriptsSpecified');
    if exist('hho' ,'var'), try, spm_orthviews('window',hho ,[0 WMfactor0]); set(cc{1},'YTick',ytick * 4/3 - 20); end; end
    if exist('hhm' ,'var'), try, spm_orthviews('window',hhm ,[0 WMfactor1]); set(cc{2},'YTick',ytick * 4/3 - 20); end; end
    if exist('hhp0','var'), try, spm_orthviews('window',hhp0,[0 WMfactor1]); end; end
    clear WMfactor0 WMfactor1; 
  end
  
  %% change line style of TPM surf (from b-- to r--)
  if ov_mesh && exist('Psurf','var') && ~isempty(Psurf) && exist('st','var') && ...
      isfield(st,'vols') && iscell(st.vols) && isfield(st.vols{1},'ax') && ... 
      iscell(st.vols{1}.ax) && isfield(st.vols{1}.ax{1} ,'cm') 
    hM = findobj(st.vols{1}.ax{1}.cm,'Label','Mesh');
    UD = get(hM,'UserData');
    UD.style{1} = 'r--'; 
    set(hM,'UserData',UD);
    set(cclp,'Color', [1 0 0]); % overlay legend
    try,spm_ov_mesh('redraw',1);end
  end  
end