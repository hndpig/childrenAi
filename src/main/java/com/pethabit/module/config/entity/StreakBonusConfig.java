package com.pethabit.module.config.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 连续打卡加成阶梯配置（PRD 2.4）
 */
@Data
@TableName("streak_bonus_config")
public class StreakBonusConfig {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;
    private Integer minDays;
    private Integer maxDays;
    private BigDecimal xpMultiplier;
    private BigDecimal pointMultiplier;
    private String description;
    private Integer sortOrder;
    private LocalDateTime createdAt;
}
