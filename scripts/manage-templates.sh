#!/bin/bash

# テンプレート管理スクリプト
# 使用方法: ./scripts/manage-templates.sh [command] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config/templates.json"
TEMPLATES_DIR="$PROJECT_ROOT/templates"

# 色付き出力のための定数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ヘルプ表示
show_help() {
    echo "=== テンプレート管理ツール ==="
    echo "使用方法: ./scripts/manage-templates.sh [command] [options]"
    echo
    echo "📋 利用可能なコマンド:"
    echo "  list              全てのテンプレートを一覧表示"
    echo "  list --enabled    有効なテンプレートのみ表示"
    echo "  list --disabled   無効なテンプレートのみ表示"
    echo "  list --category   カテゴリ別に表示"
    echo
    echo "  enable <id>       テンプレートを有効化"
    echo "  disable <id>      テンプレートを無効化"
    echo "  toggle <id>       テンプレートの有効/無効を切り替え"
    echo
    echo "  add <file>        新しいテンプレートを追加"
    echo "  remove <id>       テンプレートを削除"
    echo "  info <id>         テンプレートの詳細情報を表示"
    echo
    echo "  validate          設定ファイルの検証"
    echo "  backup            設定ファイルのバックアップ作成"
    echo "  restore           設定ファイルの復元"
    echo
    echo "例:"
    echo "  ./scripts/manage-templates.sh list"
    echo "  ./scripts/manage-templates.sh disable math"
    echo "  ./scripts/manage-templates.sh add my-custom-template.tex"
}

# jqが利用可能かチェック
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}エラー: jqがインストールされていません${NC}"
        echo "macOS: brew install jq"
        echo "Ubuntu/Debian: sudo apt install jq"
        exit 1
    fi
}

# 設定ファイルの存在確認
check_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}エラー: 設定ファイルが見つかりません: $CONFIG_FILE${NC}"
        exit 1
    fi
}

# テンプレート一覧表示
list_templates() {
    local filter="$1"
    local group_by_category="$2"
    
    echo "=== テンプレート一覧 ==="
    echo
    
    if [ "$group_by_category" = "true" ]; then
        # カテゴリ別表示
        local categories=$(jq -r '.categories[].id' "$CONFIG_FILE")
        
        for category in $categories; do
            local category_name=$(jq -r ".categories[] | select(.id == \"$category\") | .name" "$CONFIG_FILE")
            local category_desc=$(jq -r ".categories[] | select(.id == \"$category\") | .description" "$CONFIG_FILE")
            
            echo -e "${BLUE}📁 $category_name${NC} - $category_desc"
            
            local templates_in_category=$(jq -r ".templates[] | select(.category == \"$category\") | select($filter) | .id" "$CONFIG_FILE")
            
            if [ -n "$templates_in_category" ]; then
                for template_id in $templates_in_category; do
                    display_template_info "$template_id" "  "
                done
            else
                echo "  (このカテゴリにはテンプレートがありません)"
            fi
            echo
        done
    else
        # 通常の一覧表示
        local template_ids=$(jq -r ".templates[] | select($filter) | .id" "$CONFIG_FILE")
        
        for template_id in $template_ids; do
            display_template_info "$template_id" ""
        done
    fi
}

# テンプレート情報表示
display_template_info() {
    local template_id="$1"
    local prefix="$2"
    
    local template=$(jq -r ".templates[] | select(.id == \"$template_id\")" "$CONFIG_FILE")
    local name=$(echo "$template" | jq -r '.name')
    local description=$(echo "$template" | jq -r '.description')
    local file=$(echo "$template" | jq -r '.file')
    local enabled=$(echo "$template" | jq -r '.enabled')
    local category=$(echo "$template" | jq -r '.category')
    
    if [ "$enabled" = "true" ]; then
        local status="${GREEN}✓ 有効${NC}"
    else
        local status="${RED}✗ 無効${NC}"
    fi
    
    echo -e "${prefix}${status} ${YELLOW}$template_id${NC}: $name"
    echo -e "${prefix}   📝 $description"
    echo -e "${prefix}   📄 $file"
    
    # ファイルの存在確認
    if [ ! -f "$TEMPLATES_DIR/$file" ]; then
        echo -e "${prefix}   ${RED}⚠️  ファイルが見つかりません${NC}"
    fi
    echo
}

