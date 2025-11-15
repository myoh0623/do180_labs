#!/bin/bash

# DO180 Lab 20: Mount Storage - PV and PVC - 자동 설정 스크립트
# NFS 기반 스토리지 실습 환경 구성

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 20 - Mount Storage PV/PVC 실습 환경 구성"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Storage Class 확인
echo -e "${YELLOW}[1/7] NFS Storage Class 확인 중...${NC}"
STORAGE_CLASS=$(oc get storageclass -o jsonpath='{.items[?(@.provisioner=="kubernetes.io/no-provisioner")].metadata.name}' 2>/dev/null | head -n1)
if [ -z "$STORAGE_CLASS" ]; then
    # NFS Storage Class가 없으면 기본값 사용
    STORAGE_CLASS=$(oc get storageclass -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
fi

if [ -n "$STORAGE_CLASS" ]; then
    echo -e "${GREEN}✓ Storage Class 발견: $STORAGE_CLASS${NC}"
    RECLAIM_POLICY=$(oc get storageclass $STORAGE_CLASS -o jsonpath='{.reclaimPolicy}' 2>/dev/null || echo "Retain")
    echo -e "${GREEN}✓ Reclaim Policy: $RECLAIM_POLICY${NC}"
else
    echo -e "${YELLOW}⚠ Storage Class를 찾을 수 없습니다. 기본값 사용: Retain${NC}"
    RECLAIM_POLICY="Retain"
fi
echo ""

# 2. NFS 서버 확인 또는 설정
echo -e "${YELLOW}[2/7] NFS 서버 정보 확인 중...${NC}"
# NFS Storage Class에서 서버 정보 자동 감지
NFS_SERVER=$(oc get deployment nfs-client-provisioner -n nfs-client-provisioner -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="NFS_SERVER")].value}' 2>/dev/null || echo "192.168.50.254")
NFS_BASE_PATH=$(oc get deployment nfs-client-provisioner -n nfs-client-provisioner -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="NFS_PATH")].value}' 2>/dev/null || echo "/exports-ocp4")
NFS_PATH="${NFS_BASE_PATH}/page"

echo -e "${BLUE}  NFS Server: $NFS_SERVER${NC}"
echo -e "${BLUE}  NFS Path: $NFS_PATH${NC}"

# NFS 디렉토리 생성 시도 (권한이 있는 경우)
echo -e "${YELLOW}  NFS 디렉토리 준비 시도 중...${NC}"
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${NFS_SERVER} "mkdir -p ${NFS_PATH} && chmod 755 ${NFS_PATH}" 2>/dev/null && \
    echo -e "${GREEN}✓ NFS 디렉토리 생성 완료${NC}" || \
    echo -e "${YELLOW}⚠ NFS 디렉토리를 자동으로 생성할 수 없습니다. 수동으로 확인하세요.${NC}"

# 샘플 HTML 파일 생성 시도
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${NFS_SERVER} "cat > ${NFS_PATH}/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Exoplanets - DO180 Lab 20</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            padding: 50px;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        p { font-size: 1.5em; }
        .info { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin: 20px auto; max-width: 600px; }
    </style>
</head>
<body>
    <h1>🪐 Exoplanets Discovery Portal</h1>
    <p>Welcome to the Declarative Manifests Project</p>
    <div class=\"info\">
        <h2>Storage Information</h2>
        <p><strong>Storage Type:</strong> NFS-backed Persistent Volume</p>
        <p><strong>Access Mode:</strong> ReadOnlyMany (ROX)</p>
        <p><strong>Capacity:</strong> 1Gi</p>
        <p><strong>Replicas:</strong> 3 Pods sharing the same storage</p>
    </div>
    <p>Lab 20: Mount Storage - PV and PVC</p>
</body>
</html>
HTMLEOF
chmod 644 ${NFS_PATH}/index.html" 2>/dev/null && \
    echo -e "${GREEN}✓ 샘플 HTML 파일 생성 완료${NC}" || \
    echo -e "${YELLOW}⚠ 샘플 HTML 파일을 자동으로 생성할 수 없습니다.${NC}"
