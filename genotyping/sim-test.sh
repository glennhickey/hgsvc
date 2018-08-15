# Simulate reads from a sample in the hgsvc graph, map them back, then 
# run vg call to make a vcf. requires that graphs have been made by running
# ./make-vcf.sh and ./do-by-chrom.sh hgsvc_v1 in ../haps/

#!/bin/bash

usage() {
    # Print usage to stderr
    exec 1>&2
    printf "Usage: $0 [OPTIONS] <SAMPLE> <HGSVC_BASE> \n"
	 printf "Options:\n"
	 printf "\t-1\t\tSkip simulation\n"
	 printf "\t-2\t\tSkip simulation and alignment\n"
	 printf "\t-t\t N\tUse up to N threads\n"
    exit 1
}

THREADS=20
SIM=1
ALIGN=1

while getopts "t:12" o; do
    case "${o}" in
        t)
            THREADS=${OPTARG}
            ;;
        1)
            SIM=0
            ;;
        2)
            SIM=0
				ALIGN=0
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

if [[ "$#" -lt "2" ]]; then
    # Too few arguments
    usage
fi

# Needs to have been made in ../haps so: HG005733 or HG00514 or NA19240
SAMPLE="${1}"
shift

# Base of path to vg indexes: ex ../haps/hgsvc_v1.threads
HGSVC_BASE="${1}"
shift

#wget http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
#gzip -d hg38.fa.gz
HG38=../haps/hg38.fa 
SAMPLE_VCF=../haps/HGSVC.${SAMPLE}.vcf.gz

CHROM=chr21
REGIONS=chr21_non_repeats.bed
GAM_PREFIX=${SAMPLE}_sim_5M
NUMREADS=5000000
NAME=simtest-$(basename ${HGSVC_BASE})-${SAMPLE}
JS=./js_${NAME}_${NUMREADS}
OS=./${NAME}

if [ $SIM == "1" ]
then
	 # Make a graph for each haplotype thread of SAMPLE to simulate from
	 rm -rf ${JS} haplo_${NAME}.log; toil-vg construct ${JS} ${OS} --realTimeLogging --vcf ${SAMPLE_VCF} --fasta ${HG38} --haplo_sample ${SAMPLE} --xg_index --regions ${CHROM} --out_name hgsvc_baseline --logFile haplo_${NAME}.log --maxCores $THREADS --flat_alts

	 # Simulate some reads for this sample using thread graphs made above
	 rm -rf ${JS} sim_${NAME}.log; toil-vg sim ${JS} ${OS}/hgsvc_baseline_${SAMPLE}_haplo_thread_0.xg ${OS}/hgsvc_baseline_${SAMPLE}_haplo_thread_1.xg ${NUMREADS} ${OS} --realTimeLogging --fastq ftp://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/data/NA12878/NIST_NA12878_HG001_HiSeq_300x/131219_D00360_005_BH814YADXX/Project_RM8398/Sample_U5a/U5a_AGTCAA_L002_R1_007.fastq.gz --gam  --out_name ${GAM_PREFIX} --fastq_out --sim_chunks 20 --logFile sim_${NAME}.log --seed 23 --maxCores $THREADS

	 # Make a version of the reads for bwa
	 bgzip -dc ${OS}/${GAM_PREFIX}.fq.gz - | sed 's/fragment_\([0-9]*\)_[0-9]/fragment_\1/g' | bgzip > ${OS}/${GAM_PREFIX}_bwa.fq.gz &
fi

if [ $ALIGN == "1" ]
then
	 # Remap simulated reads to the full graph (takes about 3.5 hours on 32 cores)
	 echo "Mapping simulated reads back to hgsvc graph"
	 time vg map -d ${HGSVC_BASE} -f ${OS}/${GAM_PREFIX}.fq.gz -i  -t $THREADS > ${OS}/${GAM_PREFIX}_remapped.gam
	 time vg gamsort ${OS}/${GAM_PREFIX}_remapped.gam -t $THREADS -i ${OS}/${GAM_PREFIX}_remapped_sorted.gam.gai >  ${OS}/${GAM_PREFIX}_remapped_sorted.gam

	 # Remap simulated reads to the control graph
	 time vg map -d ./controls/primary -f ${OS}/${GAM_PREFIX}.fq.gz -i  -t $THREADS > ${OS}/${GAM_PREFIX}_remapped_primary.gam
	 time vg gamsort ${OS}/${GAM_PREFIX}_remapped_primary.gam -t $THREADS -i ${OS}/${GAM_PREFIX}_remapped_primary_sorted.gam.gai >  ${OS}/${GAM_PREFIX}_remapped_primary_sorted.gam

	 # bwa mapping
	 time bwa mem ./hg38.fa ${OS}/${GAM_PREFIX}_bwa.fq.gz -p -t $THREADS | samtools view -bS - > ${OS}/${GAM_PREFIX}_bwa_remapped.bam
fi

# run the calling and vcf evaluation
rm -rf ${JS} calleval_${NAME}.log; toil-vg calleval ${JS} ${OS}/  --realTimeLogging --chroms ${CHROM} --gams ${OS}/${GAM_PREFIX}_remapped_sorted.gam ${OS}/${GAM_PREFIX}_remapped_primary_sorted.gam --gam_names hgsvc primary --xg_paths ${HGSVC_BASE}.xg ./controls/primary.xg --vcfeval_fasta ${HG38} --vcfeval_baseline ${SAMPLE_VCF}  --vcfeval_opts " --squash-ploidy --Xmax-length 15000" --logFile calleval_${NAME}.log --call  --sample_name ${SAMPLE} --workDir . --maxCores $THREADS --recall --vcfeval_bed_regions $REGIONS --sveval 

# disable freebayes and platypus for now.  they often produce no calls which crashes calleval
#--bams ${OS}/${GAM_PREFIX}_bwa_remapped.bam --bam_names bwa  --freebayes --platypus
