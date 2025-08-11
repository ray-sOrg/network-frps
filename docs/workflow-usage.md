# GitHub Actions 工作流使用说明

## 概述

本项目包含两个 GitHub Actions 工作流文件，分别用于不同的场景：

1. **`deploy.yml`** - 完整构建和部署工作流
2. **`build-only.yml`** - 仅构建工作流（用于 Pull Request）

## 工作流详解

### 1. deploy.yml - 完整构建和部署工作流

#### 触发条件

- **推送到 main/master 分支**：自动触发完整的构建和部署流程

#### 执行步骤

1. **代码检出** - 从 GitHub 检出最新代码
2. **Docker 构建** - 构建 FRPS Docker 镜像
3. **镜像推送** - 推送到腾讯云 CCR 镜像仓库
4. **K3s 部署** - 使用 deploy.sh 脚本部署到 K3s 集群
5. **部署验证** - 验证 Pod 状态、服务状态、部署状态
6. **功能测试** - 测试 FRPS 服务是否正常工作
7. **清理工作** - 清理临时文件和敏感信息
8. **结果通知** - 显示部署结果和相关信息

#### 使用场景

- 代码合并到主分支后自动部署
- 生产环境更新
- 功能发布

### 2. build-only.yml - 仅构建工作流

#### 触发条件

- **创建 Pull Request**：到 main/master 分支时自动触发

#### 执行步骤

1. **代码检出** - 从 GitHub 检出 PR 代码
2. **Docker 构建** - 构建 FRPS Docker 镜像（不推送）
3. **构建验证** - 验证镜像构建是否成功
4. **结果通知** - 显示构建结果

#### 使用场景

- 代码审查阶段验证构建
- 确保 PR 代码可以正常构建
- 提前发现构建问题

## 工作流配置说明

### 环境变量配置

```yaml
env:
  REGISTRY: ccr.ccs.tencentyun.com # 腾讯云CCR地址
  IMAGE_NAME: ray321/frps # 镜像名称
  KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }} # K3s集群配置
```

### 镜像标签策略

#### deploy.yml 标签策略

- `latest` - 主分支最新版本
- `main-<commit-sha>` - 基于 commit SHA 的版本标签
- `branch-<commit-sha>` - 基于分支和 commit 的标签

#### build-only.yml 标签策略

- `pr-<number>` - Pull Request 编号标签
- `pr-<commit-sha>` - 基于 commit SHA 的 PR 标签

## 使用流程

### 开发工作流

1. **创建功能分支**

   ```bash
   git checkout -b feature/new-feature
   ```

2. **开发并提交代码**

   ```bash
   git add .
   git commit -m "feat: 添加新功能"
   git push origin feature/new-feature
   ```

3. **创建 Pull Request**

   - 在 GitHub 上创建 PR 到 main 分支
   - 自动触发 build-only.yml 工作流
   - 验证代码可以正常构建

4. **代码审查和合并**
   - 审查代码并通过
   - 合并到 main 分支
   - 自动触发 deploy.yml 工作流
   - 自动部署到 K3s 集群

### 直接部署流程

1. **直接推送到 main 分支**

   ```bash
   git checkout main
   git pull origin main
   git add .
   git commit -m "feat: 直接部署新功能"
   git push origin main
   ```

2. **自动触发部署**
   - 自动构建 Docker 镜像
   - 自动推送到腾讯云 CCR
   - 自动部署到 K3s 集群

## 监控和调试

### 查看工作流状态

1. **GitHub Actions 页面**

   - 进入仓库的 Actions 标签页
   - 查看工作流执行历史
   - 查看详细执行日志

2. **工作流执行详情**
   - 点击具体的工作流执行
   - 查看每个步骤的执行状态
   - 查看详细日志输出

### 常见问题排查

#### 构建失败

- 检查 Dockerfile 语法
- 检查依赖包版本
- 查看构建日志中的错误信息

#### 部署失败

- 检查 K3s 集群连接
- 验证 kubeconfig 配置
- 查看 Pod 事件和日志

#### 镜像推送失败

- 检查腾讯云 CCR 凭证
- 确认镜像仓库权限
- 验证网络连接

## 安全注意事项

### 凭证管理

- 所有敏感信息都通过 GitHub Secrets 管理
- 定期轮换腾讯云 CCR 密码
- 使用最小权限原则

### 网络安全

- K3s 集群访问通过 kubeconfig 控制
- 镜像仓库访问通过临时凭证
- 避免在代码中硬编码敏感信息

## 自定义配置

### 修改触发条件

```yaml
on:
  push:
    branches: [main, master, develop] # 添加更多分支
  pull_request:
    branches: [main, master, develop] # 添加更多分支
```

### 修改构建参数

```yaml
build-args: |
  BUILD_DATE=${{ github.event.head_commit.timestamp }}
  VCS_REF=${{ github.sha }}
  VERSION=${{ github.ref_name }}
  CUSTOM_VAR=value  # 添加自定义变量
```

### 修改部署配置

```yaml
env:
  NAMESPACE: frps-prod # 修改命名空间
  REGISTRY: your-registry.com # 修改镜像仓库
```

## 最佳实践

1. **分支管理**

   - 使用功能分支开发新功能
   - 通过 Pull Request 进行代码审查
   - 主分支保持稳定

2. **提交信息**

   - 使用清晰的提交信息
   - 遵循约定式提交规范
   - 包含功能描述和影响范围

3. **测试策略**

   - 在 PR 阶段进行构建测试
   - 在合并后进行完整部署测试
   - 定期进行功能验证

4. **监控告警**
   - 关注工作流执行状态
   - 设置失败通知
   - 定期检查部署状态
