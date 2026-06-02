package com.pethabit.module.habit.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.pethabit.module.habit.entity.Habit;
import com.pethabit.module.habit.mapper.HabitMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class HabitService {
    private final HabitMapper habitMapper;

    public Habit createHabit(Long parentId, Long childId, String name, Habit.Category category, int difficulty) {
        Habit habit = new Habit();
        habit.setParentId(parentId);
        habit.setChildId(childId);
        habit.setName(name);
        habit.setCategory(category);
        habit.setDifficulty(difficulty);
        habit.setIsActive(1);
        habitMapper.insert(habit);
        return habit;
    }

    public List<Habit> getHabitsByChild(Long childId) {
        return habitMapper.selectList(new QueryWrapper<Habit>().eq("child_id", childId));
    }
}
