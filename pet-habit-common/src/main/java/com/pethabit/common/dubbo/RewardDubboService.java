package com.pethabit.common.dubbo;

public interface RewardDubboService {
    int getPointBalance(Long childId);
    boolean deductPoints(Long childId, int amount, String description);
}
