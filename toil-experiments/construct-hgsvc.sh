# Construct a graph for hg38 (chromosomes only) from the HGSVC vcf
# EX ./construct-hgsvc.sh -c my-cluster my-jobstore my-bucket/hgsvc

#!/bin/bash

BID=0.83
RESUME=0
REGION="us-west-2"
HEAD_NODE_OPTS=""

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
    exit 1
}

while getopts "b:re:c:" o; do
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
aws s3 cp ${VCF} s3://${OUTSTORE_NAME}/HGSVC.haps.vcf.gz
aws s3 cp ${VCF}.tbi s3://${OUTSTORE_NAME}/HGSVC.haps.vcf.gz.tbi

# without -r we start from scratch! 
if [ $RESUME == 0 ]
then
	 toil clean aws:${REGION}:${JOBSTORE_NAME}
fi

# run the job
./ec2-run.sh ${HEAD_NODE_OPTS} -n i3.8xlarge:${BID},i3.8xlarge "construct aws:${REGION}:${JOBSTORE_NAME} aws:${REGION}:${OUTSTORE_NAME} --fasta http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz --vcf s3://${OUTSTORE_NAME}/HGSVC.haps.vcf.gz --out_name HGSVC.chroms --pangenome --flat_alts --xg_index --gcsa_index --gbwt_index --gbwt_prune --id_ranges_index --pos_control HG00514 --haplo_sample HG00514 --normalize --regions $(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}; done) --whole_genome_config --logFile construct.hgsvc.chroms.log" | tee construct.hgsvc.stdout
