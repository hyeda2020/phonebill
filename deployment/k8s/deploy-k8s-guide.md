# 통신요금 관리 서비스 백엔드 Kubernetes 배포 가이드

## 📋 배포 개요

**시스템명**: phonebill
**네임스페이스**: phonebill-dg0504
**ACR명**: acrdigitalgarage01  
**k8s명**: aks-digitalgarage-01
**파드수**: 1개 (각 서비스)
**리소스**: CPU 256m/1024m, 메모리 256Mi/1024Mi

## 🎯 배포 대상 서비스

| 서비스명 | 포트 | 엔드포인트 |
|---------|------|-----------|
| api-gateway | 8080 | Gateway 및 라우팅 |
| user-service | 8081 | /api/v1/auth, /api/v1/users |
| bill-service | 8082 | /api/v1/bills |
| product-service | 8083 | /api/v1/products |
| kos-mock | 8084 | /api/v1/kos |

## 📋 배포 전 검증 결과

### ✅ 검증 완료 항목
- 객체이름 네이밍룰 준수
- Secret에서 stringData 사용
- JWT_SECRET 실행 프로파일 값 적용
- Image 경로 올바른 형식
- Service/Ingress 포트 매핑 일치 (80번)
- Controller @RequestMapping 기반 path 설정
- 보안 환경변수 Secret 분리
- REDIS_DATABASE 서비스별 구분 (0,1,2)
- envFrom 사용으로 환경변수 주입
- 실행 프로파일 전체 환경변수 매핑 완료

### ✅ 배포 전 확인 완료 사항
모든 환경 정보가 확인되어 매니페스트 파일에 반영 완료되었습니다:

1. **✅ Ingress Controller External IP**: `20.214.196.128`
2. **✅ ACR 인증 정보**: `acrdigitalgarage01` / 실제 패스워드 적용
3. **✅ Redis Service**: `redis-cache-dev-master`
4. **✅ Database Services**:
   - User Service: `auth-postgres-dev-postgresql`
   - Bill Service: `bill-inquiry-postgres-dev-postgresql`
   - Product Service: `product-change-postgres-dev-postgresql`

## 🔧 사전 확인 방법

### 1. Azure 로그인 상태 확인
```bash
az account show
```

### 2. AKS Credential 확인
```bash
kubectl cluster-info
```

### 3. 네임스페이스 존재 확인
```bash
kubectl get ns phonebill-dg0504
```

### 4. Ingress Controller External IP 확인 ✅
```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
```
**확인 완료**: EXTERNAL-IP = `20.214.196.128`

### 5. ACR 인증 정보 확인 ✅
```bash
# USERNAME 확인
USERNAME=$(az acr credential show -n acrdigitalgarage01 --query "username" -o tsv)
echo $USERNAME

# PASSWORD 확인  
PASSWORD=$(az acr credential show -n acrdigitalgarage01 --query "passwords[0].value" -o tsv)
echo $PASSWORD
```
**확인 완료**: USERNAME = `acrdigitalgarage01`, PASSWORD = 실제 값 적용

### 6. Redis Service 이름 확인 ✅
```bash
kubectl get svc -n phonebill-dg0504 | grep redis
```
**확인 완료**: `redis-cache-dev-master` (ClusterIP)

### 7. Database Service 이름 확인 ✅
```bash
# 각 서비스별 DB 확인
kubectl get svc -n phonebill-dg0504 | grep auth
kubectl get svc -n phonebill-dg0504 | grep bill  
kubectl get svc -n phonebill-dg0504 | grep product
```
**확인 완료**:
- User Service: `auth-postgres-dev-postgresql`
- Bill Service: `bill-inquiry-postgres-dev-postgresql`  
- Product Service: `product-change-postgres-dev-postgresql`

## ✅ 매니페스트 업데이트 완료

모든 매니페스트 파일이 실제 환경 정보로 업데이트 완료되었습니다:

### 1. ✅ Ingress External IP 적용
`deployment/k8s/common/ingress.yaml`:
```yaml
host: phonebill-api.20.214.196.128.nip.io
```

### 2. ✅ CORS Origins 적용
`deployment/k8s/common/cm-common.yaml`:
```yaml
CORS_ALLOWED_ORIGINS: "http://localhost:8081,http://localhost:8082,http://localhost:8083,http://localhost:8084,http://phonebill.20.214.196.128.nip.io"
```

