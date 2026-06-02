package com.pethabit.gateway.audit;

import java.util.Set;
import java.util.regex.Pattern;

/**
 * JSON body 脱敏，将敏感字段值替换为掩码。
 */
public final class BodyMaskUtil {


    /**
     * @param maskFields 脱敏字段名集合（如 password, phone, token）
     */
    public static Pattern buildMaskPattern(Set<String> maskFields) {
        if (maskFields == null || maskFields.isEmpty()) {
            return Pattern.compile("(?!)"); // 永不匹配
        }
        String fields = String.join("|", maskFields);
        return Pattern.compile(
                "\"(" + fields + ")\"\\s*:\\s*\"([^\"]*)\"",
                Pattern.CASE_INSENSITIVE
        );
    }

    /**
     * 对 JSON 字符串中的敏感字段值脱敏。
     * phone 类 → 中间4位星号，其余 → 全星号
     */
    public static String mask(String json, Pattern pattern) {
        if (json == null || json.isEmpty()) return json;
        return pattern.matcher(json).replaceAll(match -> {
            String fieldName = match.group(1).toLowerCase();
            String value = match.group(2);
            if (value.isEmpty()) return match.group();
            String masked;
            if (fieldName.contains("phone") || fieldName.contains("mobile")) {
                masked = maskPhone(value);
            } else {
                masked = "***";
            }
            return "\"" + match.group(1) + "\":\"" + masked + "\"";
        });
    }

    private static String maskPhone(String phone) {
        if (phone.length() >= 7) {
            return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
        }
        return "***";
    }

    /**
     * 截断超长字符串
     */
    public static String truncateBytes(String body, int maxBytes) {
        if (body == null) return null;
        if (body.getBytes(java.nio.charset.StandardCharsets.UTF_8).length <= maxBytes) {
            return body;
        }
        // 粗略截断到 maxBytes 字符（UTF-8 1-4字节/字符，取较小侧）
        int cutLen = Math.min(body.length(), maxBytes / 2);
        return body.substring(0, cutLen) + "...[truncated]";
    }

    private BodyMaskUtil() {}
}
