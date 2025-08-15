#!/bin/bash

# 使用方法: ./scripts/compile.sh [path/to/main.tex] [options]
# オプション:
#   -c, --compiler [pdflatex|lualatex|xelatex|platex]  コンパイラを指定
#   -b, --bibtex                                        BibTeXも実行
#   -q, --quick                                         1回だけコンパイル
#   -o, --open                                          コンパイル後PDFを開く
#   -w, --watch                                         ファイル監視モード

# デフォルト設定
COMPILER="lualatex"
USE_BIBTEX=false
QUICK=false
OPEN_PDF=false
WATCH_MODE=false

# 引数解析
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--compiler)
            COMPILER="$2"
            shift 2
            ;;
        -b|--bibtex)
            USE_BIBTEX=true
            shift
            ;;
        -q|--quick)
            QUICK=true
            shift
            ;;
        -o|--open)
            OPEN_PDF=true
            shift
            ;;
        -w|--watch)
            WATCH_MODE=true
            shift
            ;;
        -h|--help)
            echo "使用方法: $0 [path/to/main.tex] [options]"
            echo ""
            echo "オプション:"
            echo "  -c, --compiler [compiler]  使用するコンパイラを指定"
            echo "                             (pdflatex|lualatex|xelatex|platex)"
            echo "  -b, --bibtex              BibTeXも実行"
            echo "  -q, --quick               1回だけコンパイル（相互参照解決なし）"
            echo "  -o, --open                コンパイル後PDFを開く"
            echo "  -w, --watch               ファイル変更を監視して自動コンパイル"
            echo "  -h, --help                このヘルプを表示"
            echo ""
            echo "例:"
            echo "  $0 courses/2024-fall/physics/report1/main.tex"
            echo "  $0 courses/2024-fall/physics/report1/main.tex -b -o"
            echo "  $0 courses/2024-fall/physics/report1/main.tex -c platex"
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"

if [ $# -eq 0 ]; then
    echo "エラー: TeXファイルを指定してください"
    echo "使用方法: $0 [path/to/main.tex] [options]"
    echo "詳細は -h または --help を参照してください"
    exit 1
fi

FILEPATH=$1
FILENAME=$(basename "$FILEPATH")
DIRNAME=$(dirname "$FILEPATH")
BASENAME="${FILENAME%.tex}"

# outputディレクトリの作成
echo "📁 出力ディレクトリを確認中..."
docker compose run --rm -w "/workspace/$DIRNAME" latex bash -c "
    if [ ! -d output ]; then
        echo '  → outputディレクトリを作成します'
        mkdir -p output
    fi
"

# コンパイラごとの設定
case $COMPILER in
    platex)
        # platexの場合はdvipdfmxも必要
        COMPILE_CMD="platex -interaction=nonstopmode -halt-on-error -output-directory=output"
        PDF_CMD="cd output && dvipdfmx $BASENAME && cd .."
        ;;
    *)
        # pdflatex, lualatex, xelatexは直接PDF生成
        COMPILE_CMD="$COMPILER -interaction=nonstopmode -halt-on-error -output-directory=output"
        PDF_CMD=""
        ;;
esac

echo "========================================="
echo "📝 コンパイル開始: $FILEPATH"
echo "🔧 コンパイラ: $COMPILER"
echo "📂 作業ディレクトリ: $DIRNAME"
echo "========================================="

# 監視モードの場合
if [ "$WATCH_MODE" = "true" ]; then
    echo "👁️  ファイル監視モードを開始します"
    echo "Ctrl+C で終了"
    echo ""
    
    docker compose run --rm -w "/workspace/$DIRNAME" latex bash -c "
        # 初回コンパイル
        $COMPILE_CMD $FILENAME
        $PDF_CMD
        echo '✅ 初回コンパイル完了'
        echo '監視を開始...'
        
        while true; do
            # ファイル変更を監視（outputディレクトリとログファイルを除外）
            inotifywait -q -e modify,create,delete -r . \
                --exclude '(output/|\.git/|.*\.aux$|.*\.log$|.*\.synctex\.gz$|.*\.bbl$|.*\.blg$|.*\.toc$|.*\.out$)'
            
            echo ''
            echo '🔄 変更を検出しました。再コンパイル中...'
            $COMPILE_CMD $FILENAME
            $PDF_CMD
            
            if [ \$? -eq 0 ]; then
                echo '✅ コンパイル成功'
            else
                echo '❌ コンパイルエラー（詳細はログファイルを確認）'
            fi
            echo '---'
        done
    "
    exit 0
fi

# 通常のコンパイル処理
docker compose run --rm -w "/workspace/$DIRNAME" latex bash -c "
    set -e  # エラーで停止
    
    # 初回コンパイル
    echo '🔄 [1/2] 初回コンパイル中...'
    $COMPILE_CMD $FILENAME
    $PDF_CMD
    
    # BibTeX処理
    if [ '$USE_BIBTEX' = 'true' ]; then
        echo '📚 BibTeX処理中...'
        cd output
        # .auxファイルが存在する場合のみBibTeXを実行
        if [ -f $BASENAME.aux ]; then
            bibtex $BASENAME || echo '⚠️  BibTeX警告（参考文献がない可能性があります）'
        fi
        cd ..
        
        echo '🔄 BibTeX後の再コンパイル中...'
        $COMPILE_CMD $FILENAME
        $PDF_CMD
    fi
    
    # 相互参照解決のため2回目のコンパイル
    if [ '$QUICK' = 'false' ]; then
        echo '🔄 [2/2] 相互参照解決のため再コンパイル中...'
        $COMPILE_CMD $FILENAME
        $PDF_CMD
    fi
    
    echo ''
    echo '✅ すべての処理が完了しました'
"

# コンパイル結果の確認
if [ $? -eq 0 ]; then
    echo "========================================="
    echo "✅ コンパイル成功!"
    echo "📄 出力ファイル: $DIRNAME/output/$BASENAME.pdf"
    
    # ファイルサイズを表示
    if [ -f "$DIRNAME/output/$BASENAME.pdf" ]; then
        FILE_SIZE=$(ls -lh "$DIRNAME/output/$BASENAME.pdf" | awk '{print $5}')
        echo "📊 ファイルサイズ: $FILE_SIZE"
    fi
    
    echo "========================================="
    
    # PDFを開く
    if [ "$OPEN_PDF" = "true" ]; then
        echo "📖 PDFを開いています..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            open "$DIRNAME/output/$BASENAME.pdf"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            xdg-open "$DIRNAME/output/$BASENAME.pdf" 2>/dev/null &
        elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
            start "$DIRNAME/output/$BASENAME.pdf"
        else
            echo "⚠️  お使いのOSでは自動でPDFを開けません: $OSTYPE"
        fi
    fi
else
    echo "========================================="
    echo "❌ コンパイルエラー"
    echo "詳細は以下のログファイルを確認してください:"
    echo "  $DIRNAME/output/$BASENAME.log"
    echo "========================================="
    
    # エラーメッセージの抽出を試みる
    if [ -f "$DIRNAME/output/$BASENAME.log" ]; then
        echo ""
        echo "エラー内容（抜粋）:"
        echo "---"
        docker compose run --rm -w "/workspace/$DIRNAME" latex bash -c "
            grep -A 2 -B 2 '^!' output/$BASENAME.log | head -20 || true
        "
        echo "---"
    fi
    
    exit 1
fi