package com.pethabit.common.dubbo;

import com.pethabit.common.dubbo.dto.UserDTO;
import java.util.List;

public interface UserDubboService {
    UserDTO getUserById(Long userId);
    List<UserDTO> getUsersByIds(List<Long> userIds);
}
