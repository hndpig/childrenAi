package com.pethabit.module.config.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 系统配置（key-value 通用表，存储积分/经验计算规则、业务阈值等）
 */
@Data
@TableName("system_config")
public class SystemConfig {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String configKey;
    private String configValue;
    private ValueType valueType;
    private String description;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public enum ValueType {
        STRING, INTEGER, DECIMAL, BOOLEAN, JSON
    }
}
