package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.pethabit.module.pet.enums.Attribute;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("pet_skill_def")
public class Skill {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;
    private SkillType type;
    private Integer power;
    private Integer accuracy;
    private Integer mpCost;
    private String description;
    private Attribute attributeRequired;
    private HabitCategory categoryRequired;
    private Integer minDifficulty;
    private Integer minLevel;
    private Rarity rarity;
    private LocalDateTime createdAt;

    public enum SkillType {
        ATTACK, DEFENSE, HEAL, BUFF, DEBUFF
    }

    public enum HabitCategory {
        HYGIENE, STUDY, SPORT, LIFE_SKILL, ROUTINE
    }

    public enum Rarity {
        COMMON, UNCOMMON, RARE
    }
}
