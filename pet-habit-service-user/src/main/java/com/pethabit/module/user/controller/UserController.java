package com.pethabit.module.user.controller;
import com.pethabit.common.Result;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/user")
public class UserController {

    @PostMapping("/register")
    public Result<Void> register() {
        // TODO: register logic
        return Result.success();
    }

    @PostMapping("/login")
    public Result<Void> login() {
        // TODO: login logic
        return Result.success();
    }
}
