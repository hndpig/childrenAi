package com.pethabit.common.dubbo;

public interface ConfigDubboService {
    String getConfigValue(String configKey);
    Integer getConfigInt(String configKey);
}
