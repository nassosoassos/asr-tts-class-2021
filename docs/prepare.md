# Preparing the data for Kaldi

## The theory
Considering that our dataset is a set of utterances, each with a unique id, we will need to create three files (using the names of the files as these are created for the mini-librispeech recipe):

A `wav.scp` file providing the mapping of the ids to the corresponding audio files. There is a bit more to that if the files are not in .wav format but we will get there soon. 
```
wav.scp

id000001 /data/audio/file1.wav
id000002 /data/audio/file2.wav
...
```

A `text` file linking each id to the text of the utterance.
```
text

id000001 This is the text uttered in the first file
id000002 I am now reading the second line
...
```

A `utt2spk` file mapping each utterance id to a speaker id. If speakers are unknown we can use a separate speaker id per utterance.
```
id000001 spk_id_0001
id000002 spk_id_0001
...
```

There is a `spk2utt` file that is also needed but we will create this using a utility script already provided by Kaldi. 

## In practice

### Reading the tsv files (or creating such files if they do not exist)
We will use pandas for that: 
```python
import pandas
import csv

part_file='train.tsv'

# The .tsv file has the following columns:
# client_id, path, sentence, ...
dataset = pandas.read_csv(part_file, delimiter='\t')
dataset['id'] = dataset['client_id']+ '_' + dataset['path'].str.replace('.mp3','', regex=True)

# Doing this here since Kaldi tools seem to be expecting it later in the pipeline
dataset = dataset.sort_values(by=['id'])
```

But what happens when there are no .tsv files? If we just have a directory of audio recordings and the transcriptions already in a separate file tagged by the correspoding audio filename:
```
transcriptions.txt

wav_filename_1.wav This is one utterance.
wav_filename_2.wav This is a second utterance.
...
```
We can then create a basic .tsv file as follows (again using python):
```python
import glob
import os.path

audio_data_dir = '/data/audio'
transcriptions_file = '/data/transcriptions.txt'

tsv_file = 'all.tsv'
# The audio files are in separate folders per speaker (named after speaker id)
wav_files = glob.glob(f"{audio_data_dir}/*/.wav")

# No transcription file, no honey 
with open(transcriptions_file, 'r') as trans:
	transcriptions = {}
	speakers = {}
	paths = {}
	for line in trans:
		cline = line.rstrip()
		line_info = cline.split(' ')
		utt_id, ext = os.path.splitext(line_info[0])
		if len(line_info)>1:
			transcriptions[utt_id] = " ".join(line_info[1:])
	
	for recording in wav_files:
		path_head, wav_basename = os.path.split(recording)
		path_head, spk_id = os.path.split()
		utt_id, ext = os.path.splitext(wav_basename)
		speakers[utt_id] = spk_id
		paths[utt_id] = wav_basename
		
	with open(tsv_file, 'w') as tsv:
		tsv_file.write("\t".join(("client_id", "path", "sentence"))+"\n")
		for utt_id in transcriptions:
			sentence = transcriptions[utt_id]
			speaker = speakers[utt_id]
			audio = paths[utt_id]
			tsv_file.write(f"{speaker}\t{audio}\t{sentence}\n")
```
And what if the transcriptions are inside json files along with other metadata? That's indeed true for a dataset I am aware of. To be discussed later.

### Creating the wav.scp file
The russian commonvoice dataset only has .mp3 (and not wav) audio files. So, we will need to preprocess the data to get the wav files Kaldi requires. A tool to do that is sox using the following command lines (in bash):
```bash
for f in /data/audio/*/*.mp3; do
	sox $f -r 16000 $f.wav;
done

```
By the way, we have specified, using the `-r` switch, that we want to also downsample the data to 16kHz. And then we can proceed with creating the 'wav.scp' by just doing the following in python (appending to the script we started in the previous section):
```python

dataset['abs_path'] = os.path.audio_data_dir + '/' + dataset['path'] + '.wav'

dataset[['id', 'abs_path']].to_csv(wav_scp_file, sep=' ', index=False, header=False)
```

Kaldi also provides a neat way to do this conversion from mp3 to wav right before the feature extraction step (that we will discuss later on) avoiding in this way to store the wav files and saving space. It should be noted here that wav files can be significantly bigger than their compressed (mp3)  versions (depending on the exact sampling rates and quality the wav file could be ~10 times bigger or even more). 

