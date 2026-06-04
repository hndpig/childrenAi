package com.pethabit.gateway.audit.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.pethabit.gateway.audit.entity.ApiLogConfig;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;
import java.util.List;

@Mapper
public interface ApiLogConfigMapper extends BaseMapper<ApiLogConfig> {

    @Select("SELECT * FROM gateway_api_log_config WHERE is_active = 1")
    List<ApiLogConfig> findAllActive();
}
