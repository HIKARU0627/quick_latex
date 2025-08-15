# TeX Live 公式イメージ（フル版）
FROM texlive/texlive:latest

# 必要なツールとフォントをインストール
RUN apt-get update && apt-get install -y \
    # 日本語フォント
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    # ビルドツール
    make \
    # ファイル監視用
    inotify-tools \
    # PDF処理
    poppler-utils \
    # エディタ（緊急時用）
    vim \
    && rm -rf /var/lib/apt/lists/*

# 追加のLaTeXパッケージ（レポートでよく使うもの）
RUN tlmgr update --self && tlmgr install \
    listings \
    algorithm2e \
    pgfplots \
    tikz-cd \
    chemfig \
    mhchem \
    siunitx \
    cancel

# 作業ディレクトリ
WORKDIR /workspace

# カスタムスタイルファイルのパスを追加
ENV TEXMFHOME=/workspace/docker/texmf

CMD ["/bin/bash"]