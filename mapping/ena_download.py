#!/usr/bin/env python2.7

import os, sys
import multiprocessing, subprocess

# get the addresses
file_map = {}
with open("ena_reads.tsv") as urls_file:
    for line in urls_file:
        toks = line.split()
        if len(toks) > 3:
            file_map[toks[0]] = toks[3:]

procs = []
for name, urls in file_map.items()[:1]:
    try:
        os.makedirs(name)
    except:
        pass
    for url in urls:
        download_cmd = "wget -q -c {} -O {}".format(url, os.path.join(name, os.path.basename(url)))
        upload_cmd = "aws s3 cp {} {}".format(os.path.join(name, os.path.basename(url)),
                                              os.path.join("s3://glennhickey/SIMONS", name, os.path.basename(url)))
        rm_cmd = "rm -rf {}".format(os.path.join(name, os.path.basename(url)))
                                              
        procs.append(subprocess.Popen("{}; {}; {}".format(download_cmd, upload_cmd, rm_cmd), shell=True))

for proc in procs:
    proc.wait()
