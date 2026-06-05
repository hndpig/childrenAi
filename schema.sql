-- ================================================================
-- Pet-Habit 数据库初始化脚本 v4.1（微服务拆分版）
-- 每个微服务使用独立 database，共享同一 MySQL 实例
-- 跨库引用在应用层保证完整性（MySQL InnoDB 不支持跨 database 外键）
-- 运行: mysql -u root -p < schema.sql
-- ================================================================

-- ================================================================
-- 1. 用户服务 (pet-habit-service-user :8082) → pet_habit_user
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_user CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_user;

-- 用户表（家长 + 孩子统一存储，role 区分）
CREATE TABLE IF NOT EXISTS user_account (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    phone           VARCHAR(20)   COMMENT '手机号（家长必填，孩子可选）',
    password        VARCHAR(255)  COMMENT 'BCrypt 密文',
    nickname        VARCHAR(50)   COMMENT '昵称',
    avatar_url      VARCHAR(255)  COMMENT '头像 URL',
    role            ENUM('PARENT','CHILD') NOT NULL COMMENT '用户角色',
    wechat_openid   VARCHAR(128)  COMMENT '微信小程序 OpenID',
    wechat_unionid  VARCHAR(128)  COMMENT '微信 UnionID',
    enabled         TINYINT(1)   NOT NULL DEFAULT 1 COMMENT '0=禁用 1=启用',
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_phone (phone),
    UNIQUE KEY uk_wechat_openid (wechat_openid),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- 设备绑定表
CREATE TABLE IF NOT EXISTS user_device (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '关联 child user_account.id（跨库，应用层保证完整性）',
    platform        ENUM('XTC','HUAWEI','XIAOMI','APPLE') NOT NULL COMMENT '手表平台',
    device_id       VARCHAR(128) NOT NULL COMMENT '平台内设备唯一标识',
    device_name     VARCHAR(100) COMMENT '设备名称',
    push_token      VARCHAR(512) COMMENT '推送 Token',
    is_active       TINYINT(1)  DEFAULT 1 COMMENT '是否为当前活跃设备',
    last_online_at  DATETIME     COMMENT '最近在线时间',
    created_at      DATETIME    DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_device (platform, device_id),
    INDEX idx_child (child_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='设备绑定';

-- 家长-孩子绑定关系
CREATE TABLE IF NOT EXISTS user_parent_child_binding (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_id   BIGINT NOT NULL COMMENT '家长 user_account.id',
    child_id    BIGINT NOT NULL COMMENT '孩子 user_account.id',
    nickname    VARCHAR(50)  COMMENT '家长对孩子的备注昵称',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_parent_child (parent_id, child_id),
    INDEX idx_child (child_id),
    CONSTRAINT fk_binding_parent FOREIGN KEY (parent_id) REFERENCES user_account(id),
    CONSTRAINT fk_binding_child  FOREIGN KEY (child_id)  REFERENCES user_account(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='家长-孩子绑定';

-- 好友关系
CREATE TABLE IF NOT EXISTS user_friendship (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT NOT NULL COMMENT '发起方 user_account.id',
    friend_id   BIGINT NOT NULL COMMENT '好友 user_account.id',
    status      ENUM('PENDING','ACCEPTED','BLOCKED') DEFAULT 'PENDING',
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_friendship (user_id, friend_id),
    INDEX idx_friend (friend_id),
    CONSTRAINT fk_friendship_user   FOREIGN KEY (user_id)   REFERENCES user_account(id),
    CONSTRAINT fk_friendship_friend FOREIGN KEY (friend_id) REFERENCES user_account(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='好友关系';

-- 通知/推送记录
CREATE TABLE IF NOT EXISTS common_notification (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id         BIGINT NOT NULL COMMENT '接收用户 user_account.id',
    type            ENUM('HABIT_REMIND','REVIEW_ALERT','REDEEM_ALERT','MOOD_PUSH','BATTLE_INVITE','PET_AWAKE','PET_SLEEP','STREAK_MILESTONE','FRIEND_REQUEST') NOT NULL,
    title           VARCHAR(200)  COMMENT '通知标题',
    body            VARCHAR(500)  COMMENT '通知正文',
    related_id      BIGINT        COMMENT '关联业务 ID（跨库引用，应用层保证完整性）',
    is_read         TINYINT(1) DEFAULT 0,
    push_status     ENUM('PENDING','SENT','FAILED') DEFAULT 'PENDING',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user (user_id, created_at),
    INDEX idx_unread (user_id, is_read, created_at),
    CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES user_account(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='通知记录';

-- 通知偏好设置
CREATE TABLE IF NOT EXISTS common_notification_preference (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id         BIGINT NOT NULL UNIQUE COMMENT '用户 user_account.id',
    habit_remind    TINYINT(1) DEFAULT 1,
    review_alert    TINYINT(1) DEFAULT 1,
    redeem_alert    TINYINT(1) DEFAULT 1,
    mood_push       TINYINT(1) DEFAULT 1,
    battle_invite   TINYINT(1) DEFAULT 1,
    pet_awake       TINYINT(1) DEFAULT 1,
    pet_sleep       TINYINT(1) DEFAULT 1,
    streak_milestone TINYINT(1) DEFAULT 1,
    friend_request  TINYINT(1) DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_notif_pref_user FOREIGN KEY (user_id) REFERENCES user_account(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='通知偏好设置';

-- ================================================================
-- 2. 宠物服务 (pet-habit-service-pet :8083) → pet_habit_pet
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_pet CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_pet;

-- 宠物图鉴
CREATE TABLE IF NOT EXISTS pet_species (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(50)  NOT NULL COMMENT '种类名称',
    attribute       ENUM('FIRE','WATER','GRASS','ELECTRIC','GROUND','LIGHT','DARK') NOT NULL,
    description     VARCHAR(500),
    base_hp         INT DEFAULT 100,
    base_attack     INT DEFAULT 10,
    base_defense    INT DEFAULT 10,
    base_agility    INT DEFAULT 10,
    base_mp         INT DEFAULT 50,
    evolution_chain JSON COMMENT '进化链 JSON',
    level_exp_thresholds JSON COMMENT '小等级 EXP 阈值 JSON',
    egg_sprite_url  VARCHAR(255),
    baby_sprite_url VARCHAR(255),
    adult_sprite_url VARCHAR(255),
    rare_sprite_url VARCHAR(255),
    evolution_animation_url VARCHAR(255),
    sound_set_url   VARCHAR(255),
    rarity          ENUM('COMMON','UNCOMMON','RARE','LEGENDARY') DEFAULT 'COMMON',
    is_available    TINYINT(1) DEFAULT 1,
    available_from_date DATETIME,
    available_to_date   DATETIME,
    sort_order          INT DEFAULT 0,
    generation          VARCHAR(20) COMMENT '投放批次标识',
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物图鉴';

-- 宠物实例
CREATE TABLE IF NOT EXISTS pet (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id            BIGINT NOT NULL COMMENT '所属孩子 user_account.id（跨库，应用层保证完整性）',
    species_id          BIGINT COMMENT '对应 pet_species.id',
    name                VARCHAR(50) NOT NULL COMMENT '宠物名字',
    stage               ENUM('EGG','BABY','ADULT','RARE') NOT NULL DEFAULT 'EGG',
    attribute           ENUM('FIRE','WATER','GRASS','ELECTRIC','GROUND','LIGHT','DARK') NOT NULL,
    personality         ENUM('LIVELY','GENTLE','TSUNDERE','DOODLE','BRAVE','PLAYFUL'),
    hp                  INT DEFAULT 100,
    attack              INT DEFAULT 10,
    defense             INT DEFAULT 10,
    agility             INT DEFAULT 10,
    mp                  INT DEFAULT 50,
    current_hp          INT COMMENT '当前战斗中 HP',
    current_mp          INT COMMENT '当前战斗中 MP',
    exp                 INT DEFAULT 0,
    level               INT DEFAULT 1,
    mood                ENUM('EXPECTANT','HAPPY','SAD','SLEEPING') DEFAULT 'EXPECTANT',
    incubation_progress INT DEFAULT 0,
    incubation_started_at DATETIME,
    is_active           TINYINT(1) DEFAULT 1,
    streak_days         INT DEFAULT 0,
    best_streak         INT DEFAULT 0,
    idle_days           INT DEFAULT 0,
    is_asleep           TINYINT(1) DEFAULT 0,
    daily_interaction_count INT DEFAULT 0,
    last_interaction_date   DATE,
    daily_battle_count      INT DEFAULT 0,
    last_battle_date        DATE,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    INDEX idx_active (child_id, is_active),
    INDEX idx_species (species_id),
    CONSTRAINT fk_pet_species FOREIGN KEY (species_id) REFERENCES pet_species(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物实例';

-- 进化记录
CREATE TABLE IF NOT EXISTS pet_evolution_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL,
    from_stage      ENUM('EGG','BABY','ADULT','RARE') NOT NULL,
    to_stage        ENUM('BABY','ADULT','RARE') NOT NULL,
    triggered_by    VARCHAR(100),
    evolved_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pet (pet_id),
    CONSTRAINT fk_evolution_pet FOREIGN KEY (pet_id) REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物进化记录';

-- 孵化任务
CREATE TABLE IF NOT EXISTS pet_incubation_task (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL,
    parent_id       BIGINT NOT NULL COMMENT '家长 user_account.id（跨库，应用层保证完整性）',
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(300),
    is_completed    TINYINT(1) DEFAULT 0,
    completed_at    DATETIME,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pet (pet_id),
    CONSTRAINT fk_incubation_pet FOREIGN KEY (pet_id) REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='孵化任务';

-- 宠物作息配置
CREATE TABLE IF NOT EXISTS pet_schedule (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL,
    schedule_type   ENUM('SCHOOL','REST','SLEEP') NOT NULL,
    start_time      TIME NOT NULL,
    end_time        TIME NOT NULL,
    days_of_week    VARCHAR(20) COMMENT '生效星期，如 1,2,3,4,5',
    INDEX idx_pet (pet_id),
    CONSTRAINT fk_schedule_pet FOREIGN KEY (pet_id) REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物作息配置';

-- 技能定义库
CREATE TABLE IF NOT EXISTS pet_skill_def (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(50)  NOT NULL,
    type                ENUM('ATTACK','DEFENSE','HEAL','BUFF','DEBUFF') NOT NULL,
    power               INT DEFAULT 0,
    accuracy            INT DEFAULT 100,
    mp_cost             INT DEFAULT 10,
    description         VARCHAR(200),
    attribute_required  ENUM('FIRE','WATER','GRASS','ELECTRIC','GROUND','LIGHT','DARK'),
    category_required   ENUM('HYGIENE','STUDY','SPORT','LIFE_SKILL','ROUTINE'),
    min_difficulty      INT DEFAULT 1,
    min_level           INT DEFAULT 1,
    animation_url       VARCHAR(255),
    sound_url           VARCHAR(255),
    rarity              ENUM('COMMON','UNCOMMON','RARE') DEFAULT 'COMMON',
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='技能定义库';

-- 宠物技能关联
CREATE TABLE IF NOT EXISTS pet_skill_rel (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    pet_id          BIGINT NOT NULL,
    skill_id        BIGINT NOT NULL,
    level           INT DEFAULT 1,
    learn_order     INT           COMMENT '学习顺序 0-11',
    is_equipped     TINYINT(1) DEFAULT 0,
    unlocked_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_pet_skill (pet_id, skill_id),
    INDEX idx_pet (pet_id),
    INDEX idx_equipped (pet_id, is_equipped),
    CONSTRAINT fk_pet_skill_pet   FOREIGN KEY (pet_id)   REFERENCES pet(id),
    CONSTRAINT fk_pet_skill_skill FOREIGN KEY (skill_id) REFERENCES pet_skill_def(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物技能关联';

-- 性格测试题库
CREATE TABLE IF NOT EXISTS pet_personality_question (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    question_text   VARCHAR(500) NOT NULL,
    options_json    JSON NOT NULL COMMENT '选项 JSON',
    dimension       ENUM('O','C','E','A','N') NOT NULL COMMENT '大五人格维度',
    version         INT DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='性格测试题库';

-- 性格测试结果
CREATE TABLE IF NOT EXISTS pet_personality_result (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '被测孩子 user_account.id（跨库，应用层保证完整性）',
    pet_id          BIGINT COMMENT '关联宠物 pet.id',
    answers_json    JSON NOT NULL COMMENT '答题记录 JSON',
    result_type     ENUM('LIVELY','GENTLE','TSUNDERE','DOODLE','BRAVE','PLAYFUL') NOT NULL,
    dimension_scores JSON COMMENT '各维度得分',
    tested_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    CONSTRAINT fk_personality_pet FOREIGN KEY (pet_id) REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='性格测试结果';

-- 宠物互动记录
CREATE TABLE IF NOT EXISTS pet_interaction (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    initiator_pet_id    BIGINT NOT NULL,
    receiver_pet_id     BIGINT NOT NULL,
    interaction_type    ENUM('VISIT','FRIENDLY_BATTLE') DEFAULT 'VISIT',
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_initiator (initiator_pet_id),
    INDEX idx_receiver (receiver_pet_id),
    CONSTRAINT fk_interaction_initiator FOREIGN KEY (initiator_pet_id) REFERENCES pet(id),
    CONSTRAINT fk_interaction_receiver  FOREIGN KEY (receiver_pet_id)  REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='宠物互动记录';

-- AI 对话历史
CREATE TABLE IF NOT EXISTS pet_ai_conversation (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '对话孩子 user_account.id（跨库，应用层保证完整性）',
    pet_id          BIGINT COMMENT '当前宠物 pet.id',
    role            ENUM('USER','ASSISTANT','SYSTEM') NOT NULL,
    content         TEXT NOT NULL COMMENT '对话内容 --敏感字段',
    safety_filtered TINYINT(1) DEFAULT 0,
    filter_reason   VARCHAR(100),
    model_used      VARCHAR(50),
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_child_pet (child_id, pet_id),
    INDEX idx_created (created_at),
    INDEX idx_child_created (child_id, created_at),
    CONSTRAINT fk_ai_conv_pet FOREIGN KEY (pet_id) REFERENCES pet(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI对话历史（儿童隐私数据，保留30天）';

-- ---- 初始数据：宠物物种 ----
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

-- ---- 初始数据：技能库 ----
INSERT INTO pet_skill_def (name, type, power, accuracy, mp_cost, description, attribute_required, category_required, min_difficulty, min_level, rarity) VALUES
('火焰冲击', 'ATTACK', 60, 95, 15, '释放炽热的火焰冲击对手',        'FIRE',     NULL, 1, 1, 'COMMON'),
('水枪喷射', 'ATTACK', 55, 95, 12, '喷射高压水流攻击对手',           'WATER',    NULL, 1, 1, 'COMMON'),
('藤鞭抽打', 'ATTACK', 50, 100,10, '用坚韧的藤鞭抽打对手',           'GRASS',    NULL, 1, 1, 'COMMON'),
('电击',     'ATTACK', 55, 95, 12, '释放电流麻痹对手',               'ELECTRIC', NULL, 1, 1, 'COMMON'),
('落石',     'ATTACK', 50, 90, 10, '召唤岩石砸向对手',               'GROUND',   NULL, 1, 1, 'COMMON'),
('光之射线', 'ATTACK', 60, 95, 15, '凝聚光芒射出高能射线',           'LIGHT',    NULL, 1, 1, 'COMMON'),
('暗影突袭', 'ATTACK', 65, 90, 18, '潜入暗影中突然发起袭击',         'DARK',     NULL, 1, 1, 'COMMON'),
('地震',     'ATTACK', 70, 85, 20, '引发剧烈地震，造成大范围伤害',    'GROUND',   NULL, 3, 3, 'RARE'),
('火焰护盾', 'DEFENSE', 30, 100, 15, '用火焰包裹全身，减少受到的伤害',  'FIRE',  NULL,        1, 1, 'COMMON'),
('水之屏障', 'DEFENSE', 35, 100, 15, '召唤水幕屏障抵御攻击',            'WATER', NULL,        1, 1, 'COMMON'),
('光之守护', 'DEFENSE', 30, 100, 15, '以光芒编织护盾守护自身',          'LIGHT', NULL,        1, 1, 'COMMON'),
('暗影护甲', 'DEFENSE', 35, 100, 15, '暗影能量凝聚成坚固护甲',          'DARK',  NULL,        1, 1, 'COMMON'),
('快速恢复', 'HEAL', 40, 100, 20, '加速自愈，恢复一定 HP',        NULL, 'HYGIENE', 1, 1, 'COMMON'),
('能量小憩', 'HEAL', 50, 100, 25, '小憩片刻，恢复较多 HP 和 MP',    NULL, 'ROUTINE', 2, 2, 'UNCOMMON'),
('专注',     'BUFF', 20, 100, 10, '集中精神，提升攻击力',          NULL, 'STUDY',     1, 1, 'COMMON'),
('敏捷提升', 'BUFF', 20, 100, 10, '激发速度潜能，提升敏捷属性',    NULL, 'SPORT',     1, 1, 'COMMON'),
('烟幕',     'DEBUFF', 15, 90, 8,  '释放烟雾干扰对手，降低命中率',  NULL, 'SPORT',      1, 1, 'COMMON'),
('威吓',     'DEBUFF', 15, 90, 8,  '发出威吓咆哮，降低对手攻击力',  NULL, 'LIFE_SKILL', 2, 1, 'COMMON');

-- AI 对话 30 天清理事件
DROP EVENT IF EXISTS clean_old_conversations;
CREATE EVENT clean_old_conversations
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '03:00:00')
ON COMPLETION PRESERVE
COMMENT '每日凌晨3点清理超过30天的AI对话记录'
DO
  DELETE FROM pet_ai_conversation WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY);

-- ================================================================
-- 3. 习惯服务 (pet-habit-service-habit :8084) → pet_habit_habit
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_habit CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_habit;

-- 习惯模板
CREATE TABLE IF NOT EXISTS habit_template (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(500),
    category        ENUM('HYGIENE','STUDY','SPORT','LIFE_SKILL','ROUTINE') NOT NULL,
    difficulty      INT DEFAULT 1  COMMENT '难度系数 ⭐1-3',
    frequency_type  ENUM('ONCE','DAILY','WEEKLY','CUSTOM') DEFAULT 'DAILY',
    frequency_value INT DEFAULT 1,
    remind_times    JSON          COMMENT '提醒时段 JSON',
    require_review  TINYINT(1) DEFAULT 1,
    icon_url        VARCHAR(255),
    sort_order      INT DEFAULT 0,
    is_active       TINYINT(1) DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='习惯模板';

-- 习惯定义
CREATE TABLE IF NOT EXISTS habit (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_id       BIGINT NOT NULL COMMENT '创建者 user_account.id（跨库，应用层保证完整性）',
    child_id        BIGINT NOT NULL COMMENT '执行孩子 user_account.id（跨库，应用层保证完整性）',
    template_id     BIGINT       COMMENT '来源模板 habit_template.id',
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(500),
    category        ENUM('HYGIENE','STUDY','SPORT','LIFE_SKILL','ROUTINE') NOT NULL,
    difficulty      INT DEFAULT 1,
    frequency_type  ENUM('ONCE','DAILY','WEEKLY','CUSTOM') DEFAULT 'DAILY',
    frequency_value INT DEFAULT 1,
    remind_times    JSON,
    require_review  TINYINT(1) DEFAULT 1,
    is_active       TINYINT(1) DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    INDEX idx_parent_child (parent_id, child_id),
    INDEX idx_category (child_id, category),
    CONSTRAINT fk_habit_template FOREIGN KEY (template_id) REFERENCES habit_template(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='习惯定义';

-- 打卡记录
CREATE TABLE IF NOT EXISTS habit_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    habit_id        BIGINT NOT NULL,
    child_id        BIGINT NOT NULL COMMENT '执行孩子 user_account.id（跨库，应用层保证完整性）',
    date            DATE NOT NULL,
    status          ENUM('PENDING','APPROVED','REJECTED') DEFAULT 'PENDING',
    reviewed_by     BIGINT       COMMENT '审核人 user_account.id（跨库，应用层保证完整性）',
    reviewed_at     DATETIME,
    reject_reason   VARCHAR(200),
    auto_approved   TINYINT(1) DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_habit_date (habit_id, date),
    INDEX idx_child_date (child_id, date),
    INDEX idx_status (status, created_at),
    INDEX idx_reviewed (status, reviewed_by, reviewed_at),
    CONSTRAINT fk_habit_log_habit FOREIGN KEY (habit_id) REFERENCES habit(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='打卡记录';

-- ---- 初始数据：习惯模板 ----
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

-- ================================================================
-- 4. 积分兑换服务 (pet-habit-service-reward :8085) → pet_habit_reward
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_reward CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_reward;

-- 积分账户
CREATE TABLE IF NOT EXISTS reward_point_account (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL UNIQUE COMMENT '所属孩子 user_account.id（跨库，应用层保证完整性）',
    balance         INT DEFAULT 0,
    total_earned    INT DEFAULT 0,
    total_spent     INT DEFAULT 0,
    reset_cycle     ENUM('MONTHLY','QUARTERLY','SEMESTER','MANUAL') DEFAULT 'MANUAL',
    last_reset_at   DATETIME,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_child (child_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='积分账户';

-- 积分流水
CREATE TABLE IF NOT EXISTS reward_point_transaction (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '所属孩子 user_account.id（跨库，应用层保证完整性）',
    amount          INT NOT NULL COMMENT '正数=收入，负数=支出',
    type            ENUM('HABIT_REWARD','STREAK_BONUS','REDEEM','RESET','ADJUST') NOT NULL,
    description     VARCHAR(200),
    related_id      BIGINT        COMMENT '关联业务 ID（跨库引用，应用层保证完整性）',
    before_balance  INT DEFAULT 0,
    after_balance   INT DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    INDEX idx_created (child_id, created_at),
    INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='积分流水';

-- 奖励池
CREATE TABLE IF NOT EXISTS reward_item (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    parent_id       BIGINT NOT NULL COMMENT '设置奖励的家长 user_account.id（跨库，应用层保证完整性）',
    child_id        BIGINT       COMMENT '限定兑换人 user_account.id（跨库，应用层保证完整性）',
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(500),
    cost            INT NOT NULL,
    type            ENUM('TIME','ACTIVITY','ITEM') NOT NULL,
    stock           INT DEFAULT -1 COMMENT '-1=无限兑换',
    redeem_method   ENUM('AUTO','MANUAL') DEFAULT 'MANUAL',
    is_active       TINYINT(1) DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_parent (parent_id),
    INDEX idx_child (child_id),
    INDEX idx_active (parent_id, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='奖励池';

-- 兑换记录
CREATE TABLE IF NOT EXISTS reward_redemption (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '兑换孩子 user_account.id（跨库，应用层保证完整性）',
    reward_id       BIGINT NOT NULL,
    status          ENUM('PENDING','APPROVED','REJECTED','FULFILLED') DEFAULT 'PENDING',
    cost            INT NOT NULL,
    reviewed_by     BIGINT       COMMENT '审核家长 user_account.id（跨库，应用层保证完整性）',
    reviewed_at     DATETIME,
    reject_reason   VARCHAR(200),
    fulfilled_at    DATETIME,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_child (child_id),
    INDEX idx_status (status),
    INDEX idx_child_status (child_id, status),
    CONSTRAINT fk_redemption_reward FOREIGN KEY (reward_id) REFERENCES reward_item(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='兑换记录';

-- 成就定义
CREATE TABLE IF NOT EXISTS reward_achievement (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(300),
    icon_url        VARCHAR(255),
    condition_type  ENUM('STREAK_DAYS','TOTAL_HABITS','PET_EVOLVED','BATTLE_WINS','SKILLS_UNLOCKED','POINTS_EARNED') NOT NULL,
    condition_value INT NOT NULL,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成就定义';

-- 用户成就
CREATE TABLE IF NOT EXISTS reward_user_achievement (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    child_id        BIGINT NOT NULL COMMENT '用户 user_account.id（跨库，应用层保证完整性）',
    achievement_id  BIGINT NOT NULL,
    unlocked_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_achieve (child_id, achievement_id),
    INDEX idx_child (child_id),
    CONSTRAINT fk_user_achieve_ach FOREIGN KEY (achievement_id) REFERENCES reward_achievement(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户成就';

-- ---- 初始数据：成就 ----
INSERT INTO reward_achievement (name, description, condition_type, condition_value) VALUES
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

-- ================================================================
-- 5. 对战服务 (pet-habit-service-battle :8086) → pet_habit_battle
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_battle CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_battle;

-- 对战记录
CREATE TABLE IF NOT EXISTS battle_record (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    initiator_id        BIGINT NOT NULL COMMENT '发起方 child_id → user_account.id（跨库，应用层保证完整性）',
    opponent_id         BIGINT NOT NULL COMMENT '对手 child_id → user_account.id（跨库，应用层保证完整性）',
    initiator_pet_id    BIGINT       COMMENT '发起方宠物 pet.id（跨库，应用层保证完整性）',
    opponent_pet_id     BIGINT       COMMENT '对手宠物 pet.id（跨库，应用层保证完整性）',
    winner_id           BIGINT       COMMENT '胜方 child_id → user_account.id（跨库，应用层保证完整性）',
    battle_type         ENUM('BLUETOOTH','FRIENDLY') DEFAULT 'BLUETOOTH',
    battle_status       ENUM('INVITED','ACCEPTED','DECLINED','ONGOING','COMPLETED','DRAW') DEFAULT 'COMPLETED',
    total_rounds        INT DEFAULT 0,
    battled_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_initiator (initiator_id),
    INDEX idx_opponent (opponent_id),
    INDEX idx_winner (winner_id),
    INDEX idx_battled_at (battled_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='对战记录';

-- 对战回合详情
CREATE TABLE IF NOT EXISTS battle_round (
    id                      BIGINT AUTO_INCREMENT PRIMARY KEY,
    battle_id               BIGINT NOT NULL,
    round_number            INT NOT NULL,
    attacker_id             BIGINT NOT NULL COMMENT '出招方 child_id → user_account.id（跨库，应用层保证完整性）',
    skill_id                BIGINT       COMMENT '使用的技能 pet_skill_def.id（跨库，应用层保证完整性）',
    damage                  INT DEFAULT 0,
    attacker_hp_remaining   INT,
    defender_hp_remaining   INT,
    INDEX idx_battle (battle_id),
    CONSTRAINT fk_round_battle FOREIGN KEY (battle_id) REFERENCES battle_record(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='对战回合详情';

-- ================================================================
-- 6. 配置服务 (pet-habit-service-config :8087) → pet_habit_config
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_config CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_config;

-- 系统配置
CREATE TABLE IF NOT EXISTS config_system (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    config_key      VARCHAR(100) NOT NULL,
    config_value    VARCHAR(500) NOT NULL,
    value_type      ENUM('STRING','INTEGER','DECIMAL','BOOLEAN','JSON') DEFAULT 'STRING',
    description     VARCHAR(300),
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_config_key (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统配置';

-- 连续打卡加成阶梯
CREATE TABLE IF NOT EXISTS config_streak_bonus (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    name                VARCHAR(50) NOT NULL,
    min_days            INT NOT NULL,
    max_days            INT NOT NULL COMMENT '999=无上限',
    xp_multiplier       DECIMAL(3,1) DEFAULT 1.0,
    point_multiplier    DECIMAL(3,1) DEFAULT 1.0,
    description         VARCHAR(200),
    sort_order          INT DEFAULT 0,
    created_at          DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_day_range (min_days, max_days)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='连续打卡加成阶梯';

-- ---- 初始数据：系统配置 ----
INSERT INTO config_system (config_key, config_value, value_type, description) VALUES
('DIFFICULTY_1_BASE_XP',          '10',   'INTEGER', '难度1（⭐）基础经验值'),
('DIFFICULTY_1_BASE_POINTS',      '5',    'INTEGER', '难度1（⭐）基础积分'),
('DIFFICULTY_2_BASE_XP',          '30',   'INTEGER', '难度2（⭐⭐）基础经验值'),
('DIFFICULTY_2_BASE_POINTS',      '15',   'INTEGER', '难度2（⭐⭐）基础积分'),
('DIFFICULTY_3_BASE_XP',          '60',   'INTEGER', '难度3（⭐⭐⭐）基础经验值'),
('DIFFICULTY_3_BASE_POINTS',      '30',   'INTEGER', '难度3（⭐⭐⭐）基础积分'),
('DAILY_INTERACTION_XP_LIMIT',    '50',   'INTEGER', '每日互动经验值上限'),
('DAILY_BATTLE_LIMIT',            '5',    'INTEGER', '每日对战次数上限'),
('REVIEW_TIMEOUT_MINUTES',        '120',  'INTEGER', '打卡审核超时分钟数'),
('IDLE_TRIGGER_DAYS',             '2',    'INTEGER', '懈怠触发天数');

-- ---- 初始数据：连续打卡加成阶梯 ----
INSERT INTO config_streak_bonus (name, min_days, max_days, xp_multiplier, point_multiplier, description, sort_order) VALUES
('坚持新手', 1,  2,  1.0, 1.0, 'Day1-2 基础加成',  1),
('习惯初成', 3,  6,  1.2, 1.2, 'Day3-6 轻度连续',  2),
('稳定习惯', 7,  13, 1.5, 1.5, 'Day7-13 稳定加成', 3),
('优秀坚持', 14, 29, 2.0, 2.0, 'Day14-29 持续坚持',4),
('自律达人', 30, 999,3.0, 3.0, 'Day30+ 顶级加成',  5);

-- ================================================================
-- 7. 网关审计 (pet-habit-gateway :8081) → pet_habit_gateway
-- ================================================================
CREATE DATABASE IF NOT EXISTS pet_habit_gateway CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pet_habit_gateway;

-- API 报文记录配置
CREATE TABLE IF NOT EXISTS gateway_api_log_config (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    path_pattern    VARCHAR(200) NOT NULL COMMENT '路径模式，支持*通配',
    log_request     TINYINT(1) DEFAULT 1,
    log_response    TINYINT(1) DEFAULT 1,
    max_body_size   INT DEFAULT 4096 COMMENT 'body 上限(字节)',
    is_active       TINYINT(1) DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_path (path_pattern),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='API报文记录配置';

-- API 审计记录
CREATE TABLE IF NOT EXISTS gateway_api_audit_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    trace_id        VARCHAR(32),
    user_id         BIGINT       COMMENT '操作人 user_account.id（跨库，应用层保证完整性）',
    method          VARCHAR(10)  NOT NULL,
    path            VARCHAR(500) NOT NULL,
    query_string    VARCHAR(1000),
    status_code     INT,
    duration_ms     INT,
    request_body    TEXT         COMMENT '已脱敏',
    response_body   TEXT         COMMENT '已脱敏',
    client_ip       VARCHAR(45),
    user_agent      VARCHAR(500),
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_created (created_at),
    INDEX idx_user (user_id),
    INDEX idx_path (path(100)),
    INDEX idx_trace (trace_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='API审计记录（保留90天）';

-- ---- 初始数据：API 日志配置 ----
INSERT INTO gateway_api_log_config (path_pattern, log_request, log_response, max_body_size, is_active) VALUES
('/api/habit/*',   1, 1, 4096, 1),
('/api/reward/*',  1, 1, 4096, 1),
('/api/user/*',    1, 1, 4096, 1),
('/api/pet/*',     1, 0, 2048, 1),
('/api/battle/*',  1, 1, 4096, 1),
('/api/auth/login', 0, 0, 0,    0);

-- 审计日志 90 天清理事件
DROP EVENT IF EXISTS clean_old_audit_logs;
CREATE EVENT clean_old_audit_logs
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE, '04:00:00')
ON COMPLETION PRESERVE
COMMENT '每日凌晨4点清理超过90天的审计日志'
DO
  DELETE FROM gateway_api_audit_log WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);

-- ================================================================
-- 数据维护说明
-- ================================================================
-- 清理事件依赖 MySQL event_scheduler，需确保已开启：
--   SET GLOBAL event_scheduler = ON;
--
-- 跨库引用完整性由应用层（Dubbo 服务间调用）保证，数据库层不设外键约束。
-- 所有跨库 ID 字段均在 COMMENT 中标注"跨库，应用层保证完整性"。
-- ================================================================
