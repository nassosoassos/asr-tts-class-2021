hypothesis_tra=exp/tri3b/decode_tgsmall_dev_clean_2/scoring/9.0.5.tra
ref_trw=exp/tri3b/decode_tgsmall_dev_clean_2/scoring/test_filt.txt

cat $hypothesis_tra | utils/int2sym.pl -f 2- exp/tri3b/graph_tgsmall/words.txt | sed s:\<UNK\>::g > hypothesis.trw

python hypothesis.trw hypothesis.wsj
python $ref_trw ref.wsj



