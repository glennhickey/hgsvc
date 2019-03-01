#!/bin/bash

# vg construct can't handle huge sv's when --alt-paths used.  there are only a few and we trim them
# with this cutoff until crash is fixed
MAX_SV_LEN=20000

set -x

# This VCF came from Peter.  It seems to be missing the GT column so we add it. 
bcftools view SimpleInversionList_v3.vcf.gz -h -O z > SimpleInversionList_v3_fix.vcf.gz
bcftools view -H SimpleInversionList_v3.vcf.gz |  awk -F'\t' ' BEGIN { OFS = "\t" } $8 = $8 FS "GT"' |  bgzip >> SimpleInversionList_v3_fix.vcf.gz
tabix -f -p vcf SimpleInversionList_v3_fix.vcf.gz

# Then we extract our samples.  also do length filter and add reference bases with fix-inv.py
bcftools view SimpleInversionList_v3_fix.vcf.gz -s HG00514,HG00733,NA19240 --trim-alt-alleles  -i "SVLEN<=${MAX_SV_LEN}" | ./fix-inv.py - | grep -P -v "0/0\t0/0\t0/0" | bgzip > SimpleInversionList_v3_samples.vcf.gz
tabix -f -p vcf SimpleInversionList_v3_samples.vcf.gz

# Same thing but keep the inversions as multibase snps (this helps the sveval with not crashing)
bcftools view SimpleInversionList_v3_fix.vcf.gz -s HG00514,HG00733,NA19240 --trim-alt-alleles  -i "SVLEN<=${MAX_SV_LEN}" | ./fix-inv.py - --inline | grep -P -v "0/0\t0/0\t0/0" | bgzip > SimpleInversionList_v3_samples_inline.vcf.gz
tabix -f -p vcf SimpleInversionList_v3_samples_inline.vcf.gz
rm -f SimpleInversionList_v3_fix.vcf.gz*

# Then we stick them into the the rest of the VCF and hope nothing breaks
bcftools view HGSVC.haps.vcf.gz | sed 's/HG005733/HG00733/g' | bgzip > HGSVC.haps_fix.vcf.gz
tabix -f -p vcf HGSVC.haps_fix.vcf.gz

bcftools concat -a HGSVC.haps_fix.vcf.gz SimpleInversionList_v3_samples.vcf.gz  > concat.vcf
vcfsort concat.vcf | vcfuniq | vcfkeepinfo - NA SVTYPE END | vcffixup - | bgzip > HGSVC.haps.inv.vcf.gz
tabix -f -p vcf HGSVC.haps.inv.vcf.gz

# and again with the inline version
bcftools concat -a HGSVC.haps_fix.vcf.gz SimpleInversionList_v3_samples_inline.vcf.gz  > concat.vcf
vcfsort concat.vcf | vcfuniq | vcfkeepinfo - NA SVTYPE END | vcffixup - | bgzip > HGSVC.haps.inv.inline.vcf.gz
tabix -f -p vcf HGSVC.haps.inv.inline.vcf.gz

rm -f concat.vcf

