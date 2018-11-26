#!/usr/bin/env python2.7

"""
quick and dirty: count up some GAM sizes
ex:
./filter-counter.py $(for i in $(seq 19 22; echo X; echo Y); do echo s3://cgl-pipeline-inputs/vg_cgl/HGSVC/primary_chroms_gams/HG00514.ERR903030/HG00514_chr${i}.gam; done) --filter-quals 30 60 --filter-paths $(for i in $(seq 1 22; echo X; echo Y); do echo chr${i}; done) --xg s3://cgl-pipeline-inputs/vg_cgl/HGSVC/primary.chroms.xg


"""


import argparse, sys, os, os.path, random, subprocess, shutil, itertools, math, collections

def parse_args(args):
    parser = argparse.ArgumentParser(description=__doc__, 
        formatter_class=argparse.RawDescriptionHelpFormatter)

    parser.add_argument("gam", type=str, nargs='+',
                        help="Input vcf file (- for stdin)")
    parser.add_argument("--filter-quals", type=int, nargs='+', default=[])
    parser.add_argument("--filter-paths", type=str, nargs='+', default=[])
    parser.add_argument("--xg", type=str, help="xg")
                        
    args = args[1:]
    options = parser.parse_args(args)
    return options

def run(cmd):
    sys.stderr.write(cmd + '\n')
    subprocess.check_call(cmd, shell=True)

def readwc(f):
    with open(f, 'r') as ff:
        return int(ff.readline().strip())

def main(args):
    options = parse_args(args)

    # running totals.  0 is the gams, rest are after different filters
    totals = collections.defaultdict(int)

    if options.filter_paths:
        assert len(options.filter_paths) == len(options.gam)
        assert options.xg

    # support for remote xg
    rm_xg = False
    if options.xg and options.xg.startswith('s3://'):
        run('aws s3 cp {} . >/dev/null'.format(options.xg))
        options.xg = os.path.basename(options.xg)
        rm_xg = True
    
    for in_file, filter_path in zip(options.gam, options.filter_paths):
        bname = os.path.basename(in_file)
        
        # copy local
        if in_file.startswith('s3://'):
            run('aws s3 cp {} ./{} > /dev/null'.format(in_file, bname))
            rm_gam = True
            name = bname
        else:
            name = in_file
            rm_gam = False

        # size of gam
        run('vg view -a {} | wc -l > {}.wc-base'.format(name, bname))
        totals['base'] += readwc('{}.wc-base'.format(bname))

        # then the qual filters
        for filter_qual in options.filter_quals:
            run('vg filter {} -q {} | vg view -a - | wc -l > {}.wc-q{}'.format(
                name, filter_qual, bname, filter_qual))
            totals['q{}'.format(filter_qual)] += readwc('{}.wc-q{}'.format(bname, filter_qual))
            
            if options.filter_paths:
                # then the path filters
                run('vg filter {} -q {} -p {} -x {} | vg view -a - | wc -l > {}.wc-q{}-path'.format(
                    name, filter_qual, filter_path, options.xg, bname, filter_qual))
                totals['path-q{}'] += readwc('{}.wc-q{}-path'.format(bname, filter_qual))

        # then the path filters
        run('vg filter {} -p {} -x {} | vg view -a - | wc -l > {}.wc-path'.format(
            name, filter_path, options.xg, bname))
        totals['path'] += readwc('{}.wc-path'.format(bname))
        print totals

        if rm_gam:
            run('rm {}'.format(bname))
    if rm_xg:
        run('rm {}'.format(options.xg))

        

if __name__ == "__main__" :
    sys.exit(main(sys.argv))
