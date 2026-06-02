package com.pethabit.gateway.filter;

import lombok.extern.slf4j.Slf4j;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

import java.util.UUID;
import java.util.function.Consumer;
import reactor.core.publisher.SignalType;

/**
 * 请求日志 + TraceId 注入 Filter。
 * 每个请求生成唯一 TraceId，注入 MDC 和响应 Header，便于链路追踪。
 */
@Slf4j
@Component
public class RequestLogFilter implements GlobalFilter, Ordered {

    private static final String TRACE_ID_HEADER = "X-Trace-Id";

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        long startTime = System.currentTimeMillis();

        // 如果上游已有 TraceId 则复用，否则生成
        String existingTraceId = exchange.getRequest().getHeaders().getFirst(TRACE_ID_HEADER);
        if (existingTraceId == null) {
            existingTraceId = UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        }
        String traceId = existingTraceId;

        ServerHttpRequest request = exchange.getRequest();
        String method = request.getMethod().name();
        String path = request.getURI().getPath();
        String query = request.getURI().getQuery();

        log.info("[{}] --> {} {}{}", traceId, method, path, query != null ? "?" + query : "");

        // 添加 TraceId 到请求头
        ServerHttpRequest mutatedRequest = request.mutate()
                .header(TRACE_ID_HEADER, traceId)
                .build();
        // 添加 TraceId 到响应头（在 filter 之前直接添加到原始 response）
        exchange.getResponse().getHeaders().add(TRACE_ID_HEADER, traceId);

        ServerWebExchange mutated = exchange.mutate()
                .request(mutatedRequest)
                .build();

        // 使用 doFinally 回调，捕获必要变量
        Consumer<SignalType> finallyAction = new TraceLogConsumer(startTime, traceId, method);
        return chain.filter(mutated)
                .doFinally(finallyAction);
    }

    /**
     * doFinally 回调类，显式声明以避免 lambda 变量捕获问题
     */
    private static class TraceLogConsumer implements Consumer<SignalType> {
        private final long startTime;
        private final String traceId;
        private final String method;

        TraceLogConsumer(long startTime, String traceId, String method) {
            this.startTime = startTime;
            this.traceId = traceId;
            this.method = method;
        }

        @Override
        public void accept(SignalType signalType) {
            long elapsed = System.currentTimeMillis() - startTime;
            log.info("[{}] <-- {} {} {}ms", traceId, method, 0, elapsed);
        }
    }

    @Override
    public int getOrder() {
        return -200; // 早于 AuthGlobalFilter，确保日志最先
    }
}
