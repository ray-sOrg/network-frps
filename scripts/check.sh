#!/bin/bash

set -e
source "$(dirname "$0")/common.sh"

# 配置变量
NAMESPACE=${NAMESPACE:-"frps"}
KUBECONFIG=${KUBECONFIG:-"kubeconfig.yaml"}

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local deps=("kubectl" "curl" "netcat" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖后重试"
        exit 1
    fi
    
    log_info "所有依赖检查完成"
}

# 验证Kubernetes连接
verify_k8s_connection() {
    log_info "验证Kubernetes集群连接..."
    
    if ! kubectl --kubeconfig="$KUBECONFIG" cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
    
    local cluster_info=$(kubectl --kubeconfig="$KUBECONFIG" cluster-info)
    log_info "集群信息:"
    echo "$cluster_info" | sed 's/^/  /'
    
    log_info "Kubernetes连接正常"
}

# 检查命名空间
check_namespace() {
    log_info "检查命名空间: $NAMESPACE"
    
    if ! kubectl --kubeconfig="$KUBECONFIG" get namespace "$NAMESPACE" &> /dev/null; then
        log_error "命名空间 $NAMESPACE 不存在"
        return 1
    fi
    
    local namespace_status=$(kubectl --kubeconfig="$KUBECONFIG" get namespace "$NAMESPACE" -o jsonpath='{.status.phase}')
    if [ "$namespace_status" = "Active" ]; then
        log_info "命名空间状态: Active ✅"
    else
        log_warn "命名空间状态: $namespace_status"
    fi
    
    return 0
}

# 检查Pod状态
check_pods() {
    log_info "检查Pod状态..."
    
    local pods=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" -o json)
    local pod_count=$(echo "$pods" | jq '.items | length')
    
    if [ "$pod_count" -eq 0 ]; then
        log_error "命名空间 $NAMESPACE 中没有Pod"
        return 1
    fi
    
    log_info "发现 $pod_count 个Pod:"
    
    echo "$pods" | jq -r '.items[] | "  - \(.metadata.name): \(.status.phase) (\(.status.conditions[0].type): \(.status.conditions[0].status))"' | sed 's/^/    /'
    
    # 检查Pod就绪状态
    local ready_pods=$(echo "$pods" | jq -r '.items[] | select(.status.phase == "Running" and (.status.conditions[] | select(.type == "Ready" and .status == "True"))) | .metadata.name')
    local ready_count=$(echo "$ready_pods" | wc -l)
    
    if [ "$ready_count" -eq "$pod_count" ]; then
        log_info "所有Pod都已就绪 ✅"
    else
        log_warn "只有 $ready_count/$pod_count 个Pod就绪"
    fi
    
    return 0
}

# 检查服务状态
check_services() {
    log_info "检查服务状态..."
    
    local services=$(kubectl --kubeconfig="$KUBECONFIG" get svc -n "$NAMESPACE" -o json)
    local service_count=$(echo "$services" | jq '.items | length')
    
    if [ "$service_count" -eq 0 ]; then
        log_error "命名空间 $NAMESPACE 中没有服务"
        return 1
    fi
    
    log_info "发现 $service_count 个服务:"
    
    echo "$services" | jq -r '.items[] | "  - \(.metadata.name): \(.spec.type) (\(.spec.ports[0].port):\(.spec.ports[0].targetPort))"' | sed 's/^/    /'
    
    return 0
}

# 检查部署状态
check_deployments() {
    log_info "检查部署状态..."
    
    local deployments=$(kubectl --kubeconfig="$KUBECONFIG" get deployment -n "$NAMESPACE" -o json)
    local deployment_count=$(echo "$deployments" | jq '.items | length')
    
    if [ "$deployment_count" -eq 0 ]; then
        log_error "命名空间 $NAMESPACE 中没有部署"
        return 1
    fi
    
    log_info "发现 $deployment_count 个部署:"
    
    echo "$deployments" | jq -r '.items[] | "  - \(.metadata.name): \(.spec.replicas) 副本 (\(.status.readyReplicas)/\(.status.replicas) 就绪)"' | sed 's/^/    /'
    
    return 0
}

