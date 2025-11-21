#!/bin/bash

# DO180 Lab 10: Secret을 사용하는 애플리케이션 구성 실습 환경 구성 스크립트
# satellite 애플리케이션 배포 및 moon-secret 확인

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 10 - Secret을 사용하는 애플리케이션 구성 실습 환경 구성"
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
echo ""

# 1. moon 프로젝트 및 moon-secret 확인
echo -e "${YELLOW}[2/5] moon 프로젝트 및 moon-secret 확인 중...${NC}"

if ! oc get project moon &>/dev/null; then
    echo -e "${RED}✗ moon 프로젝트를 찾을 수 없습니다.${NC}"
    echo "먼저 DO180 Lab 9를 완료하여 moon 프로젝트와 moon-secret을 생성해야 합니다."
    echo ""
    echo "Lab 9 실행 방법:"
    echo "  cd ../9"
    echo "  ./settings/setup-lab.sh"
    echo "  # moon-secret 생성 후 이 실습 재시도"
    exit 1
fi

# moon 프로젝트로 전환
oc project moon &>/dev/null

if ! oc get secret moon-secret &>/dev/null; then
    echo -e "${RED}✗ moon-secret을 찾을 수 없습니다.${NC}"
    echo "먼저 DO180 Lab 9를 완료하여 moon-secret을 생성해야 합니다."
    echo ""
    echo "moon-secret 생성 방법:"
    echo "  oc create secret generic moon-secret --from-literal=moon-key=bW9vbi1wYXNzd29yZAo="
    exit 1
fi

echo -e "${GREEN}✓ moon 프로젝트 및 moon-secret 확인 완료${NC}"

# moon-secret 내용 검증
DECODED_VALUE=$(oc get secret moon-secret -o jsonpath='{.data.moon-key}' | base64 -d 2>/dev/null || echo "디코딩 실패")
echo "  - moon-secret의 moon-key 값: '$DECODED_VALUE'"
echo ""

# 2. satellite 애플리케이션 배포 (초기 상태: Secret 없이)
echo -e "${YELLOW}[3/5] satellite 애플리케이션 배포 중...${NC}"

if oc get deployment satellite &>/dev/null; then
    CURRENT_REPLICAS=$(oc get deployment satellite -o jsonpath='{.spec.replicas}')
    echo "  ⚠ satellite deployment가 이미 존재합니다. (현재 레플리카: $CURRENT_REPLICAS)"
else
    # satellite 애플리케이션을 Secret 없이 배포 (의도적으로 구성 오류 상태)
    cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: satellite
  namespace: moon
  labels:
    app: satellite
spec:
  replicas: 1
  selector:
    matchLabels:
      app: satellite
  template:
    metadata:
      labels:
        app: satellite
    spec:
      containers:
      - name: satellite
        image: registry.access.redhat.com/ubi8/httpd-24:latest
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        # 초기에는 MOON_KEY 환경 변수가 없음 (의도적)
        # 학생이 실습을 통해 추가해야 함
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
        # 애플리케이션 구성 상태 시뮬레이션을 위한 커스텀 스크립트
        command:
        - /bin/sh
        - -c
        - |
          # 간단한 웹 서버 시뮬레이션
          echo "Starting satellite application..."
          if [ -z "\$MOON_KEY" ]; then
            echo "ERROR: MOON_KEY environment variable not found"
            echo "Application not configured correctly"
            # HTTP 서버 시작 (오류 메시지 제공)
            while true; do
              echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h1>Sorry, application is not configured correctly</h1><p>MOON_KEY environment variable is missing</p>" | nc -l -p 8080 -q 1
            done
          else
            echo "INFO: MOON_KEY environment variable found: \$MOON_KEY"
            echo "Application configured successfully"
            # HTTP 서버 시작 (성공 메시지 제공)
            while true; do
              echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<h1>Welcome to Satellite Control Center</h1><p>Configuration: OK</p><p>MOON_KEY: \$MOON_KEY</p>" | nc -l -p 8080 -q 1
            done
          fi
EOF
    
    echo "  ✓ satellite 애플리케이션 배포됨 (초기 상태: Secret 없음)"
fi

