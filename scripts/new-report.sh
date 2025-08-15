#!/bin/bash

# 新しいレポートプロジェクトを作成するスクリプト
# 使用方法: ./scripts/new-report.sh

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
        echo "テンプレート管理ツールを使用してください: ./scripts/manage-templates.sh"
        exit 1
    fi
}

# 有効なテンプレートを取得
get_enabled_templates() {
    jq -r '.templates[] | select(.enabled == true) | "\(.id)|\(.name)|\(.description)|\(.file)|\(.category)"' "$CONFIG_FILE"
}

# カテゴリ別にテンプレートを表示
show_templates_by_category() {
    local group_by_category=$(jq -r '.settings.group_by_category' "$CONFIG_FILE")
    
    if [ "$group_by_category" = "true" ]; then
        echo "📋 利用可能なテンプレート（カテゴリ別）:"
        echo
        
        local categories=$(jq -r '.categories[].id' "$CONFIG_FILE")
        local choice_num=1
        
        for category in $categories; do
            local category_name=$(jq -r ".categories[] | select(.id == \"$category\") | .name" "$CONFIG_FILE")
            local templates_in_category=$(jq -r ".templates[] | select(.category == \"$category\" and .enabled == true) | .id" "$CONFIG_FILE")
            
            if [ -n "$templates_in_category" ]; then
                echo -e "${BLUE}📁 $category_name${NC}"
                
                for template_id in $templates_in_category; do
                    local template_info=$(jq -r ".templates[] | select(.id == \"$template_id\") | \"\(.name)|\(.description)\"" "$CONFIG_FILE")
                    local name=$(echo "$template_info" | cut -d'|' -f1)
                    local description=$(echo "$template_info" | cut -d'|' -f2)
                    
                    echo "  $choice_num) $name - $description"
                    ((choice_num++))
                done
                echo
            fi
        done
        
        # テンプレートなしオプション
        echo "$choice_num) テンプレートなし - 空の基本構造のみ"
        
        return 0
    else
        show_templates_simple
    fi
}

# シンプルなテンプレート表示
show_templates_simple() {
    echo "📋 利用可能なテンプレート:"
    echo
    
    local choice_num=1
    
    while IFS='|' read -r id name description file category; do
        if [ -n "$id" ]; then
            echo "$choice_num) $name - $description"
            ((choice_num++))
        fi
    done < <(get_enabled_templates)
    
    # テンプレートなしオプション
    echo "$choice_num) テンプレートなし - 空の基本構造のみ"
}

# テンプレート選択の処理
handle_template_selection() {
    local choice="$1"
    local max_choice="$2"
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$max_choice" ]; then
        echo -e "${RED}無効な選択です${NC}"
        exit 1
    fi
    
    # choice_to_idはローカル変数なので、別の方法で選択を処理
    local choice_num=1
    local selected_id=""
    
    if $(jq -r '.settings.group_by_category' "$CONFIG_FILE") == "true"; then
        # カテゴリ別表示の場合
        local categories=$(jq -r '.categories[].id' "$CONFIG_FILE")
        
        for category in $categories; do
            local templates_in_category=$(jq -r ".templates[] | select(.category == \"$category\" and .enabled == true) | .id" "$CONFIG_FILE")
            
            for template_id in $templates_in_category; do
                if [ "$choice_num" -eq "$choice" ]; then
                    selected_id="$template_id"
                    break 2
                fi
                ((choice_num++))
            done
        done
    else
        # シンプル表示の場合
        while IFS='|' read -r id name description file category; do
            if [ -n "$id" ]; then
                if [ "$choice_num" -eq "$choice" ]; then
                    selected_id="$id"
                    break
                fi
                ((choice_num++))
            fi
        done < <(get_enabled_templates)
    fi
    
    # テンプレートなしの場合
    if [ "$choice_num" -eq "$choice" ]; then
        selected_id=""
    fi
    
    echo "$selected_id"
}

# テンプレートファイル取得
get_template_file() {
    local template_id="$1"
    
    if [ -z "$template_id" ]; then
        echo ""
        return
    fi
    
    jq -r ".templates[] | select(.id == \"$template_id\") | .file" "$CONFIG_FILE"
}

# 基本テンプレートの作成
create_basic_template() {
    local report_path="$1"
    
    cat > "$report_path/main.tex" << 'EOF'
\documentclass[12pt,a4paper]{ltjsarticle}

% ===== 共通スタイルパッケージの読み込み =====
\usepackage[japanese]{../../../common/university-style}

% ===== 大学情報設定 =====
\university{○○大学}
\department{○○学部○○学科}
\studentid{12345678}
\supervisor{担当教員：○○ ○○ 教授}

% ===== 文書情報 =====
\title{レポートタイトル}
\author{山田 太郎}
\date{\today}

\begin{document}

% ===== タイトルページ =====
\reportheader

% ===== 概要（必要に応じて） =====
% \begin{abstract}
% 本レポートでは...
% \end{abstract}

\section{はじめに}


\section{内容}


\section{まとめ}


% ===== 参考文献 =====
% \bibliographystyle{plainnat}
% \bibliography{../../../common/bibliography}

\end{document}
EOF
}

