package com.pethabit.module.reward.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("point_transaction")
public class PointTransaction {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long childId;
    private Integer amount;
    private TransactionType type;
    private String description;
    private Long relatedId;
    private LocalDateTime createdAt;

    public enum TransactionType {
        HABIT_REWARD, STREAK_BONUS, REDEEM, RESET, ADJUST
    }
}
