aws s3 cp s3://majorsv-ucsc/gt/sv_vcf/reduced.tab .
aws s3 cp s3://majorsv-ucsc/gt/sv_vcf/variants_reduced.vcf.gz.tbi .
aws s3 cp s3://majorsv-ucsc/gt/sv_vcf/variants_reduced.vcf.gz .

vt rminfo variants_reduced.vcf.gz -t END -o pseudo_diploid.vcf
bgzip -f pseudo_diploid.vcf
tabix -f -p vcf pseudo_diploid.vcf.gz


