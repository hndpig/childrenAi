package com.pethabit.module.reward.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("reward_item")
public class Reward {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long parentId;
    private String name;
    private String description;
    private Integer cost;
    private RewardType type;
    private Integer stock;
    private RedeemMethod redeemMethod;
    private Integer isActive;
    private LocalDateTime createdAt;

    public enum RewardType {
        TIME, ACTIVITY, ITEM
    }

    public enum RedeemMethod {
        AUTO, MANUAL
    }
}
