# University LaTeX Project Management System

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue)](https://docker.com)
[![LaTeX](https://img.shields.io/badge/LaTeX-LuaTeX%2C%20pdfTeX-green)](https://www.latex-project.org/)
[![Japanese](https://img.shields.io/badge/Language-Japanese%20Ready-red)](https://luatex-ja.osdn.jp/)
[![Python](https://img.shields.io/badge/Python-3.8%2B-blue)](https://python.org)

Docker環境で動作するLaTeX文書管理システム。学期・科目別のプロジェクト管理、11種類の専門テンプレート、CLI・API両対応。日本語LaTeX文書の作成・コンパイル・管理を効率化を目指す。

## ✨ 特徴

- 🏫 **学期・科目別管理**: 大学の授業に最適化された構造
- 📝 **11種類のテンプレート**: 基本レポートから卒論まで対応
- 🐳 **Docker環境**: 複雑な日本語LaTeX環境を簡単セットアップ
- 🔧 **CLI & API**: コマンドライン・プログラム両方から操作可能
- 🇯🇵 **日本語完全対応**: LuaLaTeX + Noto CJKフォント
- ⚡ **自動化**: 品質チェック、ファイル監視、バッチ処理
- 📊 **テンプレート管理**: 動的有効化・カテゴリ分類・設定検証

## 🚀 クイックスタート

### 前提条件

- [Docker](https://docs.docker.com/get-docker/) (LaTeX環境用)
- [Python 3.8+](https://python.org) (APIクライアント使用時)
- [jq](https://jqlang.github.io/jq/download/) (JSONファイル処理用)

### インストール

```bash
# リポジトリのクローン
git clone https://github.com/your-username/university-latex.git
cd university-latex

# Pythonパッケージのインストール（APIクライアントを使用する場合）
pip install -r requirements.txt

# または仮想環境を使用（推奨）
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# jqのインストール (windows chocolateyを使用)
choco install jq

# jqのインストール (macOS)
brew install jq

# jqのインストール (Ubuntu/Debian)
sudo apt install jq
```

### 新しいレポートの作成

```bash
# 対話式ウィザードで新規プロジェクト作成
./scripts/new-report.sh
```

### コンパイル

```bash
# 基本コンパイル
./scripts/compile.sh courses/2024-fall/mathematics/report01/main.tex

# BibTeX付きコンパイル
./scripts/compile.sh courses/2024-fall/mathematics/report01/main.tex -b

# 監視モード（ファイル変更時に自動再コンパイル）
./scripts/compile.sh courses/2024-fall/mathematics/report01/main.tex -w
```

### APIサーバーの起動(APIを使用する場合)

```bash
# APIサーバー起動
./scripts/start-api.sh --port 5001

# ヘルスチェック
curl http://localhost:5001/api/health
```

## 📚 目次

### 基本操作
- [CLIクイックスタート](#cli-クイックスタート)
- [APIクイックスタート](#api-クイックスタート)
- [テンプレート一覧](#テンプレート一覧)

### 詳細ガイド
- [CLI使用方法](#cli-使用方法)
- [API使用方法](#api-使用方法)
- [テンプレート管理](#テンプレート管理)
- [プロジェクト構造](#プロジェクト構造)

### 高度な機能
- [Docker環境操作](#docker-環境操作)
- [品質チェック](#品質チェック)
- [トラブルシューティング](#トラブルシューティング)

---

## CLI クイックスタート

### 🚀 基本ワークフロー

```bash
# 1. 新しいレポート作成
./scripts/new-report.sh

# 2. 文書編集
code courses/2024-fall/mathematics/report01/main.tex

# 3. コンパイル
./scripts/compile.sh courses/2024-fall/mathematics/report01/main.tex

# 4. 品質チェック
./scripts/check-quality.sh courses/2024-fall/mathematics/report01/main.tex
```

### 📋 テンプレート管理

```bash
# テンプレート一覧（カテゴリ別）
./scripts/manage-templates.sh list --category

# テンプレート有効化・無効化
./scripts/manage-templates.sh disable presentation
./scripts/manage-templates.sh enable physics-experiment

# テンプレート詳細情報
./scripts/manage-templates.sh info math
```

### 🔧 コンパイルオプション

```bash
# 基本コンパイル
./scripts/compile.sh main.tex

# BibTeX付き
./scripts/compile.sh main.tex -b

# クイックコンパイル（1回のみ）
./scripts/compile.sh main.tex -q

# PDF自動表示
./scripts/compile.sh main.tex -o

# 監視モード
./scripts/compile.sh main.tex -w

# コンパイラ指定
./scripts/compile.sh main.tex -c pdflatex
```

---

## API クイックスタート

### 🌐 APIサーバー起動

```bash
# Docker環境で起動（推奨）
cd api
docker compose -f docker-compose.api.yaml up -d

# またはスクリプト使用
./scripts/start-api.sh --docker --port 5001
```

### 📡 基本API操作

#### Python クライアント

```python
import requests

# APIクライアント
api_url = "http://localhost:5001/api"

# プロジェクト作成
response = requests.post(f"{api_url}/projects", json={
    "semester": "2024-fall",
    "course": "mathematics",
    "report_name": "calculus-report",
    "template": "report-basic.tex"
})
project = response.json()

# コンパイル
response = requests.post(f"{api_url}/compile", json={
    "file_path": f"{project['data']['project_path']}/main.tex",
    "compiler": "lualatex"
})

if response.json()['success']:
    print(f"PDF生成成功: {response.json()['data']['pdf_info']['path']}")
```

#### cURL

```bash
# ヘルスチェック
curl http://localhost:5001/api/health

# プロジェクト作成
curl -X POST http://localhost:5001/api/projects \
  -H "Content-Type: application/json" \
  -d '{
    "semester": "2024-fall",
    "course": "computer-science",
    "report_name": "algorithm-analysis",
    "template": "report-programming.tex"
  }'

# コンパイル
curl -X POST http://localhost:5001/api/compile \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "courses/2024-fall/computer-science/algorithm-analysis/main.tex",
    "compiler": "lualatex"
  }'
```

### 🔌 主要APIエンドポイント

| エンドポイント | メソッド | 説明 |
|---------------|---------|------|
| `/api/health` | GET | ヘルスチェック |
| `/api/templates` | GET | テンプレート一覧 |
| `/api/projects` | POST | プロジェクト作成 |
| `/api/projects` | GET | プロジェクト一覧 |
| `/api/compile` | POST | LaTeXコンパイル |
| `/api/quality-check` | POST | 品質チェック |
| `/api/templates/manage` | POST | テンプレート管理 |
| `/api/upload` | POST | ファイルアップロード |
| `/api/files/{path}` | GET | ファイル取得・PDF ダウンロード |

---

## テンプレート一覧

### 📚 一般

| テンプレート | ファイル名 | 用途 |
|-------------|-----------|------|
| **基本レポート** | `report-basic.tex` | 汎用的な学術レポート |
| **ディスカッション** | `report-discussion.tex` | 議論・検討用レポート |

### 🔬 理科・数学・物理

| テンプレート | ファイル名 | 用途 |
|-------------|-----------|------|
| **実験レポート** | `report-experiment.tex` | 実験データと分析 |
| **数学レポート** | `report-math.tex` | 定理・証明・数式展開 |
| **物理実験** | `report-physics-experiment.tex` | 物理実験と測定データ |
| **物理理論** | `report-physics-theory.tex` | 高度な物理理論 |

### 💻 プログラミング

| テンプレート | ファイル名 | 用途 |
|-------------|-----------|------|
| **プログラミング** | `report-programming.tex` | コード解説とアルゴリズム |

### 🎓 学術・研究

| テンプレート | ファイル名 | 用途 |
|-------------|-----------|------|
| **卒論・修論** | `thesis.tex` | 学位論文用の正式構造 |
| **文献レビュー** | `report-review.tex` | 先行研究の体系的調査 |
| **ケーススタディ** | `report-case-study.tex` | 企業・組織分析 |

### 📊 プレゼンテーション

| テンプレート | ファイル名 | 用途 |
|-------------|-----------|------|
| **プレゼンテーション** | `presentation-beamer.tex` | Beamerスライド |

---

## CLI 使用方法

### 📁 プロジェクト構造

```plaintext
university-latex/
├── courses/                    # 学期・科目別プロジェクト
│   ├── 2024-fall/
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
├── templates/                  # LaTeXテンプレート（11種類）
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

### 🎨 日本語文書作成

#### 推奨コンパイラ

- **LuaLaTeX** (推奨): Unicode対応、高機能、日本語フォント自動処理
- **pLaTeX**: 従来型（platex → dvipdfmx）

#### 基本設定

```latex
\documentclass[a4paper,11pt]{ltjsarticle}
\usepackage{luatexja-fontspec}
\setmainfont{Noto Serif CJK JP}
\setsansfont{Noto Sans CJK JP}
```

### 🔧 高度な使用方法

#### 複数プロジェクトの一括処理

```bash
# 全レポートのコンパイル
find courses/ -name "main.tex" -exec ./scripts/compile.sh {} \;

# 全レポートの品質チェック
find courses/ -name "main.tex" -exec ./scripts/check-quality.sh {} \;

# 特定学期のみ
find courses/2024-fall/ -name "main.tex" -exec ./scripts/compile.sh {} \;
```

#### エイリアスの設定

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

---

## API 使用方法

### 🌐 主要機能

#### 1. プロジェクト管理
- プロジェクト作成・一覧・削除
- テンプレート選択
- ファイル構造の自動生成

#### 2. LaTeXコンパイル
- 複数コンパイラ対応（LuaLaTeX, pdfLaTeX, XeLaTeX, pLaTeX）
- BibTeX対応
- エラーハンドリング

#### 3. 品質チェック
- 文書構造の検証
- 日本語設定の確認
- 100点満点でのスコアリング

#### 4. テンプレート管理
- 11種類の専門テンプレート
- 動的有効化・無効化
- カテゴリ別管理

#### 5. ファイル操作
- ファイルアップロード・ダウンロード
- PDFストリーミング
- リアルタイム監視

### 📡 エンドポイント詳細

#### GET /api/health
```json
{
  "success": true,
  "message": "API server is running",
  "data": {
    "version": "1.0.0",
    "timestamp": "2024-01-15T10:30:00",
    "project_root": "/workspace"
  }
}
```

#### POST /api/projects
```json
{
  "semester": "2024-fall",
  "course": "mathematics",
  "report_name": "linear-algebra",
  "template": "report-basic.tex"
}
```

#### POST /api/compile
```json
{
  "file_path": "courses/2024-fall/mathematics/linear-algebra/main.tex",
  "compiler": "lualatex",
  "use_bibtex": false,
  "quick": false
}
```

### 🐍 実践的な使用例

#### 実験レポート自動化

```python
import requests

class ExperimentReportAutomation:
    def __init__(self, api_url="http://localhost:5001/api"):
        self.api_url = api_url
    
    def create_experiment_report(self, experiment_name, data_file):
        # 1. プロジェクト作成
        project_response = requests.post(f"{self.api_url}/projects", json={
            "semester": "2024-fall",
            "course": "physics-lab",
            "report_name": experiment_name,
            "template": "report-experiment.tex"
        })
        
        # 2. データファイルアップロード
        with open(data_file, 'rb') as f:
            requests.post(f"{self.api_url}/upload", 
                files={'file': f},
                data={
                    'project_path': project_response.json()['data']['project_path'],
                    'subdirectory': 'data'
                })
        
        # 3. コンパイル
        compile_response = requests.post(f"{self.api_url}/compile", json={
            "file_path": f"{project_response.json()['data']['project_path']}/main.tex",
            "compiler": "lualatex",
            "use_bibtex": True
        })
        
        # 4. 品質チェック
        quality_response = requests.post(f"{self.api_url}/quality-check", json={
            "file_path": f"{project_response.json()['data']['project_path']}/main.tex"
        })
        
        return {
            'project_path': project_response.json()['data']['project_path'],
            'pdf_path': compile_response.json()['data']['pdf_info']['path'],
            'quality_score': quality_response.json()['data']['quality_score']
        }

# 使用例
automation = ExperimentReportAutomation()
result = automation.create_experiment_report("pendulum-period", "experiment_data.csv")
print(f"レポート生成完了: {result['pdf_path']}")
```

---

## テンプレート管理

### 📋 基本操作

```bash
# テンプレート一覧（カテゴリ別）
./scripts/manage-templates.sh list --category

# 有効なテンプレートのみ
./scripts/manage-templates.sh list --enabled

# テンプレート詳細情報
./scripts/manage-templates.sh info math

# 設定検証
./scripts/manage-templates.sh validate
```

### 🔧 管理操作

```bash
# テンプレート無効化（新規作成時に非表示）
./scripts/manage-templates.sh disable presentation

# テンプレート有効化
./scripts/manage-templates.sh enable physics-experiment

# 状態切り替え
./scripts/manage-templates.sh toggle math

# 新しいテンプレート追加
./scripts/manage-templates.sh add my-custom-template.tex
```

### 🛡️ バックアップ・復元

```bash
# 設定バックアップ
./scripts/manage-templates.sh backup

# 設定復元
./scripts/manage-templates.sh restore
```

### 🌐 API経由でのテンプレート管理

```bash
# テンプレート一覧
curl -X POST http://localhost:5001/api/templates/manage \
  -H "Content-Type: application/json" \
  -d '{"action": "list"}'

# カテゴリ別一覧
curl -X POST http://localhost:5001/api/templates/manage \
  -H "Content-Type: application/json" \
  -d '{"action": "list", "category": true}'

# テンプレート有効化
curl -X POST http://localhost:5001/api/templates/manage \
  -H "Content-Type: application/json" \
  -d '{"action": "enable", "template_id": "physics-experiment"}'
```

---

## Docker 環境操作

### 🐳 基本操作

```bash
# LaTeXコンテナでbash起動
docker compose run --rm latex bash

# 特定ディレクトリで作業
docker compose run --rm -w "/workspace/courses/2024-fall/mathematics/report01" latex bash

# 直接コマンド実行
docker compose run --rm -w "/workspace/courses/2024-fall/mathematics/report01" latex lualatex main.tex
```

### 🔧 メンテナンス

```bash
# イメージ更新
docker compose pull

# コンテナ再構築
docker compose build --no-cache

# 不要リソース削除
docker system prune
```

### 🌐 APIサーバー（Docker）

```bash
# API用Docker環境起動
cd api
docker compose -f docker-compose.api.yaml up -d

# ログ確認
docker compose -f docker-compose.api.yaml logs -f latex-api

# サービス停止
docker compose -f docker-compose.api.yaml down
```

---

## 品質チェック

### 📊 品質チェック機能

```bash
./scripts/check-quality.sh courses/2024-fall/mathematics/report01/main.tex
```

#### チェック内容
- 文書構造の妥当性
- 日本語設定の確認
- 図表キャプションの検証
- 参考文献の整合性
- ファイル構成の標準準拠

#### API経由の品質チェック

```python
import requests

response = requests.post("http://localhost:5001/api/quality-check", json={
    "file_path": "courses/2024-fall/mathematics/report01/main.tex"
})

quality_data = response.json()['data']
print(f"品質スコア: {quality_data['quality_score']}/100")
print(f"評価: {quality_data['quality_level']}")

if quality_data['suggestions']:
    print("改善提案:")
    for suggestion in quality_data['suggestions']:
        print(f"  - {suggestion}")
```

---

## トラブルシューティング

### 🛠️ よくある問題

#### 1. コンパイルエラー

**ログファイル確認**
```bash
cat output/main.log | grep -i error
```

**一時ファイル削除**
```bash
rm output/*.aux output/*.out output/*.toc
```

**日本語フォント問題**
```bash
./scripts/compile.sh main.tex -c lualatex
```

#### 2. APIサーバー起動エラー

**ポート使用中**
```bash
# 使用中ポート確認
lsof -i :5001

# 別ポートで起動
./scripts/start-api.sh --port 5002

# プロセス終了
pkill -f "python.*server.py"
```

**Docker環境問題**
```bash
# Dockerコンテナ確認
docker ps | grep latex-engine

# Docker再起動
cd api
docker compose -f docker-compose.api.yaml restart
```

#### 3. テンプレート管理エラー

**設定検証**
```bash
./scripts/manage-templates.sh validate
```

**バックアップから復元**
```bash
./scripts/manage-templates.sh restore
```

**jq未インストール**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

#### 4. Docker関連問題

```bash
# 権限問題
sudo chown -R $USER:$USER .

# ディスク容量不足
docker system prune -a

# ネットワーク問題
docker compose down && docker compose up
```

### 🔍 デバッグ方法

#### ログ確認
```bash
# Dockerログ
docker compose -f api/docker-compose.api.yaml logs -f latex-api

# APIデバッグモード
./scripts/start-api.sh --debug
```

#### 詳細テスト
```bash
# 全APIテスト
./scripts/test-api.sh

# クライアントデモ
python api/client-examples/python_client.py demo
```

---

## 📚 リソース

### 📖 ドキュメント
- **プロジェクト設定**: `CLAUDE.md`
- **API詳細**: `API_USAGE_GUIDE.md`
- **CLI詳細**: `CLI_USAGE_GUIDE.md`

### 🆘 ヘルプコマンド
```bash
./scripts/manage-templates.sh help       # テンプレート管理ヘルプ
./scripts/compile.sh --help              # コンパイルオプション
./scripts/check-quality.sh --help        # 品質チェックオプション
```

### 🌐 オンラインリソース
- [LaTeX文法 - Overleaf](https://www.overleaf.com/learn)
- [日本語LaTeX - LuaTeX-ja](https://github.com/luatexja/luatexja)
- [数学記号一覧](http://tug.ctan.org/info/symbols/comprehensive/symbols-a4.pdf)

---

## 🤝 コントリビューション

プロジェクトへの貢献を歓迎します！

### 🐛 バグ報告

以下の情報を含めてIssueを作成してください：

1. 環境情報（OS、Docker バージョン）
2. エラーメッセージの全文
3. 再現手順
4. 期待される動作

### 🚀 機能提案

新機能の提案や改善案があれば、Issueで議論しましょう。

### 📝 プルリクエスト

1. フォークしてブランチを作成
2. 変更を実装
3. テストを実行
4. プルリクエストを作成

---

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE) の下で公開されています。

---
