# FRPS Docker + K3s 部署

这是一个基于 Docker 和 K3s 的 FRP 服务端部署项目。

## 项目结构

```
.
├── Dockerfile              # Docker 镜像构建文件
├── frps.ini               # FRP 服务端配置文件
├── .dockerignore          # Docker 忽略文件
├── k8s/                   # Kubernetes 配置文件
│   ├── namespace.yaml     # 命名空间配置
│   ├── configmap.yaml     # 配置映射
│   ├── deployment.yaml    # 部署配置
│   ├── service.yaml       # 服务配置
│   ├── ingress.yaml       # 入口配置
│   └── kustomization.yaml # Kustomize 配置
└── README.md              # 项目说明
```

## 快速部署

### 1. 构建 Docker 镜像

```bash
docker build -t frps:0.63.0 .
```

### 2. 推送到镜像仓库

```bash
# 替换为你的镜像仓库地址
docker tag frps:0.63.0 ccr.ccs.tencentyun.com/ray321/frps:0.63.0
docker push ccr.ccs.tencentyun.com/ray321/frps:0.63.0
```

### 3. 部署到 K3s

```bash
# 进入 k8s 目录
cd k8s

# 使用 kustomize 部署
kubectl apply -k .

# 或者单独部署
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

## 配置说明

### 端口配置

- `7000`: FRP 服务端口（客户端连接）
- `7500`: 仪表板端口（Web 管理界面）
- `30000`: NodePort 映射到 7000
- `30001`: NodePort 映射到 7500

### 访问方式

1. **NodePort 方式**：

   - FRP 服务：`http://121.4.118.156:30000`
   - 仪表板：`http://121.4.118.156:30001`

2. **Ingress 方式**：
   - 仪表板：`http://frps.ray321.cn`（仅仪表板）
   - FRP 服务：仅通过 NodePort 访问，不通过 Ingress 暴露

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
```

## 注意事项

1. 请修改 `frps.ini` 中的密码和 token
2. 根据实际需求调整资源限制
3. Ingress 仅暴露仪表板端口（7500），FRP 服务端口（7000）通过 NodePort 访问
4. 确保镜像仓库的访问权限配置正确
