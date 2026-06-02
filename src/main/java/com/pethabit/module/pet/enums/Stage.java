package com.pethabit.module.pet.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;

public enum Stage {
    EGG, BABY, ADULT, RARE;

    @EnumValue
    private final String value;

    Stage() {
        this.value = name();
    }
}
