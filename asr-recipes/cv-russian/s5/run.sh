#!/usr/bin/env bash

# Change this location to somewhere where you want to put the data.
src_data=/data/russian/cv-corpus-6.1-2020-12-11/ru/

. ./cmd.sh
. ./path.sh

stage=0
. utils/parse_options.sh

set -euo pipefail

mkdir -p data 
# Data preparation

# No need to split into train, dev, and test. Commonvoice data are already split.
if [ $stage -le 1 ]; then
  # format the data as Kaldi data directories
  for part in train dev test; do
    # For each of these parts we need to have a separate subfolder with the following
    # files in it:
    # wav.scp text utt2spk spk2utt
    local/russian_data_prep.sh $src_data $src_data/$part.tsv data/$part
  done
  utils/combine_data.sh data/all data/train data/dev data/test

  local/prepare_lm.sh --data data/train --locdata data/local/lm

  local/prepare_dict.sh data/local/lm data/local/dict_nosp

  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  local/format_lms.sh --src-dir data/lang_nosp data/local/lm
#   # Create ConstArpaLm format language model for full 3-gram and 4-gram LMs
#   utils/build_const_arpa_lm.sh data/local/lm/lm.gz \
#     data/lang_nosp data/lang_nosp_test
fi 

if [ $stage -le 2 ]; then
  mfccdir=mfcc
  for part in train dev test; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 10 data/$part exp/make_mfcc/$part $mfccdir
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part $mfccdir
  done

  # Get the shortest 500 utterances first because those are more likely
  # to have accurate alignments.
fi