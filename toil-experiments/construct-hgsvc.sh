# Construct a graph for hg38 (chromosomes only) from the HGSVC vcf
# EX ./construct-hgsvc.sh -c my-cluster my-jobstore my-bucket/hgsvc

#!/bin/bash

BID=0.83
RESUME=0
REGION="us-west-2"
HEAD_NODE_OPTS=""
INCLUDE_1KG=0
SVPOP=0
INVERSIONS=0

usage() {
    # Print usage to stderr
    exec 1>&2
    printf "Usage: $0 [OPTIONS] <JOBSTORE-NAME> <OUTSTORE-NAME>\n"
	 printf "Arguments:\n"
	 printf "   JOBSTORE-NAME: Name of Toil S3 Jobstore (without any prefix). EX: my-job-store \n"
	 printf "   OUTSTORE-NAME: Name of output bucket (without prefix or trailing slash). EX my-bucket/hgsvc\n"
	 printf "Options:\n"
	 printf "   -b BID  Spot bid in dollars for i3.8xlarge nodes [${BID}]\n"
	 printf "   -r      Resume existing job\n"
	 printf "   -g      Aws region [${REGION}]\n"
	 printf "   -c      Toil Cluster Name (created with https://github.com/vgteam/toil-vg/blob/master/scripts/create-ec2-leader.sh).  Only use if not running from head node.\n"
	 printf "   -k      include thousand genomes VCFs"
	 printf "   -p      use sv-pop instead of HGSVC vcf"
	 printf "   -i      include inversions from sv-pop vcf"
    exit 1
}

while getopts "b:re:c:kpi" o; do
    case "${o}" in
        b)
            BID=${OPTARG}
            ;;
        r)
            RESUME=1
            ;;
		  e)
				REGION=${OPTARG}
				;;
		  c)
				HEAD_NODE_OPTS="-l ${OPTARG}"
				;;
		  k)
				INCLUDE_1KG=1
				;;
		  p)
				SVPOP=1
				;;
		  i)
				INVERSIONS=1
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

# of the form aws:us-west:name
JOBSTORE_NAME="${1}"
shift
OUTSTORE_NAME="${1}"
shift

# pull in ec2-run from git if not found in current dir
wget -nc https://raw.githubusercontent.com/vgteam/toil-vg/master/scripts/ec2-run.sh
chmod 777 ec2-run.sh

# make our vcf
if [ $SVPOP == 0 ]
then
	 pushd ../haps
	 ./make-vcf.sh
	 popd
	 VCF=../haps/HGSVC.haps.vcf.gz
	 NAME=HGSVC
else
	 pushd ../sv-pop-1
	 ./download.sh
	 if [ $INVERSIONS == 0 ]
	 then
		  INV_OPTS="--inv drop"
	 else
		  INV_OPTS="--inv leave"
	 fi
	 ./vcf-add-bed-seqs.py ${INV_OPTS} EEE_SV-Pop_1.ALL.sites.20181204.vcf.gz EEE_SV-Pop_1.ALL.sites.20181204.bed.gz | bgzip > sv-pop.vcf.gz
	 tabix -f -p vcf sv-pop.vcf.gz
	 popd
	 VCF=../sv-pop-1/sv-pop.vcf.gz
	 NAME=SVPOP
fi

# Get our vcf on S3 in our outstore
aws s3 mb s3://${OUTSTORE_NAME} --region ${REGION}
sleep 5
aws s3 cp ${VCF} s3://${OUTSTORE_NAME}/
aws s3 cp ${VCF}.tbi s3://${OUTSTORE_NAME}/
S3VCF="s3://${OUTSTORE_NAME}/$(basename $VCF)"

# without -r we start from scratch!
RESTART_FLAG=""
if [ $RESUME == 0 ]
then
	 toil clean aws:${REGION}:${JOBSTORE_NAME}
else
	 RESTART_FLAG="--restart"
fi

REGIONS="--regions $(for i in $(seq 1 22; echo X; echo Y; echo M); do echo chr${i}; done) --add_chr_prefix"
FASTA="ftp://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz"
# note hgsvc deltions only work with hg38 (not hs38d1) becuase of Y/N mismatch on chr10
#FASTA="ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/GRCh38_reference_genome/GRCh38_full_analysis_set_plus_decoy_hla.fa"

CONTROLS="--pangenome"

if [ $INCLUDE_1KG == 1 ]
then
	 # Pass in a mix of our HGSVC and 1KG vcfs
	 VCFS="$(for i in $(seq 1 22; echo X; echo Y); do echo ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/supporting/GRCh38_positions/ALL.chr${i}_GRCh38.genotypes.20170504.vcf.gz,${S3VCF}; done)"
	 OUT_NAME="${NAME}_1KG"
else
	 # just the HGSVC SVs
	 VCFS="${S3VCF}"
	 OUT_NAME="${NAME}"
	 if [ $SVPOP == 0 ]
	 then
		  CONTROLS="--pos_control HG00514 --haplo_sample HG00514 --neg_control HG00514 --pangenome"
	 fi
fi

if [ $SVPOP == 0 ]
then
	 INDEX_OPTS="--all_index --gbwt_prune"
else
	 INDEX_OPTS="--xg_index --gcsa_index --id_ranges_index --snarls_index --handle_svs"
fi

# run the job
./ec2-run.sh ${HEAD_NODE_OPTS} -n i3.8xlarge:${BID},i3.8xlarge "construct aws:${REGION}:${JOBSTORE_NAME} aws:${REGION}:${OUTSTORE_NAME} --fasta ${FASTA} --vcf ${VCFS}  --out_name ${OUT_NAME} --flat_alts ${ALL_INDEX} ${CONTROLS} --normalize ${REGIONS} ${INDEX_OPTS} --merge_graphs --keep_vcfs --whole_genome_config --logFile construct.${OUT_NAME}.log ${RESTART_FLAG}" | tee construct.${OUT_NAME}.stdout
