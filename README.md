# 格式转换HTML工具

一个功能强大的HTML格式转换工具，支持将HTML文档批量转换为PDF和Markdown格式。基于Pandoc构建，专为macOS环境优化。

## ✨ 主要特性

- 🚀 **批量转换** - 支持一次性转换多个HTML文件
- 📄 **多种格式** - 支持PDF和Markdown输出格式
- ⚙️ **智能配置** - 灵活的配置管理系统
- 🛡️ **错误处理** - 完善的错误处理和日志记录
- 📊 **进度显示** - 实时显示转换进度
- 🔧 **自动安装** - 一键安装所有依赖项
- 🌐 **中文支持** - 完美支持中文字符和格式

## 📋 系统要求

- **操作系统**: macOS 10.14 或更高版本
- **包管理器**: Homebrew
- **磁盘空间**: 至少500MB可用空间
- **网络连接**: 首次安装时需要网络连接

## 🚀 快速开始

### 1. 安装依赖

首次使用前，运行安装脚本自动安装所有依赖项：

```bash
./install.sh
```

安装脚本会自动：
- 检查并安装Homebrew（如果未安装）
- 安装Pandoc转换引擎
- 安装BasicTeX LaTeX环境
- 配置必要的环境变量
- 验证安装结果

### 2. 准备HTML文件

将需要转换的HTML文件放入 `input/` 目录：

```bash
cp your-file.html input/
```

### 3. 执行转换

#### 转换为PDF
```bash
./convert.sh --format pdf
```

#### 转换为Markdown
```bash
./convert.sh --format markdown
```

### 4. 查看结果

转换完成的文件将保存在 `output/` 目录中。

## 📖 详细使用说明

### 命令行选项

```bash
./convert.sh [选项]
```

#### 必需选项
- `-f, --format FORMAT` - 输出格式 (pdf, markdown, md)

#### 输入选项
- `-i, --input DIR` - 输入目录 (默认: input/)
- `-s, --single FILE` - 转换单个文件
- `-r, --recursive` - 递归处理子目录

#### 输出选项
- `-o, --output DIR` - 输出目录 (默认: output/)
- `-w, --overwrite` - 覆盖已存在的文件

#### 其他选项
- `-v, --verbose` - 详细输出
- `-n, --dry-run` - 试运行，不实际转换
- `-h, --help` - 显示帮助信息

### 使用示例

#### 基本用法
```bash
# 转换所有HTML文件为PDF
./convert.sh --format pdf

# 转换所有HTML文件为Markdown
./convert.sh --format markdown

# 转换单个文件
./convert.sh --single example.html --format pdf
```

#### 高级用法
```bash
# 递归转换子目录中的文件
./convert.sh --format pdf --recursive

# 覆盖已存在的文件
./convert.sh --format pdf --overwrite

# 详细输出模式
./convert.sh --format pdf --verbose

# 试运行模式（不实际转换）
./convert.sh --format pdf --dry-run

# 指定输入和输出目录
./convert.sh --format pdf --input /path/to/html --output /path/to/output
```

## ⚙️ 配置管理

### 查看当前配置
```bash
./config.sh --show
```

### 交互式配置
```bash
./config.sh --config
```

### 命令行配置
```bash
# 获取配置项
./config.sh --get pdf.engine

# 更新配置项
./config.sh --update pdf.font_size 14pt

# 重置为默认配置
./config.sh --reset
```

### 主要配置选项

#### PDF转换配置
- `pdf.engine` - PDF引擎 (pdflatex, xelatex, lualatex)
- `pdf.margin_*` - 页边距设置
- `pdf.font_size` - 字体大小
- `pdf.paper_size` - 纸张尺寸 (a4, letter, a3)

#### Markdown转换配置
- `markdown.variant` - Markdown变体 (gfm, commonmark, markdown)
- `markdown.wrap` - 文本换行方式
- `markdown.columns` - 行宽度设置

