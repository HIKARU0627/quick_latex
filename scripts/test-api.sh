#!/bin/bash

# University LaTeX API テストスクリプト
# 使用方法: ./scripts/test-api.sh [API_URL]

API_URL="${1:-http://localhost:5001/api}"

echo "🧪 University LaTeX API テスト"
echo "API URL: $API_URL"
echo "========================================"

# ヘルスチェック
echo ""
echo "1️⃣ ヘルスチェック..."
HEALTH_RESPONSE=$(curl -s "$API_URL/health" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ ヘルスチェック成功"
    echo "   レスポンス: $(echo "$HEALTH_RESPONSE" | jq -r '.message' 2>/dev/null || echo "$HEALTH_RESPONSE")"
else
    echo "❌ ヘルスチェック失敗 - APIサーバーが起動していない可能性があります"
    echo "   以下のコマンドでサーバーを起動してください:"
    echo "   ./scripts/start-api.sh --port 5001"
    exit 1
fi

# テンプレート一覧取得
echo ""
echo "2️⃣ テンプレート一覧取得..."
TEMPLATES_RESPONSE=$(curl -s "$API_URL/templates" 2>/dev/null)
if [ $? -eq 0 ]; then
    TEMPLATE_COUNT=$(echo "$TEMPLATES_RESPONSE" | jq -r '.data.templates | length' 2>/dev/null || echo "N/A")
    echo "✅ テンプレート一覧取得成功"
    echo "   利用可能テンプレート: ${TEMPLATE_COUNT}個"
    
    # テンプレート名の表示
    if command -v jq >/dev/null 2>&1; then
        echo "   テンプレート:"
        echo "$TEMPLATES_RESPONSE" | jq -r '.data.templates[] | "     - \(.name): \(.filename)"' 2>/dev/null || true
    fi
else
    echo "❌ テンプレート一覧取得失敗"
fi

# システム情報取得
echo ""
echo "3️⃣ システム情報取得..."
SYSTEM_RESPONSE=$(curl -s "$API_URL/system/info" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✅ システム情報取得成功"
    if command -v jq >/dev/null 2>&1; then
        DOCKER_AVAILABLE=$(echo "$SYSTEM_RESPONSE" | jq -r '.data.docker_available' 2>/dev/null)
        COMPILERS=$(echo "$SYSTEM_RESPONSE" | jq -r '.data.supported_compilers | join(", ")' 2>/dev/null)
        echo "   Docker利用可能: $DOCKER_AVAILABLE"
        echo "   サポートコンパイラ: $COMPILERS"
    fi
else
    echo "❌ システム情報取得失敗"
fi

# プロジェクト一覧取得
echo ""
echo "4️⃣ プロジェクト一覧取得..."
PROJECTS_RESPONSE=$(curl -s "$API_URL/projects" 2>/dev/null)
if [ $? -eq 0 ]; then
    PROJECT_COUNT=$(echo "$PROJECTS_RESPONSE" | jq -r '.data.total_count' 2>/dev/null || echo "N/A")
    echo "✅ プロジェクト一覧取得成功"
    echo "   総プロジェクト数: ${PROJECT_COUNT}個"
else
    echo "❌ プロジェクト一覧取得失敗"
fi

# テストプロジェクトの作成
echo ""
echo "5️⃣ テストプロジェクト作成..."
TEST_PROJECT_NAME="api-test-$(date +%s)"
CREATE_DATA=$(cat <<EOF
{
    "semester": "2024-fall",
    "course": "api-test",
    "report_name": "$TEST_PROJECT_NAME",
    "template": "report-basic.tex"
}
EOF
)

CREATE_RESPONSE=$(curl -s -X POST "$API_URL/projects" \
    -H "Content-Type: application/json" \
    -d "$CREATE_DATA" 2>/dev/null)

if [ $? -eq 0 ]; then
    CREATE_SUCCESS=$(echo "$CREATE_RESPONSE" | jq -r '.success' 2>/dev/null)
    if [ "$CREATE_SUCCESS" = "true" ]; then
        echo "✅ テストプロジェクト作成成功"
        PROJECT_PATH=$(echo "$CREATE_RESPONSE" | jq -r '.data.project_path' 2>/dev/null)
        echo "   プロジェクトパス: $PROJECT_PATH"
        
        # 作成したプロジェクトのコンパイルテスト
        if [ -n "$PROJECT_PATH" ]; then
            echo ""
            echo "6️⃣ コンパイルテスト..."
            MAIN_TEX_PATH="$PROJECT_PATH/main.tex"
            COMPILE_DATA=$(cat <<EOF
{
    "file_path": "$MAIN_TEX_PATH",
    "compiler": "lualatex",
    "quick": true
}
EOF
)
            
            COMPILE_RESPONSE=$(curl -s -X POST "$API_URL/compile" \
                -H "Content-Type: application/json" \
                -d "$COMPILE_DATA" 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                COMPILE_SUCCESS=$(echo "$COMPILE_RESPONSE" | jq -r '.success' 2>/dev/null)
                if [ "$COMPILE_SUCCESS" = "true" ]; then
                    echo "✅ コンパイルテスト成功"
                    PDF_PATH=$(echo "$COMPILE_RESPONSE" | jq -r '.data.pdf_info.path' 2>/dev/null)
                    if [ "$PDF_PATH" != "null" ] && [ -n "$PDF_PATH" ]; then
                        echo "   PDF生成: $PDF_PATH"
                    fi
                else
                    echo "❌ コンパイルテスト失敗"
                    ERROR_MSG=$(echo "$COMPILE_RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null)
                    echo "   エラー: $ERROR_MSG"
                    
                    # 詳細エラー情報の表示
                    if command -v jq >/dev/null 2>&1; then
                        ERRORS=$(echo "$COMPILE_RESPONSE" | jq -r '.errors[]?' 2>/dev/null)
                        if [ -n "$ERRORS" ]; then
                            echo "   詳細エラー:"
                            echo "$ERRORS" | head -5 | sed 's/^/     /'
                        fi
                        
                        STDERR=$(echo "$COMPILE_RESPONSE" | jq -r '.data.stderr?' 2>/dev/null)
                        if [ -n "$STDERR" ] && [ "$STDERR" != "null" ]; then
                            echo "   STDERR: $STDERR"
                        fi
                    fi
                fi
            else
                echo "❌ コンパイルリクエスト失敗"
            fi
            
            # 品質チェックテスト
            echo ""
            echo "7️⃣ 品質チェックテスト..."
            QUALITY_DATA=$(cat <<EOF
{
    "file_path": "$MAIN_TEX_PATH"
}
EOF
)
            
            QUALITY_RESPONSE=$(curl -s -X POST "$API_URL/quality-check" \
                -H "Content-Type: application/json" \
                -d "$QUALITY_DATA" 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                QUALITY_SUCCESS=$(echo "$QUALITY_RESPONSE" | jq -r '.success' 2>/dev/null)
                if [ "$QUALITY_SUCCESS" = "true" ]; then
                    echo "✅ 品質チェックテスト成功"
                    QUALITY_SCORE=$(echo "$QUALITY_RESPONSE" | jq -r '.data.quality_score' 2>/dev/null)
                    QUALITY_LEVEL=$(echo "$QUALITY_RESPONSE" | jq -r '.data.quality_level' 2>/dev/null)
                    if [ "$QUALITY_SCORE" != "null" ] && [ -n "$QUALITY_SCORE" ]; then
                        echo "   品質スコア: ${QUALITY_SCORE}/100 (${QUALITY_LEVEL})"
                    fi
                else
                    echo "❌ 品質チェックテスト失敗"
                fi
            else
                echo "❌ 品質チェックリクエスト失敗"
            fi
        fi
    else
        echo "❌ テストプロジェクト作成失敗"
        ERROR_MSG=$(echo "$CREATE_RESPONSE" | jq -r '.message // "Unknown error"' 2>/dev/null)
        echo "   エラー: $ERROR_MSG"
    fi
else
    echo "❌ プロジェクト作成リクエスト失敗"
fi

echo ""
echo "========================================"
echo "🎯 APIテスト完了"
echo ""
echo "詳細なテストを実行したい場合は以下のコマンドを使用してください:"
echo "  Python: python api/client-examples/python_client.py"
echo "  JavaScript: node api/client-examples/javascript_client.js"
echo "  対話型: python api/client-examples/python_client.py demo"