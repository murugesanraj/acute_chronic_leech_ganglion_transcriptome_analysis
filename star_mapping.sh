#!/bin/bash

#==============================================================================
# SBATCH Directives
#==============================================================================
#SBATCH --job-name=star_alignment        # A descriptive name for your job
#SBATCH --error=star_align_%j.err        # File to which STDERR will be written
#SBATCH --output=star_align_%j.out       # File to which STDOUT will be written
#SBATCH --time=47:00:00                  # Requested time (HH:MM:SS)
#SBATCH --cpus-per-task=16               # Number of CPUs to use for STAR
#SBATCH --mem=64G                        # Requested memory (STAR needs a lot)
#SBATCH --mail-type=BEGIN,END,FAIL       # Send email notifications for these events
#SBATCH --mail-user=rajum@umsystem.edu   # Your email address

#==============================================================================
# USER-DEFINED VARIABLES
#==============================================================================
GENOME_DIR="/mnt/pixstor/schulzd-lab/software_tools/leech_genome_annot/hv_genome_annot/hv_star_index"
GTF_FILE="/mnt/pixstor/schulzd-lab/software_tools/leech_genome_annot/hv_genome_annot/genemark_star_ready.gtf"

#==============================================================================
# Main Script
#==============================================================================

echo "Starting STAR alignment for multiple samples..."
echo "Using genome index from: $GENOME_DIR"
echo "Using annotation GTF: $GTF_FILE"

# -----------------------------------------------------------------------------
# 1. Load the STAR module
# -----------------------------------------------------------------------------
echo "Loading STAR module..."
module load star

# -----------------------------------------------------------------------------
# 2. Check for the genome index
# -----------------------------------------------------------------------------
if [ ! -d "$GENOME_DIR" ]; then
    echo "ERROR: Genome index directory '$GENOME_DIR' not found. Exiting."
    exit 1
fi

# -----------------------------------------------------------------------------
# 3. Loop through all trimmed R1 files from qc.sh output
#    Expecting: 1_S41_L004_preprocessed/1_S41_L004_R1_trimmed.fastq.gz
# -----------------------------------------------------------------------------
FOUND_ANY=false

for R1_TRIMMED_FILE in *_preprocessed/*_R1_trimmed.fastq.gz
do
    # If the glob doesn't match anything, it will stay as the literal string
    if [ ! -e "$R1_TRIMMED_FILE" ]; then
        continue
    fi

    FOUND_ANY=true

    # Get sample base name (e.g. 1_S41_L004) without directory and suffix
    BASE_NAME=$(basename "$R1_TRIMMED_FILE" _R1_trimmed.fastq.gz)

    # Construct R2 path in the same directory
    R2_TRIMMED_FILE="${R1_TRIMMED_FILE/_R1_trimmed.fastq.gz/_R2_trimmed.fastq.gz}"

    if [ ! -e "$R2_TRIMMED_FILE" ]; then
        echo "WARNING: Corresponding R2 file not found for $R1_TRIMMED_FILE"
        echo "Expected: $R2_TRIMMED_FILE"
        echo "Skipping sample $BASE_NAME."
        continue
    fi

    echo "----------------------------------------------------"
    echo "Processing sample: $BASE_NAME"
    echo "R1 file: $R1_TRIMMED_FILE"
    echo "R2 file: $R2_TRIMMED_FILE"

    # Output directory for STAR results (in current working directory)
    STAR_OUTPUT_DIR="${BASE_NAME}_STAR_output"
    mkdir -p "$STAR_OUTPUT_DIR"

    # -------------------------------------------------------------------------
    # 4. Run the STAR alignment
    # -------------------------------------------------------------------------
    echo "Running STAR alignment for $BASE_NAME..."

    STAR \
        --runThreadN "$SLURM_CPUS_PER_TASK" \
        --genomeDir "$GENOME_DIR" \
        --readFilesIn "$R1_TRIMMED_FILE" "$R2_TRIMMED_FILE" \
        --readFilesCommand zcat \
        --outFileNamePrefix "${STAR_OUTPUT_DIR}/${BASE_NAME}_" \
        --outSAMtype BAM SortedByCoordinate \
        --outSAMunmapped Within \
        --outSAMattributes All \
        --quantMode GeneCounts \
        --sjdbGTFfile "$GTF_FILE"

    echo "STAR alignment for $BASE_NAME completed. Results are in '$STAR_OUTPUT_DIR'."
done

if [ "$FOUND_ANY" = false ]; then
    echo "No trimmed FASTQ files found."
    echo "Expected pattern: *_preprocessed/*_R1_trimmed.fastq.gz"
fi

echo "----------------------------------------------------"
echo "STAR alignment for all samples has finished (or no samples were found)."

