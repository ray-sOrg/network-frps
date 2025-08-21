# 🔍 FRPS 故障排查指南

本指南帮助你解决 FRPS 部署过程中可能遇到的各种问题。

## 🚨 紧急问题排查

### 1. 服务完全无法访问

**症状**: 无法通过任何方式访问 FRPS 服务

**快速检查**:

```bash
# 检查Pod状态
kubectl get pods -n frps

# 检查服务状态
kubectl get svc -n frps

# 检查节点状态
kubectl get nodes
```

**常见原因**:

- Pod 未启动或崩溃
- 服务配置错误
- 网络策略问题
- 资源不足

### 2. 镜像拉取失败

**症状**: Pod 状态为 `ImagePullBackOff` 或 `ErrImagePull`

**检查命令**:

```bash
# 查看Pod详细信息
kubectl describe pod -n frps -l app=frps

# 查看事件
kubectl get events -n frps --sort-by='.lastTimestamp'
```

**解决方案**:

1. 检查镜像仓库认证
2. 验证镜像是否存在
3. 检查网络连通性

## 🔧 分步骤排查

### 步骤 1: 检查基础设施

#### 1.1 K3s 集群状态

```bash
# 检查集群状态
kubectl cluster-info

# 检查节点状态
kubectl get nodes -o wide

# 检查系统资源
kubectl top nodes
```

**预期结果**: 所有节点状态为 `Ready`，资源使用率正常

#### 1.2 网络连通性

```bash
# 检查集群内网络
kubectl run test-connectivity --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# 检查外部网络
kubectl run test-external --image=busybox --rm -it --restart=Never -- wget -qO- http://www.baidu.com
```

**预期结果**: 网络连通性正常

### 步骤 2: 检查应用部署

#### 2.1 命名空间状态

```bash
# 检查命名空间
kubectl get namespace frps

# 检查命名空间中的资源
kubectl get all -n frps
```

**预期结果**: 命名空间存在且状态为 `Active`

#### 2.2 Pod 状态检查

```bash
# 查看Pod状态
kubectl get pods -n frps -o wide

# 查看Pod详细信息
kubectl describe pod -n frps -l app=frps

# 查看Pod日志
kubectl logs -n frps -l app=frps
```

**常见 Pod 状态及解决方案**:

| Pod 状态            | 含义         | 解决方案               |
| ------------------- | ------------ | ---------------------- |
| `Pending`           | 等待调度     | 检查节点资源、污点设置 |
| `ContainerCreating` | 创建容器中   | 等待或检查镜像拉取     |
| `Running`           | 运行中       | 正常状态               |
| `CrashLoopBackOff`  | 容器崩溃重启 | 查看日志排查配置问题   |
| `ImagePullBackOff`  | 镜像拉取失败 | 检查镜像仓库认证       |
| `ErrImagePull`      | 镜像拉取错误 | 检查镜像地址和权限     |

#### 2.3 服务配置检查

```bash
# 查看服务配置
kubectl get svc -n frps -o wide

# 查看服务详细信息
kubectl describe svc -n frps

# 测试服务连通性
kubectl run test-service --image=busybox --rm -it --restart=Never -- wget -qO- frps-service:7000
```

**预期结果**: 服务类型正确，端口映射正常

### 步骤 3: 检查配置和 Secret

#### 3.1 ConfigMap 检查

```bash
# 查看ConfigMap
kubectl get configmap -n frps

# 查看配置内容
kubectl get configmap frps-config -n frps -o yaml

# 验证配置语法
kubectl exec -n frps deployment/frps -- frps -c /etc/frp/frps.ini --test
```

**常见问题**:

- 配置文件语法错误
- 端口冲突
- 权限配置不当

#### 3.2 Secret 检查

```bash
# 查看Secret
kubectl get secret -n frps

# 检查Secret类型
kubectl describe secret -n frps

# 验证镜像仓库认证
kubectl get secret tencent-registry-secret -n frps -o yaml
```

**常见问题**:

- 认证信息过期
- 权限不足
- 配置格式错误

### 步骤 4: 检查网络和防火墙

#### 4.1 端口连通性

```bash
# 在K3s节点上检查端口
netstat -tlnp | grep -E "(30000|30001)"

# 检查防火墙规则
iptables -L -n | grep -E "(30000|30001)"

# 测试端口连通性
telnet localhost 30000
telnet localhost 30001
```

#### 4.2 外部访问测试

```bash
# 从外部测试端口
nc -zv <你的服务器IP> 30000
nc -zv <你的服务器IP> 30001

# 使用curl测试HTTP服务
curl -v http://<你的服务器IP>:30001
```

## 🐛 常见问题及解决方案

### 问题 1: Pod 启动失败

