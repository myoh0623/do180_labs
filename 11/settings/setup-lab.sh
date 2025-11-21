#!/bin/bash

# DO180 Lab 11: Troubleshooting MySQL Deployment 실습 환경 구성 스크립트
# 문제가 있는 MySQL deployment를 포함한 database 프로젝트 생성

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 11 - Troubleshooting MySQL Deployment 실습 환경 구성"
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

# 1. database 프로젝트 생성
echo -e "${YELLOW}[2/4] database 프로젝트 생성 중...${NC}"

if oc get project database &>/dev/null; then
    echo "  ⚠ database 프로젝트가 이미 존재합니다."
    oc project database
else
    if oc auth can-i create projects &>/dev/null; then
        oc new-project database --display-name="Database Troubleshooting Lab" --description="DO180 Lab 11 - MySQL Troubleshooting"
        echo "  ✓ database 프로젝트 생성됨"
    else
        echo -e "${RED}  ✗ 프로젝트 생성 권한이 없습니다.${NC}"
        echo "  관리자에게 database 프로젝트 생성을 요청하거나 self-provisioner 권한을 요청하세요."
        exit 1
    fi
fi

echo -e "${GREEN}✓ database 프로젝트 설정 완료${NC}"
echo ""

# 2. 문제가 있는 MySQL deployment 생성
echo -e "${YELLOW}[3/4] 문제가 있는 MySQL deployment 생성 중...${NC}"

# 현재 프로젝트가 database인지 확인
oc project database &>/dev/null

if oc get deployment mysql &>/dev/null; then
    echo "  ⚠ mysql deployment가 이미 존재합니다."
    echo "  기존 deployment를 사용합니다."
else
    # 의도적으로 환경 변수 없이 MySQL deployment 생성 (문제 상황 재현)
    cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: database
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: quay.io/sclorg/mysql-80-c9s
        ports:
        - containerPort: 3306
          name: mysql
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        # 의도적으로 필수 환경 변수를 설정하지 않음
        # 이로 인해 MySQL 컨테이너가 시작 실패
        readinessProbe:
          exec:
            command:
            - /bin/sh
            - -i
            - -c
            - MYSQL_PWD="\$MYSQL_ROOT_PASSWORD" mysqladmin -u root ping
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          exec:
            command:
            - /bin/sh
            - -i
            - -c
            - MYSQL_PWD="\$MYSQL_ROOT_PASSWORD" mysqladmin -u root ping
          initialDelaySeconds: 30
          periodSeconds: 10
EOF
    
    echo "  ✓ 문제가 있는 mysql deployment 생성됨"
    echo "  ❌ 필수 환경 변수가 설정되지 않아 Pod가 시작 실패할 예정"
fi

echo -e "${GREEN}✓ MySQL deployment 생성 완료${NC}"
echo ""

# 3. 서비스 생성
echo -e "${YELLOW}[4/4] MySQL 서비스 생성 중...${NC}"

# 서비스 생성
if ! oc get service mysql &>/dev/null; then
    oc expose deployment mysql --port=3306 --target-port=3306
    echo "  ✓ mysql 서비스 생성됨 (포트 3306)"
else
    echo "  ⚠ mysql 서비스가 이미 존재합니다."
fi

echo -e "${GREEN}✓ MySQL 서비스 생성 완료${NC}"
echo ""

# 문제 상황 확인을 위한 대기
echo "  - Pod 시작 대기 중... (문제 상황 재현을 위해)"
sleep 10

# 현재 상태 확인
echo "  - 현재 deployment 상태:"
oc get deployment mysql || echo "    deployment 정보를 가져올 수 없습니다."

echo ""
echo "  - 현재 Pod 상태 (문제 예상):"
oc get pods | grep mysql || echo "    mysql Pod를 찾을 수 없습니다."

echo ""

# 완료 메시지
echo -e "${BLUE}=========================================="
echo "MySQL Troubleshooting 실습 환경 구성 완료!"
echo "=========================================="
echo ""
echo "생성된 리소스:"
echo "✓ database 프로젝트"
echo "❌ mysql deployment (환경 변수 누락으로 문제 상황)"
echo "✓ mysql 서비스 (포트 3306)"
echo ""
echo "현재 문제 상황:"
echo "❌ MySQL Pod가 CrashLoopBackOff 또는 Error 상태"
echo "❌ 필수 환경 변수가 설정되지 않아 MySQL 컨테이너 시작 실패"
echo ""
echo "실습 과제:"
echo "🎯 mysql deployment의 문제를 진단하고 해결하세요!"
echo ""
echo "문제 진단 단계:"
echo "1. 현재 상태 확인:"
echo "   oc get deployments"
echo "   oc get pods"
echo ""
echo "2. 문제 원인 분석:"
echo "   oc logs deployment/mysql"
echo "   # 또는 oc logs <mysql-pod-name>"
echo ""
echo "3. 문제 해결 (다음 중 하나 선택):"
echo "   # 방법 1: Root 패스워드 설정 (권장)"
echo "   oc set env deployment/mysql MYSQL_ROOT_PASSWORD=rootpasswd"
echo ""
echo "   # 방법 2: 일반 사용자 + 데이터베이스 설정"
echo "   oc set env deployment/mysql \\"
echo "     MYSQL_USER=student \\"
echo "     MYSQL_PASSWORD=passwd \\"
echo "     MYSQL_DATABASE=testdb"
echo ""
echo "4. 해결 결과 확인:"
echo "   oc rollout status deployment/mysql"
echo "   oc get pods"
echo "   oc logs deployment/mysql"
echo ""
echo "정리: ./settings/cleanup-lab.sh"
echo -e "${NC}"
