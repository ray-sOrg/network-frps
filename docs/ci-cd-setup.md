# CI/CD 设置指南

## 概述

本文档详细说明如何设置完整的 CI/CD 流程，实现代码提交后自动构建、推送镜像并部署到腾讯云 K3s 集群。

## 前置要求

### 1. 腾讯云环境

- 已安装 K3s 的云服务器
- 腾讯云容器镜像服务(CCR)账号
- 服务器访问权限

### 2. GitHub 仓库

- 代码已推送到 GitHub
- 仓库访问权限

## 详细配置步骤

### 步骤 1: 配置腾讯云容器镜像服务

1. 登录腾讯云控制台
2. 进入容器镜像服务
3. 创建命名空间（如：ray321）
4. 创建镜像仓库（如：frps）
5. 获取访问凭证：
   - 用户名：通常是腾讯云账号 ID
   - 密码：在镜像仓库页面生成临时访问凭证

### 步骤 2: 配置 K3s 集群访问

1. 在 K3s 服务器上生成 kubeconfig：

```bash
# 在K3s服务器上执行
sudo cat /etc/rancher/k3s/k3s.yaml
```

2. 将输出内容保存为 kubeconfig.yaml 文件

3. 将 kubeconfig 内容进行 base64 编码：

```bash
cat kubeconfig.yaml | base64 -w 0
```

### 步骤 3: 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

1. **TENCENT_REGISTRY_USERNAME**: 腾讯云 CCR 用户名
2. **TENCENT_REGISTRY_PASSWORD**: 腾讯云 CCR 密码
3. **KUBE_CONFIG**: base64 编码后的 kubeconfig 内容

### 步骤 4: 创建镜像拉取密钥

在 K3s 集群中创建镜像拉取密钥：

```bash
kubectl create secret docker-registry tencent-registry-secret \
  --docker-server=ccr.ccs.tencentyun.com \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-email=<your-email> \
  -n frps
```

### 步骤 5: 验证配置

1. 推送代码到 main 分支
2. 检查 GitHub Actions 是否自动触发
3. 查看构建和部署日志
4. 验证 K3s 集群中的部署状态

## 工作流程说明

### 触发条件

- 推送到 main/master 分支
- 创建 Pull Request

### 执行步骤

1. **代码检出**: 从 GitHub 检出最新代码
2. **Docker 构建**: 构建 FRPS Docker 镜像
3. **镜像推送**: 推送到腾讯云 CCR
4. **K8s 部署**: 更新并应用 Kubernetes 配置
5. **健康检查**: 验证部署状态和日志

### 镜像标签策略

- `latest`: 主分支的最新版本
- `main-<commit-sha>`: 基于 commit SHA 的标签
- `pr-<number>`: Pull Request 标签

## 故障排除

### 常见问题

1. **镜像推送失败**

   - 检查腾讯云 CCR 凭证
   - 确认镜像仓库权限

2. **Kubernetes 部署失败**

   - 检查 kubeconfig 配置
   - 确认集群资源是否充足
   - 查看 Pod 事件和日志

3. **服务无法访问**
   - 检查 Service 和 Ingress 配置
   - 确认防火墙规则
   - 验证网络策略

### 调试命令

```bash
# 查看Pod状态
kubectl get pods -n frps -o wide

# 查看Pod日志
kubectl logs -n frps deployment/frps

# 查看Pod事件
kubectl describe pod -n frps <pod-name>

# 查看服务状态
kubectl get svc -n frps

# 查看部署状态
kubectl get deployment -n frps
```

## 安全注意事项

1. **凭证管理**

   - 定期轮换腾讯云 CCR 密码
   - 使用最小权限原则
   - 避免在代码中硬编码敏感信息

2. **网络安全**

   - 限制 K3s API 访问
   - 使用 VPN 或内网访问
   - 配置防火墙规则

3. **镜像安全**
   - 定期更新基础镜像
   - 扫描镜像漏洞
   - 使用可信的基础镜像

## 监控和维护

### 监控指标

- 部署成功率
- 构建时间
- 镜像大小
- 服务响应时间

### 维护任务

- 定期清理旧镜像
- 更新依赖包
- 备份配置文件
- 监控资源使用情况
