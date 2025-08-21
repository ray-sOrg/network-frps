#!/bin/bash

set -e
source "$(dirname "$0")/common.sh"

# 配置变量
REGISTRY=${REGISTRY:-"ccr.ccs.tencentyun.com"}
IMAGE_NAME=${IMAGE_NAME:-"ray321/frps"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}
NAMESPACE=${NAMESPACE:-"frps"}
KUBECONFIG=${KUBECONFIG:-"kubeconfig.yaml"}

# 调试信息：显示环境变量状态
log_info "=== 环境变量调试信息 ==="
log_info "REGISTRY: $REGISTRY"
log_info "IMAGE_NAME: $IMAGE_NAME"
log_info "IMAGE_TAG: $IMAGE_TAG"
log_info "NAMESPACE: $NAMESPACE"
log_info "KUBECONFIG: $KUBECONFIG"
log_info "TENCENT_REGISTRY_USERNAME: ${TENCENT_REGISTRY_USERNAME:+已设置}"
log_info "TENCENT_REGISTRY_PASSWORD: ${TENCENT_REGISTRY_PASSWORD:+已设置}"
log_info "FRP_DASHBOARD_PWD: ${FRP_DASHBOARD_PWD:+已设置}"
log_info "FRP_TOKEN: ${FRP_TOKEN:+已设置}"
log_info "=========================="

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl 未安装"
        exit 1
    fi
    
    if ! command -v sed &> /dev/null; then
        log_error "sed 未安装"
        exit 1
    fi
    
    if ! command -v base64 &> /dev/null; then
        log_error "base64 未安装"
        exit 1
    fi
    
    log_info "依赖检查完成"
}

# 验证Kubernetes连接
verify_k8s_connection() {
    log_info "验证Kubernetes连接..."
    
    if ! kubectl --kubeconfig="$KUBECONFIG" cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
    
    log_info "Kubernetes连接正常"
}

# 更新镜像标签
update_image_tag() {
    log_info "更新镜像标签为: $REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
    
    # 备份原文件
    cp k8s/deployment.yaml k8s/deployment.yaml.backup
    
    # 更新镜像标签
    sed -i "s|image: $REGISTRY/$IMAGE_NAME:.*|image: $REGISTRY/$IMAGE_NAME:$IMAGE_TAG|g" k8s/deployment.yaml
    
    # 计算配置校验和并更新deployment.yaml
    update_config_checksum
    
    log_info "镜像标签更新完成"
}

# 更新配置校验和
update_config_checksum() {
    log_info "计算配置校验和..."
    
    # 计算configmap.yaml的SHA256校验和
    if [ -f "k8s/configmap.yaml" ]; then
        CONFIG_CHECKSUM=$(sha256sum k8s/configmap.yaml | awk '{print $1}')
        log_info "配置校验和: $CONFIG_CHECKSUM"
        
        # 更新deployment.yaml中的校验和
        sed -i "s|checksum/config: \".*\"|checksum/config: \"$CONFIG_CHECKSUM\"|g" k8s/deployment.yaml
        
        log_info "配置校验和更新完成"
    else
        log_warn "configmap.yaml 文件不存在，跳过校验和计算"
    fi
}

# 创建腾讯云镜像仓库认证Secret
create_registry_secret() {
    log_info "创建腾讯云镜像仓库认证Secret..."
    
    # 检查是否有腾讯云镜像仓库的认证信息
    if [ -n "$TENCENT_REGISTRY_USERNAME" ] && [ -n "$TENCENT_REGISTRY_PASSWORD" ]; then
        log_info "使用环境变量创建镜像仓库认证Secret..."
        
        # 创建dockerconfigjson
        DOCKER_CONFIG=$(cat <<EOF
{
  "auths": {
    "$REGISTRY": {
      "username": "$TENCENT_REGISTRY_USERNAME",
      "password": "$TENCENT_REGISTRY_PASSWORD",
      "auth": "$(echo -n "$TENCENT_REGISTRY_USERNAME:$TENCENT_REGISTRY_PASSWORD" | base64)"
    }
  }
}
EOF
)
        
        # 编码为base64
        DOCKER_CONFIG_B64=$(echo "$DOCKER_CONFIG" | base64 -w 0)
        
        # 更新secret.yaml
        sed -i "s|.dockerconfigjson: \".*\"|.dockerconfigjson: \"$DOCKER_CONFIG_B64\"|g" k8s/secret.yaml
        
        log_info "镜像仓库认证Secret配置已更新"
    else
        log_error "❌ 缺少必要的环境变量！"
        log_error "请设置以下环境变量："
        log_error "  - TENCENT_REGISTRY_USERNAME: 腾讯云镜像服务用户名"
        log_error "  - TENCENT_REGISTRY_PASSWORD: 腾讯云镜像服务密码"
        log_error ""
        log_error "在GitHub Secrets中设置这些值，或通过环境变量传递。"
        log_error "部署将失败，因为无法创建有效的镜像仓库认证。"
        exit 1
    fi
}

