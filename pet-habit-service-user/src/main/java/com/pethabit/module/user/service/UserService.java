package com.pethabit.module.user.service;

import com.pethabit.module.user.entity.User;
import com.pethabit.module.user.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UserService {
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    public User register(String phone, String password, String nickname, User.Role role) {
        User user = new User();
        user.setPhone(phone);
        user.setPassword(passwordEncoder.encode(password));
        user.setNickname(nickname);
        user.setRole(role);
        user.setEnabled(1);
        userMapper.insert(user);
        return user;
    }
}
