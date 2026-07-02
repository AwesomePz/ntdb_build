#!/usr/local/bin/perl -w

# v8.2
# 1. 删除taxids参数
# 2. 补充多个指定分类库
# 3. 增加-notree参数
# 4. 日志增设运行命令记录

use File::Basename;

#########    pre process    ##########

# set the database
my %db_map = (
    'nt'     => "/Bio/database/ntdb/nt/nt",
#    'm'      => "/Bio/database/microorganism/20230721/micro",
    'bac'    => "/Bio/database/ntdb/ntsub/bac_Bacteria/Bacteria",
    'fish'   => "/Bio/database/ntdb/ntsub/fish_Actinopterygii/Actinopterygii",
    'fungi'  => "/Bio/database/ntdb/ntsub/fungi_Fungi/Fungi",
     );
$ENV{BLASTDB} = "/Bio/database/ntdb/ntsub/bac_Bacteria:/Bio/database/ntdb/ntsub/fungi_Fungi:/Bio/database/ntdb/ntsub/fish_Actinopterygii:/Bio/database/ntdb/nt";

# set the blast software
my $blastn="/home/zpy/software/miniconda3/envs/blast/bin/blastn";
my $blastdb_aliastool="/home/zpy/software/miniconda3/envs/blast/bin/blastdb_aliastool";
# deal with the blast result
my $get_each_fasta="/Bio/pipeline/Species_identity/get_each_tree.pl";
my $spe_cal="/Bio/pipeline/Species_identity/spe.v1.0.pl";

########   get rawdata and make the functions #########

my $help =<<HELP;
\   
\  
\             #################################################################################################################
\             #                                                                                                               #
\             #     对序列进行物种分类                                                                                        #
\             #                                                                                                               #
\             #     使用方法 :                                                                                                #
\             #         1.将序列文件以规定格式上传至 "物种分类" 目录 。                                                       #
\             #           格式 : XXX.zip ; 一个放有所有待测序列（.seq或.txt）文件夹的同名zip压缩包。不要包含特殊字符          #
\             #           注意 : 直接解压后要有一个名为XXX的文件夹                                                            #
\             #         2.在命令行 \$ 后输入 : taxonomy22 XXX.zip                                                              #
\             #         3.看到 "后台进程已启动" ，等待。同时 "物种分类" 目录会生成一个XXX-特殊码.log.txt的文件，该文件记录    #  
\             #           程序运行进度。如果运行完成，会生成一个XXX-特殊码.zip的结果文件，和一个XXX-特殊码.finish的文件。     #    
\             #                                                                                                               #
\             #         查看当前排队情况：taxonomy22 -q                                                                       #
\             #                                                                                                               #
\             #         比对全库 : taxonomy22 example.zip                                                                     #
\             #         比对单个子库：taxonomy22 example.zip fish                                                             #
\             #         比对多个子库：taxonomy22 example.zip fish fungi bac                                                   #
\             #                       鱼类 fish      真菌 fungi      细菌 bac                                                 #
\             #                                                                                                               #
\             #         结果不生成树文件(加快速度)：taxonomy22 example.zip -notree                                            #
\             #                                     taxonomy22 example.zip fish -notree                                       #
\             #                                     taxonomy22 example.zip fish fungi bac -notree                             #
\             #                                                                                                               #
\             #################################################################################################################
\   
\   
HELP

# 第一个参数是zip文件，后面的都是数据库
my $raw_zip = shift @ARGV;
my $notree = 0;
my @libraries;
foreach my $arg (@ARGV) {
    if ($arg eq '-notree') {
        $notree = 1;
    } else {
        push @libraries, $arg;
    }
}
my $root_dir = "/usr/wuhan2/物种分类";
my ($result_dir,$result_name);
my @file_list;
my $taxids_param = "";
die $help if !$raw_zip;

# 处理数据库参数
my $library;  # 最终用于blast的数据库路径
my $combined_db_flag = 0;  # 标记是否使用了合并数据库

if (@libraries == 0) {
    # 没有指定数据库，默认用nt
    $library = $db_map{'nt'};
} elsif (@libraries == 1) {
    # 单个数据库
    $library = $libraries[0];
    if(exists $db_map{$library}){
        $library = $db_map{$library};
    }
} else {
    # 多个数据库，需要合并
    $combined_db_flag = 1;
    my @db_paths;
    foreach my $lib (@libraries) {
        if (exists $db_map{$lib}) {
            push @db_paths, $db_map{$lib};
        } else {
            push @db_paths, $lib;
        }
    }

    # 保存合并参数，在prepare后处理
    my $dblist = join(" ", @db_paths);
    my $combined_title = join("_", @libraries);
    $library = "COMBINED:$dblist:$combined_title";
}

