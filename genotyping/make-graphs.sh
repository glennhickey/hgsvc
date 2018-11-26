# Make some indexes for bwa and primary graph controls

#!/bin/bash

#wget http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
#gzip -d hg38.fa.gz
HG38=../haps/hg38.fa 

#chroms=$(cat $ref.fai | cut -f 1)
#chroms=$(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}; done)
chroms=chr21
#HG38=../haps/hg38_chr21.fa 

#Make graphs and indexes including the regular graph and the primary and the positive control
rm -rf jsc ; toil-vg construct ./jsc ./graphs --fasta ${HG38} --vcf ../haps/HGSVC.haps.vcf.gz  --region ${chroms} --realTimeLogging  --xg_index --gcsa_index --out_name hgsvc.norm --flat_alts --normalize  --workDir . --gcsa_index_cores 20 --whole_genome_config --gbwt_index --gbwt_prune --primary --pangenome --pos_control HG00514

#Make a bwa index
bwa index ${HG38} -p ./graphs/hg38.fa

