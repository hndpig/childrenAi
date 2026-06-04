package com.pethabit.module.reward.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.pethabit.module.reward.entity.PointAccount;
import com.pethabit.module.reward.mapper.PointAccountMapper;
import com.pethabit.module.reward.mapper.RewardMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RewardService {
    private final PointAccountMapper pointAccountMapper;
    private final RewardMapper rewardMapper;

    public PointAccount getOrCreateAccount(Long childId) {
        PointAccount account = pointAccountMapper.selectOne(
            new QueryWrapper<PointAccount>().eq("child_id", childId)
        );
        if (account == null) {
            account = new PointAccount();
            account.setChildId(childId);
            account.setBalance(0);
            account.setTotalEarned(0);
            pointAccountMapper.insert(account);
        }
        return account;
    }
}
