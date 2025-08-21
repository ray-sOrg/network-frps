# 🚀 FRPS 快速部署指南

本指南将帮助你快速部署 FRPS 服务到腾讯云 K3s 集群，实现完整的 CI/CD 流程。

## 📋 前置要求

### 1. 基础设施

- ✅ 腾讯云服务器（已安装 K3s）
- ✅ 腾讯云容器镜像服务账号
- ✅ GitHub 仓库

### 2. 软件要求

- ✅ kubectl 命令行工具
- ✅ Docker（可选，用于本地测试）

## 🎯 部署流程概览

```
代码提交 → GitHub Actions → 构建镜像 → 推送到腾讯云 → 部署到K3s → 服务就绪
```

## ⚡ 快速开始（5 分钟部署）

### 步骤 1: 配置 GitHub Secrets

1. 进入你的 GitHub 仓库 → `Settings` → `Secrets and variables` → `Actions`
2. 添加以下 Secrets：
   ```
   TENCENT_REGISTRY_USERNAME: 你的腾讯云镜像服务用户名
   TENCENT_REGISTRY_PASSWORD: 你的腾讯云镜像服务密码
   KUBE_CONFIG: 你的K3s集群kubeconfig的base64编码
   ```

### 步骤 2: 推送代码触发部署

```bash
# 推送代码到main分支
git add .
git commit -m "Initial deployment"
git push origin main
```

### 步骤 3: 监控部署状态

1. 在 GitHub 仓库中查看 `Actions` 标签
2. 等待工作流完成（通常需要 3-5 分钟）
3. 检查部署结果

### 步骤 4: 验证部署

```bash
# 在你的K3s服务器上执行
kubectl get pods -n frps
kubectl get svc -n frps
```

## 🔧 手动部署（可选）

如果你需要手动部署或调试，可以使用以下命令：

### 1. 构建并推送镜像

```bash
# 构建镜像
docker build -t ccr.ccs.tencentyun.com/ray321/frps:latest .

# 登录腾讯云镜像服务
docker login ccr.ccs.tencentyun.com

# 推送镜像
docker push ccr.ccs.tencentyun.com/ray321/frps:latest
```

### 2. 部署到 K3s

```bash
# 创建命名空间
kubectl apply -f k8s/namespace.yaml

# 创建Secret
kubectl apply -f k8s/secret.yaml

# 部署应用
kubectl apply -k k8s/
```

## 🌐 访问服务

部署成功后，你可以通过以下方式访问：

### NodePort 方式

- **FRP 服务**: `http://<你的服务器IP>:30000`
- **仪表板**: `http://<你的服务器IP>:30001`

### 域名方式（需要配置 DNS）

- **仪表板**: `http://frps.ray321.cn`

## 📊 部署状态检查

使用内置的检查脚本验证部署状态：

```bash
# 给脚本添加执行权限
chmod +x scripts/check.sh

# 运行检查
./scripts/check.sh
```

## 🔍 故障排查

### 常见问题及解决方案

| 问题         | 现象                        | 解决方案                   |
| ------------ | --------------------------- | -------------------------- |
| 镜像拉取失败 | Pod 状态为 ImagePullBackOff | 检查镜像仓库认证 Secret    |
| 服务无法访问 | 端口连接超时                | 检查防火墙和 NodePort 配置 |
| Pod 启动失败 | Pod 状态为 CrashLoopBackOff | 查看 Pod 日志排查配置问题  |

### 查看日志

```bash
# 查看Pod日志
kubectl logs -n frps deployment/frps

# 查看Pod状态
kubectl describe pod -n frps -l app=frps

# 查看服务状态
kubectl get events -n frps --sort-by='.lastTimestamp'
```

## 🔄 更新部署

### 自动更新（推荐）

推送代码到 main 分支即可自动触发更新。

### 手动更新

```bash
# 更新镜像标签
kubectl set image deployment/frps frps=ccr.ccs.tencentyun.com/ray321/frps:latest -n frps

# 重启部署
kubectl rollout restart deployment/frps -n frps
```

## 📈 监控和维护

### 1. 资源监控

```bash
# 查看资源使用情况
kubectl top pods -n frps
kubectl top nodes
```

### 2. 日志管理

```bash
# 查看实时日志
kubectl logs -f -n frps deployment/frps

# 导出日志
kubectl logs -n frps deployment/frps > frps.log
```

### 3. 备份配置

```bash
# 备份Kubernetes配置
kubectl get all -n frps -o yaml > frps-backup.yaml
```

## 🎉 部署完成！

恭喜！你的 FRPS 服务已经成功部署。现在你可以：

1. **配置 frpc 客户端** 连接到你的 frps 服务器
2. **访问 Web 仪表板** 监控服务状态
3. **配置域名解析** 使用自定义域名访问
4. **设置监控告警** 确保服务稳定运行

## 📚 更多资源

- [项目 README](./README.md) - 详细的项目说明
- [GitHub Secrets 配置](./GITHUB_SECRETS_SETUP.md) - 完整的 Secrets 配置指南
- [故障排查指南](./TROUBLESHOOTING.md) - 常见问题解决方案

## 🤝 获取帮助

如果遇到问题：

1. 查看 GitHub Actions 日志
2. 运行检查脚本获取详细信息
3. 在 GitHub Issues 中提问
4. 参考项目文档和配置示例
