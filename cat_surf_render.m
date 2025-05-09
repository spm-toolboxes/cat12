function varargout = cat_surf_render(action,varargin)
% Display a surface mesh & various utilities
% FORMAT H = cat_surf_render('Disp',M,'PropertyName',propertyvalue)
% M        - a GIfTI filename/object or patch structure
% H        - structure containing handles of various objects
% Opens a new figure unless a 'parent' Property is provided with an axis
% handle.
%
% FORMAT H = cat_surf_render(M)
% Shortcut to previous call format.
%
% FORMAT H = cat_surf_render('ContextMenu',AX)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
%
% FORMAT H = cat_surf_render('Overlay',AX,P)
% AX       - axis handle or structure given by cat_surf_render('Disp',...)
% P        - data to be overlayed on mesh (see spm_mesh_project)
%
% FORMAT H = cat_surf_render('ColourBar',AX,MODE)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
% MODE     - {['on'],'off'}
%
% FORMAT H = cat_surf_render('Clim',AX,[mn mx])
% AX       - axis handle or structure given by cat_surf_render('Disp',...)
% mn mx    - min/max of range
%
% FORMAT H = cat_surf_render('Clip',AX,[mn mx])
% AX       - axis handle or structure given by cat_surf_render('Disp',...)
% mn mx    - min/max of clipping range
%
% FORMAT H = cat_surf_render('ColourMap',AX,MAP)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
% MAP      - a colour map matrix
%
% FORMAT MAP = cat_surf_render('ColourMap',AX)
% Retrieves the current colourmap.
%
% FORMAT H = cat_surf_render('Underlay',AX,P)
% AX       - axis handle or structure given by cat_surf_render('Disp',...)
% P        - data (curvature) to be underlayed on mesh (see spm_mesh_project)
%
% FORMAT H = cat_surf_render('Clim',AX, range)
% range    - range of colour scaling
%
% FORMAT H = cat_surf_render('SaveAs',AX, filename)
% filename - filename
%
% FORMAT cat_surf_render('Register',AX,hReg)
% AX       - axis handle or structure returned by cat_surf_render('Disp',...)
% hReg     - Handle of HandleGraphics object to build registry in.
% See spm_XYZreg for more information.
%__________________________________________________________________________
% Copyright (C) 2010-2011 Wellcome Trust Centre for Neuroimaging
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________

% based on spm_mesh_render.m
% $Id$

%#ok<*ASGLU>
%#ok<*INUSL>
%#ok<*INUSD>
%#ok<*TRYNC>
 
%-Input parameters
%--------------------------------------------------------------------------
if ~nargin, action = 'Disp'; end

if ~ischar(action)
    varargin = {action varargin{:}};
    action   = 'Disp';
end

varargout = {[]};

