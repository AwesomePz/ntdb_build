#!/bin/bash

# 以真菌为例
#mkdir fungi_Fungi && cd fungi_Fungi/
#blastdbcmd -db nt -taxids 4751 -outfmt "%a %T" > Fungi_map.txt
#blastdbcmd -db nt -taxids 4751 -outfmt "%f" > Fungi.fa
#sed -i 's/ \([0-9]\+\)$/\t\1/' Fungi_map.txt
#makeblastdb -in Fungi.fa -dbtype nucl -parse_seqids -taxid_map Fungi_map.txt -out Fungi
#blastdbcmd -db Fungi -entry all -outfmt "%a %T %S" | head -5 # 验证有无拉丁名
#ln -s /home/zpy/Project/ntsub/fungi_Fungi/* /home/zpy/Project/ntsub/00.allsub/
#rm -rf Fungi_map.txt Fungi.fa # 内存不够可以删

source /home/zpy/software/miniconda3/etc/profile.d/conda.sh
conda activate blast

BASE="/home/zpy/Project/ntsub"
NT="nt"
P=1

DBS=(
"bac|Bacteria|2"
"fish|Actinopterygii|7898"
"fungi|Fungi|4751"
)

build() {
local s=$(echo $1|cut -d'|' -f1)
local f=$(echo $1|cut -d'|' -f2)
local t=$(echo $1|cut -d'|' -f3)
local d="$BASE/${s}_${f}"
local o="$d/$f"

[ -f "$o.nal" ] && { echo "[skip] ${s}_${f}"; return; }

mkdir -p "$d" && cd "$d"
blastdbcmd -db $NT -taxids $t -outfmt "%a %T" -out ${f}_map.txt
blastdbcmd -db $NT -taxids $t -outfmt "%f" -out ${f}.fa
sed -i 's/ \([0-9]\+\)$/\t\1/' ${f}_map.txt
makeblastdb -in ${f}.fa -dbtype nucl -parse_seqids -taxid_map ${f}_map.txt -out $f
ln -sf $d/* $ALL/
echo "[done] ${s}_${f}"
}

printf "%s\n" "${DBS[@]}" | xargs -P $P -I {} bash -c 'build "$@"' _ {}

conda deactivate
