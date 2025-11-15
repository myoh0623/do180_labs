#!/bin/bash

# DO180 Lab 11: Troubleshooting MySQL Deployment 정리 스크립트
# 실습 후 리소스 정리

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 11 - 실습 환경 정리"
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
echo "  - database 프로젝트 및 모든 리소스"
echo "  - mysql deployment"
echo "  - mysql service"
echo "  - 관련된 모든 pods, secrets, configmaps"
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

if oc get project database &>/dev/null; then
    echo -e "${GREEN}✓ database 프로젝트 존재함${NC}"
    
    # database 프로젝트로 전환
    oc project database &>/dev/null
    
    # MySQL deployment 해결 상태 확인
    if oc get deployment mysql &>/dev/null; then
        MYSQL_READY=$(oc get deployment mysql -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        MYSQL_REPLICAS=$(oc get deployment mysql -o jsonpath='{.spec.replicas}')
        
        if [ "$MYSQL_READY" -eq "$MYSQL_REPLICAS" ] && [ "$MYSQL_READY" -gt 0 ]; then
            echo -e "${GREEN}    ✓ mysql deployment 해결됨 (Ready: $MYSQL_READY/$MYSQL_REPLICAS)${NC}"
            echo "    🎉 실습 성공적으로 완료!"
        else
            echo -e "${YELLOW}    ⚠ mysql deployment 미해결 (Ready: $MYSQL_READY/$MYSQL_REPLICAS)${NC}"
        fi
        
        # 환경 변수 설정 확인
        ENV_VARS=$(oc get deployment mysql -o jsonpath='{.spec.template.spec.containers[0].env}' 2>/dev/null || echo "[]")
        if echo "$ENV_VARS" | grep -q "MYSQL_ROOT_PASSWORD\|MYSQL_USER"; then
            echo "    ✓ MySQL 환경 변수 설정됨"
        else
            echo "    ❌ MySQL 환경 변수 미설정"
        fi
    fi
    
    # 현재 리소스 목록 표시
    echo ""
    echo "  현재 database 프로젝트의 리소스:"
    
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
    
    # Secrets 확인 (mysql-secret이 있는 경우)
    USER_SECRETS=$(oc get secrets --no-headers 2>/dev/null | grep -v "default-token\|builder-token\|deployer-token" | wc -l)
    if [ "$USER_SECRETS" -gt 0 ]; then
        echo "    User Secrets: $USER_SECRETS개"
        oc get secrets --no-headers | grep -v "default-token\|builder-token\|deployer-token" | sed 's/^/      /'
    fi
    
else
    echo -e "${YELLOW}⚠ database 프로젝트를 찾을 수 없습니다.${NC}"
    echo "이미 정리되었거나 생성되지 않았을 수 있습니다."
fi

echo ""

# 2. MySQL 리소스 개별 삭제 (선택적)
echo -e "${YELLOW}[3/4] MySQL 애플리케이션 리소스 삭제 중...${NC}"

if oc get project database &>/dev/null; then
    oc project database &>/dev/null
    
    # mysql deployment 삭제
    if oc get deployment mysql &>/dev/null; then
        echo "  - mysql deployment 삭제 중..."
        oc delete deployment mysql --ignore-not-found=true
        echo -e "${GREEN}  ✓ mysql deployment 삭제됨${NC}"
        
        # Pod 삭제 대기
        echo "  - mysql pod 종료 대기 중..."
        oc wait --for=delete pod -l app=mysql --timeout=60s 2>/dev/null || true
        echo -e "${GREEN}  ✓ mysql pod 정리됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ mysql deployment를 찾을 수 없습니다.${NC}"
    fi
    
    # mysql service 삭제
    if oc get service mysql &>/dev/null; then
        echo "  - mysql service 삭제 중..."
        oc delete service mysql --ignore-not-found=true
        echo -e "${GREEN}  ✓ mysql service 삭제됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ mysql service를 찾을 수 없습니다.${NC}"
    fi
    
    # mysql-secret 삭제 (있는 경우)
    if oc get secret mysql-secret &>/dev/null; then
        echo "  - mysql-secret 삭제 중..."
        oc delete secret mysql-secret --ignore-not-found=true
        echo -e "${GREEN}  ✓ mysql-secret 삭제됨${NC}"
    fi
    
else
    echo -e "${YELLOW}  ⚠ database 프로젝트가 없으므로 건너뜁니다.${NC}"
fi

echo ""

# 3. database 프로젝트 삭제
echo -e "${YELLOW}[4/4] database 프로젝트 삭제 중...${NC}"

if oc get project database &>/dev/null; then
    echo "  - database 프로젝트 및 모든 리소스 삭제 중..."
    oc delete project database
    
    # 프로젝트 삭제 완료 대기
    echo "  - 프로젝트 삭제 완료 대기 중..."
    while oc get project database &>/dev/null; do
        echo -n "."
        sleep 2
    done
    echo ""
    echo -e "${GREEN}  ✓ database 프로젝트 삭제 완료${NC}"
else
    echo -e "${YELLOW}  ⚠ database 프로젝트가 이미 존재하지 않습니다.${NC}"
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
echo "  - database 프로젝트"
echo "  - mysql deployment 및 관련 리소스"
echo "  - mysql service"
echo "  - mysql-secret (있었던 경우)"
echo "  - 모든 pods 및 기타 리소스"
echo ""
echo -e "${BLUE}실습을 다시 수행하려면:${NC}"
echo "  ./settings/setup-lab.sh"
echo ""
echo -e "${YELLOW}MySQL 트러블슈팅 핵심 포인트:${NC}"
echo "  1. Pod 로그 확인: oc logs deployment/mysql"
echo "  2. 환경 변수 설정: oc set env deployment/mysql MYSQL_ROOT_PASSWORD=<password>"
echo "  3. 상태 모니터링: oc rollout status deployment/mysql"
echo ""

# 기본 프로젝트로 전환
if oc get project default &>/dev/null; then
    oc project default &>/dev/null
    echo -e "${YELLOW}현재 프로젝트가 'default'로 전환되었습니다.${NC}"
fi

echo -e "${NC}"