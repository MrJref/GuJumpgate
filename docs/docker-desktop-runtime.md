# Docker Remote Desktop Runtime

本仓库是 GuJumpgate Docker 运行壳。主核扩展代码不在本仓库维护，容器启动时通过 Git 拉取：

```text
https://github.com/FoundZiGu/GuJumpgate.git
```

默认运行目录：

- 壳项目目录：`/opt/gujumpgate-shell`
- 主核项目目录：`/opt/gujumpgate-core`
- Chromium 用户数据：`/home/app/.config/chromium-gujumpgate`
- 下载目录：`/home/app/Downloads`

## docker run

```bash
docker build -t gujumpgate-desktop:local .

docker run -d \
  --name gujumpgate-desktop \
  --shm-size=2g \
  -p 6080:6080 \
  -p 5900:5900 \
  -e TZ=Asia/Shanghai \
  -e RESOLUTION=1440x900 \
  -e VNC_PASSWORD=replace-me \
  -e GIT_REPO_URL=https://github.com/FoundZiGu/GuJumpgate.git \
  -e AUTO_PULL_LATEST_CODE=true \
  -e GLOBAL_PROXY= \
  -e GIT_PROXY= \
  -e CONFIG_PROXY= \
  -v gujumpgate-core:/opt/gujumpgate-core \
  -v gujumpgate-chromium:/home/app/.config/chromium-gujumpgate \
  -v gujumpgate-downloads:/home/app/Downloads \
  --add-host=host.docker.internal:host-gateway \
  gujumpgate-desktop:local
```

## docker compose

```bash
VNC_PASSWORD=replace-me docker compose up -d --build
```

停止：

```bash
docker compose down
```

## 自动更新主核项目

通过这两个环境变量控制容器启动时是否自动更新主核项目：

- `GIT_REPO_URL`：要拉取的 Git 仓库地址，默认 `https://github.com/FoundZiGu/GuJumpgate.git`。
- `AUTO_PULL_LATEST_CODE`：是否在容器启动时检查并拉取最新代码，默认 `true`。

当 `AUTO_PULL_LATEST_CODE=true` 且 `GIT_REPO_URL` 不为空时，容器每次启动都会先检查 `/opt/gujumpgate-core`。如果目录已经是 Git 仓库，则执行 `fetch` 并在远端有更新时 `pull --ff-only`；如果目录不是 Git 仓库，则首次从 `GIT_REPO_URL` clone 并同步到扩展目录。

如果 `AUTO_PULL_LATEST_CODE=false`，容器重启时不会检查或拉取代码，直接使用 `/opt/gujumpgate-core` 当前内容。

## 代理变量

容器支持三类代理变量：

- `GLOBAL_PROXY`：全局兜底代理。
- `GIT_PROXY`：Git 专用代理，只用于 `AUTO_PULL_LATEST_CODE=true` 时的 `clone / fetch / pull`。
- `CONFIG_PROXY`：项目运行代理，用于容器内 Chromium 和 Hotmail Helper 的运行期网络。

优先级：

- Git 交互使用 `GIT_PROXY`；如果未配置，则回退到 `GLOBAL_PROXY`。
- 项目运行使用 `CONFIG_PROXY`；如果未配置，则回退到 `GLOBAL_PROXY`。
- 如果只配置 `GLOBAL_PROXY`，Git 交互和项目运行都会使用这个代理。

示例：

```bash
GLOBAL_PROXY=http://host.docker.internal:7890 \
GIT_PROXY=http://host.docker.internal:7891 \
CONFIG_PROXY=socks5://host.docker.internal:7892 \
docker compose up -d
```

## 访问地址

- noVNC 浏览器远程桌面：`http://<宿主机局域网IP>:6080/vnc.html?autoconnect=1&resize=scale`
- 普通 VNC 客户端：`<宿主机局域网IP>:5900`

## 常用环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `RESOLUTION` | `1440x900` | 远程桌面分辨率 |
| `VNC_PASSWORD` | 空 | x11vnc/RFB 认证密码；noVNC 会把页面输入的密码转发给 x11vnc。标准 VNC 认证只使用前 8 个字符 |
| `START_URL` | `chrome://extensions/` | Chromium 启动后打开的页面 |
| `START_HOTMAIL_HELPER` | `1` | 是否自动启动主核项目内的 Hotmail Helper |
| `HOTMAIL_HELPER_HOST` | `127.0.0.1` | helper 监听地址 |
| `HOTMAIL_HELPER_PORT` | `17373` | helper 监听端口 |
| `GIT_REPO_URL` | `https://github.com/FoundZiGu/GuJumpgate.git` | 自动更新时要拉取的主核 Git 仓库地址 |
| `AUTO_PULL_LATEST_CODE` | `true` | 是否在容器启动时检查并拉取最新代码 |
| `GLOBAL_PROXY` | 空 | Git 与项目运行的兜底代理 |
| `GIT_PROXY` | 空 | Git 专用代理，优先级高于 `GLOBAL_PROXY` |
| `CONFIG_PROXY` | 空 | 项目运行代理，优先级高于 `GLOBAL_PROXY` |
| `CHROMIUM_EXTRA_ARGS` | 空 | 额外 Chromium 参数 |
