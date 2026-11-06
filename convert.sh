#!/bin/bash

# 格式转换HTML工具 - 主转换脚本
# 执行批量HTML转换操作

set -e  # 遇到错误立即退出

# 引入工具函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 设置错误陷阱
set_error_trap

# 全局变量
OUTPUT_FORMAT=""
INPUT_DIR=""
OUTPUT_DIR=""
SINGLE_FILE=""
RECURSIVE=false
OVERWRITE=false
VERBOSE=false
DRY_RUN=false
TEMP_DIR=""

# 统计变量
TOTAL_FILES=0
PROCESSED_FILES=0
SUCCESS_COUNT=0
ERROR_COUNT=0
SKIPPED_COUNT=0

# 清理函数
cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        cleanup_temp "$TEMP_DIR"
    fi
}

# 设置退出时清理
trap cleanup EXIT

# 显示使用帮助
show_usage() {
    cat << EOF
格式转换HTML工具 - 主转换脚本

用法: $0 [选项]

必需选项:
  -f, --format FORMAT     输出格式 (pdf, markdown, md)

输入选项:
  -i, --input DIR         输入目录 (默认: input/)
  -s, --single FILE       转换单个文件
  -r, --recursive         递归处理子目录

输出选项:
  -o, --output DIR        输出目录 (默认: output/)
  -w, --overwrite         覆盖已存在的文件

其他选项:
  -v, --verbose           详细输出
  -n, --dry-run           试运行，不实际转换
  -h, --help              显示此帮助信息

示例:
  $0 --format pdf                     # 转换input/目录下所有HTML为PDF
  $0 --format markdown --recursive    # 递归转换所有HTML为Markdown
  $0 --single test.html --format pdf  # 转换单个文件
  $0 --format pdf --overwrite         # 转换并覆盖已存在文件

支持的输出格式:
  pdf       - PDF文档
  markdown  - Markdown文档
  md        - Markdown文档 (简写)

EOF
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--format|-i|--input|-o|--output|-s|--single)
                if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
                    log_error "选项 $1 缺少参数"
                    exit 1
                fi
                ;;
        esac
        case $1 in
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -i|--input)
                INPUT_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -s|--single)
                SINGLE_FILE="$2"
                shift 2
                ;;
            -r|--recursive)
                RECURSIVE=true
                shift
                ;;
            -w|--overwrite)
                OVERWRITE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# 验证参数
