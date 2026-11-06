#!/bin/bash

# 格式转换HTML工具 - 工具函数库
# 提供通用功能和错误处理

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/conversion.log"
CONFIG_FILE="$SCRIPT_DIR/config/config.json"

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")"

# 日志函数
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[INFO]${NC} $message"
    echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
}

log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS]${NC} $message"
    echo "[$timestamp] [SUCCESS] $message" >> "$LOG_FILE"
}

log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARNING]${NC} $message"
    echo "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} $message" >&2
    echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
}

log_debug() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $message"
    fi
    echo "[$timestamp] [DEBUG] $message" >> "$LOG_FILE"
}

# 进度显示函数
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local percentage=$((current * 100 / total))
    local bar_length=50
    local filled_length=$((percentage * bar_length / 100))
    
    # 创建进度条
    local bar=""
    local i
    for ((i=0; i<filled_length; i++)); do
        bar+="█"
    done
    for ((i=filled_length; i<bar_length; i++)); do
        bar+="░"
    done
    
    printf "\r${CYAN}[PROGRESS]${NC} [%s] %d%% (%d/%d) %s" "$bar" "$percentage" "$current" "$total" "$message"
    
    if [[ $current -eq $total ]]; then
        echo  # 换行
    fi
}

# 检查依赖项
check_dependencies() {
    log_info "检查系统依赖项..."
    
    local missing_deps=()
    
    # 检查Pandoc
    if ! command -v pandoc &> /dev/null; then
        missing_deps+=("pandoc")
    fi
    
    # 检查jq (用于JSON处理)
    if ! command -v jq &> /dev/null; then
        log_warning "jq未安装，将使用基础JSON解析"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必要依赖项: ${missing_deps[*]}"
        log_info "请运行 ./install.sh 安装依赖项"
        return 1
    fi
    
    log_success "所有依赖项检查通过"
    return 0
}

# 验证文件路径
validate_file_path() {
    local file_path="$1"
    local file_type="$2"  # input 或 output
    
    if [[ -z "$file_path" ]]; then
        log_error "文件路径不能为空"
        return 1
    fi
    
    if [[ "$file_type" == "input" ]]; then
        if [[ ! -f "$file_path" ]]; then
            log_error "输入文件不存在: $file_path"
            return 1
        fi
        
        if [[ ! -r "$file_path" ]]; then
            log_error "输入文件不可读: $file_path"
            return 1
        fi
    elif [[ "$file_type" == "output" ]]; then
        local output_dir=$(dirname "$file_path")
        if [[ ! -d "$output_dir" ]]; then
            log_info "创建输出目录: $output_dir"
            mkdir -p "$output_dir" || {
                log_error "无法创建输出目录: $output_dir"
                return 1
            }
        fi
        
        if [[ ! -w "$output_dir" ]]; then
            log_error "输出目录不可写: $output_dir"
            return 1
        fi
    fi
    
    return 0
}

# 获取文件扩展名
get_file_extension() {
    local file_path="$1"
    echo "${file_path##*.}"
}

# 获取文件名（不含扩展名）
get_file_basename() {
    local file_path="$1"
    local filename=$(basename "$file_path")
    echo "${filename%.*}"
}

# 检查HTML文件有效性
validate_html_file() {
    local html_file="$1"
    
    if [[ ! -f "$html_file" ]]; then
        log_error "HTML文件不存在: $html_file"
        return 1
    fi
    
    # 检查文件扩展名
    local extension=$(get_file_extension "$html_file")
    if [[ ! "$extension" =~ ^(html|htm)$ ]]; then
        log_warning "文件扩展名不是HTML格式: $html_file"
    fi
    
    # 检查文件是否为空
    if [[ ! -s "$html_file" ]]; then
        log_error "HTML文件为空: $html_file"
        return 1
    fi
    
    # 基础HTML结构检查
    if ! grep -qi "<html\|<body\|<div\|<p\|<h[1-6]" "$html_file"; then
        log_warning "文件可能不包含有效的HTML内容: $html_file"
    fi
    
    return 0
}

