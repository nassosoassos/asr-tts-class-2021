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

  local/russian_prepare_dict.sh data/local/lm data/local/dict_nosp

  utils/prepare_lang.sh data/local/dict_nosp \
    "<UNK>" data/local/lang_tmp_nosp data/lang_nosp

  local/russian_format_lms.sh --src-dir data/lang_nosp data/local/lm
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
  utils/subset_data_dir.sh --shortest data/train 500 data/train_500short
fi

if [ $stage -le 3 ]; then
  # TODO(galv): Is this too many jobs for a smaller dataset?
  steps/train_mono.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
    data/train_500short data/lang_nosp exp/mono

  steps/align_si.sh --boost-silence 1.25 --nj 5 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/mono exp/mono_ali_train
fi

# train a first delta + delta-delta triphone system on all utterances
if [ $stage -le 4 ]; then
  steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    2000 10000 data/train data/lang_nosp exp/mono_ali_train exp/tri1

  steps/align_si.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri1 exp/tri1_ali_train
fi

# train an LDA+MLLT system.
if [ $stage -le 5 ]; then
  steps/train_lda_mllt.sh --cmd "$train_cmd" \
    --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
    data/train data/lang_nosp exp/tri1_ali_train exp/tri2b

  # Align utts using the tri2b model
  steps/align_si.sh  --nj 5 --cmd "$train_cmd" --use-graphs true \
    data/train data/lang_nosp exp/tri2b exp/tri2b_ali_train
fi

# Train tri3b, which is LDA+MLLT+SAT
if [ $stage -le 6 ]; then
  steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
    data/train data/lang_nosp exp/tri2b_ali_train exp/tri3b
fi

# Now we compute the pronunciation and silence probabilities from training data,
# and re-create the lang directory.
if [ $stage -le 7 ]; then
  steps/get_prons.sh --cmd "$train_cmd" \
    data/train data/lang_nosp exp/tri3b
  utils/dict_dir_add_pronprobs.sh --max-normalize true \
    data/local/dict_nosp \
    exp/tri3b/pron_counts_nowb.txt exp/tri3b/sil_counts_nowb.txt \
    exp/tri3b/pron_bigram_counts_nowb.txt data/local/dict

  utils/prepare_lang.sh data/local/dict \
    "<UNK>" data/local/lang_tmp data/lang

  local/russian_format_lms.sh --src-dir data/lang data/local/lm

  steps/align_fmllr.sh --nj 5 --cmd "$train_cmd" \
    data/train data/lang exp/tri3b exp/tri3b_ali_train
fi

if [ $stage -le 8 ]; then
  # Test the tri3b system with the silprobs and pron-probs.

  # decode using the tri3b model
  utils/mkgraph.sh data/lang_test_tgmed \
                   exp/tri3b exp/tri3b/graph_tgmed
  for test in dev; do
    steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
                          exp/tri3b/graph_tgmed data/$test \
                          exp/tri3b/decode_tgmed_$test
    steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_tgmed \
                       data/$test exp/tri3b/decode_tgmed_$test
    # steps/lmrescore_const_arpa.sh \
    #   --cmd "$decode_cmd" data/lang_test_{tgsmall,tglarge} \
    #   data/$test exp/tri3b/decode_{tgsmall,tglarge}_$test
  done

  for x in exp/*/decode*; do [ -d $x ] && [[ $x =~ "$1" ]] && grep WER $x/wer_* | utils/best_wer.sh; done

fi


