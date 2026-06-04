# Pet-Habit 🐱

儿童手表习惯养成 App — 后端微服务

> 目标平台：小天才儿童手表（小学年龄段）  
> 技术栈：Java 17 + Spring Boot 3.2.5 + Spring Cloud + Dubbo 3.x + MySQL + Redis + Nacos

## 项目结构

```
pet-habit/
├── pom.xml                      父 POM（9 个子模块）
├── pet-habit-common/            共享库（Result、PushService、安全配置、Dubbo API）
├── pet-habit-gateway/      网关（:8081，路由、鉴权、限流、熔断）
├── pet-habit-service-user/  用户服务（:8082，注册登录、家庭、好友、设备、通知）
├── pet-habit-service-pet/   宠物服务（:8083，孵化进化、属性成长、技能、性格、AI 对话）
├── pet-habit-service-habit/ 习惯服务（:8084，习惯模板、打卡记录、家长审核）
├── pet-habit-service-reward/积分服务（:8085，积分账户、奖池、兑换、成就）
├── pet-habit-service-battle/对战服务（:8086，蓝牙对战、回合详情）
├── pet-habit-service-config/配置服务（:8087，系统配置、连续打卡加成）
└── schema.sql                   数据库初始化（7 个独立 database）
```

## 快速开始

### 依赖
- JDK 17+
- Maven 3.8+
- MySQL 8.0+
- Redis 6+
- Nacos 2.3.x（服务注册 + 配置中心）

### 启动

```bash
# 1. 初始化数据库（创建 7 个 database 及全部表）
mysql -u root -p < schema.sql

# 2. 启动 Nacos（standalone 模式）
cd nacos/bin && startup.cmd -m standalone

# 3. 编译全部模块
mvn clean compile -DskipTests

# 4. 启动各服务（需要多个终端）
mvn -pl pet-habit-service-user spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-pet spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-habit spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-reward spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-battle spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-config spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-gateway spring-boot:run -Dspring-boot.run.profiles=dev
```

### 配置

修改各服务 `application-dev.yml` 中的数据库连接信息。各服务使用独立 database：

| 服务 | 端口 | Database |
|------|------|----------|
| gateway | 8081 | pet_habit_gateway |
| user | 8082 | pet_habit_user |
| pet | 8083 | pet_habit_pet |
| habit | 8084 | pet_habit_habit |
| reward | 8085 | pet_habit_reward |
| battle | 8086 | pet_habit_battle |
| config | 8087 | pet_habit_config |

## 通信架构

```
Client (手表 / 微信小程序)
  │  HTTPS
  ▼
Gateway (:8081) ─── HTTP ───▶ user (:8082)
  │                            │
  │                            ├── Dubbo ──▶ pet (:20883)
  │                            ├── Dubbo ──▶ habit (:20884)
  │                            └── Dubbo ──▶ reward (:20885)
  │
  ├── HTTP ──▶ pet (:8083) ──── Dubbo ──▶ user (:20882)
  ├── HTTP ──▶ habit (:8084)
  ├── HTTP ──▶ reward (:8085)
  ├── HTTP ──▶ battle (:8086)
  ├── HTTP ──▶ config (:8087)
  └── WebSocket ──▶ pet (:8083)
```

- **外部请求**：全走 HTTP REST，通过 Gateway 统一入口
- **服务间调用**：Apache Dubbo 3.x（triple 协议），Nacos 注册发现

## 模块说明

| 服务 | 职责 |
|------|------|
| 用户服务 | 注册登录、家长-孩子绑定、好友关系、设备绑定、通知推送 |
| 宠物服务 | 蛋孵化、进化链、性格/情绪/属性五维、技能系统、AI 对话 |
| 习惯服务 | 5 类习惯 CRUD、打卡记录、家长审核、连续打卡 |
| 积分兑换 | 积分增减、奖池管理、兑换审核、清零周期 |
| 对战服务 | 蓝牙对战结果保存、战绩查询 |
| 配置服务 | key-value 通用配置、打卡加成阶梯配置 |

## 抽象层

- **Dubbo 接口** — `com.pethabit.common.dubbo.*`（在 common 模块定义，各服务实现）
- **ModelService** — AI 模型抽象（pet 服务，当前 DeepSeek，可切换 OpenAI/通义）
- **PushService** — 推送抽象（common 模块，各手表平台实现各自的适配器）
