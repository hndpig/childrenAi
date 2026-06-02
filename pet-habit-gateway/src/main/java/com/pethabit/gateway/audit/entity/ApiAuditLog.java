package com.pethabit.gateway.audit.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("api_audit_log")
public class ApiAuditLog {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String traceId;
    private Long userId;
    private String method;
    private String path;
    private String queryString;
    private Integer statusCode;
    private Integer durationMs;
    private String requestBody;
    private String responseBody;
    private String clientIp;
    private String userAgent;
    private LocalDateTime createdAt;
}