#### 路径配置
- `paths.input_dir` - 输入目录
- `paths.output_dir` - 输出目录
- `paths.temp_dir` - 临时目录
- `paths.log_dir` - 日志目录

## 📁 项目结构

```
格式转换html/
├── README.md              # 项目说明文档
├── install.sh             # 安装脚本
├── convert.sh             # 主转换脚本
├── config.sh              # 配置管理脚本
├── utils.sh               # 工具函数库
├── config/
│   └── config.json        # 配置文件
├── input/                 # 输入HTML文件目录
│   ├── simple.html        # 简单测试文件
│   └── complex.html       # 复杂测试文件
├── output/                # 输出文件目录
├── logs/                  # 日志文件目录
├── temp/                  # 临时文件目录
└── tests/                 # 测试文件目录
    └── test_conversion.html
```

## 🔧 故障排除

### 常见问题

#### 1. Pandoc命令未找到
**问题**: `pandoc: command not found`
**解决方案**: 运行 `./install.sh` 重新安装依赖

#### 2. PDF转换失败
**问题**: PDF转换时出现LaTeX错误
**解决方案**: 
- 重启终端
- 重新运行 `./install.sh`
- 检查LaTeX环境: `which xelatex`

#### 3. 中文字符显示异常
**问题**: PDF中中文字符显示为方块或乱码
**解决方案**: 
- 确保使用XeLaTeX引擎
- 检查字体配置: `./config.sh --get pdf.engine`

#### 4. 权限错误
**问题**: `Permission denied` 错误
**解决方案**: 
```bash
chmod +x *.sh
```

#### 5. 转换速度慢
**问题**: 大量文件转换速度慢
**解决方案**: 
- 调整批处理大小: `./config.sh --update conversion.batch_size 5`
- 使用更快的PDF引擎: `./config.sh --update pdf.engine pdflatex`

### 日志查看

查看详细的转换日志：
```bash
tail -f logs/conversion.log
```

查看最近的错误：
```bash
grep ERROR logs/conversion.log | tail -10
```

## 📊 性能指标

- **单文件转换时间**: 1-5秒（取决于文件复杂度）
- **批量转换**: 支持同时处理数百个文件
- **内存使用**: 每个文件约10-50MB
- **磁盘空间**: PDF文件通常比HTML文件大2-5倍

## ⚠️ 注意事项

1. **首次使用**: 必须先运行 `./install.sh` 安装依赖
2. **磁盘空间**: 确保有足够空间存储输出文件
3. **CSS样式**: 复杂的CSS样式可能无法完全保留
4. **JavaScript**: JS代码不会在转换后的文档中执行
5. **文件备份**: 建议在转换前备份重要文件
6. **网络连接**: 首次安装需要网络连接下载依赖

## 🧪 测试

项目包含多个测试文件用于验证转换功能：

### 运行测试
```bash
# 测试简单HTML转换
./convert.sh --single input/simple.html --format pdf

# 测试复杂HTML转换
./convert.sh --single input/complex.html --format pdf

# 测试功能完整性
./convert.sh --single tests/test_conversion.html --format markdown
```

### 测试文件说明
- `input/simple.html` - 基本HTML元素测试
- `input/complex.html` - 复杂样式和布局测试
- `tests/test_conversion.html` - 转换功能完整性测试

## 📝 更新日志

### v1.0.0 (2024-01-15)
- ✨ 初始版本发布
- 🚀 支持HTML到PDF/Markdown转换
- ⚙️ 完整的配置管理系统
- 🛡️ 错误处理和日志记录
- 📊 进度显示功能
- 🔧 自动安装脚本

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个项目！

## 📄 许可证

MIT License - 详见LICENSE文件

## 📞 技术支持

如果遇到问题，请：

1. 查看日志文件: `logs/conversion.log`
2. 运行诊断命令: `./convert.sh --help`
3. 检查配置: `./config.sh --show`
4. 重新安装依赖: `./install.sh`

---

**让HTML文档转换变得简单高效！** 🎉