%-Action
%--------------------------------------------------------------------------
switch lower(action)
    
    %-Display
    %======================================================================
    case 'disp'
        if isempty(varargin)
            [M, sts] = spm_select(1,'mesh','Select surface mesh file');
            if ~sts, return; end
        else
            M = varargin{1};
        end
        
        
        %-load mesh data
        if ischar(M) || isstruct(M) % default - one surface
            [pp,ff,ee] = spm_fileparts(M);  
            H.filename{1} = M; 
            switch ee
                case '.gii'
                    M  = gifti(M); 
                otherwise
                    M  = cat_io_FreeSurfer('read_surf',M);
                    M  = gifti(M);
            end
            
        elseif iscellstr(M) % multiple surfaces
          %%
            MS = M; % save filelist 
            H.filename = MS; 
            [pp,ff,ee] = spm_fileparts(MS{1}); 
            switch ee
                case '.gii'
                    M  = gifti(MS{1}); 
                otherwise
                    M  = cat_io_FreeSurfer('read_surf',MS{1}); 
                    M  = gifti(M);
            end
            for mi = 2:numel(MS)
                try
                    MI         = gifti(MS{mi});
                    M.faces    = [double(M.faces); double(MI.faces) + size(M.vertices,1)];   % further faces with increased vertices ids
                    M.vertices = [M.vertices; MI.vertices];                 % further points at the end of the list
                    if isfield(M,'cdata');
                        M.cdata  = [M.cdata; MI.cdata];                     % further texture values at the end of the list
                    end
                catch
                    error('cat_surf_render:multisurf','Error adding surface %d: ''%s''.\n',mi,MS{mi});
                end
            end
        else
          H.filename = {''}; 
        end
        
        
        if ~isfield(M,'vertices')
          try
            MM = M;


            if isempty(MM.private.metadata)
              Tname = fullfile(fileparts(mfilename('fullpath')),'templates_surfaces_32k','mesh.central.freesurfer.gii');
              MM.private.metadata(1).value = Tname;
              MM.private.metadata(1).name = 'SurfaceID';
              M  = gifti(MM.private.metadata(1).value);
              try, M.cdata = MM.cdata(); end
            else
              try
                name = MM.private.metadata(1).value;

                % try to replace path to cat12 and correct template name to new template
                if ~exist(name,'File')
                  [pt,nm,xt] = fileparts(name);
                   nm = strrep(nm,'Template_T1_IXI555_MNI152_GS','Template_T1');                     
                   [pt2,nm2,xt2] = fileparts(pt);
                   MM.private.metadata(1).value = fullfile(fileparts(mfilename('fullpath')),nm2,[nm xt]);
                end
              end
              M  = gifti(MM.private.metadata(1).value);
              try, M.cdata = MM.cdata(); end
            end
          catch
            error('Cannot find a surface mesh to be displayed.');
          end
        end
        O = getOptions(varargin{2:end});
        if isfield(O,'results')
          H.results = O.results;
        else
          H.results = 0; 
        end
        if isfield(O,'cdata') % data input
            M.cdata = O.cdata; 
        elseif isfield(O,'pcdata') % single file input 
            if ischar(O.pcdata)
                [pp,ff,ee] = fileparts(O.pcdata);
                H.filename{1} = O.pcdata; 
                if strcmp(ee,'.gii')
                    Mt = gifti(O.pcdata);
                    M.cdata = Mt.cdata;
                elseif strcmp(ee,'.annot')
                  labelmap = zeros(0); labelnam = cell(0); ROIv = zeros(0);
            
                  %%
                    [fsv,cdata,colortable] = cat_io_FreeSurfer('read_annotation',O.pcdata); %clear fsv;
                    [sentry,id] = sort(colortable.table(:,5));
                    M.cdata = cdata; nid=1;
                    for sentryi = 1:numel(sentry)
                      ROI = round(cdata)==sentry(sentryi); 
                      if sum(ROI)>0 && ( (sentryi==numel(sentry)) || sentry(sentryi)~=sentry(sentryi+1) && ...
                        (sentryi==1 || sentry(sentryi)~=sentry(sentryi+1))), 
                        M.cdata(round(cdata)==sentry(sentryi)) = nid;  
                        labelmap(nid,:) = colortable.table(id(sentryi),1:3)/255;
                        labelnam(nid)   = colortable.struct_names(id(sentryi));
                        nid=nid+1;
                        ROIv(nid) = sum(ROI); 
                      end
                    end
                    %labelmap = colortable.table(id,1:3)/255;
                    % addition maximum element
                    M.cdata(M.cdata>=colortable.numEntries)=0; %colortable.numEntries+1;  
                    labelmapclim = [min(M.cdata),max(M.cdata)];
                    %labelnam = colortable.struct_names(id);
                else
                    M.cdata = cat_io_FreeSurfer('read_surf_data',O.pcdata);
                end
            elseif iscell(O.pcdata) % multifile input
                if ~exist('MS','var') || numel(O.pcdata)~=numel(MS)
                    error('cat_surf_render:multisurfcdata',...
                      'Number of meshes and texture files must be equal.\n');
                end
                for mi=1:numel(O.pcdata)
                  [pp,ff,ee] = fileparts(O.pcdata{mi});
                  if strcmp(ee,'.gii')
                    H.filename{mi} = fullfile(pp,ff); 
                  else
                    H.filename{mi} = O.pcdata{mi}; 
                  end
                end
                [pp,ff,ee] = fileparts(O.pcdata{1});
                if strcmp(ee,'.gii')
                    MC = gifti(O.pcdata{1});
                    M.cdata = MC.cdata;
                elseif strcmp(ee,'.annot')
                  %%
                    [fsv,cdata,colortable] = cat_io_FreeSurfer('read_annotation',O.pcdata{1}); %clear fsv;
                    [sentry,id] = sort(colortable.table(:,5));
                    M.cdata = cdata; nid=1;
                    for sentryi = 1:numel(sentry)
                      ROI = round(cdata)==sentry(sentryi); 
                      if sum(ROI)>0 && ( (sentryi==numel(sentry)) || sentry(sentryi)~=sentry(sentryi+1) && ...
                        (sentryi==1 || sentry(sentryi)~=sentry(sentryi+1))), 
                        M.cdata(round(cdata)==sentry(sentryi)) = nid;  
                        labelmap(nid,:) = colortable.table(id(sentryi),1:3)/255; %#ok<AGROW>
                        labelnam(nid)   = colortable.struct_names(id(sentryi)); %#ok<AGROW>
                        nid=nid+1;
                        ROIv(nid) = sum(ROI); %#ok<AGROW> 
                      end
                    end
                    %labelmap = colortable.table(id,1:3)/255;
                    % addition maximum element
                    M.cdata(M.cdata>colortable.numEntries)=0; %colortable.numEntries+1;  
                    labelmapclim = [min(M.cdata),max(M.cdata)];
                    %labelnam = colortable.struct_names(id);
                else
                    M.cdata = cat_io_FreeSurfer('read_surf_data',O.pcdata{1});
                end
                for mi = 2:numel(MS)
                    [pp,ff,ee] = fileparts(O.pcdata{mi});
                    if strcmp(ee,'.gii')
                        Mt = gifti(O.pcdata{mi});
                    elseif strcmp(ee,'.annot')
                      %%
                        [fsv,cdata,colortable] = cat_io_FreeSurfer('read_annotation',O.pcdata{mi}); %clear fsv;
                        [sentry,id] = sort(colortable.table(:,5));
                        Mt.cdata = cdata; 
                        for sentryi = 1:numel(sentry)
                          ROI = round(cdata)==sentry(sentryi); 
                          if sum(ROI)>0 && ( (sentryi==numel(sentry)) || sentry(sentryi)~=sentry(sentryi+1) && ...
                            (sentryi==1 || sentry(sentryi)~=sentry(sentryi+1))), 
                            Mt.cdata(round(cdata)==sentry(sentryi)) = nid;  
                            labelmap(nid,:) = colortable.table(id(sentryi),1:3)/255; 
                            labelnam(nid)   = colortable.struct_names(id(sentryi));
                            nid=nid+1;
                            ROIv(nid) = sum(ROI); 
                          end
                        end
                        %labelmap = colortable.table(id,1:3)/255;
                        % addition maximum element
                        Mt.cdata(Mt.cdata>=colortable.numEntries + labelmapclim(2))=0; %colortable.numEntries+1;  
                        %labelnam = colortable.struct_names(id);
                    else
                        Mt.cdata = cat_io_FreeSurfer('read_surf_data',O.pcdata{mi});
                    end
                    M.cdata = [M.cdata; Mt.cdata];
                    labelmapclim = [min(double(M.cdata)),max(double(M.cdata))];
                end
                if size(M.vertices,1)~=numel(M.cdata); 
                  warning('cat_surf_render:multisurfcdata',...
                    'Surface data error (number of vertices does not match number of surface data), remove texture.\n');
                  M = rmfield(M,'cdata');
                end
            end 
        else
          % with values you can colorize the surface and have not the
          % standard lighting ... 20160623
          % M.cdata = 0.5*ones(size(M.vertices,1),1);
        end
        if ~isfield(M,'vertices') || ~isfield(M,'faces')
            error('cat_surf_render:nomesh','ERROR:cat_surf_render: No input mesh in ''%s''', varargin{1});
        end
        
        M = export(M,'patch');
        
        %-Figure & Axis
        %------------------------------------------------------------------
        if isfield(O,'parent')
            H.issubfigure = 1; 
            H.axis   = O.parent;
            H.figure = ancestor(H.axis,'figure');
            figure(H.figure); axes(H.axis);
        else
            H.issubfigure = 0;
            H.figure = figure('Color',[1 1 1]);
            H.axis   = axes('Parent',H.figure,'Visible','off');
        end
        renderer = get(H.figure,'Renderer');
        set(H.figure,'Renderer','OpenGL');
        
        if isfield(M,'facevertexcdata')
          H.cdata = M.facevertexcdata;
        else
          H.cdata = []; 
        end
        
        %% -Patch
        %------------------------------------------------------------------
        P = struct('vertices',M.vertices, 'faces',double(M.faces));
        H.patch = patch(P,...
            'FaceColor',        [0.6 0.6 0.6],...
            'EdgeColor',        'none',...
            'FaceLighting',     'gouraud',...
            'SpecularStrength', 0.0,... 0.7
            'AmbientStrength',  0.4,... 0.1
            'DiffuseStrength',  0.6,... 0.7
            'SpecularExponent', 10,...
            'Clipping',         'off',...
            'DeleteFcn',        {@myDeleteFcn, renderer},...
            'Visible',          'off',...
            'Tag',              'CATSurfRender',...
            'Parent',           H.axis);
        setappdata(H.patch,'patch',P);
        
        %-Label connected components of the mesh
        %------------------------------------------------------------------
        C = spm_mesh_label(P);
        setappdata(H.patch,'cclabel',C);
        
        %-Compute mesh curvature
        %------------------------------------------------------------------
        curv = spm_mesh_curvature(P); %$ > 0;
        setappdata(H.patch,'curvature',curv);
        
        %-Apply texture to mesh
        %------------------------------------------------------------------
        if isfield(M,'facevertexcdata')
            T = M.facevertexcdata;
        elseif isfield(M,'cdata')
            T = M.cdata;
        else
            T = [];
        end
        try
          updateTexture(H,T);
        end
        
        %-Set viewpoint, light and manipulation options
        %------------------------------------------------------------------
        axis(H.axis,'image');
        axis(H.axis,'off');
        view(H.axis,[90 0]);
        material(H.figure,'dull');
        
        % default lighting
        if ismac, H.catLighting = 'inner'; else H.catLighting = 'cam'; end
        %H.catLighting = 'cam';
        
        H.light(1) = camlight('headlight','infinite'); set(H.light(1),'Parent',H.axis,'Tag','camlight'); 
        switch H.catLighting
          case 'inner'
            % switch off local light (camlight)
            set(H.light(1),'visible','off');
            
            % set inner light
            H.light(2) = light('Position',[0 0 0],'Tag','centerlight'); 
            set(H.patch,'BackFaceLighting','unlit');
        end
        
        set(H.axis,'Visible','On');
        H.rotate3d = rotate3d(H.axis);
        set(H.axis,'Visible','Off');
        set(H.rotate3d,'ActionPostCallback',{@myPostCallback, H});
        if ~H.results
          set(H.rotate3d,'Enable','on');
        end
        %try
        %    setAllowAxesRotate(H.rotate3d, ...
        %        setxor(findobj(H.figure,'Type','axes'),H.axis), false);
        %end
        
      
        
        %-Store handles
        %------------------------------------------------------------------
        setappdata(H.axis,'handles',H);
        set(H.patch,'Visible','on');
        
        setappdata(H.patch,'clip',[false NaN NaN]);
        %set(H.axis,'Position',[0.1 0.1 0.8 0.8]);
        if exist('labelmap','var')
          %%
          setappdata(H.patch,'colourmap',labelmap); 
          cat_surf_render('clim',H.axis,labelmapclim - 1); 
          try
            colormap(H.axis,labelmap); 
          catch
            colormap(labelmap); 
          end
          caxis(labelmapclim - [1 0]);
          H = cat_surf_render('ColorBar',H.axis,'on'); 
          labelnam2 = labelnam; for lni=1:numel(labelnam2),labelnam2{lni} = [' ' labelnam2{lni} ' ']; end
          labelnam2(end+1) = {''}; labelnam2(end+1) = {''}; 
          labellength = min(100,max(cellfun('length',labelnam2))); 
          ss = max(1,round(diff(labelmapclim+1)/30)); 
          ytick = labelmapclim(1)-0.5:ss:labelmapclim(2)+0.5;
          set(H.colourbar,'ytick',ytick,'yticklabel',labelnam2(1:ss:end),...
            'Position',[max(0.75,0.98-0.008*labellength) 0.05 0.02 0.9]);
          try, set(H.colourbar,'TickLabelInterpreter','none'); end
          set(H.axis,'Position',[0.1 0.1 min(0.6,0.98-0.008*labellength - 0.2) 0.8])
          H.labelmap = struct('colormap',labelmap,'ytick',ytick,'labelnam2',{labelnam2});
          setappdata(H.axis,'handles',H);
        end
       
        % annotation with filename
        %if ~H.issubfigure
        %  [pp,ff,ee] = fileparts(H.filename{1}); 
        %  H.text = annotation('textbox','string',[ff ee],'position',[0.0,0.97,0.2,0.03],'LineStyle','none','Interpreter','none');
        %end

        %-Add context menu
        %------------------------------------------------------------------
        cat_surf_render('ContextMenu',H);
        
        
        % set default view
        cat_surf_render2('view',H,[   0  90]);
        
        axis vis3d; %zoom(1.15);
         
        % remember this zoom level
        zoom reset
        
        
    %-Context Menu
    %======================================================================
    case 'contextmenu'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if ~isempty(get(H.patch,'UIContextMenu')), return; end
        
        % -- Inflate, Overlay , Underlay, Label
        cmenu = uicontextmenu('Callback',{@myMenuCallback, H});
        if ~H.results        
            uimenu(cmenu, 'Label','Inflate', 'Interruptible','off', ...
                'Callback',{@myInflate, H});

            uimenu(cmenu, 'Label','Underlay (Texture)...', 'Interruptible','off', ...
                'Callback',{@myUnderlay, H});
        
            uimenu(cmenu, 'Label','Image Sections...', 'Interruptible','off', ...
                'Callback',{@myImageSections, H});
        
            uimenu(cmenu, 'Label','Change underlying mesh...', 'Interruptible','off', ...
                'Callback',{@myChangeGeometry, H});
        else
            % -- surface meshes --
            c = uimenu(cmenu, 'Label', 'Meshes');

            sinfo1 = cat_surf_info( H.filename ); 
            if strcmp(sinfo1(1).texture,'defects'), set(c,'Enable','off');  end
              if ~isempty(strfind(fileparts(sinfo1(1).Pmesh),'_32k'))
                str32k = '_32k';
              else
                str32k = '';
              end
              H.meshs = {'Average' ; 'Inflated' ; 'Shooting' ;  'Custom...' };
              for i=1:numel(H.patch)
                H.meshs = [ H.meshs , { 
                    fullfile(fileparts(mfilename('fullpath')),['templates_surfaces' str32k],[sinfo1(i).side '.central.freesurfer.gii']);
                    fullfile(fileparts(mfilename('fullpath')),['templates_surfaces' str32k],[sinfo1(i).side '.inflated.freesurfer.gii']);
                    fullfile(fileparts(mfilename('fullpath')),['templates_surfaces' str32k],[sinfo1(i).side '.central.' cat_get_defaults('extopts.shootingsurf') '.gii']);
                    '';
                  }];
              end

              uimenu(c, 'Label','Average',    'Checked','on' , 'Callback',{@myChangeMesh, H});
              uimenu(c, 'Label','Inflated',   'Checked','off', 'Callback',{@myChangeMesh, H});
              uimenu(c, 'Label','Shooting',   'Checked','off', 'Callback',{@myChangeMesh, H});
              uimenu(c, 'Label','Custom Mesh...',        'Interruptible','off','Callback',{@myChangeGeometry, H});
              
              
              
              % -- surface overlays --
            %{
              c = uimenu(cmenu, 'Label', 'Overlay');
              % get & name images
              % create menu
              % add custom
              uimenu(c, 'Label','Overlay...', 'Interruptible','off','Callback',{@myOverlay, H});
            %}
              
        end

        c = uimenu(cmenu, 'Label', 'Connected Components', 'Interruptible','off');
        C = getappdata(H.patch,'cclabel');
        for i=1:length(unique(C))
            uimenu(c, 'Label',sprintf('Component %d',i), 'Checked','on', ...
                'Callback',{@myCCLabel, H});
        end
        
        
        % -- Views --
        if H.results
          uimenu(cmenu, 'Label','Rotate', 'Checked','off', 'Separator','on', ...
                    'Callback',{@mySwitchRotate, H});
        else
          uimenu(cmenu, 'Label','Rotate', 'Checked','on', 'Separator','on', ...
            'Callback',{@mySwitchRotate, H});
          uimenu(cmenu, 'Label','Synchronise Views', 'Visible','off', ...
            'Checked','off', 'Tag','SynchroMenu', 'Callback',{@mySynchroniseViews, H});
        end
        c = uimenu(cmenu, 'Label','View');
        uimenu(c, 'Label','Right',  'Callback', {@myView, H, [90 0]});
        uimenu(c, 'Label','Left',   'Callback', {@myView, H, [-90 0]});
        uimenu(c, 'Label','Top',    'Callback', {@myView, H, [0 90]});
        uimenu(c, 'Label','Bottom', 'Callback', {@myView, H, [-180 -90]});
        uimenu(c, 'Label','Front',  'Callback', {@myView, H, [-180 0]});
        uimenu(c, 'Label','Back',   'Callback', {@myView, H, [0 0]});

        
        % -- Colorbar --
        %if ~H.results        
          uimenu(cmenu, 'Label','Colorbar', 'Callback', {@myColourbar, H});
        %end

        
        % -- Colormap --
        c = uimenu(cmenu, 'Label','Colormap');
        %clrmp = {'hot' 'jet' 'gray' 'hsv' 'bone' 'copper' 'pink' 'white' ...
        %     'flag' 'lines' 'colorcube' 'prism' 'cool' 'autumn' ...
        %     'spring' 'winter' 'summer'};
        clrmp = {'hot' 'cool' , 'jet' 'hsv' , 'autumn' 'spring' 'winter' 'summer' , ... 
                 'CAThot','CAThotinv','CATcold','CATcoldinv','CATtissues','CATcold&hot'};
        for i=1:numel(clrmp)
          if any(i == [5,9]) 
            uimenu(c, 'Label', clrmp{i}, 'Checked','off', 'Callback', {@myColourmap, H}, 'Separator', 'on');
          else
            if i == 1 + H.results*3
              uimenu(c, 'Label', clrmp{i}, 'Checked','on', 'Callback', {@myColourmap, H});
              myColourmap([],[],H,'colormap',clrmp{i})
            else
              uimenu(c, 'Label', clrmp{i}, 'Checked','off', 'Callback', {@myColourmap, H});
            end
          end
        end
        % custom does not work, as far as I can not update from the
        % colormapeditor yet 
        %uimenu(c, 'Label','Custom...'  , 'Checked','off', 'Callback', {@myColourmap, H, 'custom'}, 'Separator', 'on');

        
        % -- Colorrange --
        if ~H.results         
          c = uimenu(cmenu, 'Label','Colorrange');
          uimenu(c, 'Label','min-max'    , 'Checked','off', 'Callback', {@myCaxis, H, 'auto'});
          uimenu(c, 'Label','2-98 %'     , 'Checked','off', 'Callback', {@myCaxis, H, '2p'});
          uimenu(c, 'Label','5-95 %'     , 'Checked','off', 'Callback', {@myCaxis, H, '5p'});
          uimenu(c, 'Label','Custom...'  , 'Checked','off', 'Callback', {@myCaxis, H, 'custom'});
          uimenu(c, 'Label','Custom %...', 'Checked','off', 'Callback', {@myCaxis, H, 'customp'});
          uimenu(c, 'Label','Synchronise Colorranges', 'Visible','off', ...
              'Checked','off', 'Tag','SynchroMenu', 'Callback',{@mySynchroniseCaxis, H});
        end

        
        % -- Lighting --
        c = uimenu(cmenu, 'Label','Lighting'); 
        macon = {'on' 'off'}; isinner = strcmp(H.catLighting,'inner'); 
        uimenu(c, 'Label','cam',    'Checked',macon{isinner+1}, 'Callback', {@myLighting, H,'cam'});
        if ismac
          uimenu(c, 'Label','inner',  'Checked',macon{2-isinner}, 'Callback', {@myLighting, H,'inner'});
        end
        uimenu(c, 'Label','set1',   'Checked','off', 'Callback', {@myLighting, H,'set1'}, 'Separator', 'on');
        uimenu(c, 'Label','set2',   'Checked','off', 'Callback', {@myLighting, H,'set2'});
        uimenu(c, 'Label','set3',   'Checked','off', 'Callback', {@myLighting, H,'set3'});
        uimenu(c, 'Label','grid',   'Checked','off', 'Callback', {@myLighting, H,'grid'}, 'Separator', 'on');
        uimenu(c, 'Label','none',   'Checked','off', 'Callback', {@myLighting, H,'none'});
   
        if H.results
          c = uimenu(cmenu, 'Label','Mesh Texture');
          uimenu(c, 'Label','bright',  'Checked','off', 'Callback', {@mySurfcolor, H,1.0});
          uimenu(c, 'Label','medium',  'Checked','on',  'Callback', {@mySurfcolor, H,0.5});
          uimenu(c, 'Label','dark',    'Checked','off', 'Callback', {@mySurfcolor, H,0.0});
          uimenu(c, 'Label','dull',    'Checked','on',  'Callback', {@myMaterial, H,'dull'}, 'Separator', 'on');
          uimenu(c, 'Label','shiny',   'Checked','off', 'Callback', {@myMaterial, H,'shiny'});
          uimenu(c, 'Label','metal',   'Checked','off', 'Callback', {@myMaterial, H,[0.2 0.7 0.5 2]});
        end
        
        % -- Cross --
        if H.results
          c = uimenu(cmenu, 'Label','Crossbar');
          uimenu(c, 'Label','off',      'Checked','off', 'Callback', {@myCross, H,'setsize',0});
          uimenu(c, 'Label','small',    'Checked','off', 'Callback', {@myCross, H,'setsize',50});
          uimenu(c, 'Label','medium',   'Checked','on',  'Callback', {@myCross, H,'setsize',100});
          uimenu(c, 'Label','large',    'Checked','off', 'Callback', {@myCross, H,'setsize',200});
          uimenu(c, 'Label','red',      'Checked','on',  'Callback', {@myCross, H,'setcolor',[1 0 0]},'Separator', 'on');
          uimenu(c, 'Label','blue',     'Checked','off', 'Callback', {@myCross, H,'setcolor',[0 0 1]});
          uimenu(c, 'Label','white',    'Checked','off', 'Callback', {@myCross, H,'setcolor',[1 1 1]});
          uimenu(c, 'Label','black',    'Checked','off', 'Callback', {@myCross, H,'setcolor',[0 0 0]});
          uimenu(c, 'Label','Custom...','Checked','off', 'Callback', {@myCross, H,'setcolor',[]});
        end
        
        
        % -- Material --
        if ~H.results           
          c = uimenu(cmenu, 'Label','Material');
          uimenu(c, 'Label','dull',     'Checked','on',  'Callback', {@myMaterial, H,'dull'});
          uimenu(c, 'Label','shiny',    'Checked','off', 'Callback', {@myMaterial, H,'shiny'});
          uimenu(c, 'Label','metal',    'Checked','off', 'Callback', {@myMaterial, H,[0.2 0.7 0.5 2]});
          %uimenu(c, 'Label','plastic',  'Checked','off', 'Callback', {@myMaterial, H,'plastic'});
          %uimenu(c, 'Label','greasy',   'Checked','off', 'Callback', {@myMaterial, H,'greasy'});
          %uimenu(c, 'Label','grid',     'Checked','off', 'Callback', {@myMaterial, H,'grid'});
          uimenu(c, 'Label','Custom...','Checked','off', 'Callback', {@myMaterial, H,'custom'});
        end 

        
        % -- Transparency --
        c = uimenu(cmenu, 'Label','Transparency'); tlevel = [0 10 40 80 90]; reson = {'on' 'off'};
        uimenu(c, 'Label','TextureTransparency',        'Checked','on',   'Callback', {@myTextureTransparency, H});
        for ti=1:numel(tlevel)
          if ti==1
            uimenu(c, 'Label',sprintf('%0.0f%%',tlevel(ti)), 'Checked',reson{2 - (ti==1 + H.results*1)}, 'Callback', {@myTransparency, H}, 'Separator', 'on');
          else
            uimenu(c, 'Label',sprintf('%0.0f%%',tlevel(ti)), 'Checked',reson{2 - (ti==1 + H.results*1)}, 'Callback', {@myTransparency, H});
          end
        end
        
        
        % -- Background --
        col   = get(H.figure,'Color');
        if isempty(col) || all(col==[1 1 1]), col = [0.94 0.94 0.94]; end % default color
        bgs = {'off','off','off','off','off'}; 
        if     all(col==[0.94 0.94 0.94]), bgs{1} = 'on'; % light gray
        elseif all(col==[0.10 0.20 0.40]), bgs{2} = 'on'; % dark blue
        elseif all(col==[1.00 1.00 0.999]),bgs{3} = 'on'; % the white is slighly different 
        elseif all(col==[0.00 0.00 0.00]), bgs{4} = 'on'; % 
        else,                              bgs{5} = 'on';
        end
        c = uimenu(cmenu, 'Label','Background Color');
        uimenu(c, 'Label','Lightgray', 'Checked',bgs{1}, 'Callback', {@myBackgroundColor, H, [0.94 0.94 0.94]}); 
        uimenu(c, 'Label','Darkblue',  'Checked',bgs{2}, 'Callback', {@myBackgroundColor, H, [0.10 0.20 0.40]});
        uimenu(c, 'Label','White',     'Checked',bgs{3}, 'Callback', {@myBackgroundColor, H, [1.00 1.00 0.999]}); 
        uimenu(c, 'Label','Black',     'Checked',bgs{4}, 'Callback', {@myBackgroundColor, H, [0.00 0.00 0.00]}); 
        uimenu(c, 'Label','Custom...', 'Checked',bgs{5}, 'Callback', {@myBackgroundColor, H, []}, 'Separator', 'on'); 
        %set(H.figure,'Color',col); whitebg(H.figure,col); set(H.figure,'Color',col);
        
        if H.results
            % definition and loading of the atlas maps for data coursor 
            % - is it useful to load them at the start?
            % - is it useful to show it or the outlines? 
            % - there is at least no space for the legend 
            % - use of own atlas maps? 
            satlas = {
                'Desikan'     'aparc_DK40';
                'Destrieux'   'aparc_a2009s';
                'HCP'         'aparc_HCP_MMP1';};
            if ~isempty(strfind(fileparts(sinfo1(1).Pmesh),'_32k'))
              str32k = '_32k';
            else
              str32k = '';
            end
            %%
            for ai = 1:size(satlas,1)
              % define file
              safiles = fullfile(fileparts(mfilename('fullpath')),['atlases_surfaces' str32k],...
                sprintf('%s.%s.freesurfer.annot',sinfo1(1).side,satlas{ai,2}));
                
              % loading
              [S,sdata,odata,rnames] = cat_surf_load(safiles,'mesh',2);
              H.satlases(ai).adata   = S.facevertexcdata;
              H.satlases(ai).rnames  = rnames; 
              H.satlases(ai).names   = [satlas(ai,:) safiles]; 
            end
        end
        
        % -- Data Coursor --
        uimenu(cmenu, 'Label','Data Cursor', 'Callback', {@myDataCursor, H});

        
        % -- Slider --
        if ~H.results        
          uimenu(cmenu, 'Label','Slider', 'Callback', {@myAddslider, H});
        end
        
        
        % -- Save --
        uimenu(cmenu, 'Label','Save As...', 'Separator', 'on', ...
            'Callback', {@mySave, H,H.filename{1}});
        
        set(H.rotate3d,'enable','off');
        try set(H.rotate3d,'uicontextmenu',cmenu); end
        try set(H.patch,   'uicontextmenu',cmenu); end
        if ~H.results
          set(H.rotate3d,'enable','on');
        end

        dcm_obj = datacursormode(H.figure);  
        set(dcm_obj, 'Enable','off', 'SnapToDataVertex','on', ...
            'DisplayStyle','Window', 'Updatefcn',{@myDataCursorUpdate, H});
        
          
          
    %-View
    %======================================================================
    case 'view'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        myView([],[],H,varargin{2});

        
    %-SaveAs
    %======================================================================
    case 'saveas'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        mySavePNG(H.patch,[],H, varargin{2});

        
    %-Underlay
    %======================================================================
    case 'underlay'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if nargin < 3, varargin{2} = []; end

        v = varargin{2};
        if ischar(v)
          [p,n,e] = fileparts(v);
          if ~strcmp(e,'.mat') && ~strcmp(e,'.nii') && ~strcmp(e,'.gii') && ~strcmp(e,'.img') % freesurfer format
            v = cat_io_FreeSurfer('read_surf_data',v);
          else
            try spm_vol(v); catch, v = gifti(v); end;
          end
        end
        if isa(v,'gifti')
          v = v.cdata;
        end

        setappdata(H.patch,'curvature',v);
        setappdata(H.axis,'handles',H);
        d = getappdata(H.patch,'data');
        updateTexture(H,d);

        
    %-Overlay
    %======================================================================
    case 'overlay'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if nargin < 3, varargin{2} = []; end
        updateTexture(H,varargin{2:end});
        try
          tr1 = findobj(get(findobj('Label','Transparency'),'children'),'checked','on'); 
          tr2 = findobj(get(findobj('Label','Transparency'),'children'),'checked','on','Label','TextureTransparency');
          myTransparency([],[],H,get(setdiff(tr1,tr2) ,'Label'));
        end
        
    %-Slices
    %======================================================================
    case 'slices'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if nargin < 3, varargin{2} = []; end
        renderSlices(H,varargin{2:end});
        
        
    %-Material
    %======================================================================
    case 'material'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
       
        
    %-Lighting
    %======================================================================
    case 'lighting'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
       
        
    %-ColourBar
    %======================================================================
    case {'colourbar', 'colorbar'}
        if isempty(varargin), varargin{1} = gca; end
        if length(varargin) == 1, varargin{2} = 'on'; end
        H   = getHandles(varargin{1});
        d   = getappdata(H.patch,'data');
        col = getappdata(H.patch,'colourmap');
        if strcmpi(varargin{2},'off')
            if isfield(H,'colourbar') && ishandle(H.colourbar)
               %set(H.colourbar,'visible','off')  
               if ~H.results
                 set(H.axis,'Position',get(H.axis,'position') .* [0.10 0.10 0.8 0.8]);
               end
               delete(H.colourbar);
               H = rmfield(H,'colourbar');
               setappdata(H.axis,'handles',H);
            end
            return;
        end
        %{
        if strcmpi(varargin{2},'on')
          if isfield(H,'colourbar') && ishandle(H.colourbar)
            set(H.colourbar,'visible','on')  
            labelnam2 = get(H.colourbar,'yticklabel');
            labellength = min(100,max(cellfun('length',labelnam2))); 
            set(H.axis,'Position',[0.03 0.03 min(0.94,0.98-0.008*labellength - 0.06) 0.94])
            return
          end
        end
        %}
        if isempty(d) || ~any(d(:)), varargout = {H}; return; end
        if isempty(col), col = hot(256); end
        if ~isfield(H,'colourbar') || ~ishandle(H.colourbar)
            if H.results
              H.colourbar = colorbar('peer',H.axis,'southoutside'); %'EastOutside');
              set(H.colourbar,'Tag','','Position',get(H.axis,'position') .* [1.05 1 0.25 0.02]);
            else
              H.colourbar = colorbar('peer',H.axis); %'EastOutside');
              set(H.colourbar,'Tag','','Position',get(H.axis,'position') .* [.93 0.2 0.02 0.6]);
            end
            set(get(H.colourbar,'Children'),'Tag','');
        end
        caxis(H.axis,[min(d(:)),max(d(:))] .* [1 1+eps])
        
        c(1:size(col,1),1,1:size(col,2)) = col;
        ic = findobj(H.colourbar,'Type','image');
        clim = getappdata(H.patch, 'clim');
        if isempty(clim), clim = [false NaN NaN]; end

        % Update colorbar colors if clipping is used
        clip = getappdata(H.patch, 'clip');
        if ~isempty(clip)
            if ~isnan(clip(2)) && ~isnan(clip(3))
                ncol = length(col);
                col_step = (clim(3) - clim(2))/ncol;
                cmin = max([1,ceil((clip(2)-clim(2))/col_step)]);
                cmax = min([ncol,floor((clip(3)-clim(2))/col_step)]);
                col(cmin:cmax,:) = repmat([0.5 0.5 0.5],(cmax-cmin+1),1);
                c(1:size(col,1),1,1:size(col,2)) = col;
            end
        end
        if size(d,1) > 1
            set(ic,'CData',c(1:size(d,1),:,:));
            set(ic,'YData',[1 size(d,1)]);
            set(H.colourbar,'YLim',[1 size(d,1)]);
            set(H.colourbar,'YTickLabel',[]);
        else
            set(ic,'CData',c);
            clim = getappdata(H.patch,'clim');
            if isempty(clim), clim = [false min(d) max(d)]; end
            if clim(3) > clim(2)
              set(ic,'YData',clim(2:3));
              set(H.colourbar,'YLim',clim(2:3));
              caxis(H.axis,[min(d(:)),max(d(:))] .* [1 1+eps])
            end
        end
        if isfield(H,'labelmap')
          labellength = min(100,max(cellfun('length',H.labelmap.labelnam2))); 
          ss = diff(H.labelmap.ytick(1:2)); 
          set(H.colourbar,'ytick',H.labelmap.ytick,'yticklabel',H.labelmap.labelnam2(1:ss:end),...
            'Position',get(H.axis,'position') .* [max(0.75,0.98-0.008*labellength) 0.05 0.02 0.9]);
          try, set(H.colourbar,'TickLabelInterpreter','none'); end
          set(H.axis,'Position',[0.1 0.1 min(0.6,0.98-0.008*labellength - 0.2) 0.8])
        end
        setappdata(H.axis,'handles',H);
        
        
    %-ColourMap
    %======================================================================
    case {'colourmap', 'colormap'}
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if length(varargin) == 1
            varargout = { getappdata(H.patch,'colourmap') };
            return;
        else
            setappdata(H.patch,'colourmap',varargin{2});
            d = getappdata(H.patch,'data');
            updateTexture(H,d);
        end
        if nargin>1
            H.colormap = colormap(H.axis,varargin{2});
        end
        if isfield(H,'colourmap')
          set(H.colourbar,'YLim',get(H.axis,'clim')); 
        end
        
        %{
  switch varargin{1}
    case 'onecolor'
      dx= spm_input('Color','1','r',[0.7 0.7 0.7],[3,1]);
      H=cat_surf_render('Colourmap',H,feval(get(obj,'Label'),1));
      
      if isempty(varargin{1})
          c = uisetcolor(H.figure, ...
              'Pick a background color...');
          if numel(c) == 1, return; end
      else
          c = varargin{1};
      end
      h = findobj(H.figure,'Tag','SPMMeshRenderBackground');
      if isempty(h)
          set(H.figure,'Color',c);
          whitebg(H.figure,c);
          set(H.figure,'Color',c);
      else
          set(h,'Color',c);
          whitebg(h,c);
          set(h,'Color',c);
      end
    case 'colormapeditor'
      colormapeditor
      H=cat_surf_render('Colourmap',H,feval(get(obj,'Label'),256));
  end  
       %} 
        
