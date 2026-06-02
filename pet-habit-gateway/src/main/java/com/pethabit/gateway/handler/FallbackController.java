package com.pethabit.gateway.handler;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

import java.util.Map;

/**
 * 熔断降级兜底 — 返回统一 JSON 错误。
 */
@RestController
public class FallbackController {

    @GetMapping("/fallback/user")
    public Mono<Map<String, Object>> userFallback() {
        return fallback("用户服务暂时不可用");
    }

    @GetMapping("/fallback/pet")
    public Mono<Map<String, Object>> petFallback() {
        return fallback("宠物服务暂时不可用");
    }

    @GetMapping("/fallback/habit")
    public Mono<Map<String, Object>> habitFallback() {
        return fallback("习惯服务暂时不可用");
    }

    @GetMapping("/fallback/reward")
    public Mono<Map<String, Object>> rewardFallback() {
        return fallback("积分兑换服务暂时不可用");
    }

    @GetMapping("/fallback/battle")
    public Mono<Map<String, Object>> battleFallback() {
        return fallback("对战服务暂时不可用");
    }

    private Mono<Map<String, Object>> fallback(String msg) {
        return Mono.just(Map.of("code", 503, "msg", msg, "data", null));
    }
}