# 读取配置文件
read_config() {
    local key="$1"
    local default_value="$2"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "配置文件不存在，使用默认值"
        echo "$default_value"
        return
    fi
    
    # 如果有jq，使用jq解析
    if command -v jq &> /dev/null; then
        local value=$(jq -r ".$key // \"$default_value\"" "$CONFIG_FILE" 2>/dev/null)
        echo "$value"
    else
        # 简单的grep解析（不够健壮，但可用）
        local value=$(grep "\"$key\"" "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/' 2>/dev/null)
        if [[ -z "$value" ]]; then
            echo "$default_value"
        else
            echo "$value"
        fi
    fi
}

# 创建临时目录
create_temp_dir() {
    local temp_dir="$SCRIPT_DIR/temp/$(date +%Y%m%d_%H%M%S)_$$"
    mkdir -p "$temp_dir"
    echo "$temp_dir"
}

# 清理临时文件
cleanup_temp() {
    local temp_dir="$1"
    if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
        log_debug "清理临时目录: $temp_dir"
        rm -rf "$temp_dir"
    fi
}

# 文件大小格式化
format_file_size() {
    local size_bytes="$1"
    
    if [[ $size_bytes -lt 1024 ]]; then
        echo "${size_bytes}B"
    elif [[ $size_bytes -lt 1048576 ]]; then
        echo "$((size_bytes / 1024))KB"
    elif [[ $size_bytes -lt 1073741824 ]]; then
        echo "$((size_bytes / 1048576))MB"
    else
        echo "$((size_bytes / 1073741824))GB"
    fi
}

# 获取文件信息
get_file_info() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    local size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
    local formatted_size=$(format_file_size "$size")
    local modified=$(stat -f%Sm -t"%Y-%m-%d %H:%M:%S" "$file_path" 2>/dev/null || stat -c%y "$file_path" 2>/dev/null | cut -d'.' -f1)
    
    echo "文件: $(basename "$file_path")"
    echo "大小: $formatted_size"
    echo "修改时间: $modified"
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local line_number=$1
    local command="$2"
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "命令执行失败 (退出码: $exit_code)"
        log_error "行号: $line_number"
        log_error "命令: $command"
        
        # 清理临时文件
        if [[ -n "${TEMP_DIR:-}" ]]; then
            cleanup_temp "$TEMP_DIR"
        fi
        
        exit $exit_code
    fi
}

# 设置错误陷阱
set_error_trap() {
    trap 'handle_error $LINENO "$BASH_COMMAND"' ERR
}

# 验证输出格式
validate_output_format() {
    local format="$1"
    
    case "$format" in
        pdf|markdown|md)
            return 0
            ;;
        *)
            log_error "不支持的输出格式: $format"
            log_info "支持的格式: pdf, markdown, md"
            return 1
            ;;
    esac
}

# 检查磁盘空间
check_disk_space() {
    local required_space_mb="$1"  # 所需空间（MB）
    local target_dir="$2"         # 目标目录
    
    # 获取可用空间（KB）
    local available_kb=$(df "$target_dir" | tail -1 | awk '{print $4}')
    local available_mb=$((available_kb / 1024))
    
    if [[ $available_mb -lt $required_space_mb ]]; then
        log_error "磁盘空间不足"
        log_error "需要: ${required_space_mb}MB, 可用: ${available_mb}MB"
        return 1
    fi
    
    log_debug "磁盘空间检查通过: 可用 ${available_mb}MB"
    return 0
}

# 显示帮助信息
show_help() {
    cat << EOF
格式转换HTML工具 - 工具函数库

这个脚本提供了以下工具函数：

日志函数:
  log_info     - 信息日志
  log_success  - 成功日志
  log_warning  - 警告日志
  log_error    - 错误日志
  log_debug    - 调试日志

文件处理:
  validate_file_path      - 验证文件路径
  validate_html_file      - 验证HTML文件
  get_file_extension      - 获取文件扩展名
  get_file_basename       - 获取文件基名
  get_file_info          - 获取文件信息

配置管理:
  read_config            - 读取配置项

系统检查:
  check_dependencies     - 检查系统依赖
  check_disk_space       - 检查磁盘空间

临时文件:
  create_temp_dir        - 创建临时目录
  cleanup_temp           - 清理临时文件

进度显示:
  show_progress          - 显示进度条

错误处理:
  set_error_trap         - 设置错误陷阱
  handle_error           - 处理错误

使用方法:
  source utils.sh        # 在其他脚本中引入此工具库

EOF
}

# 如果直接运行此脚本，显示帮助信息
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_help
fi
