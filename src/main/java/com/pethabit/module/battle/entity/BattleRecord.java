package com.pethabit.module.battle.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("battle_record")
public class BattleRecord {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long initiatorId;
    private Long opponentId;
    private Long winnerId;
    private BattleType battleType;
    private LocalDateTime battledAt;

    public enum BattleType {
        BLUETOOTH, FRIENDLY
    }
}
