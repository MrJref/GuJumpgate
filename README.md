# GuJumpgate Docker Runtime Shell

当前版本：`v0.1.8`

这是 GuJumpgate 的 Docker 运行壳项目，不再维护浏览器扩展业务代码。

主核项目来源：

```text
https://github.com/FoundZiGu/GuJumpgate.git
```

容器启动时会从 `GIT_REPO_URL` 拉取主核项目到 `/opt/gujumpgate-core`，再用 Chromium 加载该目录作为浏览器扩展。当前仓库只负责 Docker、Chromium、VNC/noVNC、Hotmail Helper 运行环境。

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

`docker-compose.yml` 默认配置：

- `GIT_REPO_URL=https://github.com/FoundZiGu/GuJumpgate.git`
- `AUTO_PULL_LATEST_CODE=true`
- 主核项目持久化到 named volume：`gujumpgate-core`
- `VNC_PASSWORD` 是 x11vnc/RFB 认证密码；noVNC 会把页面输入的密码转发给 x11vnc。标准 VNC 认证只使用前 8 个字符。

## 访问

noVNC 浏览器远程桌面：

```text
http://<宿主机局域网IP>:6080/vnc.html?autoconnect=1&resize=scale
```

普通 VNC 客户端：

```text
<宿主机局域网IP>:5900
```

## 代理变量

- `GLOBAL_PROXY`：全局兜底代理。
- `GIT_PROXY`：Git 专用代理，只用于自动拉取主核项目。
- `CONFIG_PROXY`：项目运行代理，用于 Chromium 和 helper 运行期网络。

优先级：

- Git 交互使用 `GIT_PROXY`，未配置时回退到 `GLOBAL_PROXY`。
- 项目运行使用 `CONFIG_PROXY`，未配置时回退到 `GLOBAL_PROXY`。
- 只配置 `GLOBAL_PROXY` 时，Git 交互和项目运行都会使用它。

更多说明见 [Docker Remote Desktop Runtime](docs/docker-desktop-runtime.md)。
