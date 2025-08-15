# University LaTeX API 使用ガイド

このガイドでは、University LaTeX APIの使い方を詳しく説明します。このAPIを使用することで、外部アプリケーションからLaTeX文書のコンパイル、プロジェクト管理、品質チェックなどの機能を利用できます。

## 目次

1. [クイックスタート](#クイックスタート)
2. [APIの起動方法](#apiの起動方法)
3. [基本的な使い方](#基本的な使い方)
4. [主要な機能](#主要な機能)
5. [エンドポイントリファレンス](#エンドポイントリファレンス)
6. [実践的な使用例](#実践的な使用例)
7. [トラブルシューティング](#トラブルシューティング)

## クイックスタート

### 1. APIサーバーの起動

```bash
# Dockerを使用してAPIを起動（推奨）
cd api
docker compose -f docker-compose.api.yaml up -d

# またはスクリプトを使用
./scripts/start-api.sh --docker --port 5001
```

### 2. ヘルスチェック

```bash
curl http://localhost:5001/api/health
```

### 3. 簡単なプロジェクトの作成とコンパイル

```python
import requests
import json

# APIのベースURL
API_URL = "http://localhost:5001/api"

# 新しいプロジェクトを作成
project_data = {
    "semester": "2024-fall",
    "course": "mathematics",
    "report_name": "calculus-report",
    "template": "report-basic.tex"
}

response = requests.post(f"{API_URL}/projects", json=project_data)
project = response.json()
print(f"プロジェクト作成: {project['data']['path']}")

# LaTeX文書をコンパイル
compile_data = {
    "file_path": f"{project['data']['path']}/main.tex",
    "compiler": "lualatex"
}

response = requests.post(f"{API_URL}/compile", json=compile_data)
result = response.json()
if result['success']:
    print(f"PDF生成成功: {result['data']['pdf_path']}")
```

## APIの起動方法

### Docker Composeを使用（推奨）

```bash
# APIディレクトリに移動
cd api

# サービスを起動
docker compose -f docker-compose.api.yaml up -d

# ログを確認
docker compose -f docker-compose.api.yaml logs -f latex-api

# サービスを停止
docker compose -f docker-compose.api.yaml down
```

### 起動スクリプトを使用

```bash
# デフォルト設定で起動（ポート5001）
./scripts/start-api.sh

# Dockerモードで起動
./scripts/start-api.sh --docker

# カスタムポートで起動
./scripts/start-api.sh --port 8000

# プロダクションモードで起動
./scripts/start-api.sh --production
```

### 環境変数の設定

```bash
export LATEX_API_PORT=5001
export FLASK_ENV=development
export FLASK_DEBUG=true
```

## 基本的な使い方

### Python クライアント

```python
import requests
import json
from pathlib import Path

class LaTeXAPIClient:
    def __init__(self, base_url="http://localhost:5001/api"):
        self.base_url = base_url
        
    def health_check(self):
        """APIの稼働状況を確認"""
        response = requests.get(f"{self.base_url}/health")
        return response.json()
    
    def create_project(self, semester, course, report_name, template=None):
        """新しいプロジェクトを作成"""
        data = {
            "semester": semester,
            "course": course,
            "report_name": report_name,
            "template": template
        }
        response = requests.post(f"{self.base_url}/projects", json=data)
        return response.json()
    
    def compile_document(self, file_path, compiler="lualatex", use_bibtex=False):
        """LaTeX文書をコンパイル"""
        data = {
            "file_path": file_path,
            "compiler": compiler,
            "use_bibtex": use_bibtex
        }
        response = requests.post(f"{self.base_url}/compile", json=data)
        return response.json()
    
    def check_quality(self, file_path):
        """文書の品質をチェック"""
        data = {"file_path": file_path}
        response = requests.post(f"{self.base_url}/quality", json=data)
        return response.json()

# 使用例
client = LaTeXAPIClient()

# ヘルスチェック
status = client.health_check()
print(f"API Status: {status['message']}")

# プロジェクト作成
project = client.create_project(
    semester="2024-fall",
    course="physics",
    report_name="quantum-mechanics",
    template="report-experiment.tex"
)
print(f"Created: {project['data']['path']}")

# コンパイル
result = client.compile_document(
    file_path=f"{project['data']['path']}/main.tex",
    compiler="lualatex"
)
if result['success']:
    print(f"PDF: {result['data']['pdf_path']}")
```

### JavaScript/Node.js クライアント

```javascript
const axios = require('axios');

class LaTeXAPIClient {
    constructor(baseURL = 'http://localhost:5001/api') {
        this.client = axios.create({ baseURL });
    }
    
    async healthCheck() {
        const response = await this.client.get('/health');
        return response.data;
    }
    
    async createProject(semester, course, reportName, template = null) {
        const response = await this.client.post('/projects', {
            semester,
            course,
            report_name: reportName,
            template
        });
        return response.data;
    }
    
    async compileDocument(filePath, compiler = 'lualatex', useBibtex = false) {
        const response = await this.client.post('/compile', {
            file_path: filePath,
            compiler,
            use_bibtex: useBibtex
        });
        return response.data;
    }
    
    async checkQuality(filePath) {
        const response = await this.client.post('/quality', {
            file_path: filePath
        });
        return response.data;
    }
}

// 使用例
async function main() {
    const client = new LaTeXAPIClient();
    
    // ヘルスチェック
    const status = await client.healthCheck();
    console.log(`API Status: ${status.message}`);
    
    // プロジェクト作成
    const project = await client.createProject(
        '2024-fall',
        'chemistry',
        'organic-synthesis',
        'report-experiment.tex'
    );
    console.log(`Created: ${project.data.path}`);
    
    // コンパイル
    const result = await client.compileDocument(
        `${project.data.path}/main.tex`,
        'lualatex'
    );
    if (result.success) {
        console.log(`PDF: ${result.data.pdf_path}`);
    }
}

main().catch(console.error);
```

### cURL コマンド例

```bash
# ヘルスチェック
curl -X GET http://localhost:5001/api/health

# テンプレート一覧取得
curl -X GET http://localhost:5001/api/templates

# プロジェクト作成
curl -X POST http://localhost:5001/api/projects \
  -H "Content-Type: application/json" \
  -d '{
    "semester": "2024-fall",
    "course": "computer-science",
    "report_name": "algorithm-analysis",
    "template": "report-programming.tex"
  }'

# 文書コンパイル
curl -X POST http://localhost:5001/api/compile \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "courses/2024-fall/computer-science/algorithm-analysis/main.tex",
    "compiler": "lualatex"
  }'

# 品質チェック
curl -X POST http://localhost:5001/api/quality-check \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "courses/2024-fall/computer-science/algorithm-analysis/main.tex"
  }'

# テンプレート管理
curl -X POST http://localhost:5001/api/templates/manage \
  -H "Content-Type: application/json" \
  -d '{
    "action": "list"
  }'

# ファイルアップロード
curl -X POST http://localhost:5001/api/upload \
  -F "file=@graph.png" \
  -F "project_path=courses/2024-fall/physics/quantum" \
  -F "subdirectory=figures"

# プロジェクト削除
curl -X DELETE http://localhost:5001/api/projects/courses/2024-fall/test/sample-project
```

## 主要な機能

### 1. プロジェクト管理

- **プロジェクト作成**: テンプレートを使用して新しいLaTeXプロジェクトを作成
- **プロジェクト一覧**: 既存のプロジェクトを検索・表示
- **プロジェクト削除**: 不要なプロジェクトを削除

### 2. LaTeXコンパイル

- **複数のコンパイラ対応**: LuaLaTeX, pdfLaTeX, XeLaTeX, pLaTeX
- **BibTeX対応**: 参考文献の自動処理
- **エラーハンドリング**: コンパイルエラーの詳細な報告

### 3. 品質チェック

- **文書構造の検証**: セクション、図表、参照の確認
- **日本語設定の確認**: フォント、文字コードの検証
- **スコアリング**: 100点満点での品質評価

### 4. テンプレート管理

- **組み込みテンプレート**: 11種類の用途別テンプレート
- **テンプレート情報**: 各テンプレートの詳細説明
- **テンプレート操作**: 有効化/無効化、追加、削除
- **設定検証**: テンプレート設定の検証

### 5. ファイル操作

- **ファイルアップロード**: LaTeXファイルや画像のアップロード
- **PDFダウンロード**: 生成されたPDFのダウンロード
- **ファイル監視**: リアルタイムファイル変更監視
- **プロジェクト削除**: 不要なプロジェクトの削除

## エンドポイントリファレンス

### GET /api/health

APIサーバーのヘルスチェック

**レスポンス例:**

```json
{
  "success": true,
  "message": "API server is running",
  "data": {
    "version": "1.0.0",
    "timestamp": "2024-01-15T10:30:00",
    "project_root": "/app"
  }
}
```

### GET /api/templates

利用可能なテンプレート一覧を取得

**レスポンス例:**

```json
{
  "success": true,
  "message": "Templates retrieved successfully",
  "data": {
    "templates": [
      {
        "name": "基本レポート",
        "filename": "report-basic.tex",
        "description": "一般的な学術レポート用テンプレート",
        "use_case": "授業レポート、課題提出用"
      },
      {
        "name": "実験レポート",
        "filename": "report-experiment.tex",
        "description": "実験・データ分析用テンプレート",
        "use_case": "実験結果報告、データ分析レポート"
      }
    ]
  }
}
```

### POST /api/projects

新しいプロジェクトを作成

**リクエストボディ:**

```json
{
  "semester": "2024-fall",
  "course": "mathematics",
  "report_name": "linear-algebra",
  "template": "report-basic.tex"  // オプション
}
```

**レスポンス例:**

```json
{
  "success": true,
  "message": "Project created successfully",
  "data": {
    "path": "courses/2024-fall/mathematics/linear-algebra",
    "main_file": "courses/2024-fall/mathematics/linear-algebra/main.tex",
    "created_at": "2024-01-15T10:30:00"
  }
}
```

### GET /api/projects

プロジェクト一覧を取得

**クエリパラメータ:**

- `semester`: 学期でフィルタ（例: 2024-fall）
- `course`: コース名でフィルタ

**レスポンス例:**

```json
{
  "success": true,
  "message": "Projects retrieved successfully",
  "data": {
    "projects": [
      {
        "path": "courses/2024-fall/mathematics/linear-algebra",
        "semester": "2024-fall",
        "course": "mathematics",
        "report_name": "linear-algebra",
        "has_pdf": true,
        "last_modified": "2024-01-15T10:30:00"
      }
    ],
    "total": 1
  }
}
```

### POST /api/compile

LaTeX文書をコンパイル

**リクエストボディ:**

```json
{
  "file_path": "courses/2024-fall/mathematics/linear-algebra/main.tex",
  "compiler": "lualatex",      // デフォルト: lualatex
  "use_bibtex": false,         // デフォルト: false
  "quick": false,              // デフォルト: false
  "open_pdf": false,           // デフォルト: false
  "watch": false               // デフォルト: false
}
```

**レスポンス例:**

```json
{
  "success": true,
  "message": "Compilation successful",
  "data": {
    "pdf_path": "courses/2024-fall/mathematics/linear-algebra/output/main.pdf",
    "log_path": "courses/2024-fall/mathematics/linear-algebra/output/main.log",
    "compile_time": 3.2,
    "compiler_used": "lualatex"
  }
}
```

### POST /api/quality-check

文書の品質をチェック

**リクエストボディ:**

```json
{
  "file_path": "courses/2024-fall/mathematics/linear-algebra/main.tex"
}
```

**レスポンス例:**

```json
{
  "success": true,
  "message": "Quality check completed",
  "data": {
    "score": 95,
    "rating": "excellent",
    "checks": {
      "document_structure": {
        "score": 10,
        "max_score": 10,
        "message": "Document structure is valid"
      },
      "japanese_settings": {
        "score": 10,
        "max_score": 10,
        "message": "Japanese settings are properly configured"
      },
      "figures_and_tables": {
        "score": 8,
        "max_score": 10,
        "message": "2 figures without captions"
      }
    },
    "suggestions": [
      "すべての図表にキャプションを追加してください",
      "参考文献リストを追加することを検討してください"
    ]
  }
}
```

### GET /api/system/info

システム情報を取得

**レスポンス例:**

```json
{
  "success": true,
  "message": "System information retrieved",
  "data": {
    "project_root": "/workspace",
    "courses_directory": "/workspace/courses",
    "templates_directory": "/workspace/templates",
    "scripts_directory": "/workspace/scripts",
    "docker_available": true,
    "docker_compose_available": true,
    "supported_compilers": ["lualatex", "pdflatex", "xelatex", "platex"],
    "total_project_size_mb": 125.8,
    "api_version": "1.0.0"
  }
}
```

### POST /api/templates/manage

テンプレート管理操作（CLI manage-templates.sh 相当）

**リクエストボディ:**

```json
{
  "action": "list",           // list, enable, disable, add, info, validate
  "template_id": "template-1",  // enable, disable, info時に必要
  "template_file": "path.tex", // add時に必要
  "category": true            // list時のオプション
}
```

**レスポンス例:**

```json
{
  "success": true,
  "message": "Template management action 'list' completed",
  "data": {
    "action": "list",
    "command": "./scripts/manage-templates.sh list",
    "output": "Available templates:\n1. report-basic.tex\n2. report-experiment.tex\n...",
    "stderr": null
  }
}
```

### POST /api/watch

ファイル監視の開始

**リクエストボディ:**

```json
{
  "file_path": "courses/2024-fall/mathematics/linear-algebra/main.tex"
}
```

**レスポンス例:**

```json
{
  "success": true,
  "message": "Watch mode information retrieved",
  "data": {
    "file_path": "courses/2024-fall/mathematics/linear-algebra/main.tex",
    "absolute_path": "/workspace/courses/2024-fall/mathematics/linear-algebra/main.tex",
    "status": "watch_ready",
    "message": "File watching requires WebSocket or SSE implementation",
    "last_modified": "2024-01-15T10:30:00"
  }
}
```

### POST /api/upload

ファイルをアップロード

**リクエスト形式:** multipart/form-data

**パラメータ:**

- `file`: アップロードするファイル
- `project_path`: プロジェクトのパス
- `subdirectory`: サブディレクトリ（オプション、例: "figures"）

**レスポンス例:**

```json
{
  "success": true,
  "message": "File uploaded successfully",
  "data": {
    "filename": "graph.png",
    "path": "courses/2024-fall/mathematics/linear-algebra/figures/graph.png",
    "size": 45678
  }
}
```

### GET /api/files/{path}

ファイル内容の取得またはPDFダウンロード

**パラメータ:**

- `path`: ファイルのパス

**レスポンス（テキストファイル）:**

```json
{
  "success": true,
  "message": "File content retrieved",
  "data": {
    "path": "courses/2024-fall/mathematics/linear-algebra/main.tex",
    "content": "\\documentclass{...}",
    "size": 1234,
    "lines": 45,
    "modified": "2024-01-15T10:30:00",
    "encoding": "utf-8"
  }
}
```

**レスポンス（PDFファイル）:** PDFファイル（application/pdf）

### DELETE /api/projects/{path}

プロジェクトを削除

**パラメータ:**

- `path`: プロジェクトのパス（例: courses/2024-fall/test/test-project）

**レスポンス例:**

```json
{
  "success": true,
  "message": "Project deleted successfully",
  "data": {
    "deleted_path": "courses/2024-fall/test/test-project",
    "absolute_path": "/workspace/courses/2024-fall/test/test-project"
  }
}
```

## 実践的な使用例

### 例1: 実験レポートの自動化ワークフロー

```python
import requests
import json
import time
from pathlib import Path

class ExperimentReportAutomation:
    def __init__(self, api_url="http://localhost:5001/api"):
        self.api_url = api_url
    
    def create_experiment_report(self, experiment_name, data_file):
        """実験レポートを作成し、データを含めてコンパイル"""
        
        # 1. プロジェクト作成
        project_response = requests.post(
            f"{self.api_url}/projects",
            json={
                "semester": "2024-fall",
                "course": "physics-lab",
                "report_name": experiment_name,
                "template": "report-experiment.tex"
            }
        )
        project = project_response.json()
        project_path = project['data']['path']
        
        # 2. データファイルをアップロード
        with open(data_file, 'rb') as f:
            files = {'file': f}
            data = {
                'project_path': project_path,
                'subdirectory': 'data'
            }
            upload_response = requests.post(
                f"{self.api_url}/upload",
                files=files,
                data=data
            )
        
        # 3. LaTeX文書を編集（APIを通じて、または直接ファイルシステムで）
        # ここでは仮定として、テンプレートがデータファイルを参照するように設定済み
        
        # 4. コンパイル
        compile_response = requests.post(
            f"{self.api_url}/compile",
            json={
                "file_path": f"{project_path}/main.tex",
                "compiler": "lualatex",
                "use_bibtex": True
            }
        )
        
        # 5. 品質チェック
        quality_response = requests.post(
            f"{self.api_url}/quality-check",
            json={"file_path": f"{project_path}/main.tex"}
        )
        
        quality = quality_response.json()
        print(f"レポート品質スコア: {quality['data']['quality_score']}/100")
        
        if quality['data']['suggestions']:
            print("改善提案:")
            for suggestion in quality['data']['suggestions']:
                print(f"  - {suggestion}")
        
        return {
            'project_path': project_path,
            'pdf_path': compile_response.json()['data']['pdf_info']['path'] if compile_response.json()['data']['pdf_info'] else None,
            'quality_score': quality['data']['quality_score']
        }

# 使用例
automation = ExperimentReportAutomation()
result = automation.create_experiment_report(
    experiment_name="pendulum-period",
    data_file="experiment_data.csv"
)
print(f"レポート生成完了: {result['pdf_path']}")
```

### 例2: バッチ処理による複数レポートのコンパイル

```python
import requests
import concurrent.futures
from typing import List, Dict

class BatchCompiler:
    def __init__(self, api_url="http://localhost:5001/api", max_workers=4):
        self.api_url = api_url
        self.max_workers = max_workers
    
    def compile_single(self, project_info: Dict) -> Dict:
        """単一のプロジェクトをコンパイル"""
        response = requests.post(
            f"{self.api_url}/compile",
            json={
                "file_path": project_info['file_path'],
                "compiler": project_info.get('compiler', 'lualatex'),
                "use_bibtex": project_info.get('use_bibtex', False)
            }
        )
        result = response.json()
        return {
            'project': project_info['name'],
            'success': result['success'],
            'pdf_path': result['data']['pdf_path'] if result['success'] else None,
            'error': result.get('errors')
        }
    
    def compile_batch(self, projects: List[Dict]) -> List[Dict]:
        """複数のプロジェクトを並行してコンパイル"""
        results = []
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_project = {
                executor.submit(self.compile_single, project): project 
                for project in projects
            }
            
            for future in concurrent.futures.as_completed(future_to_project):
                project = future_to_project[future]
                try:
                    result = future.result()
                    results.append(result)
                    print(f"✅ {result['project']}: コンパイル成功")
                except Exception as exc:
                    print(f"❌ {project['name']}: エラー発生 - {exc}")
                    results.append({
                        'project': project['name'],
                        'success': False,
                        'error': str(exc)
                    })
        
        return results

# 使用例
compiler = BatchCompiler()

projects = [
    {
        'name': 'math-report',
        'file_path': 'courses/2024-fall/mathematics/calculus/main.tex',
        'compiler': 'lualatex',
        'use_bibtex': True
    },
    {
        'name': 'physics-report',
        'file_path': 'courses/2024-fall/physics/mechanics/main.tex',
        'compiler': 'pdflatex'
    },
    {
        'name': 'cs-report',
        'file_path': 'courses/2024-fall/computer-science/algorithms/main.tex',
        'compiler': 'lualatex'
    }
]

results = compiler.compile_batch(projects)

# 結果サマリー
successful = sum(1 for r in results if r['success'])
print(f"\n結果: {successful}/{len(results)} プロジェクトが正常にコンパイルされました")
```

### 例3: CI/CDパイプラインとの統合

```yaml
# .github/workflows/latex-compile.yml
name: LaTeX Compilation

on:
  push:
    paths:
      - 'courses/**/*.tex'
  pull_request:
    paths:
      - 'courses/**/*.tex'

jobs:
  compile:
    runs-on: ubuntu-latest
    
    services:
      latex-api:
        image: university-latex-api:latest
        ports:
          - 5001:5001
    
    steps:
      - uses: actions/checkout@v2
      
      - name: Wait for API to be ready
        run: |
          for i in {1..30}; do
            if curl -f http://localhost:5001/api/health; then
              break
            fi
            sleep 2
          done
      
      - name: Compile LaTeX documents
        run: |
          python -c "
          import requests
          import json
          import sys
          from pathlib import Path
          
          api_url = 'http://localhost:5001/api'
          
          # 変更されたTeXファイルを検出
          tex_files = list(Path('courses').glob('**/*.tex'))
          
          for tex_file in tex_files:
              if tex_file.name == 'main.tex':
                  response = requests.post(
                      f'{api_url}/compile',
                      json={'file_path': str(tex_file)}
                  )
                  result = response.json()
                  
                  if not result['success']:
                      print(f'Compilation failed for {tex_file}')
                      print(result.get('errors'))
                      sys.exit(1)
                  else:
                      print(f'Successfully compiled {tex_file}')
          "
      
      - name: Upload PDFs
        uses: actions/upload-artifact@v2
        with:
          name: compiled-pdfs
          path: courses/**/output/*.pdf
```

### 例4: Webアプリケーションとの統合

```javascript
// Express.js バックエンドの例
const express = require('express');
const axios = require('axios');
const multer = require('multer');
const app = express();

const upload = multer({ dest: 'uploads/' });
const LATEX_API_URL = process.env.LATEX_API_URL || 'http://localhost:5001/api';

// LaTeXプロジェクトの作成エンドポイント
app.post('/create-report', async (req, res) => {
    try {
        const { semester, course, reportName, template } = req.body;
        
        // LaTeX APIを呼び出し
        const response = await axios.post(`${LATEX_API_URL}/projects`, {
            semester,
            course,
            report_name: reportName,
            template
        });
        
        res.json({
            success: true,
            projectPath: response.data.data.path
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// リアルタイムコンパイルエンドポイント
app.post('/compile-live', async (req, res) => {
    try {
        const { content, projectPath } = req.body;
        
        // 一時的にコンテンツを保存
        // (実際の実装では、ファイルシステムまたはデータベースを使用)
        
        // コンパイル
        const response = await axios.post(`${LATEX_API_URL}/compile`, {
            file_path: `${projectPath}/main.tex`,
            compiler: 'lualatex',
            quick: true  // 高速コンパイル
        });
        
        if (response.data.success) {
            res.json({
                success: true,
                pdfUrl: `/pdf/${response.data.data.pdf_path}`
            });
        } else {
            res.json({
                success: false,
                errors: response.data.errors
            });
        }
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// PDFストリーミングエンドポイント
app.get('/pdf/:path(*)', async (req, res) => {
    try {
        const response = await axios.get(
            `${LATEX_API_URL}/download/${req.params.path}`,
            { responseType: 'stream' }
        );
        
        res.setHeader('Content-Type', 'application/pdf');
        response.data.pipe(res);
    } catch (error) {
        res.status(404).send('PDF not found');
    }
});

app.listen(3000, () => {
    console.log('Web server running on port 3000');
});
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. APIサーバーが起動しない

**問題:** ポートが既に使用されている

```bash
# エラーメッセージ
⚠️  ポート 5001 は既に使用されています
```

**解決方法:**

```bash
# 使用中のポートを確認
lsof -i :5001

# 別のポートで起動
./scripts/start-api.sh --port 5002

# または既存のプロセスを終了
pkill -f "python.*server.py"
```

#### 2. コンパイルエラー

**問題:** LaTeXコンパイラが見つからない

```json
{
  "success": false,
  "errors": ["Compilation failed: lualatex not found"]
}
```

**解決方法:**

```bash
# Dockerコンテナが起動しているか確認
docker ps | grep latex-engine

# Dockerサービスを再起動
cd api
docker compose -f docker-compose.api.yaml restart
```

#### 3. ファイルアクセスエラー

**問題:** ファイルが見つからない

```json
{
  "success": false,
  "errors": ["File not found: courses/2024-fall/test/main.tex"]
}
```

**解決方法:**

```python
# ファイルパスが正しいか確認
response = requests.get(f"{API_URL}/projects")
projects = response.json()['data']['projects']
for project in projects:
    print(project['path'])

# 正しいパスを使用
correct_path = "courses/2024-fall/test/test-project/main.tex"
```

#### 4. メモリ不足

**問題:** 大きな文書のコンパイルで失敗

```json
{
  "success": false,
  "errors": ["Command timed out after 5 minutes"]
}
```

**解決方法:**

```bash
# Dockerのメモリ制限を増やす
docker update --memory="4g" api-latex-engine-1

# タイムアウトを延長（APIサーバーの設定を変更）
export LATEX_COMPILE_TIMEOUT=600  # 10分
```

#### 5. 日本語の文字化け

**問題:** PDFで日本語が正しく表示されない

**解決方法:**

```python
# LuaLaTeXを使用してコンパイル
response = requests.post(f"{API_URL}/compile", json={
    "file_path": "path/to/main.tex",
    "compiler": "lualatex"  # 日本語対応
})

# またはpLaTeXを使用
response = requests.post(f"{API_URL}/compile", json={
    "file_path": "path/to/main.tex",
    "compiler": "platex"
})
```

### デバッグ方法

#### APIログの確認

```bash
# Dockerログを確認
docker compose -f api/docker-compose.api.yaml logs -f latex-api

# ローカル実行時のログ
./scripts/start-api.sh --debug
```

#### テストスクリプトの実行

```bash
# APIの全機能をテスト
./scripts/test-api.sh

# Pythonクライアントでデモ実行
python api/client-examples/python_client.py demo
```

#### curl での詳細なデバッグ

```bash
# 詳細なHTTPヘッダーを表示
curl -v http://localhost:5001/api/health

# レスポンスタイムを測定
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:5001/api/health

# curl-format.txt の内容:
# time_namelookup:  %{time_namelookup}\n
# time_connect:  %{time_connect}\n
# time_appconnect:  %{time_appconnect}\n
# time_pretransfer:  %{time_pretransfer}\n
# time_redirect:  %{time_redirect}\n
# time_starttransfer:  %{time_starttransfer}\n
# time_total:  %{time_total}\n
```

## サポート

問題が解決しない場合は、以下の情報を含めてイシューを報告してください：

1. APIバージョン（`/api/health`のレスポンス）
2. 使用しているコンパイラ
3. エラーメッセージの全文
4. 再現手順

イシュー報告先: [GitHub Issues](https://github.com/your-repo/issues)

## まとめ

University LaTeX APIは、LaTeX文書の作成とコンパイルを自動化するための強力なツールです。このガイドで説明した機能を活用することで、効率的な文書作成ワークフローを構築できます。

主なポイント：

- RESTful APIによる簡単な統合
- 複数のプログラミング言語からの利用
- Docker による環境の一貫性
- 包括的なエラーハンドリングとデバッグ機能

ぜひAPIを活用して、LaTeX文書作成の自動化を実現してください。
