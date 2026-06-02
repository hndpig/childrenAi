package com.pethabit.gateway.config;

import org.springframework.cloud.gateway.filter.ratelimit.KeyResolver;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import reactor.core.publisher.Mono;

import java.security.Principal;

/**
 * Redis 令牌桶限流 Key 解析器
 */
@Configuration
public class RateLimiterConfig {

    /**
     * 按用户 ID 限流（已认证用户）
     */
    @Bean
    KeyResolver userKeyResolver() {
        return exchange -> {
            Principal principal = exchange.getPrincipal().block();
            if (principal != null) {
                return Mono.just(principal.getName());
            }
            return Mono.just("anonymous");
        };
    }

    /**
     * 按 IP + 路径 限流（通用兜底）
     */
    @Bean
    @Primary
    KeyResolver ipKeyResolver() {
        return exchange -> {
            String ip = exchange.getRequest().getRemoteAddress().getAddress().getHostAddress();
            String path = exchange.getRequest().getURI().getPath();
            return Mono.just(ip + ":" + path);
        };
    }
}
