#!/bin/bash

# 格式转换HTML工具 - 配置管理脚本
# 设置转换参数和输出选项

# 引入工具函数库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# 配置文件路径
CONFIG_FILE="$SCRIPT_DIR/config/config.json"

# 默认配置
DEFAULT_CONFIG='{
  "pdf": {
    "engine": "xelatex",
    "margin_top": "2cm",
    "margin_bottom": "2cm", 
    "margin_left": "2cm",
    "margin_right": "2cm",
    "font_size": "12pt",
    "font_family": "SimSun",
    "paper_size": "a4",
    "toc": false,
    "number_sections": false
  },
  "markdown": {
    "variant": "gfm",
    "wrap": "auto",
    "columns": 80,
    "preserve_tabs": false,
    "tab_stop": 4
  },
  "paths": {
    "input_dir": "input",
    "output_dir": "output", 
    "temp_dir": "temp",
    "log_dir": "logs"
  },
  "logging": {
    "level": "info",
    "file": "logs/conversion.log",
    "show_progress": true
  },
  "conversion": {
    "overwrite_existing": false,
    "create_subdirs": true,
    "preserve_structure": true,
    "batch_size": 10
  }
}'

# 显示当前配置
show_config() {
    log_info "当前配置设置："
    echo "========================================"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        if command -v jq &> /dev/null; then
            jq '.' "$CONFIG_FILE"
        else
            cat "$CONFIG_FILE"
        fi
    else
        log_warning "配置文件不存在，显示默认配置："
        echo "$DEFAULT_CONFIG" | jq '.' 2>/dev/null || echo "$DEFAULT_CONFIG"
    fi
    
    echo "========================================"
}

# 初始化配置文件
init_config() {
    log_info "初始化配置文件..."
    
    # 确保配置目录存在
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # 创建默认配置文件
    echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    
    log_success "配置文件已创建: $CONFIG_FILE"
}

# 更新配置项
update_config() {
    local key="$1"
    local value="$2"
    
    if [[ -z "$key" || -z "$value" ]]; then
        log_error "配置键和值不能为空"
        return 1
    fi
    
    # 确保配置文件存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        init_config
    fi
    
    # 使用jq更新配置
    if command -v jq &> /dev/null; then
        local temp_file=$(mktemp)
        jq ".$key = \"$value\"" "$CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$CONFIG_FILE"
        log_success "已更新配置: $key = $value"
    else
        log_error "需要安装jq来更新配置文件"
        log_info "请运行: brew install jq"
        return 1
    fi
}

# 获取配置项
get_config() {
    local key="$1"
    local default_value="$2"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default_value"
        return
    fi
    
    if command -v jq &> /dev/null; then
        jq -r ".$key // \"$default_value\"" "$CONFIG_FILE" 2>/dev/null
    else
        echo "$default_value"
    fi
}

# 重置配置为默认值
reset_config() {
    log_warning "重置配置为默认值..."
    read -p "确定要重置所有配置吗？(y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        init_config
        log_success "配置已重置为默认值"
    else
        log_info "取消重置操作"
    fi
}

# 验证配置文件
validate_config() {
    log_info "验证配置文件..."
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    # 检查JSON格式
    if command -v jq &> /dev/null; then
        if ! jq '.' "$CONFIG_FILE" >/dev/null 2>&1; then
            log_error "配置文件JSON格式无效"
            return 1
        fi
    fi
    
    # 检查必要的配置项
    local required_keys=("paths.input_dir" "paths.output_dir" "pdf.engine" "markdown.variant")
    
    for key in "${required_keys[@]}"; do
        local value=$(get_config "$key")
        if [[ -z "$value" || "$value" == "null" ]]; then
            log_error "缺少必要配置项: $key"
            return 1
        fi
    done
    
    # 检查目录是否存在
    local input_dir=$(get_config "paths.input_dir" "input")
    local output_dir=$(get_config "paths.output_dir" "output")
    
    if [[ ! -d "$SCRIPT_DIR/$input_dir" ]]; then
        log_warning "输入目录不存在，将创建: $input_dir"
        mkdir -p "$SCRIPT_DIR/$input_dir"
    fi
    
    if [[ ! -d "$SCRIPT_DIR/$output_dir" ]]; then
        log_warning "输出目录不存在，将创建: $output_dir"
        mkdir -p "$SCRIPT_DIR/$output_dir"
    fi
    
    log_success "配置文件验证通过"
    return 0
}

# 交互式配置设置
interactive_config() {
    log_info "交互式配置设置"
    echo "========================================"
    
    # 确保配置文件存在
    if [[ ! -f "$CONFIG_FILE" ]]; then
        init_config
    fi
    
    echo "当前配置选项："
    echo "1. PDF转换设置"
    echo "2. Markdown转换设置"
    echo "3. 路径设置"
    echo "4. 日志设置"
    echo "5. 转换选项"
    echo "6. 查看当前配置"
    echo "7. 重置为默认配置"
    echo "0. 退出"
    echo
    
    while true; do
        read -p "请选择要配置的选项 (0-7): " choice
        
        case $choice in
            1)
                configure_pdf_settings
                ;;
            2)
                configure_markdown_settings
                ;;
            3)
                configure_path_settings
                ;;
            4)
                configure_logging_settings
                ;;
            5)
                configure_conversion_options
                ;;
            6)
                show_config
                ;;
            7)
                reset_config
                ;;
            0)
                log_info "退出配置设置"
                break
                ;;
            *)
                log_warning "无效选择，请输入0-7"
                ;;
        esac
        
        echo
        read -p "按回车键继续..." 
        echo
    done
}

