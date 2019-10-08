#!/bin/bash
sed 's/c./\t/g' $1 | cut -f 5 | sort | uniq -c
