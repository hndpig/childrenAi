package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.pethabit.module.pet.enums.Stage;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("pet_evolution_log")
public class PetEvolutionLog {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long petId;
    private Stage fromStage;
    private Stage toStage;
    private String triggeredBy;
    private LocalDateTime evolvedAt;
}
