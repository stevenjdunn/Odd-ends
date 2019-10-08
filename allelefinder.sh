#!/bin/bash
grep $1 *.tab | cut -f 2,3,4,5,11 | sed '/snp/!d' | sort | uniq -c | sort -r -s -n -k 1,1
