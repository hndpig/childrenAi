package com.pethabit.common.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("notification")
public class Notification {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private NotifyType type;
    private String title;
    private String body;
    private Integer isRead;
    private LocalDateTime createdAt;

    public enum NotifyType {
        HABIT_REMIND, REVIEW_ALERT, REDEEM_ALERT, MOOD_PUSH,
        BATTLE_INVITE, PET_AWAKE, PET_SLEEP, STREAK_MILESTONE
    }
}