# 检查Secret状态
check_secrets() {
    log_info "检查Secret状态..."
    
    local secrets=$(kubectl --kubeconfig="$KUBECONFIG" get secret -n "$NAMESPACE" -o json)
    local secret_count=$(echo "$secrets" | jq '.items | length')
    
    if [ "$secret_count" -eq 0 ]; then
        log_error "命名空间 $NAMESPACE 中没有Secret"
        return 1
    fi
    
    log_info "发现 $secret_count 个Secret:"
    
    echo "$secrets" | jq -r '.items[] | "  - \(.metadata.name): \(.type)"' | sed 's/^/    /'
    
    return 0
}

# 检查ConfigMap状态
check_configmaps() {
    log_info "检查ConfigMap状态..."
    
    local configmaps=$(kubectl --kubeconfig="$KUBECONFIG" get configmap -n "$NAMESPACE" -o json)
    local configmap_count=$(echo "$configmaps" | jq '.items | length')
    
    if [ "$configmap_count" -eq 0 ]; then
        log_error "命名空间 $NAMESPACE 中没有ConfigMap"
        return 1
    fi
    
    log_info "发现 $configmap_count 个ConfigMap:"
    
    echo "$configmaps" | jq -r '.items[] | "  - \(.metadata.name)"' | sed 's/^/    /'
    
    return 0
}

# 检查网络连通性
check_network_connectivity() {
    log_info "检查网络连通性..."
    
    # 获取Pod名称
    local pod_name=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" -l app=frps -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        log_error "无法获取Pod名称"
        return 1
    fi
    
    # 检查Pod内端口监听
    log_info "检查Pod内端口监听状态:"
    kubectl --kubeconfig="$KUBECONFIG" exec -n "$NAMESPACE" "$pod_name" -- netstat -tlnp 2>/dev/null | grep -E "(7000|7500)" | sed 's/^/    /' || log_warn "无法检查端口监听状态"
    
    # 检查FRPS进程
    log_info "检查FRPS进程状态:"
    kubectl --kubeconfig="$KUBECONFIG" exec -n "$NAMESPACE" "$pod_name" -- ps aux | grep frps | sed 's/^/    /' || log_warn "无法检查进程状态"
    
    return 0
}

