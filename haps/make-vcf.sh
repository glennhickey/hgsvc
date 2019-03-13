#!/bin/bash

# Make individual VCF for each sample (required for do-by-add.sh)
for SAMPLE in HG00514 HG00733 NA19240
do
	 # Make diploid VCF out of haploid vcfs:
	 echo "Making diploid VCF for ${SAMPLE}"
	 ./hap-merge.py ${SAMPLE}.hap0.vcf.gz ${SAMPLE}.hap1.vcf.gz | vcfuniq | vcfkeepinfo - NA | vcffixup - | bgzip > HGSVC.${SAMPLE}.vcf.gz
	 tabix -f -p vcf HGSVC.${SAMPLE}.vcf.gz
done

# Merge the samples
echo "Making merged VCF for all samples"
bcftools merge -0 HGSVC.HG00514.vcf.gz HGSVC.HG005733.vcf.gz HGSVC.NA19240.vcf.gz | sed -e 's/0\/0/0\|0/g' | bgzip > HGSVC.haps.vcf.gz
tabix -f -p vcf HGSVC.haps.vcf.gz



