# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Pet-Habit (儿童手表习惯养成App) — Spring Boot 3.2.5 microservice backend. Target platform: 小天才 children's smartwatch (primary school age).

## Build & Run

```bash
# Full project build
mvn clean compile -DskipTests

# Build specific module
mvn -pl pet-habit-service-pet clean compile

# Run a service (dev profile)
mvn -pl pet-habit-service-user spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-pet spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-habit spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-reward spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-battle spring-boot:run -Dspring-boot.run.profiles=dev
mvn -pl pet-habit-service-config spring-boot:run -Dspring-boot.run.profiles=dev

# Run gateway (port 8081)
mvn -pl pet-habit-gateway spring-boot:run -Dspring-boot.run.profiles=dev

# Database init
mysql -u root -p < schema.sql
```

Requires: JDK 17, Maven 3.8+, MySQL 8.0+, Redis 6+, Nacos (optional, defaults to localhost:8848).

## Module Architecture

```
pom.xml (parent, packaging=pom)
├── pet-habit-common/              Shared library (Result, PushService, SecurityConfig,
│                                   GatewayHeaderAuthFilter, RedisConfig, Dubbo APIs)
├── pet-habit-service-user/ :8082  User service (auth, profile, device, friendship, notification)
├── pet-habit-service-pet/  :8083  Pet service (egg, evolution, skills, personality, AI chat, WebSocket)
├── pet-habit-service-habit/:8084  Habit service (templates, habit CRUD, check-in, review)
├── pet-habit-service-reward/:8085 Reward service (points, redemption, achievements)
├── pet-habit-service-battle/:8086 Battle service (P2P records, round details)
├── pet-habit-service-config/:8087 Config service (system_config, streak_bonus_config)
└── pet-habit-gateway/      :8081  API Gateway (reactive, routing, auth, rate-limit)
```

## Service Communication

- **External → Gateway**: HTTP REST
- **Gateway → Services**: HTTP REST (Nacos load-balanced: `lb://pet-habit-{service}`)
- **Service ↔ Service**: Apache Dubbo 3.x (triple protocol, Nacos registry)
- **Dubbo ports**: user:20882, pet:20883, habit:20884, reward:20885, battle:20886, config:20887

## Request Flow

```
Client → Gateway (8081, reactive) → [AuthGlobalFilter: JWT verify]
       → inject X-User-Id / X-User-Role headers
       → route to target service via lb://pet-habit-{name} (Nacos)
       → GatewayHeaderAuthFilter reads headers, builds SecurityContext
       → @PreAuthorize on controllers for role-based access
```

- **Gateway auth**: `AuthGlobalFilter` verifies JWT, skips public paths (`/api/auth/**`, `/actuator/**`, `/ws/**`). Injects `X-User-Id` and `X-User-Role` headers.
- **Server auth**: `GatewayHeaderAuthFilter` trusts those headers blindly. Server uses `@PreAuthorize` for method-level role checks.
- **User roles**: `PARENT` / `CHILD` enum on `User.Role`.

## Domain Modules (per service)

Each service follows: `entity` → `mapper` (MyBatis-Plus) → `service` → `controller` (+ `dubbo/` for Dubbo impl).

- **user** — Registration/login, parent-child binding, friendship, device binding, notification
- **pet** — Egg incubation, evolution, personality/emotion/5-attribute, skills, AI conversations, WebSocket
- **habit** — 5 categories (HYGIENE/STUDY/SPORT/LIFE_SKILL/ROUTINE), check-in, parent review
- **reward** — Points ledger, reward shop, redemption, achievements
- **battle** — Bluetooth P2P battle records between devices
- **config** — System-level config tables (`config_system`, `config_streak_bonus`)

## Key Abstractions

- **`ModelService`** (`com.pethabit.ai`) — AI chat interface (pet service). `DeepSeekServiceImpl` is a stub.
- **`PushService`** (`com.pethabit.common`) — Platform push adapter interface.
- **`Result<T>`** — Standard API response envelope: `{code, msg, data}`.
- **Dubbo interfaces** — `com.pethabit.common.dubbo.*` in common module, implementation in each service's `dubbo/` package.

## Database

Shared MySQL, each service has its own database:

| Service | Database |
|---------|----------|
| user | pet_habit_user |
| pet | pet_habit_pet |
| habit | pet_habit_habit |
| reward | pet_habit_reward |
| battle | pet_habit_battle |
| config | pet_habit_config |
| gateway | pet_habit_gateway |

## Configuration

- Profile `dev`: `application-dev.yml` in each module
- Gateway overrides: `pet-habit-gateway/src/main/resources/application.yml`
- Nacos shared config: `optional:nacos:${spring.application.name}.yaml`
