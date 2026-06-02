# Pet-Habit 🐱

儿童手表习惯养成 App — 后端服务

> 目标平台：小天才儿童手表（小学年龄段）  
> 技术栈：Java 17 + Spring Boot 3.x + MySQL + Redis

## 项目结构

```
pet-habit/
├── common/        通用工具（Result、异常处理、推送抽象）
├── config/        配置类（Security、Redis、WebSocket）
├── ai/            AI 模型抽象层（ModelService + DeepSeek 实现）
├── module/
│   ├── user/      用户服务（注册/登录/家庭/好友）
│   ├── pet/       宠物服务（孵化/进化/情绪/技能）
│   ├── habit/     习惯服务（5类习惯/打卡/审核）
│   ├── reward/    积分兑换服务（积分/奖池/兑换）
│   └── battle/    对战服务（蓝牙对战/结算记录）
└── resources/     配置文件（dev/prod 多环境）
```

## 快速开始

### 依赖
- JDK 17+
- Maven 3.8+
- MySQL 8.0+
- Redis 6+

### 启动

```bash
# 1. 创建数据库
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS pet_habit;"

# 2. 编译运行
cd pet-habit
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

### 配置

修改 `application-dev.yml` 中的数据库和 Redis 连接信息。

## 模块说明

| 服务 | 职责 |
|------|------|
| 用户服务 | 注册登录、家长-孩子绑定、好友关系 |
| 宠物服务 | 蛋孵化、进化链、性格/情绪/属性/五维、技能系统 |
| 习惯服务 | 5类习惯CRUD、打卡记录、家长审核、连续打卡 |
| 积分兑换 | 积分增减、奖池管理、兑换审核、清零周期 |
| 对战服务 | 蓝牙对战结果保存、战绩查询 |
| AI 服务 | 宠物对话、知识问答（通过 ModelService 抽象层） |

## 抽象层

- **ModelService** — AI 模型抽象（当前 DeepSeek，可切换 OpenAI/通义）
- **PushService** — 推送抽象（各手表平台实现各自的适配器）
