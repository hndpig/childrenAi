package com.pethabit.module.pet.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;

public enum Attribute {
    FIRE, WATER, GRASS, ELECTRIC, GROUND, LIGHT, DARK;

    @EnumValue
    private final String value;

    Attribute() {
        this.value = name();
    }
}
