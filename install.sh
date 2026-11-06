#!/bin/bash

# 格式转换HTML工具安装脚本
# 自动安装Pandoc和LaTeX环境

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为macOS系统
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "此脚本仅支持macOS系统"
        exit 1
    fi
    log_success "检测到macOS系统"
}

# 检查Homebrew是否安装
check_homebrew() {
    log_info "检查Homebrew安装状态..."
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew未安装，正在安装..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # 添加Homebrew到PATH
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    else
        log_success "Homebrew已安装"
    fi
}

# 安装Pandoc
install_pandoc() {
    log_info "检查Pandoc安装状态..."
    if ! command -v pandoc &> /dev/null; then
        log_info "正在安装Pandoc..."
        brew install pandoc
        log_success "Pandoc安装完成"
    else
        local version=$(pandoc --version | head -n1)
        log_success "Pandoc已安装: $version"
    fi
}

# 安装LaTeX环境
install_latex() {
    log_info "检查LaTeX环境..."
    
    # 检查是否已安装BasicTeX或MacTeX
    if command -v pdflatex &> /dev/null && command -v xelatex &> /dev/null; then
        log_success "LaTeX环境已安装"
        return
    fi
    
    log_info "正在安装BasicTeX (轻量级LaTeX发行版)..."
    
    # 使用Homebrew安装BasicTeX
    if brew list --cask basictex &> /dev/null; then
        log_success "BasicTeX已通过Homebrew安装"
    else
        brew install --cask basictex
    fi
    
    # 更新PATH以包含LaTeX二进制文件
    export PATH="/usr/local/texlive/2023/bin/universal-darwin:$PATH"
    export PATH="/Library/TeX/texbin:$PATH"
    
    # 添加到shell配置文件
    local shell_config=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        shell_config="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        shell_config="$HOME/.bash_profile"
    fi
    
    if [[ -n "$shell_config" ]]; then
        if ! grep -q "texbin" "$shell_config" 2>/dev/null; then
            echo 'export PATH="/Library/TeX/texbin:$PATH"' >> "$shell_config"
            log_info "已添加LaTeX路径到 $shell_config"
        fi
    fi
    
    # 刷新tlmgr并安装必要的包
    log_info "更新LaTeX包管理器..."
    sudo tlmgr update --self 2>/dev/null || true
    
    # 安装常用的LaTeX包
    log_info "安装必要的LaTeX包..."
    sudo tlmgr install collection-fontsrecommended 2>/dev/null || true
    sudo tlmgr install collection-latexextra 2>/dev/null || true
    
    log_success "LaTeX环境安装完成"
}

# 验证安装
verify_installation() {
    log_info "验证安装结果..."
    
    # 检查Pandoc
    if command -v pandoc &> /dev/null; then
        local pandoc_version=$(pandoc --version | head -n1)
        log_success "✓ Pandoc: $pandoc_version"
    else
        log_error "✗ Pandoc安装失败"
        return 1
    fi
    
    # 检查LaTeX引擎
    if command -v pdflatex &> /dev/null; then
        log_success "✓ pdflatex可用"
    else
        log_warning "✗ pdflatex不可用"
    fi
    
    if command -v xelatex &> /dev/null; then
        log_success "✓ xelatex可用"
    else
        log_warning "✗ xelatex不可用"
    fi
    
    # 测试Pandoc转换功能
    log_info "测试Pandoc转换功能..."
    echo "<h1>测试</h1><p>这是一个测试文档。</p>" > /tmp/test.html
    
    if pandoc /tmp/test.html -o /tmp/test.md 2>/dev/null; then
        log_success "✓ HTML到Markdown转换测试通过"
        rm -f /tmp/test.md
    else
        log_error "✗ HTML到Markdown转换测试失败"
    fi
    
    if command -v xelatex &> /dev/null; then
        if pandoc /tmp/test.html --pdf-engine=xelatex -o /tmp/test.pdf 2>/dev/null; then
            log_success "✓ HTML到PDF转换测试通过"
            rm -f /tmp/test.pdf
        else
            log_warning "✗ HTML到PDF转换测试失败（可能需要重启终端或重新加载PATH）"
        fi
    fi
    
    rm -f /tmp/test.html
}

# 创建必要的目录
setup_directories() {
    log_info "创建必要的目录结构..."
    mkdir -p input output logs temp
    log_success "目录结构创建完成"
}

# 设置脚本权限
setup_permissions() {
    log_info "设置脚本执行权限..."
    chmod +x *.sh 2>/dev/null || true
    log_success "脚本权限设置完成"
}

# 主安装流程
main() {
    echo "========================================"
    echo "    格式转换HTML工具 - 安装脚本"
    echo "========================================"
    echo
    
    check_macos
    check_homebrew
    install_pandoc
    install_latex
    setup_directories
    setup_permissions
    verify_installation
    
    echo
    echo "========================================"
    log_success "安装完成！"
    echo "========================================"
    echo
    echo "使用方法："
    echo "  1. 将HTML文件放入 input/ 目录"
    echo "  2. 运行: ./convert.sh --format pdf"
    echo "  3. 或运行: ./convert.sh --format markdown"
    echo "  4. 查看转换结果在 output/ 目录"
    echo
    echo "如果遇到LaTeX相关错误，请重启终端后重试。"
    echo
}

# 执行主函数
main "$@"