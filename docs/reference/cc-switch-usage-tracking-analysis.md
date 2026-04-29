# CC-Switch 用量追踪（Usage & Cost Tracking）深度源码分析报告

## 一、项目概述

**CC-Switch** 是一款基于 **Tauri 2 + Rust 后端 + React/TypeScript 前端** 的跨平台桌面应用，用于统一管理 Claude Code、Codex、Gemini CLI、OpenCode 和 OpenClaw 五个 AI CLI 工具的 Provider 配置。其核心特性之一 **Usage & Cost Tracking**（用量与费用追踪）通过**本地 HTTP 代理**拦截 API 请求，实时记录 Token 使用量并计算费用。

---

## 二、核心架构流程图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Frontend (React + TypeScript)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ UsageDashboard│  │RequestLogTable│  │UsageTrendChart│  │PricingConfigPanel│  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └────────┬────────┘  │
│         └─────────────────┴─────────────────┴───────────────────┘            │
│                                    │                                        │
│                              Tauri IPC (invoke)                              │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │
┌────────────────────────────────────▼────────────────────────────────────────┐
│                         Backend (Tauri + Rust)                               │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                        Proxy Server (Axum + Hyper)                       ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐ ││
│  │  │  /v1/messages│  │/chat/completions│  │ /v1/responses │  │ /v1beta/*path  │ ││
│  │  │  (Claude)   │  │   (Codex)   │  │   (Codex)   │  │   (Gemini)     │ ││
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └───────┬────────┘ ││
│  │         └─────────────────┴─────────────────┴─────────────────┘          ││
│  │                                    │                                      ││
│  │                         RequestForwarder                                 ││
│  │                    (Failover + Circuit Breaker)                          ││
│  │                                    │                                      ││
│  │                         ProviderRouter                                   ││
│  │              (Select Provider → Adapter → Transform)                     ││
│  │                                    │                                      ││
│  │                              Upstream API                                ││
│  └────────────────────────────────────┼─────────────────────────────────────┘│
│                                       │                                      │
│  ┌────────────────────────────────────┼─────────────────────────────────────┐│
│  │                         Response Processing                              ││
│  │  ┌─────────────────────────────────┼─────────────────────────────────┐   ││
│  │  │        Streaming (SSE)          │      Non-Streaming (JSON)       │   ││
│  │  │  ┌───────────────────────────┐  │  ┌───────────────────────────┐  │   ││
│  │  │  │ SseUsageCollector         │  │  │ TokenUsage::from_*_response│  │   ││
│  │  │  │  - Collect SSE events     │  │  │  - Parse usage from JSON   │   ││
│  │  │  │  - Parse usage on finish  │  │  │  - Log to database         │   ││
│  │  │  └───────────────────────────┘  │  └───────────────────────────┘  │   ││
│  │  └─────────────────────────────────┼─────────────────────────────────┘   ││
│  │                                    │                                      ││
│  │                         UsageLogger::log_with_calculation                  ││
│  │                    (Calculate cost → Save to SQLite)                       ││
│  └────────────────────────────────────┼─────────────────────────────────────┘│
└─────────────────────────────────────┼────────────────────────────────────────┘
                                      │
┌─────────────────────────────────────▼────────────────────────────────────────┐
│                              SQLite Database                                   │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────────────────┐  │
│  │  proxy_request_logs │  │    model_pricing    │  │   usage_daily_rollups  │  │
│  │  (Request details)  │  │  (Price per model)  │  │  (Daily aggregated stats)│  │
│  └─────────────────────┘  └─────────────────────┘  └────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、本地代理实现详解

### 3.1 代理服务器启动

**文件**: `src-tauri/src/proxy/server.rs`

```rust
// 代理服务器基于 Axum + 手动 Hyper HTTP/1.1 accept loop
// 关键特性：preserve_header_case(true) 保留原始请求头大小写

pub async fn start(&self) -> Result<ProxyServerInfo, ProxyError> {
    let addr: SocketAddr = format!("{}:{}", self.config.listen_address, self.config.listen_port)
        .parse()
        .map_err(|e| ProxyError::BindFailed(format!("无效的地址: {e}")))?;

    // 绑定 TCP 监听器
    let listener = tokio::net::TcpListener::bind(&addr)
        .await
        .map_err(|e| ProxyError::BindFailed(e.to_string()))?;

    // 手动 accept loop，使用 peek 捕获原始 header casing
    let handle = tokio::spawn(async move {
        loop {
            let (stream, _remote_addr) = listener.accept().await?;
            
            // Peek raw TCP bytes to capture original header casing
            let original_cases = {
                let mut peek_buf = vec![0u8; 8192];
                match stream.peek(&mut peek_buf).await {
                    Ok(n) => OriginalHeaderCases::from_raw_bytes(&peek_buf[..n]),
                    Err(_) => OriginalHeaderCases::default(),
                }
            };

            // 使用 hyper::server::conn::http1 处理连接
            hyper::server::conn::http1::Builder::new()
                .preserve_header_case(true)
                .serve_connection(TokioIo::new(stream), service)
                .await
        }
    });
}
```

**关键设计决策**:
- **默认端口**: `15721`
- **默认地址**: `127.0.0.1`
- **协议**: HTTP/1.1（为了兼容性和 header case 保留）
- **手动 accept loop**: 为了使用 `stream.peek()` 捕获原始 header 大小写，避免 hyper 自动 lowercase

### 3.2 路由配置

**文件**: `src-tauri/src/proxy/server.rs` (build_router 方法)

```rust
fn build_router(&self) -> Router {
    Router::new()
        // 健康检查
        .route("/health", get(handlers::health_check))
        .route("/status", get(handlers::get_status))
        // Claude API
        .route("/v1/messages", post(handlers::handle_messages))
        .route("/claude/v1/messages", post(handlers::handle_messages))
        // OpenAI Chat Completions API (Codex CLI)
        .route("/chat/completions", post(handlers::handle_chat_completions))
        .route("/v1/chat/completions", post(handlers::handle_chat_completions))
        .route("/codex/v1/chat/completions", post(handlers::handle_chat_completions))
        // OpenAI Responses API (Codex CLI)
        .route("/responses", post(handlers::handle_responses))
        .route("/v1/responses", post(handlers::handle_responses))
        .route("/codex/v1/responses", post(handlers::handle_responses))
        // Gemini API
        .route("/v1beta/*path", post(handlers::handle_gemini))
        .route("/gemini/v1beta/*path", post(handlers::handle_gemini))
        .layer(DefaultBodyLimit::max(200 * 1024 * 1024))  // 200MB body limit
        .with_state(self.state.clone())
}
```

**路由设计特点**:
- 同时支持带前缀和不带前缀的路径（如 `/v1/messages` 和 `/claude/v1/messages`）
- 根据 URL 路径自动判断应用类型，无需客户端额外标识

---

## 四、API 请求拦截机制

### 4.1 拦截方式：修改 CLI 的 Base URL（非系统代理）

**CC-Switch 不依赖系统代理**，而是通过**修改各 CLI 工具的配置文件**来实现请求拦截：

**文件**: `src-tauri/src/services/proxy.rs`

| CLI 工具 | 修改的配置项 | 原始配置 | 接管后配置 |
|---------|------------|---------|----------|
| **Claude Code** | `ANTHROPIC_BASE_URL` | `https://api.anthropic.com` | `http://127.0.0.1:15721` |
| **Codex** | `base_url` (config.toml) + `OPENAI_API_KEY` (auth.json) | `https://api.openai.com` | `http://127.0.0.1:15721/v1` |
| **Gemini CLI** | `GOOGLE_GEMINI_BASE_URL` | `https://generativelanguage.googleapis.com` | `http://127.0.0.1:15721` |

```rust
// Claude 接管逻辑
fn apply_claude_takeover_fields(config: &mut Value, proxy_url: &str) {
    let env = config.entry("env").or_insert_with(|| json!({}));
    env.insert("ANTHROPIC_BASE_URL".to_string(), json!(proxy_url));
    
    // Token 替换为占位符（代理会从数据库读取真实 Token）
    for key in ["ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "OPENAI_API_KEY"] {
        if env.contains_key(key) {
            env.insert(key.to_string(), json!(PROXY_TOKEN_PLACEHOLDER));
        }
    }
}

// Codex 接管逻辑
async fn takeover_live_config_strict(&self, app_type: &AppType) -> Result<(), String> {
    // 1. 修改 auth.json 中的 OPENAI_API_KEY 为占位符
    auth.insert("OPENAI_API_KEY".to_string(), json!(PROXY_TOKEN_PLACEHOLDER));
    
    // 2. 修改 config.toml 中的 base_url
    let updated_config = Self::update_toml_base_url(config_str, &proxy_codex_base_url);
}
```

### 4.2 接管流程（Takeover）

```
用户开启代理接管
    │
    ▼
1. 备份原始 Live 配置 → proxy_live_backup 表
    │
    ▼
2. 同步 Live Token 到数据库（确保代理能读取）
    │
    ▼
3. 设置 live_takeover_active = true（断电保护）
    │
    ▼
4. 写入接管配置（修改 base_url，Token 替换为 PROXY_TOKEN_PLACEHOLDER）
    │
    ▼
5. 启动代理服务器
    │
    ▼
CLI 工具的所有 API 请求自动路由到本地代理
```

**关键设计**:
- **断电保护**: 在写入接管配置前设置 `live_takeover_active` 标志，下次启动时自动恢复
- **Token 安全**: 真实 Token 存储在数据库中，Live 配置中只保留 `PROXY_TOKEN_PLACEHOLDER`
- **自动恢复**: 应用退出时自动恢复原始 Live 配置

---

## 五、Token 使用量解析机制

### 5.1 解析策略：响应体 JSON 解析（非响应头）

**文件**: `src-tauri/src/proxy/usage/parser.rs`

CC-Switch **不读取响应头**中的 token 使用量，而是**解析响应体 JSON**。这是因为：
- 不同 API 提供商的响应格式不同
- 流式响应（SSE）的 token 信息在数据块中
- 响应头通常不包含详细的 usage 信息

### 5.2 TokenUsage 数据结构

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TokenUsage {
    pub input_tokens: u32,
    pub output_tokens: u32,
    pub cache_read_tokens: u32,       // Claude cache read
    pub cache_creation_tokens: u32,   // Claude cache creation
    pub model: Option<String>,        // 实际使用的模型名称
    pub message_id: Option<String>,   // 用于跨源去重
}
```

### 5.3 各 API 格式的解析实现

#### Claude API（非流式）

```rust
pub fn from_claude_response(body: &Value) -> Option<Self> {
    let usage = body.get("usage")?;
    let model = body.get("model").and_then(|v| v.as_str()).map(|s| s.to_string());
    let message_id = body.get("id").and_then(|v| v.as_str()).map(|s| s.to_string());

    Some(Self {
        input_tokens: usage.get("input_tokens")?.as_u64()? as u32,
        output_tokens: usage.get("output_tokens")?.as_u64()? as u32,
        cache_read_tokens: usage.get("cache_read_input_tokens").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        cache_creation_tokens: usage.get("cache_creation_input_tokens").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        model,
        message_id,
    })
}
```

#### Claude API（流式 SSE）

```rust
pub fn from_claude_stream_events(events: &[Value]) -> Option<Self> {
    let mut usage = Self::default();
    
    for event in events {
        match event.get("type").and_then(|v| v.as_str())? {
            "message_start" => {
                // input_tokens 在 message_start 事件中
                if let Some(msg_usage) = event.get("message").and_then(|m| m.get("usage")) {
                    usage.input_tokens = msg_usage.get("input_tokens").and_then(|v| v.as_u64())? as u32;
                    usage.cache_read_tokens = msg_usage.get("cache_read_input_tokens").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                    usage.cache_creation_tokens = msg_usage.get("cache_creation_input_tokens").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                }
            }
            "message_delta" => {
                // output_tokens 在 message_delta 事件中
                if let Some(delta_usage) = event.get("usage") {
                    usage.output_tokens = delta_usage.get("output_tokens").and_then(|v| v.as_u64())? as u32;
                }
            }
            _ => {}
        }
    }
    
    if usage.input_tokens > 0 || usage.output_tokens > 0 {
        Some(usage)
    } else {
        None
    }
}
```

#### OpenAI / Codex API

```rust
// 智能检测格式：prompt_tokens (OpenAI) vs input_tokens (Codex Responses)
pub fn from_codex_response_auto(body: &Value) -> Option<Self> {
    let usage = body.get("usage")?;
    
    if usage.get("prompt_tokens").is_some() {
        // OpenAI Chat Completions 格式
        Self::from_openai_response(body)
    } else if usage.get("input_tokens").is_some() {
        // Codex Responses 格式
        Self::from_codex_response(body)
    } else {
        None
    }
}

pub fn from_openai_response(body: &Value) -> Option<Self> {
    let usage = body.get("usage")?;
    let prompt_tokens = usage.get("prompt_tokens")?.as_u64()?;
    let completion_tokens = usage.get("completion_tokens")?.as_u64()?;
    
    // cached_tokens 在 prompt_tokens_details 中
    let cached_tokens = usage
        .get("prompt_tokens_details")
        .and_then(|d| d.get("cached_tokens"))
        .and_then(|v| v.as_u64())
        .unwrap_or(0) as u32;

    Some(Self {
        input_tokens: prompt_tokens as u32,
        output_tokens: completion_tokens as u32,
        cache_read_tokens: cached_tokens,
        cache_creation_tokens: 0,
        model: body.get("model").and_then(|v| v.as_str()).map(|s| s.to_string()),
        message_id: None,
    })
}
```

#### Gemini API

```rust
pub fn from_gemini_response(body: &Value) -> Option<Self> {
    let usage = body.get("usageMetadata")?;
    let model = body.get("modelVersion").and_then(|v| v.as_str()).map(|s| s.to_string());

    let prompt_tokens = usage.get("promptTokenCount")?.as_u64()? as u32;
    let total_tokens = usage.get("totalTokenCount")?.as_u64()? as u32;
    
    // output_tokens = total_tokens - input_tokens（包含 candidates + thoughts）
    let output_tokens = total_tokens.saturating_sub(prompt_tokens);

    Some(Self {
        input_tokens: prompt_tokens,
        output_tokens,
        cache_read_tokens: usage.get("cachedContentTokenCount").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        cache_creation_tokens: 0,
        model,
        message_id: None,
    })
}
```

### 5.4 流式响应的处理

**文件**: `src-tauri/src/proxy/response_processor.rs`

```rust
pub async fn handle_streaming(
    response: ProxyResponse,
    ctx: &RequestContext,
    state: &ProxyState,
    parser_config: &UsageParserConfig,
) -> Response {
    let stream = response.bytes_stream();
    
    // 创建 SSE 使用量收集器
    let usage_collector = create_usage_collector(ctx, state, status.as_u16(), parser_config);
    
    // 创建带日志和超时的透传流
    let logged_stream = create_logged_passthrough_stream(
        stream, 
        ctx.tag, 
        Some(usage_collector), 
        timeout_config
    );
    
    // 透传给客户端，同时在后台收集 usage
    let body = axum::body::Body::from_stream(logged_stream);
    builder.body(body).unwrap()
}

// SSE 收集器在流结束时触发回调
pub struct SseUsageCollector {
    inner: Arc<SseUsageCollectorInner>,
}

struct SseUsageCollectorInner {
    events: Mutex<Vec<Value>>,
    first_event_time: Mutex<Option<std::time::Instant>>,
    on_complete: UsageCallbackWithTiming,
    finished: AtomicBool,
}

impl SseUsageCollector {
    pub async fn finish(&self) {
        if self.inner.finished.swap(true, Ordering::SeqCst) {
            return;
        }
        
        let events = std::mem::take(&mut *self.inner.events.lock().await);
        let first_token_ms = self.inner.first_event_time.lock().await
            .map(|t| (t - self.inner.start_time).as_millis() as u64);
        
        // 回调中解析 usage 并记录到数据库
        (self.inner.on_complete)(events, first_token_ms);
    }
}
```

**流式处理核心逻辑**:
1. 创建 `SseUsageCollector` 收集所有 SSE 事件
2. 通过 `create_logged_passthrough_stream` 透传数据给客户端
3. 流结束时，调用 `stream_parser` 函数解析所有事件中的 usage
4. 异步记录到数据库（不阻塞客户端响应）

---

## 六、费用计算逻辑

### 6.1 定价模型

**文件**: `src-tauri/src/database/schema.rs`

```sql
CREATE TABLE IF NOT EXISTS model_pricing (
    model_id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    input_cost_per_million TEXT NOT NULL,        -- 每百万输入 token 价格（USD）
    output_cost_per_million TEXT NOT NULL,       -- 每百万输出 token 价格（USD）
    cache_read_cost_per_million TEXT NOT NULL DEFAULT '0',     -- 缓存读取价格
    cache_creation_cost_per_million TEXT NOT NULL DEFAULT '0'  -- 缓存创建价格
);
```

**价格存储格式**:
- 使用 **TEXT 类型**存储字符串化的 Decimal（避免浮点精度问题）
- 单位：**USD per 1M tokens**
- 示例：`claude-sonnet-4-20250514` 的 input 价格可能是 `"3.0"`（$3.0/M tokens）

### 6.2 费用计算算法

**文件**: `src-tauri/src/proxy/usage/calculator.rs`

```rust
pub struct CostCalculator;

impl CostCalculator {
    pub fn calculate(
        usage: &TokenUsage,
        pricing: &ModelPricing,
        cost_multiplier: Decimal,
    ) -> CostBreakdown {
        let million = Decimal::from(1_000_000);

        // 核心逻辑：input_tokens 需要减去 cache_read_tokens（避免缓存部分被重复计费）
        let billable_input_tokens = usage.input_tokens.saturating_sub(usage.cache_read_tokens);

        // 各项基础成本（不含倍率）
        let input_cost = Decimal::from(billable_input_tokens) * pricing.input_cost_per_million / million;
        let output_cost = Decimal::from(usage.output_tokens) * pricing.output_cost_per_million / million;
        let cache_read_cost = Decimal::from(usage.cache_read_tokens) * pricing.cache_read_cost_per_million / million;
        let cache_creation_cost = Decimal::from(usage.cache_creation_tokens) * pricing.cache_creation_cost_per_million / million;

        // 总成本 = 各项基础成本之和 × 倍率
        let base_total = input_cost + output_cost + cache_read_cost + cache_creation_cost;
        let total_cost = base_total * cost_multiplier;

        CostBreakdown {
            input_cost,
            output_cost,
            cache_read_cost,
            cache_creation_cost,
            total_cost,
        }
    }
}
```

**计算要点**:
1. **可计费输入 Token** = `input_tokens - cache_read_tokens`（缓存命中部分不计入输入价格）
2. **缓存读取单独计费** = `cache_read_tokens × cache_read_price`
3. **倍率只作用于最终总价** = `base_total × cost_multiplier`
4. 使用 `rust_decimal::Decimal` 避免浮点精度问题

### 6.3 定价配置优先级

**文件**: `src-tauri/src/proxy/usage/logger.rs`

```rust
pub async fn resolve_pricing_config(&self, provider_id: &str, app_type: &str) -> (Decimal, String) {
    // 1. 获取全局默认倍率和计费模式
    let default_multiplier = self.db.get_default_cost_multiplier(app_type).await.unwrap_or_else(|_| "1".to_string());
    let default_pricing_source = self.db.get_pricing_model_source(app_type).await.unwrap_or_else(|_| "response".to_string());

    // 2. 获取 Provider 级别的覆盖配置
    let provider = self.db.get_provider_by_id(provider_id, app_type).ok().flatten();
    
    let (provider_multiplier, provider_pricing_source) = provider
        .as_ref()
        .and_then(|p| p.meta.as_ref())
        .map(|meta| (
            meta.cost_multiplier.as_deref(),       // Provider 自定义倍率
            meta.pricing_model_source.as_deref(),  // Provider 自定义计费模式
        ))
        .unwrap_or((None, None));

    // 3. 优先级：Provider 配置 > 全局默认配置
    let cost_multiplier = match provider_multiplier {
        Some(value) => Decimal::from_str(value).unwrap_or(default_multiplier),
        None => default_multiplier,
    };

    let pricing_model_source = match provider_pricing_source {
        Some("response") | Some("request") => value.to_string(),
        _ => default_pricing_source,
    };

    (cost_multiplier, pricing_model_source)
}
```

**定价模型来源** (`pricing_model_source`):
- `"response"`: 使用响应中的模型名称查找定价
- `"request"`: 使用请求中的模型名称查找定价

**配置层级**:
1. **Provider 级别** (最高优先级): 每个 Provider 可独立设置 `cost_multiplier` 和 `pricing_model_source`
2. **应用级别**: 每个 app_type (claude/codex/gemini) 可设置默认值
3. **全局默认**: 倍率 `1.0`，计费模式 `"response"`

---

## 七、数据模型与数据库 Schema

### 7.1 核心表结构

**文件**: `src-tauri/src/database/schema.rs`

#### proxy_request_logs（请求日志表）

```sql
CREATE TABLE IF NOT EXISTS proxy_request_logs (
    request_id TEXT PRIMARY KEY,           -- 请求唯一标识（含 session: 前缀用于去重）
    provider_id TEXT NOT NULL,             -- Provider ID
    app_type TEXT NOT NULL,                -- 应用类型 (claude/codex/gemini)
    model TEXT NOT NULL,                   -- 实际使用的模型名称
    request_model TEXT,                    -- 请求中指定的模型名称
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    cache_read_tokens INTEGER NOT NULL DEFAULT 0,
    cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
    input_cost_usd TEXT NOT NULL DEFAULT '0',
    output_cost_usd TEXT NOT NULL DEFAULT '0',
    cache_read_cost_usd TEXT NOT NULL DEFAULT '0',
    cache_creation_cost_usd TEXT NOT NULL DEFAULT '0',
    total_cost_usd TEXT NOT NULL DEFAULT '0',
    latency_ms INTEGER NOT NULL,           -- 请求延迟（毫秒）
    first_token_ms INTEGER,                -- 首 token 时间（毫秒）
    duration_ms INTEGER,                   -- 流式总时长
    status_code INTEGER NOT NULL,          -- HTTP 状态码
    error_message TEXT,                    -- 错误信息
    session_id TEXT,                       -- 会话 ID
    provider_type TEXT,                    -- 供应商类型
    is_streaming INTEGER NOT NULL DEFAULT 0,
    cost_multiplier TEXT NOT NULL DEFAULT '1.0',
    created_at INTEGER NOT NULL,           -- Unix 时间戳
    data_source TEXT NOT NULL DEFAULT 'proxy'  -- 数据来源 (proxy/session)
);

-- 索引
CREATE INDEX idx_request_logs_provider ON proxy_request_logs(provider_id, app_type);
CREATE INDEX idx_request_logs_created_at ON proxy_request_logs(created_at);
CREATE INDEX idx_request_logs_model ON proxy_request_logs(model);
CREATE INDEX idx_request_logs_session ON proxy_request_logs(session_id);
CREATE INDEX idx_request_logs_status ON proxy_request_logs(status_code);
```

#### usage_daily_rollups（日聚合统计表）

```sql
CREATE TABLE IF NOT EXISTS usage_daily_rollups (
    date TEXT NOT NULL,                    -- 日期 (YYYY-MM-DD)
    app_type TEXT NOT NULL,
    provider_id TEXT NOT NULL,
    model TEXT NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,
    input_tokens INTEGER NOT NULL DEFAULT 0,
    output_tokens INTEGER NOT NULL DEFAULT 0,
    cache_read_tokens INTEGER NOT NULL DEFAULT 0,
    cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
    total_cost_usd TEXT NOT NULL DEFAULT '0',
    avg_latency_ms INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (date, app_type, provider_id, model)
);
```

**聚合策略**:
- 明细数据保存在 `proxy_request_logs`
- 完整日期范围的数据聚合到 `usage_daily_rollups`
- 查询时 UNION 两个表的结果，兼顾性能与实时性

### 7.2 数据存储位置

```
~/.cc-switch/
├── cc-switch.db          # SQLite 主数据库（用量、Provider、配置）
├── settings.json         # 设备级 UI 设置
├── backups/              # 自动备份（保留最近 10 个）
├── skills/               # Skills 文件
└── skill-backups/        # Skills 备份
```

---

## 八、各 CLI 工具的适配方式

### 8.1 Claude Code

**适配方式**: 修改 `ANTHROPIC_BASE_URL` 环境变量

**文件**: `src-tauri/src/proxy/handlers.rs`

```rust
pub async fn handle_messages(State(state): State<ProxyState>, request: Request) -> Result<Response, ProxyError> {
    let mut ctx = RequestContext::new(&state, &body, &headers, AppType::Claude, "Claude", "claude").await?;
    
    // 转发请求
    let result = forwarder.forward_with_retry(&AppType::Claude, endpoint, body, headers, extensions, providers).await?;
    
    // 处理响应（支持格式转换，如 OpenRouter → Anthropic）
    process_response(response, &ctx, &state, &CLAUDE_PARSER_CONFIG).await
}
```

**特点**:
- 原生支持 Anthropic API 格式
- 支持通过适配器转换其他格式（如 OpenRouter 的 OpenAI 格式 → Anthropic 格式）
- 支持 thinking signature 整流器（处理 Claude 的 thinking block 兼容性问题）

### 8.2 Codex (OpenAI)

**适配方式**: 修改 `config.toml` 中的 `base_url` + `auth.json` 中的 `OPENAI_API_KEY`

```rust
// 两个主要端点
.route("/chat/completions", post(handlers::handle_chat_completions))  // OpenAI Chat Completions
.route("/responses", post(handlers::handle_responses))                // OpenAI Responses API
.route("/responses/compact", post(handlers::handle_responses_compact)) // Codex 远程压缩
```

**智能解析**:
- 自动检测 OpenAI Chat Completions 格式（`prompt_tokens`）和 Codex Responses 格式（`input_tokens`）
- 支持 SSE 流式和非流式两种模式

### 8.3 Gemini CLI

**适配方式**: 修改 `GOOGLE_GEMINI_BASE_URL` 环境变量

```rust
pub async fn handle_gemini(State(state): State<ProxyState>, uri: Uri, request: Request) -> Result<Response, ProxyError> {
    // Gemini 的模型名称在 URI 中：/v1beta/models/gemini-pro:generateContent
    let mut ctx = RequestContext::new(&state, &body, &headers, AppType::Gemini, "Gemini", "gemini").await?
        .with_model_from_uri(&uri);
    
    process_response(response, &ctx, &state, &GEMINI_PARSER_CONFIG).await
}
```

**特点**:
- 模型名称从 URI 路径中提取
- 解析 `usageMetadata` 字段（`promptTokenCount`, `totalTokenCount`, `cachedContentTokenCount`）
- 输出 tokens = `totalTokenCount - promptTokenCount`（包含 candidates + thoughts）

### 8.4 非标准协议处理

**Claude Code 的非 HTTP 协议**:
- Claude Code 实际上**走的是标准 HTTP API**（Anthropic Messages API）
- 不存在自定义的二进制协议
- CC-Switch 通过拦截 HTTP 请求即可完全覆盖

**如果 CLI 工具不走标准 HTTP API**:
- CC-Switch **不支持**非 HTTP 协议的拦截
- 对于非 HTTP 协议（如 gRPC、WebSocket、自定义二进制协议），需要：
  1. 使用系统级代理（如 mitmproxy、Charles）
  2. 或者 Hook CLI 工具的网络层

---

## 九、前端用量展示组件

### 9.1 组件结构

**文件**: `src/components/usage/`

```
src/components/usage/
├── UsageDashboard.tsx          # 主仪表盘（汇总卡片 + 趋势图 + 标签页）
├── UsageSummaryCards.tsx       # 用量汇总卡片（总请求数、总费用、总 Token）
├── UsageTrendChart.tsx         # 趋势图（按小时/天聚合）
├── RequestLogTable.tsx         # 请求日志表格（分页、筛选）
├── RequestDetailPanel.tsx      # 请求详情面板
├── ProviderStatsTable.tsx      # Provider 统计表格
├── ModelStatsTable.tsx         # 模型统计表格
├── PricingConfigPanel.tsx      # 定价配置面板
├── PricingEditModal.tsx        # 定价编辑弹窗
├── UsageDateRangePicker.tsx    # 日期范围选择器
├── DataSourceBar.tsx           # 数据来源指示条
└── format.ts                   # 格式化工具函数
```

### 9.2 UsageDashboard 核心逻辑

**文件**: `src/components/usage/UsageDashboard.tsx`

```typescript
export function UsageDashboard() {
    const [range, setRange] = useState<UsageRangeSelection>({ preset: "today" });
    const [appType, setAppType] = useState<AppTypeFilter>("all");
    const [refreshIntervalMs, setRefreshIntervalMs] = useState(30000); // 30s 自动刷新

    return (
        <motion.div>
            {/* 应用类型筛选：all / claude / codex / gemini */}
            <div className="flex flex-wrap items-center gap-1.5">
                {APP_FILTER_OPTIONS.map((type) => (
                    <button key={type} onClick={() => setAppType(type)}>
                        {t(`usage.appFilter.${type}`)}
                    </button>
                ))}
            </div>

            {/* 汇总卡片 */}
            <UsageSummaryCards range={range} appType={appType} refreshIntervalMs={refreshIntervalMs} />

            {/* 趋势图 */}
            <UsageTrendChart range={range} appType={appType} refreshIntervalMs={refreshIntervalMs} />

            {/* 标签页：请求日志 / Provider 统计 / 模型统计 */}
            <Tabs defaultValue="logs">
                <TabsContent value="logs">
                    <RequestLogTable range={range} appType={appType} />
                </TabsContent>
                <TabsContent value="providers">
                    <ProviderStatsTable range={range} appType={appType} />
                </TabsContent>
                <TabsContent value="models">
                    <ModelStatsTable range={range} appType={appType} />
                </TabsContent>
            </Tabs>

            {/* 定价配置（折叠面板） */}
            <Accordion>
                <AccordionItem value="pricing">
                    <PricingConfigPanel />
                </AccordionItem>
            </Accordion>
        </motion.div>
    );
}
```

### 9.3 数据查询架构

前端使用 **TanStack Query (React Query)** 进行数据获取和缓存：

```typescript
// src/lib/query/usage.ts
export const usageKeys = {
    all: ["usage"] as const,
    summary: (range: UsageRangeSelection, appType: AppTypeFilter) => 
        [...usageKeys.all, "summary", range, appType] as const,
    trends: (range: UsageRangeSelection, appType: AppTypeFilter) => 
        [...usageKeys.all, "trends", range, appType] as const,
    logs: (range: UsageRangeSelection, appType: AppTypeFilter, page: number) => 
        [...usageKeys.all, "logs", range, appType, page] as const,
    providers: (range: UsageRangeSelection, appType: AppTypeFilter) => 
        [...usageKeys.all, "providers", range, appType] as const,
    models: (range: UsageRangeSelection, appType: AppTypeFilter) => 
        [...usageKeys.all, "models", range, appType] as const,
};
```

---

## 十、关键技术决策与亮点

### 10.1 精度处理

使用 `rust_decimal::Decimal` 而非 `f64` 进行所有费用计算，避免浮点数精度问题：

```rust
let million = Decimal::from(1_000_000);
let input_cost = Decimal::from(billable_input_tokens) * pricing.input_cost_per_million / million;
```

### 10.2 跨源去重

通过 `message_id` 生成统一的 `request_id`（格式：`session:{message_id}`），实现代理日志和会话日志的跨源去重：

```rust
pub fn dedup_request_id(&self) -> String {
    self.message_id
        .as_ref()
        .map(|mid| format!("session:{mid}"))
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string())
}
```

### 10.3 故障转移与熔断器

```rust
// ProviderRouter 持有熔断器状态，跨请求保持
let providers = state.provider_router.select_providers(app_type_str).await?;

