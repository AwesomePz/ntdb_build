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
#ALL="$BASE/00.allsub"
NT="nt"
P=1

DBS=(
#"amphi|Amphibia|8292"
"bac|Bacteria|2"
#"bird|Aves|8782"
"fish|Actinopterygii|7898"
"fungi|Fungi|4751"
#"insect|Arthropoda|6656"
#"moll|Mollusca|6447"
#"plant|Viridiplantae|33090"
)

build() {
local s=$(echo $1|cut -d'|' -f1)
local f=$(echo $1|cut -d'|' -f2)
local t=$(echo $1|cut -d'|' -f3)
local d="$BASE/${s}_${f}"
local o="$d/$f"

[ -f "$o.nal" ] && { echo "[skip] ${s}_${f}"; return; }

#mkdir -p "$ALL"
mkdir -p "$d" && cd "$d"
blastdbcmd -db $NT -taxids $t -outfmt "%a %T" -out ${f}_map.txt
blastdbcmd -db $NT -taxids $t -outfmt "%f" -out ${f}.fa
sed -i 's/ \([0-9]\+\)$/\t\1/' ${f}_map.txt
makeblastdb -in ${f}.fa -dbtype nucl -parse_seqids -taxid_map ${f}_map.txt -out $f
ln -sf $d/* $ALL/
echo "[done] ${s}_${f}"
}

#build_rept() {
#local d="$BASE/rept_reptilia"
#local o="$d/reptilia"

#[ -f "$o.nal" ] && { echo "[skip] rept_reptilia"; return; }

#mkdir -p $d && cd $d
#for t in "Lepidosauria|8504" "Testudines|8459" "Crocodylia|1294634"; do
#    name=$(echo $t|cut -d'|' -f1)
#    taxid=$(echo $t|cut -d'|' -f2)
#    blastdbcmd -db $NT -taxids $taxid -outfmt "%a %T" -out ${name}_map.txt
#    blastdbcmd -db $NT -taxids $taxid -outfmt "%f" -out ${name}.fa
#done

#cat Lepidosauria.fa Testudines.fa Crocodylia.fa > reptilia.fa
#cat Lepidosauria_map.txt Testudines_map.txt Crocodylia_map.txt > reptilia_map.txt
#sed -i 's/ \([0-9]\+\)$/\t\1/' reptilia_map.txt
#makeblastdb -in reptilia.fa -dbtype nucl -parse_seqids -taxid_map reptilia_map.txt -out reptilia

#ln -sf $d/* $ALL/
#echo "[done] rept_reptilia"
#}

#export -f build build_rept
#export BASE ALL NT

# 并行构建普通库
printf "%s\n" "${DBS[@]}" | xargs -P $P -I {} bash -c 'build "$@"' _ {}
# 构建爬行类
#build_rept

#blastdb_aliastool -dblist "Amphibia Aves Actinopterygii Arthropoda Mollusca reptilia" -dbtype nucl -title "animal" -out $ALL/animal
#blastdb_aliastool -dblist "Amphibia Bacteria Aves Actinopterygii Fungi Arthropoda Mollusca Viridiplantae reptilia" -dbtype nucl -title "all" -out $ALL/all

#echo ""
#ls $ALL

conda deactivate

#检查确认无误后删除
#for fa in *_*/*.fa; do rm -rf "$fa"; done
#for map in *_*/*_map.txt; do rm -rf "$map"; done
