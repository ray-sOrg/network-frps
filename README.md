# FRPS Docker 部署

FRP 服务端 Docker 镜像，用于实现外网访问家庭网络。

## 项目结构

```
.
├── frps                # FRP 服务端二进制文件 (v0.65.0)
├── Dockerfile          # Docker 镜像构建
├── deployment.yaml     # K8s 部署配置
├── .dockerignore       # Docker 忽略文件
└── .github/workflows/  # GitHub Actions 自动部署
```

## 升级 FRP 版本

```bash
# 下载新版本 (替换版本号)
VERSION=0.64.0
curl -L -o frp.tar.gz https://github.com/fatedier/frp/releases/download/v${VERSION}/frp_${VERSION}_linux_amd64.tar.gz
tar -xzf frp.tar.gz
mv frp_${VERSION}_linux_amd64/frps .
rm -rf frp_${VERSION}_linux_amd64 frp.tar.gz

# 提交并推送，自动触发部署
git add frps && git commit -m "upgrade frps to v${VERSION}" && git push
```

## 自动部署

推送代码到 `main` 分支，GitHub Actions 自动：
1. 构建 Docker 镜像并推送到阿里云 ACR
2. 部署到 K8s 集群

### 需要配置的 Secrets

| Secret 名称 | 说明 |
|------------|------|
| `ALICLOUD_USERNAME` | 阿里云 ACR 用户名 |
| `ALICLOUD_PASSWORD` | 阿里云 ACR 密码 |
| `KUBECONFIG` | K8s 集群配置 |
| `FRP_DASHBOARD_PWD` | FRP Dashboard 密码 |
| `FRP_TOKEN` | FRP 认证令牌 |

## 端口说明

| 端口 | 用途 |
|------|------|
| `7000` | FRP 主端口（客户端连接） |
| `7500` | Dashboard（Web 管理界面） |
| `6001-6100` | 代理端口范围（用于穿透服务） |

## 客户端配置示例

在家庭软路由/Mac 上配置 `frpc.toml`：

```toml
serverAddr = "你的服务器IP"
serverPort = 7000
auth.token = "你的token"

[[proxies]]
name = "qbittorrent"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8080
remotePort = 6001

[[proxies]]
name = "moviepilot"
type = "tcp"
localIP = "127.0.0.1"
localPort = 3000
remotePort = 6002
```

## 常用命令

```bash
# 查看 Pod 状态
kubectl get pods -n frps

# 查看日志
kubectl logs -f deployment/frps-deployment -n frps

# 重启部署
kubectl rollout restart deployment/frps-deployment -n frps
```