%     %-ColourMap
%     %======================================================================
%     case {'labelmap'}
%         if isempty(varargin), varargin{1} = gca; end
%         H = getHandles(varargin{1});
%         if length(varargin) == 1
%             varargout = { getappdata(H.patch,'labelmap') };
%             return;
%         else
%             setappdata(H.patch,'labelmap',varargin{2});
%             d = getappdata(H.patch,'data');
%             updateTexture(H,d,getappdata(H.patch,'labelmap'),'flat');
%         end     
        
    
    %-CLim
    %======================================================================
    case 'clim'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if length(varargin) == 1
            c = getappdata(H.patch,'clim');
            if ~isempty(c), c = c(2:3); end
            varargout = { c };
            return;
        else
            if strcmp(varargin{2},'on') || isempty(varargin{2}) || any(~isfinite(varargin{2}))
                setappdata(H.patch,'clim',[false NaN NaN]);
            else
                setappdata(H.patch,'clim',[true varargin{2}]);
            end
            d = getappdata(H.patch,'data');
            updateTexture(H,d);
          
        end
        
        if nargin>1 && isnumeric(varargin{2}) && numel(varargin{2})==2
            % use min/max if given range is the same
            if diff(varargin{2})
                caxis(H.axis,varargin{2});
            else
                caxis(H.axis,[min(d),max(d)])
            end
        else
            caxis(H.axis,[min(d),max(d)])
            %varargin{2} = [min(d),max(d)];
        end
        
        %{
        if isfield(H,'colourbar')
          set(H.colourbar','ticksmode','auto','LimitsMode','auto')
          tick      = get(H.colourbar,'ticks');
          ticklabel = get(H.colourbar,'ticklabels');
          if ~isnan(str2double(ticklabel{1}))
            tickdiff = mean(diff(tick));
            if tick(1)~=varargin{2}(1)   && diff([min(d),varargin{2}(1)])>tickdiff*0.05
              tick = [varargin{2}(1),tick]; ticklabel = [sprintf('%0.3f',varargin{2}(1)); ticklabel]; 
            end
            if tick(end)~=varargin{2}(2) && diff([tick(1),varargin{2}(2)])>tickdiff*0.05, 
              tick = [tick,varargin{2}(2)]; ticklabel = [ticklabel; sprintf('%0.3f',varargin{2}(2))];
            end
            set(H.colourbar,'ticks',tick); %,'ticklabels',ticklabel);
          end
          set(H.colourbar','ticksmode','manual','LimitsMode','manual')
        end
        %}
        
    %-CLip
    %======================================================================
    case 'clip'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        if length(varargin) == 1
            c = getappdata(H.patch,'clip');
            if ~isempty(c), c = c(2:3); end
            varargout = { c };
            return;
        else
            if isempty(varargin{2}) || any(~isfinite(varargin{2}))
                setappdata(H.patch,'clip',[false NaN NaN]);
            else
                setappdata(H.patch,'clip',[true varargin{2}]);
            end
            d = getappdata(H.patch,'data');
            updateTexture(H,d);
        end
        
    %-Register
    %======================================================================
    case 'register'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1});
        hReg = varargin{2};
        xyz  = spm_XYZreg('GetCoords',hReg);
        hs   = myCrossBar('Create',H,xyz);
        set(hs,'UserData',hReg);
        spm_XYZreg('Add2Reg',hReg,hs,@myCrossBar);
        
    %-Slider
    %======================================================================
    case 'slider'
        if isempty(varargin), varargin{1} = gca; end
        if length(varargin) == 1, varargin{2} = 'on'; end
        H = getHandles(varargin{1});
        if strcmpi(varargin{2},'off')
            if isfield(H,'slider') && ishandle(H.slider)
                delete(H.slider);
                H = rmfield(H,'slider');
                setappdata(H.axis,'handles',H);
            end
            return;
        else
            AddSliders(H);
        end
        setappdata(H.axis,'handles',H);

        
    %-TextureTransparency
    %======================================================================
    case 'texturetransparency'
        if isempty(varargin), varargin{1} = gca; end
        H = getHandles(varargin{1}); 
        myTextureTransparency(H,[],H)
   
    %-Otherwise...
    %======================================================================
    otherwise
        try
            H = cat_surf_render('Disp',action,varargin{:});
        catch
            error('Unknown action.');
        end
end

varargout = {H};



%==========================================================================
function myChangeMesh(obj,evt,H)
pmenu  = get(obj,'parent');
meshs  = {'Average','Inflated','Shooting','Custom Mesh...'};
for mi = 1:numel(meshs), set( findobj( pmenu, 'Label',meshs{mi}) ,'Checked','off'); end
set(obj,'Checked','on');

% remove slices ...
oldslices = findobj(get(H.axis,'children'),'type','surf','Tag','volumeSlice');
delete(oldslices);

id = find(cellfun('isempty',strfind(H.meshs(:,1),obj.Label))==0); 
for i=1:numel(H.patch)
  if ischar(H.meshs{id,1+i})
    [pp,ff,ee] = spm_fileparts(H.meshs{id,1+i});  
    switch ee
        case '.gii'
            M  = gifti(H.meshs{id,1+i}); 
        otherwise
            M  = cat_io_FreeSurfer('read_surf',H.meshs{id,1+i});
            M  = gifti(M);
    end
    H.patch(i).Vertices = M.vertices; 
  else
    H.patch(i).Vertices = H.meshs{id,1+i}; 
  end
end
d = getappdata(H.patch(1),'data');
updateTexture(H,d);
%==========================================================================
function AddSliders(H)

c = getappdata(H.patch,'clim');
mn = c(2);
mx = c(3);

