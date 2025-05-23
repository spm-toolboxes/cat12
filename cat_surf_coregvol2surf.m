% Nonlinear coregistration batch
% ______________________________________________________________________
%
% Christian Gaser, Robert Dahnke
% Structural Brain Mapping Group (https://neuro-jena.github.io)
% Departments of Neurology and Psychiatry
% Jena University Hospital
% ______________________________________________________________________
% Job saved on 29-Nov-2017 20:46:02 by cfg_util (rev $Rev$)
% spm SPM - SPM12 (7219)
% cfg_basicio BasicIO - Unknown
%-----------------------------------------------------------------------
matlabbatch{1}.spm.tools.cat.tools.nonlin_coreg.ref = '<UNDEFINED>';
matlabbatch{1}.spm.tools.cat.tools.nonlin_coreg.source = '<UNDEFINED>';
matlabbatch{1}.spm.tools.cat.tools.nonlin_coreg.other = '<UNDEFINED>';
matlabbatch{1}.spm.tools.cat.tools.nonlin_coreg.reg = 1;
matlabbatch{1}.spm.tools.cat.tools.nonlin_coreg.bb = [NaN NaN NaN
                                                      NaN NaN NaN];
matlabbatch{1}.spm.tools.cat.tools.nonlin_coreg.vox = [2 2 2];
matlabbatch{2}.spm.tools.cat.stools.vol2surf.data_vol(1) = cfg_dep('Non-linear co-registration: Non-linear coregistered data', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','ofiles'));
matlabbatch{2}.spm.tools.cat.stools.vol2surf.data_mesh_lh = '<UNDEFINED>';
matlabbatch{2}.spm.tools.cat.stools.vol2surf.sample = {'maxabs'};
matlabbatch{2}.spm.tools.cat.stools.vol2surf.datafieldname = 'maxabs';
matlabbatch{2}.spm.tools.cat.stools.vol2surf.mapping.rel_equivol_mapping.class = 'GM';
matlabbatch{2}.spm.tools.cat.stools.vol2surf.mapping.rel_equivol_mapping.startpoint = -0.6;
matlabbatch{2}.spm.tools.cat.stools.vol2surf.mapping.rel_equivol_mapping.steps = 7;
matlabbatch{2}.spm.tools.cat.stools.vol2surf.mapping.rel_equivol_mapping.endpoint = 0.6;