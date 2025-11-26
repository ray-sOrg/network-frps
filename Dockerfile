FROM alpine:latest

# 复制本地预下载的 frps 二进制文件
COPY frps /usr/local/bin/frps
RUN chmod +x /usr/local/bin/frps && mkdir -p /etc/frp /var/log

# 暴露端口：7000(主端口) 7500(Dashboard)
EXPOSE 7000 7500

# 启动命令（配置文件由 K8s ConfigMap 挂载）
CMD ["frps", "-c", "/etc/frp/frps.toml"]
