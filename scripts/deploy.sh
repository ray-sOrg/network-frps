#!/bin/bash

set -e
source "$(dirname "$0")/common.sh"

# 配置变量
REGISTRY=${REGISTRY:-"ccr.ccs.tencentyun.com"}
IMAGE_NAME=${IMAGE_NAME:-"ray321/frps"}
IMAGE_TAG=${IMAGE_TAG:-"latest"}
NAMESPACE=${NAMESPACE:-"frps"}
KUBECONFIG=${KUBECONFIG:-"kubeconfig.yaml"}

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
    
    # 生成配置校验和
    CONFIG_CHECKSUM=$(sha256sum k8s/configmap.yaml | awk '{print $1}')
    sed -i "s|\${CONFIG_CHECKSUM}|$CONFIG_CHECKSUM|g" k8s/deployment.yaml
    
    log_info "镜像标签更新完成"
}

# 部署到Kubernetes
deploy_to_k8s() {
    log_info "开始部署到Kubernetes..."
    
    # 创建命名空间（如果不存在）
    kubectl --kubeconfig="$KUBECONFIG" apply -f k8s/namespace.yaml
    
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
    update_image_tag
    deploy_to_k8s
    wait_for_deployment
    verify_deployment
    cleanup
    
    log_info "FRPS部署完成！"
}

# 错误处理
trap 'log_error "部署过程中发生错误，退出码: $?"; cleanup; exit 1' ERR

# 仅在脚本被直接执行时运行主函数
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi 