package com.pethabit.module.user.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.pethabit.module.user.entity.Notification;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface NotificationMapper extends BaseMapper<Notification> {
}
