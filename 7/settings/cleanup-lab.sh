#!/bin/bash

# DO180 Lab 7: Horizontal Pod Autoscaling 정리 스크립트
# 실습 후 리소스 정리

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 7 - 실습 환경 정리"
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

echo -e "${GREEN}✓ 현재 사용자: $(oc whoami)${NC}"
echo ""

# 사용자 확인
echo -e "${BLUE}이 스크립트는 다음 리소스를 삭제합니다:${NC}"
echo "  - solar 프로젝트 및 모든 리소스"
echo "  - titan 애플리케이션 deployment"
echo "  - titan HPA (있는 경우)"
echo "  - 관련된 pods, services, routes"
echo ""

read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "정리가 취소되었습니다."
    exit 0
fi

echo ""

# 1. 현재 상태 확인
echo -e "${YELLOW}[2/4] 현재 상태 확인 중...${NC}"

if oc get project solar &>/dev/null; then
    echo -e "${GREEN}✓ solar 프로젝트 존재함${NC}"
    
    # solar 프로젝트로 전환
    oc project solar &>/dev/null
    
    # 현재 리소스 목록 표시
    echo ""
    echo "  현재 solar 프로젝트의 리소스:"
    
    # HPA 확인
    HPAS=$(oc get hpa --no-headers 2>/dev/null | wc -l)
    if [ "$HPAS" -gt 0 ]; then
        echo "    HorizontalPodAutoscalers: $HPAS개"
        oc get hpa --no-headers | sed 's/^/      /'
    fi
    
    # Deployments 확인
    DEPLOYMENTS=$(oc get deployments --no-headers 2>/dev/null | wc -l)
    if [ "$DEPLOYMENTS" -gt 0 ]; then
        echo "    Deployments: $DEPLOYMENTS개"
        oc get deployments --no-headers | sed 's/^/      /'
    fi
    
    # Pods 확인
    PODS=$(oc get pods --no-headers 2>/dev/null | wc -l)
    if [ "$PODS" -gt 0 ]; then
        echo "    Pods: $PODS개"
        oc get pods --no-headers | sed 's/^/      /'
    fi
    
    # Services 확인
    SERVICES=$(oc get services --no-headers 2>/dev/null | wc -l)
    if [ "$SERVICES" -gt 0 ]; then
        echo "    Services: $SERVICES개"
        oc get services --no-headers | sed 's/^/      /'
    fi
    
    # Routes 확인
    ROUTES=$(oc get routes --no-headers 2>/dev/null | wc -l)
    if [ "$ROUTES" -gt 0 ]; then
        echo "    Routes: $ROUTES개"
        oc get routes --no-headers | sed 's/^/      /'
    fi
    
else
    echo -e "${YELLOW}⚠ solar 프로젝트를 찾을 수 없습니다.${NC}"
    echo "이미 정리되었거나 생성되지 않았을 수 있습니다."
fi

echo ""

# 2. HPA 및 titan 애플리케이션 개별 삭제 (선택적)
echo -e "${YELLOW}[3/4] HPA 및 titan 애플리케이션 삭제 중...${NC}"

if oc get project solar &>/dev/null; then
    oc project solar &>/dev/null
    
    # HPA 삭제
    if oc get hpa titan &>/dev/null; then
        echo "  - titan HPA 삭제 중..."
        oc delete hpa titan --ignore-not-found=true
        echo -e "${GREEN}  ✓ titan HPA 삭제됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ titan HPA를 찾을 수 없습니다.${NC}"
    fi
    
    # titan deployment 삭제
    if oc get deployment titan &>/dev/null; then
        echo "  - titan deployment 삭제 중..."
        oc delete deployment titan --ignore-not-found=true
        echo -e "${GREEN}  ✓ titan deployment 삭제됨${NC}"
        
        # Pod 삭제 대기
        echo "  - titan pod 종료 대기 중..."
        oc wait --for=delete pod -l app=titan --timeout=60s 2>/dev/null || true
        echo -e "${GREEN}  ✓ titan pod 정리됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ titan deployment를 찾을 수 없습니다.${NC}"
    fi
    
    # Service 삭제
    if oc get service titan &>/dev/null; then
        echo "  - titan service 삭제 중..."
        oc delete service titan --ignore-not-found=true
        echo -e "${GREEN}  ✓ titan service 삭제됨${NC}"
    fi
    
    # Route 삭제
    if oc get route titan &>/dev/null; then
        echo "  - titan route 삭제 중..."
        oc delete route titan --ignore-not-found=true
        echo -e "${GREEN}  ✓ titan route 삭제됨${NC}"
    fi
    
else
    echo -e "${YELLOW}  ⚠ solar 프로젝트가 없으므로 건너뜁니다.${NC}"
fi

echo ""

# 3. solar 프로젝트 삭제
echo -e "${YELLOW}[4/4] solar 프로젝트 삭제 중...${NC}"

if oc get project solar &>/dev/null; then
    echo "  - solar 프로젝트 및 모든 리소스 삭제 중..."
    oc delete project solar
    
    # 프로젝트 삭제 완료 대기
    echo "  - 프로젝트 삭제 완료 대기 중..."
    while oc get project solar &>/dev/null; do
        echo -n "."
        sleep 2
    done
    echo ""
    echo -e "${GREEN}  ✓ solar 프로젝트 삭제 완료${NC}"
else
    echo -e "${YELLOW}  ⚠ solar 프로젝트가 이미 존재하지 않습니다.${NC}"
fi

echo ""

# 정리 완료 확인
echo -e "${BLUE}=========================================="
echo "정리 완료"
echo "=========================================="
echo ""

# 최종 상태 확인
echo -e "${GREEN}✓ 실습 환경이 성공적으로 정리되었습니다.${NC}"
echo ""
echo "정리된 리소스:"
echo "  - solar 프로젝트"
echo "  - titan deployment 및 관련 리소스"
echo "  - titan HorizontalPodAutoscaler"
echo "  - 모든 pods, services, routes"
echo ""
echo -e "${BLUE}실습을 다시 수행하려면 다음 명령어를 실행하세요:${NC}"
echo "  ./settings/setup-lab.sh"
echo ""

# 기본 프로젝트로 전환
if oc get project default &>/dev/null; then
    oc project default &>/dev/null
    echo -e "${YELLOW}현재 프로젝트가 'default'로 전환되었습니다.${NC}"
fi

echo -e "${NC}"