# Construct a graph for hg38 (chromosomes only) from the HGSVC vcf
# EX ./construct-hgsvc.sh -c my-cluster my-jobstore my-bucket/hgsvc

#!/bin/bash

BID=0.83
RESUME=0
REGION="us-west-2"
HEAD_NODE_OPTS=""
INCLUDE_1KG=0

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
    exit 1
}

while getopts "b:re:c:k" o; do
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
pushd ../haps
./make-vcf.sh
popd
VCF=../haps/HGSVC.haps.vcf.gz

# Get our vcf on S3 in our outstore
aws s3 mb s3://${OUTSTORE_NAME} --region ${REGION}
sleep 5
aws s3 cp ${VCF} s3://${OUTSTORE_NAME}/
aws s3 cp ${VCF}.tbi s3://${OUTSTORE_NAME}/

# without -r we start from scratch!
RESTART_FLAG=""
if [ $RESUME == 0 ]
then
	 toil clean aws:${REGION}:${JOBSTORE_NAME}
else
	 RESTART_FLAG="--restart"
fi

if [ $INCLUDE_1KG == 1 ]
then
	 REGIONS=" --add_chr_prefix --fasta_regions --ignore_regions_keywords _alt HLA-"
	 # Pass in a mix of our HGSVC and 1KG vcfs
	 VCFS="$(for i in $(seq 1 22; echo X; echo Y); do echo ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/supporting/GRCh38_positions/ALL.chr${i}_GRCh38.genotypes.20170504.vcf.gz,${VCF}; done)"
	 FASTA="ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/technical/reference/GRCh38_reference_genome/GRCh38_full_analysis_set_plus_decoy_hla.fa"
	 OUT_NAME="HGSVC_1KG"
	 CONTROLS="--min_af 0.01"
else
	 REGIONS="--regions $(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}; done)"
	 VCFS="s3://${OUTSTORE_NAME}/$(basename $VCF)"
	 FASTA="http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz"
	 OUT_NAME="HGSVC.chroms"
	 CONTROLS="--pos_control HG00514 --haplo_sample HG00514 --neg_control HG00514 --pangenome"
fi

# run the job
./ec2-run.sh ${HEAD_NODE_OPTS} -n i3.8xlarge:${BID},i3.8xlarge "construct aws:${REGION}:${JOBSTORE_NAME} aws:${REGION}:${OUTSTORE_NAME} --fasta ${FASTA} --vcf ${VCFS} --out_name ${OUT_NAME} --flat_alts --xg_index --gcsa_index --gbwt_index --gbwt_prune --id_ranges_index ${CONTROLS} --normalize ${REGIONS} --whole_genome_config --logFile construct.${OUT_NAME}.log ${RESTART_FLAG}" | tee construct.${OUT_NAME}.stdout
