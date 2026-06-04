package com.pethabit.ai.impl;

import com.pethabit.ai.ModelService;
import com.pethabit.ai.dto.ChatMessage;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import java.util.List;

@Slf4j
@Service
public class DeepSeekServiceImpl implements ModelService {

    @Override
    public String chat(String userId, String petId, String message, List<ChatMessage> history) {
        // TODO: 接入 DeepSeek API
        // 1. 根据 userId 和 petId 组装 System Prompt（宠物性格+上下文）
        // 2. 调用 WebClient post https://api.deepseek.com/v1/chat/completions
        // 3. 返回 AI 回复
        log.info("DeepSeek chat: userId={}, petId={}, msg={}", userId, petId, message);
        return "（AI reply pending implementation）";
    }
}
