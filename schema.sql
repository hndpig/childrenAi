-- ================================================================
-- Pet-Habit 数据库初始化脚本 v4.0（微服务拆分版）
-- 每个微服务使用独立 database，共享同一 MySQL 实例
-- 运行: mysql -u root -p < schema.sql
-- ================================================================

-- ================================================================
-- 0. 用户服务 (pet-habit-service-user :8082)
--    数据库: pet_habit_user
--    包含: user_account, user_device, user_parent_child_binding,
--          user_friendship, common_notification, common_notification_preference
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_user CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_user;

-- ================================================================
-- 0.1 用户与家庭（用户服务）
-- ================================================================
-- ================================================================

-- 用户表（家长 + 孩子统一存储，role 区分）
CREATE TABLE IF NOT EXISTS `user_account` (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    phone           VARCHAR(20)   COMMENT '手机号（家长必填，孩子可选）',
    password        VARCHAR(255)  COMMENT 'BCrypt 密文',
    nickname        VARCHAR(50)   COMMENT '昵称',
    avatar_url      VARCHAR(255)  COMMENT '头像 URL',
    role            ENUM('PARENT','CHILD') NOT NULL COMMENT '用户角色',
    wechat_openid   VARCHAR(128)  COMMENT '微信小程序 OpenID（家长登录凭据）',
    wechat_unionid  VARCHAR(128)  COMMENT '微信 UnionID（跨应用关联）',
    enabled         TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '0=禁用 1=启用',
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_wechat_openid (wechat_openid),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表（家长通过微信小程序登录，孩子通过设备平台登录）';

-- 设备绑定表（手表端设备，平台抽象层）
CREATE TABLE IF NOT EXISTS user_device (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '关联 child user.id',
    platform        ENUM('XTC','HUAWEI','XIAOMI','APPLE') NOT NULL COMMENT '手表平台：XTC=小天才',
    device_id       VARCHAR(128) NOT NULL COMMENT '平台内设备唯一标识',
    device_name     VARCHAR(100) COMMENT '设备名称（如"小天才 Z9"）',
    push_token      VARCHAR(512) COMMENT '推送服务 Token（平台 Push SDK 注册所得）',
    is_active       TINYINT(1)  DEFAULT 1 COMMENT '是否为当前活跃设备',
    last_online_at  DATETIME     COMMENT '最近一次在线时间',
    created_at      DATETIME    DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_device (platform, device_id),
    INDEX idx_child (child_id),
    CONSTRAINT fk_device_child FOREIGN KEY (child_id) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备绑定（手表平台抽象层：小天才优先，预留华为/小米/Apple Watch）';

-- 家长-孩子绑定关系（双向：一个家长可绑多个孩子，一个孩子可被多位家长管理）
CREATE TABLE IF NOT EXISTS user_parent_child_binding (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_id   BIGINT NOT NULL COMMENT '家长 user.id',
    child_id    BIGINT NOT NULL COMMENT '孩子 user.id',
    nickname    VARCHAR(50)  COMMENT '家长对孩子的备注昵称',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_parent_child (parent_id, child_id),
    INDEX idx_child (child_id),
    CONSTRAINT fk_binding_parent FOREIGN KEY (parent_id) REFERENCES `user_account`(id),
    CONSTRAINT fk_binding_child  FOREIGN KEY (child_id)  REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='家长-孩子绑定（家庭管理核心表）';

-- ================================================================
-- 2. 好友系统（用户服务）
-- ================================================================

CREATE TABLE IF NOT EXISTS user_friendship (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT NOT NULL COMMENT '发起方 user.id',
    friend_id   BIGINT NOT NULL COMMENT '好友 user.id',
    status      ENUM('PENDING','ACCEPTED','BLOCKED') DEFAULT 'PENDING' COMMENT '好友状态',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_friendship (user_id, friend_id),
    INDEX idx_friend (friend_id),
    CONSTRAINT fk_friendship_user   FOREIGN KEY (user_id)   REFERENCES `user_account`(id),
    CONSTRAINT fk_friendship_friend FOREIGN KEY (friend_id) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='好友关系（蓝牙加好友，云端同步）';

-- ================================================================
-- 1. 宠物服务 (pet-habit-service-pet :8083)
--    数据库: pet_habit_pet
--    包含: pet_species, pet, pet_evolution_log, pet_incubation_task,
--          pet_schedule, pet_skill_def, pet_skill_rel,
--          pet_personality_question, pet_personality_result,
--          pet_ai_conversation, pet_interaction
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_pet CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_pet;

-- ================================================================
-- 1.1 宠物系统（宠物服务）
-- ================================================================

-- 宠物图鉴（所有可获得的宠物种类定义）
CREATE TABLE IF NOT EXISTS pet_species (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(50)  NOT NULL COMMENT '种类名称',
    attribute       ENUM('FIRE','WATER','GRASS','ELECTRIC','GROUND','LIGHT','DARK') NOT NULL COMMENT '固定属性类型',
    description     VARCHAR(500) COMMENT '物种描述',

    -- 基础五维
    base_hp         INT DEFAULT 100 COMMENT '基础 HP',
    base_attack     INT DEFAULT 10  COMMENT '基础攻击',
    base_defense    INT DEFAULT 10  COMMENT '基础防御',
    base_agility    INT DEFAULT 10  COMMENT '基础敏捷',
    base_mp         INT DEFAULT 50  COMMENT '基础蓝耗',

    -- 进化链（JSON 格式，定义各阶段累积经验阈值）
    evolution_chain JSON COMMENT '进化链 JSON: [{"stage":"EGG","exp":0},{"stage":"BABY","exp":500},{"stage":"ADULT","exp":2000},{"stage":"RARE","exp":5000}]',

    -- 阶段内小等级经验阈值（所有阶段通用，5 个值对应 Lv1→Lv2→Lv3→Lv4→Lv5 所需累积经验）
    level_exp_thresholds JSON COMMENT '小等级 EXP 阈值 JSON: [0,200,500,1000,2000]，与 evolution_chain 配合计算经验进度条',

    -- 各阶段美术资源
    egg_sprite_url  VARCHAR(255) COMMENT '蛋形态精灵图 URL',
    baby_sprite_url VARCHAR(255) COMMENT '幼体形态精灵图 URL',
    adult_sprite_url VARCHAR(255) COMMENT '成体形态精灵图 URL',
    rare_sprite_url VARCHAR(255) COMMENT '稀有形态精灵图 URL',

    -- 进化与音效资源
    evolution_animation_url VARCHAR(255) COMMENT '进化演出动画资源 URL',
    sound_set_url   VARCHAR(255) COMMENT '音效资源包 URL（互动/情绪/进化/休眠音效）',

    rarity          ENUM('COMMON','UNCOMMON','RARE','LEGENDARY') DEFAULT 'COMMON' COMMENT '稀有度',
    is_available    TINYINT(1) DEFAULT 1 COMMENT '是否对用户可见（控制蛋池投放）',

    -- 蛋池投放管理（PRD 2.2 首次进入展示 3-5 个蛋供选择）
    available_from_date DATETIME COMMENT '投放开始时间（NULL=不限，到达时间后对用户可见）',
    available_to_date   DATETIME COMMENT '投放结束时间（NULL=不限，过期后从蛋池移除）',
    sort_order          INT DEFAULT 0 COMMENT '蛋池展示排序权重（越小越靠前）',
    generation          VARCHAR(20) COMMENT '投放批次标识（如"GEN1"、"SUMMER2026"，方便按批次管理）',

    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物图鉴（所有可获得宠物种类的元数据）';

-- 宠物实例（用户实际拥有的宠物）
CREATE TABLE IF NOT EXISTS pet (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id            BIGINT NOT NULL COMMENT '所属孩子 user.id',
    species_id          BIGINT COMMENT '对应 pet_species.id',
    name                VARCHAR(50) NOT NULL COMMENT '宠物名字（孩子自定义，同时也是语音唤醒词）',

    -- 阶段与属性
    stage               ENUM('EGG','BABY','ADULT','RARE') NOT NULL DEFAULT 'EGG' COMMENT '进化阶段',
    attribute           ENUM('FIRE','WATER','GRASS','ELECTRIC','GROUND','LIGHT','DARK') NOT NULL COMMENT '属性类型（冗余自 species，查询优化）',
    personality         ENUM('LIVELY','GENTLE','TSUNDERE','DOODLE','BRAVE','PLAYFUL') COMMENT '当前性格（渐变式变化）',

    -- 五维属性（动态成长值）
    hp                  INT DEFAULT 100 COMMENT 'HP 成长值',
    attack              INT DEFAULT 10  COMMENT '攻击成长值',
    defense             INT DEFAULT 10  COMMENT '防御成长值',
    agility             INT DEFAULT 10  COMMENT '敏捷成长值',
    mp                  INT DEFAULT 50  COMMENT '蓝耗成长值',

    -- 对战临时状态（非持久属性，战斗期间有效）
    current_hp          INT COMMENT '当前战斗中 HP',
    current_mp          INT COMMENT '当前战斗中 MP',

    -- 成长系统
    exp                 INT DEFAULT 0  COMMENT '当前经验值',
    level               INT DEFAULT 1  COMMENT '当前阶段内小等级 1-5',

    -- 情绪与状态
    mood                ENUM('EXPECTANT','HAPPY','SAD','SLEEPING') DEFAULT 'EXPECTANT' COMMENT '当前情绪状态',

    -- 孵化追踪
    incubation_progress INT DEFAULT 0  COMMENT '孵化进度 0-100',
    incubation_started_at DATETIME     COMMENT '孵化开始时间',

    -- 活跃状态（一个孩子同时只养一只活跃宠物）
    is_active           TINYINT(1) DEFAULT 1 COMMENT '是否为当前活跃宠物',

    -- 打卡统计（冗余字段，用于快速查询）
    streak_days         INT DEFAULT 0  COMMENT '当前连续打卡天数',
    best_streak         INT DEFAULT 0  COMMENT '历史最佳连续打卡天数',

    -- 懈怠追踪（负反馈机制触发条件）
    idle_days           INT DEFAULT 0  COMMENT '连续未打卡天数',
    is_asleep           TINYINT(1) DEFAULT 0 COMMENT '强制休眠状态（懈怠超过可配置阈值）',

    -- 每日互动/对战上限追踪（PRD 2.4 / 2.11）
    daily_interaction_count INT DEFAULT 0  COMMENT '今日互动次数（聊天/抚摸，每日重置）',
    last_interaction_date   DATE           COMMENT '上次互动日期（跨日清零计数）',
    daily_battle_count      INT DEFAULT 0  COMMENT '今日对战次数（每日重置）',
    last_battle_date        DATE           COMMENT '上次对战日期（跨日清零计数）',

    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    INDEX idx_active (child_id, is_active),
    INDEX idx_species (species_id),
    CONSTRAINT fk_pet_child   FOREIGN KEY (child_id)   REFERENCES `user_account`(id),
    CONSTRAINT fk_pet_species FOREIGN KEY (species_id) REFERENCES pet_species(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物实例（用户养成的具体宠物）';

-- 宠物进化记录
CREATE TABLE IF NOT EXISTS pet_evolution_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL COMMENT '宠物实例 pet.id',
    from_stage      ENUM('EGG','BABY','ADULT','RARE') NOT NULL COMMENT '进化前阶段',
    to_stage        ENUM('BABY','ADULT','RARE') NOT NULL COMMENT '进化后阶段',
    triggered_by    VARCHAR(100) COMMENT '触发条件描述（如"累计达成500经验"）',
    evolved_at      DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '进化时间',
    INDEX idx_pet (pet_id),
    CONSTRAINT fk_evolution_pet FOREIGN KEY (pet_id) REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物进化记录';

-- 宠物孵化任务（家长为孵化期的蛋设置的小任务）
CREATE TABLE IF NOT EXISTS pet_incubation_task (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL COMMENT '宠物实例 pet.id（需处于 EGG 阶段）',
    parent_id       BIGINT NOT NULL COMMENT '创建任务的家长 user.id',
    name            VARCHAR(100) NOT NULL COMMENT '任务名称（如"每天和蛋说一句话"）',
    description     VARCHAR(300) COMMENT '任务说明',
    is_completed    TINYINT(1) DEFAULT 0 COMMENT '是否已完成',
    completed_at    DATETIME    COMMENT '完成时间',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pet (pet_id),
    CONSTRAINT fk_incubation_pet    FOREIGN KEY (pet_id)    REFERENCES pet(id),
    CONSTRAINT fk_incubation_parent FOREIGN KEY (parent_id) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='孵化任务（家长为蛋期设置的加速孵化小任务）';

-- 宠物作息配置（家长设置，避免影响孩子上课/休息）
CREATE TABLE IF NOT EXISTS pet_schedule (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL COMMENT '宠物实例 pet.id',
    schedule_type   ENUM('SCHOOL','REST','SLEEP') NOT NULL COMMENT '时段类型：上课/午休/晚睡',
    start_time      TIME NOT NULL COMMENT '休眠开始时间',
    end_time        TIME NOT NULL COMMENT '苏醒时间',
    days_of_week    VARCHAR(20) COMMENT '生效星期 "1,2,3,4,5"=周一至周五，NULL=每天适用',
    INDEX idx_pet (pet_id),
    CONSTRAINT fk_schedule_pet FOREIGN KEY (pet_id) REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物作息配置（上课休眠/午休/晚间睡眠时段）';

-- ================================================================
-- 4. 技能系统（宠物服务）
-- ================================================================

-- 技能库（所有可学习技能的元数据）
CREATE TABLE IF NOT EXISTS pet_skill_def (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(50)  NOT NULL COMMENT '技能名称',
    type                ENUM('ATTACK','DEFENSE','HEAL','BUFF','DEBUFF') NOT NULL COMMENT '技能类型',
    power               INT DEFAULT 0  COMMENT '技能威力',
    accuracy            INT DEFAULT 100 COMMENT '命中率 %',
    mp_cost             INT DEFAULT 10 COMMENT '蓝耗',
    description         VARCHAR(200)  COMMENT '技能描述',

    -- 解锁条件
    attribute_required  ENUM('FIRE','WATER','GRASS','ELECTRIC','GROUND','LIGHT','DARK') COMMENT '解锁所需宠物属性',
    category_required   ENUM('HYGIENE','STUDY','SPORT','LIFE_SKILL','ROUTINE') COMMENT '解锁所需习惯类别',
    min_difficulty      INT DEFAULT 1  COMMENT '解锁所需最小习惯难度 ⭐1-3',
    min_level           INT DEFAULT 1  COMMENT '解锁所需宠物等级',

    -- 表现资源
    animation_url       VARCHAR(255) COMMENT '技能像素动画资源 URL',
    sound_url           VARCHAR(255) COMMENT '技能音效资源 URL',

    rarity              ENUM('COMMON','UNCOMMON','RARE') DEFAULT 'COMMON' COMMENT '技能稀有度',
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='技能库（所有可学习技能的元数据定义）';

-- 宠物已学技能关联
CREATE TABLE IF NOT EXISTS pet_skill_rel (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL COMMENT '宠物实例 pet.id',
    skill_id        BIGINT NOT NULL COMMENT '技能 skill.id',
    level           INT DEFAULT 1  COMMENT '技能等级',
    learn_order     INT           COMMENT '学习顺序 0-11（最多学12个技能，NULL=尚未纳入排序）',
    is_equipped     TINYINT(1) DEFAULT 0 COMMENT '是否已装备到战斗槽位（最多同时装备4个主动技能）',
    unlocked_at     DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '解锁时间',
    UNIQUE KEY uk_pet_skill (pet_id, skill_id),
    INDEX idx_pet (pet_id),
    INDEX idx_equipped (pet_id, is_equipped),
    CONSTRAINT fk_pet_skill_pet   FOREIGN KEY (pet_id)   REFERENCES pet(id),
    CONSTRAINT fk_pet_skill_skill FOREIGN KEY (skill_id) REFERENCES pet_skill_def(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物技能关联（+12个学习位 learn_order + 4个战斗装备槽 is_equipped）';

-- ================================================================
-- 5. 性格测试（宠物服务）
-- ================================================================

-- 性格测试题库（大五人格儿童版）
CREATE TABLE IF NOT EXISTS pet_personality_question (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    question_text   VARCHAR(500) NOT NULL COMMENT '题目文本',
    options_json    JSON NOT NULL COMMENT '选项列表 JSON: [{"text":"非常同意","dimension":"O","score":5},...]',
    dimension       ENUM('O','C','E','A','N') NOT NULL COMMENT '大五人格维度：O=开放性 C=尽责性 E=外向性 A=宜人性 N=神经质',
    version         INT DEFAULT 1  COMMENT '题库版本号（支持持续迭代）',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='性格测试题库（大五人格儿童版，持续迭代）';

-- 性格测试结果
CREATE TABLE IF NOT EXISTS pet_personality_result (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '被测孩子 user.id',
    pet_id          BIGINT COMMENT '关联的宠物（选蛋后测试，测试完成后创建宠物）',
    answers_json    JSON NOT NULL COMMENT '答题记录 JSON: [{"questionId":1,"selectedIndex":2},...]',
    result_type     ENUM('LIVELY','GENTLE','TSUNDERE','DOODLE','BRAVE','PLAYFUL') NOT NULL COMMENT '测试结果性格',
    dimension_scores JSON COMMENT '各维度得分 {"O":85,"C":60,"E":70,"A":80,"N":40}',
    tested_at       DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '测试时间',
    INDEX idx_child (child_id),
    CONSTRAINT fk_personality_child FOREIGN KEY (child_id) REFERENCES `user_account`(id),
    CONSTRAINT fk_personality_pet   FOREIGN KEY (pet_id)   REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='性格测试结果（领养前测试，结果决定宠物初始性格）';

-- ================================================================
-- 2. 习惯服务 (pet-habit-service-habit :8084)
--    数据库: pet_habit_habit
--    包含: habit_template, habit, habit_log
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_habit CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_habit;

-- ================================================================
-- 2.1 习惯系统（习惯服务）
-- ================================================================

-- 习惯模板（预设模板库，家长可直接选用或参考）
CREATE TABLE IF NOT EXISTS habit_template (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL COMMENT '模板名称',
    description     VARCHAR(500) COMMENT '模板描述',
    category        ENUM('HYGIENE','STUDY','SPORT','LIFE_SKILL','ROUTINE') NOT NULL COMMENT '习惯分类',
    difficulty      INT DEFAULT 1  COMMENT '默认难度系数 ⭐1-3',
    frequency_type  ENUM('ONCE','DAILY','WEEKLY','CUSTOM') DEFAULT 'DAILY' COMMENT '执行频率类型：单次/每天/每周X次/自定义',
    frequency_value INT DEFAULT 1  COMMENT '频率值（如每周N次）',
    remind_times    JSON          COMMENT '默认提醒时段 ["07:30","20:00"]',
    require_review  TINYINT(1) DEFAULT 1 COMMENT '是否默认需要家长审核',
    icon_url        VARCHAR(255)  COMMENT '习惯图标 URL',
    sort_order      INT DEFAULT 0  COMMENT '排序权重',
    is_active       TINYINT(1) DEFAULT 1 COMMENT '是否启用',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='习惯模板（预设习惯库，家长可选用快速创建）';

-- 习惯定义（家长为孩子自定义的习惯）
CREATE TABLE IF NOT EXISTS habit (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_id       BIGINT NOT NULL COMMENT '创建者（家长 user.id）',
    child_id        BIGINT NOT NULL COMMENT '执行孩子 user.id',
    template_id     BIGINT       COMMENT '来源模板 habit_template.id（NULL=纯自定义）',
    name            VARCHAR(100) NOT NULL COMMENT '习惯名称',
    description     VARCHAR(500) COMMENT '习惯描述',
    category        ENUM('HYGIENE','STUDY','SPORT','LIFE_SKILL','ROUTINE') NOT NULL COMMENT '习惯分类',
    difficulty      INT DEFAULT 1  COMMENT '难度系数 ⭐1-3（影响积分/经验计算）',
    frequency_type  ENUM('ONCE','DAILY','WEEKLY','CUSTOM') DEFAULT 'DAILY' COMMENT '执行频率类型：单次/每天/每周X次/自定义',
    frequency_value INT DEFAULT 1  COMMENT '频率值（如每周3次）',
    remind_times    JSON          COMMENT '提醒时段列表 ["07:30","20:00"]',
    require_review  TINYINT(1) DEFAULT 1 COMMENT '是否需要家长审核',
    is_active       TINYINT(1) DEFAULT 1 COMMENT '是否启用',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    INDEX idx_parent_child (parent_id, child_id),
    INDEX idx_category (child_id, category),
    CONSTRAINT fk_habit_parent   FOREIGN KEY (parent_id)   REFERENCES `user_account`(id),
    CONSTRAINT fk_habit_child    FOREIGN KEY (child_id)    REFERENCES `user_account`(id),
    CONSTRAINT fk_habit_template FOREIGN KEY (template_id) REFERENCES habit_template(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='习惯定义（家长自定义，按孩子分配）';

-- 习惯打卡记录
CREATE TABLE IF NOT EXISTS habit_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    habit_id        BIGINT NOT NULL COMMENT '习惯 habit.id',
    child_id        BIGINT NOT NULL COMMENT '执行孩子 user.id',
    date            DATE NOT NULL COMMENT '打卡日期',
    status          ENUM('PENDING','APPROVED','REJECTED') DEFAULT 'PENDING' COMMENT '审核状态',
    reviewed_by     BIGINT       COMMENT '审核人（家长 user.id）',
    reviewed_at     DATETIME     COMMENT '审核时间',
    reject_reason   VARCHAR(200) COMMENT '驳回原因',
    auto_approved   TINYINT(1) DEFAULT 0 COMMENT '是否超时自动通过（家长未在时限内审核）',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '打卡时间',
    UNIQUE KEY uk_habit_date (habit_id, date),
    INDEX idx_child_date (child_id, date),
    INDEX idx_status (status, created_at),
    INDEX idx_reviewed (status, reviewed_by, reviewed_at),
    CONSTRAINT fk_habit_log_habit    FOREIGN KEY (habit_id)    REFERENCES habit(id),
    CONSTRAINT fk_habit_log_child    FOREIGN KEY (child_id)    REFERENCES `user_account`(id),
    CONSTRAINT fk_habit_log_reviewer FOREIGN KEY (reviewed_by) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='习惯打卡记录（打卡→待审核→通过/驳回/超时自动通过）';

-- ================================================================
-- 3. 积分兑换服务 (pet-habit-service-reward :8085)
--    数据库: pet_habit_reward
--    包含: reward_point_account, reward_point_transaction, reward_item,
--          reward_redemption, reward_achievement, reward_user_achievement
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_reward CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_reward;

-- ================================================================
-- 3.1 积分与兑换（积分兑换服务）
-- ================================================================

-- 积分账户
CREATE TABLE IF NOT EXISTS reward_point_account (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL UNIQUE COMMENT '所属孩子 user.id',
    balance         INT DEFAULT 0  COMMENT '当前可用积分',
    total_earned    INT DEFAULT 0  COMMENT '累计获取积分',
    total_spent     INT DEFAULT 0  COMMENT '累计消费积分',
    reset_cycle     ENUM('MONTHLY','QUARTERLY','SEMESTER','MANUAL') DEFAULT 'MANUAL' COMMENT '积分清零周期（家长自行设置）',
    last_reset_at   DATETIME      COMMENT '最近清零时间',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    CONSTRAINT fk_point_account_child FOREIGN KEY (child_id) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='积分账户（一对一关联孩子，独立货币体系）';

-- 积分流水
CREATE TABLE IF NOT EXISTS reward_point_transaction (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '所属孩子 user.id',
    amount          INT NOT NULL COMMENT '变动金额（正数=收入，负数=支出）',
    type            ENUM('HABIT_REWARD','STREAK_BONUS','REDEEM','RESET','ADJUST') NOT NULL COMMENT '交易类型',
    description     VARCHAR(200)  COMMENT '交易说明',
    related_id      BIGINT        COMMENT '关联业务 ID（habit_log.id / redemption.id）',
    before_balance  INT DEFAULT 0 COMMENT '交易前余额（审计用）',
    after_balance   INT DEFAULT 0 COMMENT '交易后余额（审计用）',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    INDEX idx_created (child_id, created_at),
    INDEX idx_type (type),
    CONSTRAINT fk_point_txn_child FOREIGN KEY (child_id) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='积分流水（完整收支记录，支持审计追踪）';

-- 奖励池（家长设置的可兑换奖励）
CREATE TABLE IF NOT EXISTS reward_item (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_id       BIGINT NOT NULL COMMENT '设置奖励的家长 user.id',
    child_id        BIGINT       COMMENT '限定兑换人（NULL=该家长下所有孩子均可兑）',
    name            VARCHAR(100) NOT NULL COMMENT '奖励名称',
    description     VARCHAR(500) COMMENT '奖励描述',
    cost            INT NOT NULL COMMENT '所需积分价格',
    type            ENUM('TIME','ACTIVITY','ITEM') NOT NULL COMMENT '奖励类型：时间/活动/实物',
    stock           INT DEFAULT -1 COMMENT '库存（-1=无限兑换，>=0=有限次数）',
    redeem_method   ENUM('AUTO','MANUAL') DEFAULT 'MANUAL' COMMENT '兑现方式：自动生效/家长手动兑现',
    is_active       TINYINT(1) DEFAULT 1 COMMENT '是否上架',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_parent (parent_id),
    INDEX idx_child (child_id),
    INDEX idx_active (parent_id, is_active),
    CONSTRAINT fk_reward_parent FOREIGN KEY (parent_id) REFERENCES `user_account`(id),
    CONSTRAINT fk_reward_child  FOREIGN KEY (child_id)  REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='奖励池（家长设置，孩子浏览兑换）';

-- 兑换记录
CREATE TABLE IF NOT EXISTS reward_redemption (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '兑换孩子 user.id',
    reward_id       BIGINT NOT NULL COMMENT '奖励 reward.id',
    status          ENUM('PENDING','APPROVED','REJECTED','FULFILLED') DEFAULT 'PENDING' COMMENT '兑换状态',
    cost            INT NOT NULL COMMENT '兑换时积分价格（冗余，防止奖励价格变动后历史数据失准）',
    reviewed_by     BIGINT       COMMENT '审核家长 user.id',
    reviewed_at     DATETIME     COMMENT '审核时间',
    reject_reason   VARCHAR(200) COMMENT '拒绝原因',
    fulfilled_at    DATETIME     COMMENT '兑现时间（家长手动兑现时更新）',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '兑换申请时间',
    INDEX idx_child (child_id),
    INDEX idx_status (status),
    INDEX idx_child_status (child_id, status),
    CONSTRAINT fk_redemption_child    FOREIGN KEY (child_id)    REFERENCES `user_account`(id),
    CONSTRAINT fk_redemption_reward   FOREIGN KEY (reward_id)   REFERENCES reward_item(id),
    CONSTRAINT fk_redemption_reviewer FOREIGN KEY (reviewed_by) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兑换记录（孩子申请→家长审核→兑现）';

-- ================================================================
-- 4. 对战服务 (pet-habit-service-battle :8086)
--    数据库: pet_habit_battle
--    包含: battle_record, battle_round
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_battle CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_battle;

-- ================================================================
-- 4.1 对战系统（对战服务）
-- ================================================================

-- 对战记录
CREATE TABLE IF NOT EXISTS battle_record (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    initiator_id        BIGINT NOT NULL COMMENT '发起方 child_id',
    opponent_id         BIGINT NOT NULL COMMENT '对手 child_id',
    initiator_pet_id    BIGINT       COMMENT '发起方使用的宠物 pet.id',
    opponent_pet_id     BIGINT       COMMENT '对手使用的宠物 pet.id',
    winner_id           BIGINT       COMMENT '胜方 child_id（NULL=平局）',
    battle_type         ENUM('BLUETOOTH','FRIENDLY') DEFAULT 'BLUETOOTH' COMMENT '对战类型：蓝牙本地对战/好友异步对战',
    battle_status       ENUM('INVITED','ACCEPTED','DECLINED','ONGOING','COMPLETED','DRAW') DEFAULT 'COMPLETED' COMMENT '对战状态：异步对战邀请→接受/拒绝→进行中→完成/平局',
    total_rounds        INT DEFAULT 0 COMMENT '总回合数',
    battled_at          DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '对战时间',
    INDEX idx_initiator (initiator_id),
    INDEX idx_opponent (opponent_id),
    INDEX idx_winner (winner_id),
    INDEX idx_battled_at (battled_at),
    CONSTRAINT fk_battle_initiator     FOREIGN KEY (initiator_id)     REFERENCES `user_account`(id),
    CONSTRAINT fk_battle_opponent      FOREIGN KEY (opponent_id)      REFERENCES `user_account`(id),
    CONSTRAINT fk_battle_initiator_pet FOREIGN KEY (initiator_pet_id) REFERENCES pet(id),
    CONSTRAINT fk_battle_opponent_pet  FOREIGN KEY (opponent_pet_id)  REFERENCES pet(id),
    CONSTRAINT fk_battle_winner        FOREIGN KEY (winner_id)        REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='对战记录（蓝牙本地对战/好友异步对战）';

-- 对战回合详情
CREATE TABLE IF NOT EXISTS battle_round (
    id                      BIGINT AUTO_INCREMENT PRIMARY KEY,
    battle_id               BIGINT NOT NULL COMMENT '对战 battle_record.id',
    round_number            INT NOT NULL COMMENT '回合序号 1,2,3...',
    attacker_id             BIGINT NOT NULL COMMENT '出招方 child_id',
    skill_id                BIGINT       COMMENT '使用的技能 skill.id',
    damage                  INT DEFAULT 0 COMMENT '造成的伤害值',
    attacker_hp_remaining   INT          COMMENT '出招方剩余 HP',
    defender_hp_remaining   INT          COMMENT '受击方剩余 HP',
    INDEX idx_battle (battle_id),
    CONSTRAINT fk_round_battle   FOREIGN KEY (battle_id)   REFERENCES battle_record(id),
    CONSTRAINT fk_round_attacker FOREIGN KEY (attacker_id)  REFERENCES `user_account`(id),
    CONSTRAINT fk_round_skill    FOREIGN KEY (skill_id)     REFERENCES pet_skill_def(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='对战回合详情（回合制逐回合记录）';

-- ================================================================
-- 9. 宠物互动记录（宠物服务）
-- ================================================================

-- 宠物串门互动记录（同家庭多孩之间的宠物互动）
CREATE TABLE IF NOT EXISTS pet_interaction (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    initiator_pet_id    BIGINT NOT NULL COMMENT '发起方宠物 pet.id',
    receiver_pet_id     BIGINT NOT NULL COMMENT '接收方宠物 pet.id',
    interaction_type    ENUM('VISIT','FRIENDLY_BATTLE') DEFAULT 'VISIT' COMMENT '互动类型：串门/好友对战',
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '互动时间',
    INDEX idx_initiator (initiator_pet_id),
    INDEX idx_receiver (receiver_pet_id),
    INDEX idx_created (created_at),
    CONSTRAINT fk_interaction_initiator FOREIGN KEY (initiator_pet_id) REFERENCES pet(id),
    CONSTRAINT fk_interaction_receiver  FOREIGN KEY (receiver_pet_id)  REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物互动记录（同家庭多孩宠物串门/对战）';

-- ================================================================
-- 10. 成就系统（积分兑换服务）
-- ================================================================

-- 成就定义
CREATE TABLE IF NOT EXISTS reward_achievement (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL COMMENT '成就名称',
    description     VARCHAR(300) COMMENT '成就描述',
    icon_url        VARCHAR(255) COMMENT '成就图标 URL',
    condition_type  ENUM('STREAK_DAYS','TOTAL_HABITS','PET_EVOLVED','BATTLE_WINS','SKILLS_UNLOCKED','POINTS_EARNED') NOT NULL COMMENT '达成条件类型',
    condition_value INT NOT NULL COMMENT '触发阈值（如连续打卡7天则值为7）',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成就定义（条件达成自动解锁）';

-- 用户成就
CREATE TABLE IF NOT EXISTS reward_user_achievement (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '获得成就的孩子 user.id',
    achievement_id  BIGINT NOT NULL COMMENT '成就 achievement.id',
    unlocked_at     DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '解锁时间',
    UNIQUE KEY uk_user_achieve (child_id, achievement_id),
    INDEX idx_child (child_id),
    CONSTRAINT fk_user_achieve_child  FOREIGN KEY (child_id)       REFERENCES `user_account`(id),
    CONSTRAINT fk_user_achieve_ach    FOREIGN KEY (achievement_id) REFERENCES reward_achievement(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户成就（记录孩子获得的成就勋章）';

-- ================================================================
-- 11. AI 对话与通知（AI 服务 + 推送服务）
-- ================================================================

-- AI 对话历史（敏感数据：儿童语音/文字对话记录）
CREATE TABLE IF NOT EXISTS pet_ai_conversation (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '对话孩子 user.id --敏感字段',
    pet_id          BIGINT       COMMENT '当前对话宠物 pet.id',
    role            ENUM('USER','ASSISTANT','SYSTEM') NOT NULL COMMENT '消息角色',
    content         TEXT NOT NULL COMMENT '对话内容 --敏感字段（儿童隐私）',
    safety_filtered TINYINT(1) DEFAULT 0 COMMENT '是否触发了安全过滤（内容被拦截/替换）',
    filter_reason   VARCHAR(100) COMMENT '过滤原因：PROFANITY=敏感词，TOPIC_BOUNDARY=话题边界，LEADING_QUESTION=诱导性问题',
    model_used      VARCHAR(50)  COMMENT '使用的 AI 模型（DeepSeek/OpenAI 等，模型抽象层记录）',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '消息时间（自动清理超过30天的记录，见文件末尾清理策略）',
    INDEX idx_child_pet (child_id, pet_id),
    INDEX idx_created (created_at),
    INDEX idx_child_created (child_id, created_at),
    CONSTRAINT fk_ai_conv_child FOREIGN KEY (child_id) REFERENCES `user_account`(id),
    CONSTRAINT fk_ai_conv_pet   FOREIGN KEY (pet_id)   REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI对话历史（儿童隐私数据，仅保留最近30天）';

-- 通知/推送记录
CREATE TABLE IF NOT EXISTS common_notification (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id         BIGINT NOT NULL COMMENT '接收用户 user.id',
    type            ENUM('HABIT_REMIND','REVIEW_ALERT','REDEEM_ALERT','MOOD_PUSH','BATTLE_INVITE','PET_AWAKE','PET_SLEEP','STREAK_MILESTONE','FRIEND_REQUEST') NOT NULL COMMENT '通知类型',
    title           VARCHAR(200)  COMMENT '通知标题',
    body            VARCHAR(500)  COMMENT '通知正文',
    related_id      BIGINT        COMMENT '关联业务 ID（habit_log.id / redemption.id / battle_record.id 等）',
    is_read         TINYINT(1) DEFAULT 0 COMMENT '是否已读',
    push_status     ENUM('PENDING','SENT','FAILED') DEFAULT 'PENDING' COMMENT '推送发送状态',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    INDEX idx_user (user_id, created_at),
    INDEX idx_unread (user_id, is_read, created_at),
    INDEX idx_type (type),
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='通知记录（习惯提醒/审核通知/情绪推送/对战通知）';

-- 用户通知偏好设置（PRD 5.1 家长端"通知偏好"）
CREATE TABLE IF NOT EXISTS common_notification_preference (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id             BIGINT NOT NULL UNIQUE COMMENT '用户 user.id',
    habit_remind        TINYINT(1) DEFAULT 1 COMMENT '习惯提醒推送开关',
    review_alert        TINYINT(1) DEFAULT 1 COMMENT '审核通知推送开关',
    redeem_alert        TINYINT(1) DEFAULT 1 COMMENT '兑换申请通知推送开关',
    mood_push           TINYINT(1) DEFAULT 1 COMMENT '宠物情绪推送开关',
    battle_invite       TINYINT(1) DEFAULT 1 COMMENT '对战邀请推送开关',
    pet_awake           TINYINT(1) DEFAULT 1 COMMENT '宠物苏醒推送开关',
    pet_sleep           TINYINT(1) DEFAULT 1 COMMENT '宠物休眠推送开关',
    streak_milestone    TINYINT(1) DEFAULT 1 COMMENT '连续打卡里程碑推送开关',
    friend_request      TINYINT(1) DEFAULT 1 COMMENT '好友申请推送开关',
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_pref_user FOREIGN KEY (user_id) REFERENCES `user_account`(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户通知偏好设置（家长/孩子均可按类型开关推送）';

-- ================================================================
-- 5. 系统配置服务 (pet-habit-service-config :8087)
--    数据库: pet_habit_config
--    包含: config_system, config_streak_bonus
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_config CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_config;

-- ================================================================
-- 5.1 系统配置
-- ================================================================

-- 系统配置表（key-value 通用配置，积分/经验计算规则等）
CREATE TABLE IF NOT EXISTS config_system (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    config_key      VARCHAR(100) NOT NULL COMMENT '配置键',
    config_value    VARCHAR(500) NOT NULL COMMENT '配置值',
    value_type      ENUM('STRING','INTEGER','DECIMAL','BOOLEAN','JSON') DEFAULT 'STRING' COMMENT '值类型（前端/后端按类型反序列化）',
    description     VARCHAR(300) COMMENT '配置项说明',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统配置（key-value 通用表，存储积分/经验计算规则、业务阈值等）';

-- 连续打卡加成阶梯配置（PRD 2.4 连续打卡加成: Day1-2=1.0x, Day3-6=1.2x, Day7-13=1.5x, Day14-29=2.0x, Day30+=3.0x）
CREATE TABLE IF NOT EXISTS config_streak_bonus (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(50) NOT NULL COMMENT '阶梯名称（如"坚持新手"、"习惯养成"）',
    min_days            INT NOT NULL COMMENT '起始天数（含）',
    max_days            INT NOT NULL COMMENT '结束天数（含，999=无上限）',
    xp_multiplier       DECIMAL(3,1) DEFAULT 1.0 COMMENT '经验加成倍率',
    point_multiplier    DECIMAL(3,1) DEFAULT 1.0 COMMENT '积分加成倍率',
    description         VARCHAR(200) COMMENT '阶梯说明',
    sort_order          INT DEFAULT 0 COMMENT '排序权重',
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_day_range (min_days, max_days)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='连续打卡加成阶梯配置（PRD 2.4，支持动态调整加成规则）';

-- ================================================================
-- 初始化默认数据
-- ================================================================

-- 预设习惯模板
INSERT INTO habit_template (name, description, category, difficulty, frequency_type, frequency_value, remind_times, require_review, sort_order) VALUES
('早晚刷牙', '每天早晚各刷一次牙，保护牙齿健康', 'HYGIENE', 1, 'DAILY', 1, '["07:30","20:00"]', 1, 1),
('饭前洗手', '吃饭前用肥皂洗手', 'HYGIENE', 1, 'DAILY', 1, '["12:00","18:30"]', 1, 2),
('自己洗澡', '学会自己洗澡，保持身体清洁', 'HYGIENE', 2, 'DAILY', 1, '["20:00"]', 1, 3),
('背单词', '每天背5个英语单词', 'STUDY', 2, 'DAILY', 1, '["16:30"]', 1, 4),
('课外阅读', '每天阅读课外书20分钟', 'STUDY', 2, 'DAILY', 1, '["19:00"]', 0, 5),
('练字', '每天练字10分钟', 'STUDY', 2, 'DAILY', 1, '["16:30"]', 0, 6),
('户外活动', '每天户外活动30分钟', 'SPORT', 2, 'DAILY', 1, '["15:30"]', 0, 7),
('跳绳', '每天跳绳100下', 'SPORT', 2, 'DAILY', 1, '["16:00"]', 0, 8),
('整理书包', '每天自己整理书包', 'LIFE_SKILL', 3, 'DAILY', 1, '["20:30"]', 1, 9),
('帮忙做家务', '帮忙扫地/擦桌子/收拾玩具', 'LIFE_SKILL', 3, 'WEEKLY', 3, '["10:00"]', 1, 10),
('按时睡觉', '晚上9点前上床睡觉', 'ROUTINE', 2, 'DAILY', 1, '["20:45"]', 1, 11),
('按时起床', '早上7点前起床', 'ROUTINE', 2, 'DAILY', 1, '["06:50"]', 0, 12),
('练习画画', '每天画画或做手工15分钟', 'ROUTINE', 1, 'WEEKLY', 3, '["16:00"]', 0, 13);

-- 预设宠物物种（MVP 选蛋流程需要 3-5 个蛋供选择，PRD 2.2）
INSERT INTO pet_species (name, attribute, description, base_hp, base_attack, base_defense, base_agility, base_mp, rarity, evolution_chain, level_exp_thresholds, available_from_date, available_to_date, sort_order, generation) VALUES
('焰爪崽', 'FIRE',    '一只充满活力的小火兽，爪子闪烁着温暖的火焰。性格热情开朗，喜欢和小朋友一起冒险。',   100, 12, 8,  10, 50, 'COMMON',
 '[{"stage":"EGG","exp":0},{"stage":"BABY","exp":500},{"stage":"ADULT","exp":2000},{"stage":"RARE","exp":5000}]', '[0,200,500,1000,2000]', NOW(), NULL, 1, 'GEN1'),
('泡泡豚', 'WATER',   '喜欢吐泡泡的水系宠物，圆滚滚的身体像一颗大水珠。性格温和友善，是最贴心的伙伴。',       110, 8,  10, 12, 55, 'COMMON',
 '[{"stage":"EGG","exp":0},{"stage":"BABY","exp":500},{"stage":"ADULT","exp":2000},{"stage":"RARE","exp":5000}]', '[0,200,500,1000,2000]', NOW(), NULL, 2, 'GEN1'),
('萌芽龙', 'GRASS',   '背上长出嫩芽的小龙，热爱阳光和雨露。性格安静沉稳，但偶尔也会调皮地甩甩尾巴。',        105, 10, 10, 10, 50, 'COMMON',
 '[{"stage":"EGG","exp":0},{"stage":"BABY","exp":500},{"stage":"ADULT","exp":2000},{"stage":"RARE","exp":5000}]', '[0,200,500,1000,2000]', NOW(), NULL, 3, 'GEN1'),
('闪电狐', 'ELECTRIC','毛发间跳跃着细小电弧的机灵小狐狸。性格聪明伶俐，动作敏捷，电光一闪就不见了踪影。',      95, 14, 6,  15, 45, 'UNCOMMON',
 '[{"stage":"EGG","exp":0},{"stage":"BABY","exp":500},{"stage":"ADULT","exp":2000},{"stage":"RARE","exp":5000}]', '[0,200,500,1000,2000]', NOW(), NULL, 4, 'GEN1'),
('岩壳龟', 'GROUND',  '背负坚硬岩壳的稳重小龟，防御力出众。性格老实憨厚，虽然走得慢但从不放弃。',             120, 8,  14, 6,  60, 'COMMON',
 '[{"stage":"EGG","exp":0},{"stage":"BABY","exp":500},{"stage":"ADULT","exp":2000},{"stage":"RARE","exp":5000}]', '[0,200,500,1000,2000]', NOW(), NULL, 5, 'GEN1');

-- 预设技能库（对战系统需要预定义技能，PRD 2.11，覆盖五种技能类型和全部属性）
-- ATTACK 类 — 攻击技能（按宠物属性解锁）
INSERT INTO skill (name, type, power, accuracy, mp_cost, description, attribute_required, category_required, min_difficulty, min_level, rarity) VALUES
('火焰冲击', 'ATTACK', 60, 95, 15, '释放炽热的火焰冲击对手',        'FIRE',     NULL, 1, 1, 'COMMON'),
('水枪喷射', 'ATTACK', 55, 95, 12, '喷射高压水流攻击对手',           'WATER',    NULL, 1, 1, 'COMMON'),
('藤鞭抽打', 'ATTACK', 50, 100,10, '用坚韧的藤鞭抽打对手',           'GRASS',    NULL, 1, 1, 'COMMON'),
('电击',     'ATTACK', 55, 95, 12, '释放电流麻痹对手',               'ELECTRIC', NULL, 1, 1, 'COMMON'),
('落石',     'ATTACK', 50, 90, 10, '召唤岩石砸向对手',               'GROUND',   NULL, 1, 1, 'COMMON'),
('光之射线', 'ATTACK', 60, 95, 15, '凝聚光芒射出高能射线',           'LIGHT',    NULL, 1, 1, 'COMMON'),
('暗影突袭', 'ATTACK', 65, 90, 18, '潜入暗影中突然发起袭击',         'DARK',     NULL, 1, 1, 'COMMON'),
('地震',     'ATTACK', 70, 85, 20, '引发剧烈地震，造成大范围伤害',    'GROUND',   NULL, 3, 3, 'RARE');

-- DEFENSE 类 — 防御技能
INSERT INTO skill (name, type, power, accuracy, mp_cost, description, attribute_required, category_required, min_difficulty, min_level, rarity) VALUES
('火焰护盾', 'DEFENSE', 30, 100, 15, '用火焰包裹全身，减少受到的伤害',  'FIRE',  NULL,        1, 1, 'COMMON'),
('水之屏障', 'DEFENSE', 35, 100, 15, '召唤水幕屏障抵御攻击',            'WATER', NULL,        1, 1, 'COMMON'),
('光之守护', 'DEFENSE', 30, 100, 15, '以光芒编织护盾守护自身',          'LIGHT', NULL,        1, 1, 'COMMON'),
('暗影护甲', 'DEFENSE', 35, 100, 15, '暗影能量凝聚成坚固护甲',          'DARK',  NULL,        1, 1, 'COMMON');

-- HEAL 类 — 恢复技能（按习惯类别解锁）
INSERT INTO skill (name, type, power, accuracy, mp_cost, description, attribute_required, category_required, min_difficulty, min_level, rarity) VALUES
('快速恢复', 'HEAL', 40, 100, 20, '加速自愈，恢复一定 HP',        NULL, 'HYGIENE', 1, 1, 'COMMON'),
('能量小憩', 'HEAL', 50, 100, 25, '小憩片刻，恢复较多 HP 和 MP',    NULL, 'ROUTINE', 2, 2, 'UNCOMMON');

-- BUFF 类 — 增益技能
INSERT INTO skill (name, type, power, accuracy, mp_cost, description, attribute_required, category_required, min_difficulty, min_level, rarity) VALUES
('专注',     'BUFF', 20, 100, 10, '集中精神，提升攻击力',          NULL, 'STUDY',     1, 1, 'COMMON'),
('敏捷提升', 'BUFF', 20, 100, 10, '激发速度潜能，提升敏捷属性',    NULL, 'SPORT',     1, 1, 'COMMON');

-- DEBUFF 类 — 减益技能
INSERT INTO skill (name, type, power, accuracy, mp_cost, description, attribute_required, category_required, min_difficulty, min_level, rarity) VALUES
('烟幕',     'DEBUFF', 15, 90, 8,  '释放烟雾干扰对手，降低命中率',  NULL, 'SPORT',      1, 1, 'COMMON'),
('威吓',     'DEBUFF', 15, 90, 8,  '发出威吓咆哮，降低对手攻击力',  NULL, 'LIFE_SKILL', 2, 1, 'COMMON');

-- 预设成就
INSERT INTO achievement (name, description, condition_type, condition_value) VALUES
('坚持小达人', '连续打卡3天', 'STREAK_DAYS', 3),
('习惯小标兵', '连续打卡7天', 'STREAK_DAYS', 7),
('自律小冠军', '连续打卡21天', 'STREAK_DAYS', 21),
('金牌习惯家', '连续打卡30天', 'STREAK_DAYS', 30),
('初次完成任务', '完成第1个习惯', 'TOTAL_HABITS', 1),
('任务小能手', '累计完成10个习惯', 'TOTAL_HABITS', 10),
('习惯达人', '累计完成50个习惯', 'TOTAL_HABITS', 50),
('习惯大师', '累计完成100个习惯', 'TOTAL_HABITS', 100),
('初次进化', '宠物首次进化', 'PET_EVOLVED', 1),
('胜利初体验', '对战首次胜利', 'BATTLE_WINS', 1),
('对战高手', '对战胜利10次', 'BATTLE_WINS', 10),
('技能初学者', '解锁第1个技能', 'SKILLS_UNLOCKED', 1),
('技能收集家', '解锁5个技能', 'SKILLS_UNLOCKED', 5),
('积分新星', '累计获得100积分', 'POINTS_EARNED', 100),
('积分富翁', '累计获得500积分', 'POINTS_EARNED', 500);

-- 系统配置（积分/经验计算规则、业务阈值，PRD 4.1 + 2.4）
INSERT INTO system_config (config_key, config_value, value_type, description) VALUES
('DIFFICULTY_1_BASE_XP',          '10',   'INTEGER', '难度1（⭐）基础经验值'),
('DIFFICULTY_1_BASE_POINTS',      '5',    'INTEGER', '难度1（⭐）基础积分'),
('DIFFICULTY_2_BASE_XP',          '30',   'INTEGER', '难度2（⭐⭐）基础经验值'),
('DIFFICULTY_2_BASE_POINTS',      '15',   'INTEGER', '难度2（⭐⭐）基础积分'),
('DIFFICULTY_3_BASE_XP',          '60',   'INTEGER', '难度3（⭐⭐⭐）基础经验值'),
('DIFFICULTY_3_BASE_POINTS',      '30',   'INTEGER', '难度3（⭐⭐⭐）基础积分'),
('DAILY_INTERACTION_XP_LIMIT',    '50',   'INTEGER', '每日互动（聊天/抚摸）经验值上限'),
('DAILY_BATTLE_LIMIT',            '5',    'INTEGER', '每日对战次数上限'),
('REVIEW_TIMEOUT_MINUTES',        '120',  'INTEGER', '打卡审核超时分钟数（超时自动通过）'),
('IDLE_TRIGGER_DAYS',             '2',    'INTEGER', '懈怠触发天数（连续未打卡N天后触发负反馈）');

-- 连续打卡加成阶梯（PRD 2.4: Day1-2=1.0x, Day3-6=1.2x, Day7-13=1.5x, Day14-29=2.0x, Day30+=3.0x）
INSERT INTO streak_bonus_config (name, min_days, max_days, xp_multiplier, point_multiplier, description, sort_order) VALUES
('坚持新手', 1,  2,  1.0, 1.0, 'Day1-2 基础加成（1.0x = 无加成）',  1),
('习惯初成', 3,  6,  1.2, 1.2, 'Day3-6 轻度连续打卡加成',            2),
('稳定习惯', 7,  13, 1.5, 1.5, 'Day7-13 稳定习惯养成加成',           3),
('优秀坚持', 14, 29, 2.0, 2.0, 'Day14-29 持续坚持高倍率加成',        4),
('自律达人', 30, 999,3.0, 3.0, 'Day30+ 顶级连续打卡加成（999=无上限）', 5);

-- ================================================================
-- 6. 网关审计 (pet-habit-gateway :8081)
--    数据库: pet_habit_gateway
--    包含: gateway_api_log_config, gateway_api_audit_log
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_gateway CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_gateway;

-- ================================================================
-- 6.1 API 网关审计（网关服务直接写入）
-- ================================================================

-- 接口记录配置（控制哪些路径需要记录报文）
CREATE TABLE IF NOT EXISTS gateway_api_log_config (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    path_pattern    VARCHAR(200) NOT NULL COMMENT '路径模式，支持*通配，如 /api/habit/*',
    log_request     TINYINT(1) DEFAULT 1 COMMENT '是否记录请求体',
    log_response    TINYINT(1) DEFAULT 1 COMMENT '是否记录响应体',
    max_body_size   INT DEFAULT 4096 COMMENT 'body 上限(字节)，默认4KB',
    is_active       TINYINT(1) DEFAULT 1 COMMENT '0=停用 1=启用',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_path (path_pattern),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='API报文记录配置（控制哪些接口需要审计）';

-- 接口审计记录（请求+响应报文，异步写入）
CREATE TABLE IF NOT EXISTS gateway_api_audit_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    trace_id        VARCHAR(32)  COMMENT '链路追踪 ID',
    user_id         BIGINT       COMMENT '操作人 user.id（未登录为 NULL）',
    method          VARCHAR(10)  NOT NULL COMMENT 'HTTP 方法',
    path            VARCHAR(500) NOT NULL COMMENT '请求路径',
    query_string    VARCHAR(1000) COMMENT 'URL 查询参数',
    status_code     INT          COMMENT 'HTTP 状态码',
    duration_ms     INT          COMMENT '耗时(毫秒)',
    request_body    TEXT         COMMENT '请求体（已脱敏，超过上限截断）',
    response_body   TEXT         COMMENT '响应体（已脱敏，超过上限截断）',
    client_ip       VARCHAR(45)  COMMENT '客户端 IP',
    user_agent      VARCHAR(500) COMMENT 'User-Agent',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    INDEX idx_created (created_at),
    INDEX idx_user (user_id),
    INDEX idx_path (path(100)),
    INDEX idx_trace (trace_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='API审计记录（请求+响应报文，异步写入，保留90天）';

-- 默认配置：核心业务接口记录报文
INSERT INTO api_log_config (path_pattern, log_request, log_response, max_body_size, is_active) VALUES
('/api/habit/*',   1, 1, 4096, 1),
('/api/reward/*',  1, 1, 4096, 1),
('/api/user/*',    1, 1, 4096, 1),
('/api/pet/*',     1, 0, 2048, 1),
('/api/battle/*',  1, 1, 4096, 1),
('/api/auth/login', 0, 0, 0,    0);

-- ================================================================
-- 数据维护策略
-- ================================================================

-- AI 对话 30 天自动清理策略（PRD 7.1 规定对话记录仅保留最近30天）
--
-- 方案一：MySQL EVENT 定时任务（推荐，无需额外服务依赖）
--   需确保 MySQL event_scheduler = ON（SET GLOBAL event_scheduler = ON;）
--   每日凌晨 3:00 执行，删除 created_at 超过 30 天的对话记录
--
-- 方案二：应用层定时任务（备选，推荐生产环境使用）
--   在 Spring Boot 中通过 @Scheduled 注解实现定时清理
--   优势：不依赖 MySQL event_scheduler，便于监控和日志追踪
--   示例：@Scheduled(cron = "0 0 3 * * ?")  // 每天凌晨3点
--   DELETE FROM pet_ai_conversation WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)

-- 启用 MySQL 事件调度器（生产环境建议在 my.cnf 中配置）
-- SET GLOBAL event_scheduler = ON;

-- 创建每日清理事件
DROP EVENT IF EXISTS clean_old_conversations;
CREATE EVENT clean_old_conversations
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '03:00:00')
ON COMPLETION PRESERVE
COMMENT '每日凌晨3点自动清理超过30天的AI对话记录（儿童隐私合规）'
DO
  DELETE FROM pet_ai_conversation WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- 审计日志 90 天自动清理
DROP EVENT IF EXISTS clean_old_audit_logs;
CREATE EVENT clean_old_audit_logs
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '04:00:00')
ON COMPLETION PRESERVE
COMMENT '每日凌晨4点自动清理超过90天的API审计日志'
DO
  DELETE FROM gateway_api_audit_log WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