This is done by providing a command line that would write the converted audio directly to stdout so that it could be piped into a following command (bash magic). The command line would look like this:
```bash
sox file.mp3 -t wav -r 16000 - | 
```
By providing the `-` at the input of `sox` instead of a filename we are guiding the tool to generate the output and flush it to the standard output. And then we can pipe this into the following command. So, to write the corresponding wav.scp file in python we would do the following:
```python
# Create wav.scp file

dataset['mp3_to_wav'] = 'sox ' + audio_data_dir + '/' + dataset['path'] + ' -r 16000 -t wav - |'

dataset[['id', 'mp3_to_wav']].to_csv(wav_scp_file, quotechar=' ', sep=' ', index=False, header=False)
```
So, what about the `quotechar`? As one would easily notice if omitting to use this, the generated file would look as follows:
```
wav.scp

id000001 "sox f1.mp3 -r 16000 -t wav - |"
...
```
where the command has been written within quotes. That's the right thing to do  given that our separator is the space character that is also included in the command line we want to register. Without the quotes our file won't be readable as a space-separated file. That's not what we are aiming at, however. Our goal is to just separate the initial column, i.e., the id, from the rest of the line with a space (that's what Kaldi needs, it complains otherwise) and we are just tweaking a bit the `.to_csv` method of pandas dataframes to make it work as we want. So, instead of a "quote" we instruct pandas to use a space character. 

### Creating the text file
Having done most of the work already, the only thing we need to take care when creating the text file is to clean punctuation (well, and also use python3 to make sure encodings are handled properly out-of-the-box). The code in python follows:
```
# Create trans_file

dataset['sentence'] = dataset['sentence'].str.replace(r'[^\w\s]+',' ', regex=True)

dataset[['id', 'sentence']].to_csv(trans_file, quotechar=' ', sep=' ', index=False, header=False)
```
Using the `quotechar`here for the reasons explained above.

### And here comes the utt2spk file
The easiest of all. Mind the `quotechar` game again:
```
# Create utt2spk file

dataset[['id', 'client_id']].to_csv(utt2spk_file, quotechar=' ', sep=' ', index=False, header=False)
```

And that's our "process_tsv_file.py" script. Could be named: "data_prep_from_tsv.py". That would probably be more appropriate. 

## Final steps
There are two more things to be done:
1. Create the spk2utt file.
2. Validate that these data files are all following Kaldi conventions. There is a script for that. 

We will use the `utils/utt2spk_to_spk2utt.pl` for that, copying it from the "minilibrispeech". Actually, let's copy the entire "utils", "steps", and "local" folders into our working directory since we will be using various tools and scripts from there:
```
cp -rp mini_librispeech/s5/{utils,steps,local} cv_russian/s5
```

And we will properly modify the "local/data_prep.sh" script to create our own:
```bash
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

# If the following files exist, then delete them, we will recreate them.
wav_scp=$dst/wav.scp; [[ -f "$wav_scp" ]] && rm $wav_scp
trans=$dst/text; [[ -f "$trans" ]] && rm $trans
utt2spk=$dst/utt2spk; [[ -f "$utt2spk" ]] && rm $utt2spk

# Process tsv files to extract all required information
PYTHONIOENCODING=UTF-8 python3 local/process_tsv_file.py $part $src/clips $wav_scp $trans $utt2spk

spk2utt=$dst/spk2utt
utils/utt2spk_to_spk2utt.pl <$utt2spk >$spk2utt || exit 1

```
And here comes the data validation part:
```
# Data validation

# To measure the number of lines in the corresponding files
ntrans=$(wc -l <$trans)
nutt2spk=$(wc -l <$utt2spk)

! [ "$ntrans" -eq "$nutt2spk" ] && \

echo "Inconsistent #transcripts($ntrans) and #utt2spk($nutt2spk)" && exit 1;
utils/validate_data_dir.sh --no-feats $dst || exit 1;

echo "$0: successfully prepared data in $dst"

exit 0
```

Data validation must be 100% successful before proceeding with the rest of the recipe.

## Back to the recipe
And this is how our recipe looks now. Notice how we need to run data preparation for each of our "training", "development", and "test" datasets.
```
#!/usr/bin/env bash

src_data=/data/russian/cv-corpus-6.1-2020-12-11/ru/

# These are for configuration and to add tools to the path so that they are 
# accessible from the command line.
. ./cmd.sh
. ./path.sh

stage=0

. utils/parse_options.sh

set -euo pipefail
mkdir -p data

# Data preparation
# No need to split data into train, dev, and test. Commonvoice data is already split.

if [ $stage -le 1 ]; then
# format the data as Kaldi data directories
	for part in train dev test; do
		# For each of these parts we need to have a separate subfolder with the following files in it:
		# wav.scp text utt2spk spk2utt
		local/russian_data_prep.sh $src_data $src_data/$part.tsv data/$part
	done
fi
```