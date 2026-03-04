#!/bin/bash

# --- CONFIGURATION DES CHEMINS ---
SOURCE_DATA="/data"
SAVE_DIR="/results"
# MODEL_PATH="/models/checkpoint_ovaire.pth"
MODEL_PATH="heatmaps/demo/ckpts/s_0_checkpoint.pt"
CONFIG_YAML="/results/heatmap_config.yaml"
LOG_DIR="$SAVE_DIR/logs"
PATCH_SIZE=256

mkdir -p "$LOG_DIR"

# 1. PATCHING
echo "STAGE 1 >>> Patching..."
python create_patches_fp.py \
    --source $SOURCE_DATA \
    --save_dir $SAVE_DIR \
    --patch_size $PATCH_SIZE \
    --step_size $PATCH_SIZE \
    --seg --patch --stitch >> "$LOG_DIR/patching.log" 2>&1

# 2. FEATURE EXTRACTION
echo "STAGE 2 >>> Feature Extraction..."
python extract_features_fp.py \
    --data_h5_dir $SAVE_DIR \
    --data_slide_dir $SOURCE_DATA \
    --csv_path $SAVE_DIR/process_list_autogen.csv \
    --feat_dir $SAVE_DIR/features \
    --batch_size 64 \
    --slide_ext .mrxs >> "$LOG_DIR/feature_extraction.log" 2>&1

# 3. HEATMAP GENERATION
echo "STAGE 3 >>> Heatmap Generation..."

mkdir -p $SAVE_DIR/heatmaps/raw/OV_PREDICTION
mkdir -p $SAVE_DIR/heatmaps/production/OV_PREDICTION

echo "slide_id,label" > "$SAVE_DIR/process_list.csv"
find "$SOURCE_DATA" -maxdepth 1 -name "*.mrxs" | while read -r slide_path; do
    full_name=$(basename "$slide_path")
    slide_id="${full_name%.mrxs}"
    echo "$slide_id,Tumeur" >> "$SAVE_DIR/process_list.csv"
done

cat << EOF > $CONFIG_YAML
exp_arguments:
  n_classes: 2
  save_exp_code: "OV_PREDICTION"
  raw_save_dir: "${SAVE_DIR}/heatmaps/raw"
  production_save_dir: "${SAVE_DIR}/heatmaps/production"
  batch_size: 256

data_arguments:
  data_dir: "${SOURCE_DATA}"
  data_dir_key: "source"
  process_list: "${SAVE_DIR}/process_list.csv"
  preset: "${SAVE_DIR}/process_list_autogen.csv"
  slide_ext: ".mrxs"
  label_dict:
    Sain: 0
    Tumeur: 1

patching_arguments:
  patch_size: ${PATCH_SIZE}
  overlap: 0.5
  patch_level: 0
  custom_downsample: 1

encoder_arguments:
  model_name: "resnet50_trunc" 
  target_img_size: 224

model_arguments:
  ckpt_path: "${MODEL_PATH}"
  model_type: "clam_sb"
  initiate_fn: "initiate_model"
  model_size: "small"
  drop_out: 0.0
  embed_dim: 1024

heatmap_arguments:
  vis_level: 6      
  alpha: 0.4              
  cmap: "jet"             
  blank_canvas: false     
  save_orig: true         
  save_ext: "jpg"
  custom_downsample: 1
  calc_heatmap: true      
  use_ref_scores: false    
  blur: false             
  use_center_shift: true  
  binarize: false         
  binary_thresh: -1       
  use_roi: false          

sample_arguments:
  samples:
    - name: "topk_high_attention"
      sample: true
      seed: 1
      k: 0               
      mode: "topk"        
EOF

python create_heatmaps.py --config_file $CONFIG_YAML >> "$LOG_DIR/heatmap_generation.log" 2>&1

# 4. POST-PROCESSING
echo "STAGE 4 >>> Post-processing..."
python post_processing.py --source $SAVE_DIR --patch_size $PATCH_SIZE >> "$LOG_DIR/post_processing.log" 2>&1

# 5. COPY RESULTS
echo "STAGE 5 >>> Copying results..."
mkdir -p "$SOURCE_DATA/CLAM"

date_str=$(date +%Y%m%d_%H%M%S)
cp -r "$SAVE_DIR/heatmaps/raw/OV_PREDICTION/Tumeur" "$SOURCE_DATA/CLAM/OV_PREDICTION_$date_str"
cp -r "$LOG_DIR" "$SOURCE_DATA/CLAM/OV_PREDICTION_${date_str}_logs"
cp $CONFIG_YAML "$SOURCE_DATA/CLAM/OV_PREDICTION_${date_str}_logs/heatmap_config.yaml"