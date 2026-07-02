#!/usr/bin/env bash

set -e

source /home/zpy/software/miniconda3/etc/profile.d/conda.sh
DEST=/home/zpy/Project/ntdb/nt_20260527
NUM=317

conda activate axel
mkdir -p $DEST && cd $DEST

wget -c https://ftp.ncbi.nlm.nih.gov/blast/db/{nt-nucl-metadata.json,taxdb-metadata.json,taxdb.tar.gz,taxdb.tar.gz.md5}

for i in $(seq 0 $NUM); do
    axel -c -n 8 https://ftp.ncbi.nlm.nih.gov/blast/db/nt.$(printf %03d $i).tar.gz
    axel -c -n 4 https://ftp.ncbi.nlm.nih.gov/blast/db/nt.$(printf %03d $i).tar.gz.md5
done

FAILED=0
TOTAL=0

for i in $(seq 0 $NUM); do
    filename="nt.$(printf %03d $i).tar.gz"
    TOTAL=$((TOTAL + 1))
    [[ ! -f "$filename" || ! -f "$filename.md5" ]] && { echo "✗ $filename: Missing"; FAILED=$((FAILED+1)); continue; }
    [[ $(md5sum "$filename" | awk '{print $1}') != $(awk '{print $1}' "$filename.md5") ]] && { echo "✗ $filename: MD5 mismatch"; FAILED=$((FAILED+1)); }
done

TOTAL=$((TOTAL + 1))
taxdb="taxdb.tar.gz"
if [[ ! -f "$taxdb" || ! -f "$taxdb.md5" ]]; then
    echo "✗ $taxdb: Missing"
    FAILED=$((FAILED+1))
elif [[ $(md5sum "$taxdb" | awk '{print $1}') != $(awk '{print $1}' "$taxdb.md5") ]]; then
    echo "✗ $taxdb: MD5 mismatch"
    FAILED=$((FAILED+1))
else
    echo "✓ $taxdb: OK"
fi

echo "Total: $TOTAL, Failed: $FAILED"

if [[ $FAILED -eq 0 ]]; then
    echo "✓ All files verified successfully! Starting extraction..."
    
    echo "解压 nt ..."
    ls nt.[0-9][0-9][0-9].tar.gz 2>/dev/null | \
        xargs -P 8 -I {} sh -c 'echo "解压 {} ..." && tar -xvzf "{}"'
    
    if [[ -f "taxdb.tar.gz" ]]; then
        echo "解压 taxdb.tar.gz ..."
        tar -xvzf taxdb.tar.gz
    fi
    
    echo "✓ Extraction completed successfully!"
else
    echo "✗ Some files failed verification. Extraction aborted."
    conda deactivate
    exit 1
fi

# 确认文件下载无误后再执行
#for i in $(seq 0 $NUM); do
#    filename="nt.$(printf %03d $i).tar.gz"
#    rm -rf $filename
#    rm -rf $filename.md5
#done

conda deactivate
