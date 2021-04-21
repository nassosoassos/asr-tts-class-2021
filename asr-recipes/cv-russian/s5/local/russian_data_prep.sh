#!/usr/bin/env bash

# Copyright 2020 Nassos Katsamanis
# Apache 2.0

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <src-dir> <part-info> <dst-dir>"
  echo "e.g.: $0 /data/russian train.tsv data/train"
  exit 1
fi

src=$1
part=$2
dst=$3

mkdir -p $dst || exit 1;

[ ! -d $src ] && echo "$0: no such directory $src" && exit 1;

wav_scp=$dst/wav.scp; [[ -f "$wav_scp" ]] && rm $wav_scp
trans=$dst/text; [[ -f "$trans" ]] && rm $trans
utt2spk=$dst/utt2spk; [[ -f "$utt2spk" ]] && rm $utt2spk

# Process tsv files to extract all required information
PYTHONIOENCODING=UTF-8 python3 local/process_tsv_file.py $part $src/clips $wav_scp $trans $utt2spk


spk2utt=$dst/spk2utt
utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1


# Data validation
ntrans=$(wc -l <$trans)
nutt2spk=$(wc -l <$utt2spk)
! [ "$ntrans" -eq "$nutt2spk" ] && \
  echo "Inconsistent #transcripts($ntrans) and #utt2spk($nutt2spk)" && exit 1;

utils/validate_data_dir.sh --no-feats $dst || exit 1;

echo "$0: successfully prepared data in $dst"

exit 0
