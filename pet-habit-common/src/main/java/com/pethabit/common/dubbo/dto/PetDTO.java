package com.pethabit.common.dubbo.dto;

import lombok.Data;
import java.io.Serializable;

@Data
public class PetDTO implements Serializable {
    private Long id;
    private Long childId;
    private Long speciesId;
    private String name;
    private String stage;
    private String attribute;
    private String personality;
    private Integer hp;
    private Integer attack;
    private Integer defense;
    private Integer agility;
    private Integer mp;
    private Integer exp;
    private Integer level;
    private String mood;
    private Boolean isActive;
}
