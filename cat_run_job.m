function cat_run_job(job,tpm,subj)
% run CAT 
% ______________________________________________________________________
%
% Initialization functions for the CAT preprocessing
%  * creation of the subfolder structure (if active)
%  * check of image resolution (avoid scans with very low resolution)
%  * interpolation 
%  * affine preprocessing (APP)
%    >> cat_run_job_APP_init
%    >> cat_run_job_APP_final
%  * affine registration
%  * initial SPM preprocessing
%
%   cat_run_job(job,tpm,subj)
% 
%   job  .. SPM job structure with main parameter
%   tpm  .. tissue probability map (hdr structure)
%   subj .. file name
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
% $Id$

%#ok<*WNOFF,*WNON>

  job.test_warnings  = 0; % just for tests
  job.extopts.histth = [0.96 0.9999]; % histogram thresholds
  % use "lower" first histth to deal with diffent low intensity BGs that 
  % is corrected in case of highBG data
  job.extopts.input  = 0; % 0 - auto (default), 1-with skull (normal), 2-skull-stripped, 3-high BG

  if exist('rng','file') == 2, rng('default'); rng(0); else, rand('state',0); randn('state',0); end
  
  % if there is a breakpoint in this file set debug=1 and do not clear temporary variables 
  dbs   = dbstatus; debug = 0; for dbsi=1:numel(dbs), if strcmp(dbs(dbsi).name,mfilename); debug = 1; break; end; end
  
  clearvars -global cat_err_res;
  global cat_err_res; % for CAT error report
  cat_err_res.stime        = clock; 
  cat_err_res.cat_warnings = cat_io_addwarning('reset'); % reset warnings 
  stime  = clock; 
  stime0 = stime; % overall processing time

  % create subfolders if not exist
  pth = spm_fileparts(job.channel(1).vols{subj}); 
  [mrifolder, reportfolder, surffolder, labelfolder] = cat_io_subfolders(job.channel(1).vols{subj},job);

  if job.extopts.subfolders
  
    folders = {mrifolder,reportfolder};
    warning('off', 'MATLAB:MKDIR:DirectoryExists');
    for i=1:numel(folders)
      [stat, msg] = mkdir(fullfile(pth,folders{i}));
      if ~stat
        fprintf('%s: Error while creating directory %s\n\n\n',msg,fullfile(pth,folders{i}));
        return
      end
    end
  
    if ~exist(fullfile(pth,surffolder),'dir') && job.output.surface
      [stat, msg] = mkdir(fullfile(pth,surffolder));
      if ~stat
        fprintf('%s: Error while creating directory %s\n\n\n',msg,fullfile(pth,surffolder));
        return
      end
    end
  
    if ~exist(fullfile(pth,labelfolder),'dir') && job.output.ROI
      [stat, msg] = mkdir(fullfile(pth,labelfolder));
      if ~stat
        fprintf('%s: Error while creating directory %s\n\n\n',msg,fullfile(pth,labelfolder));
        return
      end
    end
    
  end
  
  % create subject-wise diary file with the command-line output
  [pp,ff,ee,ex] = spm_fileparts(job.data{subj});  %#ok<ASGLU>
  % sometimes we have to remove .nii from filename if files were zipped
  catlog = fullfile(pth,reportfolder,['catlog_' strrep(ff,'.nii','') '.txt']);
  if exist(catlog,'file'), delete(catlog); end % write every time a new file, turn this off to have an additional log file
  
  % check if not another diary is already written that is not the default- or catlog-file. 
  if ~strcmpi(spm_check_version,'octave')
    olddiary = spm_str_manip( get(0,'DiaryFile') , 't');
    usediary = ~isempty(strfind( olddiary , 'diary' )) || ~isempty(strfind( olddiary , 'catlog_' )); 
    if usediary
      diary(catlog); 
      diary on; 
    else  
      cat_io_cprintf('warn',sprintf('External diary log is written to "%s".\n',get(0,'DiaryFile'))); 
    end
  else
    % always use diary and don't check for old one for Octave
    usediary = 1;
    diary(catlog); 
    diary on; 
  end
  
  % print current CAT release number and subject file
  [n,r] = cat_version;
  str  = sprintf('%s r%s: %d/%d',n,r,subj,numel(job.channel(1).vols));
  str2 = spm_str_manip(job.channel(1).vols{subj}(1:end-2),['a' num2str(70 - length(str))]);
  cat_io_cprintf([0.2 0.2 0.8],'\n%s\n%s: %s%s\n%s\n',...
        repmat('-',1,72),str,...
        repmat(' ',1,70 - length(str) - length(str2)),str2,...
        repmat('-',1,72));
  clear r str str2
  
  if job.extopts.ignoreErrors>1
    cat_io_addwarning([mfilename ':ignoreErrors'],'Run pipeline with backup functions (IN DEVELOPMENT).',1,[1 1]); 
  end

  
  %  -----------------------------------------------------------------
  %  separation of full CAT preprocessing and SPM segmentation
  %  preprocessing (running DARTEL and PBT with SPM segmentation)
  %  -----------------------------------------------------------------
  [pp,ff,ee,ex] = spm_fileparts(job.data{subj}); 
  if exist(fullfile(pp,['c1' ff(3:end) ee]),'file') && ...
     exist(fullfile(pp,['c2' ff(3:end) ee]),'file') && ...
     exist(fullfile(pp,['c3' ff(3:end) ee]),'file') && ...
     exist(fullfile(pp,[ff(3:end) '_seg_sn.mat']),'file') && ...
     strcmp(ff(1:2),'c1')

      cat_io_cprintf('blue','Load SPM old-segment segmentation (*seg_sn.mat)\n ')

      % create field also for dependency setup
      if ~isfield(job.extopts,'spmAMAP'), job.extopts.spmAMAP = 0; end

      job.data{subj}          = fullfile(pp,[ff ee]); 
      job.channel.vols{subj}  = fullfile(pp,[ff ee]); 

      % prepare SPM preprocessing structure 
      images = job.channel(1).vols{subj};
      for n = 2:numel(job.channel)
        images  = char(images,job.channel(n).vols{subj});
      end
      Pseg8     = fullfile(pp,[ff(3:end) '_seg_sn.mat']); 
      reso      = load(Pseg8); 
      res       = reso.flags;
      res.segsn = reso; 

      % prepare spm classes (the GUI limits this to 3 images + automatic background class) 
      for ti = 1:numel(res.ngaus)
        job.tissue(ti).ngaus = res.ngaus(ti);
        job.tissue(ti).tpm   = reso.VG(min(ti,numel(reso.VG))).fname; 
      end
      job.tissue(numel(res.ngaus)+1:end) = []; 

      % create class parameter variable 
      res.lkp = [];
      if all(isfinite(cat(1,res.ngaus)))
          for k=1:numel(res.ngaus)
              res.lkp = [res.lkp ones(1,job.tissue(k).ngaus)*k];
          end
      end

      % update template data and load template
      res.tpm = reso.VG; 
      if numel(res.lkp) == numel(res.mg)
        for lkpi = 1:max(res.lkp)
          res.mg(res.lkp==lkpi) = res.mg(res.lkp==lkpi) / sum(res.mg(res.lkp==lkpi)); 
        end
      end
      res.mn       = res.mn'; 
      tpm          = spm_load_priors8(res.tpm);

      obj.image    = spm_vol(images);
      obj.fwhm     = job.opts.fwhm;
      obj.affreg   = res.regtype;
      obj.biasreg  = res.biasreg;
      obj.biasfwhm = res.biasfwhm;
      obj.tol      = NaN;
      obj.reg      = res.warpreg;
      obj.samp     = res.samp;              
      obj.lkp      = res.lkp; 
      obj.tpm      = tpm; 

      % prepare the internal T1 map
      cfname   = fullfile(pp,[ff ee]);
      ofname   = fullfile(pp,[ff(3:end) ee]); 
      nfname   = fullfile(pp,mrifolder,['n' ff '.nii']); 
      copyfile(ofname,nfname,'f'); 

      % update option fields
      job.opts.tpm      = {reso.VG(1).fname};
      job.opts.biasreg  = res.biasreg;
      job.opts.biasfwhm = res.biasfwhm;
      job.opts.samp     = res.samp;          
      job.opts.tpm      = res.tpm(1).fname; 
      job.opts.biasreg  = res.biasreg; 
      % [abs.-displacement, membran-engery, bending-engery, linear-elasticity 2x ] 
      job.opts.warpreg  = nan(1,5); % this does not fit to the old parameter
      job.extopts.shootingT1 = job.extopts.T1; 
      job.channel(1).vols{subj}  = [nfname ex];
      job.channel(1).vols0{subj} = [ofname ex];
      res.image  = spm_vol([nfname ex]);
      res.image0 = spm_vol([ofname ex]);
      res.imagec = spm_vol([cfname ex]);
      res.spmpp  = 1; 
      job.spmpp  = 1; 
      
      % load volumes
      Ysrc0    = single(spm_read_vols(obj.image)); 
      Ylesion  = single(isnan(Ysrc0) | isinf(Ysrc0) | Ysrc0==0); clear Ysrc0;
  
      % prepare error sturture
      cat_err_res.obj = obj;

    elseif exist(fullfile(pp,['c1' ff(3:end) ee]),'file') && ...
           exist(fullfile(pp,['c2' ff(3:end) ee]),'file') && ...
           exist(fullfile(pp,['c3' ff(3:end) ee]),'file') && ...
           exist(fullfile(pp,[ff(3:end) '_seg8.mat']),'file') && strcmp(ff(1:2),'c1')
     
      cat_io_cprintf('blue','Load SPM segment segmentation (*seg8.mat)\n ')

      % create field also for dependency setup
      if ~isfield(job.extopts,'spmAMAP'), job.extopts.spmAMAP = 0; end

      job.data{subj}          = fullfile(pp,[ff ee]); 
      job.channel.vols{subj}  = fullfile(pp,[ff ee]); 

      % prepare SPM preprocessing structure 
      images = job.channel(1).vols{subj};
      for n=2:numel(job.channel)
        images = char(images,job.channel(n).vols{subj});
      end

      obj.image    = spm_vol(images);
      obj.fwhm     = job.opts.fwhm;
      obj.biasreg  = cat(1,job.opts.biasreg);
      obj.biasfwhm = cat(1,job.opts.biasfwhm);
      obj.tol      = job.opts.tol;
      obj.lkp      = [];
      obj.reg      = job.opts.warpreg;
      obj.samp     = job.opts.samp;              
      spm_check_orientations(obj.image);

      if all(isfinite(cat(1,job.tissue.ngaus)))
          for k=1:numel(job.tissue)
              obj.lkp = [obj.lkp ones(1,job.tissue(k).ngaus)*k];
          end
      end

      Pseg8 = fullfile(pp,[ff(3:end) '_seg8.mat']); 
      if ~exist(Pseg8,'file')
        error('cat_run_job:SPMpp_MissSeg8mat','Can''t find "%s" file!',Pseg8);
      end
      res = load(Pseg8);
      
      % load tpm priors 
      tpm = spm_load_priors8(res.tpm);
      obj.lkp = res.lkp; 
      obj.tpm = tpm; 
      
      % Special cases with different class numbers in case of SPM input
      if max(obj.lkp)==6
      % default cases
      elseif max(obj.lkp)==3
        cat_io_addwarning('SPMpp_PostMortem','Detected only 3 classes that are interpretated as GM, WM, and CSF/background.',0,[0 1])
      elseif max(obj.lkp)==4 
        cat_io_addwarning('SPMpp_SkullStripped','Detected only 4 classes that are interpretated as GM, WM, CSF, and background',0,[0 1])
      else
        cat_io_addwarning('SPMpp_AtypicalClsNumber',sprintf('Atypical number of input classes (max(lkp)=%d).',max(obj.lkp)),2,[0 1])
      end
      
      
      cfname  = fullfile(pp,[ff ee]);
      ofname  = fullfile(pp,[ff(3:end) ee]); 
      nfname  = fullfile(pp,mrifolder,['n' ff '.nii']); 
      copyfile(ofname,nfname,'f'); 

      Ysrc0    = single(spm_read_vols(obj.image)); 
      Ylesion  = single(isnan(Ysrc0) | isinf(Ysrc0) | Ysrc0==0); clear Ysrc0;
      
     
      job.channel(1).vols{subj}  = [nfname ex];
      job.channel(1).vols0{subj} = [ofname ex];
      res.image  = spm_vol([nfname ex]);
      res.image0 = spm_vol([ofname ex]);
      res.imagec = spm_vol([cfname ex]);
      res.spmpp  = 1; 
      job.spmpp  = 1; 
      
      % prepare error sturture
      cat_err_res.obj = obj; 
  else

      %  -----------------------------------------------------------------
      %  check resolution properties
      %  -----------------------------------------------------------------
      %  There were some images that should not be processed. So we have  
      %  to check for large slice thickness and low spatial resolution.
      %  RD201909: I tried 4x4x4 and 1x1x8 mm data with default and NLM 
      %            interpolation. Also NLM shows less edges and more 
      %            correct surfaces, the thickness results are worse and 
      %            the limits are ok.
      %  RD202007: Low resolution data is now allowed if ignoreErrer > 1.
      %            Tested again NLM and Boeseflug interpolation and there
      %            are many artefacts and simple spline interpolation is 
      %            more save. 
      %  RD202107: Print warning for reslimit/2 and alert for reslimit.  
      %  -----------------------------------------------------------------
      for n=1:numel(job.channel) 
        V = spm_vol(job.channel(n).vols{subj});
        vx_vol = sqrt(sum(V.mat(1:3,1:3).^2));

        % maximum [ slice-thickness , volume^3 , anisotropy ]
        reslimits    = [5 4 8]; 
        
        % too thin slices
        if any( vx_vol > reslimits(1) ) || job.test_warnings
          mid = [mfilename 'cat_run_job:TooLowResolution']; 
          msg = sprintf(['Voxel resolution should be better than %d mm in any dimension for \\\\n' ...
            'reliable preprocessing! This image has a resolution of %0.2fx%0.2fx%0.2f mm%s. '], ... 
            reslimits(1),vx_vol,native2unicode(179, 'latin1'));
          cat_io_addwarning(mid,msg,1 + any( vx_vol > reslimits(1) ) ,[0 1],vx_vol);
        end
        
        % too small voxel volume (smaller than 3x3x3 mm3)
        if prod(vx_vol) > (reslimits(2))^3 || job.test_warnings
          mid = [mfilename 'cat_run_job:TooLargeVoxelVolume']; 
          msg = sprintf(['Voxel volume should be smaller than %d mm%s (around %dx%dx%d mm%s) for \\\\n' ...
                  'reliable preprocessing! This image has a voxel volume of %0.2f mm%s. '], ...
                  reslimits(2)^3,native2unicode(179, 'latin1'),reslimits(2),reslimits(2),reslimits(2),...
                  native2unicode(179, 'latin1'),prod(vx_vol),native2unicode(179, 'latin1'));
          cat_io_addwarning(mid,msg,1 + (prod(vx_vol) > reslimits(2)^3),[0 1],vx_vol);
        end
        
        % anisotropy
        if max(vx_vol) / min(vx_vol) > reslimits(3) || job.test_warnings
          mid = [mfilename 'cat_run_job:TooStrongAnisotropy'];
          msg = sprintf(['Voxel anisotropy (max(vx_size)/min(vx_size)) should be smaller than %d for \\\\n' ...
                  'reliable preprocessing! This image has a resolution %0.2fx%0.2fx%0.2f mm%s \\\\nand a anisotropy of %0.2f. '], ...
                  reslimits(3),vx_vol,native2unicode(179, 'latin1'),max(vx_vol)/min(vx_vol));
          cat_io_addwarning(mid,msg,1 + (max(vx_vol) / min(vx_vol) > reslimits(3)/3),[0 1],vx_vol);
        end
      end

      % save original file name 
      for n=1:numel(job.channel) 
        job.channel(n).vols0{subj} = job.channel(n).vols{subj};
      end
      
     
      % always create the n*.nii image because of the real masking of the
      % T1 data for spm_preproc8 that includes rewriting the image!
      for n=1:numel(job.channel) 
        [pp,ff,ee] = spm_fileparts(job.channel(n).vols{subj}); 
        ofname  = fullfile(pp,[ff ee]); 
        nfname  = fullfile(pp,mrifolder,['n' ff '.nii']); 
        if strcmp(ee,'.nii')
          if ~copyfile(ofname,nfname,'f')
            spm('alert!',sprintf('ERROR: Check file permissions for folder %s.\n',fullfile(pp,mrifolder)),'',spm('CmdLine'),1);
          end
        elseif strcmp(ee,'.img')
          V = spm_vol(job.channel(n).vols{subj});
          Y = spm_read_vols(V);
          V.fname = nfname; 
          spm_write_vol(V,Y);
          clear Y; 
        end
        job.channel(n).vols{subj} = nfname;

        %% denoising
        if job.extopts.NCstr~=0
          NCstr.labels = {'none','full','light','medium','strong','heavy'};
          NCstr.values = {0 1 2 -inf 4 5}; 
          stime = cat_io_cmd(sprintf('SANLM denoising (%s)',...
            NCstr.labels{find(cell2mat(NCstr.values)==job.extopts.NCstr,1,'first')}));
          cat_vol_sanlm(struct('data',nfname,'verb',0,'prefix','','NCstr',job.extopts.NCstr)); 
          fprintf('%5.0fs\n',etime(clock,stime));   
        end

        %% skull-stripping detection
        %  ------------------------------------------------------------
        %  Detect skull-stripping or defaceing because it strongly 
        %  affects SPM segmentation that expects gaussian distribution! 
        %  If a brain mask was used than we expect 
        %   - many zeros (50% for small background - 80-90% for large backgrounds)
        %   - a smaller volume because of missing skull (below 2500 cm3)
        %   - only one object (the masked regions)
        %   - only one background (not in every case?)
        %   - less variance of tissue intensity (only 3 brain classes)
        %   - no object close to the boudary
        %  RD202008: Added detection of high intensity background because
        %            they require a very low histogram threshold to avoid
        %            masking of CSF intensities that are then the lowest
        %            values. 
        %  RD202008: Added variable for manual overwrite that maybe allow
        %            to skip the processing (but the number are maybe
        %            intersting in the XML report.
        %  ------------------------------------------------------------
% ######## RD202306: not adapted for non-zero backgounds - see cat_run_job1639 later     
        VFn   = spm_vol(nfname); 
        YF    = spm_read_vols(VFn);
        [YF,R]= cat_vol_resize(YF,'reduceV',vx_vol,2,32,'meanm');
        YF    = cat_stat_histth(YF,job.extopts.histth); 
        YFm   = cat_stat_histth(YF,[0.95 0.95],struct('scale',[0 1])); 
        Oth   = cat_stat_nanmean(YF(abs(YF(:))~=0 & YF(:)>cat_stat_nanmean(YF(:)))); 
        F0vol = cat_stat_nansum(YFm(:)>0.02) * prod(R.vx_volr) / 1000; 
        F0std = cat_stat_nanstd(YF(YFm(:)>0.2)/Oth); 
        % RD202008: improved object detection with gradient

        Yg    = cat_vol_grad(YFm,R.vx_volr); 
        gth   = max(0.05,min(0.2,median(Yg(Yg(:)>median(Yg(Yg(:)>0.1)))))); % object edge threshold
        YOB   = abs(YFm)>0.1 & Yg>gth;                                   % high intensity object edges 
        YOB   = cat_vol_morph(YOB,'ldc',8/mean(R.vx_volr));                 % full object
        % background  
        if sum(YOB(:)>0)<numel(YOB)*0.9 && sum(YOB(:)>0)>numel(YOB)*0.1  % if there is a meanful background
          YBG = ~cat_vol_morph(YOB,'lc',2/mean(R.vx_volr));                 % close noisy background
        elseif ppe.affreg.skullstripped % RD20220316: added skull-stripping case to avoid warning
          YBG = YF==0;
        else
          YBG = ~cat_vol_morph(YOB,'lc',2/mean(R.vx_volr));  
          msg = [mfilename 'Detection of background failed.']; 
          cat_io_addwarning('cat_run_job:failedBGD',msg,1,[0 1]);
        end
        % image pricture frame to test for high intensity background in case of defaced data
        hd    = max(3,round(0.03 * size(YF))); 
        YCO   = true(size(YF)); YCO(hd(1):end-hd(1)+1,hd(2):end-hd(2)+1,hd(3):end-hd(3)+1) = false; 
        hd    = max(6,round(0.06 * size(YF))); 
        YCO2  = true(size(YF)); YCO2(hd(1):end-hd(1)+1,hd(2):end-hd(2)+1,hd(3):end-hd(3)+1) = false; 
        %% skull-stripping 
        [YL,numo] = spm_bwlabel(double(YF~=0),26);  clear YL;            %#ok<ASGLU> % number of objects
        [YL,numi] = spm_bwlabel(double(YBG==0),26); clear YL;            %#ok<ASGLU> % number of background regions 
        ppe.affreg.skullstrippedpara = [sum(YBG(:))/numel(YF) numo numi F0vol F0std sum(YCO2(:) .* YOB(:))/sum(YOB(:))]; 
        ppe.affreg.skullstripped = ...
          ppe.affreg.skullstrippedpara(1)>0.5 && ...                     % many zeros
          ppe.affreg.skullstrippedpara(2)<15  && ...                     % only a few objects
          ppe.affreg.skullstrippedpara(3)<10  && ...                     % only a few background regions 
          F0vol<2500 && F0std<0.5 && ...                                 % many zeros and not too big
          ppe.affreg.skullstrippedpara(3)<0.02;                          % there should be no object (neck) very close to the boundary
        ppe.affreg.skullstripped = ppe.affreg.skullstripped || ...
          sum([ppe.affreg.skullstrippedpara(1)>0.8 F0vol<1500 F0std<0.4])>1; % or 2 extreme values
        % not automatic detection in animals
        ppe.affreg.skullstripped = ppe.affreg.skullstripped && strcmp(job.extopts.species,'human') && job.extopts.gcutstr<10;
        %% high intensity background (MP2Rage)
        ppe.affreg.highBGpara = [ ...
          cat_stat_nanmedian( YFm( YBG(:) > 1/3 )) ... normal background
          cat_stat_nanmedian( YFm( YCO(:) > 1/3 )) ... pricture frame background 
          cat_stat_nanstd( YFm(YBG(:)) > 1/3)]; % I am not sure if we should use the std, because inverted images are maybe quite similar
        ppe.affreg.highBG     = ...
          ppe.affreg.highBGpara(1) > 1/5 || ...
          ppe.affreg.highBGpara(2) > 1/5; 
        
        if ~debug, clear YFC YBG YOB YCO YCO2 F0vol F0std numo numi hd; end 
        
        % manual overwrite 
        switch job.extopts.input
          case 1, ppe.affreg.skullstripped = 0; ppe.affreg.highBGpara = 0;
          case 2, ppe.affreg.skullstripped = 1; ppe.affreg.highBGpara = 0;
          case 3, ppe.affreg.skullstripped = 0; ppe.affreg.highBGpara = 1; 
        end
        
        if ppe.affreg.highBG
          msg = 'Detected high intensity background use lower histrogram thresholds.'; 
          cat_io_addwarning([mfilename ':highBG'],msg,1,[0 1],ppe.affreg.highBGpara);
          job.extopts.histth(1) = 0.999999;
        end
        
        
        
        
        %% Interpolation
        %  -----------------------------------------------------------------
        %  The interpolation can help reducing problems for morphological
        %  operations for low resolutions and strong isotropic images. 
        %  Especially for Dartel registration a native resolution larger than the Dartel 
        %  resolution helps to reduce normalization artifacts of the
        %  deformations. Furthermore, even if artifacts can be reduced by the final smoothing
        %  it is much better to avoid them.  

        % prepare header of resampled volume
        Vi        = spm_vol(job.channel(n).vols{subj}); 
        vx_vol    = sqrt(sum(Vi.mat(1:3,1:3).^2));
        %vx_vol    = round(vx_vol*10^2)/10^2; % avoid small differences 

        % we have to look for the name of the field due to the GUI job struct generation! 
        restype   = char(fieldnames(job.extopts.restypes));
        switch restype
          case 'native'
            vx_voli  = vx_vol;
          case 'fixed' 
            vx_voli  = min(vx_vol ,job.extopts.restypes.(restype)(1) ./ ...
                       ((vx_vol > (job.extopts.restypes.(restype)(1)+job.extopts.restypes.(restype)(2)))+eps));
            vx_voli  = max(vx_voli,job.extopts.restypes.(restype)(1) .* ...
                       ( vx_vol < (job.extopts.restypes.(restype)(1)-job.extopts.restypes.(restype)(2))));
          case 'best'
            best_vx  = max( min(vx_vol) ,job.extopts.restypes.(restype)(1)); 
            vx_voli  = min(vx_vol ,best_vx ./ ((vx_vol > (best_vx + job.extopts.restypes.(restype)(2)))+eps));
          case 'optimal'
            %%
            aniso   = @(vx_vol) (max(vx_vol) / min(vx_vol)^(1/3))^(1/3);                                              % penetration factor
            volres  = @(vx_vol) repmat( round( aniso(vx_vol) * prod(vx_vol)^(1/3) * 10)/10 , 1 , 3);                  % volume resolution
            optresi = @(vx_vol) min( job.extopts.restypes.(restype)(1) , max( median(vx_vol) , volres(vx_vol) ) );    % optimal resolution 
            optdiff = @(vx_vol) abs( vx_vol - optresi(vx_vol) ) < job.extopts.restypes.(restype)(2);                  % tolerance limites
            optimal = @(vx_vol) vx_vol .* optdiff(vx_vol) + optresi(vx_vol) .* (1 - optdiff(vx_vol) );                % final optimal resolution 
            vx_voli = optimal(vx_vol); 
          otherwise 
            error('cat_run_job:restype','Unknown resolution type ''%s''. Choose between ''fixed'',''native'',''optimal'', and ''best''.',restype)
        end

        % interpolation 
        if any( (vx_vol ~= vx_voli) )  
          stime = cat_io_cmd(sprintf('Internal resampling (%4.2fx%4.2fx%4.2fmm > %4.2fx%4.2fx%4.2fmm)',vx_vol,vx_voli));
         
          if 1
            imat      = spm_imatrix(Vi.mat); 
            Vi.dim    = round(Vi.dim .* vx_vol./vx_voli);
            imat(7:9) = vx_voli .* sign(imat(7:9));
            Vi.mat    = spm_matrix(imat); clear imat; 
            Vn        = spm_vol(job.channel(n).vols{subj}); 
            cat_vol_imcalc(Vn,Vi,'i1',struct('interp',2,'verb',0,'mask',-1));
          else
            %% Small improvement for CAT12.9 that uses the cat_vol_resize function rather than the simple interpolation. 
            %  However, postive effects only in case of strong reductions >2, ie. it is nearly useless.  
            jobr              = struct(); 
            jobr.data   = {Vi.fname}; 
            jobr.interp       = -3005; % spline with smoothing in case of downsampling;  default without smoothing -5; 
            jobr.verb         = debug; 
            jobr.lazy         = 0; 
            jobr.prefix = ''; 
            jobr.restype.res  = vx_voli; % use other resolution for test  
            cat_vol_resize(jobr); 
          end
          vx_vol = vx_voli;
          
          fprintf('%5.0fs\n',etime(clock,stime));     
        else
          vx_vol = sqrt(sum(Vi.mat(1:3,1:3).^2));
        end

        clear Vi Vn;
        
        
        %% Affine Preprocessing (APP) with SPM  
        %  ------------------------------------------------------------
        %  Bias correction is essential for stable affine registration 
        %  but also the following preprocessing. This approach uses the
        %  SPM Unified segmentation for intial bias correction of the 
        %  input data with different FWHMs (low to high frequency) and 
        %  resolutions (low to high).
        %  ------------------------------------------------------------
        if job.extopts.APP == 1  
           job.subj = subj;
           [Ym,Ybg,WMth] = cat_run_job_APP_SPMinit(job,tpm,ppe,n,...
             ofname,nfname,mrifolder,ppe.affreg.skullstripped);
        end
      end
      job.extopts.gcutstr = mod(job.extopts.gcutstr,10);


      
      % MP2RAGE skull-stripping & bias-correction
      if ppe.affreg.highBG
        stime = cat_io_cmd('Additional MP2RAGE preprocessing');
       
        % mp2rage preprocessing options
        mp2job.ofiles            = {ofname};
        mp2job.files             = {nfname}; % list of MP2Rage images
        mp2job.headtrimming      = 0;        % trimming to brain or head (*0-none*,1-brain,2-head)
        mp2job.biascorrection    = 1;        % biascorrection (0-no,1-light(SPM60mm),2-average(SPM60mm+X,3-strong(SPM30+X)) #######
        mp2job.skullstripping    = 3;        % skull-stripping (0-no, 1-SPM, 2-optimized, 3-*background-removal*)
        mp2job.logscale          = inf;      % use log/exp scaling for more equally distributed
                                             % tissues (0-none, 1-log, -1-exp, inf-*auto*);
        mp2job.intnorm           = -.25;     % contrast normalization using the tan of GM normed
                                             % values with values between 1.0 - 2.0 for light to 
                                             % strong adaptiong (0-none, 1..2-manuel, -0..-2-*auto*)
        mp2job.restoreLCSFnoise  = 1;        % restore values below zero (lower CSF noise)    
        mp2job.prefix            = '';       % filename prefix (strong with PARA for parameter
                                             % depending naming, e.g. ... ) 
        mp2job.spm_preprocessing = 2;        % do SPM preprocessing (0-no, 1-yes (if required), 2-always)
        mp2job.spm_cleanupfiles  = 1;        % remove temporary files
        mp2job.report            = 0;        % create a report
        mp2job.verb              = 0;        % be verbose (0-no,1-yes,2-details)
        
        % adapt tissue class number 
        job.opts.ngaus(3) = 1;   % at least for CSF we should avoid further peaks
        if mp2job.skullstripping>0 % no skull-stripping triggered non-T1 case
          % with skull-stripping we keep things simple
          job.opts.ngaus(4) = 1; 
          job.opts.ngaus(5) = 1; 
          job.opts.ngaus(6) = 1; 
        end
        
        % call mp2rage preprocessing
        cat_vol_mp2rage(mp2job);
        ppe.affreg.skullstripped = mp2job.skullstripping==1 | mp2job.skullstripping==2; 
        
        fprintf('%5.0fs\n',etime(clock,stime));   
      end

      
      % prepare SPM preprocessing structure 
      images = job.channel(1).vols{subj};
      for n=2:numel(job.channel)
        images = char(images,job.channel(n).vols{subj});
      end
      obj.image    = spm_vol(images);
      obj.fwhm     = job.opts.fwhm;
      obj.biasreg  = job.opts.biasreg;
      obj.biasfwhm = job.opts.biasfwhm;
      obj.tpm      = tpm;   
      obj.reg      = job.opts.warpreg;
      obj.samp     = job.opts.samp; % resolution of SPM preprocessing (def. 3, 1.5 as last highest TPM optimal level)               
      obj.tol      = job.opts.tol;  % stopping criteria for SPM iteration of outer/inner loops
      obj.newtol   = 1 + ( isfield(job,'useprior') && ~isempty(job.useprior) ); 
                        % stopping criteria for outer (=tol) and inner loop:
                        %  -1-old SPM (>9 iters, inner=tol), 
                        %   0-old CAT more outer iterations (>19 iter, inner=tol),  
                        %   1-new optimal/faster with additional AUC criteria to have SPM minimum iterations (>9 iters, inner=1e-2)
                        %   2-new accurate with additioal AUC criteria but CAT minimum iterations (>19 iter, outer=tol, inner=1e-4) - like 0 
                        obj.lkp      = [];
      if ~strcmp('human',job.extopts.species) 
        % RD202105: There are multiple problems in primates and increased 
        %           accuracy is maybe better (eg. 0.5 - 0.66) 
        scannorm   = 0.7; %prod(obj.image.dims .* vx_vol).^(1/3) / 20; % variance from typical field fo view to normalized parameter 
        obj.samp   = obj.samp * scannorm; % normalize by voxel size 
        obj.fwhm   = obj.fwhm * scannorm; 
      end
      if all(isfinite(cat(1,job.tissue.ngaus)))
        for k=1:numel(job.tissue)
          obj.lkp = [obj.lkp ones(1,job.tissue(k).ngaus)*k];
        end
      end
      spm_check_orientations(obj.image);
      cat_err_res.obj = obj; 
      
      %% Initial affine registration.
      %  -----------------------------------------------------------------
      Affine  = eye(4); 
      [pp,ff] = spm_fileparts(job.channel(1).vols{subj});
      Pbt     = fullfile(pp,mrifolder,['brainmask_' ff '.nii']);
      Pb      = char(job.extopts.brainmask);
      Pt1     = char(job.extopts.T1);
      
      if ~isempty(job.opts.affreg)  
        % first affine registration (with APP)
        
        % load template and remove the skull if the image is skull-stripped
        try 
          VG = spm_vol(Pt1);
        catch
          pause(rand(1))
          VG = spm_vol(Pt1);
        end
        VF = spm_vol(obj.image(1));

        % skull-stripping of the template
        if ppe.affreg.skullstripped || job.extopts.gcutstr<0
          % print a warning for all users that did not turn off skull-stripping 
          % because processing of skull-stripped data is not standard!
          if (job.extopts.gcutstr>=0 || job.test_warnings) && ~ppe.affreg.highBG
            msg = [...
              'Detected skull-stripped or strongly masked image. Skip APP. \\n' ...
              'Use skull-stripped initial affine registration template and \\n' ...
              'TPM without head tissues (class 4 and 5)!']; 
            if job.extopts.verb>1 && job.extopts.expertgui
               msg = [msg sprintf(['\\\\n  BG: %0.2f%%%%%%%% zeros; %d object(s); %d background region(s) \\\\n' ...
                '  %4.0f cm%s; normalized SD of all tissues %0.2f'],...
                ppe.affreg.skullstrippedpara(1:4),native2unicode(179, 'latin1'),ppe.affreg.skullstrippedpara(5))]; 
            end  
            cat_io_addwarning([mfilename ':skullStrippedInputWithSkullStripping'],msg,1,[0 1],ppe.affreg.skullstrippedpara);
            
          elseif job.extopts.gcutstr<0 && ~ppe.affreg.skullstripped || job.test_warnings
            cat_io_addwarning([mfilename ':noSkullStrippingButSkull'],[...
                'Skull-Stripping is deactivated but skull was detected. \\n' ...
                'Go on without skull-stripping what possibly will fail.'],0,[0 1],ppe.affreg.skullstrippedpara);
          end

          % skull-stripping of the template
          VB = spm_vol(Pb);
          [VB2,YB] = cat_vol_imcalc([VG,VB],Pbt,'i1 .* i2',struct('interp',3,'verb',0,'mask',-1)); 
          VB2.dat(:,:,:) = eval(sprintf('%s(YB/max(YB(:))*255);',spm_type(VB2.dt))); 
          VB2.pinfo      = repmat([1;0],1,size(YB,3));
          VG             = cat_spm_smoothto8bit(VB2,0.5);
          clear VB2 YB; 
        end

        % Rescale images so that globals are better conditioned
        VF.pinfo(1:2,:) = VF.pinfo(1:2,:)/spm_global(VF);
        VG.pinfo(1:2,:) = VG.pinfo(1:2,:)/spm_global(VG);

        % APP step 1 rough bias correction and preparation of the affine 
        % registration
        % --------------------------------------------------------------
        % Already for the rough initial affine registration a simple  
        % bias corrected and intensity scaled image is required, because
        % large head intensities can disturb the whole process.
        % --------------------------------------------------------------
        % ds('l2','',vx_vol,Ym, Yt + 2*Ybg,obj.image.private.dat(:,:,:)/WMth,Ym,60)
        if job.extopts.APP == 1070 && ~ppe.affreg.highBG && ...
          ( ~isfield(job,'useprior') || isempty(job.useprior) )
          stime = cat_io_cmd('Affine preprocessing (APP)');
          Ysrc  = single(obj.image.private.dat(:,:,:)); 
          try
            [Ym,Yt,Ybg,WMth] = cat_run_job_APP_init1070(Ysrc,vx_vol,job.extopts.verb); %#ok<ASGLU>
          catch apperr
            %% very simple affine preprocessing ... only simple warning
            cat_io_addwarning([mfilename ':APPerror'],'APP failed. Use simple scaling.',1,[0 0],apperr);
            [Ym,Yt,Ybg,WMth] = APPmini(obj,VF,job.extopts.histth); %#ok<ASGLU>
            if cat_get_defaults('extopts.send_info')
              urlinfo = sprintf('%s%s%s%s%s%s%s%s%s%s',cat_version,'%2F',computer,'%2F','errors',...
                 '%2F','cat_run_job:failedAPP','%2F','WARNING: APP failed. Use simple scaling.','cat_run_job');
              cat_io_send_to_server(urlinfo);
            end
          end
          APPRMS = checkAPP(Ym,Ysrc,job.extopts.histth); 
          if APPRMS>1 || job.test_warnings
            if job.extopts.ignoreErrors < 1 
              fprintf('\n'); 
              error([mfilename ':APPerror'],'Detect problems in APP preprocessing (APPRMS: %0.4f). Do not use APP results. ',APPRMS);
            else
              cat_io_addwarning([mfilename ':APPerror'],...
                sprintf('Detect problems in APP preprocessing (APPRMS: %0.4f). \\\\nDo not use APP results. ',APPRMS),1,[0 1],APPRMS);
            end 
          end
      
          if ~( job.extopts.setCOM && ~( isfield(job,'useprior') && ~isempty(job.useprior) ) && ~ppe.affreg.highBG )
            stime = cat_io_cmd('Affine registration','','',1,stime); 
          end

          % write data to VF
          VF.dt         = [spm_type('UINT8') spm_platform('bigend')];
          VF.dat(:,:,:) = cat_vol_ctype(Ym * 200,'uint8'); 
          VF.pinfo      = repmat([1;0],1,size(Ym,3));
if 0 % new           
          % use further data limitation and remove background for affreg 
          [Ym2,ths]     = cat_stat_histth(Ym,job.extopts.histth);
          Ym2           = (Ym2 - ths(1)) ./ diff(ths) .* (1 - Ybg); 
          VF.dat(:,:,:) = cat_vol_ctype(Ym2 * 200,'uint8'); 
end
          clear WI; 

          % smoothing
          resa  = obj.samp*2; % definine smoothing by sample size
          VF1   = spm_smoothto8bit(VF,resa); 
          VG1   = spm_smoothto8bit(VG,resa);

        elseif job.extopts.APP == 1
          % APP by SPM 
          VF.dt         = [spm_type('UINT8') spm_platform('bigend')];
          VF.dat(:,:,:) = cat_vol_ctype(Ym * 200,'uint8'); 
          VF.pinfo      = repmat([1;0],1,size(Ym,3));
         
          % smoothing
          resa  = obj.samp*2; % definine smoothing by sample size
          VF1   = spm_smoothto8bit(VF,resa);
          VG1   = spm_smoothto8bit(VG,resa);

        elseif job.extopts.setCOM && ~( isfield(job,'useprior') && ~isempty(job.useprior) ) && ~ppe.affreg.highBG 
          % standard approach (no APP) with static resa value and no VG smoothing
          stime = cat_io_cmd('Coarse affine registration');
          resa  = 8;
          VF1   = spm_smoothto8bit(VF,resa);
          VG1   = VG; 
          [Ym,Yt,Ybg,WMth] = APPmini(obj,VF,job.extopts.histth);
        else
          stime = cat_io_cmd('Skip initial affine registration due to high-intensity background','','',1);  
          VF = spm_vol(obj.image(1));
          [Ym,Yt,Ybg,WMth] = APPmini(obj,VF,job.extopts.histth);
        end

        %% prepare affine parameter 
        aflags     = struct('sep',obj.samp,'regtype','subj','WG',[],'WF',[],'globnorm',1);
        aflags.sep = max(aflags.sep,max(sqrt(sum(VG(1).mat(1:3,1:3).^2))));
        aflags.sep = max(aflags.sep,max(sqrt(sum(VF(1).mat(1:3,1:3).^2))));

        % use affine transformation of given (average) data for longitudinal mode
        if isfield(job,'useprior') && ~isempty(job.useprior) 
          % even in the development pipeline the prior is a good start !
          priorname = job.useprior{1};
          [pp,ff,ee,ex] = spm_fileparts(priorname);  %#ok<ASGLU>
          catxml = fullfile(pp,reportfolder,['cat_' ff '.xml']);

          % check that file exists and get affine transformation
          if exist(catxml,'file') 
            if strcmp(job.opts.affreg,'prior')
              fprintf('\nUse affine transformation from:\n%s\n',priorname);
            else
              fprintf('\nInitialize with affine transformation from:\n%s\n',priorname);
            end
            stime           = cat_io_cmd(' ',' ','',job.extopts.verb); 
            xml             = cat_io_xml(catxml);
            % sometimes xml file does not contain affine transformation
            if ~isfield(xml,'SPMpreprocessing')
              cat_io_cprintf('warn',sprintf('WARNING: File "%s" does not contain successful affine transformation. Use individual affine transformation\n',catxml));
              Affine   = eye(4); 
              useprior = 0;
            else
              Affine   = xml.SPMpreprocessing.Affine;
              affscale = 1;
              useprior = 1 + ~strcmp(job.opts.affreg,'prior'); 
            end
          else
            cat_io_cprintf('warn',sprintf('WARNING: File "%s" not found. Use individual affine transformation\n',catxml));
            Affine   = eye(4); 
            useprior        = 0;
          end
          clear catxml; 
                      
          % RD202010: The AVG contains much more background that can
          %           cause a lot of trouble if not modelled !
          obj.lkp(obj.lkp == 6) = []; 
          obj.lkp = [ obj.lkp 6*ones(1,8) ]; 
        else
          %%
          Affine   = eye(4); 
          useprior          = 0;
        end
        
        % correct origin using COM and invert translation and use it as starting value
        if job.extopts.setCOM && ~useprior && ~ppe.affreg.highBG
          fprintf('\n'); stime = clock;  
          Affine_com        = cat_vol_set_com(VF1);
          Affine_com(1:3,4) = -Affine_com(1:3,4);
        else
          Affine_com = eye(4);
        end

        if strcmp('human',job.extopts.species) && ~useprior && ~ppe.affreg.highBG 
          % affine registration
          try
            spm_plot_convergence('Init','Coarse affine registration','Mean squared difference','Iteration');
          catch
            spm_chi2_plot('Init','Coarse affine registration','Mean squared difference','Iteration');
          end

          try 
            evalc('[Affine0, affscale]  = spm_affreg(VG1, VF1, aflags, Affine_com); Affine = Affine0;');  
          catch
            affscale = 0; 
          end
          % RD202007: Unimportant information if maff8 works 
          if job.extopts.expertgui 
            if affscale>3 || affscale<0.5
              stime  = cat_io_cmd('  Coarse affine registration failed. Try fine affine registration.','','',1,stime);
              Affine = Affine_com; 
            end
          end
        elseif strcmp('human',job.extopts.species) && ~useprior && ppe.affreg.highBG 
          Affine  = Affine_com; 
          Affine1 = Affine; 
        end

        
        %% APP step 2 - brainmasking and second tissue separated bias correction  
        %  ---------------------------------------------------------
        %  The second part of APP maps a brainmask to native space and 
        %  refines it by morphologic operations and region-growing to
        %  adapt for worse initial affine alignments. It is important
        %  that the mask covers the whole brain, whereas additional
        %  masked head is here less problematic.
        %  ---------------------------------------------------------
        %    ds('l2','',vx_vol,Ym,Yb,Ym,Yp0,90)
        
        % fine affine registration 
        if strcmp('human',job.extopts.species) && ~useprior && ~ppe.affreg.highBG
          aflags.sep = obj.samp/2; 
          aflags.sep = max(aflags.sep,max(sqrt(sum(VG(1).mat(1:3,1:3).^2))));
          aflags.sep = max(aflags.sep,max(sqrt(sum(VF(1).mat(1:3,1:3).^2))));
          
          stime = cat_io_cmd('Affine registration','','',1,stime); 
          if job.extopts.APP > 0
            VF.dt         = [spm_type('UINT8') spm_platform('bigend')];
            VF.pinfo      = repmat([1;0],1,size(Ym,3));
            VF.dat(:,:,:) = cat_vol_ctype(Ym*200); 
          end
          VF1 = spm_smoothto8bit(VF,aflags.sep);
          VG1 = spm_smoothto8bit(VG,aflags.sep);

          try
            spm_plot_convergence('Init','Affine registration','Mean squared difference','Iteration');
          catch
            spm_chi2_plot('Init','Affine registration','Mean squared difference','Iteration');
          end
          warning off
          if ~exist('affscale','var'), affscale = 1.0; end
          evalc('[Affine1,affscale1] = spm_affreg(VG1, VF1, aflags, Affine, affscale);'); 
          warning on
          if ~any(any(isnan(Affine1(1:3,:)))) && affscale1>0.5 && affscale1<3, Affine = Affine1; end 
        end
        clear VG1 VF1
       
      else
        % no affine registration and preprocessing at all and just prepare the data 
        VF = spm_vol(obj.image(1));
        [Ym,Yt,Ybg,WMth] = APPmini(obj,VF,job.extopts.histth); %#ok<ASGLU>
        if ~debug, clear Yt; end
        useprior = 0; 
        Affine = eye(4); 
      end
          
      
      
      %% Lesion masking as zero values of the orignal image (2018-06):
      %  We do not use NaN and -INF because (i) most images are only (u)int16
      %  and do not allow such values, (ii) NaN can be part of the background
      %  of resliced images, and (iii) multiple options are not required here. 
      %  Zero values can also occure by poor data scaling or processing in the 
      %  background but also by other (large) CSF regions and we have to remove  
      %  these regions later. 
      %  We further discussed to use a separate mask images but finally decided
      %  to keep this as simple as possible using no additional options!
      %  Moreover, we have to test here anyway to create warnings in case
      %  of inoptimal settings (e.g. no SLC but possible large lesions).
      obj.image0 = spm_vol(job.channel(1).vols0{subj});
      Ysrc0      = spm_read_vols(obj.image0); 
      Ylesion    = single(Ysrc0==0 | isnan(Ysrc0) | isinf(Ysrc0)); clear Ysrc0; 
      Ylesion(smooth3(Ylesion)<0.5)=0; % general denoising 
      if any( obj.image0.dim ~= obj.image.dim )
        mat      = obj.image0.mat \ obj.image.mat;
        Ylesion  = smooth3(Ylesion); 
        Ylesionr = zeros(obj.image.dim,'single'); 
        for i=1:obj.image.dim(3)
          Ylesionr(:,:,i) = single(spm_slice_vol(Ylesion,mat*spm_matrix([0 0 i]),obj.image.dim(1:2),[1,NaN]));
        end
        Ylesion = Ylesionr>0.5; clear Ylesionr;
      end
      if exist('Ybg','var'), Ylesion(Ybg)=0; end % denoising in background
      if sum(Ylesion(:))/prod(vx_vol)/1000 > 1 && ~(ppe.affreg.highBG || ppe.affreg.skullstripped) && strcmp('human',job.extopts.species)
        fprintf('%5.0fs\n',etime(clock,stime)); stime = []; 
        if ~job.extopts.SLC
          % this could be critical and we use a warning for >1 cm3 and an alert in case of >10 cm3
          cat_io_addwarning([mfilename ':StrokeLesionButNoCorrection'],sprintf( ...
           ['There are %0.2f cm%s of zeros within the brain but Stroke Lesion \\\\n', ...
            'Correction (SLC) inactive (available in the expert mode). '], ...
            sum(Ylesion(:))/1000,native2unicode(179, 'latin1')),1 + (sum(Ylesion(:))/1000 > 10),[0 1]);  
          clear Ylesion; 
        else
          cat_io_cprintf('note',sprintf('SLC: Found masked region of %0.2f cm%s. \n', sum(Ylesion(:))/1000,native2unicode(179, 'latin1'))); 
        end
      end
      
      %% APP for spm_maff8
      %  optimize intensity range
      %  we have to rewrite the image, because SPM reads it again 
      if job.extopts.APP > 0
          % WM threshold
          Ysrc = single(obj.image.private.dat(:,:,:)); 
          Ysrc(isnan(Ysrc) | isinf(Ysrc)) = min(Ysrc(:));

          if job.extopts.APP == 1070 
            % APPinit is just a simple bias correction for affreg and should
            % not be used further although it maybe helps in some cases!
            Ymc = Ysrc; 
          else
            bth = min( [ mean(single(Ysrc( Ybg(:)))) - 2*std(single(Ysrc( Ybg(:)))) , ...
                         mean(single(Ysrc(~Ybg(:)))) - 4*std(single(Ysrc(~Ybg(:)))) , ...
                         min(single(Ysrc(~Ybg(:)))) ]); 
            % use bias corrected image with original intensities 
            Ymc = Ym * abs(diff([bth,WMth])) + bth; 
            clear bth
          end
          
          % set variable and write image
          obj.image.dat(:,:,:)         = Ymc;  
          obj.image.pinfo              = repmat([255;0],1,size(Ymc,3));
          obj.image.private.dat(:,:,:) = Ymc; % = WRITE FILE

          obj.image.dt    = [spm_type('FLOAT32') spm_platform('bigend')];
          obj.image.pinfo = repmat([1;0],1,size(Ymc,3));

          % mask the eroded background
          % RD202006: masking of distant background
          % This has strong effects for some images but I found no good 
          % explanation how to use the mask. However, it seems that it is
          % useful to mask unclear and/or bad background voxels but not 
          % all of them. So we use the eroded background segment mask and 
          % remove also regions with 0 and no gradient that are often the
          % result of defacing, skull-stripping and reslicing.
          % RD202006: SVE 32 dataset 
          % We use a noisy corona here to avoid that SPM try to fit a
          % head class into it.
          % RD202006: thickness phantom problems
          % Masking causes general problems in SPM US with Christian's 
          % thickness phantom (brain PVE voxels were aligned to class 5) 
          % that required further correction in cat_main_updateSPM. 
          isSPMtpm = strcmp(job.extopts.species,'human') && ...
            ( strcmp(job.opts.tpm , fullfile(spm('dir'),'tpm','TPM.nii') ) || ...
              strcmp(job.opts.tpm , fullfile(spm('dir'),'tpm','TPM.nii,1') ) );
          [ppt,fft] = spm_fileparts(job.opts.tpm{1});
          isLONGtpm = strcmp(fft(1:min(numel(fft),7)),'longTPM');
          if exist('Ybg','var') && job.extopts.setCOM ~= 120 % case 120 no msk at all
            if ~isempty(job.useprior) || job.extopts.new_release 
              if job.extopts.setCOM == 122
                % RD202006 background corona to have save background values
                Ymsk      = cat_vol_morph(Ybg,'de',10,vx_vol) | ...           % define background for cat_main_updateSPM
                            ( cat_vol_grad( Ysrc , vx_vol)==0  &  Ysrc==0 );  % RD202006: set value arbitrary to 10 mm 
              else
                % RD202006 background random msk to have save background values
                Ymsk      = cat_vol_morph( ~Ybg ,'dd',15,vx_vol) & ...        % remove voxels far from head
                            ~( Ybg & rand(size(Ybg))>0.5) & ...               % have a noisy corona
                            ~( cat_vol_grad( Ysrc , vx_vol)==0  &  Ysrc==0 ); % remove voxel that are 0 and have no gradient
              end
            else
              % RD20220103: old cross-sectional setting with small correction for own TPMs
              if isSPMtpm || isLONGtpm
                Ymsk      = ~Ybg; % old default - mask background
              else
                cat_io_addwarning([mfilename ':noSPMTPM-noBGmasking'],...
                  'Different TPM detected - deactivated background masking!',1,[1 2]);  
                Ymsk      = []; % new special case for other TPMs
              end
            end
            if ~isempty( Ymsk )
              obj.msk       = VF; 
              obj.msk.pinfo = repmat([255;0],1,size(Ybg,3));
              obj.msk.dt    = [spm_type('uint8') spm_platform('bigend')];
              obj.msk.dat   = uint8( Ymsk ); 
              obj.msk       = spm_smoothto8bit(obj.msk,0.1); 
            end
          end            
          clear Ysrc Ymsk; 
      else
        % defintion of basic variables in case of no APP 
          obj.image.dat(:,:,:)  = single(obj.image.private.dat(:,:,:));
          obj.image.dt          = [spm_type('FLOAT32') spm_platform('bigend')];
          obj.image.pinfo       = repmat([255;0],1,size(obj.image.dat,3));
          
        % no masking !
      end

      

      
      %% Fine affine Registration with automatic selection in case of multiple TPMs. 
      %  This may not work for non human data (or very small brains).
      %  This part should be an external (coop?) function?
      if useprior==1
        stime = cat_io_cmd('SPM preprocessing 1 (estimate 1 - use prior):','','',1,stime); 
      elseif job.extopts.setCOM == 10 % no maffreg
        stime = cat_io_cmd('SPM preprocessing 1 (estimate 1 - use no TPM registration):','','',1,stime); 
      else
        stime = cat_io_cmd('SPM preprocessing 1 (estimate 1 - TPM registration):','','',1,stime); 
      end
      if ~isempty(job.opts.affreg) && strcmp('human',job.extopts.species) && ~useprior && job.extopts.setCOM ~= 10 % setcom == 10 - never use
        % turn rand warning off
        wo = warning('QUERY','MATLAB:RandStream:ActivatingLegacyGenerators'); wo = strfind( wo.state , 'on');
        if wo, warning('OFF','MATLAB:RandStream:ActivatingLegacyGenerators'); end

        if strcmp(job.extopts.species,'human')
          %% only one TPM (old approach); 
          spm_plot_convergence('Init','affine registration to TPM','Mean squared difference','Iteration');

          % first we start with the given affine registration and affreg parameter (e.g. mni) and a very low resolution
          % RD202007: also here different maskings could be tested - however, it looks quite stable now 
          [Affine2,ppe.spm_maff8.ll(1)] = spm_maff8(obj.image(1),obj.samp,(obj.fwhm+1)*16,obj.tpm,Affine ,job.opts.affreg,80); 
          scl1 = abs(det(Affine1(1:3,1:3)));
          scl2 = abs(det(Affine2(1:3,1:3)));
          
          %CG202010: disabled, because it's not working yet
          if 0 % new approach with multiple tests
            ppe.spm_maff8.ll_help = ['ll(1) with affreg result, ll(2) without spm_affreg init, ' ...
              'll(3) without spm_affreg and with opts.affreg=none; only test further cases if ll(i)<0.9'];   
            if ppe.spm_maff8.ll(1)<0.9
              % if there was no high overlap than we try if maff8 supports better results without affreg initialization 
              [Affine2o,ppe.spm_maff8.ll(2)] = spm_maff8(obj.image(1),obj.samp,(obj.fwhm+1)*16,obj.tpm,eye(4),job.opts.affreg,80); 
              Affine2 = Affine2o; 
              if ppe.spm_maff8.ll(2)<0.9
                % especially for very small heads the mni definition is not good 
                % we start here with the maff8 that is more robust to varying contrasts
                [Affine2n,ppe.spm_maff8.ll(3)] = spm_maff8(obj.image(1),obj.samp,(obj.fwhm+1)*16,obj.tpm,eye(4),'none',80); 
                if ppe.spm_maff8.ll(3) > ppe.spm_maff8.ll(2)
                  cat_io_addwarning([mfilename ':spm_maff8n'],'Use affreg=none due to better results.',1,[1 2],ppe.spm_maff8);
                  job.opts.affreg = 'none'; % in this case we have to update the affreg parameter
                  Affine2 = Affine2n;
                else
                  if ppe.spm_maff8.ll(1) < ppe.spm_maff8.ll(2)
                    Affine2 = Affine2o; 
                  end
                end
              end
            end
          end
          
          % if nan than retry with less smoothing
          if any(any(isnan(Affine2(1:3,:))))
            [Affine2,ppe.spm_maff8.ll(end+1)] = spm_maff8(obj.image(1),obj.samp,(obj.fwhm+1)*4,obj.tpm,Affine ,job.opts.affreg,80);
            if any(any(isnan(Affine2(1:3,:)))) 
              Affine2 = Affine; 
            end
          else
            % check for > 10% larger scaling 
            if scl1 > 1.1*scl2 && job.extopts.setCOM ~= 11 % setcom == 11 - use always 
              cat_io_addwarning([mfilename ':spm_maff8i'], ...
               ['Inital affine registration to TPM failed, try fine.'], 1,[1 2],ppe.spm_maff8.ll(end));
              Affine2 = Affine1;
              scl2 = scl1;
            end
            
            % after this initial step we do some refined registration with less smoothing 
            [Affine3,ppe.spm_maff8.ll(end+1)]  = spm_maff8(obj.image(1),obj.samp,obj.fwhm,obj.tpm,Affine2,job.opts.affreg,80);

            if ~any(any(isnan(Affine3(1:3,:))))
              scl3 = abs(det(Affine3(1:3,1:3)));
              % check for > 5% larger scaling 
              if scl2 > 1.05*scl3 && job.extopts.setCOM ~= 11 % setcom == 11 - use always 
                cat_io_addwarning([mfilename ':spm_maff8f'], ...
                 ['Final affine registration to TPM failed.\\n' ...
                  'Use affine registration from previous sucessful step.'], 1,[1 2],ppe.spm_maff8.ll(end));
                Affine2 = Affine1;
                %scl2 = scl1;
                Affine = Affine2;
              else
                Affine = Affine3;
              end
            else % Affine3 failed (NaN), use Affine2
              Affine = Affine2;
            end
          end
          
          % turn warning on 
          if wo, warning('ON','MATLAB:RandStream:ActivatingLegacyGenerators'); end
        end
      end
      if 0
        %% visual control for development and debugging
        VFa = VF; VFa.mat = Affine * VF.mat; %Fa.mat = res0(2).Affine * VF.mat;
        if isfield(VFa,'dat'), VFa = rmfield(VFa,'dat'); end
        [Vmsk,Yb] = cat_vol_imcalc([VFa,spm_vol(Pb)],Pbt,'i2',struct('interp',3,'verb',0,'mask',-1));  
        %[Vmsk,Yb] = cat_vol_imcalc([VFa;obj.tpm.V(1:3)],Pbt,'i2 + i3 + i4',struct('interp',3,'verb',0));  
        %[Vmsk,Yb] = cat_vol_imcalc([VFa;obj.tpm.V(5)],Pbt,'i2',struct('interp',3,'verb',0));  
        ds('d2sm','',1,Ym,Ym.*(Yb>0.5),round(size(Yb,3)*0.6))
      end
      
      
      %% test for flipping 
      %fliptest = 1; % 1 - test x>1, 2 - test for shearing 
      %[ppe.affreg.flipped, ppe.affreg.flippedval,stime] = cat_vol_testflipping(obj,Affine,fliptest,stime,0);
 
      if isfield(ppe.affreg,'skullstripped') && ~ppe.affreg.skullstripped 
        %% affreg with brainmask
        if debug 
          [AffineN,Ybi,Ymi,Ym0] = cat_run_job_APRGs(Ym,Ybg,VF,Pb,Pbt,Affine,vx_vol,obj,job); %#ok<ASGLU>
        else
          [AffineN,Ybi] = cat_run_job_APRGs(Ym,Ybg,VF,Pb,Pbt,Affine,vx_vol,obj,job);
        end
        if ~useprior, Affine = AffineN; end
        clear AffineN; 
      end

      if ppe.affreg.skullstripped || job.extopts.gcutstr<0
        %% update number of SPM gaussian classes 
        Ybg = 1 - spm_read_vols(obj.tpm.V(1)) - spm_read_vols(obj.tpm.V(2)) - spm_read_vols(obj.tpm.V(3));
        noCSF = job.extopts.gcutstr == -2; 
        if 1
          for k=1:3 - noCSF
            obj.tpm.dat{k}     = spm_read_vols(obj.tpm.V(k));
            obj.tpm.V(k).dt(1) = 64;
            obj.tpm.V(k).dat   = double(obj.tpm.dat{k});
            obj.tpm.V(k).pinfo = repmat([1;0],1,size(Ybg,3));
          end
        end

        obj.tpm.V(4 - noCSF).dat = Ybg;
        obj.tpm.dat{4 - noCSF}   = Ybg; 
        obj.tpm.V(4 - noCSF).pinfo = repmat([1;0],1,size(Ybg,3));
        obj.tpm.V(4 - noCSF).dt(1) = 64;
        obj.tpm.dat(5 - noCSF:6) = []; 
        obj.tpm.V(5 - noCSF:6)   = []; 
        obj.tpm.bg1(4 - noCSF)   = obj.tpm.bg1(6);
        obj.tpm.bg2(4 - noCSF)   = obj.tpm.bg1(6);
        obj.tpm.bg1(5 - noCSF:6) = [];
        obj.tpm.bg2(5 - noCSF:6) = [];
        %obj.tpm.V = rmfield(obj.tpm.V,'private');

        % tryed 3 peaks per class, but BG detection error require manual 
        % correction (set 0) that is simple with only one class  
        % RD202306: SPM is not considering things without variation and 
        %           a zeroed background is simply not existing!
        %           Moreover it is possible just to ignore classes :D
        %           Hence, we may not need to redefine the TPM at all.
        if noCSF
          job.opts.ngaus = [([job.tissue(1:2).ngaus])',1]; % gaussian background
        else
          job.opts.ngaus = ([job.tissue(1:3).ngaus])'; % no gaussian background
        end
        obj.lkp        = [];
        for k=1:numel(job.opts.ngaus)
          job.tissue(k).ngaus = job.opts.ngaus(k);
          obj.lkp = [obj.lkp ones(1,job.tissue(k).ngaus)*k];
        end
      end
      
      % adpation parameter for affine registration? 0.98 and 1.02?
      if isfield(job.extopts,'affmod') && any(job.extopts.affmod)
        stime = cat_io_cmd('  Modify affine regitration:','','',1,stime); 
        AffineUnmod = Affine; 
        if numel(job.extopts.affmod)>6, job.extopts.affmod = job.extopts.affmod(1:6); end % remove too many
        if numel(job.extopts.affmod)<3, job.extopts.affmod(end+1:3) = job.extopts.affmod(1); end % isotropic
        if numel(job.extopts.affmod)<6, job.extopts.affmod(end+1:6) = 0; end % add translation
        fprintf('\n  Modify affine regitration (S=[%+3d%+3d%+3d], T=[%+3d%+3d%+3d])',job.extopts.affmod);
        sf   = (100 - job.extopts.affmod(1:3)) / 100;  
        imat = spm_imatrix(Affine); 
        COMc = [eye(4,3), [ 0; -24 / mean(imat(7:9)); -12 / mean(imat(7:9)); 1]  ]; 
        imat = spm_imatrix(Affine * COMc); 
        imat(1:3) = imat(1:3) - job.extopts.affmod(4:6); 
        imat(7:9) = imat(7:9) .* sf;  
        AffineMod = spm_matrix(imat) / COMc; 
        
        res.AffineUnmod = AffineUnmod; 
        res.AffineMod   = AffineMod;
      else
        AffineMod = Affine;
      end 
      obj.Affine  = AffineMod;
      cat_err_res.obj = obj; 
    
      
      %% SPM preprocessing 1
      %  ds('l2','a',0.5,Ym,Ybg,Ym,Ym,140);
      %  ds('l2','a',0.5,Ysrc/WMth,Yb,Ysrc/WMth,Yb,140);
      warning off 
      try 
        %% inital estimate
        stime = cat_io_cmd('SPM preprocessing 1 (estimate 2):','','',job.extopts.verb-1,stime);
        obj.tol = job.opts.tol; % reset within loop 
        
        % RD202012:  Missclassification of GM as CSF and BG as tissue:
        %  We observed problems with high-quality data (e.g. AVGs) and
        %  interpolated low resolution data (single_subT1=Collins), 
        %  where (low-intensity) GM was missclassified as CSF but also 
        %  miss-classification of background. The problems where caused
        %  by the US (or better the way we use it here) and higher
        %  accuracy (increased number of minimum iterations in 
        %  cat_spm_preproc8) was essential. Nevertheless, some
        %  cases still cause severe errors at 3 mm sample size but 
        %  not for other resolutions (eg. 4, 6, 2 mm). In addition, the
        %  log-likelihood became NaN in such cases. Hence, I added a 
        %  little loop her to test other resolutions for samp. We keep
        %  the output here quit simple to avoid confusion. samp is a
        %  rarely used expert parameter and other resolutions are only 
        %  used as backup and the effects should be not too strong for 
        %  normal data without strong bias. 

        % sampling resolution definition
        if      round(obj.samp) == 3, samp = [obj.samp 4 2]; 
        elseif  round(obj.samp) == 2, samp = [obj.samp 3 4]; 
        elseif  ~strcmp(job.extopts.species,'human')
                                      samp = [obj.samp obj.samp*2 obj.samp/2];          
        else,                         samp = [obj.samp 3 2]; 
        end 

        if job.opts.redspmres 
          image1 = obj.image; 
          [obj.image,redspmres]  = cat_vol_resize(obj.image,'interpv',1);
        end
        
        % run loop until you get a non NaN
        % #### additional threshold is maybe also helpful ####
        warning off; % turn off "Warning: Using 'state' to set RANDN's internal state causes RAND ..."
        for sampi = 1:numel(samp)
          obj.samp = samp(sampi); 
          try 
            res = cat_spm_preproc8(obj);
            if any(~isnan(res.ll))
              break
            else
              stime = cat_io_cmd(sprintf('SPM preprocessing 1 (estimate %d):',...
                2 + sampi),'caution','',job.extopts.verb-1,stime);
            end
          catch  
            % RD202110: Catch real errors of cat_spm_preproc8 and try a 
            %           skull-stripped version just to get some result.
            stime = cat_io_cmd(sprintf('SPM preprocessing 1 (estimate %d skull-stripped):',...
                2 + sampi),'caution','',job.extopts.verb-1,stime);
            if exist('Ybi','var') % use individual mask
              obj.image.dat = obj.image.dat .* (cat_vbdist(single(Ybi>0.5))<10);
            else % use template mask 
              VFa = VF; VFa.mat = Affine * VF.mat; %Fa.mat = res0(2).Affine * VF.mat;
              if isfield(VFa,'dat'), VFa = rmfield(VFa,'dat'); end
              [Vmsk,Yb] = cat_vol_imcalc([VFa,spm_vol(Pb)],Pbt,'i2',struct('interp',3,'verb',0,'mask',-1));  
              ds('d2sm','',1,Ym,Ym.*(Yb>0.5),round(size(Yb,3)*0.6))
              obj.image.dat = obj.image.dat .* (cat_vbdist(single(Yb>0.5))<10);
            end 
            res = cat_spm_preproc8(obj);
            if any(~isnan(res.ll))
              break
            else
              stime = cat_io_cmd(sprintf('SPM preprocessing 1 (estimate %d):',...
                2 + sampi),'caution','',job.extopts.verb-1,stime);
            end
          end
        end
        if ~exist('res','var')
          cat_io_printf('SPM preprocessing with default settings failed. Run backup settings. \n'); 
        end
        warning on; 
        
        if job.opts.redspmres
          res.image1 = image1; 
          clear reduce; 
        end
        
      catch
        %%
        cat_io_addwarning([mfilename ':ignoreErrors'],'Run backup function (IN DEVELOPMENT).',1,[1 1]); 
        
        if isfield(obj.image,'dat')
          tmp = obj.image.dat; 
        else
          tmp = spm_read_vols(obj.image); 
          dt2 = obj.image.dt(1); 
          dts = cat_io_strrep(spm_type(dt2),{'float32','float64'},{'single','double'}); 
          obj.image.dat = eval(sprintf('%s(tmp);',dts)); 
          obj.image.pinfo = repmat([1;0],1,size(tmp,3));
        end
        if exist('Ybi','var')
          obj.image.dat = obj.image.dat .* (cat_vbdist(single(Ybi>0.5))<10);
        else
          VFa = VF; VFa.mat = Affine * VF.mat; %Fa.mat = res0(2).Affine * VF.mat;
          if isfield(VFa,'dat'), VFa = rmfield(VFa,'dat'); end
          [Vmsk,Yb] = cat_vol_imcalc([VFa,spm_vol(Pb)],Pbt,'i2',struct('interp',3,'verb',0,'mask',-1));  
          ds('d2sm','',1,Ym,Ym.*(Yb>0.5),round(size(Yb,3)*0.6))
          obj.image.dat = obj.image.dat .* (cat_vbdist(single(Yb>0.5))<10);
        end
        
        suc = 0;
        % try higher accuracy
        while obj.tol>10e-9 && suc == 0
          obj.tol = obj.tol / 10;
          try
            res = cat_spm_preproc8(obj);
            suc = 1;
          end
        end
        if suc == 0  
          % try lower accuracy
          while obj.tol<1 && suc == 0
            obj.tol = obj.tol * 10;
            try
              res = cat_spm_preproc8(obj);
              suc = 1;
            end
          end
        end
        
        if any( (vx_vol ~= vx_voli) ) || ~strcmp(job.extopts.species,'human')
          [pp,ff,ee] = spm_fileparts(job.channel(1).vols{subj});
          delete(fullfile(pp,[ff,ee]));
        end
        
        if suc==0
          %%
          mati = spm_imatrix(V.mat);
          
          error('cat_run_job:spm_preproc8',sprintf([
            'Error in spm_preproc8. Check image and orientation. \n'...
            '  Volume size (x,y,z):   %8.0f %8.0f %8.0f \n' ...
            '  Origin (x,y,z):        %8.1f %8.1f %8.1f \n' ...
            '  Rotation (deg):        %8.1f %8.1f %8.1f \n' ...
            '  Resolution:            %8.1f %8.1f %8.1f \n'],...
            V.dim,[mati(1:3),mati(4:6),mati(7:9),]));
        end
        
        %% set internal image
        if ~exist('dt2','var')
          %tmp = obj.image.dat;
          dt2 = obj.image.dt(1); 
          dts = cat_io_strrep(spm_type(dt2),{'float32','float64'},{'single','double'}); 
        end
        obj.image.dat   = eval(sprintf('%s(tmp);',dts)); 
        obj.image.pinfo = repmat([1;0],1,size(tmp,3));
        obj.image.dt(1) = dt2; 
        res.image.dat   = eval(sprintf('%s(tmp);',dts)); 
        res.image.pinfo = repmat([1;0],1,size(tmp,3));
        res.image.dt(1) = dt2; 
      end
      if ppe.affreg.skullstripped || job.extopts.gcutstr<0
       % here we have to add manually our no variance background value of 0 
        res.mg(end+1)  = 1;
        res.mn(end+1)  = ppe.affreg.skullstrippedBGth;
        res.vr(end+1)  = max(eps,numel(res.wp) * eps);
        res.wp = res.wp - numel(res.wp) * eps;
        res.wp(end+1)  = numel(res.wp) * eps;
        res.lkp(end+1) = 4;
      end
      warning on 

      if job.extopts.expertgui>1
        %% print the tissue peaks 
        mnstr = sprintf('\n  SPM-US:  ll=%0.6f, Tissue-peaks: ',res.ll);
        for lkpi = 1:numel(res.lkp)
          if lkpi==1 || ( res.lkp(lkpi) ~= res.lkp(lkpi-1) )
            mnstr = sprintf('%s  (%d) ',mnstr,res.lkp(lkpi)); 
          end
          if lkpi>1 &&( res.lkp(lkpi) == res.lkp(lkpi-1) ), mnstr = sprintf('%s, ',mnstr); end
          if sum(res.lkp == res.lkp(lkpi))>1 && res.mg(lkpi)==max( res.mg( res.lkp == res.lkp(lkpi) )), mnstr = sprintf('%s*',mnstr); end
          mnstr = sprintf('%s%0.2f',mnstr,res.mn( lkpi )); 
        end
        cat_io_cprintf('blue',sprintf('%s\n',mnstr)); 
        cat_io_cmd(' ',' ');
      end
      fprintf('%5.0fs\n',etime(clock,stime));
      
      %% check contrast (and convergence)
      %  RD202006: SPM peak averaging 
      %  To get one single tissue value the following definition is correct 
      %  in principle but outliers can have strong effect on mean estimation: 
      %    clsint = @(x) round( sum(res.mn(res.lkp==x) .* res.mg(res.lkp==x)') * 10^5)/10^5;
      %  So we have to be careful by using these values.
      if ~isempty(res)  
        clsint = @(x) round( sum(res.mn(res.lkp==x) .* res.mg(res.lkp==x)') * 10^5)/10^5;
        Tgw = [cat_stat_nanmean(res.mn(res.lkp==1)) cat_stat_nanmean(res.mn(res.lkp==2))]; 
        Tth = [
          ... min(res.mn(res.lkp==6 & res.mg'>0.3)) ... % bg; ignore the background, because of MP2RGAGE, R1, and MT weighted images  
          max( min( clsint(3) ,  max(Tgw) + 1.5*abs(diff(Tgw))) , min(Tgw) - 1.5*abs(diff(Tgw)) ) ... % csf with limit for T2!
          clsint(1) ... gm
          clsint(2) ... wm 
          clsint(4) ... skull
          clsint(5) ... head tissue
          clsint(6) ... background
        ];

        res.Tth = Tth; 
        cat_err_res.res = res;   

        % RD202006: Throw warning/error?
        % Due to inaccuracies of the clsint function it is better to print 
        % this as intense warning.
        if any( Tth(2:3)<0 ) || job.test_warnings
          cat_io_addwarning([mfilename ':negVal'],sprintf( ...
           ['CAT12 was developed for images with positive values and \\\\n', ...
            'negative values can lead to preprocessing problems. The average \\\\n', ...
            'intensities of CSF/GM/WM are %0.4f/%0.4f/%0.4f. \\\\n', ...
            'If you observe problems, you can use the %s to scale your data.'], Tth(1:3), ...
            spm_file('Datatype-batch','link','spm_jobman(''interactive'','''',''spm.tools.cat.tools.spmtype'');')),2,[0 1],Tth);
        end
      end

  end
  
  %% updated tpm information for skull-stripped data should be available for cat_main
  if isfield(obj.tpm,'bg1') && exist('ppe','var') && ( ppe.affreg.skullstripped || job.extopts.gcutstr<0 )
    fname = res.tpm(1).fname;
    res.tpm       = obj.tpm;
    res.tpm(1).fname = fname;
  end
  spm_progress_bar('Clear');
  cat_progress_bar('Clear');
          
  % call main processing
  res.tpm     = obj.tpm.V;
  res.stime   = stime0;
  res.catlog  = catlog; 
  res.Affine0 = res.Affine; 
  res.image0  = spm_vol(job.channel(1).vols0{subj}); 
  if exist('ppe','var'), res.ppe = ppe; end
  
  if isfield(job.extopts,'affmod') && any(job.extopts.affmod)
    res.AffineUnmod = AffineUnmod; 
    res.AffineMod   = AffineMod;
  end
  if exist('Ybge','var')
    % If the background was estimated we want to save it to improve the 
    % SPM segmentation in regions outside the TPM volume. 
    res.bge = Ybge; 
  end
  
  if exist('Ylesion','var'), res.Ylesion = Ylesion; else, res.Ylesion = false(size(res.image.dim)); end; clear Ylesion;
  if exist('redspmres','var'); res.redspmres = redspmres; res.image1 = image1; end
  job.subj = subj; 
  cat_main(res,obj.tpm,job);
  
  % delete denoised/interpolated image
  [pp,ff,ee] = spm_fileparts(job.channel(1).vols{subj});
  if exist(fullfile(pp,[ff,ee]),'file') 
    delete(fullfile(pp,[ff,ee]));
  end
  %%
  
  if usediary
    diary off;
  end
return

%=======================================================================
function [Ym,Yt,Ybg,WMth] = APPmini(obj,VF,histth)
%% very simple affine preprocessing (APP)
%  ------------------------------------------------------------------------
%  Creates an intensity normalized image Ym by the average higher tissue
%  intensity WMth estimated in the mask Yt. Moreover, it estimates the
%  background region Ybg. 
%
%  [Ym,Yt,Ybg,WMth] = APPmini(obj,VF)
%  ------------------------------------------------------------------------
%  Robert Dahnke 2019/01

  Ysrc = single(obj.image.private.dat(:,:,:)); 

  % remove outlier and use SPM for intensity normalization to uint8 
  % empirical division by 200 to get WM values around 1.0
  Ysrc = cat_stat_histth(Ysrc,histth,struct('scale',[0 1]));
  VF0  = cat_spm_smoothto8bit(VF,0.1); 
  Ym   = single(VF0.dat)/200; clear VG0 
  
  % find the larges object and estimate the averag intensity
  % keep in mind that this will may inlcude the head (and in MP2RAGE/MT/R1
  % images also the background), i.e. highest intensity is may head,
  % blood vessels or WM or CSF in T1/PD
  Yt   = cat_vol_morph(Ym>cat_stat_nanmean(Ym(Ym(:)>0.1)),'l',[100 1000])>0.5;
  WMth = cat_stat_kmeans( Ysrc(Yt(:)) , 1); 
  
  % rescale Ym and roughly estimate the background (not in MP2Rage/MT/R1)
  Ym   = Ysrc ./ WMth;
  Ybg  = cat_vol_morph(Ym<0.2,'l',[20 0.05])>0;
  
return

function APP_RMSE = checkAPP(Ym,Ysrc,histth) 
%% check Ym
%  ------------------------------------------------------------------------
%  Function to compare the normalized gradient maps of two input images 
%  that should be nearly identical.
%
%  APP_RMSE = checkAPP(Ym,Ysrc) 
%  ------------------------------------------------------------------------
%  Robert Dahnke 2019/01

  % remove strongest outlier
  Ym   = cat_stat_histth(Ym  ,histth);
  Ysrc = cat_stat_histth(Ysrc,histth);

  % avoid division by zeros
  Ym   = Ym   + min(Ym(:));
  Ysrc = Ysrc + min(Ysrc(:)); 
  
  % normalized gradient maps
  Ygm = cat_vol_grad(Ym)   ./ (Ym + eps);     
  Ygs = cat_vol_grad(Ysrc) ./ (Ysrc + eps);

  % use only the central region and values in the expected tissue range
  sYm  = round(size(Ym) / 5);
  Ymsk = false(size(Ym) ); Ymsk(sYm(1):end-sYm(1),sYm(2):end-sYm(2),sYm(3):end-sYm(3)) = true;  
  Ymsk = Ymsk & cat_vol_morph(Ygm<2 & Ygs<2 & Ym>0.5 & Ysrc>0.5,'e');
  
  % general error between both images within the mask
  APP_RMSE = cat_stat_nanmean( ( Ygm(Ymsk(:)) - Ygs(Ymsk(:)) ).^2 )^0.5;
  
return