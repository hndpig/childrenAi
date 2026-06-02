package com.pethabit.common.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.pethabit.common.entity.Notification;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface NotificationMapper extends BaseMapper<Notification> {
}