echo ""

# 3. webserver 프로젝트 생성
echo -e "${YELLOW}[3/7] webserver 프로젝트 생성 중...${NC}"
oc new-project webserver --display-name="Web Server Project" --description="DO180 Lab 20 - Storage with PV/PVC" 2>/dev/null || oc project webserver
echo -e "${GREEN}✓ webserver 프로젝트 준비 완료${NC}"
echo ""

# 4. PersistentVolume 생성
echo -e "${YELLOW}[4/7] PersistentVolume 생성 중...${NC}"
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: web-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadOnlyMany
  persistentVolumeReclaimPolicy: ${RECLAIM_POLICY}
  nfs:
    server: ${NFS_SERVER}
    path: ${NFS_PATH}
EOF
echo -e "${GREEN}✓ PersistentVolume 'web-pv' 생성 완료${NC}"
echo ""

# 5. PersistentVolumeClaim 생성
echo -e "${YELLOW}[5/7] PersistentVolumeClaim 생성 중...${NC}"
oc apply -f "$SCRIPT_DIR/web-pvc.yaml"
echo -e "${GREEN}✓ PersistentVolumeClaim 'web-pvc' 생성 완료${NC}"

# PVC 바인딩 대기
echo -e "${YELLOW}  PVC 바인딩 대기 중...${NC}"
for i in {1..30}; do
    PVC_STATUS=$(oc get pvc web-pvc -n webserver -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [ "$PVC_STATUS" == "Bound" ]; then
        echo -e "${GREEN}✓ PVC가 PV에 성공적으로 바인딩되었습니다${NC}"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# 6. 애플리케이션 배포
echo -e "${YELLOW}[6/7] Web Landing 애플리케이션 배포 중...${NC}"
oc apply -f "$SCRIPT_DIR/web-landing-deployment.yaml"
oc apply -f "$SCRIPT_DIR/web-landing-service.yaml"
oc apply -f "$SCRIPT_DIR/web-landing-route.yaml"
echo -e "${GREEN}✓ 애플리케이션 배포 완료${NC}"
echo ""

# 7. Pod 준비 상태 확인
echo -e "${YELLOW}[7/7] Pod 준비 상태 확인 중...${NC}"
echo -e "${BLUE}  3개의 레플리카가 시작될 때까지 대기 중...${NC}"
oc wait --for=condition=ready pod -l app=web-landing -n webserver --timeout=180s 2>/dev/null || {
    echo -e "${YELLOW}⚠ 일부 Pod가 아직 준비되지 않았습니다. 수동으로 확인하세요.${NC}"
}
echo -e "${GREEN}✓ Pod 준비 완료${NC}"
echo ""

# 최종 상태 확인
echo "=========================================="
echo -e "${GREEN}실습 환경 구성 완료!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}📊 현재 상태:${NC}"
echo ""
echo "PersistentVolume:"
oc get pv web-pv
echo ""
echo "PersistentVolumeClaim:"
oc get pvc web-pvc -n webserver
echo ""
echo "Deployments:"
oc get deployment web-landing -n webserver
echo ""
echo "Pods:"
oc get pods -l app=web-landing -n webserver
echo ""
echo "Service:"
oc get svc web-landing -n webserver
echo ""
echo "Route:"
oc get route web-landing -n webserver
echo ""
echo -e "${BLUE}🌐 접근 URL:${NC}"
ROUTE_URL=$(oc get route web-landing -n webserver -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$ROUTE_URL" ]; then
    echo -e "${GREEN}https://$ROUTE_URL${NC}"
else
    echo -e "${YELLOW}Route URL을 가져올 수 없습니다.${NC}"
fi
echo ""
echo -e "${YELLOW}💡 다음 명령으로 애플리케이션을 테스트하세요:${NC}"
echo -e "${BLUE}curl -k https://$ROUTE_URL${NC}"
echo ""
echo -e "${YELLOW}📖 실습 가이드는 README.md 파일을 참조하세요.${NC}"
echo "=========================================="
