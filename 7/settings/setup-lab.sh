#!/bin/bash

# DO180 Lab 7: Horizontal Pod Autoscaling 실습 환경 구성 스크립트
# solar 프로젝트와 titan 애플리케이션을 자동으로 생성하고 배포

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 7 - Horizontal Pod Autoscaling 실습 환경 구성"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 사전 조건 확인
echo -e "${YELLOW}[1/5] 사전 조건 확인 중...${NC}"

if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ OpenShift 클러스터에 로그인되어 있지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 사전 조건 확인 완료${NC}"
echo "  - 현재 사용자: $(oc whoami)"

# Metrics Server 확인
echo "  - Metrics Server 상태 확인..."
if oc get pods -n openshift-monitoring | grep -q "prometheus-adapter"; then
    echo -e "${GREEN}  ✓ Metrics Server 사용 가능${NC}"
else
    echo -e "${YELLOW}  ⚠ Metrics Server 상태를 확인할 수 없습니다. HPA가 정상 작동하지 않을 수 있습니다.${NC}"
fi

echo ""

# 1. solar 프로젝트 생성
echo -e "${YELLOW}[2/5] solar 프로젝트 생성 중...${NC}"

if oc get project solar &>/dev/null; then
    echo "  ⚠ solar 프로젝트가 이미 존재합니다."
    oc project solar
else
    if oc auth can-i create projects &>/dev/null; then
        oc new-project solar --display-name="Solar System Control" --description="DO180 Lab 7 - Horizontal Pod Autoscaling"
        echo "  ✓ solar 프로젝트 생성됨"
    else
        echo -e "${RED}  ✗ 프로젝트 생성 권한이 없습니다.${NC}"
        echo "  관리자에게 solar 프로젝트 생성을 요청하거나 self-provisioner 권한을 요청하세요."
        exit 1
    fi
fi

echo -e "${GREEN}✓ solar 프로젝트 설정 완료${NC}"
echo ""

# 2. titan 애플리케이션 배포
echo -e "${YELLOW}[3/5] titan 애플리케이션 배포 중...${NC}"

# 현재 프로젝트가 solar인지 확인
oc project solar &>/dev/null

if oc get deployment titan &>/dev/null; then
    CURRENT_REPLICAS=$(oc get deployment titan -o jsonpath='{.spec.replicas}')
    echo "  ⚠ titan deployment가 이미 존재합니다. (현재 레플리카: $CURRENT_REPLICAS)"
else
    # Red Hat UBI httpd 이미지를 사용하여 titan 애플리케이션 생성
    # 리소스 요청을 포함하여 배포 (HPA 동작을 위해 필수)
    cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: titan
  namespace: solar
  labels:
    app: titan
spec:
  replicas: 1
  selector:
    matchLabels:
      app: titan
  template:
    metadata:
      labels:
        app: titan
    spec:
      containers:
      - name: titan
        image: registry.redhat.io/ubi8/httpd-24:latest
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 250m
            memory: 128Mi
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
EOF
    
    echo "  ✓ titan 애플리케이션 배포됨 (리소스 요청: 50m CPU, 64Mi Memory)"
fi

# 애플리케이션이 Ready 상태가 될 때까지 대기
echo "  - Pod가 Ready 상태가 될 때까지 대기 중..."
oc rollout status deployment titan --timeout=120s

echo -e "${GREEN}✓ titan 애플리케이션 배포 완료${NC}"
echo ""

# 3. 서비스 및 라우트 생성
echo -e "${YELLOW}[4/5] 서비스 및 라우트 생성 중...${NC}"

# 서비스 생성
if ! oc get service titan &>/dev/null; then
    oc expose deployment titan --port=8080 --target-port=8080
    echo "  ✓ titan 서비스 생성됨 (포트 8080)"
else
    echo "  ⚠ titan 서비스가 이미 존재합니다."
fi

# 라우트 생성
if ! oc get route titan &>/dev/null; then
    oc expose service titan
    echo "  ✓ titan 라우트 생성됨"
else
    echo "  ⚠ titan 라우트가 이미 존재합니다."
fi

echo -e "${GREEN}✓ 서비스 및 라우트 생성 완료${NC}"
echo ""

# 4. 현재 상태 확인
echo -e "${YELLOW}[5/5] 현재 상태 확인 중...${NC}"

echo "  - 현재 deployment 상태:"
oc get deployment titan

echo ""
echo "  - 현재 실행 중인 Pod:"
oc get pods | grep titan || echo "    titan Pod를 찾을 수 없습니다."

echo ""
echo "  - 리소스 요청 확인:"
oc describe deployment titan | grep -A 2 -B 2 "Requests:" || echo "    리소스 요청 정보를 찾을 수 없습니다."

echo -e "${GREEN}✓ 현재 상태 확인 완료${NC}"
echo ""

# 완료 메시지
echo -e "${BLUE}=========================================="
echo "Horizontal Pod Autoscaling 실습 환경 구성 완료!"
echo "=========================================="
echo ""
echo "생성된 리소스:"
CURRENT_REPLICAS=$(oc get deployment titan -o jsonpath='{.spec.replicas}')
READY_REPLICAS=$(oc get deployment titan -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo "✓ solar 프로젝트"
echo "✓ titan deployment (Red Hat UBI httpd, 현재 레플리카: $CURRENT_REPLICAS, Ready: $READY_REPLICAS)"
echo "✓ titan 서비스 (포트 8080)"
echo "✓ titan 라우트 (외부 접근)"
echo "✓ 리소스 요청: 50m CPU, 64Mi Memory (HPA 동작을 위해 필수)"
echo ""
echo "실습 과제:"
echo "🎯 titan deployment에 다음 요구사항으로 HPA를 구성하세요:"
echo "   - 최소 Pod 수: 2개"
echo "   - 최대 Pod 수: 5개"
echo "   - 목표 평균 CPU 사용률: 75%"
echo "   - 각 Pod CPU 요구사항: 50m (이미 설정됨)"
echo "   - 전체 CPU 사용량 제한: 250m (이미 설정됨)"
echo ""
echo "HPA 생성 방법:"
echo "1. CLI 방법:"
echo "   oc autoscale deployment titan --min=2 --max=5 --cpu-percent=75"
echo ""
echo "2. Web Console 방법:"
echo "   - Developer View → Topology → titan 애플리케이션 클릭"
echo "   - Actions → Add HorizontalPodAutoscaler"
echo "   - Min Pods: 2, Max Pods: 5, CPU: 75%"
echo ""
echo "3. 상태 확인:"
echo "   oc get hpa"
echo "   oc describe hpa titan"
echo "   watch oc get pods | grep titan"
echo ""
echo "4. CPU 사용률 확인 (metrics-server 필요):"
echo "   oc top pods | grep titan"
echo ""
echo "정리: ./settings/cleanup-lab.sh"
echo -e "${NC}"