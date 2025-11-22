#!/bin/bash

# DO180 Lab 14 Setup Script
# ConfigMap을 사용한 Deployment 구성 실습 환경 구성

set -e

echo "=== DO180 Lab 14 Setup: ConfigMap을 사용한 Deployment 구성 ==="
echo

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 헬퍼 함수들
print_header() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# OpenShift 로그인 상태 확인
print_header "OpenShift 로그인 상태 확인"
if ! oc whoami &> /dev/null; then
    print_error "OpenShift에 로그인하지 않았습니다."
    echo "다음 명령으로 로그인하세요:"
    echo "oc login -u <username> -p <password> <cluster-url>"
    exit 1
fi

CURRENT_USER=$(oc whoami)
print_success "현재 사용자: $CURRENT_USER"

# publish 프로젝트 생성
print_header "publish 프로젝트 생성"
if oc get project publish &> /dev/null; then
    print_warning "publish 프로젝트가 이미 존재합니다. 기존 프로젝트를 정리합니다."
    oc delete project publish --ignore-not-found=true
    
    # 프로젝트 삭제 완료 대기 (최대 60초)
    echo "프로젝트 삭제 완료 대기 중..."
    for i in {1..60}; do
        if ! oc get project publish &> /dev/null; then
            print_success "기존 프로젝트가 완전히 삭제되었습니다."
            break
        fi
        echo -n "."
        sleep 1
    done
    echo
fi

# 새 프로젝트 생성
oc new-project publish --description="ConfigMap 실습용 프로젝트" --display-name="Publish Project"
print_success "publish 프로젝트가 생성되었습니다."

# 프로젝트로 전환
oc project publish
print_success "publish 프로젝트로 전환했습니다."

# 소스 파일 디렉터리 생성
print_header "소스 파일 구성"
WEB_DIR="/home/student/web"
if [ -d "$WEB_DIR" ]; then
    print_warning "기존 $WEB_DIR 디렉터리를 정리합니다."
    rm -rf "$WEB_DIR"
fi

mkdir -p "$WEB_DIR"
print_success "웹 소스 디렉터리 생성: $WEB_DIR"

# index.html 파일 생성
cat > "$WEB_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ConfigMap 실습</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background-color: #f5f5f5;
        }
        .container {
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            max-width: 600px;
            margin: 0 auto;
        }
        .header {
            color: #2c3e50;
            text-align: center;
            margin-bottom: 20px;
        }
        .content {
            color: #34495e;
            line-height: 1.6;
        }
        .highlight {
            background-color: #3498db;
            color: white;
            padding: 2px 8px;
            border-radius: 4px;
        }
        .footer {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 2px solid #ecf0f1;
            text-align: center;
            font-size: 0.9em;
            color: #7f8c8d;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="header">🚀 OpenShift ConfigMap 실습</h1>
        <div class="content">
            <p><strong>실습 목표:</strong> ConfigMap을 통한 설정 관리</p>
            <p>이 파일은 <span class="highlight">ConfigMap</span>을 통해 Pod에 마운트되었습니다.</p>
            <p><strong>ConfigMap 이름:</strong> web-cm</p>
            <p><strong>마운트 경로:</strong> /messages</p>
            <p><strong>소스 파일:</strong> /home/student/web/index.html</p>
            
            <h3>ConfigMap의 장점:</h3>
            <ul>
                <li>애플리케이션 코드와 설정의 분리</li>
                <li>환경별 설정 관리 용이성</li>
                <li>런타임 설정 변경 가능</li>
                <li>여러 Pod 간 설정 공유</li>
            </ul>
            
            <h3>실습 단계:</h3>
            <ol>
                <li>파일로부터 ConfigMap 생성</li>
                <li>Deployment에 볼륨 마운트</li>
                <li>Pod에서 설정 파일 확인</li>
                <li>설정 업데이트 및 재배포</li>
            </ol>
        </div>
        <div class="footer">
            <p>DO180 Lab 14 - ConfigMap을 사용한 Deployment 구성</p>
            <p>생성 시간: $(date)</p>
        </div>
    </div>
</body>
</html>
EOF

print_success "index.html 파일이 생성되었습니다."

# web deployment 생성
print_header "web Deployment 생성"
cat << EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: publish
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: web
        image: registry.access.redhat.com/ubi8/httpd-24
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "100m"
EOF

print_success "web Deployment가 생성되었습니다."

# Service 생성
print_header "web Service 생성"
cat << EOF | oc apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: publish
  labels:
    app: web
spec:
  selector:
    app: web
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
EOF

print_success "web Service가 생성되었습니다."

# Deployment 롤아웃 완료 대기
print_header "Deployment 생성 완료"
print_warning "web Deployment는 ConfigMap을 마운트하기 전까지 Ready되지 않을 수 있습니다."
print_success "Lab 14 실습 환경 구성이 완료되었습니다!"

# Pod 실행 상태 확인
echo "Pod 실행 상태 확인 중..."
sleep 5

POD_STATUS=$(oc get pods -l app=web -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$POD_STATUS" = "Running" ]; then
    print_success "web Pod가 정상적으로 실행 중입니다."
else
    print_warning "Pod 상태: $POD_STATUS (준비 중일 수 있습니다)"
fi

# 현재 리소스 상태 표시
print_header "생성된 리소스 확인"
echo "=== Deployments ==="
oc get deployments

echo
echo "=== Services ==="
oc get services

echo
echo "=== Pods ==="
oc get pods

echo
echo "=== 소스 파일 위치 ==="
echo "파일 경로: $WEB_DIR/index.html"
echo "파일 크기: $(ls -lh $WEB_DIR/index.html | awk '{print $5}')"
echo

# 실습 준비 완료 안내
print_header "실습 준비 완료"
print_success "Lab 14 환경 구성이 완료되었습니다!"
print_success "Lab 14 실습을 시작하세요!"
