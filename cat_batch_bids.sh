#! /bin/bash
# Wrapper to call either CAT12 standard or longitudinal pipeline from shell for BIDS data
# Parallelization should be either done using standalone/cat_parallize.sh or any
# batch or queue system
# ______________________________________________________________________
#
# Christian Gaser, Robert Dahnke
# Structural Brain Mapping Group (https://neuro-jena.github.io)
# Departments of Neurology and Psychiatry
# Jena University Hospital
# ______________________________________________________________________
# $Id$
#
# all bids-folder have to be structured like this:
# sub-*/ses-*/anat/sub-*T1w.nii*

if [ "$1" = "" ]; then
  echo usage:  $0 bids_directories
  exit
fi

cat12_dir=$cwd
matlab=matlab # you can use other matlab versions by changing the matlab parameter
default="cat_defaults_bids.m" # define own defaults file here
model=2     # 0 - detect large changes with brain/head growth (i.e. developmental effects)
            # 1 - detect small changes (i.e. due to plasticity)
            # 2 - detect large changes (i.e. ageing or development)
            # 3 - save results for both models 1 and 2

#no_surf=" --no-surf " # remove comment if you don't want to estimate surface
export_dartel=" --export-dartel " # export affine registered segmentations for Dartel (longitudinal data)
rp=" --rp " # additionally estimate affine registered segmentations (cross-sectional data)
bids_folder_cross="../derivatives/CAT12.8.1"     # define BIDS path for cross-sectional data
bids_folder_long="../derivatives/CAT12.8.1_long" # define BIDS path for longitudinal data
fg=" --fg " # keep process in foreground which might be neccessary for batch/queue systems

for i in ${@}/; do
  count=0 # count files
  list="" # build list of files
  
  # go through all session folders in subjects
  for j in ${i}/ses-*/; do
    
    t1=`ls ${j}/anat/sub*T1w.nii.gz 2>/dev/null`

    # first check for nii.gz
    if [ ! -n "$t1" ]; then
      t1=`ls ${j}/anat/sub*T1w.nii 2>/dev/null`

      # if not found then check for nii
      if [ ! -n "$t1" ]; then
        break
      fi  
    fi  
    
    # update list and count
    list="${list} ${t1}"  
    count=`expr $count + 1`  
  done

  # nothing found
  if [ "${count}" -eq "0" ]; then
    echo "Could not found any *.nii* file in ${j}/anat/"
  else
    # use cross-sectional pipeline for single files
    if [ "${count}" -eq "1" ]; then
      ${cat12_dir}/cat_batch_cat.sh $list -p 1 $fg --matlab $matlab --defaults $default $no_surf $rp --bids_folder $bids_folder_cross
    else # otherwise call longitudinal pipeline
      ${cat12_dir}/cat_batch_long.sh $list $fg --matlab $matlab --defaults $default --model $model $no_surf $export_dartel --bids_folder $bids_folder_long
    fi    
  fi
    
done