// 依次尝试每个 Provider，失败自动切换到下一个
for provider in providers.iter() {
    match forwarder.forward(provider, endpoint, body, headers).await {
        Ok(response) => {
            router.record_result(&provider.id, app_type_str, true, None).await;
            return Ok(response);
        }
        Err(e) => {
            router.record_result(&provider.id, app_type_str, false, Some(e.to_string())).await;
            // 继续尝试下一个 Provider
        }
    }
}
```

### 10.4 日聚合优化

为了处理大量请求日志的查询性能问题，CC-Switch 引入了日聚合表：

```sql
-- 查询时 UNION 明细表和聚合表
SELECT COALESCE(d.total_requests, 0) + COALESCE(r.total_requests, 0), ...
FROM (
    SELECT COUNT(*) as total_requests, ...
    FROM proxy_request_logs WHERE created_at >= ? AND created_at <= ?
) d,
(
    SELECT SUM(request_count) as total_requests, ...
    FROM usage_daily_rollups WHERE date >= ? AND date <= ?
) r
```

---

## 十一、参考与借鉴建议

如果你要设计类似的用量追踪系统，可以参考以下架构决策：

| 维度 | CC-Switch 方案 | 建议 |
|------|---------------|------|
| **拦截方式** | 修改 CLI 配置文件中的 base_url | ✅ 简单可靠，无需系统级权限 |
| **代理协议** | HTTP/1.1 (Axum + Hyper) | ✅ 兼容性好，如需 HTTP/2 可升级 |
| **Token 解析** | 解析响应体 JSON | ✅ 信息完整，支持流式 |
| **费用计算** | rust_decimal 高精度计算 | ✅ 避免浮点精度问题 |
| **数据存储** | SQLite + 日聚合表 | ✅ 本地场景足够，云场景可扩展 |
| **定价配置** | 内置 model_pricing 表 + 可覆盖 | ✅ 灵活且可用户自定义 |
| **倍率支持** | Provider 级 cost_multiplier | ✅ 方便处理中转商加价 |
| **流式处理** | SSE 事件收集 + 结束回调 | ✅ 不阻塞客户端，体验好 |

### 需要改进的点

1. **非 HTTP 协议支持**: 如果 CLI 工具使用 gRPC 或 WebSocket，当前架构无法拦截
2. **实时推送**: 目前前端依赖轮询（TanStack Query），可添加 WebSocket/EventSource 实时推送
3. **多用户/团队**: 当前设计为单机单用户，团队协作需后端服务支持

---

## 十二、关键文件索引

| 文件路径 | 作用 |
|---------|------|
| `src-tauri/src/proxy/server.rs` | 代理服务器启动、路由配置 |
| `src-tauri/src/proxy/handlers.rs` | 各 API 端点处理器 |
| `src-tauri/src/proxy/forwarder.rs` | 请求转发、故障转移 |
| `src-tauri/src/proxy/response_processor.rs` | 响应处理、SSE 流解析 |
| `src-tauri/src/proxy/usage/parser.rs` | Token 使用量解析（核心） |
| `src-tauri/src/proxy/usage/calculator.rs` | 费用计算 |
| `src-tauri/src/proxy/usage/logger.rs` | 用量记录到数据库 |
| `src-tauri/src/proxy/handler_config.rs` | 各 API 解析配置 |
| `src-tauri/src/services/proxy.rs` | 代理服务业务逻辑（接管/恢复） |
| `src-tauri/src/services/usage_stats.rs` | 用量统计查询 |
| `src-tauri/src/database/schema.rs` | 数据库 Schema 定义 |
| `src/components/usage/UsageDashboard.tsx` | 前端用量仪表盘 |

---

*报告生成时间: 2026-04-28*
*分析对象: farion1231/cc-switch (main branch)*
