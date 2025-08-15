# University LaTeX API

他のアプリケーションから大学LaTeXシステムを利用できるRESTful APIサーバーです。

## 機能

- **LaTeX コンパイル**: 複数のコンパイラ対応（LuaLaTeX, pdfLaTeX, XeLaTeX, pLaTeX）
- **プロジェクト管理**: 新しいレポートプロジェクトの作成と管理
- **品質チェック**: 文書構造、日本語設定、図表等の品質分析
- **テンプレート管理**: 5種類のテンプレート（基本、実験、プログラミング、論文、プレゼン）
- **ファイル操作**: ファイル内容の取得、プロジェクト一覧表示

## クイックスタート

### 1. 依存関係のインストール

```bash
pip install flask flask-cors
```

### 2. APIサーバーの起動

```bash
cd /path/to/university-latex
python api/server.py
```

サーバーは `http://localhost:5000` で起動します。

### 3. 基本的な使用例

```bash
# ヘルスチェック
curl http://localhost:5000/api/health

# テンプレート一覧の取得
curl http://localhost:5000/api/templates

# 新しいプロジェクトの作成
curl -X POST http://localhost:5000/api/projects \
  -H "Content-Type: application/json" \
  -d '{
    "semester": "2024-fall",
    "course": "physics",
    "report_name": "experiment1",
    "template": "report-experiment.tex"
  }'

# LaTeX文書のコンパイル
curl -X POST http://localhost:5000/api/compile \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "courses/2024-fall/physics/experiment1/main.tex",
    "compiler": "lualatex",
    "use_bibtex": true
  }'

# 品質チェック
curl -X POST http://localhost:5000/api/quality-check \
  -H "Content-Type: application/json" \
  -d '{
    "file_path": "courses/2024-fall/physics/experiment1/main.tex"
  }'
```

## API エンドポイント

### システム関連

#### `GET /api/health`
サーバーのヘルスチェック

**レスポンス例:**
```json
{
  "success": true,
  "message": "API server is running",
  "data": {
    "version": "1.0.0",
    "timestamp": "2024-01-01T12:00:00Z",
    "project_root": "/path/to/university-latex"
  }
}
```

#### `GET /api/system/info`
システム情報の取得

**レスポンス例:**
```json
{
  "success": true,
  "message": "System information retrieved",
  "data": {
    "project_root": "/path/to/university-latex",
    "docker_available": true,
    "supported_compilers": ["lualatex", "pdflatex", "xelatex", "platex"],
    "total_project_size_mb": 15.6,
    "api_version": "1.0.0"
  }
}
```

### テンプレート管理

