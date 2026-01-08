#!/bin/bash

#==============================================================================
# SBATCH Directives
#==============================================================================
#SBATCH --job-name=batch_fastq_preproc   # A descriptive name for your job
#SBATCH --error=batch_fastq_%j.err       # File to which STDERR will be written
#SBATCH --output=batch_fastq_%j.out      # File to which STDOUT will be written
#SBATCH --time=08:00:00                  # Requested time (HH:MM:SS)
#SBATCH --cpus-per-task=8                # Number of CPUs to use
#SBATCH --mem=32G                        # Requested memory
#SBATCH --mail-type=BEGIN,END,FAIL       # Send email notifications for these events
#SBATCH --mail-user=rajum@umsystem.edu   # Your email address

#==============================================================================
# Main Script
#==============================================================================

echo "Starting batch FASTQ preprocessing..."

# Load the Conda module
module load miniconda3
conda activate my_conda

# Loop through all R1 files that match the pattern "*_R1.fastq.gz"
# This will catch: 1_S41_L004_R1.fastq.gz, 2_S42_L004_R1.fastq.gz, etc.
for RAW_R1 in *_R1_001_trimmed.fastq.gz
do
    # Check if the file exists and is not an empty glob
    if [ ! -e "$RAW_R1" ]; then
        echo "No files matching '*_R1_001_trimmed.fastq.gz' found. Exiting loop."
        break
    fi

    echo "----------------------------------------------------"
    echo "Processing file: $RAW_R1"

    # Extract the base name (e.g., '1_S41_L004') from the R1 file name
    BASE_NAME=$(basename "$RAW_R1" _R1_001_trimmed.fastq.gz)
    RAW_R2="${BASE_NAME}_R2_001_trimmed.fastq.gz"

    # Check if the corresponding R2 file exists
    if [ ! -e "$RAW_R2" ]; then
        echo "WARNING: Corresponding R2 file ($RAW_R2) not found. Skipping $RAW_R1."
        continue
    fi

    # Create a unique output directory for this sample
    OUTPUT_DIR="${BASE_NAME}_preprocessed"
    mkdir -p "$OUTPUT_DIR"

    # -------------------------------------------------------------------------
    # 1. Run initial FastQC on raw files
    # -------------------------------------------------------------------------
    echo "Running initial FastQC on raw files..."
    fastqc "$RAW_R1" "$RAW_R2" -o "$OUTPUT_DIR"

    # -------------------------------------------------------------------------
    # 2. Trim and filter with fastp
    # -------------------------------------------------------------------------
    echo "Trimming and filtering reads with fastp..."

    # Define output file names inside the sample-specific directory
    TRIMMED_R1="${OUTPUT_DIR}/${BASE_NAME}_R1_trimmed.fastq.gz"
    TRIMMED_R2="${OUTPUT_DIR}/${BASE_NAME}_R2_trimmed.fastq.gz"
    FASTP_HTML="${OUTPUT_DIR}/${BASE_NAME}_fastp_report.html"

    # Run fastp with the specified number of threads
    fastp \
        --in1 "$RAW_R1" \
        --in2 "$RAW_R2" \
        --out1 "$TRIMMED_R1" \
        --out2 "$TRIMMED_R2" \
        --html "$FASTP_HTML" \
        --thread "$SLURM_CPUS_PER_TASK"

    # -------------------------------------------------------------------------
    # 3. Run final FastQC on trimmed files
    # -------------------------------------------------------------------------
    echo "Running final FastQC on trimmed files..."
    fastqc "$TRIMMED_R1" "$TRIMMED_R2" -o "$OUTPUT_DIR"

    echo "Preprocessing for $BASE_NAME completed. Results are in '$OUTPUT_DIR'."
done

echo "----------------------------------------------------"
echo "Batch FASTQ preprocessing job has finished successfully."

