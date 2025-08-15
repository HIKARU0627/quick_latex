# CLI使用ガイド

このガイドでは、コマンドライン（CLI）でLaTeXプロジェクトを管理する方法を説明します。

## 必要な環境

- Docker（LaTeX環境用）
- Bash（スクリプト実行用）
- jq（JSONファイル処理用）

### jqのインストール

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# その他
# https://jqlang.github.io/jq/download/
```

## 🚀 クイックスタート

### 1. 新しいレポートの作成

```bash
./scripts/new-report.sh
```

対話式ウィザードが起動し、以下を選択：

- 学期（例: 2025-fall）
- 科目名（例: programming, mathematics, physics）
- レポート名（例: report01, final-project）
- テンプレート（11種類から選択、カテゴリ別表示）

### 2. レポートのコンパイル

```bash
./scripts/compile.sh courses/2025-fall/mathematics/report01/main.tex
```

### 3. PDFの確認

生成されたPDFは `output/` ディレクトリに保存されます。

## 📋 テンプレート管理システム

### 利用可能なテンプレート一覧

```bash
# 全テンプレート表示
./scripts/manage-templates.sh list

# カテゴリ別表示（推奨）
./scripts/manage-templates.sh list --category

# 有効なテンプレートのみ
./scripts/manage-templates.sh list --enabled
```

### テンプレートカテゴリ

#### 📚 一般

- **基本レポート**: 汎用的な学術レポート
- **ディスカッション**: 議論・検討用レポート

#### 🔬 理科・数学・物理

- **実験レポート**: 実験データと分析
- **数学レポート**: 定理・証明・数式展開
- **物理実験レポート**: 物理実験と測定データ
- **物理理論レポート**: 高度な物理理論

#### 💻 プログラミング

- **プログラミングレポート**: コード解説とアルゴリズム

#### 🎓 学術・研究

- **卒論・修論**: 学位論文用の正式構造
- **文献レビュー**: 先行研究の体系的調査
- **ケーススタディ**: 企業・組織分析

#### 📊 プレゼンテーション

- **プレゼンテーション**: Beamerスライド

### テンプレートの管理

#### 有効化・無効化

```bash
# テンプレートを無効化（新規作成時に非表示）
./scripts/manage-templates.sh disable math

# テンプレートを有効化
./scripts/manage-templates.sh enable math

# 状態切り替え
./scripts/manage-templates.sh toggle physics-theory
```

#### 詳細情報の確認

```bash
# テンプレートの詳細情報
./scripts/manage-templates.sh info math

# 設定ファイルの検証
./scripts/manage-templates.sh validate
```

#### 新しいテンプレートの追加

```bash
# 対話式でテンプレートを追加
./scripts/manage-templates.sh add my-custom-template.tex
```

手順：

1. `templates/` ディレクトリに新しいテンプレートファイルを配置
2. 上記コマンドを実行
3. ID、名前、説明、カテゴリを入力

#### 設定のバックアップ・復元

```bash
# 設定ファイルのバックアップ
./scripts/manage-templates.sh backup

# 設定の復元
./scripts/manage-templates.sh restore
```

## 📝 文書作成の基本ワークフロー

### 1. プロジェクト作成

```bash
./scripts/new-report.sh
```

### 2. 文書編集

お気に入りのエディタで `main.tex` を編集：

```bash
# VSCode
code courses/2025-fall/mathematics/report01/main.tex

# Vim
vim courses/2025-fall/mathematics/report01/main.tex
```

### 3. コンパイル（複数オプション）

```bash
# 基本コンパイル
./scripts/compile.sh courses/2025-fall/mathematics/report01/main.tex

# BibTeX付き（参考文献処理）
./scripts/compile.sh courses/2025-fall/mathematics/report01/main.tex -b

# クイックコンパイル（1回のみ、高速）
./scripts/compile.sh courses/2025-fall/mathematics/report01/main.tex -q