# 애플리케이션이 Ready 상태가 될 때까지 대기
echo "  - Pod가 Ready 상태가 될 때까지 대기 중..."
sleep 5  # nc 명령어 기반 서버는 readiness probe가 정확하지 않을 수 있어 충분한 대기

echo -e "${GREEN}✓ satellite 애플리케이션 배포 완료${NC}"
echo ""

# 3. 서비스 및 라우트 생성
echo -e "${YELLOW}[4/5] 서비스 및 라우트 생성 중...${NC}"

# 서비스 생성
if ! oc get service satellite &>/dev/null; then
    oc expose deployment satellite --port=8080 --target-port=8080
    echo "  ✓ satellite 서비스 생성됨 (포트 8080)"
else
    echo "  ⚠ satellite 서비스가 이미 존재합니다."
fi

# 라우트 생성
if ! oc get route satellite &>/dev/null; then
    oc expose service satellite
    echo "  ✓ satellite 라우트 생성됨"
else
    echo "  ⚠ satellite 라우트가 이미 존재합니다."
fi

echo -e "${GREEN}✓ 서비스 및 라우트 생성 완료${NC}"
echo ""

# 4. 현재 상태 확인
echo -e "${YELLOW}[5/5] 현재 상태 확인 중...${NC}"

echo "  - 현재 deployment 상태:"
oc get deployment satellite

echo ""
echo "  - 현재 실행 중인 Pod:"
oc get pods | grep satellite || echo "    satellite Pod를 찾을 수 없습니다."

echo ""
echo "  - 라우트 정보:"
ROUTE_URL=$(oc get route satellite -o jsonpath='{.spec.host}' 2>/dev/null || echo "라우트 없음")
echo "    URL: http://$ROUTE_URL"

echo ""
echo "  - 현재 애플리케이션 로그 (오류 메시지 확인):"
sleep 2
oc logs deployment/satellite --tail=5 2>/dev/null || echo "    로그를 가져올 수 없습니다."

echo -e "${GREEN}✓ 현재 상태 확인 완료${NC}"
echo ""

# 완료 메시지
echo -e "${BLUE}=========================================="
echo "Secret을 사용하는 애플리케이션 구성 실습 환경 구성 완료!"
echo "=========================================="
echo ""
echo "생성된 리소스:"
CURRENT_REPLICAS=$(oc get deployment satellite -o jsonpath='{.spec.replicas}')
READY_REPLICAS=$(oc get deployment satellite -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
echo "✓ moon 프로젝트 (Lab 9에서 생성)"
echo "✓ moon-secret (Lab 9에서 생성, moon-key: '$DECODED_VALUE')"
echo "✓ satellite deployment (현재 레플리카: $CURRENT_REPLICAS, Ready: $READY_REPLICAS)"
echo "✓ satellite 서비스 (포트 8080)"
echo "✓ satellite 라우트 (외부 접근)"
echo ""
echo "현재 상태:"
echo "❌ satellite 애플리케이션이 'Sorry, application is not configured correctly' 메시지 표시"
echo "❌ MOON_KEY 환경 변수가 설정되지 않음"
echo ""
echo "실습 과제:"
echo "🎯 satellite 애플리케이션에 moon-secret을 환경 변수로 주입하세요:"
echo "   - Secret: moon-secret"
echo "   - 환경 변수: MOON_KEY (moon-secret의 moon-key 사용)"
echo "   - 목표: 오류 메시지 제거 및 정상 동작 확인"
echo ""
echo "Secret 주입 방법:"
echo "1. CLI 방법:"
echo "   oc set env deployment/satellite MOON_KEY --from=secret/moon-secret:moon-key"
echo ""
echo "2. Web Console 방법:"
echo "   - Developer View → Topology → satellite → Actions → Edit Deployment"
echo "   - Environment 섹션에서 MOON_KEY 환경 변수 추가"
echo "   - Value from Secret: moon-secret, Key: moon-key"
echo ""
echo "3. 구성 완료 확인:"
echo "   oc logs deployment/satellite"
echo "   oc exec deployment/satellite -- env | grep MOON_KEY"
echo "   curl http://$ROUTE_URL"
echo ""
echo "정리: ./settings/cleanup-lab.sh"
echo -e "${NC}"
