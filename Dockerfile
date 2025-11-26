FROM alpine:latest

ENV FRP_VERSION=0.65.0

# 从 GitHub 镜像站下载 frps（国内加速）
RUN apk add --no-cache curl gettext && \
    curl -L -o /tmp/frp.tar.gz "https://gh.ddlc.top/https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz" && \
    tar -xzf /tmp/frp.tar.gz -C /tmp && \
    mv /tmp/frp_${FRP_VERSION}_linux_amd64/frps /usr/local/bin/frps && \
    chmod +x /usr/local/bin/frps && \
    rm -rf /tmp/* && \
    mkdir -p /etc/frp /var/log

# 暴露端口：7000(主端口) 7500(Dashboard)
EXPOSE 7000 7500

# 启动命令（配置文件由 K8s ConfigMap 挂载）
CMD ["frps", "-c", "/etc/frp/frps.toml"]
