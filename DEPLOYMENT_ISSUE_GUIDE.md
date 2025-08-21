# 🚨 部署问题排查指南

## 🔍 当前问题分析

**错误信息**:

```
The Secret "tencent-registry-secret" is invalid: data[.dockerconfigjson]: Invalid value: "<secret contents redacted>": unexpected end of JSON input
```

**根本原因**: 缺少必要的 GitHub Secrets 环境变量

## 🛠️ 立即修复步骤

### 步骤 1: 配置 GitHub Secrets

1. 进入你的 GitHub 仓库
2. 点击 `Settings` 标签
3. 在左侧菜单中点击 `Secrets and variables` → `Actions`
4. 点击 `New repository secret` 按钮
5. 添加以下两个 Secrets：

#### Secret 1: `TENCENT_REGISTRY_USERNAME`

- **Name**: `TENCENT_REGISTRY_USERNAME`
- **Value**: 你的腾讯云镜像服务用户名（通常是腾讯云账号 ID）

#### Secret 2: `TENCENT_REGISTRY_PASSWORD`

- **Name**: `TENCENT_REGISTRY_PASSWORD`
- **Value**: 你的腾讯云镜像服务密码

### 步骤 2: 获取腾讯云镜像服务认证信息

#### 方法 1: 腾讯云控制台

1. 登录 [腾讯云控制台](https://console.cloud.tencent.com/)
2. 进入 `容器镜像服务` → `实例列表`
3. 选择你的镜像仓库实例
4. 点击 `访问凭证` 标签
5. 复制用户名和密码

#### 方法 2: 命令行获取

```bash
# 如果你有腾讯云CLI工具
tccli tcr DescribeInstanceToken --InstanceId <你的实例ID>
```

### 步骤 3: 重新触发部署

配置完 Secrets 后，重新推送代码或手动触发 GitHub Actions：

```bash
# 方法1: 推送代码
git commit --allow-empty -m "Retry deployment with fixed secrets"
git push origin main

# 方法2: 在GitHub网页上手动触发
# 进入 Actions 标签 → 选择工作流 → 点击 "Run workflow"
```

## 🔍 问题排查清单

### ✅ 检查项 1: GitHub Secrets 配置

- [ ] `TENCENT_REGISTRY_USERNAME` 已设置
- [ ] `TENCENT_REGISTRY_PASSWORD` 已设置
- [ ] 值不为空且格式正确

### ✅ 检查项 2: 腾讯云镜像服务状态

- [ ] 镜像服务实例正常运行
- [ ] 用户有推送和拉取权限
- [ ] 网络连通性正常

### ✅ 检查项 3: 仓库权限

- [ ] GitHub Actions 有权限访问 Secrets
- [ ] 仓库设置中启用了 Actions

## 🚀 验证修复结果

### 1. 查看 GitHub Actions 日志

- 进入 `Actions` 标签
- 查看最新的工作流运行
- 确认没有认证相关错误

### 2. 检查部署状态

```bash
# 在你的K3s服务器上执行
kubectl get pods -n frps
kubectl get secret -n frps
kubectl describe secret tencent-registry-secret -n frps
```

### 3. 验证镜像拉取

```bash
# 检查Pod状态
kubectl get pods -n frps -o wide

# 查看Pod事件
kubectl describe pod -n frps -l app=frps

# 查看Pod日志
kubectl logs -n frps deployment/frps
```

## 🆘 如果问题仍然存在

### 1. 检查 Secrets 值格式

确保 Secrets 值没有多余的空格、换行符或特殊字符

### 2. 验证腾讯云认证

```bash
# 手动测试镜像拉取
docker login ccr.ccs.tencentyun.com
# 输入用户名和密码
docker pull ccr.ccs.tencentyun.com/ray321/frps:latest
```

### 3. 检查网络连通性

```bash
# 测试网络连接
ping ccr.ccs.tencentyun.com
telnet ccr.ccs.tencentyun.com 443
```

### 4. 查看详细错误日志

```bash
# 在GitHub Actions中查看完整日志
# 特别关注 "Create registry secret" 步骤的输出
```

## 📋 常见问题解决方案

### 问题 1: "authentication required"

**原因**: 认证信息错误或过期
**解决**: 重新获取并更新 Secrets

### 问题 2: "unauthorized"

**原因**: 用户权限不足
**解决**: 检查腾讯云镜像服务用户权限

### 问题 3: "connection refused"

**原因**: 网络连通性问题
**解决**: 检查防火墙和网络配置

## 🎯 预防措施

### 1. 定期更新认证信息

- 定期更换腾讯云镜像服务密码
- 监控认证过期时间

### 2. 监控部署状态

- 设置部署失败通知
- 定期检查服务健康状态

### 3. 备份配置

- 备份重要的配置文件
- 记录部署步骤和配置

## 📞 获取更多帮助

如果以上步骤无法解决问题：

1. **收集错误信息**: 完整的 GitHub Actions 日志
2. **检查系统状态**: K3s 集群和腾讯云服务状态
3. **提交 Issue**: 在 GitHub 仓库中创建 Issue
4. **社区支持**: 在相关技术社区寻求帮助

## 🎉 成功标志

修复成功后，你应该看到：

- ✅ GitHub Actions 成功完成
- ✅ 镜像成功推送到腾讯云
- ✅ K3s 集群成功部署 FRPS
- ✅ 服务正常运行并可访问

---

**记住**: 配置 GitHub Secrets 是解决当前问题的关键！🔑
