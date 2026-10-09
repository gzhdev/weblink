#!/usr/bin/env sh
# 生成内网自签根 CA 与服务器证书，输出到本目录：
#   ca.crt      分发到客户端并导入为受信任根证书
#   ca.key      根证书私钥，妥善保管，不要随部署包分发
#   server.crt  nginx 使用的证书
#   server.pem  nginx 使用的私钥
# 用法：sh gen-cert.sh <域名> <服务器IP>
# 已有单位内网 CA 时不需要本脚本，直接把签发的证书放成 server.crt / server.pem。
set -eu

HOST="${1:-weblink.intra.local}"
SERVER_IP="${2:-10.0.0.10}"
cd "$(dirname "$0")"

if [ ! -f ca.key ]; then
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -key ca.key -sha256 -days 3650 \
    -subj "/CN=Weblink Intranet Root CA" -out ca.crt
fi

openssl genrsa -out server.pem 2048
openssl req -new -key server.pem -subj "/CN=${HOST}" -out server.csr
cat > server.ext <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:${HOST},IP:${SERVER_IP}
EOF
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 825 -sha256 -extfile server.ext -out server.crt
rm -f server.csr server.ext
chmod 644 server.crt ca.crt
chmod 600 server.pem ca.key

echo "已生成 server.crt / server.pem（${HOST}, ${SERVER_IP}），请把 ca.crt 导入各客户端的受信任根证书。"