# メイン処理
main() {
    # 依存関係チェック
    check_jq
    check_config
    
    echo -e "${BLUE}=== 新規レポート作成ウィザード ===${NC}"
    echo
    
    # 学期の選択
    echo "学期を入力してください (例: 2024-fall):"
    read -r SEMESTER
    
    # 授業名の入力
    echo "授業名を入力してください (例: physics, mathematics):"
    read -r COURSE
    
    # レポート名の入力
    echo "レポート名を入力してください (例: report1, final-report):"
    read -r REPORT_NAME
    
    echo
    
    # テンプレートの選択
    show_templates_by_category
    
    # 選択肢の総数を計算
    local total_templates=$(jq -r '.templates[] | select(.enabled == true) | .id' "$CONFIG_FILE" | wc -l)
    local max_choice=$((total_templates + 1))  # +1 for "テンプレートなし"
    
    echo
    read -p "選択してください (1-$max_choice): " TEMPLATE_CHOICE
    
    # テンプレートIDを取得
    local selected_template_id=$(handle_template_selection "$TEMPLATE_CHOICE" "$max_choice")
    local template_file=$(get_template_file "$selected_template_id")
    
    # ディレクトリ構造の作成
    REPORT_PATH="courses/$SEMESTER/$COURSE/$REPORT_NAME"
    mkdir -p "$REPORT_PATH"/{figures,output,sections}
    
    echo
    echo -e "${GREEN}📁 作成中: $REPORT_PATH${NC}"
    
    # テンプレートのコピーまたは新規作成
    if [ -n "$template_file" ] && [ -f "$TEMPLATES_DIR/$template_file" ]; then
        cp "$TEMPLATES_DIR/$template_file" "$REPORT_PATH/main.tex"
        
        local template_name=$(jq -r ".templates[] | select(.id == \"$selected_template_id\") | .name" "$CONFIG_FILE")
        echo -e "${GREEN}📝 テンプレートをコピーしました: $template_name ($template_file)${NC}"
    else
        # 基本テンプレートを作成
        create_basic_template "$REPORT_PATH"
        echo -e "${GREEN}📝 基本テンプレートを作成しました${NC}"
    fi
    
    # READMEの作成
    cat > "$REPORT_PATH/README.md" << EOF
# $COURSE - $REPORT_NAME

## レポート情報
- 学期: $SEMESTER
- 授業: $COURSE
- 作成日: $(date +%Y-%m-%d)
- テンプレート: ${selected_template_id:-"基本テンプレート"}

## コンパイル方法
\`\`\`bash
# プロジェクトルートから
./scripts/compile.sh courses/$SEMESTER/$COURSE/$REPORT_NAME/main.tex

# BibTeXを使用する場合
./scripts/compile.sh courses/$SEMESTER/$COURSE/$REPORT_NAME/main.tex -b

# コンパイル後自動でPDFを開く
./scripts/compile.sh courses/$SEMESTER/$COURSE/$REPORT_NAME/main.tex -o
\`\`\`

## テンプレート管理
\`\`\`bash
# テンプレート一覧表示
./scripts/manage-templates.sh list

# テンプレート管理
./scripts/manage-templates.sh help
\`\`\`

## メモ
- 

EOF
    
    echo -e "${GREEN}📚 README.mdを作成しました${NC}"
    
    # .gitignoreの作成
    cat > "$REPORT_PATH/.gitignore" << 'EOF'
output/*
!output/.gitkeep
*.aux
*.log
*.toc
*.lof
*.lot
*.bbl
*.blg
*.out
*.synctex.gz
EOF
    
    # .gitkeepファイルの作成
    touch "$REPORT_PATH/output/.gitkeep"
    touch "$REPORT_PATH/figures/.gitkeep"
    
    echo
    echo -e "${GREEN}✅ レポートプロジェクトを作成しました！${NC}"
    echo -e "${BLUE}📍 場所: $REPORT_PATH${NC}"
    echo
    echo -e "${YELLOW}次のステップ:${NC}"
    echo "1. cd $REPORT_PATH"
    echo "2. main.texを編集"
    echo "3. ./scripts/compile.sh $REPORT_PATH/main.tex"
    echo
    echo -e "${YELLOW}テンプレート管理:${NC}"
    echo "- テンプレート一覧: ./scripts/manage-templates.sh list"
    echo "- テンプレート管理: ./scripts/manage-templates.sh help"
}

# スクリプト実行
main "$@"