**错误信息**: `CrashLoopBackOff`

**排查步骤**:

```bash
# 查看Pod日志
kubectl logs -n frps deployment/frps --previous

# 查看Pod事件
kubectl describe pod -n frps -l app=frps

# 检查配置文件
kubectl exec -n frps deployment/frps -- cat /etc/frp/frps.ini
```

**常见原因**:

- 配置文件语法错误
- 端口被占用
- 权限不足
- 资源限制过严

**解决方案**:

1. 修复配置文件语法
2. 检查端口占用情况
3. 调整资源限制
4. 检查文件权限

### 问题 2: 服务无法访问

**错误信息**: 连接超时或拒绝连接

**排查步骤**:

```bash
# 检查服务状态
kubectl get svc -n frps

# 检查Pod状态
kubectl get pods -n frps

# 测试集群内访问
kubectl run test-access --image=busybox --rm -it --restart=Never -- wget -qO- frps-service:7000
```

**常见原因**:

- Pod 未就绪
- 服务配置错误
- 网络策略限制
- 防火墙阻止

**解决方案**:

1. 确保 Pod 正常运行
2. 检查服务配置
3. 配置网络策略
4. 调整防火墙规则

### 问题 3: 镜像拉取失败

**错误信息**: `ImagePullBackOff` 或 `ErrImagePull`

**排查步骤**:

```bash
# 查看Pod事件
kubectl get events -n frps --sort-by='.lastTimestamp'

# 检查镜像仓库认证
kubectl get secret tencent-registry-secret -n frps -o yaml

# 手动测试镜像拉取
docker pull ccr.ccs.tencentyun.com/ray321/frps:latest
```

**常见原因**:

- 认证信息过期
- 镜像不存在
- 网络连通性问题
- 权限不足

**解决方案**:

1. 更新认证信息
2. 确认镜像存在
3. 检查网络配置
4. 验证用户权限

### 问题 4: 配置更新不生效

**错误信息**: 配置修改后服务行为未改变

**排查步骤**:

```bash
# 检查ConfigMap是否更新
kubectl get configmap frps-config -n frps -o yaml

# 检查Pod是否重启
kubectl get pods -n frps -o wide

# 查看Pod中的配置
kubectl exec -n frps deployment/frps -- cat /etc/frp/frps.ini
```

**常见原因**:

- ConfigMap 未更新
- Pod 未重启
- 配置挂载错误
- 缓存问题

**解决方案**:

1. 强制更新 ConfigMap
2. 重启 Pod
3. 检查卷挂载配置
4. 清除缓存

## 🔍 高级排查技巧

### 1. 使用调试容器

```bash
# 创建调试Pod
kubectl run debug-pod --image=busybox --rm -it --restart=Never -- sh

# 在调试Pod中测试网络
nslookup frps-service
wget -qO- frps-service:7000
```

### 2. 实时监控

```bash
# 监控Pod状态变化
kubectl get pods -n frps -w

# 监控事件
kubectl get events -n frps -w

# 监控日志
kubectl logs -f -n frps deployment/frps
```

### 3. 资源使用分析

```bash
# 查看资源使用情况
kubectl top pods -n frps
kubectl top nodes

# 查看资源限制
kubectl describe pod -n frps -l app=frps | grep -A 10 "Limits:"
```

## 📊 健康检查清单

使用以下清单快速评估部署状态：

- [ ] K3s 集群正常运行
- [ ] 命名空间创建成功
- [ ] Pod 状态为 Running
- [ ] 服务配置正确
- [ ] 端口可访问
- [ ] 配置文件有效
- [ ] 认证信息正确
- [ ] 网络连通性正常
- [ ] 资源使用合理
- [ ] 日志无错误

## 🆘 获取更多帮助

如果以上排查步骤无法解决问题：

1. **收集诊断信息**:

   ```bash
   # 运行检查脚本
   ./scripts/check.sh

   # 收集集群信息
   kubectl cluster-info dump > cluster-dump.yaml

   # 收集Pod信息
   kubectl get all -n frps -o yaml > frps-dump.yaml
   ```

2. **查看官方文档**: [FRP 官方文档](https://gofrp.org/docs/)

3. **提交 Issue**: 在 GitHub 仓库中创建 Issue，附上详细的错误信息和诊断结果

4. **社区支持**: 在相关技术社区寻求帮助

## 📝 故障记录模板

记录故障信息有助于快速定位问题：

```
故障时间: [YYYY-MM-DD HH:MM:SS]
故障现象: [描述具体问题]
影响范围: [影响的服务和用户]
排查步骤: [已尝试的排查方法]
错误信息: [具体的错误日志]
解决方案: [最终解决方法]
预防措施: [避免再次发生的建议]
```
