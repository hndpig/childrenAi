package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("pet_skill")
public class PetSkill {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long petId;
    private Long skillId;
    private Integer level;
    private Integer slotIndex;
    private LocalDateTime unlockedAt;
}
