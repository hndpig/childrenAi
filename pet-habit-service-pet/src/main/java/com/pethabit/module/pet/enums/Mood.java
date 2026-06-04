package com.pethabit.module.pet.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;

public enum Mood {
    EXPECTANT, HAPPY, SAD, SLEEPING;

    @EnumValue
    private final String value;

    Mood() {
        this.value = name();
    }
}
