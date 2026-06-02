package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.pethabit.module.pet.enums.Personality;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("personality_result")
public class PersonalityResult {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long childId;
    private Long petId;
    private String answersJson;
    private Personality resultType;
    private String dimensionScores;
    private LocalDateTime testedAt;
}
