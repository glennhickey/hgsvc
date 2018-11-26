
#!/bin/bash

base=$1
ref=./hg38.fa
vars=./HGSVC.haps.vcf.gz

#chroms=$(cat $ref.fai | cut -f 1)
#chroms=$(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}; done)
chroms=chr21

echo "constructing"
echo $chroms | tr ' ' '\n' | parallel -j 10 "vg construct -r $ref -v $vars -R {} -C -m 32 -a -f | vg mod -n - | vg mod -X 32 - > $base.{}.vg"

echo "node id unification"
vg ids -j -m $base.mapping $(for i in $chroms; do echo $base.$i.vg; done)
cp $base.mapping $.base.mapping.backup

echo "indexing haplotypes"
echo $chroms | tr ' ' '\n' | parallel -j 10 "vg index -x $base.{}.xg -G $base.{}.gbwt -v $vars -F $base.{}.threads $base.{}.vg"

echo "merging GBWT"
vg gbwt -m -f -o $base.all.gbwt $(for i in $chroms; do echo $base.$i.gbwt; done)

echo "extracting threads as paths"
for i in $chroms; do ( vg mod $(for f in $(vg paths -L -x $base.$i.xg ); do echo -n ' -r '$f; done) $base.$i.vg; vg paths -x $base.$i.xg -g $base.$i.gbwt -T -V ) | vg view -v - >$base.$i.threads.vg; done

echo "re-indexing haps+threads"
vg index -x $base.threads.xg $(for i in $chroms; do echo $base.$i.threads.vg; done)

echo "building gcsa2 index"
mkdir -p work
TMPDIR=. vg index -g $base.threads.gcsa -k 16 -p -b work -t 15 $(for i in $chroms; do echo $base.$i.threads.vg; done)
