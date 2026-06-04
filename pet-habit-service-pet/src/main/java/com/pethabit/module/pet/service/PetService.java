package com.pethabit.module.pet.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.pethabit.module.pet.entity.Pet;
import com.pethabit.module.pet.enums.Attribute;
import com.pethabit.module.pet.enums.Stage;
import com.pethabit.module.pet.mapper.PetMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class PetService {
    private final PetMapper petMapper;

    public Pet createPet(Long childId, String name, String species, Attribute attr) {
        Pet pet = new Pet();
        pet.setChildId(childId);
        pet.setName(name);
        pet.setSpeciesId(null); // species lookup TBD
        pet.setAttribute(attr);
        pet.setStage(Stage.EGG);
        pet.setIsActive(1);
        petMapper.insert(pet);
        return pet;
    }

    public List<Pet> getPetsByChild(Long childId) {
        return petMapper.selectList(new QueryWrapper<Pet>().eq("child_id", childId));
    }
}
