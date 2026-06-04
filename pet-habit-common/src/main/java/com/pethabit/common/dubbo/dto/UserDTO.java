package com.pethabit.common.dubbo.dto;

import lombok.Data;
import java.io.Serializable;

@Data
public class UserDTO implements Serializable {
    private Long id;
    private String nickname;
    private String phone;
    private String avatarUrl;
    private String role;
    private Boolean enabled;
}
