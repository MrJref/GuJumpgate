# Docker Remote Desktop Runtime

这个容器把 GuJumpgate 扩展、Chromium、虚拟桌面、VNC/noVNC 和本地 Hotmail Helper 放在同一个运行环境里。浏览器在容器内运行，所以扩展默认配置里的 `http://127.0.0.1:17373` 会连接到容器内的 helper。

## 构建镜像

```bash
docker build -t gujumpgate-desktop:local .
```

## docker run

```bash
docker run -d \
  --name gujumpgate-desktop \
  --shm-size=2g \
  -p 6080:6080 \
  -p 5900:5900 \
  -e TZ=Asia/Shanghai \
  -e RESOLUTION=1440x900 \
  -e VNC_PASSWORD=replace-me \
  -v "$PWD:/opt/gujumpgate" \
  -v gujumpgate-chromium:/home/app/.config/chromium-gujumpgate \
  -v gujumpgate-downloads:/home/app/Downloads \
  --add-host=host.docker.internal:host-gateway \
  gujumpgate-desktop:local
```

访问地址：

- noVNC 浏览器远程桌面：`http://<宿主机局域网IP>:6080/vnc.html?autoconnect=1&resize=scale`
- 普通 VNC 客户端：`<宿主机局域网IP>:5900`

## docker compose

```bash
VNC_PASSWORD=replace-me docker compose up -d --build
```

停止：

```bash
docker compose down
```

## 更新扩展代码

compose 和上面的 `docker run` 示例都把当前仓库挂载到了 `/opt/gujumpgate`。因此更新代码后重启容器即可：

```bash
git pull
docker compose restart
```

如果没有挂载当前仓库，而是只使用镜像内复制的代码，则需要重新构建镜像。

## 常用环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `RESOLUTION` | `1440x900` | 远程桌面分辨率 |
| `VNC_PASSWORD` | 空 | VNC/noVNC 密码；局域网使用建议设置 |
| `START_URL` | `chrome://extensions/` | Chromium 启动后打开的页面 |
| `START_HOTMAIL_HELPER` | `1` | 是否自动启动本地 Hotmail Helper |
| `HOTMAIL_HELPER_HOST` | `127.0.0.1` | helper 监听地址 |
| `HOTMAIL_HELPER_PORT` | `17373` | helper 监听端口 |
| `CHROMIUM_EXTRA_ARGS` | 空 | 额外 Chromium 参数 |

## 代理说明

容器内访问宿主机服务时可以使用 `host.docker.internal`。例如宿主机 Clash/Mihomo 监听 `7890`，扩展或浏览器内可配置为：

```text
host.docker.internal:7890
```

如果你的 Docker 环境不支持 `host-gateway`，需要改成宿主机在 Docker 网桥上的实际 IP。
