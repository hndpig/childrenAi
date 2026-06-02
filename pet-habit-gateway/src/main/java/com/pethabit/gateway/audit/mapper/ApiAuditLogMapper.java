package com.pethabit.gateway.audit.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.pethabit.gateway.audit.entity.ApiAuditLog;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface ApiAuditLogMapper extends BaseMapper<ApiAuditLog> {
}
