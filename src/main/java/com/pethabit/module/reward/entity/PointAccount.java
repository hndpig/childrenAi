package com.pethabit.module.reward.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("point_account")
public class PointAccount {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long childId;
    private Integer balance;
    private Integer totalEarned;
    private ResetCycle resetCycle;
    private LocalDateTime lastResetAt;
    private LocalDateTime createdAt;

    public enum ResetCycle {
        MONTHLY, QUARTERLY, SEMESTER, MANUAL
    }
}
