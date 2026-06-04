package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("pet_personality_question")
public class PersonalityQuestion {
    @TableId(type = IdType.AUTO)
    private Long id;
    private String questionText;
    private String optionsJson;
    private Dimension dimension;
    private Integer version;
    private LocalDateTime createdAt;

    public enum Dimension {
        O, C, E, A, N
    }
}