# 自動PDF表示
./scripts/compile.sh courses/2025-fall/mathematics/report01/main.tex -o

# 監視モード（ファイル変更時に自動再コンパイル）
./scripts/compile.sh courses/2025-fall/mathematics/report01/main.tex -w

# コンパイラ指定
./scripts/compile.sh courses/2025-fall/mathematics/report01/main.tex -c pdflatex
```

### 4. 品質チェック

```bash
./scripts/check-quality.sh courses/2025-fall/mathematics/report01/main.tex
```

チェック内容：

- 文書構造の妥当性
- 日本語設定の確認
- 図表キャプションの検証
- 参考文献の整合性
- ファイル構成の標準準拠

## 🐳 Docker環境での操作

### 直接操作

```bash
# LaTeXコンテナでbash起動
docker compose run --rm latex bash

# 特定ディレクトリで作業
docker compose run --rm -w "/workspace/courses/2025-fall/mathematics/report01" latex bash

# 直接コマンド実行
docker compose run --rm -w "/workspace/courses/2025-fall/mathematics/report01" latex lualatex main.tex
```

### メンテナンス

```bash
# イメージ更新
docker compose pull

# コンテナ再構築
docker compose build --no-cache

# 不要リソース削除
docker system prune
```

## 📁 プロジェクト構造

```plaintext
university-latex/
├── courses/                    # 学期・科目別プロジェクト
│   ├── 2025-fall/
│   │   ├── mathematics/
│   │   │   └── report01/
│   │   │       ├── main.tex          # メイン文書
│   │   │       ├── figures/          # 図・画像
│   │   │       ├── sections/         # セクションファイル（任意）
│   │   │       ├── output/           # 生成ファイル（PDF等）
│   │   │       ├── .gitignore        # Git除外設定
│   │   │       └── README.md         # プロジェクト説明
│   │   ├── physics/
│   │   └── programming/
│   ├── 2024-fall/
│   └── 2024-spring/
├── templates/                  # LaTeXテンプレート（11種類）
│   ├── report-basic.tex
│   ├── report-math.tex
│   ├── report-physics-experiment.tex
│   └── ...
├── config/                     # 設定ファイル
│   └── templates.json          # テンプレート管理設定
├── scripts/                    # ユーティリティスクリプト
│   ├── new-report.sh          # 新規プロジェクト作成
│   ├── manage-templates.sh    # テンプレート管理
│   ├── compile.sh             # LaTeXコンパイル
│   └── check-quality.sh       # 品質チェック
├── common/                     # 共通リソース
│   ├── university-style.sty   # 共通スタイルパッケージ
│   └── bibliography.bib       # 共通文献データベース
└── docker/                     # Docker設定
```

## 🎨 日本語文書の作成

### 基本設定

```latex
\documentclass[a4paper,11pt]{ltjsarticle}
\usepackage{luatexja-fontspec}
\setmainfont{Noto Serif CJK JP}
\setsansfont{Noto Sans CJK JP}
```

### 推奨コンパイラ

- **LuaLaTeX** (推奨): Unicode対応、高機能、日本語フォント自動処理
- **pLaTeX**: 従来型（platex → dvipdfmx）

### 数学・物理文書

数学・物理テンプレートには以下が含まれます：

```latex
% 数学記号
\usepackage{amsmath,amssymb,amsthm}
\usepackage{mathtools}

% 物理記号
\usepackage{physics}
\usepackage{siunitx}

% 図表
\usepackage{tikz}
\usepackage{pgfplots}
```

## 🔧 高度な使用方法

### 複数プロジェクトの一括処理

```bash
# 全レポートのコンパイル
find courses/ -name "main.tex" -exec ./scripts/compile.sh {} \;

# 全レポートの品質チェック
find courses/ -name "main.tex" -exec ./scripts/check-quality.sh {} \;

