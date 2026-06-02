package com.pethabit.gateway.filter;

import com.pethabit.gateway.audit.ApiLogConfigCache;
import com.pethabit.gateway.audit.AuditLogService;
import com.pethabit.gateway.audit.BodyMaskUtil;
import com.pethabit.gateway.audit.entity.ApiAuditLog;
import com.pethabit.gateway.audit.entity.ApiLogConfig;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.context.annotation.Profile;
import org.springframework.core.Ordered;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpResponseDecorator;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * 报文记录 Filter。根据 api_log_config 配置选择性记录请求/响应，脱敏后异步入库。
 * order=50，在 AuthGlobalFilter(-100) 之后执行，确保能拿到 X-User-Id。
 */
@Slf4j
@Component
@Profile("!dev")
@RequiredArgsConstructor
public class PayloadLogFilter implements GlobalFilter, Ordered {

    private static final String CACHED_REQUEST_BODY = PayloadLogFilter.class.getName() + ".reqBody";
    private static final String START_TIME = PayloadLogFilter.class.getName() + ".start";
    private static final List<String> SKIP_PATHS = List.of("/ws/", "/actuator/");

    private final ApiLogConfigCache configCache;
    private final AuditLogService auditLogService;

    @Value("${payload-log.global-max-body-size:4096}")
    private int globalMaxBodySize;

    private volatile Pattern maskPattern;
    private volatile Set<String> maskHeaders;

    @Value("${payload-log.mask-fields:password,token,secret,jwt,phone,mobile}")
    public void setMaskFields(String fields) {
        this.maskPattern = BodyMaskUtil.buildMaskPattern(
                new HashSet<>(Arrays.asList(fields.split(","))));
    }

    @Value("${payload-log.mask-headers:authorization,cookie}")
    public void setMaskHeaders(String headers) {
        this.maskHeaders = new HashSet<>(Arrays.asList(headers.split(",")));
    }

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        String path = exchange.getRequest().getURI().getPath();
        if (SKIP_PATHS.stream().anyMatch(path::startsWith)) {
            return chain.filter(exchange);
        }

        ApiLogConfig config = configCache.match(path);
        if (config == null || config.getIsActive() == 0) {
            return chain.filter(exchange);
        }

        exchange.getAttributes().put(START_TIME, System.currentTimeMillis());
        int maxBody = config.getMaxBodySize() > 0 ? config.getMaxBodySize() : globalMaxBodySize;
        ServerHttpRequest request = exchange.getRequest();

        // 缓存请求体
        Mono<Void> bodyCache;
        if (config.getLogRequest() == 1 && isBodyMethod(request.getMethod())) {
            bodyCache = DataBufferUtils.join(request.getBody())
                    .doOnNext(buf -> {
                        exchange.getAttributes().put(CACHED_REQUEST_BODY, readBytes(buf));
                        DataBufferUtils.release(buf);
                    })
                    .then();
        } else {
            bodyCache = Mono.empty();
        }

        return bodyCache.then(Mono.defer(() -> {
            byte[][] respHolder = new byte[1][];
            ServerWebExchange decoratedExchange = decorateResponse(exchange, config, maxBody, respHolder);
            return chain.filter(decoratedExchange)
                    .doFinally(s -> writeAudit(exchange, config, maxBody, respHolder));
        }));
    }

    private ServerWebExchange decorateResponse(ServerWebExchange exchange,
                                                ApiLogConfig config, int maxBody, byte[][] respHolder) {
        if (config.getLogResponse() != 1) {
            return exchange;
        }

        return exchange.mutate().response(new ServerHttpResponseDecorator(exchange.getResponse()) {
            @Override
            public Mono<Void> writeWith(org.reactivestreams.Publisher<? extends DataBuffer> body) {
                return super.writeWith(Flux.from(body).map(buf -> {
                    respHolder[0] = readBytes(buf);
                    DataBufferUtils.release(buf);
                    return exchange.getResponse().bufferFactory().wrap(respHolder[0]);
                }));
            }
        }).build();
    }

    private void writeAudit(ServerWebExchange exchange, ApiLogConfig config,
                             int maxBody, byte[][] respHolder) {
        try {
            ServerHttpRequest request = exchange.getRequest();
            String path = request.getURI().getPath();
            Long start = exchange.getAttribute(START_TIME);

            ApiAuditLog audit = new ApiAuditLog();
            audit.setTraceId(request.getHeaders().getFirst("X-Trace-Id"));
            audit.setUserId(extractUserId(request));
            audit.setMethod(request.getMethod().name());
            audit.setPath(path);
            audit.setQueryString(request.getURI().getQuery());
            audit.setStatusCode(exchange.getResponse().getStatusCode() != null
                    ? exchange.getResponse().getStatusCode().value() : 0);
            audit.setDurationMs(start != null ? (int) (System.currentTimeMillis() - start) : 0);
            audit.setClientIp(extractClientIp(request));
            audit.setUserAgent(request.getHeaders().getFirst(HttpHeaders.USER_AGENT));

            if (config.getLogRequest() == 1) {
                byte[] bytes = exchange.getAttribute(CACHED_REQUEST_BODY);
                audit.setRequestBody(maskAndTruncate(bytes, maxBody));
            }
            if (config.getLogResponse() == 1 && respHolder[0] != null) {
                audit.setResponseBody(maskAndTruncate(respHolder[0], maxBody));
            }

            auditLogService.saveAsync(audit);
        } catch (Exception e) {
            log.debug("Audit failed for path={}: {}", exchange.getRequest().getURI().getPath(), e.getMessage());
        }
    }

    private String maskAndTruncate(byte[] bytes, int maxBody) {
        if (bytes == null || bytes.length == 0) return null;
        String raw = new String(bytes, StandardCharsets.UTF_8);
        String masked = BodyMaskUtil.mask(raw, maskPattern);
        return BodyMaskUtil.truncateBytes(masked, maxBody);
    }

    private Long extractUserId(ServerHttpRequest request) {
        String uid = request.getHeaders().getFirst("X-User-Id");
        try {
            return uid != null ? Long.valueOf(uid) : null;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private String extractClientIp(ServerHttpRequest request) {
        String xff = request.getHeaders().getFirst("X-Forwarded-For");
        if (xff != null) return xff.split(",")[0].trim();
        var addr = request.getRemoteAddress();
        return addr != null ? addr.getAddress().getHostAddress() : "unknown";
    }

    private byte[] readBytes(DataBuffer buf) {
        byte[] bytes = new byte[buf.readableByteCount()];
        buf.read(bytes);
        return bytes;
    }

    private boolean isBodyMethod(HttpMethod method) {
        return method == HttpMethod.POST || method == HttpMethod.PUT || method == HttpMethod.PATCH;
    }

    @Override
    public int getOrder() {
        return 50;
    }
}
