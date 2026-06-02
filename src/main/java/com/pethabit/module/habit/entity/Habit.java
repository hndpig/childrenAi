package com.pethabit.module.habit.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("habit")
public class Habit {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long parentId;
    private Long childId;
    private String name;
    private String description;
    private Category category;
    private Integer difficulty;
    private FrequencyType frequencyType;
    private Integer frequencyValue;
    private String remindTimes;
    private Integer requireReview;
    private Integer isActive;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public enum Category {
        HYGIENE, STUDY, SPORT, LIFE_SKILL, ROUTINE
    }

    public enum FrequencyType {
        DAILY, WEEKLY, CUSTOM
    }
}
