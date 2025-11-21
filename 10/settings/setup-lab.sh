#!/bin/bash

# DO180 Lab 10: Secret을 사용하는 애플리케이션 구성 실습 환경 구성 스크립트
# satellite 애플리케이션 배포 및 moon-secret 확인

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 10 - Secret을 사용하는 애플리케이션 구성 실습 환경 구성"
echo "=========================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}[1/5] 사전 조건 확인 중...${NC}"

if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ OpenShift 클러스터에 로그인되어 있지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 사전 조건 확인 완료${NC}"
echo "  - 현재 사용자: $(oc whoami)"
echo ""

echo -e "${YELLOW}[2/5] moon 프로젝트 및 moon-secret 확인 중...${NC}"

if ! oc get project moon &>/dev/null; then
    echo -e "${RED}✗ moon 프로젝트가 존재하지 않습니다.${NC}"
    echo "Lab 9에서 moon 프로젝트와 moon-secret을 먼저 생성해야 합니다."
    exit 1
fi

oc project moon &>/dev/null

if ! oc get secret moon-secret &>/dev/null; then
    echo -e "${RED}✗ moon-secret이 존재하지 않습니다.${NC}"
    echo "Lab 9에서 moon-secret을 먼저 생성해야 합니다."
    exit 1
fi

DECODED_VALUE=$(oc get secret moon-secret -o jsonpath='{.data.moon-key}' | base64 -d 2>/dev/null || echo "디코딩 실패")
echo -e "${GREEN}✓ moon 프로젝트 및 moon-secret 확인 완료${NC}"
echo "  - moon-key 값: '$DECODED_VALUE'"
echo ""

echo -e "${YELLOW}[3/5] satellite 애플리케이션 배포 중...${NC}"

if oc get deployment satellite &>/dev/null; then
    echo "  ⚠ satellite deployment가 이미 존재합니다. 스킵합니다."
else
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
        image: registry.access.redhat.com/ubi8/python-38:latest
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
        command:
        - /bin/sh
        - -c
        - |
          echo "Starting satellite application..."
          if [ -z "\$MOON_KEY" ]; then
            echo "<h1>Sorry, application is not configured correctly</h1>" > /tmp/index.html
            echo "<p>MOON_KEY environment variable is missing</p>" >> /tmp/index.html
          else
            echo "<h1>Welcome to Satellite Control Center</h1>" > /tmp/index.html
            echo "<p>Configuration: OK</p><p>MOON_KEY: \$MOON_KEY</p>" >> /tmp/index.html
          fi
          python3 -m http.server 8080 --directory /tmp
EOF

    echo "  ✓ satellite 애플리케이션 배포됨 (초기 상태: Secret 없음)"
fi

sleep 4
echo -e "${GREEN}✓ satellite 애플리케이션 배포 완료${NC}"
echo ""

echo -e "${YELLOW}[4/5] 서비스 및 라우트 생성 중...${NC}"

if ! oc get service satellite &>/dev/null; then
    oc expose deployment satellite --port=8080 --target-port=8080
    echo "  ✓ satellite 서비스 생성됨"
else
    echo "  ⚠ satellite 서비스 이미 존재"
fi

if ! oc get route satellite &>/dev/null; then
    oc expose service satellite
    echo "  ✓ satellite 라우트 생성됨"
else
    echo "  ⚠ satellite 라우트 이미 존재"
fi

echo -e "${GREEN}✓ 서비스 및 라우트 생성 완료${NC}"
echo ""

echo -e "${YELLOW}[5/5] 현재 상태 확인 중...${NC}"

echo "  - Deployment:"
oc get deployment satellite

echo "  - Pods:"
oc get pods | grep satellite || echo "satellite Pod 없음"

ROUTE_URL=$(oc get route satellite -o jsonpath='{.spec.host}')
echo ""
echo "  - 라우트 URL: http://$ROUTE_URL"
echo ""

echo "  - 마지막 로그:"
oc logs deployment/satellite --tail=5 || true
echo ""

echo -e "${BLUE}=========================================="
echo "Secret 기반 satellite 애플리케이션 실습 환경 구성 완료!"
echo "==========================================${NC}"
echo ""
echo "이제 다음 명령으로 Secret을 주입해보세요:"
echo ""
echo "  oc set env deployment/satellite MOON_KEY --from=secret/moon-secret:moon-key"
echo ""
echo "성공하면 웹 페이지가 다음처럼 변경됩니다:"
echo "  Welcome to Satellite Control Center"
echo ""
echo "정리: ./settings/cleanup-lab.sh"
echo ""
