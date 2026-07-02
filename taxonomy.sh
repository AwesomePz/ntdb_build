#!/bin/bash

# v1.0

PERL_SCRIPT="/Bio/pipeline/Species_identity/Species_identity.pl"
QUEUE_DIR="/tmp/taxonomy_queue"
MAX_TASKS=2
QUEUE_FILE="$QUEUE_DIR/queue.txt"
DAEMON_LOG="$QUEUE_DIR/daemon.log"

# 初始化队列目录
mkdir -p "$QUEUE_DIR" 2>/dev/null
chmod 777 "$QUEUE_DIR" 2>/dev/null || true

# 启动守护进程
start_daemon() {
    # 检查守护进程是否已在运行
    if ! pgrep -f "TAXONOMY_DAEMON_MARKER" > /dev/null 2>&1; then
        (
            # 这个标记用于 pgrep 检测
            TAXONOMY_DAEMON_MARKER=1
	    idle_count=0
            while true; do
                running_tasks=$(ps -aux | grep "Species_identity\.pl" | grep -v grep | grep -v "sh -c" | wc -l)
                
                if [ "$running_tasks" -lt "$MAX_TASKS" ] && [ -s "$QUEUE_FILE" ]; then
                    next_task=$(head -n 1 "$QUEUE_FILE")
                    if [ -n "$next_task" ]; then
                        sed -i '1d' "$QUEUE_FILE"
                        set -- $next_task
                         nohup perl "$PERL_SCRIPT" "$@" > /dev/null 2>&1 &
			 echo "[$(date '+%Y-%m-%d %H:%M:%S')] 队列任务已启动，参数: $*，PID: $!" >> "$DAEMON_LOG"
			 idle_count=0 
                    fi
		else
		    idle_count=$((idle_count + 1))
                    if [ "$idle_count" -gt 60 ] && [ ! -s "$QUEUE_FILE" ]; then
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 守护进程空闲超时，自动退出" >> "$DAEMON_LOG"
                        break
                    fi
                fi
                sleep 10
            done
        ) &
        disown
    fi
}

# 显示队列状态
show_queue() {
    echo "=== 运行中的任务 ==="
    ps -aux | grep "Species_identity\.pl" | grep -v grep | grep -v "sh -c" | while read -r line; do
        # 提取参数部分（perl脚本路径后面的所有内容）
        args=$(echo "$line" | sed 's/.*Species_identity\.pl //')
        if [ -n "$args" ]; then
            echo "  $args"
        else
            echo "  (无参数)"
        fi
    done
    
    echo ""
    echo "=== 队列中的任务 ==="
    if [ -s "$QUEUE_FILE" ]; then
        while IFS= read -r line; do
            # 将制表符替换为空格显示
            echo "  $(echo "$line" | tr '\t' ' ')"
        done < "$QUEUE_FILE"
    else
        echo ""
    fi
}

# 主逻辑
main() {
    # 检查 -q 参数
    if [ "$1" = "-q" ]; then
        show_queue
        exit 0
    fi
    
    # 1. 无参数时显示帮助文档
    if [ $# -eq 0 ]; then
        perl "$PERL_SCRIPT"
        exit 0
    fi
    
    touch "$QUEUE_FILE" "$DAEMON_LOG" 2>/dev/null
    chmod 777 "$QUEUE_FILE" "$DAEMON_LOG" 2>/dev/null || true
    
    # 启动守护进程
    start_daemon

    # 2. 有参数时检查任务数量
    current_tasks=$(ps -aux | grep "Species_identity\.pl" | grep -v grep | grep -v "sh -c" | wc -l)
    
    if [ "$current_tasks" -lt "$MAX_TASKS" ]; then
        # 2.1 任务数小于2，直接后台运行
        nohup perl "$PERL_SCRIPT" "$@" > /dev/null 2>&1 &
        echo "后台进程已启动，PID: $!"
    else
        # 2.2 任务数大于等于2，加入队列
        queue_count=$(wc -l < "$QUEUE_FILE" 2>/dev/null || echo 0)
        echo "当前有$MAX_TASKS/$MAX_TASKS个任务正在运行，前方有 $queue_count 个任务正在排队，等待..."
        echo "无需重复提交"
        echo "$*" >> "$QUEUE_FILE"
    fi
}

main "$@"