validate_arguments() {
    # 检查输出格式
    if [[ -z "$OUTPUT_FORMAT" ]]; then
        log_error "必须指定输出格式 (-f|--format)"
        show_usage
        exit 1
    fi
    
    if ! validate_output_format "$OUTPUT_FORMAT"; then
        exit 1
    fi
    
    # 标准化格式名称
    case "$OUTPUT_FORMAT" in
        md)
            OUTPUT_FORMAT="markdown"
            ;;
    esac
    
    # 设置默认目录
    if [[ -z "$INPUT_DIR" ]]; then
        INPUT_DIR=$(read_config "paths.input_dir" "input")
    fi
    
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR=$(read_config "paths.output_dir" "output")
    fi
    
    # 转换为绝对路径
    if [[ ! "$INPUT_DIR" = /* ]]; then
        INPUT_DIR="$SCRIPT_DIR/$INPUT_DIR"
    fi
    
    if [[ ! "$OUTPUT_DIR" = /* ]]; then
        OUTPUT_DIR="$SCRIPT_DIR/$OUTPUT_DIR"
    fi
    
    # 验证输入
    if [[ -n "$SINGLE_FILE" ]]; then
        # 如果不是绝对路径，则相对于当前目录而不是INPUT_DIR
        if [[ ! "$SINGLE_FILE" = /* ]]; then
            SINGLE_FILE="$SCRIPT_DIR/$SINGLE_FILE"
        fi
        
        if ! validate_html_file "$SINGLE_FILE"; then
            exit 1
        fi
    else
        if [[ ! -d "$INPUT_DIR" ]]; then
            log_error "输入目录不存在: $INPUT_DIR"
            exit 1
        fi
    fi
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    # 从配置读取覆盖设置
    if [[ "$OVERWRITE" == "false" ]]; then
        local config_overwrite=$(read_config "conversion.overwrite_existing" "false")
        if [[ "$config_overwrite" == "true" ]]; then
            OVERWRITE=true
        fi
    fi
}

# 获取HTML文件列表
get_html_files() {
    local files=()
    
    if [[ -n "$SINGLE_FILE" ]]; then
        files=("$SINGLE_FILE")
    else
        if [[ "$RECURSIVE" == "true" ]]; then
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$INPUT_DIR" -type f \( -name "*.html" -o -name "*.htm" \) -print0)
        else
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$INPUT_DIR" -maxdepth 1 -type f \( -name "*.html" -o -name "*.htm" \) -print0)
        fi
    fi
    
    if [[ ${#files[@]} -gt 0 ]]; then
        printf '%s\0' "${files[@]}"
    fi
}

# 生成输出文件路径
generate_output_path() {
    local input_file="$1"
    local basename=$(get_file_basename "$input_file")
    local relative_path=""
    
    # 计算相对路径
    if [[ -z "$SINGLE_FILE" ]]; then
        relative_path=$(dirname "${input_file#$INPUT_DIR/}")
        if [[ "$relative_path" == "." ]]; then
            relative_path=""
        fi
    fi
    
    # 确定文件扩展名
    local extension=""
    case "$OUTPUT_FORMAT" in
        pdf)
            extension="pdf"
            ;;
        markdown)
            extension="md"
            ;;
    esac
    
    # 构建输出路径
    local output_path="$OUTPUT_DIR"
    if [[ -n "$relative_path" ]]; then
        output_path="$output_path/$relative_path"
    fi
    output_path="$output_path/$basename.$extension"
    
    echo "$output_path"
}

# 转换单个HTML文件
convert_single_file() {
    local input_file="$1"
    local output_file="$2"
    
    log_debug "转换文件: $input_file -> $output_file"
    
    # 检查输出文件是否已存在
    if [[ -f "$output_file" && "$OVERWRITE" == "false" ]]; then
        log_warning "输出文件已存在，跳过: $output_file"
        ((SKIPPED_COUNT+=1))
        return 0
    fi
    
    # 创建输出目录
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # 试运行模式
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[试运行] 将转换: $(basename "$input_file") -> $(basename "$output_file")"
        return 0
    fi
    
    # 构建Pandoc命令
    local pandoc_cmd="pandoc"
    local pandoc_args=()
    
    # 输入文件
    pandoc_args+=("$input_file")
    
    # 输出文件
    pandoc_args+=("-o" "$output_file")
    
    # 根据输出格式设置参数
    case "$OUTPUT_FORMAT" in
        pdf)
            # PDF特定参数
            local pdf_engine=$(read_config "pdf.engine" "xelatex")
            local margin_top=$(read_config "pdf.margin_top" "2cm")
            local margin_bottom=$(read_config "pdf.margin_bottom" "2cm")
            local margin_left=$(read_config "pdf.margin_left" "2cm")
            local margin_right=$(read_config "pdf.margin_right" "2cm")
            local font_size=$(read_config "pdf.font_size" "12pt")
            local paper_size=$(read_config "pdf.paper_size" "a4")
            
            pandoc_args+=("--pdf-engine=$pdf_engine")
            pandoc_args+=("-V" "geometry:top=$margin_top,bottom=$margin_bottom,left=$margin_left,right=$margin_right")
            pandoc_args+=("-V" "fontsize=$font_size")
            pandoc_args+=("-V" "papersize=$paper_size")
            
            # 中文支持
            if [[ "$pdf_engine" == "xelatex" ]]; then
                pandoc_args+=("-V" "CJKmainfont=PingFang SC")
                pandoc_args+=("-V" "mainfont=PingFang SC")
            fi
            ;;
        markdown)
            # Markdown特定参数
            local variant=$(read_config "markdown.variant" "gfm")
            local wrap=$(read_config "markdown.wrap" "auto")
            local columns=$(read_config "markdown.columns" "80")
            
            pandoc_args+=("-t" "$variant")
            pandoc_args+=("--wrap=$wrap")
            if [[ "$wrap" != "auto" && "$wrap" != "none" ]]; then
                pandoc_args+=("--columns=$columns")
            fi
            ;;
    esac
    
    # 执行转换
    log_debug "执行命令: $pandoc_cmd ${pandoc_args[*]}"
    
    if "$pandoc_cmd" "${pandoc_args[@]}" 2>/dev/null; then
        log_success "转换成功: $(basename "$input_file") -> $(basename "$output_file")"
        ((SUCCESS_COUNT+=1))
        
        # 显示文件信息
        if [[ "$VERBOSE" == "true" ]]; then
            get_file_info "$output_file"
        fi
        
        return 0
    else
        log_error "转换失败: $(basename "$input_file")"
        ((ERROR_COUNT+=1))
        return 1
    fi
}

# 批量转换文件
batch_convert() {
    log_info "开始批量转换..."
    log_info "输出格式: $OUTPUT_FORMAT"
    log_info "输入目录: $INPUT_DIR"
    log_info "输出目录: $OUTPUT_DIR"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "试运行模式 - 不会实际转换文件"
    fi
    
    # 获取文件列表
    local files=()
    while IFS= read -r -d '' file; do
        [[ -n "$file" ]] && files+=("$file")
    done < <(get_html_files)
    
    TOTAL_FILES=${#files[@]}
    
    if [[ $TOTAL_FILES -eq 0 ]]; then
        log_warning "未找到HTML文件"
        return 0
    fi
    
    log_info "找到 $TOTAL_FILES 个HTML文件"
    
    # 检查磁盘空间
    local estimated_space=$((TOTAL_FILES * 5))  # 估计每个文件5MB
    if ! check_disk_space "$estimated_space" "$OUTPUT_DIR"; then
        log_error "磁盘空间不足，无法继续转换"
        return 1
    fi
    
    # 创建临时目录
    TEMP_DIR=$(create_temp_dir)
    
    # 批量处理
    local batch_size=$(read_config "conversion.batch_size" "10")
    local show_progress=$(read_config "logging.show_progress" "true")
    
    local i
    for ((i=0; i<TOTAL_FILES; i++)); do
        local input_file="${files[i]}"
        local output_file=$(generate_output_path "$input_file")
        
        # 显示进度
        if [[ "$show_progress" == "true" ]]; then
            show_progress $((i+1)) "$TOTAL_FILES" "$(basename "$input_file")"
        fi
        
        # 验证输入文件
        if ! validate_html_file "$input_file"; then
            log_warning "跳过无效文件: $(basename "$input_file")"
            ((SKIPPED_COUNT+=1))
            continue
        fi
        
        # 转换文件
        # Each failure is counted by convert_single_file; finish the batch before
        # main returns a nonzero status from the aggregate error count.
        if convert_single_file "$input_file" "$output_file"; then
            :
        fi
        ((PROCESSED_FILES+=1))
        
        # 批处理暂停
        if [[ $((i % batch_size)) -eq $((batch_size - 1)) && $i -lt $((TOTAL_FILES - 1)) ]]; then
            log_debug "批处理暂停 1 秒..."
            sleep 1
        fi
    done
    
    # 显示最终进度
    if [[ "$show_progress" == "true" ]]; then
        show_progress "$TOTAL_FILES" "$TOTAL_FILES" "完成"
    fi
}

# 显示转换统计
show_statistics() {
    echo
    echo "========================================"
    echo "转换统计"
    echo "========================================"
    echo "总文件数: $TOTAL_FILES"
    echo "已处理: $PROCESSED_FILES"
    echo "成功: $SUCCESS_COUNT"
    echo "失败: $ERROR_COUNT"
    echo "跳过: $SKIPPED_COUNT"
    echo "========================================"
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        log_warning "有 $ERROR_COUNT 个文件转换失败，请检查日志文件: $LOG_FILE"
    fi
    
    if [[ $SUCCESS_COUNT -gt 0 ]]; then
        log_success "成功转换 $SUCCESS_COUNT 个文件到 $OUTPUT_DIR"
    fi
}

# 主函数
main() {
    echo "========================================"
    echo "    格式转换HTML工具 - 批量转换"
    echo "========================================"
    echo
    
    # 解析参数
    parse_arguments "$@"
    
    # 验证参数
    validate_arguments
    
    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi
    
    # 开始转换
    local start_time=$(date +%s)
    
    batch_convert
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 显示统计
    show_statistics
    
    echo
    log_info "转换耗时: ${duration}秒"
    
    # 返回适当的退出码
    if [[ $ERROR_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# 执行主函数
main "$@"
