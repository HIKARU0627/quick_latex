#!/bin/bash

# ファイル変更を監視して自動コンパイル
# 使用方法: ./scripts/watch.sh [path/to/main.tex]

if [ $# -eq 0 ]; then
    echo "使用方法: $0 [path/to/main.tex]"
    exit 1
fi

FILEPATH=$1
DIRNAME=$(dirname "$FILEPATH")
FILENAME=$(basename "$FILEPATH")

echo "👁️  監視開始: $FILEPATH"
echo "Ctrl+C で終了"
echo

# 初回コンパイル
./scripts/compile.sh "$FILEPATH" -q

# ファイル変更を監視
docker compose run --rm -w "/workspace/$DIRNAME" latex bash -c "
while true; do
    inotifywait -q -e modify,create,delete -r . \
        --exclude '(output/|\.git/|.*\.aux$|.*\.log$|.*\.synctex\.gz$)'
    
    echo '🔄 変更を検出しました。再コンパイル中...'
    lualatex -interaction=nonstopmode -halt-on-error -output-directory=output $FILENAME
    
    if [ \$? -eq 0 ]; then
        echo '✅ コンパイル成功'
    else
        echo '❌ コンパイルエラー'
    fi
    echo '---'
done
"