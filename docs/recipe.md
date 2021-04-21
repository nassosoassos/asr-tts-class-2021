# How to initialize a new Kaldi recipe

So, what is really a recipe in this context? It's the set of instructions the machine should follow to actually generate, or train, if you like, a speech recognition engine for a specific task. One such task could be speech recognition for Mandarin Chinese or spoken command recognition for smart home applications, or you name it. By "engine" here we essentially refer to a "final.mdl" file including all acoustic modeling information, a "HCLG.fst" with all language information and a few other configuration

files. These files can be loaded into a so-called decoder (one of the "tools" Kaldi provides) to actually transform speech into text. There are already multiple recipes

to build such engines included with Kaldi and we will be re-using them as much as possible. That is probably the most important take-home-message of this exercise: there is already a lot of work put into Kaldi, we just need to understand a bit better what kind of "lego pieces", or, even better, "lego structures" we have available and then go ahead to build our "castle".

## First pick a task ( or, more typically, the task will pick you )

In our case we just want to build a speech recognition engine for dictation in Russian and we will use that as a working case. Other cases one can work on:

We will be using commonvoice data as provided by Mozilla. I used to be a fan of voxforge in the past for open source data but it seems that Mozilla is actually doing a very good job on that these days: offers many languages and really lots of crowdsourced data.

## Use mini-librispeech as our guide

We will then simply run the mini-librispeech recipe to make sure that it works smoothly and that we get back the results we expect. I can do that by just running:
```bash
cd asr\_recipes/mini\_librispeech/s5
./run.sh
```
We would typically just need to replace 'queue.pl' inside cmd.sh file with 'run.pl' for the recipe to run end-to-end without problems:
```bash
sed -i 's/queue/run/g' cmd.sh
```
The recipe will reach stage 9 and will typically exit with a message saying that there are no GPUs available, etc. That is fine for now.

You can check that the recipe has worked by running the one-liner in the header of the RESULTS file inside the s5 folder. This command (or multiple commands, better) will look for the WERs (Word Error Rates) estimated for various different configurations and different snapshots of the speech recognition engine, pick the lowest of them and display it:
```bash
for x in exp/*/decode\*; do 
	[ -d $x ] && [[ $x =~ "$1" ]] && \
	grep WER $x/wer_\* | \
	utils/best_wer.sh; 
done
```
The output should be something like the following, presenting the numbers for insertions/deletions/substitutions for three tests using different language models (small, medium, large):
```
WER 13.45 [ 2708 / 20138, 358 ins, 330 del, 2020 sub ] exp/tri3b/decode_nosp_tglarge_dev_clean_2/wer_17_0.0
WER 16.25 [ 3273 / 20138, 332 ins, 485 del, 2456 sub ] exp/tri3b/decode_nosp_tgmed_dev_clean_2/wer_16_0.0
WER 18.10 [ 3645 / 20138, 332 ins, 603 del, 2710 sub ] exp/tri3b/decode_nosp_tgsmall_dev_clean_2/wer_16_0.0
```

## Create the folder for the new recipe
Let's name it cv-russian. And also create a subfolder 's5' into it:
```bash
cd asr\_recipes
mkdir -p cv-russian/s5
```
This 's5' is legacy from one of the initial recipes developed, namely one for the Wall Street Journal task (still available as wsj inside asr\_recipes). There is used to be multiple alternatives, from s1 to s5. The best of them, 's5', was the one essentially inherited and properly modified in other recipes that were developed later on.

And let's create a new run.sh file in ths folder.  

## Initial recipe structure
The recipe will need to include four (or five, optionally) main parts:

1. The preamble, where we will initialize stuff, create the necessary folder structure and add tools to our working path 

1. If we don't yet have the dataset available, we will need to also include a "download data" section, where all audio files, transcriptions, and, if available, the language model as well are downloaded from the web (or transferred from elsewhere)

1. The main data preparation part, where speech data are preprocessed so that they can be fed to Kaldi tools for model training and testing 

1. The acoustic model training part, where we will be feeding the data to the appropriate Kaldi tools to build the engine.

## Our data 
Before moving any deeper into the recipe development, let's first review our data. We will be looking for audio recordings (.wav, .mp3 files or other formats) and the corresponding transcriptions (.txt, .json, .tsv files or similar). These are the basic ingredients: we need the audio (in relatively small chunks, typically, e.g., 10-15 seconds of duration max.) and what was actually said in the audio in the form of text.

For the tutorial, we will be using Russian data from commonvoice as made available [[https://commonvoice.mozilla.org/en/datasets|here]]. It's impressive how they've gathered data from so many languages in there. Other sources for publicly available speech data include: [[http://www.voxforge.org|voxforge]], [[https://www.openslr.org/12|librispeech]], and [[https://www.openslr.org/51/|TED Talks]]. Here is a nice collection, by the way, of relevant publicly available resources [[https://www.openslr.org/index.html]]. 

Assuming for now that data have already been downloaded and are stored in a locally mounted folder as unzipped from the downloaded dataset (ru.tar.gz. Use: `tar xvfz ru.tar.gz` to unzip):
```bash
data=/other/data/russian/cv-corpus-6.1-2020-12-11/ru/
```
This is what we have in there:
```
clips  dev.tsv  invalidated.tsv  other.tsv  reported.tsv  testing  test.tsv  text  train.tsv  validated.tsv
```
Our audio is in .mp3 format inside the clips folder. We will some extra preprocessing for these as we will see later on.
```
common_voice_ru_18849003.mp3
common_voice_ru_18849004.mp3
common_voice_ru_18849005.mp3
common_voice_ru_18849006.mp3
...
```
And then we have these .tsv files (watch for tab separated values), with metadata:
```
train.tsv

client_id	path	sentence	up_votes	down_votes	age	gender	accent	...
87e2683ece	common_voice_ru_18931630.mp3	Важно, чтобы все стороны четко ...
```
It's where we will get our transcriptions from, there is a `sentence` field for each `path` with the text in Russian. There's also speaker information, i.e., `client_id`, that will come in handy during training. 

So, here's the plan: 
1. We have a list of the files we will be using for training, testing, and development (coming from the corresponding .tsv files) along with the corresponding transcriptions. It won't be hard to actually convert these to the appropriate format for kaldi. We will see how that happens in the following.
2. We also have the audio recordings as .mp3 files that we will need to convert to wav for further processing. Tools like `ffmpeg` or `sox` can be used to the rescue. 


