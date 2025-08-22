# FRPS 网页代理访问 - 简化指南

## 概述

通过 Ingress 配置，你可以直接通过网页访问 frps 代理的本地服务：

- **PVE 管理界面**: `https://tx.ray321.cn/pve`
- **iKuai 管理界面**: `https://tx.ray321.cn/ikuai`
- **iStoreOS 管理界面**: `https://tx.ray321.cn/istoreos`
- **FRPS 管理面板**: `https://tx.ray321.cn/frps`

## 工作原理

### 网络流程

1. **用户访问**: `https://tx.ray321.cn/pve`
2. **Ingress 路由**: 将请求路由到 `frps-service:6001`
3. **frps 转发**: 将流量转发到本地 PVE 服务 (192.168.31.254:8006)
4. **响应返回**: 通过相同路径返回给用户

### 端口映射

| 服务     | 访问路径    | Service 端口 | 本地端口 | frpc 配置         |
| -------- | ----------- | ------------ | -------- | ----------------- |
| PVE      | `/pve`      | 6001         | 8006     | remote_port: 6001 |
| iKuai    | `/ikuai`    | 6002         | 80       | remote_port: 6002 |
| iStoreOS | `/istoreos` | 6003         | 80       | remote_port: 6003 |

## 配置说明

### 1. frpc 配置（保持不变）

你的 frpc 配置不需要任何修改：

```ini
config conf 'pve'
        option name 'pve'
        option type 'tcp'
        option local_ip '192.168.31.254'
        option local_port '8006'
        option remote_port '6001'

config conf 'ikuai'
        option name 'ikuai'
        option type 'tcp'
        option local_ip '192.168.31.1'
        option local_port '80'
        option remote_port '6002'

config conf 'istoreos'
        option name 'istoreos'
        option type 'tcp'
        option local_ip '192.168.31.2'
        option local_port '80'
        option remote_port '6003'
```

### 2. Kubernetes 配置

#### Ingress 配置（分离式设计）

我们使用两个独立的 Ingress 来避免配置冲突：

**frps-dashboard-ingress** (用于管理面板):

```yaml
spec:
  rules:
    - host: tx.ray321.cn
      http:
        paths:
          - path: /frps(/|$)(.*)
            backend:
              service:
                name: frps-service
                port:
                  number: 7500
```

**frps-proxy-ingress** (用于代理服务):

```yaml
spec:
  rules:
    - host: tx.ray321.cn
      http:
        paths:
          - path: /pve(/|$)(.*)
            backend:
              service:
                name: frps-service
                port:
                  number: 6001
          - path: /ikuai(/|$)(.*)
            backend:
              service:
                name: frps-service
                port:
                  number: 6002
          - path: /istoreos(/|$)(.*)
            backend:
              service:
                name: frps-service
                port:
                  number: 6003
```

#### Service 配置

```yaml
spec:
  type: ClusterIP # 只允许集群内部访问
  ports:
    - name: pve-port
      port: 6001
      targetPort: 6001
    - name: ikuai-port
      port: 6002
      targetPort: 6002
    - name: istoreos-port
      port: 6003
      targetPort: 6003
```

## 部署步骤

### 1. 检查配置

```bash
# 运行配置检查脚本
chmod +x scripts/test-config.sh
./scripts/test-config.sh
```

### 2. 构建镜像

```bash
docker build -t ccr.ccs.tencentyun.com/ray321/frps:latest .
docker push ccr.ccs.tencentyun.com/ray321/frps:latest
```

### 3. 部署到 Kubernetes

```bash
# 应用配置
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/ingress.yaml
```

### 4. 验证部署

```bash
# 检查服务状态
kubectl get pods,services,ingress -n frps-system

# 测试访问
curl -I https://tx.ray321.cn/pve
curl -I https://tx.ray321.cn/ikuai
curl -I https://tx.ray321.cn/istoreos
```

## 配置修复说明

### 修复的问题

1. **Ingress 配置冲突**: 将 frps dashboard 和代理服务分离为两个独立的 Ingress
2. **路径重写问题**: 代理服务不再使用路径重写，避免连接问题
3. **frps.ini 重复配置**: 移除了重复的 `max_pool_count` 配置
4. **Service 类型优化**: 使用 ClusterIP 类型，简化配置

### 设计优势

1. **配置分离**: Dashboard 和代理服务使用不同的 Ingress，避免配置冲突
2. **简化代理**: 代理服务直接转发，不进行路径重写
3. **向后兼容**: 保持原有的 frps dashboard 功能不变
4. **易于维护**: 配置清晰，便于调试和更新

## 常见问题

### Q: 为什么使用两个 Ingress？

A: 因为 frps dashboard 需要特殊的路径重写规则，而代理服务不需要。分离配置可以避免冲突。

### Q: frpc 配置需要修改吗？

A: 不需要！你的 frpc 配置保持不变，只需要确保 frps 支持 6001-6003 端口即可。

### Q: 如果某个服务无法访问怎么办？

A: 检查以下几点：

1. frpc 客户端是否正常运行
2. 本地服务是否可访问
3. frps 日志中是否有错误信息
4. Ingress 配置是否正确

### Q: 如何添加更多服务？

A: 只需要：

1. 在 frpc 中添加新的配置
2. 在 Service 中添加新的端口
3. 在 frps-proxy-ingress 中添加新的路径规则

## 优势

1. **简单**: 只需要通过 URL 访问，无需记住端口号
2. **安全**: 通过 HTTPS 访问，支持 SSL 证书
3. **统一**: 所有服务通过同一个域名访问
4. **易维护**: 配置集中管理，便于更新
5. **稳定**: 分离式设计，避免配置冲突
