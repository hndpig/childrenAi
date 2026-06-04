package com.pethabit.module.pet.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;

public enum Personality {
    LIVELY, GENTLE, TSUNDERE, DOODLE, BRAVE, PLAYFUL;

    @EnumValue
    private final String value;

    Personality() {
        this.value = name();
    }
}
