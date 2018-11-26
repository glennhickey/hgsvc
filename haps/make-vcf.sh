#!/bin/bash

ls *hap0.vcf.gz | cut -f 1 -d\. | while read base; do echo $base; time vcfcombine <(zcat $base.hap0.vcf.gz | sed s/$base/$base.a/ | sed s%\\./\\.%1% | vcf-sort -c ) <(zcat $base.hap1.vcf.gz | sed s/$base/$base.b/ | sed s%\\./\\.%1% | vcf-sort -c) | vcf-sort -c | vcfnull2ref - | awk 'BEGIN { OFS="\t" } /#CHROM/ { $11="" } /#/ { print } !/#/ { $10=$10"|"$11; $11=""; print }' | sed s/$base.a/$base/g | cut -f -10 | bgziptabix $base.haps.vcf.gz; done

# Make individual VCF for each sample (required for do-by-add.sh)
for SAMPLE in HG00514 HG005733 NA19240; do gzip -dc ${SAMPLE}.haps.vcf.gz | vcfkeepinfo - NA | vcffixup - | hap-flatten.py - | bgziptabix HGSVC.${SAMPLE}.vcf.gz; done

# Merge the samples
bcftools merge -0 HGSVC.HG00514.vcf.gz HGSVC.HG005733.vcf.gz HGSVC.NA19240.vcf.gz | bgziptabix HGSVC.haps.vcf.gz

# vcfcombine drops a lot of stuff.  replacing with bcftools above
#vcfcombine HG00514.haps.vcf.gz HG005733.haps.vcf.gz NA19240.haps.vcf.gz | awk 'BEGIN { OFS = "\t"} $10 == "." { $10 = "0|0" } $11 == "." { $11 = "0|0" } $12 == "." { $12 = "0|0" } { print }' | vcfkeepinfo - NA | vcffixup - | bgziptabix HGSVC.haps.vcf.gz

