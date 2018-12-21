### HG00514 Whole Genome Experiment

## Setup
The following environment variables need to be set
```
# jobstore prefix: EX my-jobstore
export JOBSTORE=
# outstore: EX my-outstore/HGSVC
export OUTSTORE=
# cluster name prefix EX: my-cluster where my-cluster1 and my-cluster2 were already created with toil-vg/scripts/create-ec2-leader.sh
export CLUSTER=
# BED file for evaluation
export COMPARE_REGIONS_BED=
# interleaved fq template for simulation error model
export TEMPLATE_FQ=
# input reads 1
export FQ1=
# input reads 2
export FQ2=

```

## Running
```
# Construct all graphs and indexes.  Haploid vcfs from ../haps/haps.urls must have been downloaded into ../haps
./construct-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}

# Simulate a GAM and fastq from the two HG00514 haplotypes
./simulate-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/sim s3://${OUTSTORE}/HGSVC.chroms_HG00514_haplo_thread_0.xg s3://${OUTSTORE}/HGSVC.chroms_HG00514_haplo_thread_1.xg ${TEMPLATE_FQ}

# Map real and simulated reads against both the HGSVC and HG00514 graph (positive control)
./map-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/map-sim-HG00514  s3://${OUTSTORE}/HGSVC.chroms HG00514-sim-map s3://${OUTSTORE}/sim/sim-HG00514-30x.fq.gz

./map-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/map-sim-HG00514-pc  s3://${OUTSTORE}/HGSVC.chroms_HG00514 HG00514-sim-map-pos-control s3://${OUTSTORE}/sim/sim-HG00514-30x.fq.gz

./map-hgsvc.sh -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/map-HG00514  s3://${OUTSTORE}/HGSVC.chroms HG00514-ERR903030-map ${FQ1} ${FQ2}

./map-hgsvc.sh -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/map-HG00514-pc s3://${OUTSTORE}/HGSVC.chroms_HG00514 HG00514-ERR903030-map-pos-control ${FQ1} ${FQ2}

# Call a VCF for each GAM, including the simulated "Truth" GAM

# call_conf_truth.yaml is made with toil-vg generate-config --whole_genome then setting
# (note that toil-vg may set the container to None in your config if you don't have Docker locally.
# in this case, it needs to be set back to Docker)
#  filter-opts: []
#  augment-opts: ['-M']
#  recall-opts: ['-u', '-n', '0', '-T']
#
#call_conf.yaml has:
#  filter-opts: []
#  augment-opts: []
#  recall-opts: ['-u', '-n', '0']

./call-hgsvc.sh -c ${CLUSTER}1 -f ./call_conf_truth.yaml ${JOBSTORE}1 ${OUTSTORE}/call-sim-HG00514-truth s3://${OUTSTORE}/HGSVC.chroms_HG00514_haplo.xg HG00514 s3://${OUTSTORE}/sim/sim-HG00514-30x.gam

./call-hgsvc.sh -c ${CLUSTER}1 -f ./call_conf.yaml ${JOBSTORE}1 ${OUTSTORE}/call-sim-HG00514 s3://${OUTSTORE}/HGSVC.chroms.xg HG00514 s3://${OUTSTORE}/map-sim-HG00514/HG00514-sim-map_chr

./call-hgsvc.sh -c ${CLUSTER}1 -f ./call_conf.yaml ${JOBSTORE}1 ${OUTSTORE}/call-sim-HG00514-pc s3://${OUTSTORE}/HGSVC.chroms_HG00514.xg HG00514 s3://${OUTSTORE}/map-sim-HG00514-pc/HG00514-sim-map-pos-control_chr

./call-hgsvc.sh -c ${CLUSTER}2 -f ./call_conf.yaml ${JOBSTORE}2 ${OUTSTORE}/call-HG00514 s3://${OUTSTORE}/HGSVC.chroms.xg HG00514 s3://${OUTSTORE}/map-HG00514/HG00514-ERR903030-map_chr

./call-hgsvc.sh -c ${CLUSTER}2 -f ./call_conf.yaml ${JOBSTORE}2 ${OUTSTORE}/call-HG00514-pc s3://${OUTSTORE}/HGSVC.chroms_HG00514.xg HG00514 s3://${OUTSTORE}/map-HG00514-pc/HG00514-ERR903030-map-pos-control_chr

# Do comparisons on called VCFs and download results locally
./eval-hgsvc.sh -d -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/eval-sim-HG00514-truth s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-sim-HG00514-truth/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/eval-sim-HG00514 s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-sim-HG00514/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/eval-sim-HG00514-pc s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-sim-HG00514-pc/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/eval-HG00514 s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-HG00514/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh -d -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/eval-HG00514-pc s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-HG00514-pc/HG00514.vcf.gz ${COMPARE_REGIONS_BED}
```

## Mixing in Variants from Thousand Genomes

```
# Construct graph and index for HGSVC+1KG variatns.  Haploid vcfs from ../haps/haps.urls must have been downloaded into ../haps
./construct-hgsvc.sh -k -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}

# Map real reads against the HGSVC+1KG graph
./map-hgsvc.sh -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/map-1kg-HG00514 s3://${OUTSTORE}/HGSVC_1KG_minaf_0.01 HG00514-ERR903030-map-1kg ${FQ1} ${FQ2}

# Call a VCF for each GAM
./call-hgsvc.sh -c ${CLUSTER}2 -f ./call_conf.yaml ${JOBSTORE}2 ${OUTSTORE}/call-1kg-HG00514 s3://${OUTSTORE}/HGSVC_1KG_minaf_0.01.xg HG00514 s3://${OUTSTORE}/map-1kg-HG00514/HG00514-ERR903030-map-1kg

# Do comparisons on called VCFs and download results locally
./eval-hgsvc.sh -d -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/eval-1kg-HG00514 s3://${OUTSTORE}/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/call-1kg-HG00514/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

```
