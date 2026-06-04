package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.pethabit.module.pet.enums.Attribute;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("pet_species")
public class PetSpecies {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String name;
    private Attribute attribute;
    private String description;
    private Integer baseHp;
    private Integer baseAttack;
    private Integer baseDefense;
    private Integer baseAgility;
    private Integer baseMp;
    private String evolutionChain;
    private String spriteUrl;
    private Rarity rarity;
    private Integer isAvailable;

    /** 蛋池投放管理 -- 投放开始时间（NULL=不限） */
    private LocalDateTime availableFromDate;
    /** 蛋池投放管理 -- 投放结束时间（NULL=不限） */
    private LocalDateTime availableToDate;
    /** 蛋池展示排序权重（越小越靠前） */
    private Integer sortOrder;
    /** 投放批次标识（如"GEN1"） */
    private String generation;

    private LocalDateTime createdAt;

    public enum Rarity {
        COMMON, UNCOMMON, RARE, LEGENDARY
    }
}
