package com.pethabit.common.dubbo;

import com.pethabit.common.dubbo.dto.PetDTO;
import java.util.List;

public interface PetDubboService {
    PetDTO getPetById(Long petId);
    PetDTO getActivePetByChildId(Long childId);
    List<PetDTO> getPetsByChildId(Long childId);
}