#### `GET /api/templates`
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
        "use_case": "授業レポート、課題提出用",
        "path": "templates/report-basic.tex",
        "size": 2048,
        "modified": "2024-01-01T12:00:00Z"
      }
    ]
  }
}
```

#### `GET /api/templates/<template_name>`
特定のテンプレートの内容を取得

**パラメータ:**
- `template_name`: テンプレートファイル名

**レスポンス例:**
```json
{
  "success": true,
  "message": "Template content retrieved successfully",
  "data": {
    "filename": "report-basic.tex",
    "content": "\\documentclass[12pt,a4paper]{ltjsarticle}...",
    "size": 2048,
    "lines": 50
  }
}
```

### プロジェクト管理

#### `POST /api/projects`
新しいプロジェクトを作成

**リクエストボディ:**
```json
{
  "semester": "2024-fall",
  "course": "physics",
  "report_name": "experiment1",
  "template": "report-experiment.tex"  // オプション
}
```

**レスポンス例:**
```json
{
  "success": true,
  "message": "Project created successfully",
  "data": {
    "project_path": "courses/2024-fall/physics/experiment1",
    "absolute_path": "/path/to/project",
    "template_used": "report-experiment.tex",
    "created_files": ["main.tex", "README.md", ".gitignore"]
  }
}
```

#### `GET /api/projects`
プロジェクト一覧の取得

**レスポンス例:**
```json
{
  "success": true,
  "message": "Projects retrieved successfully",
  "data": {
    "projects": [
      {
        "semester": "2024-fall",
        "course": "physics",
        "name": "experiment1",
        "path": "courses/2024-fall/physics/experiment1",
        "main_tex_path": "courses/2024-fall/physics/experiment1/main.tex",
        "has_pdf": true,
        "modified": "2024-01-01T12:00:00Z",
        "pdf_info": {
          "path": "courses/2024-fall/physics/experiment1/output/main.pdf",
          "size": 1048576,
          "created": "2024-01-01T12:30:00Z"
        }
      }
    ],
    "total_count": 1
  }
}
```

### コンパイル

#### `POST /api/compile`
LaTeX文書をコンパイル

**リクエストボディ:**
```json
{
  "file_path": "courses/2024-fall/physics/experiment1/main.tex",
  "compiler": "lualatex",        // オプション: "lualatex"|"pdflatex"|"xelatex"|"platex"
  "use_bibtex": true,           // オプション: デフォルト false
  "quick": false,               // オプション: デフォルト false（1回のみコンパイル）
  "open_pdf": false             // オプション: デフォルト false（API では無効）
}
```

**レスポンス例:**
```json
{
  "success": true,
  "message": "Compilation completed",
  "data": {
    "command": "./scripts/compile.sh courses/2024-fall/physics/experiment1/main.tex -c lualatex -b",
    "returncode": 0,
    "compiler": "lualatex",
    "used_bibtex": true,
    "quick_mode": false,
    "output": "コンパイル出力...",
    "pdf_info": {
      "path": "courses/2024-fall/physics/experiment1/output/main.pdf",
      "size": 1048576,
      "size_mb": 1.0,
      "created": "2024-01-01T12:30:00Z"
    }
  }
}
```

### 品質チェック

#### `POST /api/quality-check`
文書の品質をチェック

**リクエストボディ:**
```json
{
  "file_path": "courses/2024-fall/physics/experiment1/main.tex"
}
```

**レスポンス例:**
```json
{
  "success": true,
  "message": "Quality check completed",
  "data": {
    "file_path": "courses/2024-fall/physics/experiment1/main.tex",
    "quality_score": 85,
    "quality_level": "good",
    "errors": 0,
    "warnings": 3,
    "suggestions": [
      "1. 著者を\\authorコマンドで定義することを推奨します",
      "2. すべての図表にキャプションを付けることを推奨します"
    ],
    "full_output": "完全な品質チェック出力...",
    "check_successful": true
  }
}
```

**品質レベル:**
- `excellent` (90-100点): 優秀
- `good` (70-89点): 良好
- `needs_improvement` (50-69点): 改善が必要
- `poor` (0-49点): 要大幅改善

### ファイル操作

#### `GET /api/files/<path:file_path>`
ファイル内容の取得

**パラメータ:**
- `file_path`: プロジェクトルートからの相対パス

**テキストファイルのレスポンス例:**
```json
{
  "success": true,
  "message": "File content retrieved",
  "data": {
    "path": "courses/2024-fall/physics/experiment1/main.tex",
    "content": "\\documentclass[12pt,a4paper]{ltjsarticle}...",
    "size": 2048,
    "lines": 50,
    "modified": "2024-01-01T12:00:00Z",
    "encoding": "utf-8"
  }
}
```

**PDFファイルの場合:**
バイナリデータとして `application/pdf` MIMEタイプでファイルを返します。

## エラーハンドリング

すべてのAPIエンドポイントは統一されたエラー形式を使用します：

```json
{
  "success": false,
  "message": "エラーの概要",
  "data": null,
  "errors": [
    "詳細なエラーメッセージ1",
    "詳細なエラーメッセージ2"
  ]
}
```

**HTTPステータスコード:**
- `200`: 成功
- `400`: 不正なリクエスト
- `404`: リソースが見つからない
- `413`: ファイルサイズ超過（最大16MB）
- `500`: サーバー内部エラー

## 設定とカスタマイズ

### 環境変数

```bash
export LATEX_API_HOST=0.0.0.0          # ホストアドレス（デフォルト: 0.0.0.0）
export LATEX_API_PORT=5000             # ポート番号（デフォルト: 5000）
export LATEX_API_DEBUG=true            # デバッグモード（デフォルト: true）
export LATEX_API_MAX_FILE_SIZE=16MB    # 最大ファイルサイズ（デフォルト: 16MB）
```

### セキュリティ設定

本APIは開発・研究用途を想定しており、以下のセキュリティ考慮事項があります：

- **CORS有効**: すべてのオリジンからのアクセスを許可
- **認証なし**: 現在認証機能は実装されていません
- **ファイルアクセス**: プロジェクトルート配下のファイルのみアクセス可能
- **コマンド実行**: shell injection対策済み

本番環境で使用する場合は、適切な認証・認可機能を追加してください。

## 使用例

### Python クライアントの例

```python
import requests
import json

# APIベースURL
BASE_URL = "http://localhost:5000/api"

def create_and_compile_project():
    """プロジェクト作成からコンパイルまでの例"""
    
    # 1. 新しいプロジェクトの作成
    project_data = {
        "semester": "2024-fall",
        "course": "physics",
        "report_name": "api-test",
        "template": "report-basic.tex"
    }
    
    response = requests.post(f"{BASE_URL}/projects", json=project_data)
    if response.status_code == 200:
        project = response.json()
        print(f"プロジェクト作成成功: {project['data']['project_path']}")
        
        # 2. コンパイル実行
        compile_data = {
            "file_path": project['data']['project_path'] + "/main.tex",
            "compiler": "lualatex",
            "use_bibtex": False
        }
        
        compile_response = requests.post(f"{BASE_URL}/compile", json=compile_data)
        if compile_response.status_code == 200:
            result = compile_response.json()
            if result['success']:
                print(f"コンパイル成功: {result['data']['pdf_info']['path']}")
                
                # 3. 品質チェック
                quality_data = {"file_path": compile_data['file_path']}
                quality_response = requests.post(f"{BASE_URL}/quality-check", json=quality_data)
                
                if quality_response.status_code == 200:
                    quality = quality_response.json()
                    print(f"品質スコア: {quality['data']['quality_score']}/100")
                    print(f"品質レベル: {quality['data']['quality_level']}")
        else:
            print(f"コンパイルエラー: {compile_response.text}")
    else:
        print(f"プロジェクト作成エラー: {response.text}")

if __name__ == "__main__":
    create_and_compile_project()
```

### JavaScript (Node.js) クライアントの例

```javascript
const axios = require('axios');

const BASE_URL = 'http://localhost:5000/api';

async function createAndCompileProject() {
    try {
        // 1. プロジェクト作成
        const projectData = {
            semester: '2024-fall',
            course: 'mathematics',
            report_name: 'js-api-test',
            template: 'report-basic.tex'
        };
        
        const projectResponse = await axios.post(`${BASE_URL}/projects`, projectData);
        console.log('プロジェクト作成成功:', projectResponse.data.data.project_path);
        
        // 2. コンパイル
        const compileData = {
            file_path: `${projectResponse.data.data.project_path}/main.tex`,
            compiler: 'lualatex'
        };
        
        const compileResponse = await axios.post(`${BASE_URL}/compile`, compileData);
        
        if (compileResponse.data.success) {
            console.log('コンパイル成功:', compileResponse.data.data.pdf_info.path);
            
            // 3. ファイル取得
            const fileResponse = await axios.get(`${BASE_URL}/files/${compileData.file_path}`);
            console.log('TeXファイル行数:', fileResponse.data.data.lines);
        }
        
    } catch (error) {
        console.error('エラー:', error.response?.data || error.message);
    }
}

createAndCompileProject();
```

## トラブルシューティング

### よくある問題

1. **Docker が利用できない**
   ```
   Error: Docker not available
   ```
   - Dockerがインストールされ、起動していることを確認
   - `docker compose` コマンドが利用可能であることを確認

2. **ファイルが見つからない**
   ```
   Error: File not found
   ```
   - ファイルパスがプロジェクトルートからの相対パスになっているか確認
   - ファイルが実際に存在するか確認

3. **コンパイルエラー**
   ```
   Compilation failed
   ```
   - LaTeX構文エラーがないか確認
   - 必要なパッケージが読み込まれているか確認
   - 日本語文書の場合はLuaLaTeX使用を推奨

4. **ポートが使用中**
   ```
   Port 5000 is already in use
   ```
   - 他のアプリケーションが5000ポートを使用していないか確認
   - 環境変数 `LATEX_API_PORT` で別のポートを指定

### ログとデバッグ

APIサーバーはデフォルトでデバッグモードで起動し、詳細なログを出力します：

```bash
python api/server.py
```

コンパイル時のログは `courses/.../output/*.log` ファイルで確認できます。

## 開発とコントリビューション

### 開発環境のセットアップ

```bash
# リポジトリのクローン
git clone <repository-url>
cd university-latex

# Python依存関係のインストール
pip install flask flask-cors

# APIサーバーの起動
python api/server.py
```

### API拡張

新しいエンドポイントを追加する場合：

1. `api/server.py` にルート関数を追加
2. `ApiResponse` データクラスを使用して統一されたレスポンス形式を維持
3. 適切なエラーハンドリングを実装
4. このREADMEのドキュメントを更新

## ライセンス

このプロジェクトは大学での学習・研究用途に特化しています。詳細なライセンス情報については、メインプロジェクトのLICENSEファイルを参照してください。