# 🔍 环境变量调试指南

## 🚨 当前问题

你已经正确设置了 GitHub Secrets，但部署脚本仍然无法获取到环境变量。

## 🔧 已修复的问题

### 1. **GitHub Actions 工作流修复** ✅

我已经修复了 `.github/workflows/deploy.yml` 文件，现在会正确传递环境变量：

```yaml
# 步骤8：执行部署脚本
- name: Execute deployment script
  run: |
    # 设置环境变量
    export KUBECONFIG=kubeconfig.yaml
    export REGISTRY="${{ env.REGISTRY }}"
    export IMAGE_NAME="${{ env.IMAGE_NAME }}"
    export IMAGE_TAG="latest"
    export NAMESPACE="frps"

    # 传递腾讯云镜像仓库认证环境变量
    export TENCENT_REGISTRY_USERNAME="${{ secrets.TENCENT_REGISTRY_USERNAME }}"
    export TENCENT_REGISTRY_PASSWORD="${{ secrets.TENCENT_REGISTRY_PASSWORD }}"

    # 可选：传递FRP配置环境变量
    export FRP_DASHBOARD_PWD="${{ secrets.FRP_DASHBOARD_PWD }}"
    export FRP_TOKEN="${{ secrets.FRP_TOKEN }}"

    # 执行部署脚本
    ./scripts/deploy.sh
```

### 2. **部署脚本调试增强** ✅

在 `scripts/deploy.sh` 开头添加了环境变量调试信息，会显示所有环境变量的状态。

## 🚀 立即测试步骤

### 步骤 1: 推送修复后的代码

```bash
git add .
git commit -m "Fix GitHub Actions environment variables passing"
git push origin main
```

### 步骤 2: 监控 GitHub Actions 执行

1. 进入 GitHub 仓库 → `Actions` 标签
2. 查看最新的工作流运行
3. 特别关注 "Execute deployment script" 步骤

### 步骤 3: 查看调试输出

在部署脚本执行时，你应该看到类似这样的输出：

```
[INFO] === 环境变量调试信息 ===
[INFO] REGISTRY: ccr.ccs.tencentyun.com
[INFO] IMAGE_NAME: ray321/frps
[INFO] IMAGE_TAG: latest
[INFO] NAMESPACE: frps
[INFO] KUBECONFIG: kubeconfig.yaml
[INFO] TENCENT_REGISTRY_USERNAME: 已设置
[INFO] TENCENT_REGISTRY_PASSWORD: 已设置
[INFO] FRP_DASHBOARD_PWD: 已设置
[INFO] FRP_TOKEN: 已设置
[INFO] ==========================
```

## 🔍 如果问题仍然存在

### 检查项 1: GitHub Secrets 名称

确保 Secrets 名称完全匹配（区分大小写）：

- ✅ `TENCENT_REGISTRY_USERNAME`
- ✅ `TENCENT_REGISTRY_PASSWORD`
- ✅ `KUBE_CONFIG`

### 检查项 2: Secrets 值格式

- 确保值没有多余的空格
- 确保值不为空
- 确保没有特殊字符

### 检查项 3: 仓库权限

- 确保 GitHub Actions 有权限访问 Secrets
- 确保仓库设置中启用了 Actions

## 🧪 手动测试环境变量

### 在 GitHub Actions 中添加测试步骤

```yaml
- name: Test environment variables
  run: |
    echo "Testing environment variables:"
    echo "TENCENT_REGISTRY_USERNAME: ${TENCENT_REGISTRY_USERNAME:+已设置}"
    echo "TENCENT_REGISTRY_PASSWORD: ${TENCENT_REGISTRY_PASSWORD:+已设置}"
    echo "KUBE_CONFIG: ${KUBE_CONFIG:+已设置}"

    # 测试Secrets是否可访问
    if [ -n "$TENCENT_REGISTRY_USERNAME" ]; then
      echo "✅ TENCENT_REGISTRY_USERNAME 可访问"
    else
      echo "❌ TENCENT_REGISTRY_USERNAME 不可访问"
    fi

    if [ -n "$TENCENT_REGISTRY_PASSWORD" ]; then
      echo "✅ TENCENT_REGISTRY_PASSWORD 可访问"
    else
      echo "❌ TENCENT_REGISTRY_PASSWORD 不可访问"
    fi
```

## 📋 问题排查清单

### ✅ 已确认的配置

- [ ] GitHub Secrets 已正确设置
- [ ] 工作流已修复环境变量传递
- [ ] 部署脚本已添加调试信息

### 🔍 需要验证的步骤

- [ ] 推送修复后的代码
- [ ] 监控 GitHub Actions 执行
- [ ] 查看调试输出
- [ ] 确认环境变量状态

## 🎯 预期结果

修复成功后，你应该看到：

1. **环境变量调试信息正常显示**
2. **所有必要的环境变量都标记为"已设置"**
3. **部署脚本成功创建镜像仓库认证 Secret**
4. **整个部署流程顺利完成**

## 🆘 如果仍然失败

### 收集调试信息

1. 完整的 GitHub Actions 日志
2. 环境变量调试输出
3. 具体的错误信息

### 可能的解决方案

1. **重新创建 Secrets**: 删除并重新创建 GitHub Secrets
2. **检查仓库设置**: 确认 Actions 权限配置
3. **验证 Secrets 值**: 手动测试 Secrets 是否可访问

---

**关键**: 现在环境变量应该能正确传递了！推送代码测试一下。🚀
