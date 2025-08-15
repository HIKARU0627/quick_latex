#!/bin/bash

# University LaTeX API サーバー起動スクリプト
# 使用方法: ./scripts/start-api.sh [options]

# デフォルト設定
HOST="0.0.0.0"
PORT="5000"
DEBUG="true"
USE_DOCKER="false"

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            HOST="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --production)
            DEBUG="false"
            shift
            ;;
        --docker)
            USE_DOCKER="true"
            shift
            ;;
        -h|--help)
            echo "使用方法: $0 [options]"
            echo ""
            echo "オプション:"
            echo "  --host HOST        ホストアドレス（デフォルト: 0.0.0.0）"
            echo "  --port PORT        ポート番号（デフォルト: 5000）"
            echo "  --production       本番モードで起動（デバッグ無効）"
            echo "  --docker           Dockerコンテナで起動"
            echo "  -h, --help         このヘルプを表示"
            echo ""
            echo "例:"
            echo "  $0                      # 開発モードで起動"
            echo "  $0 --port 8000         # ポート8000で起動"
            echo "  $0 --production        # 本番モードで起動"
            echo "  $0 --docker            # Dockerで起動"
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            echo "ヘルプは -h または --help を参照してください"
            exit 1
            ;;
    esac
done

echo "==============================================="
echo "🚀 University LaTeX API Server 起動"
echo "==============================================="
echo "ホスト: $HOST"
echo "ポート: $PORT"
echo "デバッグ: $DEBUG"
echo "Docker: $USE_DOCKER"
echo "==============================================="

# ポートが使用中かチェック
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # ポートは使用中
    else
        return 1  # ポートは使用可能
    fi
}

# ポートの使用状況をチェック
if check_port "$PORT"; then
    echo "⚠️  ポート $PORT は既に使用されています"
    if [ "$PORT" = "5000" ]; then
        echo "💡 AirPlay Receiver がポート5000を使用している可能性があります"
        echo "   システム環境設定 > 一般 > AirDrop と Handoff で無効化できます"
    fi
    echo "   別のポートを使用してください: ./scripts/start-api.sh --port 5001"
    exit 1
fi

# 環境変数の設定
export LATEX_API_HOST="$HOST"
export LATEX_API_PORT="$PORT"
export FLASK_DEBUG="$DEBUG"

# プロジェクトルートディレクトリの確認
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_ROOT/api"

echo "📁 プロジェクトルート: $PROJECT_ROOT"

# 必要なディレクトリの確認
if [ ! -f "$API_DIR/server.py" ]; then
    echo "❌ エラー: API サーバーファイルが見つかりません"
    echo "   パス: $API_DIR/server.py"
    exit 1
fi

# Python 仮想環境の確認と作成
if [ ! -d "$PROJECT_ROOT/venv" ]; then
    echo "🐍 Python仮想環境を作成中..."
    cd "$PROJECT_ROOT"
    python3 -m venv venv
    
    if [ $? -ne 0 ]; then
        echo "❌ 仮想環境の作成に失敗しました"
        exit 1
    fi
fi

# 仮想環境のアクティベート
source "$PROJECT_ROOT/venv/bin/activate"

# 依存関係のインストール
echo "📦 依存関係のチェックとインストール..."
if [ -f "$API_DIR/requirements.txt" ]; then
    pip install -q -r "$API_DIR/requirements.txt"
    
    if [ $? -ne 0 ]; then
        echo "❌ 依存関係のインストールに失敗しました"
        exit 1
    fi
else
    echo "⚠️  requirements.txt が見つかりません。手動で依存関係をインストールしてください："
    echo "   pip install flask flask-cors"
fi

# Docker環境のチェック
if [ "$USE_DOCKER" = "true" ]; then
    echo "🐳 Docker環境でAPIサーバーを起動..."
    
    # Docker Composeファイルの確認
    if [ -f "$API_DIR/docker-compose.api.yaml" ]; then
        cd "$API_DIR"
        export LATEX_API_PORT="$PORT"
        docker-compose -f docker-compose.api.yaml up --build
    else
        echo "❌ Docker設定ファイルが見つかりません: $API_DIR/docker-compose.api.yaml"
        exit 1
    fi
else
    # 直接実行モード
    echo "🔥 APIサーバーを起動しています..."
    echo "   URL: http://$HOST:$PORT"
    echo "   Ctrl+C で停止"
    echo ""
    
    cd "$PROJECT_ROOT"
    python "$API_DIR/server.py"
fi