# 创建或更新Secret
create_secrets() {
    log_info "创建或更新Secret..."
    
    # 检查是否需要更新Secret
    if [ -n "$FRP_DASHBOARD_PWD" ] && [ -n "$FRP_TOKEN" ]; then
        log_info "使用环境变量更新Secret..."
        
        # 更新secret.yaml中的值
        DASHBOARD_USER_B64=$(echo -n "admin" | base64)
        DASHBOARD_PWD_B64=$(echo -n "$FRP_DASHBOARD_PWD" | base64)
        TOKEN_B64=$(echo -n "$FRP_TOKEN" | base64)
        
        sed -i "s|dashboard_pwd: .*|dashboard_pwd: $DASHBOARD_PWD_B64|g" k8s/secret.yaml
        sed -i "s|token: .*|token: $TOKEN_B64|g" k8s/secret.yaml
        
        log_info "Secret配置已更新"
    else
        log_warn "⚠️  未设置FRP_DASHBOARD_PWD或FRP_TOKEN环境变量"
        log_warn "将使用默认配置（dashboard_pwd: ttangtao123, token: ttangtao123）"
        log_warn "建议在生产环境中设置自定义密码和token"
    fi
}

# 部署到Kubernetes
deploy_to_k8s() {
    log_info "开始部署到Kubernetes..."
    
    # 创建命名空间（如果不存在）
    kubectl --kubeconfig="$KUBECONFIG" apply -f k8s/namespace.yaml
    
    # 创建Secret
    kubectl --kubeconfig="$KUBECONFIG" apply -f k8s/secret.yaml
    
    # 应用所有配置
    kubectl --kubeconfig="$KUBECONFIG" apply -k k8s/
    
    log_info "Kubernetes配置应用完成"
}

# 等待部署完成
wait_for_deployment() {
    log_info "等待部署完成..."
    
    if ! kubectl --kubeconfig="$KUBECONFIG" rollout status deployment/frps -n "$NAMESPACE" --timeout=300s; then
        log_error "部署超时或失败"
        kubectl --kubeconfig="$KUBECONFIG" rollout status deployment/frps -n "$NAMESPACE"
        exit 1
    fi
    
    log_info "部署完成"
}

# 验证部署
verify_deployment() {
    log_info "验证部署状态..."
    
    # 检查Pod状态
    log_info "Pod状态:"
    kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" -o wide
    
    # 检查服务状态
    log_info "服务状态:"
    kubectl --kubeconfig="$KUBECONFIG" get svc -n "$NAMESPACE"
    
    # 检查部署状态
    log_info "部署状态:"
    kubectl --kubeconfig="$KUBECONFIG" get deployment -n "$NAMESPACE"
    
    # 检查Secret状态
    log_info "Secret状态:"
    kubectl --kubeconfig="$KUBECONFIG" get secret -n "$NAMESPACE"
    
    # 检查日志
    log_info "最新日志:"
    kubectl --kubeconfig="$KUBECONFIG" logs -n "$NAMESPACE" deployment/frps --tail=20
}

# 清理备份文件
cleanup() {
    log_info "清理临时文件..."
    rm -f k8s/deployment.yaml.backup
}

# 主函数
main() {
    log_info "开始FRPS部署流程..."
    
    check_dependencies
    verify_k8s_connection
    create_registry_secret
    create_secrets
    update_image_tag
    deploy_to_k8s
    wait_for_deployment
    verify_deployment
    cleanup
    
    log_info "FRPS部署完成！"
    log_info "访问信息:"
    log_info "  - FRP服务端口: 7000 (NodePort: 30000)"
    log_info "  - 仪表板端口: 7500 (NodePort: 30001)"
    log_info "  - 仪表板域名: http://frps.ray321.cn"
}

# 错误处理
trap 'log_error "部署过程中发生错误，退出码: $?"; cleanup; exit 1' ERR

# 仅在脚本被直接执行时运行主函数
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi 