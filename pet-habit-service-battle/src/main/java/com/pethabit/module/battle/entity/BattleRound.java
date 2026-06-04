package com.pethabit.module.battle.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

@Data
@TableName("battle_round")
public class BattleRound {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long battleId;
    private Integer roundNumber;
    private Long attackerId;
    private Long skillId;
    private Integer damage;
    private Integer defenderHpRemaining;
}
