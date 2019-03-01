#!/usr/bin/env python2.7

"""
Make sure the REFs are correct. 
"""


import argparse, sys, os, os.path, random, subprocess, shutil, itertools, math
import vcf, collections

import pysam
from Bio.Seq import Seq

def parse_args(args):
    parser = argparse.ArgumentParser(description=__doc__, 
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("vcf", type=str,
                        help="Input vcf file")
    parser.add_argument("--inline", action="store_true",
                        help="Embed inversion ans multibase snp")
                        
    args = args[1:]
    options = parser.parse_args(args)
    return options

def main(args):
    options = parse_args(args)

    faidx = pysam.FastaFile('ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/GRCh38_reference_genome/'
                            'GRCh38_full_analysis_set_plus_decoy_hla.fa')

    with open(options.vcf) if options.vcf != '-' else sys.stdin as vcf_file:
        reader1 = vcf.Reader(vcf_file)
        vcf_writer = vcf.Writer(sys.stdout, reader1)
        i = 0

        for record1 in reader1:
            if record1.INFO['SVTYPE'] == 'INV':
                # assume we're only working with 0/1 and 1/1 calls
                assert len(record1.ALT) == 1
                record1.REF = faidx.fetch(record1.CHROM, record1.POS - 1, record1.POS)

                if options.inline:
                    #embed the inversion right after POS (following vg convention)
                    ref_seq = faidx.fetch(record1.CHROM, record1.POS, record1.POS + int(record1.INFO['SVLEN']))
                    # assume we wanna keep things in hg38 (as opposed to hs38d1 that we're reading from)
                    ref_seq = ref_seq.replace('Y', 'N').replace('U', 'N')
                    alt_seq = str(Seq(ref_seq).reverse_complement())
                    ref_base = record1.REF
                    record1.REF = ref_base + ref_seq
                    record1.ALT[0] =  ref_base + alt_seq
                    del record1.INFO['SVTYPE']
                    del record1.INFO['SVLEN']
                    del record1.INFO['END']
                
            vcf_writer.write_record(record1)            

if __name__ == "__main__" :
    sys.exit(main(sys.argv))
