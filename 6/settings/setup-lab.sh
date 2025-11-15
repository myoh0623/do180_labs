#!/bin/bash

# DO180 Lab 6: 애플리케이션 스케일링 실습 환경 구성 스크립트
# Apollo 프로젝트와 jet 애플리케이션을 자동으로 생성하고 배포

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 6 - 애플리케이션 스케일링 실습 환경 구성"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 사전 조건 확인
echo -e "${YELLOW}[1/4] 사전 조건 확인 중...${NC}"

if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ OpenShift 클러스터에 로그인되어 있지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 사전 조건 확인 완료${NC}"
echo "  - 현재 사용자: $(oc whoami)"
echo ""

# 1. Apollo 프로젝트 생성
echo -e "${YELLOW}[2/4] Apollo 프로젝트 생성 중...${NC}"

if oc get project apollo &>/dev/null; then
    echo "  ⚠ Apollo 프로젝트가 이미 존재합니다."
    oc project apollo
else
    if oc auth can-i create projects &>/dev/null; then
        oc new-project apollo --display-name="Apollo Mission Control" --description="DO180 Lab 6 - Application Scaling"
        echo "  ✓ Apollo 프로젝트 생성됨"
    else
        echo -e "${RED}  ✗ 프로젝트 생성 권한이 없습니다.${NC}"
        echo "  관리자에게 Apollo 프로젝트 생성을 요청하거나 self-provisioner 권한을 요청하세요."
        exit 1
    fi
fi

echo -e "${GREEN}✓ Apollo 프로젝트 설정 완료${NC}"
echo ""

# 2. jet 애플리케이션 배포
echo -e "${YELLOW}[3/4] jet 애플리케이션 배포 중...${NC}"

# 현재 프로젝트가 apollo인지 확인
oc project apollo &>/dev/null

if oc get deployment jet &>/dev/null; then
    CURRENT_REPLICAS=$(oc get deployment jet -o jsonpath='{.spec.replicas}')
    echo "  ⚠ jet deployment가 이미 존재합니다. (현재 레플리카: $CURRENT_REPLICAS)"
else
    # Red Hat Universal Base Image with httpd를 사용하여 jet 애플리케이션 생성
    oc create deployment jet --image=registry.redhat.io/ubi8/httpd-24:latest
    
    # deployment가 생성될 때까지 잠시 대기
    echo "  - deployment 생성 대기 중..."
    sleep 3
    
    # 초기 레플리카를 3개로 설정 (스케일링 실습을 위해)
    oc scale deployment jet --replicas=3
    
    echo "  ✓ jet 애플리케이션 배포됨 (Red Hat UBI httpd, 초기 레플리카: 3)"
fi

# 애플리케이션이 Ready 상태가 될 때까지 대기
echo "  - Pod가 Ready 상태가 될 때까지 대기 중..."
oc rollout status deployment jet --timeout=120s

# 서비스 생성 (접근 편의를 위해, httpd는 8080 포트 사용)
if ! oc get service jet &>/dev/null; then
    oc expose deployment jet --port=8080 --target-port=8080
    echo "  ✓ jet 서비스 생성됨 (포트 8080)"
else
    echo "  ⚠ jet 서비스가 이미 존재합니다."
fi

if ! oc get route jet &>/dev/null; then
    oc expose service jet
    echo "  ✓ jet 라우트 생성됨"
else
    echo "  ⚠ jet 라우트가 이미 존재합니다."
fi

echo -e "${GREEN}✓ jet 애플리케이션 배포 완료${NC}"
echo ""

# 3. 현재 상태 확인
echo -e "${YELLOW}[4/4] 현재 상태 확인 중...${NC}"

echo "  - 현재 deployment 상태:"
oc get deployment jet

echo ""
echo "  - 현재 실행 중인 Pod:"
oc get pods | grep jet || echo "    jet Pod를 찾을 수 없습니다."

echo -e "${GREEN}✓ 현재 상태 확인 완료${NC}"
echo ""

# 완료 메시지
echo -e "${BLUE}=========================================="
echo "애플리케이션 스케일링 실습 환경 구성 완료!"
echo "=========================================="
echo ""
echo "생성된 리소스:"
CURRENT_REPLICAS=$(oc get deployment jet -o jsonpath='{.spec.replicas}')
READY_REPLICAS=$(oc get deployment jet -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo "✓ Apollo 프로젝트"
echo "✓ jet deployment (Red Hat UBI httpd, 현재 레플리카: $CURRENT_REPLICAS, Ready: $READY_REPLICAS)"
echo "✓ jet 서비스 (포트 8080)"
echo "✓ jet 라우트 (외부 접근)"
echo ""
echo "실습 과제:"
echo "🎯 jet deployment의 레플리카를 정확히 5개로 스케일링하세요!"
echo ""
echo "스케일링 방법:"
echo "1. CLI 방법:"
echo "   oc scale deployment jet --replicas=5"
echo ""
echo "2. Web Console 방법:"
echo "   - Developer View → Topology → jet 애플리케이션 클릭"
echo "   - Details 탭에서 Pod 개수 조정 (↑↓ 버튼 사용)"
echo ""
echo "3. 결과 확인:"
echo "   oc get deployment jet"
echo "   oc get pods | grep jet"
echo ""
echo "정리: ./settings/cleanup-lab.sh"
echo -e "${NC}"