% allow slider a more extended range
mnx = 1.5*max([-mn mx]);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Overlay min', ...
        'Position', [0.01 0.01 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mn, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clim_min);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Overlay max', ...
        'Position', [0.21 0.01 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mx, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clim_max);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Clip min', ...
        'Position', [0.01 0.83 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mn, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clip_min);

sliderPanel(...
        'Parent'  , H.figure, ...
        'Title'   , 'Clip max', ...
        'Position', [0.21 0.83 0.2 0.17], ...
        'Backgroundcolor', [1 1 1],...
        'Min'     , -mnx, ...
        'Max'     , mnx, ...
        'Value'   , mn, ...
        'FontName', 'Verdana', ...
        'FontSize', 8, ...
        'NumFormat', '%f', ...
        'Callback', @slider_clip_max);

setappdata(H.patch,'clip',[true mn mn]);
setappdata(H.patch,'clim',[true mn mx]);

%==========================================================================
function myTextureTransparency(obj,evt,H)
y = {'on','off'}; toggle = @(x) y{1+strcmpi(x,'on')};
set(obj,'Checked',toggle(get(obj,'Checked')));
d = getappdata(H.patch(1),'data');
updateTexture(H,d);
%==========================================================================

%==========================================================================
function O = getOptions(varargin)
O = [];
if ~nargin
    return;
elseif nargin == 1 && isstruct(varargin{1})
    for i=fieldnames(varargin{1})
        O.(lower(i{1})) = varargin{1}.(i{1});
    end
elseif mod(nargin,2) == 0
    for i=1:2:numel(varargin)
        O.(lower(varargin{i})) = varargin{i+1};
    end
else
    error('Invalid list of property/value pairs.');
end

%==========================================================================
function H = getHandles(H)
if ~nargin || isempty(H), H = gca; end
if ishandle(H) && ~isappdata(H,'handles')
    a = H; clear H;
    H.axis     = a;
    H.figure   = ancestor(H.axis,'figure');
    H.patch    = findobj(H.axis,'type','patch');
    H.light    = findobj(H.axis,'type','light');
    H.rotate3d = rotate3d(H.axis);
    setappdata(H.axis,'handles',H);
elseif ishandle(H)
    H = getappdata(H,'handles');
else
    H = getappdata(H.axis,'handles');
end

%==========================================================================
function myMenuCallback(obj,evt,H)
H = getHandles(H);

h = findobj(obj,'Label','Rotate');
if strcmpi(get(H.rotate3d,'Enable'),'on')
    set(h,'Checked','on');
else
    set(h,'Checked','off');
end

h = findobj(obj,'Label','Slider');
d = getappdata(H.patch,'data');
if isempty(d) || ~any(d(:)), set(h,'Enable','off'); else set(h,'Enable','on'); end

if isfield(H,'slider')
    if ishandle(H.slider)
        set(h,'Checked','on');
    else
        H = rmfield(H,'slider');
        set(h,'Checked','off');
    end
else
    set(h,'Checked','off');
end

if numel(findobj('Tag','CATSurfRender','Type','Patch')) > 1
    h = findobj(obj,'Tag','SynchroMenu');
    set(h,'Visible','on');
end

h  = findobj(obj,'Label','Colorbar');
hx = findobj(obj,'Label','Colormap');
hr = findobj(obj,'Label','Colorrange');
d = getappdata(H.patch,'data');
if isempty(d) || ~any(d(:)), 
  set(h ,'Enable','off'); 
  set(hx,'Enable','off'); 
  set(hr,'Enable','off'); 
else
  set(h ,'Enable','on');
  set(hx,'Enable','on');
  set(hr,'Enable','on');
end
if isfield(H,'labelmap')
  set(hx,'Enable','off'); 
  set(hr,'Enable','off'); 
end

if isfield(H,'colourbar')
    if ishandle(H.colourbar)
        set(h,'Checked','on');
    else
        H = rmfield(H,'colourbar');
        set(h,'Checked','off');
    end
else
    set(h,'Checked','off');
end
setappdata(H.axis,'handles',H);

%==========================================================================
function myPostCallback(obj,evt,H)
P = findobj('Tag','CATSurfRender','Type','Patch');
if numel(P) == 1
  if strcmp(H.light(1).Visible,'on'), camlight(H.light(1),'headlight','infinite'); end
else
    for i=1:numel(P)
        H = getappdata(ancestor(P(i),'axes'),'handles');
        if strcmp(H.light(1).Visible,'on'), camlight(H.light(1),'headlight','infinite'); end
    end
end
axis vis3d;

%==========================================================================
function mySurfcolor(obj,evt,H,val)
  c  = get(get(obj,'parent'),'children'); 
  cb = get(c,'callback'); 
  for cbi=1:numel(cb), if strcmp(char(cb{cbi}{1}),'mySurfcolor'), set(c(cbi),'Checked','off'); end; end
  set(obj,'Checked','on');
  d = getappdata(H.patch(1),'data');
  setappdata(H.axis,'handles',H);
  H.surfbrightness = val;
  updateTexture(H,d);
  
%==========================================================================
function myCross(obj,evt,H,action,val)
  hs = findobj(H.axis,'Marker','+'); 
  if isempty(hs), return; end
  pobj = get(obj,'parent'); 
  switch action
    case 'setsize'
      if val>0
        set(hs,'MarkerSize',val,'Visible','on'); 
      else
        set(hs,'MarkerSize',1,'Visible','off'); 
      end
      labs = {'off','small','medium','large'}; 
  
    case 'setcolor'
      if isempty(val)
        val = uisetcolor(H.axis, ...
          'Pick a crossbar color...');
        if numel(val) == 1, return; end
      end
      set(hs,'Color',val)
      labs = {'red','blue','white','black','Custom...'}; 
  end

  for li = 1:numel(labs)
    set(findobj(pobj,'Label',labs{li}),'Checked','off');
  end
  set(obj,'Checked','on');
  
%==========================================================================
function varargout = myCrossBar(varargin)

switch lower(varargin{1})

    case 'create'
    %----------------------------------------------------------------------
    % hMe = myCrossBar('Create',H,xyz)
    H  = varargin{2};
    xyz = varargin{3};
    hold(H.axis,'on');
    hs = plot3(xyz(1),xyz(2),xyz(3),'Marker','+','MarkerSize',100,'LineWidth',2,...
        'parent',H.axis,'Color',[1 0 0],'Tag','CrossBar','ButtonDownFcn',{});
    varargout = {hs};
    
    case 'setcoords'
    %----------------------------------------------------------------------
    % [xyz,d] = myCrossBar('SetCoords',xyz,hMe)
    hMe  = varargin{3};
    xyz  = varargin{2};
    set(hMe,'XData',xyz(1));
    set(hMe,'YData',xyz(2));
    set(hMe,'ZData',xyz(3));
    varargout = {xyz,[]};
    
    case 'setvertex'
    %----------------------------------------------------------------------
    % [xyz,d] = myCrossBar('SetCoords',xyz,hMe)
    hMe  = varargin{3};
    id   = varargin{2};
    set(hMe,'XData',id);
    varargout = {id,[]};
    
    otherwise
    %----------------------------------------------------------------------
    error('Unknown action string')

end
%cat_spm_results_ui('spm_list_cleanup'); % does not work?
    

%==========================================================================
function myInflate(obj,evt,H)
spm_mesh_inflate(H.patch,Inf,1);
axis(H.axis,'image');

%==========================================================================
function myCCLabel(obj,evt,H)
C   = getappdata(H.patch,'cclabel');
F   = get(H.patch,'Faces');
ind = sscanf(get(obj,'Label'),'Component %d');
V   = get(H.patch,'FaceVertexAlphaData');
Fa  = get(H.patch,'FaceAlpha');
if ~isnumeric(Fa)
    if ~isempty(V), Fa = max(V); else Fa = 1; end
    if Fa == 0, Fa = 1; end
end
if isempty(V) || numel(V) == 1
    Ve = get(H.patch,'Vertices');
    if isempty(V) || V == 1
        V = Fa * ones(size(Ve,1),1);
    else
        V = zeros(size(Ve,1),1);
    end
end
if strcmpi(get(obj,'Checked'),'on')
    V(reshape(F(C==ind,:),[],1)) = 0;
    set(obj,'Checked','off');
else
    V(reshape(F(C==ind,:),[],1)) = Fa;
    set(obj,'Checked','on');
end
set(H.patch, 'FaceVertexAlphaData', V);
if all(V)
    % ensure that Fa is between 0..1
    Fa = min([1.0 Fa]);
    Fa = max([0.0 Fa]);
    set(H.patch, 'FaceAlpha', Fa);
else
    set(H.patch, 'FaceAlpha', 'interp');
end

%==========================================================================
function myTransparency(obj,evt,H,varargin)
if ~isempty(varargin)
  
  t = 1 - sscanf(varargin{1},'%d%%') / 100;
else
  t = 1 - sscanf(get(obj,'Label'),'%d%%') / 100;
end
%%
curv = getappdata(H.patch,'curvature');
col  = getappdata(H.patch,'colourmap');
v    = get( H.patch, 'UserData'); 
%%
C    = zeros(size(v,2),1);
clim = getappdata(H.patch, 'clim');
if isempty(clim), clim = [false nan nan]; end
mi   = clim(2); ma = clim(3);

if size(col,1)>3 && size(col,1) ~= size(v,1)
    if size(v,1) == 1
        if ~clim(1), mi = min(v(:)); ma = max(v(:)); end
        C = floor(((v(:)-mi)/(ma-mi))*size(col,1));
    elseif isequal(size(v),[size(curv,1) 3])
        C = v; v = v';
    else
        if ~clim(1), mi = min(v(:)); ma = max(v(:)); end
        for i=1:size(v,1)
            C = C + floor(((v(i,:)-mi)/(ma-mi))*size(col,1));
        end
    end
else
    if ~clim(1), ma = max(v(:)); end
    for i=1:size(v,1)
        C = C + v(i,:)'/ma * col(i,:);
    end
end
%%
if any(isnan(clim))
  set(H.patch,'FaceVertexAlphaData',t + (1-t) * zeros(size(C))/255);
else
  set(H.patch,'FaceVertexAlphaData',t + (1-t) * C/255);
end
set(H.patch,'FaceAlpha','interp'); 
set(H.patch,'AlphaDataMapping','scaled');
alim([0 1]);
set(get(get(obj,'parent'),'children'),'Checked','off');
set(obj,'Checked','on');

%==========================================================================
function mySwitchRotate(obj,evt,H)
if strcmpi(get(H.rotate3d,'enable'),'on')
    rotate3d(H.axis,'off');
    set(obj,'Checked','off');
else
    rotate3d(H.axis,'on');
    set(obj,'Checked','on');
    
    % fine red lines of the SPM result table
%{
    hRes.Fgraph       = spm_figure('FindWin','Graphics');
     
    hRes.Fline        = findobj(hRes.Fgraph,'Type','Line','Tag','');
    hRes.FlineAx      = get(hRes.Fline,'parent');

    set(hRes.Fline,'HitTest','off');
    for axi = 1:numel( hRes.FlineAx ), rotate3d(hRes.FlineAx{axi},'off'); end
    %}
end

%==========================================================================
function myView(obj,evt,H,varargin)
view(H.axis,varargin{1});
axis(H.axis,'image');
if strcmp(H.catLighting,'cam') && ~isempty(H.light), camlight(H.light(1),'headlight','infinite'); end

%==========================================================================
function myColourbar(obj,evt,H)
y = {'on','off'}; toggle = @(x) y{1+strcmpi(x,'on')}; 
cat_surf_render('Colourbar',H,toggle(get(obj,'Checked')));
set(obj,'Checked',toggle(get(obj,'Checked')));



%==========================================================================
function myLighting(obj,evt,H,newcatLighting)
y = {'on','off'}; toggle = @(x) y{1+strcmpi(x,'on')};
% set old lights
H.catLighting = newcatLighting;
delete(findall(H.axis,'Type','light','Tag',''));                    % remove old infinite lights
delete(findall(H.axis,'Type','light','Tag','centerlight'));     
caml = findall(H.axis,'Type','light','Tag','camlight');   % switch off camlight
    
% new lights
lighting gouraud
set(caml,'visible','off');
set(H.patch,'BackFaceLighting','reverselit');
set(H.patch,'LineStyle','-','EdgeColor','none');
switch H.catLighting
  case 'none'
  case 'inner'
    H.light(2) = light('Position',[0 0 0]); 
    ks = get(H.patch,'SpecularStrength'); set(H.patch,'SpecularStrength',min(0.1,ks));
    n  = get(H.patch,'SpecularExponent'); set(H.patch,'SpecularExponent',max(2,n)); 
    set(H.patch,'BackFaceLighting','unlit');
  case 'top'
    H.light(2) = light('Position',[ 0  0  1],'Color',repmat(1,1,3));    %#ok<*REPMAT>
  case 'bottom'
    H.light(2) = light('Position',[ 0  0 -1],'Color',repmat(1,1,3));   
  case 'left'
    H.light(2) = light('Position',[-1  0  0],'Color',repmat(1,1,3));   
  case 'right'
    H.light(2) = light('Position',[ 1  0  0],'Color',repmat(1,1,3));   
  case 'front'
    H.light(2) = light('Position',[ 0  1  0],'Color',repmat(1,1,3));   
  case 'back'
    H.light(2) = light('Position',[ 0 -1  0],'Color',repmat(1,1,3));   
  case 'set1'
    H.light(2) = light('Position',[ 1  0  .5],'Color',repmat(0.8,1,3)); 
    H.light(3) = light('Position',[-1  0  .5],'Color',repmat(0.8,1,3)); 
    H.light(4) = light('Position',[ 0  1 -.5],'Color',repmat(0.2,1,3));
    H.light(5) = light('Position',[ 0 -1 -.5],'Color',repmat(0.2,1,3)); 
  case 'set2'
    H.light(2) = light('Position',[ 1  0  1],'Color',repmat(0.7,1,3)); 
    H.light(3) = light('Position',[-1  0  1],'Color',repmat(0.7,1,3)); 
    H.light(4) = light('Position',[ 0  1  .5],'Color',repmat(0.3,1,3));
    H.light(5) = light('Position',[ 0 -1  .5],'Color',repmat(0.3,1,3)); 
    H.light(5) = light('Position',[ 0  0 -1],'Color',repmat(0.2,1,3)); 
  case 'set3'
    H.light(2) = light('Position',[ 1  0  0],'Color',repmat(0.8,1,3)); 
    H.light(3) = light('Position',[-1  0  0],'Color',repmat(0.8,1,3)); 
    H.light(4) = light('Position',[ 0  1  1],'Color',repmat(0.2,1,3));
    H.light(5) = light('Position',[ 0 -1  1],'Color',repmat(0.2,1,3)); 
    H.light(6) = light('Position',[ 0  0 -1],'Color',repmat(0.1,1,3));   
  case 'grid'
    set(H.patch,'LineStyle','-','EdgeColor',[0 0 0]);
    set(H.patch,'AmbientStrength',0.7,'DiffuseStrength',0.1,'SpecularStrength',0.6,'SpecularExponent',10);
  case 'cam'
    camlight(H.light(1),'headlight','infinite');
    set(caml,'visible','on');
end
set(get(get(obj,'parent'),'children'),'Checked','off');
set(obj,'Checked','on');

