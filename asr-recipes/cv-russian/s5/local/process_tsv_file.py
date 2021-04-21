import pandas
import sys
import csv

# local/process_tsv_file.py $part $wav_scp $trans $utt2spk
part_file = sys.argv[1]
audio_data_dir = sys.argv[2]
wav_scp_file = sys.argv[3]
trans_file = sys.argv[4]
utt2spk_file = sys.argv[5]

dataset = pandas.read_csv(part_file, delimiter='\t')
dataset['id'] = dataset['client_id']+ '_' + dataset['path'].str.replace('.mp3','', regex=True)
dataset = dataset.sort_values(by=['id'])

# Create wav.scp file
dataset['mp3_to_wav'] = 'sox ' + audio_data_dir + '/' + dataset['path'] + ' -r 16000 -t wav - |'
dataset[['id', 'mp3_to_wav']].to_csv(wav_scp_file, quotechar=' ', sep=' ', index=False, header=False)

# Create trans_file
dataset['sentence'] = dataset['sentence'].str.replace(r'[^\w\s]+',' ', regex=True)
dataset[['id', 'sentence']].to_csv(trans_file, quotechar=' ', sep=' ', index=False, header=False)

# Create utt2spk file
dataset[['id', 'client_id']].to_csv(utt2spk_file, quotechar=' ', sep=' ', index=False, header=False)

