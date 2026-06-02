package com.pethabit.gateway.audit;

import com.pethabit.gateway.audit.entity.ApiAuditLog;
import com.pethabit.gateway.audit.mapper.ApiAuditLogMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import java.util.concurrent.Executor;

/**
 * 异步写入审计日志到 MySQL，不阻塞 Gateway Event Loop。
 */
@Slf4j
@Service
@Profile("!dev")
public class AuditLogService {

    private final ApiAuditLogMapper mapper;

    private final Executor executor;

    public AuditLogService(ApiAuditLogMapper mapper,
                           @Qualifier("auditLogExecutor") Executor executor) {
        this.mapper = mapper;
        this.executor = executor;
    }

    public void saveAsync(ApiAuditLog auditLog) {
        executor.execute(() -> {
            try {
                mapper.insert(auditLog);
            } catch (Exception e) {
                log.error("Failed to write audit log for path={}", auditLog.getPath(), e);
            }
        });
    }
}