%==========================================================================
function myMaterial(obj,evt,H,mat)
y = {'on','off'}; toggle = @(x) y{1+strcmpi(x,'on')};
set(H.patch,'LineStyle','none');
if ischar(mat)
  switch mat
    case 'shiny'
      material shiny;
    case 'dull'
      material dull;
    case 'metal'
      material metal;
    case 'grid'
      set(H.patch,'LineStyle','-','EdgeColor',[0 0 0]);
      set(H.patch,'AmbientStrength',0.7,'DiffuseStrength',0.1,'SpecularStrength',0.6,'SpecularExponent',10);
    case 'greasy'
      set(H.patch,'AmbientStrength',0.2,'DiffuseStrength',0.5,'SpecularStrength',0.3,'SpecularExponent',0.6);
    case 'plastic'
      set(H.patch,'AmbientStrength',0.1,'DiffuseStrength',0.6,'SpecularStrength',0.3,'SpecularExponent',2);
    case 'metal'
      set(H.patch,'AmbientStrength',0.4,'DiffuseStrength',0.9,'SpecularStrength',0.1,'SpecularExponent',1);
    case 'default'
      set(H.patch,'AmbientStrength',0.4,'DiffuseStrength',0.6,'SpecularStrength',0.0,'SpecularExponent',10);
    case 'custom' 
      spm_figure('getwin','Interactive'); 
      % actual values
      ka = get(H.patch,'AmbientStrength');
      kd = get(H.patch,'DiffuseStrength');
      ks = get(H.patch,'SpecularStrength');
      n  = get(H.patch,'SpecularExponent'); 
      % new values
      ka = spm_input('AmbientStrength',1,'r',ka,[1,1]);
      kd = spm_input('DiffuseStrength',2,'r',kd,[1,1]);
      ks = spm_input('SpecularStrength',3','r',ks,[1,1]);
      n  = spm_input('SpecularExponent',4,'r',n,[1,1]);
      set(H.patch,'AmbientStrength',ka,'DiffuseStrength',kd,'SpecularStrength',ks,'SpecularExponent',n);
  end
else
  set(H.patch,'AmbientStrength',mat(1),'DiffuseStrength',mat(2),'SpecularStrength',mat(3),'SpecularExponent',mat(4));
end
c  = get(get(obj,'parent'),'children'); 
cb = get(c,'callback'); 
for cbi=1:numel(cb), if strcmp(char(cb{cbi}{1}),'myMaterial'), set(c(cbi),'Checked','off'); end; end
set(obj,'Checked','on');



%==========================================================================
function myCaxis(obj,evt,H,rangetype)
d = getappdata(H.patch,'data');
if cat_stat_nanmean(d(:))>0 && cat_stat_nanstd(d(:),1)>0
  switch rangetype
      case 'min-max', 
          range = [min(d) max(d)]; 
      case '2p'
          range = cat_vol_iscaling(d,[0.02 0.98]);
      case '5p'
          range = cat_vol_iscaling(d,[0.05 0.95]);
      case 'custom'
          fc = gcf;
          spm_figure('getwin','Interactive'); 
          range = cat_vol_iscaling(d,[0.02 0.98]);
          d = spm_input('intensity range','1','r',range,[2,1]);
          figure(fc); 
          range = [min(d) max(d)];
      case 'customp'
          fc = gcf;
          spm_figure('getwin','Interactive'); 
          dx= spm_input('percentual intensity range','1','r',[2 98],[2,1]);
          range = cat_vol_iscaling(d,dx/100);
          figure(fc); 
      otherwise
          range = [min(d) max(d)]; 
  end
  if range(1)==range(2), range = range + [-eps eps]; end
  if range(1)>range(2), range = fliplr(range); end
  cat_surf_render('Clim',H,range);
end
set(get(get(obj,'parent'),'children'),'Checked','off');
set(obj,'Checked','on');

%==========================================================================
function mySynchroniseCaxis(obj,evt,H)
P = findobj('Tag','CATSurfRender','Type','Patch');
range = getappdata(H.patch, 'clim');
range = range(2:3);

for i=1:numel(P)
    H = getappdata(ancestor(P(i),'axes'),'handles');
    cat_surf_render('Clim',H,range);
end

%==========================================================================
function myColourmap(obj,evt,H,varargin)
dx = get(H.patch,'UserData'); dx = [min(dx) min(dx(dx~=0)) max(dx)]; 
if ~isempty(varargin)
  switch varargin{1}
    case 'color'
      c = uisetcolor(H.figure,'Pick a surface color...');
    case 'colormap'
      c=feval(varargin{2},256);
    otherwise
      c = feval(get(obj,'Label'),256); 
  end
else
  switch get(obj,'Label')
    case {'CAThot','CAThotinv','CATcold','CATcoldinv'}
      catcm = get(obj,'Label'); catcm(1:3) = []; 
      c=cat_io_colormaps(catcm,256);
    case 'CATtissues'
      c=cat_io_colormaps('BCGWHw',256);
    case 'CATcold&hot'
      c=cat_io_colormaps('BWR',256); 
    otherwise 
      c = feval(get(obj,'Label'),256); 
  end
end
if ~isempty(dx), c(1:round(size(c,1) * dx(2)/dx(3)),:) = 0.5; end
cat_surf_render('Colourmap',H,c);
set(get(get(obj,'parent'),'children'),'Checked','off');
%if isfield(H,'colourbar'),H=cat_surf_render('Clim',H,H.colourbar.Limits); end
set(obj,'Checked','on');

%==========================================================================
function myAddslider(obj,evt,H)
y = {'on','off'}; toggle = @(x) y{1+strcmpi(x,'on')};
cat_surf_render('Slider',H,toggle(get(obj,'Checked')));

%==========================================================================
function mySynchroniseViews(obj,evt,H)
P = findobj('Tag','CATSurfRender','Type','Patch');
v = get(H.axis,'cameraposition');
for i=1:numel(P)
    H = getappdata(ancestor(P(i),'axes'),'handles');
    set(H.axis,'cameraposition',v);
    axis(H.axis,'image');
    if strcmp(H.catLighting,'cam') && ~isempty(H.light), camlight(H.light(1),'headlight','infinite'); end
end

%==========================================================================
function myDataCursor(obj,evt,H)
dcm_obj = datacursormode(H.figure);
set(dcm_obj, 'Enable','on', 'SnapToDataVertex','on', ...
    'DisplayStyle','datatip', 'Updatefcn',{@myDataCursorUpdate, H}); %Window

%==========================================================================
function txt = myDataCursorUpdate(obj,evt,H)
set(findobj(obj),'String',{''});
pos = get(evt,'Position');
txt = {['X: ',num2str(pos(1))],...
       ['Y: ',num2str(pos(2))],...
       ['Z: ',num2str(pos(3))]};
i = ismember(get(H.patch,'vertices'),pos,'rows');
if isfield(H,'results') && H.results && isfield(H,'satlases') 
  txt{1} = sprintf('Node: %d (%0.0f %0.0f %0.0f mm)',find(i),pos);
  for ai = 1:numel(H.satlases)
    txt{1 + ai} =  sprintf('%s: %s', H.satlases(ai).names{1}, ...
      H.satlases(ai).rnames.struct_names{  H.satlases(ai).adata(i) == H.satlases(ai).rnames.table(:,5) } ); 
  end
else
  txt = {['Node: ' num2str(find(i))] txt{:}};  
end
d = getappdata(H.patch,'data');
if ~isempty(d) && any(d(:))
    if any(i), txt = {txt{:} ['T: ',num2str(d(i))]}; end
end
set(findobj(obj),'String',txt);


hMe = findobj(H.axis,'Tag','CrossBar');
if ~isempty(hMe)
    %ws = warning('off');
    myCrossBar('SetCoords',pos,hMe);
    %spm_XYZreg('SetCoords',pos,get(hMe,'UserData')); 
    
    spm_orthviews('Reposition',pos)
    %warning(ws);
end
try
  cat_spm_results_ui('spm_list_cleanup');
end

%==========================================================================
function myBackgroundColor(obj,evt,H,varargin)
    % get color
    if isempty(varargin{1})
        c = uisetcolor(H.figure, ...
            'Pick a background color...');
        if numel(c) == 1, return; end
    else
        c = varargin{1};
    end
    
    % get the main figure and the possible satelite
    h = findobj(H.figure,'Tag','SPMMeshRenderBackground');
    if isempty(h), h = H.figure; end
    h = [h,spm_figure('FindWin','Satellite')];
    
    % find color objects that should not be inverted
    % ... we started with red and maybe add more later
    reds = findobj(h,'Color',[1 0 0]);

    
    % set new color and invert other objects (e.g., fonts and lines)
    set(h,'Color',c); 
    whitebg(h,c);
    set(h,'Color',c);

    % reset red objects
    set(reds,'Color',[1 0 0]);
    
    set(get(get(obj,'parent'),'children'),'Checked','off'); % deactivate all 
    set(obj,'Checked','on');
    cat_spm_results_ui('spm_list_cleanup');

%==========================================================================
function mySavePNG(obj,evt,H,filename)
  %%
  if ~exist('filename','var')
    filename = uiputfile({...
      '*.png' 'PNG files (*.png)'}, 'Save as');
  else
    [pth,nam,ext] = fileparts(filename);
    if isempty(pth), pth = cd; end
    if ~strcmp({'.gii','.png'},ext), nam = [nam ext]; end
    if isempty(nam)
      filename = uiputfile({...
        '*.png' 'PNG files (*.png)'}, 'Save as',nam);
    else
      filename = fullfile(pth,[nam '.png']);
    end
  end
  
  u  = get(H.axis,'units');
  set(H.axis,'units','pixels');
  p  = get(H.figure,'Position');
  r  = get(H.figure,'Renderer');
  hc = findobj(H.figure,'Tag','SPMMeshRenderBackground');
  if isempty(hc)
      c = get(H.figure,'Color');
  else
      c = get(hc,'Color');
  end
  h = figure('Position',p+[0 0 0 0], ...
                  'InvertHardcopy','off', ...
                  'Color',c, ...
                  'Renderer',r);
  copyobj(H.axis,h);
  copyobj(H.axis,h);
  set(H.axis,'units',u);
  set(get(h,'children'),'visible','off');
  colorbar('Position',[.93 0.2 0.02 0.6]);
  try
    colormap(H.axis,getappdata(H.patch,'colourmap'));
  catch
    colormap(getappdata(H.patch,'colourmap'));
  end
  [pp,ff,ee] = fileparts(H.filename{1}); 
  %H.text = annotation('textbox','string',[ff ee],'position',[0.0,0.97,0.2,0.03],'LineStyle','none','Interpreter','none');    
  %a = get(h,'children');
  %set(a,'Position',get(a,'Position').*[0 0 1 1]+[10 10 0 0]);       
  if isdeployed
      deployprint(h, '-dpng', '-opengl', fullfile(pth, filename));
  else
      print(h, '-dpng', '-opengl', fullfile(pth, filename));
  end
  close(h);
  set(getappdata(obj,'fig'),'renderer',r);

%==========================================================================
function mySave(obj,evt,H,filename)
  if ~exist('filename','var')
    [filename, pathname, filterindex] = uiputfile({...
      '*.png' 'PNG files (*.png)';...
      '*.gii' 'GIfTI files (*.gii)'; ...
      '*.dae' 'Collada files (*.dae)';...
      '*.idtf' 'IDTF files (*.idtf)'}, 'Save as');
  else
    [pth,nam,ext] = fileparts(filename);
    if ~strcmp({'.gii','.png'},ext), nam = [nam ext]; end
    [filename, pathname, filterindex] = uiputfile({...
      '*.png' 'PNG files (*.png)';...
      '*.gii' 'GIfTI files (*.gii)'; ...
      '*.dae' 'Collada files (*.dae)';...
      '*.idtf' 'IDTF files (*.idtf)'}, 'Save as',nam);
  end

if ~isequal(filename,0) && ~isequal(pathname,0)
    [pth,nam,ext] = fileparts(filename);
    switch ext
        case '.gii'
            filterindex = 1;
        case '.png'
            filterindex = 2;
        case '.dae'
            filterindex = 3;
        case '.idtf'
            filterindex = 4;
        otherwise
            switch filterindex
                case 1
                    filename = [filename '.gii'];
                case 2
                    filename = [filename '.png'];
                case 3
                    filename = [filename '.dae'];
            end
    end
    switch filterindex
        case 1
            G = gifti(H.patch);
            [p,n,e] = fileparts(filename);
            [p,n,e] = fileparts(n);
            switch lower(e)
                case '.func'
                    save(gifti(getappdata(H.patch,'data')),...
                        fullfile(pathname, filename));
                case '.surf'
                    save(gifti(struct('vertices',G.vertices,'faces',G.faces)),...
                        fullfile(pathname, filename));
                case '.rgba'
                    save(gifti(G.cdata),fullfile(pathname, filename));
                otherwise
                    save(G,fullfile(pathname, filename));
            end
        case 2
            u  = get(H.axis,'units');
            set(H.axis,'units','pixels');
            p  = get(H.figure,'Position'); % axis
            r  = get(H.figure,'Renderer');
            hc = findobj(H.figure,'Tag','SPMMeshRenderBackground');
            if isempty(hc)
                c = get(H.figure,'Color');
            else
                c = get(hc,'Color');
            end
            h = figure('Position',p+[0 0 0 0], ... [0 0 10 10]
                'InvertHardcopy','off', ...
                'Color',c, ...
                'Renderer',r);
            copyobj(H.axis,h);
            set(H.axis,'units',u);
            set(get(h,'children'),'visible','off');
            colorbar('Position',[.93 0.2 0.02 0.6]); 
            try
              colormap(H.axis,getappdata(H.patch,'colourmap'));
            catch
              colormap(getappdata(H.patch,'colourmap'));
            end
            [pp,ff,ee] = fileparts(H.filename{1}); 
            %H.text = annotation('textbox','string',[ff ee],'position',[0.0,0.97,0.2,0.03],'LineStyle','none','Interpreter','none');
            %a = get(h,'children');
            %set(a,'Position',get(a,'Position').*[0 0 1 1]+[10 10 0 0]);       
            if isdeployed
                deployprint(h, '-dpng', '-opengl', fullfile(pathname, filename));
            else
                print(h, '-dpng', '-opengl', fullfile(pathname, filename));
            end
            close(h);
            set(getappdata(obj,'fig'),'renderer',r);
        case 3
            save(gifti(H.patch),fullfile(pathname, filename),'collada');
        case 4
            save(gifti(H.patch),fullfile(pathname, filename),'idtf');
    end
end

%==========================================================================
function myDeleteFcn(obj,evt,renderer)
try rotate3d(get(obj,'parent'),'off'); end 
set(ancestor(obj,'figure'),'Renderer',renderer);

%==========================================================================
function myOverlay(obj,evt,H)
[P, sts] = spm_select(1,'any','Select file to overlay');
if ~sts, return; end
cat_surf_render('Overlay',H,P);

%==========================================================================
function myUnderlay(obj,evt,H)
[P, sts] = spm_select(1,'any','Select texture file to underlay',{},fullfile(fileparts(mfilename('fullpath')),'templates_surfaces'),'[lr]h.mc.*');
if ~sts, return; end
cat_surf_render('Underlay',H,P);

%==========================================================================
function myImageSections(obj,evt,H)
[P, sts] = spm_select(1,'image','Select image to render');
if ~sts, return; end
renderSlices(H,P);

%==========================================================================
function myChangeGeometry(obj,evt,H)
[P, sts] = spm_select(1,'mesh','Select new geometry mesh');
if ~sts, return; end
G = gifti(P);

if size(get(H.patch,'Vertices'),1) ~= size(G.vertices,1)
    error('Number of vertices must match.');
end
set(H.patch,'Vertices',G.vertices)
set(H.patch,'Faces',G.faces)
view(H.axis,[-90 0]);

pmenu  = findobj( 'Label', 'Meshes' );
meshs  = {'Average','Inflated','Shooting','Custom Mesh...'};
for mi = 1:numel(meshs), set( findobj( pmenu, 'Label',meshs{mi}) ,'Checked','off'); end
set(obj,'Checked','on');


%==========================================================================
function renderSlices(H,P,pls)
if nargin <3
    pls = 0.05:0.2:0.9;
end
N   = nifti(P);
d   = size(N.dat);
pls = round(pls.*d(3));
hold(H.axis,'on');
for i=1:numel(pls)
    [x,y,z] = ndgrid(1:d(1),1:d(2),pls(i));
    f  = N.dat(:,:,pls(i));
    x1 = N.mat(1,1)*x + N.mat(1,2)*y + N.mat(1,3)*z + N.mat(1,4);
    y1 = N.mat(2,1)*x + N.mat(2,2)*y + N.mat(2,3)*z + N.mat(2,4);
    z1 = N.mat(3,1)*x + N.mat(3,2)*y + N.mat(3,3)*z + N.mat(3,4);
    surf(x1,y1,z1, repmat(f,[1 1 3]), 'EdgeColor','none', ...
        'Clipping','off', 'Parent',H.axis);
end
hold(H.axis,'off');
axis(H.axis,'image');

%==========================================================================
function C = updateTexture(H,v,col)%$,FaceColor)

