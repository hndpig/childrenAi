package com.pethabit.module.reward.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("reward_achievement")
public class Achievement {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;
    private String description;
    private String iconUrl;
    private ConditionType conditionType;
    private Integer conditionValue;
    private LocalDateTime createdAt;

    public enum ConditionType {
        STREAK_DAYS, TOTAL_HABITS, PET_EVOLVED, BATTLE_WINS, SKILLS_UNLOCKED, POINTS_EARNED
    }
}
