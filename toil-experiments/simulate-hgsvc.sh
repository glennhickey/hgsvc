# Simulate 30X coverage for the Construct a graph for hg38 (chromosomes only) from the HGSVC vcf
# EX ./simulate-hgsvc.sh -c my-cluster my-jobstore my-bucket/hgsvc/sim/ s3://my-bucket/hgsvc/HGSVC.chroms_HG00514_haplo_thread_0.xg  s3://my-bucket/hgsvc/HGSVC.chroms_HG00514_haplo_thread_1.xg s3://my-bucket/interleaved.fq

#!/bin/bash

BID=0.53
RESUME=0
REGION="us-west-2"
HEAD_NODE_OPTS=""

usage() {
    # Print usage to stderr
    exec 1>&2
    printf "Usage: $0 [OPTIONS] <JOBSTORE-NAME> <OUTSTORE-NAME> <HAPLO-XG0> <HAPLO-XG1> <TEMPLATE-FQ>\n"
	 printf "Arguments:\n"
	 printf "   JOBSTORE-NAME: Name of Toil S3 Jobstore (without any prefix). EX: my-job-store \n"
	 printf "   OUTSTORE-NAME: Name of output bucket (without prefix or trailing slash). EX my-bucket/hgsvc\n"
	 printf "   HAPLO-XG0:     Full path to xg for haplotype 0\n"
	 printf "   HAPLO-XG2:     Full path to xg for haplotype 1\n"
	 printf "   TEMPLATE-FQ:   Full path to interleaved fastq file to use as template\n"
	 printf "Options:\n"
	 printf "   -b BID  Spot bid in dollars for r3.8xlarge nodes [${BID}]\n"
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

if [[ "$#" -lt "5" ]]; then
    # Too few arguments
    usage
fi

# of the form aws:us-west:name
JOBSTORE_NAME="${1}"
shift
OUTSTORE_NAME="${1}"
shift
XG0_PATH="${1}"
shift
XG1_PATH="${1}"
shift
TEMPLATE_PATH="${1}"
shift

# pull in ec2-run from git if not found in current dir
wget -nc https://raw.githubusercontent.com/vgteam/toil-vg/master/scripts/ec2-run.sh
chmod 777 ec2-run.sh

# without -r we start from scratch! 
if [ $RESUME == 0 ]
then
	 toil clean aws:${REGION}:${JOBSTORE_NAME}
fi

CMD="sim aws:${REGION}:${JOBSTORE_NAME} s3://vg-data/HGSVC/HGSVC.chroms_HG00514_haplo_thread_0.xg  s3://vg-data/HGSVC/HGSVC.chroms_HG00514_haplo_thread_1.xg 256000000  aws:${REGION}:${OUTSTORE_NAME} --out_name sim-HG00514-30x --gam --fastq_out --fastq  ${TEMPLATE_PATH} --sim_opts \"-p 570 -v 165 -i 0.002 -I\" --sim_chunks 1000 --seed 1 --whole_genome_config --logFile simulate.hgsvc.log"

# run the job
./ec2-run.sh ${HEAD_NODE_OPTS} -m 50 -n r3.8xlarge:${BID},r3.8xlarge "${CMD}" | tee sim.hgsvc.stdout