### 3. ✅ ACR 인증 정보 적용
`deployment/k8s/common/secret-imagepull.yaml`:
```yaml
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "acrdigitalgarage01.azurecr.io": {
          "username": "acrdigitalgarage01",
          "password": "+OY+rmOagorjWvQe/tTk6oqvnZI8SmNbY/Y2o5EDcY+ACRDCDbYk",
          "auth": "YWNyZGlnaXRhbGdhcmFnZTAxOitPWStybU9hZ29yald2UWUvdFRrNm9xdm5aSThTbU5iWS9ZMm81RURjWStBQ1JEQ0RiWWs="
        }
      }
    }
```

### 4. ✅ Redis Host 적용
`deployment/k8s/common/secret-common.yaml`:
```yaml
REDIS_HOST: "redis-cache-dev-master"
```

### 5. ✅ Database Host 적용

**user-service**: `deployment/k8s/user-service/secret-user-service.yaml`
```yaml
DB_HOST: "auth-postgres-dev-postgresql"
```

**bill-service**: `deployment/k8s/bill-service/secret-bill-service.yaml`
```yaml
DB_HOST: "bill-inquiry-postgres-dev-postgresql"
```

**product-service**: `deployment/k8s/product-service/secret-product-service.yaml`
```yaml
DB_HOST: "product-change-postgres-dev-postgresql"
```

## 🚀 배포 실행 가이드

### 1. 공통 매니페스트 적용
```bash
kubectl apply -f deployment/k8s/common/
```

### 2. 서비스별 매니페스트 적용
```bash
# 각 서비스 순차 적용
kubectl apply -f deployment/k8s/api-gateway/
kubectl apply -f deployment/k8s/user-service/
kubectl apply -f deployment/k8s/bill-service/
kubectl apply -f deployment/k8s/product-service/
kubectl apply -f deployment/k8s/kos-mock/
```

### 3. 배포 상태 확인

#### 전체 객체 확인
```bash
kubectl get all -n phonebill-dg0504
```

#### Pod 상태 확인  
```bash
kubectl get pods -n phonebill-dg0504
```

#### Service 확인
```bash
kubectl get svc -n phonebill-dg0504
```

#### Ingress 확인
```bash
kubectl get ingress -n phonebill-dg0504
```

#### ConfigMap/Secret 확인
```bash
kubectl get cm,secret -n phonebill-dg0504
```

### 4. 로그 확인
```bash
# 특정 서비스 로그 확인
kubectl logs -f deployment/user-service -n phonebill-dg0504
kubectl logs -f deployment/bill-service -n phonebill-dg0504
kubectl logs -f deployment/product-service -n phonebill-dg0504
kubectl logs -f deployment/api-gateway -n phonebill-dg0504
kubectl logs -f deployment/kos-mock -n phonebill-dg0504
```

### 5. Health Check 확인
```bash
# 각 서비스 Health 상태 확인 (Pod 내부에서)
kubectl exec -n phonebill-dg0504 deployment/user-service -- curl http://localhost:8081/actuator/health
kubectl exec -n phonebill-dg0504 deployment/bill-service -- curl http://localhost:8082/actuator/health
kubectl exec -n phonebill-dg0504 deployment/product-service -- curl http://localhost:8083/actuator/health
```

## 🔍 문제 해결 가이드

### Pod 시작 실패시
```bash
# Pod 상세 정보 확인
kubectl describe pod <POD_NAME> -n phonebill-dg0504

# 이벤트 확인
kubectl get events -n phonebill-dg0504 --sort-by='.lastTimestamp'
```

### ConfigMap/Secret 변경시
```bash
# 변경 후 Pod 재시작
kubectl rollout restart deployment/<SERVICE_NAME> -n phonebill-dg0504
```

### 네트워크 연결 문제
```bash
# Service DNS 해결 테스트
kubectl exec -n phonebill-dg0504 deployment/api-gateway -- nslookup user-service
```

## 📊 환경변수 매핑 테이블

