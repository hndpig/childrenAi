package com.pethabit.gateway.audit;

import com.pethabit.gateway.audit.entity.ApiLogConfig;
import com.pethabit.gateway.audit.mapper.ApiLogConfigMapper;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.EnableScheduling;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.util.AntPathMatcher;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * 接口记录配置内存缓存。
 * 启动时加载一次，之后每 N 秒从 DB 刷新，避免每次请求查表。
 */
@Slf4j
@Component
@Profile("!dev")
@EnableScheduling
@RequiredArgsConstructor
public class ApiLogConfigCache {

    private final ApiLogConfigMapper configMapper;
    private final List<ApiLogConfig> cache = new CopyOnWriteArrayList<>();
    private final AntPathMatcher matcher = new AntPathMatcher();

    @PostConstruct
    public void init() {
        refresh();
    }

    @Scheduled(fixedDelayString = "${payload-log.config-refresh-interval:60000}00")
    public void refresh() {
        try {
            List<ApiLogConfig> list = configMapper.findAllActive();
            cache.clear();
            cache.addAll(list);
        } catch (Exception e) {
            log.warn("Failed to refresh api_log_config from DB, using stale cache", e);
        }
    }

    /**
     * 查找匹配的配置。支持 Ant 风格通配（/api/pet/**）。
     */
    public ApiLogConfig match(String path) {
        for (ApiLogConfig config : cache) {
            if (matcher.match(config.getPathPattern(), path)) {
                return config;
            }
        }
        return null;
    }

    public boolean shouldLog(String path) {
        return match(path) != null;
    }

    public List<ApiLogConfig> getAll() {
        return List.copyOf(cache);
    }
}
