# Map reads to hgsvc graph
# EX ./map-hgsvc.sh -c my-cluster my-jobstore my-bucket/hgsvc/map s3://my-bucket/hgsvc/HGSVC.chroms hgsvc.chroms.map.HG00514 s3://my-bucket/hgsvc/sim/sim-HG00514-30x.fq.gz

#!/bin/bash

BID=0.53
RESUME=0
REGION="us-west-2"
HEAD_NODE_OPTS=""
MPMAP=0

usage() {
    # Print usage to stderr
    exec 1>&2
    printf "Usage: $0 [OPTIONS] <JOBSTORE-NAME> <OUTSTORE-NAME> <INDEX-BASE> <NAME> <FASTQ1> [FASTQ2]\n"
	 printf "Arguments:\n"
	 printf "   JOBSTORE-NAME: Name of Toil S3 Jobstore (without any prefix). EX: my-job-store \n"
	 printf "   OUTSTORE-NAME: Name of output bucket (without prefix or trailing slash). EX my-bucket/hgsvc\n"
	 printf "   INDEX-BASE:    Full path of indexes minus the file extension\n"
	 printf "   NAME:          Name of output file\n"
	 printf "   FASTQ1:        Path of fastq reads (assume interleaved if FASTQ2 not given)\n"
	 printf "   FASTQ2:        Path of fastq reads (optional)\n"
	 printf "Options:\n"
	 printf "   -b BID  Spot bid in dollars for r3.8xlarge nodes [${BID}]\n"
	 printf "   -r      Resume existing job\n"
	 printf "   -g      Aws region [${REGION}]\n"
	 printf "   -c      Toil Cluster Name (created with https://github.com/vgteam/toil-vg/blob/master/scripts/create-ec2-leader.sh).  Only use if not running from head node.\n"
	 printf "   -m      use mpmap instead of map.\n"
    exit 1
}

while getopts "b:re:c:m" o; do
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
		  m)
				MPMAP=1
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
INDEX_BASE="${1}"
shift
NAME="${1}"
shift
READS1="${1}"
shift
READS2="${1}"
shift

# assume interleaved if READS2 not given
if [ -z ${READS2} ]
then
	 READS_OPTS="--fastq ${READS1} --interleaved"
else
	 READS_OPTS="--fastq ${READS1} ${READS2}"
fi

# pull in ec2-run from git if not found in current dir
wget -nc https://raw.githubusercontent.com/vgteam/toil-vg/master/scripts/ec2-run.sh
chmod 777 ec2-run.sh

# without -r we start from scratch!
RESTART_FLAG=""
if [ $RESUME == 0 ]
then
	 toil clean aws:${REGION}:${JOBSTORE_NAME}
else
	 RESTART_FLAG="--restart"
fi

MAP_OPTS=""
if [ $MPMAP == 1 ]
then
	 MAP_OPTS="--multipath"
fi

# run the job
./ec2-run.sh ${HEAD_NODE_OPTS} -m 50 -n r3.8xlarge:${BID},r3.8xlarge "map aws:${REGION}:${JOBSTORE_NAME} ${NAME} ${INDEX_BASE}.xg ${INDEX_BASE}.gcsa aws:${REGION}:${OUTSTORE_NAME} --id_ranges ${INDEX_BASE}_id_ranges.tsv ${READS_OPTS} ${MAP_OPTS} --whole_genome_config --logFile map.hgsvc.log --reads_per_chunk 5000000 --logFile map.hgsvc.log ${RESTART_FLAG}" | tee map.hgsvc.$(basename ${OUTSTORE_NAME}).stdout

