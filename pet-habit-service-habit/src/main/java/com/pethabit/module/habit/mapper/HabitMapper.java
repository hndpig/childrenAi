package com.pethabit.module.habit.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.pethabit.module.habit.entity.Habit;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface HabitMapper extends BaseMapper<Habit> {
}