&prepare;
&formatted_seq;
&blast;
&maketree unless $notree;
&get_result;

sub prepare{
    my $full_command = "$0 " . join(" ", @ARGV);
    $raw_zip =~ m/.zip/ or die "你的输入文件不是zip文件\n";
    `unzip -o $root_dir/$raw_zip -d $root_dir`;
    my $rawdata_dir="$root_dir/$raw_zip";
    $rawdata_dir=~s/.zip//;
    # 新纪元时间(Epoch Time)
    my $epoch_time=time();    
    my $pre=$raw_zip;
    $pre=~s/.zip//;
    $result_dir="$root_dir/$pre-$epoch_time";
    `mkdir -p $result_dir`;
    if ($library =~ /^COMBINED:(.+):(.+)$/) {
        my $dblist = $1;
        my $combined_title = $2;
        my $combined_db_path = "$result_dir/combined_db";
        
        my $alias_cmd = "$blastdb_aliastool -dblist \"$dblist\" -dbtype nucl -title \"$combined_title\" -out $combined_db_path";
        `$alias_cmd`;
        
        $library = $combined_db_path;
	$ENV{BLASTDB} = "$result_dir:$ENV{BLASTDB}";
    }
    $result_name="$result_dir/$pre";
    @file_list=(split /\n/,`ls $rawdata_dir/*`);

    open LOG,">$result_dir.log.txt";
    print LOG "$full_command\n";
    print "$full_command\n";
    print "\n";
    print "$pre-$epoch_time 开始分类\n";
    
    # 三个时间：提交时间、开始运行时间、结束时间
    my $submit_time = localtime(time());
    print LOG "提交时间：$submit_time\n";
    print "提交时间：$submit_time\n";
    
    # 任务开始运行时间
    my $start_time = localtime(time());
    print LOG "任务开始运行时间：$start_time\n";
    print "任务开始运行时间：$start_time\n";
}

###################  Start Pipeline

sub formatted_seq
{
    my $fasta_line;
    open FASTA,">$result_dir/combine.fasta.fa";
    
    foreach my $file (@file_list)
    {
        open FI,"$file";
        my $seq=basename($file);
        $fasta_line.=">$seq\n";
        while(<FI>)
        {
            chomp;
            $fasta_line.="$_";
        }
        close FI;
    $fasta_line.="\n";
    }
    print FASTA "$fasta_line";
    close FASTA;
}

sub blast
{
    print LOG "开始比对\n\n";
    print "开始比对\n\n";
    my $outformatted = "6 delim=@ qacc saccver qcovs pident sscinames bitscore evalue stitle qseq sseq";
    my $command_line = "$blastn -num_threads 2 -task megablast -max_target_seqs 200 -max_hsps 1 -query $result_dir/combine.fasta.fa -db $library -outfmt \"$outformatted\" | sed 's/@/\\t/g' | sed -E 's/(([^\\t]*\\t){7}[^\\t]*) >[^\\t]*/\\1/' > $result_dir/raw.blast.result.txt";
`$command_line`;

    `sed -i "1i Query accesion\tSubject accession\tQuery Coverage\tPercentage of identical matches\tScientific Name\tscore\tevalue\tannot\tquery sequence\tsubject sequence" $result_dir/raw.blast.result.txt`;
}

sub maketree{
    my $command_line = "perl $get_each_fasta $result_dir/combine.fasta.fa $result_dir/raw.blast.result.txt $result_dir/tree";
    open SCRIPT,">$result_dir/tree.sh";
    my $script_line =<<TEXT;
    $command_line;
    mkdir -p $result_dir/nwk; 
    mv $result_dir/tree/*nwk $result_dir/nwk/;
    rm $result_dir/nwk/*consensus.nwk -rf;
    rm $result_dir/tree/*txt;
    rm $result_dir/tree/*fasta;
    rm $result_dir/tree/*fa;
TEXT
    print SCRIPT $script_line;
    `sh $result_dir/tree.sh`;
    `rm $result_dir/tree.sh -rf`;
    close SCRIPT;

}

sub get_result
{
    print LOG "开始分类\n\n";
    print "开始分类\n\n";
    my $classify_line .= "perl $spe_cal $result_dir/raw.blast.result.txt $result_dir 10";
    `$classify_line`;
}

if ($combined_db_flag) {
    `rm -f $result_dir/combined_db.nal`;
}

`zip -rqj $result_dir.zip $result_dir`;

my $end_time = localtime(time());
print LOG "任务结束运行时间：$end_time\n";
print "任务结束运行时间：$end_time\n";
print LOG "任务完成 ，你的结果文件为 $result_dir.zip\n\n";
print "任务完成 ，你的结果文件为 $result_dir.zip\n\n";
close LOG;
`touch $result_dir.finish`;

sub say {my $text=shift @_;print "$text\n";}
