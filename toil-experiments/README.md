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
#  chunk_context: [2000]
#
#call_conf.yaml has:
#  filter-opts: []
#  augment-opts: []
#  recall-opts: ['-u', '-n', '0']
#  chunk_context: [2000]

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
./construct-hgsvc.sh -k -n -a 0.01 -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14

# Map real reads against the HGSVC+1KG graph
./map-hgsvc.sh -c ${CLUSTER}1 ${JOBSTORE}1  ${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/map-HG00514 s3://${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/HGSVC_1KG-no-unfold  HG00514-ERR903030-map $FQ1 $FQ2

# Call a VCF for each GAM
./call-hgsvc.sh -c ${CLUSTER}1 -f ./call_conf.yaml ${JOBSTORE}1 ${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/call-HG00514 s3://${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/HGSVC_1KG-no-unfold.xg HG00514 s3://${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/map-HG00514/HG00514-ERR903030-map_chr

# Do comparisons on called VCFs and download results locally
./eval-hgsvc.sh -d -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/eval-HG00514 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/call-HG00514/HG00514.vcf.gz ${COMPARE_REGIONS_BED}

```

## SV-pop graph
```
# Construct the graph and index for svpop (15 sv samples) including inversions
./construct-hgsvc.sh -p -i -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/SVPOP-jan10

# Map real reads against the SVPOP graph
./map-hgsvc.sh -c ${CLUSTER}2 ${JOBSTORE}2  ${OUTSTORE}/SVPOP-jan10/map-HG00514 s3://${OUTSTORE}/SVPOP-jan10/SVPOP  HG00514-ERR903030-map $FQ1 $FQ2

# Call
./call-hgsvc.sh -c ${CLUSTER}2 -f ./call_conf.yaml ${JOBSTORE}2 ${OUTSTORE}/SVPOP-jan10/call-HG00514 s3://${OUTSTORE}/SVPOP-jan10/SVPOP.xg HG00514 s3://${OUTSTORE}/SVPOP-jan10/map-HG00514/H G00514-ERR903030-map_chr

```

## SV-pop graph with 1kg
```
# Construct the graph and index for svpop (15 sv samples) including inversions and 1kg variants
./construct-hgsvc.sh -a 0.01 -k -p -i -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/SVPOP-1KG-AF01-JAN15

# Map real reads against the SVPOP+1KG graph
./map-hgsvc.sh -c ${CLUSTER}3 ${JOBSTORE}3  ${OUTSTORE}/SVPOP-1KG-AF01-JAN15/map-HG00514 s3://${OUTSTORE}/SVPOP-1KG-AF01-JAN15/SVPOP_1KG  HG00514-ERR903030-map $FQ1 $FQ2

./call-hgsvc.sh -c ${CLUSTER}3 -f ./call_conf.yaml ${JOBSTORE}3 ${OUTSTORE}/SVPOP-1KG-AF01-JAN15/call-HG00514 s3://${OUTSTORE}/SVPOP-1KG-AF01-JAN15/SVPOP_1KG.xg HG00514 s3://${OUTSTORE}/SVPOP-1KG-AF01-JAN15/map-HG00514/HG00514-ERR903030-map_chr

```

### redos (TODO: clean up readme.  use mce everywhere?)

# simulation:

./mce-hgsvc.sh -c ${CLUSTER}1 -C " -f ./call_conf.yaml"   ${JOBSTORE}1 ${OUTSTORE}/HGSVC-jan5 s3://${OUTSTORE}/HGSVC-jan5/HGSVC HG00514 HG00514-sim s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} s3://${OUTSTORE}/HGSVC-chroms-dec5/sim/sim-HG00514-30x.fq.gz

./mce-hgsvc.sh -c ${CLUSTER}2 -C " -f ./call_conf.yaml"   ${JOBSTORE}2 ${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14 s3://${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/HGSVC_1KG-no-unfold HG00514 HG00514-sim s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} s3://${OUTSTORE}/HGSVC-chroms-dec5/sim/sim-HG00514-30x.fq.gz

./mce-hgsvc.sh -c ${CLUSTER}3 -C " -f ./call_conf.yaml"   ${JOBSTORE}3 ${OUTSTORE}/SVPOP-jan10 s3://${OUTSTORE}/SVPOP-jan10/SVPOP HG00514 HG00514-sim s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} s3://${OUTSTORE}/HGSVC-chroms-dec5/sim/sim-HG00514-30x.fq.gz

./mce-hgsvc.sh -c ${CLUSTER}4 -C " -f ./call_conf.yaml"   ${JOBSTORE}4 ${OUTSTORE}/SVPOP-1KG-AF01-JAN15/ s3://${OUTSTORE}/SVPOP-1KG-AF01-JAN15/SVPOP_1KG HG00514 HG00514-sim s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} s3://${OUTSTORE}/HGSVC-chroms-dec5/sim/sim-HG00514-30x.fq.gz


# real (skip mapping)

./mce-hgsvc.sh -c ${CLUSTER}1 -C " -f ./call_conf.yaml"   ${JOBSTORE}1 ${OUTSTORE}/HGSVC-jan5 s3://${OUTSTORE}/HGSVC-jan5/HGSVC HG00514 HG00514 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} $FQ1 $FQ2

./mce-hgsvc.sh -c ${CLUSTER}2 -C " -f ./call_conf.yaml"   ${JOBSTORE}2 ${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14 s3://${OUTSTORE}/HGSVC-1KG-AF01-NO-UNFOLD-JAN14/HGSVC_1KG-no-unfold HG00514 HG00514 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} $FQ1 $FQ2

./mce-hgsvc.sh -c ${CLUSTER}3 -C " -f ./call_conf.yaml"   ${JOBSTORE}3 ${OUTSTORE}/SVPOP-jan10 s3://${OUTSTORE}/SVPOP-jan10/SVPOP HG00514 HG00514 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} $FQ1 $FQ2

./mce-hgsvc.sh -c ${CLUSTER}4 -C " -f ./call_conf.yaml"   ${JOBSTORE}4 ${OUTSTORE}/SVPOP-1KG-AF01-JAN15/ s3://${OUTSTORE}/SVPOP-1KG-AF01-JAN15/SVPOP_1KG HG00514 HG00514 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz ${COMPARE_REGIONS_BED} $FQ1 $FQ2

# Polaris sample to compare with SVPOP



# make report
mkdir results-jan26
#for name in HGSVC-jan5 HGSVC-1KG-AF01-NO-UNFOLD-JAN14 SVPOP-jan10 SVPOP-1KG-AF01-JAN15
for name in HGSVC-jan5
do
aws s3 sync s3://${OUTSTORE}/${name}/eval-HG00514 ./results-jan26/${name}-eval-HG00514
aws s3 sync s3://${OUTSTORE}/${name}/eval-HG00514-sim ./results-jan26/${name}-eval-HG00514-sim
#aws s3 sync s3://${OUTSTORE}/${name}/eval-HG00514-bayestyper-full ./results-jan26/${name}-eval-HG00514-bayestyper
#aws s3 sync s3://${OUTSTORE}/${name}/eval-HG00514-sim-bayestyper-full ./results-jan26/${name}-eval-HG00514-sim-bayestyper
#aws s3 sync s3://${OUTSTORE}/${name}/eval-HG00514-sim-bayestyper-feb20 ./results-jan26/${name}-eval-HG00514-sim-bayestyper-feb20
#aws s3 sync s3://${OUTSTORE}/${name}/eval-HG00514-bayestyper-feb20 ./results-jan26/${name}-eval-HG00514-bayestyper-feb20
#aws s3 sync s3://${OUTSTORE}/${name}/eval-HG00514-bayestyper-manta-feb20 ./results-jan26/${name}-eval-HG00514-bayestyper-manta-feb20
done

cd results-jan26
for c in sveval-clip-norm sveval-clip sveval sveval-norm
do
rm -f ${c}.tsv ${c}-sim.tsv
for i in `find . | grep ${c}/sv_accuracy.tsv | grep -v sim`; do echo $i >> ${c}.tsv; cat $i >> ${c}.tsv; done
for i in `find . | grep ${c}/sv_accuracy.tsv | grep sim`; do echo $i >> ${c}-sim.tsv; cat $i >> ${c}-sim.tsv; done
done


# Bayestyper

./eval-hgsvc.sh  -c ${CLUSTER}1 ${JOBSTORE}1  ${OUTSTORE}/HGSVC-jan5/eval-HG00514-bayestyper-full s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/HGSVC-Bayestyper/ERR903030_hgsvc_platypus_bayestyper_pass_nomis_maxgpp.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh  -c ${CLUSTER}2 ${JOBSTORE}2  ${OUTSTORE}/HGSVC-jan5/eval-HG00514-sim-bayestyper-full s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/HGSVC-Bayestyper/HG00514_sim30x_hgsvc_platypus_bayestyper_pass_nomis_maxgpp.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh  -c ${CLUSTER}2 ${JOBSTORE}2  ${OUTSTORE}/HGSVC-jan5/eval-HG00514-sim-bayestyper-feb20 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/HGSVC-Bayestyper/HG00514_sim30x_hgsvc_bayestyper_pass_nomis-feb20.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh  -c ${CLUSTER}2 ${JOBSTORE}2  ${OUTSTORE}/HGSVC-jan5/eval-HG00514-bayestyper-manta-feb20 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/HGSVC-Bayestyper/ERR903030_hgsvc_pp_hc_mt_bayestyper_pass_nomis_feb20.vcf.gz ${COMPARE_REGIONS_BED}

./eval-hgsvc.sh  -c ${CLUSTER}2 ${JOBSTORE}2  ${OUTSTORE}/HGSVC-jan5/eval-HG00514-bayestyper-feb20 s3://${OUTSTORE}/HGSVC-jan5/HGSVC-vcfs/HGSVC.haps_HG00514.vcf.gz s3://${OUTSTORE}/HGSVC-Bayestyper/ERR903030_hgsvc_pp_bayestyper_pass_nomis_feb20.vcf.gz ${COMPARE_REGIONS_BED}


# Try making HGSVC alt graphs
./construct-hgsvc.sh -l s3://glennhickey/grch38/grch38-alt-positions-no-hla-no-chr6_GL000251v2_alt.bed -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/HGSVC-alts-feb18

./construct-hgsvc.sh -k -n -l s3://glennhickey/grch38/grch38-alt-positions-no-hla-no-chr6_GL000251v2_alt.bed -c ${CLUSTER}3 ${JOBSTORE}3 ${OUTSTORE}/HGSVC-1kg-alts-feb18

# Inversions

./mce-hgsvc.sh -c ${CLUSTER}1 -C " -f ./call_conf.yaml"   ${JOBSTORE}1 ${OUTSTORE}/HGSVC-INV-JAN29 s3://${OUTSTORE}/HGSVC-INV-JAN29/HGSVC HG00514 HG00514-sim s3://${OUTSTORE}/HGSVC-INV-JAN29/HGSVC-vcfs/HGSVC.inv_HG00514.vcf.gz ${COMPARE_REGIONS_BED} s3://${OUTSTORE}/HGSVC-INV-JAN29/sim/sim-HG00514-30x.fq.gz

./mce-hgsvc.sh -c ${CLUSTER}2 -C " -f ./call_conf.yaml"   ${JOBSTORE}2 ${OUTSTORE}/HGSVC-INV-JAN29 s3://${OUTSTORE}/HGSVC-INV-JAN29/HGSVC HG00514 HG00514 s3://${OUTSTORE}/HGSVC-INV-JAN29/HGSVC-vcfs/HGSVC.inv_HG00514.vcf.gz ${COMPARE_REGIONS_BED} $FQ1 $FQ2

./construct-hgsvc.sh -i -c ${CLUSTER}1 ${JOBSTORE}1 ${OUTSTORE}/HGSVC-INV-FEB26

# SVPOP again

./mce-hgsvc.sh -c ${CLUSTER}2 -M SKIP  -C " -f ./call_conf.yaml"   ${JOBSTORE}2 ${OUTSTORE}/SVPOP-jan10 s3://${OUTSTORE}/SVPOP-jan10/SVPOP HG00514 HG00514 s3://${OUTSTORE}/SVPOP-jan10/sv-pop-explicit.vcf.gz ${COMPARE_REGIONS_BED} $FQ1 $FQ2

aws s3 sync s3://${OUTSTORE}/SVPOP-jan10/eval-HG00514 ./SVPOP-jan10-eval-HG00514

# then do the SMRTSV that we copied from courtyard
./eval-hgsvc.sh -c ${CLUSTER}2 ${JOBSTORE}2 ${OUTSTORE}/SVPOP-jan10/eval-HG00514-smrtsv s3://${OUTSTORE}/SVPOP-jan10/sv-pop-explicit.vcf.gz  s3://glennhickey/outstore/SVPOP-jan10/call-HG00514-smrtsv/HG00514-smrtsv.shift.vcf.gz ${COMPARE_REGIONS_BED} HG00514

aws s3 sync s3://${OUTSTORE}/SVPOP-jan10/eval-HG00514-smrtsv ./SVPOP-jan10-eval-HG00514-smrtsv

