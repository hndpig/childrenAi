# Pet-Habit API 网关 — 架构·功能·使用手册

> 版本: 1.3 | 最后更新: 2026-06-04 | 模块: pet-habit-gateway

---

## 目录

1. [架构概述](#1-架构概述)
2. [系统架构](#2-系统架构)
3. [路由表](#3-路由表)
4. [功能详解](#4-功能详解)
   - [4.1 路由转发](#41-路由转发)
   - [4.2 认证鉴权](#42-认证鉴权)
   - [4.3 限流](#43-限流)
   - [4.4 熔断降级](#44-熔断降级)
   - [4.5 请求日志与链路追踪](#45-请求日志与链路追踪)
   - [4.6 跨域 CORS](#46-跨域-cors)
   - [4.7 Nacos 注册中心与配置中心](#47-nacos-注册中心与配置中心)
   - [4.8 监控端点](#48-监控端点)
   - [4.9 报文记录](#49-报文记录)
5. [Filter 执行链](#5-filter-执行链)
6. [配置参考](#6-配置参考)
7. [部署与启动](#7-部署与启动)
8. [运维手册](#8-运维手册)
9. [附录：技术选型对照](#9-附录技术选型对照)

---

## 1. 架构概述

### 1.1 定位

API 网关是全部客户端请求的**唯一入口**，承担路由转发、安全校验、流量控制、熔断降级、可观测性等横切关注点。业务服务不再各自处理这些通用逻辑。

### 1.2 核心能力矩阵

| 能力 | 组件 | 说明 |
|------|------|------|
| 路由转发 | Spring Cloud Gateway | 基于 Reactor 的非阻塞网关，按 Path 谓词匹配路由 |
| 服务发现 | Nacos Discovery | 阿里开源，服务注册/发现 + 健康检查 |
| 配置中心 | Nacos Config | 配置热刷新，无需重启 |
| 认证鉴权 | JWT (jjwt 0.12) + GlobalFilter | 网关验证 JWT，通过 Header 传递身份给下游 |
| 限流 | Redis + Lua 令牌桶 | 按用户/按 IP+路径 维度限流 |
| 熔断 | Resilience4j CircuitBreaker | 计数滑动窗口，50% 失败率触发，10s 恢复 |
| 超时 | Resilience4j TimeLimiter | 3 秒超时断开 |
| 链路追踪 | Micrometer Tracing + Brave | 每个请求注入 TraceId |
| 监控 | Micrometer + Actuator | 暴露 Prometheus 指标端点 |
| 跨域 | CorsWebFilter | 统一 CORS 配置 |

### 1.3 依赖关系

```
pom.xml (pet-habit-parent, Spring Boot 3.2.5 + Spring Cloud 2023.0.2 + Alibaba 2023.0.1 + Dubbo 3.2)
├── Nacos Server (注册中心 + 配置中心, standalone 模式)
├── pet-habit-common      (共享: Result, PushService, SecurityConfig, Dubbo API)
├── pet-habit-service-* ×6 (业务服务, :8082-8087, 注册到 Nacos)
└── pet-habit-gateway      (网关, :8081, 从 Nacos 发现所有服务)
```

### 1.4 服务发现架构

```
                    ┌─────────────────┐
                    │  Nacos Server    │
                    │  localhost:8848  │
                    └──────┬──────────┘
             ① register    │  ② discover
              self:8082-8087│     pet-habit-{user,pet,habit,reward,battle,config}
                    ┌──────┴──────────┐
                    │                 │
                    ▼                 ▼
    ┌──────────────────────┐  ┌──────────────┐
    │   6 Microservices     │  │   Gateway     │
    │   :8082 ~ :8087      │  │   :8081       │
    │                       │  │               │
    │  user / pet / habit   │  │  ③ lb://pet-  │
    │  reward / battle      │  │    habit-{svc} │
    │  config               │  │   → 对应服务   │
    └──────────────────────┘  └──────────────┘
```

---

## 2. 系统架构

### 2.1 整体拓扑

```
              手表端 (Flutter)                  家长端 (微信小程序)
                   │                                  │
                   └────────────┬─────────────────────┘
                                │  HTTPS
                                ▼
                        ┌──────────────┐
                        │    Nginx      │  TLS 终结 / 静态资源
                        └──────┬───────┘
                               │  HTTP :8081
                               ▼
                   ┌───────────────────────────┐
                   │     API Gateway :8081      │
                   │                            │
                   │  ┌──────────────────────┐  │
                   │  │ 1. RequestLogFilter   │  │  ← TraceId 注入
                   │  │    (order: -200)      │  │
                   │  ├──────────────────────┤  │
                   │  │ 2. AuthGlobalFilter   │  │  ← JWT 验证
                   │  │    (order: -100)      │  │
                   │  ├──────────────────────┤  │
                   │  │ 3. RateLimiter        │  │  ← Redis 令牌桶
                   │  ├──────────────────────┤  │
                   │  │ 4. CircuitBreaker     │  │  ← Resilience4j
                   │  └──────────────────────┘  │
                   │                            │
                   │  路由引擎 (Path Predicate)  │
                   └───┬───┬───┬───┬───┬───────┘
                       │   │   │   │   │
            ┌──────────┘   │   │   │   └──────────┐
            ▼              ▼   ▼   ▼              ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
    │  user    │  │   pet    │  │  habit   │  │  reward  │
    │  :8082   │  │  :8083   │  │  :8084   │  │  :8085   │
    └──────────┘  └──────────┘  └──────────┘  └──────────┘
            ┌──────────┐  ┌──────────┐
            │  battle  │  │  config  │
            │  :8086   │  │  :8087   │
            └──────────┘  └──────────┘
```

### 2.2 鉴权分层

```
网关层 → JWT 有效性验证 (谁在请求？)
         ├─ 通过 → 注入 Header → 转发
         └─ 不通过 → 401

业务层 → 角色权限验证 (能做什么？)
         @PreAuthorize("hasRole('PARENT')")
         @PreAuthorize("hasRole('CHILD')")
```

### 2.3 请求流转过程

```
客户端
  │  GET /api/pet/status
  │  Authorization: Bearer eyJ...
  ▼
Gateway :8081
  │
  ├─ RequestLogFilter   → [a1b2c3d4] --> GET /api/pet/status
  │                        X-Trace-Id 注入
  │
  ├─ AuthGlobalFilter   → 解析 JWT: sub=123, role=CHILD
  │                       注入: X-User-Id=123, X-User-Role=CHILD
  │
  ├─ RequestRateLimiter → Redis 令牌桶: 检查 user:123 令牌数
  │
  ├─ CircuitBreaker     → 宠物服务熔断器状态: CLOSED
  │
  └─ Route → lb://pet-habit-pet
         │
         ▼
宠物服务 :8083
  │
  ├─ GatewayHeaderAuthFilter → 读到 X-User-Id=123, X-User-Role=CHILD
  │                            构建 SecurityContext
  │
  ├─ Controller → @PreAuthorize("hasRole('CHILD')") ✓
  │
  └─ Response ← { code: 200, data: {...} }
         │
         ▼
Gateway :8081
  │
  └─ RequestLogFilter → [a1b2c3d4] <-- GET 200 45ms
```

---

## 3. 路由表

### 3.1 路由定义

| 路由 ID | 匹配路径 | 目标 | 限流 (r/s) | 熔断 | 鉴权 |
|---------|----------|------|-----------|------|------|
| auth | `/api/auth/**` | pet-habit-user:8082 | 无 | 无 | 白名单 |
| user-service | `/api/user/**` | pet-habit-user:8082 | 10/20 | userCB | JWT |
| pet-service | `/api/pet/**` | pet-habit-pet:8083 | 10/20 | petCB | JWT |
| habit-service | `/api/habit/**` | pet-habit-habit:8084 | 10/20 | habitCB | JWT |
| reward-service | `/api/reward/**` | pet-habit-reward:8085 | 5/10 | rewardCB | JWT |
| battle-service | `/api/battle/**` | pet-habit-battle:8086 | 10/20 | battleCB | JWT |
| websocket | `/ws/**` | pet-habit-pet:8083 | 无 | 无 | 透传 |

> 限流格式: `replenishRate/burstCapacity`（令牌桶：每秒填充数 / 最大突发容量）

### 3.2 白名单路径

以下路径跳过 JWT 鉴权，直接转发：

```
/api/auth/login
/api/auth/register
/actuator/health
/actuator/prometheus
```

### 3.3 WebSocket 特殊处理

`/ws/**` 路径既不限流也不鉴权，请求原样透传至 server。鉴权逻辑由 WebSocket 握手阶段的 Query Param token 单独处理（待后续完善）。

---

## 4. 功能详解

### 4.1 路由转发 + 服务发现

**实现类**: `application.yml` 中 `spring.cloud.gateway.routes` 配置 + Nacos Discovery

**路由规则**: 基于 Path 谓词匹配。所有路由目标通过 `lb://` 前缀从 Nacos 发现服务实例。

```yaml
# 示例
- id: pet-service
  uri: lb://pet-habit-pet          # ← 从 Nacos 发现，非硬编码 IP
  predicates:
    - Path=/api/pet/**
```

**服务发现流程**:
```
① 各服务启动 → 向 Nacos 注册: pet-habit-user/pet/habit/reward/battle/config (6个独立服务)
② Gateway 启动 → 向 Nacos 订阅所有 6 个服务的实例列表
③ 请求到达 Gateway → lb://pet-habit-{svc} → LoadBalancer 选择实例
④ 实例下线 → Nacos 推送变更 → Gateway 自动剔除
```

**负载均衡**: 集成 Spring Cloud LoadBalancer，默认轮询策略。后期多实例部署时自动生效，无需改代码。

**Nacos 控制台**: 访问 `http://localhost:8848/nacos` 可查看服务列表和实例健康状态。

---

### 4.2 认证鉴权

**实现类**: `filter/AuthGlobalFilter.java`

**流程**:
```
Authorization Header 是否存在？
  ├─ 无 → 返回 401 {"code":401,"msg":"Missing or invalid Authorization header"}
  └─ 有 → Bearer <token>
           │
           ├─ JWT 解析 (HMAC-SHA)
           │    ├─ 成功 → 提取 sub → X-User-Id
           │    │        提取 role → X-User-Role
           │    │        构造 mutated exchange, 继续转发
           │    └─ 失败 → 返回 401 {"code":401,"msg":"Invalid or expired token"}
```

**JWT Claims 结构**:
```json
{
  "sub": "123",           // 用户 ID
  "role": "CHILD",        // PARENT | CHILD
  "iat": 1717113600,
  "exp": 1717718400       // 7 天过期
}
```

**下游消费方式**:
```
Server 端 GatewayHeaderAuthFilter 读取 Header:
  X-User-Id   → SecurityContext.getAuthentication().getName()
  X-User-Role → SecurityContext.getAuthentication().getAuthorities()

Controller 中使用:
  @PreAuthorize("hasRole('PARENT')")  // 只有家长能访问
```

**JWT Secret 配置**:
```yaml
jwt:
  secret: ${JWT_SECRET:change-me-in-production}  # 生产环境必须设置环境变量
```

---

### 4.3 限流

**实现类**: `config/RateLimiterConfig.java` + Spring Cloud Gateway `RequestRateLimiter`

**限流算法**: Redis 令牌桶 (Lua 脚本原子操作)

**配置格式**:
```yaml
- name: RequestRateLimiter
  args:
    redis-rate-limiter.replenishRate: 10     # 每秒填充 10 个令牌
    redis-rate-limiter.burstCapacity: 20     # 最大突发 20 个令牌
    redis-rate-limiter.requestedTokens: 1    # 每次请求消耗 1 个令牌
```

**Key 解析器** — 两种策略可供选择:

| 策略 | KeyResolver Bean | Key 格式 | 适用场景 |
|------|-----------------|----------|----------|
| 按用户限流 | `userKeyResolver` | `user:123` | 已认证 API（精细控制） |
| 按 IP+路径 | `ipKeyResolver` | `192.168.1.1:/api/pet/status` | 公开 API / 未认证请求 |

**当前使用**: 生产环境推荐 `ipKeyResolver`（兜底安全），配置中只需修改 `key-resolver` 引用。

**限流拒绝响应**: HTTP 429 Too Many Requests

**Redis Key 结构**:
```
request_rate_limiter.{routeId}.{key}.tokens
request_rate_limiter.{routeId}.{key}.timestamp
```
TTL 由 `burstCapacity / replenishRate` 自动计算。

---

### 4.4 熔断降级

**依赖**: Resilience4j + Spring Cloud CircuitBreaker

**三层熔断保护**:

#### 4.4.1 CircuitBreaker（断路器）

```
状态机:
  CLOSED ──[失败率 ≥ 50%]──▶ OPEN ──[10秒后]──▶ HALF_OPEN
    ▲                                                  │
    └────────[3次试探成功]──────────────────────────────┘
                         [任一失败 → 回到 OPEN]
```

| 参数 | 值 | 说明 |
|------|-----|------|
| `slidingWindowType` | COUNT_BASED | 基于请求次数的滑动窗口 |
| `slidingWindowSize` | 10 | 窗口大小 10 次请求 |
| `failureRateThreshold` | 50 | 50% 失败率触发 |
| `waitDurationInOpenState` | 10s | 熔断后 10 秒进入半开 |
| `permittedNumberOfCallsInHalfOpenState` | 3 | 半开状态允许 3 次试探 |

#### 4.4.2 TimeLimiter（超时）

```yaml
resilience4j:
  timelimiter:
    configs:
      default:
        timeoutDuration: 3s    # 超过 3 秒直接失败
```

#### 4.4.3 Fallback（降级兜底）

**实现类**: `handler/FallbackController.java`

每个服务有独立的降级端点：

| 服务 | 降级路径 | 返回内容 |
|------|---------|----------|
| 用户服务 | `/fallback/user` | `{"code":503,"msg":"用户服务暂时不可用"}` |
| 宠物服务 | `/fallback/pet` | `{"code":503,"msg":"宠物服务暂时不可用"}` |
| 习惯服务 | `/fallback/habit` | `{"code":503,"msg":"习惯服务暂时不可用"}` |
| 积分兑换 | `/fallback/reward` | `{"code":503,"msg":"积分兑换服务暂时不可用"}` |
| 对战服务 | `/fallback/battle` | `{"code":503,"msg":"对战服务暂时不可用"}` |

> Fallback 当前返回静态 JSON。手表端应识别 `code=503` 展示"网络开小差"等儿童友好提示。

---

### 4.5 请求日志与链路追踪

**实现类**: `filter/RequestLogFilter.java`

**执行顺序**: order = -200，在 AuthFilter 之前执行（确保任何请求都有日志）

**日志格式**:
```
[a1b2c3d4e5f67890] --> GET /api/pet/status?petId=1
[a1b2c3d4e5f67890] <-- GET 200 45ms
```

**TraceId 生成规则**:
1. 检查上游是否传了 `X-Trace-Id` Header → 复用
2. 无则生成 16 位 UUID 短码
3. 注入到响应的 `X-Trace-Id` Header
4. 注入到下游请求的 `X-Trace-Id` Header

**链路串联**:
```
Client → Gateway (TraceId=a1b2) → 微服务 (TraceId=a1b2) → MySQL
        所有日志都有同一个 TraceId
```

配合 `logging.level.com.pethabit.gateway: DEBUG` 可在开发阶段看到完整的路由决策日志。

---

### 4.6 跨域 CORS

**实现类**: `config/CorsConfig.java`

```java
允许的来源: *           (所有域名, 生产需收紧)
允许的方法: GET/POST/PUT/DELETE/OPTIONS
允许的 Header: *
允许凭据: true
预检缓存: 3600 秒
```

> 生产环境上线时应将 `allowedOriginPatterns` 改为具体的微信小程序域名和手表端域名白名单。

---

### 4.7 Nacos 注册中心与配置中心

#### 注册中心

**依赖**: `spring-cloud-starter-alibaba-nacos-discovery`

**注册行为**:
```
各服务启动 → Nacos 注册实例 {ip: "192.168.1.10", port: 8082-8087, healthy: true}
  ├── 每 5 秒发送心跳（临时实例）
  ├── 15 秒无心跳 → 标记不健康
  └── 30 秒无心跳 → 剔除实例

Gateway 启动 → Nacos 订阅全部 6 个服务
  ├── 获得各服务实例列表
  ├── 实例上线/下线 → 推送变更 → 本地缓存更新
  └── lb://pet-habit-{svc} → LoadBalancer 轮询选择
```

**配置项**:
| 参数 | 默认 | 说明 |
|------|------|------|
| `spring.cloud.nacos.discovery.server-addr` | `localhost:8848` | Nacos 地址 |
| `spring.cloud.nacos.discovery.namespace` | (空=public) | 环境隔离 |
| `spring.cloud.nacos.discovery.group` | `DEFAULT_GROUP` | 分组 |

#### 配置中心

**依赖**: `spring-cloud-starter-alibaba-nacos-config`

**配置优先级**: Nacos 远程 > 本地 application.yml（使用 `spring.config.import` 导入）

**Data ID 命名规则**: `${spring.application.name}.yaml`（每个服务独立，如 `pet-habit-user.yaml`、`pet-habit-pet.yaml`）

**热刷新**: 标注 `@RefreshScope` 的 Bean，Nacos 变更后自动刷新。示例：
```java
@RestController
@RefreshScope
public class SomeController {
    @Value("${some.config:default}")
    private String value;
}
```

**Nacos 上的配置示例**（每个服务独立 Data ID，如 `pet-habit-user.yaml`、`pet-habit-pet.yaml` 等）:
```yaml
# 数据库（可热修改）
spring:
  datasource:
    url: jdbc:mysql://prod-mysql:3306/pet_habit_user

# 业务参数（可热修改）
user:
  registration:
    open: true
```

#### 多环境隔离

```yaml
# 开发环境
NACOS_NAMESPACE=dev

# 生产环境
NACOS_NAMESPACE=prod
```

不同 namespace 的服务互相不可见，配置也独立管理。

### 4.8 监控端点

暴露路径:

| 端点 | 说明 | 示例 |
|------|------|------|
| `/actuator/health` | 健康检查 | 返回 `{"status":"UP"}` |
| `/actuator/prometheus` | Prometheus 指标 | 包含 QPS/延迟/熔断状态/限流拒绝数 |
| `/actuator/gateway` | 路由列表 | 列出全部路由及其状态 |

**Grafana 可监控的关键指标**:

| 指标 | Prometheus Query |
|------|-----------------|
| 每秒请求数 | `rate(gateway_requests_seconds_count[1m])` |
| P99 延迟 | `histogram_quantile(0.99, gateway_requests_seconds_bucket)` |
| 熔断器状态 | `resilience4j_circuitbreaker_state` (0=CLOSED, 1=OPEN, 2=HALF_OPEN) |
| 限流拒绝数 | `redis_rate_limiter_denied_total` |
| 各路由错误率 | `gateway_requests_seconds_count{outcome="SERVER_ERROR"} / gateway_requests_seconds_count` |



### 4.9 报文记录

**实现类**: `filter/PayloadLogFilter.java` + `audit/` 包

#### 工作原理

```
请求到达 → PayloadLogFilter (order=50)
  │
  ├─ ① 查 ApiLogConfigCache: 当前 path 是否需要记录？
  │     └─ 否 → 跳过
  │
  ├─ ② 缓存请求体 (内存, ≤4KB, 仅 POST/PUT/PATCH)
  │     └─ 大文件/流式上传 → 不缓存 body
  │
  ├─ ③ 装饰响应 → 拦截响应体 (内存, ≤4KB)
  │
  ├─ ④ 脱敏: password→***, phone→138****0000
  │
  └─ ⑤ chain.filter 完成后 → 异步线程池写入 gateway_audit_log
        线程池: 4-8线程, 队列500, 满时丢弃最旧
```

#### 配置管理

通过数据库表 `gateway_api_log_config` 动态控制，每 60 秒自动刷新缓存，无需重启：

| 字段 | 说明 | 示例 |
|------|------|------|
| `path_pattern` | Ant 风格路径模式 | `/api/habit/*`, `/api/pet/**` |
| `log_request` | 是否记录请求体 | 1=记录, 0=跳过 |
| `log_response` | 是否记录响应体 | 1=记录, 0=跳过 |
| `max_body_size` | body 上限(字节) | 4096 |
| `is_active` | 开关 | 1=启用, 0=停用 |

```sql
-- 临时开启所有接口的请求报文记录
INSERT INTO gateway_api_log_config VALUES ('/api/**', 1, 0, 2048, 1);

-- 关闭宠物接口记录（响应体大）
UPDATE gateway_api_log_config SET is_active = 0 WHERE path_pattern = '/api/pet/**';

-- 60 秒内生效，无需重启
```

#### 脱敏规则

| 字段模式 | 脱敏方式 | 示例 |
|---------|---------|------|
| `password`, `token`, `secret`, `jwt` | 全量替换 | `"***"` |
| `phone`, `mobile` | 中间 4 位 | `"138****0000"` |
| `Authorization`, `Cookie` Header | Header 值替换 | `"Bearer ***"` |

配置在 `application.yml`:
```yaml
payload-log:
  mask-fields: password,token,secret,jwt,phone,mobile
  mask-headers: authorization,cookie
```

#### 审计表查询示例

```sql
-- 查看某个用户的所有操作
SELECT * FROM gateway_audit_log WHERE user_id = 123 ORDER BY created_at DESC LIMIT 20;

-- 查看某个 TraceId 的完整链路
SELECT * FROM gateway_audit_log WHERE trace_id = 'a1b2c3d4e5f67890';

-- 查看打卡接口的请求/响应（排查积分未到账）
SELECT * FROM gateway_audit_log
WHERE path LIKE '/api/habit/%' AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR);

-- 保留 90 天，每日凌晨 4 点自动清理
```

#### 性能保护

| 机制 | 配置 | 说明 |
|------|------|------|
| body 上限 | 默认 4KB | 超过截断 + 标记 |
| 异步写入 | 独立线程池 | 不阻塞 Event Loop |
| 队列满 | DiscardOldest | 丢弃旧数据，保护网关 |
| 缓存配置 | 60s 刷新 | 每次请求只查内存，不查 DB |
| 跳过路径 | `/ws/`, `/actuator/` | WebSocket/监控不记录 |

---


### 5.1 执行顺序

```
请求进入
  │
  ▼
┌──────────────────────────────────┐
│ 1. RequestLogFilter  (-200)      │  生成 TraceId, 记录入口日志
├──────────────────────────────────┤
│ 2. AuthGlobalFilter  (-100)      │  JWT 验证 + 身份注入
├──────────────────────────────────┤
│ 3. PayloadLogFilter   (50)       │  报文记录 (可选, 仅配置路径)
├──────────────────────────────────┤
│ 4. CorsWebFilter                 │  处理 OPTIONS 预检
├──────────────────────────────────┤
│ 5. Route Predicate 匹配          │  根据 Path 选择目标路由
├──────────────────────────────────┤
│ 6. RequestRateLimiter            │  Redis 令牌桶检查
├──────────────────────────────────┤
│ 7. CircuitBreaker                │  熔断状态检查
├──────────────────────────────────┤
│ 8. TimeLimiter                   │  超时控制 (3s)
├──────────────────────────────────┤
│ 9. 转发至对应微服务 (:8082-:8087)  │
├──────────────────────────────────┤
│ 10. [Server 处理...]             │
├──────────────────────────────────┤
│ 11. Response 返回                │
├──────────────────────────────────┤
│ 12. PayloadLogFilter.doFinally   │  异步写审计（不阻塞响应）
├──────────────────────────────────┤
│ 13. RequestLogFilter.doFinally   │  记录出口日志 (耗时 + 状态码)
└──────────────────────────────────┘
  │
  ▼
返回客户端
```

### 5.2 Order 值说明

| Filter | Order | 原因 |
|--------|-------|------|
| Netty 基础 Filter | MAX (最低优先级) | 框架内置 |
| RequestRateLimiter | 0 (默认) | GatewayFilter |
| CircuitBreaker | 0 (默认) | GatewayFilter |
| CorsWebFilter | 0 (默认) | WebFilter |
| AuthGlobalFilter | -100 | 在限流之前完成鉴权（避免未认证请求消耗令牌） |
| RequestLogFilter | -200 | 在所有业务逻辑之前记录日志 |

---

## 6. 配置参考

### 6.1 完整配置项

```yaml
# ---- 服务器 ----
server.port                                  # 默认 8081

# ---- Redis (限流依赖) ----
spring.data.redis.host                       # 默认 localhost
spring.data.redis.port                       # 默认 6379
spring.data.redis.password                   # 默认空

# ---- JWT ----
jwt.secret                                   # 签名密钥（生产必须环境变量覆盖）
jwt.expiration                               # 过期秒数，默认 604800 (7天)

# ---- 熔断 ----
resilience4j.circuitbreaker.configs.default.slidingWindowSize       # 默认 10
resilience4j.circuitbreaker.configs.default.failureRateThreshold     # 默认 50 (%)
resilience4j.circuitbreaker.configs.default.waitDurationInOpenState  # 默认 10s
resilience4j.timelimiter.configs.default.timeoutDuration             # 默认 3s

# ---- 限流 (按路由配置) ----
redis-rate-limiter.replenishRate              # 每秒填充令牌数
redis-rate-limiter.burstCapacity              # 最大令牌容量
redis-rate-limiter.requestedTokens            # 每次消耗令牌数

# ---- 监控 ----
management.endpoints.web.exposure.include     # 默认: health,prometheus,gateway
management.metrics.tags.application           # 默认: pet-habit-gateway
management.tracing.sampling.probability       # 默认: 1.0 (全量采样)
```

### 6.2 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `NACOS_SERVER` | Nacos 服务地址 | localhost:8848 |
| `NACOS_NAMESPACE` | Nacos 命名空间 | (空=public) |
| `REDIS_HOST` | Redis 地址 | localhost |
| `REDIS_PORT` | Redis 端口 | 6379 |
| `REDIS_PASSWORD` | Redis 密码 | (空) |
| `JWT_SECRET` | JWT 签名密钥 | change-me-in-production |

---

## 7. 部署与启动

### 7.1 前置条件

| 依赖 | 版本要求 | 说明 |
|------|---------|------|
| JDK | 17+ | 编译和运行 |
| Maven | 3.6.3+ | 项目构建 |
| Nacos | 2.3.x | 注册中心 + 配置中心 |
| Redis | 6+ | 限流令牌桶存储 |
| MySQL | 8.0+ | 业务服务依赖（网关本身也连 `pet_habit_gateway` database 做审计日志） |

### 7.2 编译

```bash
cd pet-habit

# 编译全部模块
mvn clean compile

# 单独编译网关
mvn clean compile -pl pet-habit-gateway -am
```

### 7.3 启动顺序

```
1. 启动 Nacos  (默认 localhost:8848, standalone 模式)
2. 启动 Redis  (默认 localhost:6379)
3. 启动 MySQL  (所有服务需要)
4. 启动 6 个微服务 (:8082-8087, 自动注册到 Nacos)
5. 启动 pet-habit-gateway (:8081, 自动从 Nacos 发现所有服务)
```

```bash
# 终端 0 — 启动 Nacos（Windows standalone 模式）
cd nacos/bin
startup.cmd -m standalone
# Nacos 控制台: http://localhost:8848/nacos (用户名/密码: nacos/nacos)

# 终端 1-6 — 启动各业务服务
mvn -pl pet-habit-service-user spring-boot:run
mvn -pl pet-habit-service-pet spring-boot:run
mvn -pl pet-habit-service-habit spring-boot:run
mvn -pl pet-habit-service-reward spring-boot:run
mvn -pl pet-habit-service-battle spring-boot:run
mvn -pl pet-habit-service-config spring-boot:run

# 终端 7 — 启动网关
mvn -pl pet-habit-gateway spring-boot:run
```

### 7.4 验证

```bash
# 健康检查
curl http://localhost:8081/actuator/health
# → {"status":"UP"}

# 未认证请求 → 401
curl http://localhost:8081/api/pet/status
# → {"code":401,"msg":"Missing or invalid Authorization header"}

# 登录获取 Token（需要 server 端有 /api/auth/login 接口）
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000","password":"test123"}'
# → {"code":200,"data":{"token":"eyJ..."}}

# 携带 Token 访问受保护接口
curl http://localhost:8081/api/pet/status \
  -H "Authorization: Bearer eyJ..."
# → {"code":200,"data":{...}}

# Prometheus 指标
curl http://localhost:8081/actuator/prometheus
# → ...gateway_requests_seconds_count...
```

### 7.5 Docker 部署（推荐生产方案）

```dockerfile
# pet-habit-gateway/Dockerfile
FROM eclipse-temurin:17-jre-alpine
COPY target/pet-habit-gateway-0.0.1-SNAPSHOT.jar app.jar
ENV JWT_SECRET=${JWT_SECRET}
ENV REDIS_HOST=redis
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

```bash
docker run -d \
  -p 8081:8081 \
  -e JWT_SECRET=prod-secret-xxxx \
  -e REDIS_HOST=redis \
  --name pet-habit-gateway \
  pet-habit-gateway:latest
```

---

## 8. 运维手册

### 8.1 常见问题排查

| 现象 | 排查方向 |
|------|---------|
| 所有请求 401 | 检查 JWT secret 是否与登录接口签发时一致 |
| 所有请求 503 | 检查对应的微服务是否启动（:8082-:8087），`/actuator/health` 是否 UP |
| 限流异常 (429 过多) | `redis-cli KEYS "request_rate_limiter*"` 查看令牌桶 Key |
| 熔断频繁触发 | 检查 server 日志，排查慢查询或异常 |
| 路由不生效 | `curl localhost:8081/actuator/gateway/routes` 查看实际路由 |
| Redis 连接失败 | 网关启动时检查 Redis 连通性，限流会降级为放过 |

### 8.2 日志级别调整

```yaml
# 排查路由问题时开启
logging:
  level:
    org.springframework.cloud.gateway: TRACE
    com.pethabit.gateway: DEBUG
```

### 8.3 性能调优建议

| 项目 | 建议 |
|------|------|
| 网关实例数 | 至少 2 个 + Nginx 负载均衡（避免单点） |
| Redis 最大连接数 | 按网关实例数 × 50 预估 |
| WebSocket 连接 | Nginx 层配置 `ip_hash` 保证 sticky session |
| JWT 密钥轮换 | 设置合理的过期时间 (7天), 定期轮换 `jwt.secret` |

### 8.4 安全清单

- [ ] 生产环境已设置 `JWT_SECRET` 环境变量（≥32 字符随机串）
- [ ] 生产环境已收紧 CORS 白名单
- [ ] 网关不暴露 `/actuator/gateway` 到公网
- [ ] Redis 已配置密码认证
- [ ] 日志中不打印 JWT Token 明文
- [ ] 监控面板已配置告警（熔断触发 / 限流拒绝率飙升）

---

## 9. 附录：技术选型对照

| 功能 | 候选方案 | 最终选择 | 原因 |
|------|---------|---------|------|
| 网关框架 | Spring Cloud Gateway / Kong / APISIX / Zuul 2 | Spring Cloud Gateway | 同栈，团队无需学新工具；Reactor 非阻塞，性能足够 |
| 限流算法 | 令牌桶 / 漏桶 / 滑动窗口计数 | 令牌桶 (Redis + Lua) | 允许突发流量，Redis 原子操作精确 |
| 熔断库 | Resilience4j / Hystrix (已停维) / Sentinel | Resilience4j | Spring Cloud 官方推荐，轻量，无外部依赖 |
| JWT 库 | jjwt / Nimbus / auth0-java | jjwt 0.12.x | API 简洁，文档好，0.12 支持新式 Builder |
| 链路追踪 | Brave / OpenTelemetry / SkyWalking | Brave (Micrometer Tracing) | Spring Boot 3 内置集成，零配置即可用 |
| 负载均衡 | Spring Cloud LoadBalancer / Nginx upstream | Nginx (后续) | 当前服务单实例，多实例后在 Nginx 层做 |

---

*本文档随网关迭代更新，修改后同步更新版本号和日期。*
