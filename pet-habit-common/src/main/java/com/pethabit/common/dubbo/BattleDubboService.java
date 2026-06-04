package com.pethabit.common.dubbo;

public interface BattleDubboService {
    int getWinCount(Long childId);
    int getTotalBattleCount(Long childId);
}
