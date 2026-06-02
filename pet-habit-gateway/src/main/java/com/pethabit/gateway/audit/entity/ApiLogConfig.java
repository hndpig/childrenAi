package com.pethabit.gateway.audit.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("api_log_config")
public class ApiLogConfig {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String pathPattern;
    private Integer logRequest;
    private Integer logResponse;
    private Integer maxBodySize;
    private Integer isActive;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
