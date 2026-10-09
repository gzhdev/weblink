# Weblink 内网离线部署包

```text
weblink-offline-<版本>-<架构>/
├── .env                      版本号、信令地址、宿主机端口
├── docker-compose.yml
├── SHA256SUMS
├── images/                   web、ws-server、coturn 镜像包
└── conf/
    ├── nginx/nginx.conf.template
    ├── coturn/turnserver.conf
    └── ssl/                  放 server.crt / server.pem，gen-cert.sh 可生成自签证书
```

## 部署

```bash
mkdir -p /opt/weblink && cp -r weblink-offline-*/. /opt/weblink/
cd /opt/weblink
sha256sum -c SHA256SUMS

# 1. 导入镜像
for f in images/*.tar.gz; do docker load -i "$f"; done

# 2. 证书：已有内网 CA 签发的证书则直接放入 conf/ssl/，否则生成自签证书
sh conf/ssl/gen-cert.sh weblink.intra.local 10.0.0.10

# 3. 修改配置
#    .env                         VITE_WEBSOCKET_URL 改为 wss://<域名>/ws
#    conf/coturn/turnserver.conf  10.0.0.10 改为服务器 IP，账号与构建时 TURN 配置一致

# 4. 启动
docker compose up -d
docker compose ps
```

客户端需能解析域名（内网 DNS 或 hosts），并把 `conf/ssl/ca.crt` 导入受信任根证书，否则 `wss://` 连接失败、无法进入房间。

## 防火墙

| 端口 | 协议 | 用途 |
| --- | --- | --- |
| 80 / 443 | TCP | 页面与信令 |
| 3478 | UDP + TCP | STUN / TURN |
| 49160–49200 | UDP | TURN 中继 |

```bash
firewall-cmd --permanent --add-service=http --add-service=https
firewall-cmd --permanent --add-port=3478/udp --add-port=3478/tcp --add-port=49160-49200/udp
firewall-cmd --reload
```

## 验证

```bash
curl -s https://weblink.intra.local/version.json
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://weblink.intra.local/turn-credentials   # 503 为正常
docker compose exec coturn turnutils_stunclient 10.0.0.10
```

## 升级与回滚

导入新版本镜像后修改 `.env` 中的 `VER`，执行 `docker compose up -d`；回滚时把 `VER` 改回旧值再执行同一命令。旧版本镜像至少保留一个，不要 `docker image prune -a`。

## 说明

- 信令地址在容器启动时写入页面，改域名/IP 只需改 `.env` 后 `docker compose up -d`，无需重建镜像。
- 默认 STUN/TURN 地址在构建时写入前端，服务器 IP 变化需重新构建；用户也可在应用设置中自行修改。
- 宿主机已有 Nginx 占用 80/443 时，把 `.env` 中 `HTTP_PORT`、`HTTPS_PORT` 改为其他端口，由宿主机 Nginx 反代到 HTTPS 端口（需同时转发 `/ws` 的 WebSocket 升级头）。
