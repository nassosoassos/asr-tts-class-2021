# Create a new Kaldi recipe
 
So, what is really a recipe in this context? It's the set of instructions the machine should follow to actually generate, or train, if you like, a speech recognition engine for a specific task. One such task could be speech recognition for Mandarin Chinese or spoken command recognition for smart home applications, or you name it. By "engine" here we essentially refer to a "final.mdl" file including all acoustic modeling information, a "HCLG.fst" with all language information and a few other configuration
files. These files can be loaded into a so-called decoder (one of the "tools" Kaldi provides) to actually transform speech into text. There are already multiple recipes
to build such engines included with Kaldi and we will be re-using them as much as possible. That is probably the most important take-home-message of this exercise: there is already a lot of work put into Kaldi, we just need to understand a bit better what kind of "lego pieces", or, even better, "lego structures" we have available and then go ahead to build our "castle". 


## First pick a task ( or, more typically, the task will pick you )
In our case we just want to build a speech recognition engine for dictation in Russian. We will be using commonvoice data as provided by Mozilla. I used to be a great fan of voxforge in the past for open source data but it seems that Mozilla is actually doing a very good job on that these dayes: many languages and really lots of crowdsourced data.


## Use mini-librispeech as our guide
We will then simply run the mini-librispeech recipe to make sure that it works smoothly and that we get back the results we expect. I can do that by just running:
```
cd asr_recipes/mini_librispeech/s5
./run.sh
```
We would typically just need to replace 'queue.pl' inside cmd.sh file with 'run.pl' for the recipe to run end-to-end without problems:
```
sed -i 's/queue/run/g' cmd.sh
```
The recipe will reach stage 9 and will typically exit with a message saying that there are no GPUs available, etc. That is actually fine for now.

## Create the folder for the new recipe
Let's name it cv-russian. And also create a subfolder 's5' into it:
```
cd asr_recipes
mkdir -p cv-russian/s5
```
This 's5' is legacy from one of the initial recipes developed, namely one for the Wall Street Journal task (still available as wsj inside asr_recipes). There is used to be multiple alternatives, from s1 to s5. The best of them, 's5', was the one essentially inherited and properly modified in other recipes that were developed later on. 

Let's copy 'run.sh' into our newly created foler:
```
cp asr_recipes/mini_librispeech/s5/run.sh cv-russian/s5
```

## Initial recipe modifications
By quickly reviewing the "./run.sh" file we can identify four main parts:
1. The preamble, where a few basic variables are initialized (that's up to the line `mkdir -p $data`)
1. The data download section, where all audio files, transcriptions, and the language model are downloaded from the web (a few lines before stage 0 and stage 0).
1. The main data preparation part, where downloaded data are essentially formatted so that they can be fed to Kaldi tools for model training and testing (staages 1 and 2).
1. The model training part, 
And let's see what we need to do to make the recipe run. Starting with the preamble:
```
#!/usr/bin/env bash

# Change this location to somewhere where you want to put the data.
data=./corpus/

data_url=www.openslr.org/resources/31
lm_url=www.openslr.org/resources/11

. ./cmd.sh
. ./path.sh

stage=0
. utils/parse_options.sh

set -euo pipefail

mkdir -p $data

for part in dev-clean-2 train-clean-5; do
  local/download_and_untar.sh $data $data_url $part
done

if [ $stage -le 0 ]; then
  local/download_lm.sh $lm_url $data data/local/lm
fi
```



Let's also copy 'utils', 'local', and 'steps', folders from the mini_librispeech folder into our new folder:
```
mini_librispeech=asr_recipes/mini_librispeech/s5
cp -rp $mini_librispeech/{utils,local,steps} cv_russian/s5
```
You may notice in the process that 'utils' and 'steps' are just links to corresponding directories inside the 'wsj' recipe folder. This is the Kaldi recipe development philosophy in practice: reusing scripts and utilities developed for the initial 'wsj' recipe. 