docker build -t clam-ovaire .

docker run -it --rm \
  -v /Users/chad/Documents/data/EXTRACTION_SN/2505014/tissue/ov_pat45_ovd/histo:/data \
  -v /Users/chad/Documents/dev/PY/CLAM/results:/results \
  -v /Users/chad/Documents/dev/PY/CLAM/models:/models \
  clam-ovaire \
  bash ./seg.sh