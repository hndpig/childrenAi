package com.pethabit.module.habit.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.pethabit.module.habit.entity.HabitLog;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface HabitLogMapper extends BaseMapper<HabitLog> {
}
