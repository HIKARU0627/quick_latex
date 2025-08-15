#!/bin/bash

# レポート品質チェックスクリプト
# 使用方法: ./scripts/check-quality.sh [path/to/main.tex]

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 引数チェック
if [ $# -eq 0 ]; then
    echo "使用方法: $0 [path/to/main.tex]"
    echo "例: $0 courses/2024-fall/physics/report1/main.tex"
    exit 1
fi

FILEPATH=$1
FILENAME=$(basename "$FILEPATH")
DIRNAME=$(dirname "$FILEPATH")
BASENAME="${FILENAME%.tex}"

# ファイル存在チェック
if [ ! -f "$FILEPATH" ]; then
    echo "❌ エラー: ファイルが見つかりません: $FILEPATH"
    exit 1
fi

echo "==================== レポート品質チェック ===================="
echo "📄 ファイル: $FILEPATH"
echo "📅 チェック日時: $(date)"
echo "================================================================"

# チェック結果を格納する変数
WARNINGS=0
ERRORS=0
SUGGESTIONS=()

# ==================================================
# 基本構造チェック
# ==================================================
echo ""
echo "🔍 [1/8] 基本構造チェック"

# documentclass チェック
if grep -q "\\\\documentclass" "$FILEPATH"; then
    echo "  ✅ documentclass が定義されています"
else
    echo "  ❌ documentclass が見つかりません"
    ((ERRORS++))
fi

# begin{document} と end{document} チェック
if grep -q "\\\\begin{document}" "$FILEPATH" && grep -q "\\\\end{document}" "$FILEPATH"; then
    echo "  ✅ document環境が正しく定義されています"
else
    echo "  ❌ document環境が不完全です"
    ((ERRORS++))
fi

# title, author チェック
if grep -q "\\\\title" "$FILEPATH"; then
    echo "  ✅ タイトルが定義されています"
else
    echo "  ⚠️  タイトルが定義されていません"
    ((WARNINGS++))
    SUGGESTIONS+=("タイトルを\\titleコマンドで定義することを推奨します")
fi

if grep -q "\\\\author" "$FILEPATH"; then
    echo "  ✅ 著者が定義されています"
else
    echo "  ⚠️  著者が定義されていません"
    ((WARNINGS++))
    SUGGESTIONS+=("著者を\\authorコマンドで定義することを推奨します")
fi

# ==================================================
# 日本語設定チェック
# ==================================================
echo ""
echo "🔍 [2/8] 日本語設定チェック"

# LuaLaTeX設定チェック
if grep -q "luatexja" "$FILEPATH"; then
    echo "  ✅ LuaTeX-ja が使用されています（日本語対応）"
else
    echo "  ⚠️  日本語パッケージが見つかりません"
    ((WARNINGS++))
    SUGGESTIONS+=("日本語文書の場合は luatexja-fontspec パッケージの使用を推奨します")
fi

# 文書クラスチェック
if grep -q "ltjs" "$FILEPATH"; then
    echo "  ✅ 日本語文書クラス（ltjs系）を使用しています"
elif grep -q "jarticle\|jreport\|jbook" "$FILEPATH"; then
    echo "  ✅ 日本語文書クラス（j系）を使用しています"
else
    echo "  ⚠️  日本語に最適化された文書クラスを使用していません"
    ((WARNINGS++))
    SUGGESTIONS+=("日本語文書の場合は ltjsarticle, ltjsreport, ltjsbook の使用を推奨します")
fi

# ==================================================
# セクション構造チェック
# ==================================================
echo ""
echo "🔍 [3/8] セクション構造チェック"

SECTIONS=$(grep -c "\\\\section{" "$FILEPATH" 2>/dev/null || echo "0")
SUBSECTIONS=$(grep -c "\\\\subsection{" "$FILEPATH" 2>/dev/null || echo "0")

echo "  📊 section: ${SECTIONS}個, subsection: ${SUBSECTIONS}個"

if [ "$SECTIONS" -eq 0 ]; then
    echo "  ⚠️  セクションが使用されていません"
    ((WARNINGS++))
    SUGGESTIONS+=("文書構造を明確にするためセクションを使用することを推奨します")
else
    echo "  ✅ セクションが適切に使用されています"
fi

# ==================================================
# 図表チェック
# ==================================================
echo ""
echo "🔍 [4/8] 図表チェック"

FIGURES=$(grep -c "\\\\begin{figure}" "$FILEPATH" 2>/dev/null | tr -d '\n' || echo "0")
TABLES=$(grep -c "\\\\begin{table}" "$FILEPATH" 2>/dev/null | tr -d '\n' || echo "0")
INCLUDEGRAPHICS=$(grep -c "\\\\includegraphics" "$FILEPATH" 2>/dev/null | tr -d '\n' || echo "0")

echo "  📊 図: ${FIGURES}個, 表: ${TABLES}個, 画像: ${INCLUDEGRAPHICS}個"

# 図のキャプションチェック
if [ "$FIGURES" -gt 0 ]; then
    FIGURE_CAPTIONS=$(grep -c "\\\\caption" "$FILEPATH" 2>/dev/null || echo "0")
    if [ "$FIGURE_CAPTIONS" -lt "$FIGURES" ]; then
        echo "  ⚠️  図にキャプションが不足している可能性があります"
        ((WARNINGS++))
        SUGGESTIONS+=("すべての図表にキャプションを付けることを推奨します")
    else
        echo "  ✅ 図表のキャプションが適切です"
    fi
fi

# figuresディレクトリの存在チェック
if [ -d "$DIRNAME/figures" ]; then
    echo "  ✅ figuresディレクトリが存在します"
    FIGURE_FILES=$(find "$DIRNAME/figures" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.pdf" -o -name "*.eps" \) | wc -l)
    echo "  📁 figures/に$FIGURE_FILES個の画像ファイルがあります"
else
    if [ "$INCLUDEGRAPHICS" -gt 0 ]; then
        echo "  ⚠️  画像を使用していますが、figuresディレクトリがありません"
        ((WARNINGS++))
        SUGGESTIONS+=("画像ファイルはfigures/ディレクトリに整理することを推奨します")
    fi
fi

# ==================================================
# 参考文献チェック
# ==================================================
echo ""
echo "🔍 [5/8] 参考文献チェック"

CITATIONS=$(grep -c "\\\\cite" "$FILEPATH" 2>/dev/null | tr -d '\n' || echo "0")
BIBLIOGRAPHY=$(grep -c "\\\\begin{thebibliography}\|\\\\bibliography" "$FILEPATH" 2>/dev/null | tr -d '\n' || echo "0")

echo "  📊 引用: ${CITATIONS}箇所, 参考文献リスト: ${BIBLIOGRAPHY}個"

if [ "$CITATIONS" -gt 0 ]; then
    if [ "$BIBLIOGRAPHY" -eq 0 ]; then
        echo "  ❌ 引用がありますが、参考文献リストが見つかりません"
        ((ERRORS++))
    else
        echo "  ✅ 引用と参考文献リストが存在します"
    fi
fi

# ==================================================
# 数式チェック
# ==================================================
echo ""
echo "🔍 [6/8] 数式チェック"

EQUATIONS=$(grep -c "\\\\begin{equation}\|\\\\begin{align}\|\\\\\[\|\$\$" "$FILEPATH" 2>/dev/null || echo "0")
echo "  📊 数式ブロック: ${EQUATIONS}個"

# ams系パッケージのチェック
if [ "$EQUATIONS" -gt 0 ]; then
    if grep -q "amsmath\|amssymb" "$FILEPATH"; then
        echo "  ✅ 数式パッケージが適切に読み込まれています"
    else
        echo "  ⚠️  数式を使用していますが、amsmath/amssymb パッケージが見つかりません"
        ((WARNINGS++))
        SUGGESTIONS+=("数式を使用する場合は amsmath, amssymb パッケージの使用を推奨します")
    fi
fi

# ==================================================
# コードリスティングチェック
# ==================================================
echo ""
echo "🔍 [7/8] コードリスティングチェック"

LISTINGS=$(grep -c "\\\\begin{lstlisting}\|\\\\begin{verbatim}" "$FILEPATH" 2>/dev/null || echo "0")
echo "  📊 コードブロック: ${LISTINGS}個"

if [ "$LISTINGS" -gt 0 ]; then
    if grep -q "listings\|fancyvrb" "$FILEPATH"; then
        echo "  ✅ コード表示パッケージが適切に読み込まれています"
    else
        echo "  ⚠️  コードを使用していますが、適切なパッケージが見つかりません"
        ((WARNINGS++))
        SUGGESTIONS+=("コード表示には listings パッケージの使用を推奨します")
    fi
fi

# ==================================================
# ファイルサイズ・行数チェック
# ==================================================
echo ""
echo "🔍 [8/8] ファイル統計"

FILESIZE=$(wc -c < "$FILEPATH")
LINES=$(wc -l < "$FILEPATH")
WORDS=$(wc -w < "$FILEPATH" 2>/dev/null || echo "N/A")

echo "  📊 ファイルサイズ: $(($FILESIZE / 1024))KB, 行数: ${LINES}行, 単語数: ${WORDS}語"

if [ "$LINES" -lt 50 ]; then
    echo "  ⚠️  文書が短すぎる可能性があります（$LINES行）"
    ((WARNINGS++))
    SUGGESTIONS+=("レポートとして適切な分量を確保することを推奨します")
fi

# ==================================================
# 出力ディレクトリとPDFチェック
# ==================================================
echo ""
echo "🔍 追加チェック: 出力ファイル"

if [ -d "$DIRNAME/output" ]; then
    echo "  ✅ outputディレクトリが存在します"
    if [ -f "$DIRNAME/output/$BASENAME.pdf" ]; then
        PDF_SIZE=$(wc -c < "$DIRNAME/output/$BASENAME.pdf")
        echo "  ✅ PDFファイルが存在します ($(($PDF_SIZE / 1024))KB)"
    else
        echo "  ⚠️  PDFファイルが見つかりません。コンパイルを実行してください"
        ((WARNINGS++))
    fi
else
    echo "  ⚠️  outputディレクトリが存在しません"
    ((WARNINGS++))
fi

# ==================================================
# 結果まとめ
# ==================================================
echo ""
echo "================== チェック結果まとめ =================="

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "🎉 素晴らしい！問題は見つかりませんでした。"
    echo "📝 このレポートは品質基準を満たしています。"
elif [ "$ERRORS" -eq 0 ]; then
    echo "✅ 重大な問題はありません。"
    echo "⚠️  警告: ${WARNINGS}個"
    echo "📝 いくつかの改善提案があります。"
else
    echo "❌ エラー: ${ERRORS}個"
    echo "⚠️  警告: ${WARNINGS}個"
    echo "📝 修正が必要な問題があります。"
fi

echo ""
echo "統計情報:"
echo "  - エラー: ${ERRORS}個"
echo "  - 警告: ${WARNINGS}個" 
TOTAL_FIGURES=$((FIGURES + TABLES))
echo "  - 文書構造: セクション${SECTIONS}個、図表${TOTAL_FIGURES}個"
echo "  - 参考文献: 引用${CITATIONS}箇所"

# ==================================================
# 改善提案の表示
# ==================================================
if [ ${#SUGGESTIONS[@]} -gt 0 ]; then
    echo ""
    echo "==================== 改善提案 ===================="
    for i in "${!SUGGESTIONS[@]}"; do
        echo "$(($i + 1)). ${SUGGESTIONS[$i]}"
    done
fi

# ==================================================
# コンパイル推奨チェック
# ==================================================
if [ -f "$DIRNAME/output/$BASENAME.pdf" ]; then
    TEX_TIME=$(stat -f %m "$FILEPATH" 2>/dev/null || stat -c %Y "$FILEPATH")
    PDF_TIME=$(stat -f %m "$DIRNAME/output/$BASENAME.pdf" 2>/dev/null || stat -c %Y "$DIRNAME/output/$BASENAME.pdf")
    
    if [ "$TEX_TIME" -gt "$PDF_TIME" ]; then
        echo ""
        echo "💡 TEXファイルがPDFより新しいです。再コンパイルを推奨します："
        echo "   ./scripts/compile.sh $FILEPATH"
    fi
fi

echo ""
echo "==================== チェック完了 ===================="

# 終了コードの設定
if [ "$ERRORS" -gt 0 ]; then
    exit 1
else
    exit 0
fi