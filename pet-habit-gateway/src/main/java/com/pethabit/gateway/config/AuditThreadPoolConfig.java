package com.pethabit.gateway.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

@Configuration
public class AuditThreadPoolConfig {

    @Value("${payload-log.audit-thread-pool.core-size:4}")
    private int coreSize;

    @Value("${payload-log.audit-thread-pool.max-size:8}")
    private int maxSize;

    @Value("${payload-log.audit-thread-pool.queue-capacity:500}")
    private int queueCapacity;

    @Bean("auditLogExecutor")
    public Executor auditLogExecutor() {
        return new ThreadPoolExecutor(
                coreSize, maxSize, 60L, TimeUnit.SECONDS,
                new ArrayBlockingQueue<>(queueCapacity),
                r -> {
                    Thread t = new Thread(r, "audit-log");
                    t.setDaemon(true);
                    return t;
                },
                new ThreadPoolExecutor.DiscardOldestPolicy() // 队列满时丢弃最旧，保护网关
        );
    }
}