# 配置PDF设置
configure_pdf_settings() {
    echo "PDF转换设置："
    
    local current_engine=$(get_config "pdf.engine" "xelatex")
    read -p "PDF引擎 (当前: $current_engine, 可选: pdflatex/xelatex/lualatex): " engine
    if [[ -n "$engine" ]]; then
        update_config "pdf.engine" "$engine"
    fi
    
    local current_font_size=$(get_config "pdf.font_size" "12pt")
    read -p "字体大小 (当前: $current_font_size): " font_size
    if [[ -n "$font_size" ]]; then
        update_config "pdf.font_size" "$font_size"
    fi
    
    local current_margin=$(get_config "pdf.margin_top" "2cm")
    read -p "页边距 (当前: $current_margin): " margin
    if [[ -n "$margin" ]]; then
        update_config "pdf.margin_top" "$margin"
        update_config "pdf.margin_bottom" "$margin"
        update_config "pdf.margin_left" "$margin"
        update_config "pdf.margin_right" "$margin"
    fi
    
    local current_paper=$(get_config "pdf.paper_size" "a4")
    read -p "纸张大小 (当前: $current_paper, 可选: a4/letter/a3): " paper_size
    if [[ -n "$paper_size" ]]; then
        update_config "pdf.paper_size" "$paper_size"
    fi
}

# 配置Markdown设置
configure_markdown_settings() {
    echo "Markdown转换设置："
    
    local current_variant=$(get_config "markdown.variant" "gfm")
    read -p "Markdown变体 (当前: $current_variant, 可选: gfm/commonmark/markdown): " variant
    if [[ -n "$variant" ]]; then
        update_config "markdown.variant" "$variant"
    fi
    
    local current_columns=$(get_config "markdown.columns" "80")
    read -p "行宽度 (当前: $current_columns): " columns
    if [[ -n "$columns" ]]; then
        update_config "markdown.columns" "$columns"
    fi
    
    local current_tab_stop=$(get_config "markdown.tab_stop" "4")
    read -p "制表符宽度 (当前: $current_tab_stop): " tab_stop
    if [[ -n "$tab_stop" ]]; then
        update_config "markdown.tab_stop" "$tab_stop"
    fi
}

# 配置路径设置
configure_path_settings() {
    echo "路径设置："
    
    local current_input=$(get_config "paths.input_dir" "input")
    read -p "输入目录 (当前: $current_input): " input_dir
    if [[ -n "$input_dir" ]]; then
        update_config "paths.input_dir" "$input_dir"
        mkdir -p "$SCRIPT_DIR/$input_dir"
    fi
    
    local current_output=$(get_config "paths.output_dir" "output")
    read -p "输出目录 (当前: $current_output): " output_dir
    if [[ -n "$output_dir" ]]; then
        update_config "paths.output_dir" "$output_dir"
        mkdir -p "$SCRIPT_DIR/$output_dir"
    fi
}

# 配置日志设置
configure_logging_settings() {
    echo "日志设置："
    
    local current_level=$(get_config "logging.level" "info")
    read -p "日志级别 (当前: $current_level, 可选: debug/info/warning/error): " level
    if [[ -n "$level" ]]; then
        update_config "logging.level" "$level"
    fi
    
    local current_progress=$(get_config "logging.show_progress" "true")
    read -p "显示进度条 (当前: $current_progress, 可选: true/false): " show_progress
    if [[ -n "$show_progress" ]]; then
        update_config "logging.show_progress" "$show_progress"
    fi
}

# 配置转换选项
configure_conversion_options() {
    echo "转换选项："
    
    local current_overwrite=$(get_config "conversion.overwrite_existing" "false")
    read -p "覆盖已存在文件 (当前: $current_overwrite, 可选: true/false): " overwrite
    if [[ -n "$overwrite" ]]; then
        update_config "conversion.overwrite_existing" "$overwrite"
    fi
    
    local current_batch_size=$(get_config "conversion.batch_size" "10")
    read -p "批处理大小 (当前: $current_batch_size): " batch_size
    if [[ -n "$batch_size" ]]; then
        update_config "conversion.batch_size" "$batch_size"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
格式转换HTML工具 - 配置管理脚本

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  -s, --show              显示当前配置
  -i, --init              初始化配置文件
  -c, --config            交互式配置设置
  -v, --validate          验证配置文件
  -r, --reset             重置配置为默认值
  -g, --get KEY           获取配置项值
  -u, --update KEY VALUE  更新配置项

示例:
  $0 --show                           # 显示当前配置
  $0 --config                         # 交互式配置
  $0 --get pdf.engine                 # 获取PDF引擎设置
  $0 --update pdf.font_size 14pt      # 设置PDF字体大小

配置文件位置: $CONFIG_FILE

EOF
}

# 主函数
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            ;;
        -s|--show)
            show_config
            ;;
        -i|--init)
            init_config
            ;;
        -c|--config)
            interactive_config
            ;;
        -v|--validate)
            validate_config
            ;;
        -r|--reset)
            reset_config
            ;;
        -g|--get)
            if [[ -n "$2" ]]; then
                get_config "$2"
            else
                log_error "请指定配置键"
                exit 1
            fi
            ;;
        -u|--update)
            if [[ -n "$2" && -n "$3" ]]; then
                update_config "$2" "$3"
            else
                log_error "请指定配置键和值"
                exit 1
            fi
            ;;
        "")
            interactive_config
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 如果直接运行此脚本，执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi