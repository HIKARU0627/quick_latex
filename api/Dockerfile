FROM python:3.11-slim

# 作業ディレクトリの設定
WORKDIR /app

# システムパッケージの更新とDockerのインストール
RUN apt-get update && apt-get install -y \
    docker.io \
    docker-compose \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Python依存関係のインストール
COPY api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# プロジェクトファイルのコピー
COPY . /app/

# APIサーバーの起動
EXPOSE 5000

# ヘルスチェック
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/api/health || exit 1

# 環境変数の設定
ENV FLASK_APP=api/server.py
ENV FLASK_ENV=production
ENV PYTHONPATH=/app

# APIサーバーを起動
CMD ["python", "api/server.py"]