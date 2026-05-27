FROM debian:12-slim

ARG VERSION=v0.1.4

LABEL org.opencontainers.image.version="${VERSION}"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    chromium \
    curl \
    fluxbox \
    fonts-liberation \
    fonts-noto-cjk \
    git \
    gosu \
    net-tools \
    novnc \
    openssh-client \
    procps \
    python3 \
    rsync \
    tigervnc-tools \
    websockify \
    x11-utils \
    x11vnc \
    xterm \
    xvfb \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash --uid 1000 app

WORKDIR /opt/gujumpgate-shell

COPY --chown=app:app . /opt/gujumpgate-shell
COPY docker/entrypoint.sh /usr/local/bin/gujumpgate-entrypoint
COPY docker/desktop-session.sh /usr/local/bin/gujumpgate-desktop-session

RUN chmod +x /usr/local/bin/gujumpgate-entrypoint /usr/local/bin/gujumpgate-desktop-session

ENV DISPLAY=:1 \
    EXTENSION_DIR=/opt/gujumpgate-core \
    CHROME_USER_DATA_DIR=/home/app/.config/chromium-gujumpgate \
    DOWNLOAD_DIR=/home/app/Downloads \
    RESOLUTION=1440x900 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080 \
    HOTMAIL_HELPER_HOST=127.0.0.1 \
    HOTMAIL_HELPER_PORT=17373 \
    GIT_REPO_URL=https://github.com/FoundZiGu/GuJumpgate.git \
    AUTO_PULL_LATEST_CODE=true \
    GLOBAL_PROXY= \
    GIT_PROXY= \
    CONFIG_PROXY= \
    START_HOTMAIL_HELPER=1 \
    START_URL=chrome://extensions/

EXPOSE 5900 6080

VOLUME ["/home/app/.config/chromium-gujumpgate", "/home/app/Downloads", "/opt/gujumpgate-core"]

ENTRYPOINT ["gujumpgate-entrypoint"]
CMD ["gujumpgate-desktop-session"]
