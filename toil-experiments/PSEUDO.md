
# make the CHM-PSEUDODIPLOID graph
./construct-hgsvc.sh -s -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/CHMPD-feb12

# map the 30x reads

./mce-hgsvc.sh -c ${CLUSTER}3 ${JOBSTORE}3 ${OUTSTORE}/CHMPD-feb12 s3://${OUTSTORE}/CHMPD-feb12/CHMPD PSEUDOSET PSEUDOSET-30 s3://${OUTSTORE}/CHMPD-feb12/pseudo_diploid-explicit.vcf.gz ${COMPARE_REGIONS_BED} s3://majorsv-ucsc/gt/gam/aln_30x.gam
#done

mkdir pseudo-results-feb12
aws s3 sync s3://${OUTSTORE}/CHMPD-feb12/eval-PSEUDOSET-30 ./pseudo-results-feb12/CHMPD-feb12-eval-PSEUDOSET-30


# then do the SMRTSV that we copied from courtyard
# note that we made it explicit with
# ./make-explicit.py PSEUDOSET-smrtsv.vcf.gz --fasta ~/dev/work/references/hg38.fa.gz  | vcfkeepinfo - NA | vcffixup - | bgzip > PSEUDOSET-smrtsv-explicit.vcf.gz

./eval-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1x ${OUTSTORE}/CHMPD-feb12/eval-PSEUDOSET-30-smrtsv s3://${OUTSTORE}/CHMPD-feb12/pseudo_diploid-explicit.vcf.gz  s3://glennhickey/outstore/CHMPD-feb12/call-PSEUDOSET-30-smrtsv/PSEUDOSET-smrtsv.explicit.vcf.gz ${COMPARE_REGIONS_BED} PSEUDOSET

aws s3 sync s3://${OUTSTORE}/CHMPD-feb12/eval-PSEUDOSET-30-smrtsv ./CHMPD-jan10-eval-PSEUDOSET-smrtsv
aws s3 sync s3://${OUTSTORE}/CHMPD-feb12/eval-PSEUDOSET-30 ./CHMPD-jan10-eval-PSEUDOSET


