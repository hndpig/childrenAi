package com.pethabit.common;

/**
 * 平台推送抽象接口
 * 不同手表平台（小天才/华为/Apple Watch）实现各自的适配器
 */
public interface PushService {
    void send(String deviceId, String title, String body);
}