# テンプレートの有効化
enable_template() {
    local template_id="$1"
    
    if [ -z "$template_id" ]; then
        echo -e "${RED}エラー: テンプレートIDを指定してください${NC}"
        exit 1
    fi
    
    # テンプレートが存在するかチェック
    if ! jq -e ".templates[] | select(.id == \"$template_id\")" "$CONFIG_FILE" > /dev/null; then
        echo -e "${RED}エラー: テンプレート '$template_id' が見つかりません${NC}"
        exit 1
    fi
    
    # 設定を更新
    jq "(.templates[] | select(.id == \"$template_id\") | .enabled) = true" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}✓ テンプレート '$template_id' を有効化しました${NC}"
}

# テンプレートの無効化
disable_template() {
    local template_id="$1"
    
    if [ -z "$template_id" ]; then
        echo -e "${RED}エラー: テンプレートIDを指定してください${NC}"
        exit 1
    fi
    
    # テンプレートが存在するかチェック
    if ! jq -e ".templates[] | select(.id == \"$template_id\")" "$CONFIG_FILE" > /dev/null; then
        echo -e "${RED}エラー: テンプレート '$template_id' が見つかりません${NC}"
        exit 1
    fi
    
    # 設定を更新
    jq "(.templates[] | select(.id == \"$template_id\") | .enabled) = false" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${YELLOW}○ テンプレート '$template_id' を無効化しました${NC}"
}

# テンプレートの切り替え
toggle_template() {
    local template_id="$1"
    
    if [ -z "$template_id" ]; then
        echo -e "${RED}エラー: テンプレートIDを指定してください${NC}"
        exit 1
    fi
    
    # 現在の状態を取得
    local current_state=$(jq -r ".templates[] | select(.id == \"$template_id\") | .enabled" "$CONFIG_FILE")
    
    if [ "$current_state" = "null" ]; then
        echo -e "${RED}エラー: テンプレート '$template_id' が見つかりません${NC}"
        exit 1
    fi
    
    if [ "$current_state" = "true" ]; then
        disable_template "$template_id"
    else
        enable_template "$template_id"
    fi
}

# 新しいテンプレートの追加
add_template() {
    local template_file="$1"
    
    if [ -z "$template_file" ]; then
        echo -e "${RED}エラー: テンプレートファイルを指定してください${NC}"
        exit 1
    fi
    
    # ファイルが存在するかチェック
    if [ ! -f "$TEMPLATES_DIR/$template_file" ]; then
        echo -e "${RED}エラー: テンプレートファイルが見つかりません: $TEMPLATES_DIR/$template_file${NC}"
        exit 1
    fi
    
    echo "=== 新しいテンプレートの追加 ==="
    echo
    
    # 対話的に情報を入力
    read -p "テンプレートID: " template_id
    read -p "テンプレート名: " template_name
    read -p "説明: " template_description
    
    # カテゴリ選択
    echo "利用可能なカテゴリ:"
    jq -r '.categories[] | "  \(.id): \(.name)"' "$CONFIG_FILE"
    read -p "カテゴリID: " template_category
    
    # カテゴリが有効かチェック
    if ! jq -e ".categories[] | select(.id == \"$template_category\")" "$CONFIG_FILE" > /dev/null; then
        echo -e "${RED}エラー: 無効なカテゴリです${NC}"
        exit 1
    fi
    
    # IDの重複チェック
    if jq -e ".templates[] | select(.id == \"$template_id\")" "$CONFIG_FILE" > /dev/null; then
        echo -e "${RED}エラー: テンプレートID '$template_id' は既に存在します${NC}"
        exit 1
    fi
    
    # 新しいテンプレートを追加
    local new_template="{
        \"id\": \"$template_id\",
        \"name\": \"$template_name\",
        \"description\": \"$template_description\",
        \"file\": \"$template_file\",
        \"enabled\": true,
        \"category\": \"$template_category\"
    }"
    
    jq ".templates += [$new_template]" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}✓ テンプレート '$template_id' を追加しました${NC}"
}

# テンプレートの削除
remove_template() {
    local template_id="$1"
    
    if [ -z "$template_id" ]; then
        echo -e "${RED}エラー: テンプレートIDを指定してください${NC}"
        exit 1
    fi
    
    # テンプレートが存在するかチェック
    if ! jq -e ".templates[] | select(.id == \"$template_id\")" "$CONFIG_FILE" > /dev/null; then
        echo -e "${RED}エラー: テンプレート '$template_id' が見つかりません${NC}"
        exit 1
    fi
    
    # 確認
    read -p "テンプレート '$template_id' を削除しますか？ (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "キャンセルしました"
        exit 0
    fi
    
    # テンプレートを削除
    jq "del(.templates[] | select(.id == \"$template_id\"))" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}✓ テンプレート '$template_id' を削除しました${NC}"
}