# 检查服务健康状态
check_service_health() {
    log_info "检查服务健康状态..."
    
    # 获取NodePort服务的外部IP
    local node_ip=$(kubectl --kubeconfig="$KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null)
    
    if [ -z "$node_ip" ]; then
        node_ip=$(kubectl --kubeconfig="$KUBECONFIG" get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
    fi
    
    if [ -z "$node_ip" ]; then
        log_warn "无法获取节点IP地址"
        return 1
    fi
    
    log_info "使用节点IP: $node_ip"
    
    # 检查FRP服务端口 (7000 -> 30000)
    log_info "检查FRP服务端口 (7000 -> 30000):"
    if nc -z -w5 "$node_ip" 30000 2>/dev/null; then
        log_info "  FRP服务端口 30000 可达 ✅"
    else
        log_warn "  FRP服务端口 30000 不可达 ❌"
    fi
    
    # 检查仪表板端口 (7500 -> 30001)
    log_info "检查仪表板端口 (7500 -> 30001):"
    if nc -z -w5 "$node_ip" 30001 2>/dev/null; then
        log_info " 仪表板端口 30001 可达 ✅"
    else
        log_warn " 仪表板端口 30001 不可达 ❌"
    fi
    
    return 0
}

# 检查日志状态
check_logs() {
    log_info "检查最新日志..."
    
    local pod_name=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" -l app=frps -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ -z "$pod_name" ]; then
        log_error "无法获取Pod名称"
        return 1
    fi
    
    log_info "Pod $pod_name 的最新日志:"
    kubectl --kubeconfig="$KUBECONFIG" logs -n "$NAMESPACE" "$pod_name" --tail=10 2>/dev/null | sed 's/^/    /' || log_warn "无法获取日志"
    
    return 0
}

# 检查事件
check_events() {
    log_info "检查最近事件..."
    
    local events=$(kubectl --kubeconfig="$KUBECONFIG" get events -n "$NAMESPACE" --sort-by='.lastTimestamp' -o json 2>/dev/null)
    
    if [ -z "$events" ]; then
        log_warn "无法获取事件信息"
        return 1
    fi
    
    local recent_events=$(echo "$events" | jq -r '.items[-5:] | .[] | "  - \(.lastTimestamp): \(.type) \(.reason) - \(.message)"' 2>/dev/null)
    
    if [ -n "$recent_events" ]; then
        log_info "最近5个事件:"
        echo "$recent_events"
    else
        log_info "没有最近事件"
    fi
    
    return 0
}

# 生成部署报告
generate_report() {
    log_info "生成部署状态报告..."
    
    local report_file="frps-deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "FRPS 部署状态报告"
        echo "生成时间: $(date)"
        echo "命名空间: $NAMESPACE"
        echo "========================================"
        echo ""
        
        echo "1. 集群信息:"
        kubectl --kubeconfig="$KUBECONFIG" cluster-info 2>/dev/null | sed 's/^/   /' || echo "   无法获取集群信息"
        echo ""
        
        echo "2. 命名空间状态:"
        kubectl --kubeconfig="$KUBECONFIG" get namespace "$NAMESPACE" -o wide 2>/dev/null | sed 's/^/   /' || echo "   命名空间不存在"
        echo ""
        
        echo "3. Pod状态:"
        kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" -o wide 2>/dev/null | sed 's/^/   /' || echo "   无法获取Pod信息"
        echo ""
        
        echo "4. 服务状态:"
        kubectl --kubeconfig="$KUBECONFIG" get svc -n "$NAMESPACE" 2>/dev/null | sed 's/^/   /' || echo "   无法获取服务信息"
        echo ""
        
        echo "5. 部署状态:"
        kubectl --kubeconfig="$KUBECONFIG" get deployment -n "$NAMESPACE" 2>/dev/null | sed 's/^/   /' || echo "   无法获取部署信息"
        echo ""
        
        echo "6. 最新日志:"
        local pod_name=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" -l app=frps -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$pod_name" ]; then
            kubectl --kubeconfig="$KUBECONFIG" logs -n "$NAMESPACE" "$pod_name" --tail=20 2>/dev/null | sed 's/^/   /' || echo "   无法获取日志"
        else
            echo "   无法获取Pod名称"
        fi
        
    } > "$report_file"
    
    log_info "部署报告已生成: $report_file"
}

# 主函数
main() {
    log_info "开始FRPS部署状态检查..."
    
    check_dependencies
    verify_k8s_connection
    
    local all_checks_passed=true
    
    # 执行各项检查
    check_namespace || all_checks_passed=false
    check_pods || all_checks_passed=false
    check_services || all_checks_passed=false
    check_deployments || all_checks_passed=false
    check_secrets || all_checks_passed=false
    check_configmaps || all_checks_passed=false
    check_network_connectivity || all_checks_passed=false
    check_service_health || all_checks_passed=false
    check_logs || all_checks_passed=false
    check_events || all_checks_passed=false
    
    # 生成报告
    generate_report
    
    # 输出总结
    echo ""
    echo "========================================"
    if [ "$all_checks_passed" = true ]; then
        log_info "所有检查完成！FRPS部署状态正常 ✅"
        log_info "访问信息:"
        log_info "  - FRP服务: http://<节点IP>:30000"
        log_info "  - 仪表板: http://<节点IP>:30001"
        log_info "  - 域名: http://frps.ray321.cn"
    else
        log_warn "部分检查失败，请查看上述日志排查问题"
    fi
    echo "========================================"
}

# 错误处理
trap 'log_error "检查过程中发生错误，退出码: $?"; exit 1' ERR

# 仅在脚本被直接执行时运行主函数
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi 