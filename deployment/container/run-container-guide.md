# 백엔드 컨테이너 실행 가이드

## 실행 환경 정보
- **ACR명**: acrdigitalgarage01
- **VM 접속 정보**
  - KEY파일: ~/home/bastion-dg0504
  - USERID: azureuser
  - IP: 4.217.168.223

## 시스템 및 서비스 정보
- **시스템명**: phonebill
- **백엔드 서비스**: api-gateway, user-service, bill-service, product-service, kos-mock

## 1. VM 접속

### 터미널 실행
- **Linux/Mac**: 기본 터미널 실행
- **Windows**: Windows Terminal 실행

### Private Key 권한 설정 (최초 1회)
```bash
chmod 400 ~/home/bastion-dg0504
```

### VM 접속
```bash
ssh -i ~/home/bastion-dg0504 azureuser@4.217.168.223
```

## 2. Git Repository 클론

### 작업 디렉토리 생성
```bash
mkdir -p ~/home/workspace
cd ~/home/workspace
```

### 소스 클론
```bash
git clone https://github.com/cna-bootcamp/phonebill.git
```

### 프로젝트 디렉토리 이동
```bash
cd phonebill
```

## 3. 어플리케이션 빌드 및 컨테이너 이미지 생성
`deployment/container/build-image.md` 파일을 열어 가이드대로 빌드 및 이미지 생성을 수행하세요.

## 4. 컨테이너 레지스트리 로그인

### ACR 인증정보 조회
```bash
az acr credential show --name acrdigitalgarage01
```

출력 예시:
```json
{
  "passwords": [
    {
      "name": "password",
      "value": "your-password-here"
    },
    {
      "name": "password2",
      "value": "your-password2-here"
    }
  ],
  "username": "acrdigitalgarage01"
}
```

### Docker 레지스트리 로그인
```bash
docker login acrdigitalgarage01.azurecr.io -u {username} -p {password}
```

## 5. 컨테이너 이미지 푸시

### 이미지 태그 지정 및 푸시
각 서비스별로 아래 명령을 실행하세요:

```bash
# API Gateway
docker tag api-gateway:latest acrdigitalgarage01.azurecr.io/phonebill/api-gateway:latest
docker push acrdigitalgarage01.azurecr.io/phonebill/api-gateway:latest

# User Service
docker tag user-service:latest acrdigitalgarage01.azurecr.io/phonebill/user-service:latest
docker push acrdigitalgarage01.azurecr.io/phonebill/user-service:latest

# Bill Service
docker tag bill-service:latest acrdigitalgarage01.azurecr.io/phonebill/bill-service:latest
docker push acrdigitalgarage01.azurecr.io/phonebill/bill-service:latest

# Product Service
docker tag product-service:latest acrdigitalgarage01.azurecr.io/phonebill/product-service:latest
docker push acrdigitalgarage01.azurecr.io/phonebill/product-service:latest

# KOS Mock
docker tag kos-mock:latest acrdigitalgarage01.azurecr.io/phonebill/kos-mock:latest
docker push acrdigitalgarage01.azurecr.io/phonebill/kos-mock:latest
```

## 6. 컨테이너 실행

### API Gateway (포트: 8080)
```bash
SERVER_PORT=8080

docker run -d --name api-gateway --rm -p ${SERVER_PORT}:${SERVER_PORT} \
-e BILL_SERVICE_URL=http://localhost:8082 \
-e CORS_ALLOWED_ORIGINS=http://localhost:3000,http://4.217.168.223:3000 \
-e JWT_ACCESS_TOKEN_VALIDITY=18000000 \
-e JWT_REFRESH_TOKEN_VALIDITY=86400000 \
-e JWT_SECRET=nwe5Yo9qaJ6FBD/Thl2/j6/SFAfNwUorAY1ZcWO2KI7uA4bmVLOCPxE9hYuUpRCOkgV2UF2DdHXtqHi3+BU/ecbz2zpHyf/720h48UbA3XOMYOX1sdM+dQ== \
-e KOS_MOCK_URL=http://localhost:8084 \
-e PRODUCT_SERVICE_URL=http://localhost:8083 \
-e SERVER_PORT=8080 \
-e SPRING_PROFILES_ACTIVE=dev \
-e USER_SERVICE_URL=http://localhost:8081 \
acrdigitalgarage01.azurecr.io/phonebill/api-gateway:latest
```

### User Service (포트: 8081)
```bash
SERVER_PORT=8081

docker run -d --name user-service --rm -p ${SERVER_PORT}:${SERVER_PORT} \
-e CORS_ALLOWED_ORIGINS=http://localhost:3000,http://4.217.168.223:3000 \
-e DB_HOST=20.249.70.6 \
-e DB_KIND=postgresql \
-e DB_NAME=phonebill_auth \
-e DB_PASSWORD=AuthUser2025! \
-e DB_PORT=5432 \
-e DB_USERNAME=auth_user \
-e DDL_AUTO=update \
-e JWT_ACCESS_TOKEN_VALIDITY=18000000 \
-e JWT_REFRESH_TOKEN_VALIDITY=86400000 \
-e JWT_SECRET=nwe5Yo9qaJ6FBD/Thl2/j6/SFAfNwUorAY1ZcWO2KI7uA4bmVLOCPxE9hYuUpRCOkgV2UF2DdHXtqHi3+BU/ecbz2zpHyf/720h48UbA3XOMYOX1sdM+dQ== \
-e REDIS_DATABASE=0 \
-e REDIS_HOST=20.249.193.103 \
-e REDIS_PASSWORD=Redis2025Dev! \
-e REDIS_PORT=6379 \
-e SERVER_PORT=8081 \
-e SHOW_SQL=true \
-e SPRING_PROFILES_ACTIVE=dev \
acrdigitalgarage01.azurecr.io/phonebill/user-service:latest
```

### Bill Service (포트: 8082)
```bash
SERVER_PORT=8082

docker run -d --name bill-service --rm -p ${SERVER_PORT}:${SERVER_PORT} \
-e CORS_ALLOWED_ORIGINS=http://localhost:3000,http://4.217.168.223:3000 \
-e DB_CONNECTION_TIMEOUT=30000 \
-e DB_HOST=20.249.175.46 \
-e DB_IDLE_TIMEOUT=600000 \
-e DB_KIND=postgresql \
-e DB_LEAK_DETECTION=60000 \
-e DB_MAX_LIFETIME=1800000 \
-e DB_MAX_POOL=20 \
-e DB_MIN_IDLE=5 \
-e DB_NAME=bill_inquiry_db \
-e DB_PASSWORD=BillUser2025! \
-e DB_PORT=5432 \
-e DB_USERNAME=bill_inquiry_user \
-e JWT_ACCESS_TOKEN_VALIDITY=18000000 \
-e JWT_REFRESH_TOKEN_VALIDITY=86400000 \
-e JWT_SECRET=nwe5Yo9qaJ6FBD/Thl2/j6/SFAfNwUorAY1ZcWO2KI7uA4bmVLOCPxE9hYuUpRCOkgV2UF2DdHXtqHi3+BU/ecbz2zpHyf/720h48UbA3XOMYOX1sdM+dQ== \
-e KOS_BASE_URL=http://localhost:8084 \
-e LOG_FILE_NAME=logs/bill-service.log \
-e REDIS_DATABASE=1 \
-e REDIS_HOST=20.249.193.103 \
-e REDIS_MAX_ACTIVE=8 \
-e REDIS_MAX_IDLE=8 \
-e REDIS_MAX_WAIT=-1 \
-e REDIS_MIN_IDLE=0 \
-e REDIS_PASSWORD=Redis2025Dev! \
-e REDIS_PORT=6379 \
-e REDIS_TIMEOUT=2000 \
-e SERVER_PORT=8082 \
-e SPRING_PROFILES_ACTIVE=dev \
acrdigitalgarage01.azurecr.io/phonebill/bill-service:latest
```

### Product Service (포트: 8083)
```bash
SERVER_PORT=8083

docker run -d --name product-service --rm -p ${SERVER_PORT}:${SERVER_PORT} \
-e CORS_ALLOWED_ORIGINS=http://localhost:3000,http://4.217.168.223:3000 \
-e DB_HOST=20.249.107.185 \
-e DB_KIND=postgresql \
-e DB_NAME=product_change_db \
-e DB_PASSWORD=ProductUser2025! \
-e DB_PORT=5432 \
-e DB_USERNAME=product_change_user \
-e DDL_AUTO=update \
-e JWT_ACCESS_TOKEN_VALIDITY=18000000 \
-e JWT_REFRESH_TOKEN_VALIDITY=86400000 \
-e JWT_SECRET=nwe5Yo9qaJ6FBD/Thl2/j6/SFAfNwUorAY1ZcWO2KI7uA4bmVLOCPxE9hYuUpRCOkgV2UF2DdHXtqHi3+BU/ecbz2zpHyf/720h48UbA3XOMYOX1sdM+dQ== \
-e KOS_API_KEY=dev-api-key \
-e KOS_BASE_URL=http://localhost:8084 \
-e KOS_CLIENT_ID=product-service-dev \
-e KOS_MOCK_ENABLED=true \
-e REDIS_DATABASE=2 \
-e REDIS_HOST=20.249.193.103 \
-e REDIS_PASSWORD=Redis2025Dev! \
-e REDIS_PORT=6379 \
-e SERVER_PORT=8083 \
-e SPRING_PROFILES_ACTIVE=dev \
acrdigitalgarage01.azurecr.io/phonebill/product-service:latest
```

### KOS Mock Service (포트: 8084)
```bash
SERVER_PORT=8084

docker run -d --name kos-mock --rm -p ${SERVER_PORT}:${SERVER_PORT} \
-e SERVER_PORT=8084 \
-e SPRING_PROFILES_ACTIVE=dev \
acrdigitalgarage01.azurecr.io/phonebill/kos-mock:latest
```

## 7. 실행된 컨테이너 확인

모든 서비스가 정상적으로 실행되었는지 확인:

```bash
# 전체 컨테이너 상태 확인
docker ps

# 각 서비스별 개별 확인
docker ps | grep api-gateway
docker ps | grep user-service
docker ps | grep bill-service
docker ps | grep product-service
docker ps | grep kos-mock
```

## 8. 재배포 방법

### 8.1. 로컬에서 수정된 소스 푸시
로컬에서 코드 수정 후 Git 원격 저장소에 푸시

### 8.2. VM 접속
```bash
ssh -i ~/home/bastion-dg0504 azureuser@4.217.168.223
```

### 8.3. 소스 업데이트
```bash
cd ~/home/workspace/phonebill
git pull
```

### 8.4. 컨테이너 이미지 재생성
`deployment/container/build-image.md` 파일을 열어 가이드대로 수행

### 8.5. 컨테이너 이미지 재푸시
```bash
# 예시: user-service 재푸시
docker tag user-service:latest acrdigitalgarage01.azurecr.io/phonebill/user-service:latest
docker push acrdigitalgarage01.azurecr.io/phonebill/user-service:latest
```

### 8.6. 기존 컨테이너 중지 및 삭제
```bash
# 예시: user-service 재배포
docker stop user-service
```

### 8.7. 컨테이너 이미지 삭제 (선택사항)
```bash
docker rmi acrdigitalgarage01.azurecr.io/phonebill/user-service:latest
```

### 8.8. 컨테이너 재실행
위의 **6. 컨테이너 실행** 섹션의 해당 서비스 실행 명령을 다시 실행

## 9. 서비스 접속 확인

컨테이너 실행 후 아래 URL로 서비스 상태를 확인할 수 있습니다:

- **API Gateway**: http://4.217.168.223:8080/swagger-ui/index.html
- **User Service**: http://4.217.168.223:8081/swagger-ui/index.html
- **Bill Service**: http://4.217.168.223:8082/swagger-ui/index.html
- **Product Service**: http://4.217.168.223:8083/swagger-ui/index.html
- **KOS Mock**: http://4.217.168.223:8084/swagger-ui/index.html

## 주의사항

1. **CORS 설정**: 모든 서비스에서 프론트엔드 주소(`http://4.217.168.223:3000`)가 CORS_ALLOWED_ORIGINS에 포함되어 있습니다.
2. **네트워크**: 컨테이너 간 통신을 위해 `localhost` 주소를 사용하고 있으므로, 필요시 네트워크 설정을 조정해야 할 수 있습니다.
3. **데이터베이스 연결**: 각 서비스는 별도의 데이터베이스에 연결됩니다.
4. **Redis 공유**: 모든 서비스가 동일한 Redis 인스턴스를 사용하되, 다른 데이터베이스 번호를 사용합니다.