# テンプレート詳細情報表示
show_template_info() {
    local template_id="$1"
    
    if [ -z "$template_id" ]; then
        echo -e "${RED}エラー: テンプレートIDを指定してください${NC}"
        exit 1
    fi
    
    local template=$(jq -r ".templates[] | select(.id == \"$template_id\")" "$CONFIG_FILE")
    
    if [ "$template" = "" ]; then
        echo -e "${RED}エラー: テンプレート '$template_id' が見つかりません${NC}"
        exit 1
    fi
    
    echo "=== テンプレート詳細情報 ==="
    echo
    echo "ID: $(echo "$template" | jq -r '.id')"
    echo "名前: $(echo "$template" | jq -r '.name')"
    echo "説明: $(echo "$template" | jq -r '.description')"
    echo "ファイル: $(echo "$template" | jq -r '.file')"
    echo "有効: $(echo "$template" | jq -r '.enabled')"
    echo "カテゴリ: $(echo "$template" | jq -r '.category')"
    
    local file_path="$TEMPLATES_DIR/$(echo "$template" | jq -r '.file')"
    if [ -f "$file_path" ]; then
        echo -e "ファイル状態: ${GREEN}存在${NC}"
        echo "ファイルサイズ: $(du -h "$file_path" | cut -f1)"
        echo "最終更新: $(stat -f "%Sm" "$file_path")"
    else
        echo -e "ファイル状態: ${RED}見つかりません${NC}"
    fi
}

# 設定ファイルの検証
validate_config() {
    echo "=== 設定ファイルの検証 ==="
    
    # JSON形式の検証
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${RED}✗ JSON形式が無効です${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ JSON形式は有効です${NC}"
    
    # 必須フィールドの確認
    local required_fields=(".templates" ".categories" ".settings")
    for field in "${required_fields[@]}"; do
        if jq -e "$field" "$CONFIG_FILE" >/dev/null; then
            echo -e "${GREEN}✓ $field フィールドが存在します${NC}"
        else
            echo -e "${RED}✗ $field フィールドが見つかりません${NC}"
            return 1
        fi
    done
    
    # テンプレートファイルの存在確認
    local missing_files=()
    while IFS= read -r file; do
        if [ ! -f "$TEMPLATES_DIR/$file" ]; then
            missing_files+=("$file")
        fi
    done < <(jq -r '.templates[].file' "$CONFIG_FILE")
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ 全てのテンプレートファイルが存在します${NC}"
    else
        echo -e "${RED}✗ 見つからないファイル:${NC}"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
    
    echo -e "${GREEN}✓ 設定ファイルは有効です${NC}"
}

# バックアップ作成
backup_config() {
    local backup_file="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$backup_file"
    echo -e "${GREEN}✓ バックアップを作成しました: $backup_file${NC}"
}

# 復元
restore_config() {
    echo "利用可能なバックアップファイル:"
    ls -1 "$CONFIG_FILE".backup.* 2>/dev/null || {
        echo "バックアップファイルが見つかりません"
        exit 1
    }
    
    read -p "復元するファイル名: " backup_file
    
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}エラー: ファイルが見つかりません${NC}"
        exit 1
    fi
    
    cp "$backup_file" "$CONFIG_FILE"
    echo -e "${GREEN}✓ 設定ファイルを復元しました${NC}"
}

# メイン処理
main() {
    # 依存関係チェック
    check_jq
    check_config
    
    local command="$1"
    shift || true
    
    case "$command" in
        "list")
            local filter=".enabled == true or .enabled == false"  # 全て表示
            local group_by_category="false"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --enabled)
                        filter=".enabled == true"
                        shift
                        ;;
                    --disabled)
                        filter=".enabled == false"
                        shift
                        ;;
                    --category)
                        group_by_category="true"
                        shift
                        ;;
                    *)
                        echo -e "${RED}不明なオプション: $1${NC}"
                        exit 1
                        ;;
                esac
            done
            
            list_templates "$filter" "$group_by_category"
            ;;
        "enable")
            enable_template "$1"
            ;;
        "disable")
            disable_template "$1"
            ;;
        "toggle")
            toggle_template "$1"
            ;;
        "add")
            add_template "$1"
            ;;
        "remove")
            remove_template "$1"
            ;;
        "info")
            show_template_info "$1"
            ;;
        "validate")
            validate_config
            ;;
        "backup")
            backup_config
            ;;
        "restore")
            restore_config
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            echo -e "${RED}不明なコマンド: $command${NC}"
            echo "ヘルプを表示するには: $0 help"
            exit 1
            ;;
    esac
}

# スクリプト実行
main "$@"