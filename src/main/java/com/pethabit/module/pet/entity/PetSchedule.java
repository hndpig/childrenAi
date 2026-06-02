package com.pethabit.module.pet.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalTime;

@Data
@TableName("pet_schedule")
public class PetSchedule {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long petId;
    private ScheduleType scheduleType;
    private LocalTime startTime;
    private LocalTime endTime;

    public enum ScheduleType {
        SCHOOL, REST, SLEEP
    }
}
