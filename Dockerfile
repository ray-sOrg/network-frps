FROM alpine:latest

# 安装 curl
RUN apk add --no-cache curl

# 设置 FRP 版本为 v0.63.0
ENV FRP_VERSION=0.63.0

# 下载并安装 frps
RUN curl -L https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz \
    | tar xz -C /tmp && \
    mv /tmp/frp_${FRP_VERSION}_linux_amd64/frps /usr/local/bin/frps && \
    chmod +x /usr/local/bin/frps && \
    rm -rf /tmp/frp_${FRP_VERSION}_linux_amd64

# 复制配置文件
COPY frps.ini /etc/frp/frps.ini

# 暴露常用端口（你可以根据 frps.ini 的配置暴露更多）
EXPOSE 7000 7500

# 启动命令
CMD ["frps", "-c", "/etc/frp/frps.ini"]
