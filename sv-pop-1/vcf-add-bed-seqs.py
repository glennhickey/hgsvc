#!/usr/bin/env python2.7

"""
Add fully specified SV sequences from a BED file into a VCF.  Input pairs expected to look like these files
http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/hgsv_sv_discovery/working/20181025_EEE_SV-Pop_1/VariantCalls_EEE_SV-Pop_1/EEE_SV-Pop_1.ALL.sites.20181204.vcf.gz
http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/data_collections/hgsv_sv_discovery/working/20181025_EEE_SV-Pop_1/VariantCalls_EEE_SV-Pop_1/EEE_SV-Pop_1.ALL.sites.20181204.bed.gz

This is a quick (entire BED in memory) and dirty (don't even use pyvcf as it can't parse the above VCF) approach to get the SV's into vg construct.  

"""


import argparse, sys, os, os.path, random, subprocess, shutil, itertools, math
import vcf, collections, gzip

def parse_args(args):
    parser = argparse.ArgumentParser(description=__doc__, 
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("vcf", type=str,
                        help="VCF whose SV sequences we want to fill out")
    parser.add_argument("bed", type=str,
                        help="bed file to look sequences up in (by ID)")
    parser.add_argument("--no-inv", action="store_true",
                        help="Ignore inversions")
                        
    args = args[1:]
    options = parser.parse_args(args)
    return options


def bed_header(line):
    """ dict mapping column title to column number
    """
    assert line.strip().startswith('#')
    return dict([(col_name, col_number) for col_number, col_name in enumerate(line.strip()[1:].split('\t'))])

def open_input(file_path):
    open_fn = gzip.open if file_path.endswith('.gz') else open
    return open_fn(file_path, 'r')

def main(args):
    options = parse_args(args)

    # read the bed into memory
    bed_map = {}
    with open_input(options.bed) as bed_file:
        header_map = bed_header(bed_file.readline())
        for line in bed_file:
            toks = line.strip().split('\t')
            if toks and not toks[0].startswith('#'):
                bed_map[toks[header_map['ID']]] = toks

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
                vcf_pos = vcf_toks[1]
                assert int(vcf_pos) - 1 == int(bed_toks[header_map['POS']])
                vcf_sv_type = vcf_toks[4][1:-1]                
                assert vcf_sv_type == bed_toks[header_map['SVTYPE']]

                if vcf_sv_type == 'DEL':
                    vcf_toks[4] = vcf_toks[3]
                    vcf_toks[3] = bed_toks[header_map['SEQ']]
                elif vcf_sv_type in ['INS', 'INV']:
                    vcf_toks[4] = bed_toks[header_map['SEQ']]
                else:
                    assert False

                if vcf_sv_type != 'INV' or not options.no_inv:
                    sys.stdout.write('\t'.join(vcf_toks))

if __name__ == "__main__" :
    sys.exit(main(sys.argv))
