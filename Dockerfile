# 使用Python 3.11作为基础镜像
FROM python:3.11-slim-bookworm AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TZ=Asia/Shanghai \
    DOCKER_ENV=true \
    PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

WORKDIR /app

# ==================== Frontend Builder Stage ====================
FROM node:20-alpine AS frontend-builder
WORKDIR /frontend

COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN npm install -g pnpm@10 && \
    pnpm config set dangerously-allow-all-builds true && \
    pnpm install --no-frozen-lockfile

COPY frontend/ ./
RUN pnpm build

# ==================== Python Builder Stage ====================
FROM base AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
COPY --from=frontend-builder /static ./static

# ==================== Runtime Stage ====================
FROM base AS runtime

LABEL maintainer="zhinianboke" \
      version="2.2.0" \
      description="闲鱼自动回复系统 - 企业级多用户版本，支持自动发货和免拼发货" \
      repository="https://github.com/zhinianboke/xianyu-auto-reply"

ENV NODE_PATH=/usr/lib/node_modules

# 只手工安装项目自身需要的系统工具。
# Chromium 的底层共享库交给 Playwright 官方 install-deps 自动解析，
# 避免 Debian 版本升级导致手工维护的包名失效。
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nodejs \
        npm \
        tzdata \
        curl \
        ca-certificates \
        fonts-dejavu-core \
        fonts-liberation \
        chromium \
        xvfb \
        x11vnc \
        fluxbox \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN node --version && npm --version && chromium --version

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app /app
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="$VIRTUAL_ENV/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"

# 由当前已安装的 Playwright 版本自动安装匹配的浏览器依赖与 Chromium。
RUN playwright install-deps chromium && \
    playwright install chromium

RUN mkdir -p /app/logs /app/data /app/backups /app/static/uploads/images && \
    chmod 777 /app/logs /app/data /app/backups /app/static/uploads /app/static/uploads/images

RUN echo "ulimit -c 0" >> /etc/profile

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

CMD ["python", "/app/Start.py"]