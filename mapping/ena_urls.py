#!/usr/bin/env python2.7

import os, sys

# map id to sample id
sample_map = {}
with open('sample-id-map.tsv') as map_file:
    for line in map_file:
        toks = line.split()
        sample_map[toks[1].lower()] = toks[0]
sample_map['k'] = 'ERR1347703'
    
# map id to illumina code thingie
other_map = {}
with open('sgdp_metadata.tsv') as sgdp_file:
    for line in sgdp_file:
        toks = line.split()
        other_map[toks[3].lower()] = toks[1]
        other_map[''.join(toks[3].lower().split('_'))] = toks[1]
other_map['chi'] = 'LP6005443-DNA_B07'


# map id to ena url
with open('audano-table.tsv') as table_file:
    for line in table_file:
        toks = line.split()
        table_id = toks[0]
        if len(table_id.split('_')) > 2:
            name = table_id.split('_')[2]
            if name.lower() in sample_map:
                print '{}\t{}\thttps://www.ebi.ac.uk/ena/data/view/{}'.format(table_id, name, sample_map[name.lower()])
            elif name.lower() in other_map:
                print '{}\t{}\thttps://www.ebi.ac.uk/ena/data/search?query={}'.format(table_id, name, other_map[name.lower()])
            else:
                sys.stderr.write("Could not find {}->{} in table\n".format(table_id, name))


        
        
