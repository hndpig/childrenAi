package com.pethabit.module.reward.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("redemption")
public class Redemption {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long childId;
    private Long rewardId;
    private Status status;
    private Integer cost;
    private Long reviewedBy;
    private LocalDateTime reviewedAt;
    private String rejectReason;
    private LocalDateTime createdAt;

    public enum Status {
        PENDING, APPROVED, REJECTED, FULFILLED
    }
}
