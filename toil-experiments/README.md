### HG00514 Whole Genome Experiment

## Setup
The following environment variables need to be set
```
# jobstore prefix: EX my-jobstore
export JOBSTORE=glennhickey-jobstore-hn
# outstore: EX my-outstore/HGSVC
export OUTSTORE=glennhickey/outstore/HGSVC-chroms-dec5
# cluster name prefix EX: my-cluster where my-cluster1 and my-cluster2 were already created with toil-vg/scripts/create-ec2-leader.sh
export CLUSTER=glenn-hn
# BED file for evaluation
export COMPARE_REGIONS_BED=s3://vg-data/HGSVC/hg38_non_repeats.bed
# interleaved fq template for simulation error model
export TEMPLATE_FQ=s3://vg-data/HGSVC/reads/HG00514/ERR903030_1st_10M_interleaved.fq.gz
# input reads 1
export FQ1=s3://vg-data/HGSVC/reads/HG00514/ERR903030_1.fastq.gz
# input reads 2
export FQ2=s3://vg-data/HGSVC/reads/HG00514/ERR903030_2.fastq.gz

```

## Running
```
# Construct all graphs and indexes.  Haploid vcfs from ../haps/haps.urls must have been downloaded into ../haps
./construct-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}

# Simulate a GAM and fastq from the two HG00514 haplotypes
./simulate-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/sim s3://${OUTSTORE}/HGSVC.chroms_HG00514_haplo_thread_0.xg s3://${OUTSTORE}/HGSVC.chroms_HG00514_haplo_thread_1.xg ${TEMPLATE_FQ}

# Map real and simulated reads against both the HGSVC and HG00514 (positive graph)
./map-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/map-sim-HG00514  s3://${OUTSTORE}/HGSVC.chroms HG00514-sim-map s3://${OUTSTORE}/sim/sim-HG00514-30x.fq.gz

./map-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/map-sim-HG00514-pc  s3://${OUTSTORE}/HGSVC.chroms_HG00514 HG00514-sim-map-pos-control s3://${OUTSTORE}/sim/sim-HG00514-30x.fq.gz

./map-hgsvc.sh -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/map-HG00514  s3://${OUTSTORE}/HGSVC.chroms HG00514-ERR903030-map ${FQ1} ${FQ2}

./map-hgsvc.sh -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/map-HG00514-pc s3://${OUTSTORE}/HGSVC.chroms_HG00514 HG00514-ERR903030-map-pos-control ${FQ1} ${FQ2}

# Call a VCF for each GAM, including the simulated "Truth" GAM
./call-hgsvc.sh -c ${CLUSTER}1 -f ./call_conf_truth.yaml ${JOBSTORE}1 ${OUTSTORE}/call-sim-HG00514-truth s3://${OUTSTORE}/HGSVC.chroms_HG00514_haplo.xg HG00514 s3://${OUTSTORE}/sim/sim-HG00514-30x-sorted.gam

./call-hgsvc.sh -c ${CLUSTER}1 -f ./call_conf.yaml ${JOBSTORE}1 ${OUTSTORE}/call-sim-HG00514 s3://${OUTSTORE}/HGSVC.chroms.xg HG00514 s3://${OUTSTORE}/map-sim-HG00514/HG00514-sim-map_chr

./call-hgsvc.sh -c ${CLUSTER}1 -f ./call_conf.yaml ${JOBSTORE}1 ${OUTSTORE}/call-sim-HG00514-pc s3://${OUTSTORE}/HGSVC.chroms.xg HG00514 s3://${OUTSTORE}/map-sim-HG00514-pc/HG00514-sim-map-pos-control_chr

./call-hgsvc.sh -c ${CLUSTER}2 -f ./call_conf.yaml ${JOBSTORE}2 ${OUTSTORE}/call-HG00514-pc s3://${OUTSTORE}/HGSVC.chroms.xg HG00514 s3://${OUTSTORE}/map-sim-HG00514-pc/HG00514-ERR903030-map-pos-control_chr

./call-hgsvc.sh -c ${CLUSTER}2 -f ./call_conf.yaml ${JOBSTORE}2 ${OUTSTORE}/call-HG00514 s3://${OUTSTORE}/HGSVC.chroms.xg HG00514 s3://${OUTSTORE}/map-HG00514/HG00514-ERR903030-map_chr

# Do comparisons on called VCFs and download results locally
./eval-hgsvc.sh -d -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/eval-sim-HG00514-truth s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-sim-HG00514-truth/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/eval-sim-HG00514 s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-sim-HG00514/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/eval-sim-HG00514-pc s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-sim-HG00514-pc/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/eval-HG00514 s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-HG00514/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/eval-HG00514-pc s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-HG00514-pc/HG00514.vcf.gz ${COMPARE_REGIONS_BED}
```
