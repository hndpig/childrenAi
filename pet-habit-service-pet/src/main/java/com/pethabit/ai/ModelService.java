package com.pethabit.ai;

import com.pethabit.ai.dto.ChatMessage;
import java.util.List;

/**
 * AI 模型抽象接口
 * 支持切换 DeepSeek / OpenAI / 通义等不同 LLM 供应商
 */
public interface ModelService {
    String chat(String userId, String petId, String message, List<ChatMessage> history);
}
