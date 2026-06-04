package com.pethabit.module.battle.service;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.pethabit.module.battle.entity.BattleRecord;
import com.pethabit.module.battle.mapper.BattleRecordMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class BattleService {
    private final BattleRecordMapper battleRecordMapper;

    public BattleRecord saveRecord(Long winnerId, Long loserId, String skillsUsed) {
        BattleRecord record = new BattleRecord();
        record.setWinnerId(winnerId);
        record.setOpponentId(loserId);
        record.setBattleType(BattleRecord.BattleType.BLUETOOTH);
        battleRecordMapper.insert(record);
        return record;
    }

    public List<BattleRecord> getRecordsByChild(Long childId) {
        return battleRecordMapper.selectList(
            new QueryWrapper<BattleRecord>()
                .eq("initiator_id", childId)
                .or().eq("opponent_id", childId)
        );
    }
}
