package com.pethabit.module.user.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@TableName("user_parent_child_binding")
public class ParentChildBinding {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long parentId;
    private Long childId;
    private String nickname;
    private LocalDateTime createdAt;
}
