#!/usr/bin/env python2.7

"""
Squash pairs of variants of the form
chr1 100 A TT  0/1
chr1 100 A TTT 1/0
to
chr1 100 A TT/TTT 1/2

I think vg construct is indifferent to this, but it's important for vcfeval.
(Assumes there's only one sample in the VCF)
"""


import argparse, sys, os, os.path, random, subprocess, shutil, itertools, math
import vcf, collections

def parse_args(args):
    parser = argparse.ArgumentParser(description=__doc__, 
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("in_vcf", type=str,
                        help="Input vcf file (- for stdin)")
                        
    args = args[1:]
    options = parser.parse_args(args)
    return options

def main(args):
    options = parse_args(args)

    in_stream = sys.stdin if options.in_vcf == '-' else open(options.in_vcf)
    vcf_reader = vcf.Reader(in_stream)
    vcf_writer = vcf.Writer(sys.stdout, vcf_reader)

    prev_record = None
    wrote_prev = False
    
    for record in vcf_reader:

        if prev_record and (record.CHROM, record.POS) == (prev_record.CHROM, prev_record.POS):
            if len(prev_record.ALT) >= 2:
                assert len(prev_record.ALT) == 2
                sys.stderr.write("Warning: Skipping record because 2 have already been found for position:\n{}\n".format(
                    record))
                continue         
                                 
            assert len(record.samples) == 1
            min_common_ref_len = min(len(record.REF), len(prev_record.REF))
            assert record.REF[:min_common_ref_len] == prev_record.REF[:min_common_ref_len]

            assert record.samples[0]['GT'] in ['0|1', '1|0']
            assert prev_record.samples[0]['GT'] in ['0|1', '1|0']

            # normalize to have same reference
            if len(record.REF) > len(prev_record.REF):
                prev_record.REF += record.REF[len(prev_record.REF):]
                prev_record.ALT += record.REF[len(prev_record.REF):]
            elif len(record.REF) < len(prev_record.REF):
                record.REF += prev_record.REF[len(record.REF):]
                record.ALT += prev_record.REF[len(record.REF):]
            
            # merge into record
            record.ALT += prev_record.ALT

            # convert from namedtuple to dict so we can modify
            #data = record.samples[0].data
            #data_dict = data._asdict()
            data_dict = {}
            data_dict['GT'] = "1|2" if record.samples[0]['GT'] == '1|0' else '2|1'
            nt = collections.namedtuple('CallData', ' '.join(data_dict.keys()))(**data_dict)
            record.samples[0].data = nt

            vcf_writer.write_record(record)
            wrote_prev = True
        else:
            if not wrote_prev and prev_record:
                vcf_writer.write_record(prev_record)                
            wrote_prev = False
        
        prev_record = record

    if not wrote_prev and prev_record:
        vcf_writer.write_record(prev_record)

    if options.in_vcf != '-':
        in_stream.close()

if __name__ == "__main__" :
    sys.exit(main(sys.argv))
