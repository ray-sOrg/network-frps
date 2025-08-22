# FRPS Docker + K3s 部署

这是一个基于 Docker 和 K3s 的 FRP 服务端部署项目，用于实现外网访问家庭网络。

## 项目结构

```
.
├── Dockerfile              # Docker 镜像构建文件
├── frps.ini               # FRP 服务端配置文件
├── .dockerignore          # Docker 构建上下文忽略文件

├── k8s/                   # Kubernetes 配置文件
│   ├── namespace.yaml     # 命名空间配置
│   ├── secret.yaml        # 密钥配置（敏感信息）
│   ├── configmap.yaml     # 配置映射
│   ├── deployment.yaml    # 部署配置
│   ├── service.yaml       # 服务配置
│   ├── ingress.yaml       # 入口配置
│   └── kustomization.yaml # Kustomize 配置
├── scripts/               # 部署脚本
│   ├── deploy.sh          # 主部署脚本
│   └── common.sh          # 通用函数
└── README.md              # 项目说明
```

## 快速部署

### 1. 构建 Docker 镜像

```bash
docker build -t frps:0.64.0 .
```

### 2. 推送到镜像仓库

```bash
# 替换为你的镜像仓库地址
docker tag frps:0.64.0 ccr.ccs.tencentyun.com/ray321/frps:0.64.0
docker push ccr.ccs.tencentyun.com/ray321/frps:0.64.0
```

### 3. 部署到 K3s

#### 方式一：使用部署脚本（推荐）

```bash
# 设置环境变量（可选，用于自定义密码和token）
export FRP_DASHBOARD_PWD="your_secure_password"
export FRP_TOKEN="your_secure_token"

# 运行部署脚本
cd scripts
./deploy.sh
```

#### 方式二：手动部署

```bash
# 进入 k8s 目录
cd k8s

# 使用 kustomize 部署
kubectl apply -k .

# 或者单独部署
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

## 配置方式对比

### 配置优先级（从高到低）

1. **K8s ConfigMap 挂载** - 生产环境，支持热更新
2. **环境变量覆盖** - 运行时动态配置
3. **镜像内置 frps.ini** - 默认配置，兜底方案

### 配置方式选择

| 部署方式            | 配置方式             | 优点                 | 缺点                 | 适用场景             |
| ------------------- | -------------------- | -------------------- | -------------------- | -------------------- |
| **Docker 直接部署** | 环境变量 + 内置配置  | 简单直接，调试方便   | 配置固定，需重建镜像 | 测试、开发、简单生产 |
| **K3s 集群部署**    | ConfigMap + 环境变量 | 配置热更新，版本管理 | 配置复杂，依赖 K8s   | 生产环境，多环境管理 |

## 配置说明

### 端口配置

- `7000`: FRP 服务端口（客户端连接）
- `7500`: 仪表板端口（Web 管理界面）
- `6001-6003`: 代理端口（用于网页访问本地服务）
- `30000`: NodePort 映射到 7000（仅 K8s）
- `30001`: NodePort 映射到 7500（仅 K8s）
- `30002-30004`: NodePort 映射到 6001-6003（仅 K8s）

### 网页代理访问

通过 Ingress 配置，你可以通过以下地址访问本地服务：

- **PVE 管理界面**: `https://tx.ray321.cn/pve`
- **iKuai 管理界面**: `https://tx.ray321.cn/ikuai`
- **iStoreOS 管理界面**: `https://tx.ray321.cn/istoreos`
- **FRPS 管理面板**: `https://tx.ray321.cn/frps`

详细配置说明请参考 [PROXY_ACCESS_GUIDE.md](./PROXY_ACCESS_GUIDE.md)

### 访问方式

1. **NodePort 方式**：

   - FRP 服务：`http://121.4.118.156:30000`
   - 仪表板：`http://121.4.118.156:30001`

2. **Ingress 方式**：
   - 仪表板：`http://frps.ray321.cn`（仅仪表板）
   - FRP 服务：仅通过 NodePort 访问，不通过 Ingress 暴露

## 安全配置

### 密钥管理

项目使用 Kubernetes Secret 管理敏感信息：

- `dashboard_user`: 仪表板用户名
- `dashboard_pwd`: 仪表板密码
- `token`: FRP 认证令牌

### 环境变量配置

可以通过环境变量自定义密码和 token：

```bash
export FRP_DASHBOARD_PWD="your_secure_password"
export FRP_TOKEN="your_secure_token"
```

## 配置修改

修改 `k8s/configmap.yaml` 中的配置后，需要重启 Pod：

```bash
kubectl rollout restart deployment/frps -n frps
```

## 监控和日志

```bash
# 查看 Pod 状态
kubectl get pods -n frps

# 查看日志
kubectl logs -f deployment/frps -n frps

# 查看服务状态
kubectl get svc -n frps

# 查看 Secret 状态
kubectl get secret -n frps
```

## 家庭网络配置

### 软路由部署 frpc

在你的家庭软路由上部署 frpc 客户端：

```bash
# 下载 frpc
wget https://github.com/fatedier/frp/releases/download/v0.64.0/frp_0.64.0_linux_amd64.tar.gz
tar -xzf frp_0.64.0_linux_amd64.tar.gz

# 配置 frpc.ini
cat > frpc.ini << EOF
[common]
server_addr = 121.4.118.156
server_port = 30000
token = ttangtao123

[ssh]
type = tcp
local_ip = 127.0.0.1
local_port = 22
remote_port = 6001

[web]
type = http
local_ip = 192.168.1.1
local_port = 80
custom_domains = home.ray321.cn
EOF

# 启动 frpc
./frpc -c frpc.ini
```

## 注意事项

1. **安全提醒**：请修改默认密码和 token
2. **资源限制**：根据实际需求调整资源限制
3. **网络配置**：确保防火墙开放相应端口
4. **域名解析**：配置域名解析到腾讯云服务器 IP
5. **备份配置**：定期备份配置文件

## 故障排除

### 常见问题

1. **Pod 启动失败**

   - 检查镜像是否存在
   - 检查 Secret 配置
   - 查看 Pod 日志

2. **连接超时**

   - 检查防火墙配置
   - 验证端口映射
   - 检查网络连通性

3. **配置不生效**
   - 重启 Pod
   - 检查 ConfigMap 更新
   - 验证环境变量
