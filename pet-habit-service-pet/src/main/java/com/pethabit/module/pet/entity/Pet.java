package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.pethabit.module.pet.enums.Attribute;
import com.pethabit.module.pet.enums.Mood;
import com.pethabit.module.pet.enums.Personality;
import com.pethabit.module.pet.enums.Stage;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("pet")
public class Pet {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long childId;
    private Long speciesId;
    private String name;
    private Stage stage;
    private Attribute attribute;
    private Personality personality;

    /** 五维属性 */
    private Integer hp;
    private Integer attack;
    private Integer defense;
    private Integer agility;
    private Integer mp;

    /** 成长 */
    private Integer exp;
    private Integer level;
    private Mood mood;

    /** 孵化进度 0-100 */
    private Integer incubationProgress;

    /** 活跃状态 */
    private Integer isActive;
    private Integer streakDays;
    private Integer bestStreak;
    private Integer idleDays;
    private Integer isAsleep;

    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
