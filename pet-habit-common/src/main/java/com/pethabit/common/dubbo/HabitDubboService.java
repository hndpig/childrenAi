package com.pethabit.common.dubbo;

public interface HabitDubboService {
    int getHabitCountByChildId(Long childId);
    int getTodayCheckinCount(Long childId);
}