# 特定学期のみ
find courses/2025-fall/ -name "main.tex" -exec ./scripts/compile.sh {} \;
```

### エイリアスの設定

```bash
# ~/.bashrc または ~/.zshrc に追加
alias latex-new='./scripts/new-report.sh'
alias latex-compile='./scripts/compile.sh'
alias latex-check='./scripts/check-quality.sh'
alias latex-templates='./scripts/manage-templates.sh'

# 使用例
latex-new                           # 新規プロジェクト作成
latex-templates list --category     # テンプレート一覧
latex-compile main.tex -o           # コンパイル＋PDF表示
```

### 作業効率化

```bash
# プロジェクトルートへの移動
cd /path/to/university-latex

# 現在作業中のレポートへの移動
cd courses/2025-fall/mathematics/report01

# 編集とコンパイルの同時実行
code main.tex && ./scripts/compile.sh main.tex -w
```

## 🛠️ トラブルシューティング

### コンパイルエラー

1. **ログファイル確認**

   ```bash
   cat output/main.log | grep -i error
   ```

2. **一時ファイル削除**

   ```bash
   rm output/*.aux output/*.out output/*.toc
   ```

3. **日本語フォント問題**

   ```bash
   ./scripts/compile.sh main.tex -c lualatex
   ```

4. **テンプレート固有の問題**

   ```bash
   ./scripts/manage-templates.sh info template-id
   ./scripts/manage-templates.sh validate
   ```

### テンプレート管理エラー

1. **設定ファイル検証**

   ```bash
   ./scripts/manage-templates.sh validate
   ```

2. **バックアップから復元**

   ```bash
   ./scripts/manage-templates.sh restore
   ```

3. **jq未インストール**

   ```bash
   # macOS
   brew install jq
   
   # Ubuntu/Debian
   sudo apt install jq
   ```

### Docker関連問題

```bash
# 権限問題の解決
sudo chown -R $USER:$USER .

# ディスク容量不足
docker system prune -a

# ネットワーク問題
docker compose down && docker compose up
```

## 📚 リソース・参考情報

### ドキュメント

- **詳細設定**: `CLAUDE.md`
- **API使用方法**: `API_USAGE_GUIDE.md`
- **テンプレート**: `templates/` ディレクトリ

### ヘルプコマンド

```bash
./scripts/manage-templates.sh help       # テンプレート管理ヘルプ
./scripts/compile.sh --help              # コンパイルオプション
./scripts/check-quality.sh --help        # 品質チェックオプション
```

### オンラインリソース

- LaTeX文法: [Overleaf Documentation](https://www.overleaf.com/learn)
- 日本語LaTeX: [LuaTeX-ja](https://github.com/luatexja/luatexja)
- 数学記号: [Comprehensive LaTeX Symbol List](http://tug.ctan.org/info/symbols/comprehensive/symbols-a4.pdf)

## 🎯 使用例とベストプラクティス

### 学期開始時のセットアップ

```bash
# 1. 新学期用のプロジェクト作成
./scripts/new-report.sh
# → 2025-fall/mathematics/linear-algebra を作成

# 2. よく使うテンプレートの確認
./scripts/manage-templates.sh list --category

# 3. 不要なテンプレートの無効化
./scripts/manage-templates.sh disable presentation
```

### 日常的な文書作成

```bash
# 1. 作業ディレクトリに移動
cd courses/2025-fall/mathematics/linear-algebra

# 2. 監視モードでコンパイル開始
../../../../../scripts/compile.sh main.tex -w

# 3. 別ターミナルで編集
code main.tex
```

### レポート提出前のチェック

```bash
# 1. 品質チェック実行
./scripts/check-quality.sh courses/2025-fall/mathematics/linear-algebra/main.tex

# 2. 最終コンパイル（BibTeX含む）
./scripts/compile.sh courses/2025-fall/mathematics/linear-algebra/main.tex -b

# 3. PDF確認
open courses/2025-fall/mathematics/linear-algebra/output/main.pdf
```
