NLTK_DIR = nltk_data
NLTK_DIR_DONE = $(NLTK_DIR)/make.done
DATA_DIR = data
ALL_DATA := $(shell find $(DATA_DIR) -type f -name '*.zip')
TEST = $(DATA_DIR)/testData
LABELED_TRAIN = $(DATA_DIR)/labeledTrainData
UNLABELED_TRAIN =  $(DATA_DIR)/unlabeledTrainData
TRAIN = $(LABELED_TRAIN) $(UNLABELED_TRAIN)
WORD2VEC = $(DATA_DIR)/300features_40minwords_10context
SENT_TOKENIZER = $(DATA_DIR)/sentence_tokenizer.pickle

export NLTK_DATA=$(NLTK_DIR)

TSVS  := $(ALL_DATA:.tsv.zip=.tsv)
SENTS := $(ALL_DATA:.tsv.zip=.sents.gz)
WORDS := $(ALL_DATA:.tsv.zip=.words.gz)

clean_data:
	rm -rf $(SENTS) $(WORDS) $(WORD2VEC)

sentences: $(SENTS) | env
	@echo "done"

words: $(WORDS) | env
	@echo "done"

nltk: $(NLTK_DIR_DONE)
	@echo "done"

pretrain: $(WORD2VEC)
	@echo "done"

.SECONDARY: $(TSVS) $(SENT_TOKENIZER) $(WORDS) $(SENTS) $(WORD2VEC)
%.tsv: %.tsv.zip
	unzip -p $< > $@

train: $(LABELED_TRAIN).tsv $(LABELED_TRAIN).words.gz $(WORD2VEC)
	$(PYTHON) -m flaubert.train \
		--classifier svm --model $(WORD2VEC) \
		--train $(LABELED_TRAIN).tsv \
		--sentencelist $(LABELED_TRAIN).sents.gz
	#--wordlist $(LABELED_TRAIN).words.gz

$(WORD2VEC): $(LABELED_TRAIN).sents.gz $(UNLABELED_TRAIN).sents.gz
	@echo "Creating word2vec model at $(WORD2VEC)"
	python -m flaubert.pretrain \
		--sentences $^ \
		--output $@
	#--doc2vec

$(NLTK_DIR_DONE):
	$(PYTHON) -m nltk.downloader -d $(NLTK_DIR) wordnet stopwords punkt maxent_treebank_pos_tagger
	touch $@

%.sents.gz: %.tsv | $(NLTK_DIR_DONE) $(SENT_TOKENIZER)
	$(PYTHON) -m flaubert.preprocess --input $*.tsv --output $@ tokenize --sentences

%.words.gz: %.tsv | $(NLTK_DIR_DONE)
	$(PYTHON) -m flaubert.preprocess --input $*.tsv --output $@ tokenize

$(SENT_TOKENIZER): $(LABELED_TRAIN).tsv $(UNLABELED_TRAIN).tsv
	$(PYTHON) -m flaubert.preprocess --input $^ --output $@ train --verbose
