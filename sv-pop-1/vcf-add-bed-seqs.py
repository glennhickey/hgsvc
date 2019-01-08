#!/usr/bin/env python2.7

"""
Add fully specified SV sequences from a BED file into a VCF.  Input pairs expected to look like these files
http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/hgsv_sv_discovery/working/20181025_EEE_SV-Pop_1/VariantCalls_EEE_SV-Pop_1/EEE_SV-Pop_1.ALL.sites.20181204.vcf.gz
http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/hgsv_sv_discovery/working/20181025_EEE_SV-Pop_1/VariantCalls_EEE_SV-Pop_1/EEE_SV-Pop_1.ALL.sites.20181204.bed.gz

This is a quick (entire BED in memory) and dirty (don't even use pyvcf as it can't parse the above VCF) approach to get the SV's into vg construct.  

"""


import argparse, sys, os, os.path, random, subprocess, shutil, itertools, math
import vcf, collections, gzip, re


def parse_args(args):
    parser = argparse.ArgumentParser(description=__doc__, 
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("vcf", type=str,
                        help="VCF whose SV sequences we want to fill out")
    parser.add_argument("bed", type=str,
                        help="bed file to look sequences up in (by ID)")
    parser.add_argument("--inv", default="leave",
                        choices=["leave", "filter-out", "msnp"],
                        help="leave: leave inversions as they are.  filter-out: remove them. "
                        "msnp: explicitly write as multibase snps")
                        
    args = args[1:]
    options = parser.parse_args(args)
    return options

def bed_header(line):
    """ dict mapping column title to column number
    """
    assert line.strip().startswith('#')
    return dict([(col_name, col_number) for col_number, col_name in enumerate(line.strip()[1:].split('\t'))])

def strip_sv_tags(info):
    """ remove all the SV tags
    """
    res = ['SVTYPE=(DEL|INS|INV)', 'SVLEN=-{0,1}[0-9]+', 'SVSPAN=-{0,1}[0-9]+']
    return re.sub('|'.join([r + ';' for r in res] + [';' + r for r in res]), '', info)

def open_input(file_path):
    open_fn = gzip.open if file_path.endswith('.gz') else open
    return open_fn(file_path, 'r')

def main(args):
    options = parse_args(args)

    if options.inv == 'msnp':
        import pysam
        from Bio.Seq import Seq

    # read the bed into memory
    bed_map = {}
    with open_input(options.bed) as bed_file:
        header_map = bed_header(bed_file.readline())
        for line in bed_file:
            toks = line.strip().split('\t')
            if toks and not toks[0].startswith('#'):
                bed_map[toks[header_map['ID']]] = toks

    # fasta index needed for inversions:
    if options.inv == 'msnp':
        faidx = pysam.FastaFile('ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/GRCh38_reference_genome/'
                                'GRCh38_full_analysis_set_plus_decoy_hla.fa')

    # print the edited vcf
    with open_input(options.vcf) as vcf_file:
        for line in vcf_file:
            if line.startswith('#'):
                sys.stdout.write(line)
            elif line:
                vcf_toks = line.split('\t')
                bed_toks = bed_map[vcf_toks[2]]
                # make sure everything matches up beteween the two files
                vcf_chrom = vcf_toks[0]
                assert vcf_chrom == bed_toks[header_map['CHROM']]
                vcf_pos = int(vcf_toks[1])
                assert vcf_pos - 1 == int(bed_toks[header_map['POS']])
                vcf_sv_type = vcf_toks[4][1:-1]                
                assert vcf_sv_type == bed_toks[header_map['SVTYPE']]

                bed_sv_len = int(bed_toks[header_map['SVLEN']])
                bed_seq = bed_toks[header_map['SEQ']].upper()
                
                # remove SV info tags which will only confuse vg construct -S
                vcf_toks[7] = strip_sv_tags(vcf_toks[7])
                
                # make our SV variant
                if vcf_sv_type == 'DEL':
                    vcf_toks[4] = vcf_toks[3]
                    vcf_toks[3] = bed_seq
                elif vcf_sv_type == 'INS':
                    vcf_toks[4] = vcf_toks[3] + bed_seq
                elif vcf_sv_type == 'INV':                    
                    if options.inv == 'msnp':
                        ref_seq = faidx.fetch(vcf_chrom, vcf_pos - 1, vcf_pos - 1 + bed_sv_len)
                        # assume we wanna keep things in hg38 (as opposed to hs38d1 that we're reading from)
                        ref_seq = ref_seq.replace('Y', 'N').replace('U', 'N')
                        assert ref_seq[0].upper() == vcf_toks[3].upper()
                        vcf_toks[3] = ref_seq
                        vcf_toks[4] = str(Seq(ref_seq).reverse_complement())
                    elif options.inv == 'leave':
                        vcf_toks[7] += ';SVTYPE=INV;SVSPAN={}'.format(bed_sv_len)
                else:
                    assert False

                # write to stdout 
                if vcf_sv_type != 'INV' or options.inv != 'filter-out':
                    sys.stdout.write('\t'.join(vcf_toks))

if __name__ == "__main__" :
    sys.exit(main(sys.argv))
