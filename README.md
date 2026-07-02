# Species idenetty
本文档适用于批量下载nt库，并依据taxids构建nt子库；blast批量比对nt库和nt子库

## 下载数据库
- sh download_nt.sh
- sh download_ntsub.sh

## blast
- 比对nt库：sh taxonomy.sh example.zip
- 比对子库：sh taxonomy.sh example.zip fish
- 不生成树文件：sh taxonomy.sh example.zip -notree