| 서비스명 | 환경변수 | 지정 객체명 | 환경변수값 |
|---------|---------|-----------|-----------|
| api-gateway | SERVER_PORT | cm-api-gateway | 8080 |
| api-gateway | BILL_SERVICE_URL | cm-api-gateway | http://bill-service |
| api-gateway | PRODUCT_SERVICE_URL | cm-api-gateway | http://product-service |
| api-gateway | USER_SERVICE_URL | cm-api-gateway | http://user-service |
| api-gateway | KOS_MOCK_URL | cm-api-gateway | http://kos-mock |
| 공통 | CORS_ALLOWED_ORIGINS | cm-common | http://localhost:8081,http://localhost:8082,http://localhost:8083,http://localhost:8084,http://phonebill.{EXTERNAL_IP}.nip.io |
| 공통 | JWT_ACCESS_TOKEN_VALIDITY | cm-common | 18000000 |
| 공통 | JWT_REFRESH_TOKEN_VALIDITY | cm-common | 86400000 |
| 공통 | JWT_SECRET | secret-common | (base64 encoded JWT secret) |
| 공통 | REDIS_HOST | secret-common | (Redis 서비스명) |
| 공통 | REDIS_PASSWORD | secret-common | Redis2025Dev! |
| 공통 | REDIS_PORT | cm-common | 6379 |
| 공통 | SPRING_PROFILES_ACTIVE | cm-common | dev |
| user-service | SERVER_PORT | cm-user-service | 8081 |
| user-service | DB_KIND | cm-user-service | postgresql |
| user-service | DB_PORT | cm-user-service | 5432 |
| user-service | DDL_AUTO | cm-user-service | update |
| user-service | REDIS_DATABASE | cm-user-service | 0 |
| user-service | SHOW_SQL | cm-user-service | true |
| user-service | DB_HOST | secret-user-service | (Auth DB 서비스명) |
| user-service | DB_NAME | secret-user-service | phonebill_auth |
| user-service | DB_USERNAME | secret-user-service | auth_user |
| user-service | DB_PASSWORD | secret-user-service | AuthUser2025! |
| bill-service | SERVER_PORT | cm-bill-service | 8082 |
| bill-service | DB_KIND | cm-bill-service | postgresql |
| bill-service | DB_PORT | cm-bill-service | 5432 |
| bill-service | DB_CONNECTION_TIMEOUT | cm-bill-service | 30000 |
| bill-service | DB_IDLE_TIMEOUT | cm-bill-service | 600000 |
| bill-service | DB_LEAK_DETECTION | cm-bill-service | 60000 |
| bill-service | DB_MAX_LIFETIME | cm-bill-service | 1800000 |
| bill-service | DB_MAX_POOL | cm-bill-service | 20 |
| bill-service | DB_MIN_IDLE | cm-bill-service | 5 |
| bill-service | KOS_BASE_URL | cm-bill-service | http://kos-mock |
| bill-service | LOG_FILE_NAME | cm-bill-service | logs/bill-service.log |
| bill-service | REDIS_DATABASE | cm-bill-service | 1 |
| bill-service | REDIS_MAX_ACTIVE | cm-bill-service | 8 |
| bill-service | REDIS_MAX_IDLE | cm-bill-service | 8 |
| bill-service | REDIS_MAX_WAIT | cm-bill-service | -1 |
| bill-service | REDIS_MIN_IDLE | cm-bill-service | 0 |
| bill-service | REDIS_TIMEOUT | cm-bill-service | 2000 |
| bill-service | DB_HOST | secret-bill-service | (Bill DB 서비스명) |
| bill-service | DB_NAME | secret-bill-service | bill_inquiry_db |
| bill-service | DB_USERNAME | secret-bill-service | bill_inquiry_user |
| bill-service | DB_PASSWORD | secret-bill-service | BillUser2025! |
| product-service | SERVER_PORT | cm-product-service | 8083 |
| product-service | DB_KIND | cm-product-service | postgresql |
| product-service | DB_PORT | cm-product-service | 5432 |
| product-service | DDL_AUTO | cm-product-service | update |
| product-service | KOS_BASE_URL | cm-product-service | http://kos-mock |
| product-service | KOS_CLIENT_ID | cm-product-service | product-service-dev |
| product-service | KOS_MOCK_ENABLED | cm-product-service | true |
| product-service | REDIS_DATABASE | cm-product-service | 2 |
| product-service | DB_HOST | secret-product-service | (Product DB 서비스명) |
| product-service | DB_NAME | secret-product-service | product_change_db |
| product-service | DB_USERNAME | secret-product-service | product_change_user |
| product-service | DB_PASSWORD | secret-product-service | ProductUser2025! |
| product-service | KOS_API_KEY | secret-product-service | dev-api-key |
| kos-mock | SERVER_PORT | cm-kos-mock | 8084 |

## 🎯 배포 완료 후 접근 URL

- **API Gateway**: http://phonebill-api.20.214.196.128.nip.io
- **Swagger UI**: http://phonebill-api.20.214.196.128.nip.io/swagger-ui/index.html
- **사용자 인증**: http://phonebill-api.20.214.196.128.nip.io/api/v1/auth  
- **요금 조회**: http://phonebill-api.20.214.196.128.nip.io/api/v1/bills
- **상품 변경**: http://phonebill-api.20.214.196.128.nip.io/api/v1/products

---

**✅ 배포 준비 완료**: 모든 환경 정보가 확인되어 매니페스트 파일에 반영되었습니다. 이제 바로 배포를 진행할 수 있습니다.