%-Get colourmap
%--------------------------------------------------------------------------
if ~exist('col','var'), col = getappdata(H.patch,'colourmap'); end
if isempty(col), col = hot(256); end
if ~exist('FaceColor','var'), FaceColor = 'interp'; end
setappdata(H.patch,'colourmap',col);

%-Get curvature
%--------------------------------------------------------------------------
curv = getappdata(H.patch,'curvature');

if size(curv,2) == 1
  if 0
    th = 0.15;
    curv((curv<-th)) = -th;
    curv((curv>th))  =  th;
    curv = 0.5 * (curv + th)/(2*th);
    curv = 0.5 + repmat(curv,1,3);
  else
    th = 0.30;
    curv((curv<-th)) = -th;
    curv((curv>th))  =  th;
    curv = 0.5 * (curv + th)/(2*th);
    curv = 0.1 + 1.0 * repmat(curv,1,3);
    %curv = 0.5 * repmat(curv,1,3) + 0.3 * repmat(~curv,1,3);
    %curv = 0.5 * repmat(curv,1,3) + 0.3 * repmat(~curv,1,3);
  end
end
 
%-Project data onto surface mesh
%--------------------------------------------------------------------------
if nargin < 2, v = []; end
if ischar(v)
    [p,n,e] = fileparts(v);
    if ~strcmp(e,'.mat') && ~strcmp(e,'.nii') && ~strcmp(e,'.gii') && ~strcmp(e,'.img') % freesurfer format
      v = cat_io_FreeSurfer('read_surf_data',v);
    else
      if strcmp([n e],'SPM.mat')
        swd = pwd;
        spm_figure('GetWin','Interactive');
        [SPM,v] = spm_getSPM(struct('swd',p));
        cd(swd);
      else
        try spm_vol(v); catch, v = gifti(v); end;
      end
    end
end
if isa(v,'gifti'), v = v.cdata; end
if isa(v,'file_array'), v = v(); end

set(H.patch,'UserData',v);

if isempty(v)
    v = zeros(size(curv))';
elseif ischar(v) || iscellstr(v) || isstruct(v)
    v = spm_mesh_project(H.patch,v);
elseif isnumeric(v) || islogical(v)
    if size(v,2) == 1
        v = v';
    end
else
    error('Unknown data type.');
end
v(isinf(v)) = NaN;

setappdata(H.patch,'data',v);

%-Create RGB representation of data according to colourmap
%--------------------------------------------------------------------------
C = zeros(size(v,2),3);
clim = getappdata(H.patch, 'clim');
if isempty(clim), clim = [false NaN NaN]; end
mi = clim(2); ma = clim(3);
if any(v(:))
    if size(col,1)>3 && size(col,1) ~= size(v,1)
        if size(v,1) == 1
            if ~clim(1), mi = min(v(:)); ma = max(v(:)); end
            C = squeeze(ind2rgb(floor(((v(:)-mi)/(ma-mi))*size(col,1)),col));
        elseif isequal(size(v),[size(curv,1) 3])
            C = v; v = v';
        else
            if ~clim(1), mi = min(v(:)); ma = max(v(:)); end
            for i=1:size(v,1)
                C = C + squeeze(ind2rgb(floor(((v(i,:)-mi)/(ma-mi))*size(col,1)),col));
            end
        end
    else
        if ~clim(1), ma = max(v(:)); end
        for i=1:size(v,1)
            C = C + v(i,:)'/ma * col(i,:);
        end
    end
end

clip = getappdata(H.patch, 'clip');
if ~isempty(clip)
    v(v>clip(2) & v<clip(3)) = NaN;
    setappdata(H.patch, 'clip', [true clip(2) clip(3)]);
end

setappdata(H.patch, 'clim', [false mi ma]);

%-Build texture by merging curvature and data
%--------------------------------------------------------------------------
if size(curv,1) == 1
  curv = repmat(curv,3,1)';
end

if size(C,1) ~= size(curv,1)
  error('Colordata does not fit to underlying mesh.');
end

%C = repmat(~any(v,1),3,1)' .* curv + repmat(any(v,1),3,1)' .* C;
ttrans = findobj(H.figure,'Label','TextureTransparency');
ctrans = ~isempty(ttrans) && strcmp(ttrans.Checked,'on'); 

if ~isfield(H,'surfbrightness'), 
  scmenu = get( findobj(H.figure,'Label','Mesh Texture'),'Children');   
  c  = findobj( scmenu ,'Checked', 'on'); 
  cb = get( findobj( c ,'Checked', 'on') , 'Callback' ); 
  for cbi=1:numel(cb), if strcmp(char(cb{cbi}{1}),'mySurfcolor'), H.surfbrightness = cb{cbi}{3}; end; end
  if ~isfield(H,'surfbrightness') || isempty(H.surfbrightness)
    H.surfbrightness = 0.5; 
  end
end
C = repmat(~any(v,1),3,1)' .* (curv + H.surfbrightness/2) + ...
    (repmat(any(v,1),3,1)' .* C .* ((1-ctrans) + (0.7 + curv).*ctrans)); 

set(H.patch, 'FaceVertexCData',C, 'FaceColor',FaceColor);

%-Update the colourbar
%--------------------------------------------------------------------------
if isfield(H,'colourbar')
    cat_surf_render('Colourbar',H);
end

%==========================================================================
function slider_clim_min(hObject, evt)

val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true val c(3)]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end

%==========================================================================
function slider_clim_max(hObject, evt)

val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true c(2) val]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end

%==========================================================================
function slider_clip_min(hObject, evt)

val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clip');
setappdata(H.patch,'clip',[true val c(3)]);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true c(2) c(3)]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end


%==========================================================================
function slider_clip_max(hObject, evt) 
val = get(hObject, 'Value');
H = getHandles(gcf);
c = getappdata(H.patch,'clip');
setappdata(H.patch,'clip',[true c(2) val]);
c = getappdata(H.patch,'clim');
setappdata(H.patch,'clim',[true c(2) c(3)]);
d = getappdata(H.patch,'data');
updateTexture(H,d);
H2 = getHandles(gca);
if isfield(H2,'colourbar') && ishandle(H2.colourbar)
  cat_surf_render('ColourBar',gca, 'on');
end
