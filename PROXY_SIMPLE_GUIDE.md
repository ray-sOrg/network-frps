# FRPS 网页代理访问 - 三级域名指南

## 概述

通过 Ingress 配置，你可以直接通过三级域名访问 frps 代理的本地服务：

- **FRPS 管理面板**: `https://frps.tx.ray321.cn`
- **PVE 管理界面**: `https://pve.tx.ray321.cn`
- **iKuai 管理界面**: `https://ikuai.tx.ray321.cn`
- **iStoreOS 管理界面**: `https://istoreos.tx.ray321.cn`

## 工作原理

### 网络流程

1. **用户访问**: `https://pve.tx.ray321.cn`
2. **Ingress 路由**: 将请求路由到 `frps-service:6001`
3. **frps 转发**: 将流量转发到本地 PVE 服务 (192.168.31.254:8006)
4. **响应返回**: 通过相同域名返回给用户

### 端口映射

| 服务     | 访问域名                | Service 端口 | 本地端口 | frpc 配置         |
| -------- | ----------------------- | ------------ | -------- | ----------------- |
| PVE      | `pve.tx.ray321.cn`      | 6001         | 8006     | remote_port: 6001 |
| iKuai    | `ikuai.tx.ray321.cn`    | 6002         | 80       | remote_port: 6002 |
| iStoreOS | `istoreos.tx.ray321.cn` | 6003         | 80       | remote_port: 6003 |

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

#### Ingress 配置（三级域名方式）

每个服务使用独立的三级域名：

```yaml
# FRPS Dashboard
spec:
  rules:
    - host: frps.tx.ray321.cn
      http:
        paths:
          - path: /
            backend:
              service:
                name: frps-service
                port:
                  number: 7500

# PVE 管理界面
spec:
  rules:
    - host: pve.tx.ray321.cn
      http:
        paths:
          - path: /
            backend:
              service:
                name: frps-service
                port:
                  number: 6001

# iKuai 管理界面
spec:
  rules:
    - host: ikuai.tx.ray321.cn
      http:
        paths:
          - path: /
            backend:
              service:
                name: frps-service
                port:
                  number: 6002

# iStoreOS 管理界面
spec:
  rules:
    - host: istoreos.tx.ray321.cn
      http:
        paths:
          - path: /
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
    - name: dashboard-port
      port: 7500
      targetPort: 7500
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
kubectl get pods,services,ingress -n frps

# 测试访问
curl -I https://frps.tx.ray321.cn
curl -I https://pve.tx.ray321.cn
curl -I https://ikuai.tx.ray321.cn
curl -I https://istoreos.tx.ray321.cn
```

## 配置优势

### 设计优势

1. **配置清晰**: 每个服务使用独立域名，避免配置冲突
2. **易于维护**: 配置结构简单，便于调试和更新
3. **向后兼容**: 保持原有的 frps dashboard 功能不变
4. **扩展性好**: 新增服务只需添加新的域名和端口映射

### 三级域名的好处

1. **完全隔离**: 每个服务使用独立域名，无路径冲突
2. **静态资源正确**: 所有静态资源都能正确加载
3. **易于扩展**: 新增服务只需添加新域名
4. **DNS 配置简单**: 使用通配符解析，一次配置永久有效
5. **符合标准**: 使用标准的子域名访问方式

## 常见问题

### Q: 为什么使用三级域名而不是路径？

A: 三级域名方式有以下优势：

- 避免路径重写问题
- 静态资源加载更稳定
- 配置更清晰，易于维护
- 符合标准的域名访问方式

### Q: frpc 配置需要修改吗？

A: 不需要！你的 frpc 配置保持不变，只需要确保 frps 支持 6001-6003 端口即可。

### Q: 如果某个服务无法访问怎么办？

A: 检查以下几点：

1. frpc 客户端是否正常运行
2. 本地服务是否可访问
3. frps 日志中是否有错误信息
4. Ingress 配置是否正确
5. 域名解析是否正确

### Q: 如何添加更多服务？

A: 只需要：

1. 在 frpc 中添加新的配置
2. 在 Service 中添加新的端口
3. 在 Ingress 中添加新的域名规则

### Q: 重定向次数过多怎么办？

A: 这通常是由于配置不一致导致的：

1. 检查 frps.ini 和 configmap.yaml 是否一致
2. 确保没有重复的域名配置
3. 重启 Pod 应用新配置
4. 检查 Ingress 规则是否正确

## 优势总结

1. **简单**: 只需要通过域名访问，无需记住端口号
2. **安全**: 通过 HTTPS 访问，支持 SSL 证书
3. **统一**: 所有服务通过统一的域名结构访问
4. **易维护**: 配置集中管理，便于更新
5. **稳定**: 三级域名设计，避免配置冲突
6. **专业**: 使用标准的域名访问方式，更专业

## 升级说明

如果你之前使用的是路径方式（如 `tx.ray321.cn/frps`），升级到三级域名方式：

1. **更新配置文件**: 确保所有配置文件使用新的域名结构
2. **重启服务**: 应用新配置后重启 Pod
3. **更新 DNS**: 确保所有三级域名都正确解析
4. **测试访问**: 逐一测试所有新的域名访问

---

**现在你的配置已经完全更新为三级域名方式！** 🚀
