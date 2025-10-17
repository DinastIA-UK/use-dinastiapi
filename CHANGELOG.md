# 📋 Changelog

Todas as mudanças importantes neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

# 📋 Changelog

Todas as mudanças importantes neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [v1.2.5] - 2025-10-17

### ✨ Destaques da versão
- Eventos individuais agora utilizam o mesmo buffer persistente dos eventos globais, garantindo **ZERO perda** com retentativas consistentes e circuit breaker por transporte.
- Observabilidade completa: logger unificado com Sentry, spans de lifecycle no OpenTelemetry e middleware dedicado para cada requisição HTTP/Admin.
- Novos recursos de API: **Eco de mensagens** (API Echo), sincronização de chats/app-state sob demanda e reforço de DLQ com prune manual via painel admin.
- Stack de transportes global revisada com sanitização de metadados, retries configuráveis e defaults centralizados para SQS, Redis, Webhook e RabbitMQ.

### 🚀 Novos Recursos

#### 🧵 Buffer persistente para eventos individuais
- **Integração completa do Sprint 2**: webhooks e RabbitMQ individuais foram migrados para o mesmo buffer durável (`buffer/database.go`, `buffer/pruner.go`).
- Novo arquivo `individual_transports.go` implementa `EventTransport` para webhooks e RabbitMQ com registro dinâmico por usuário.
- `wmiau.go` ganhou `dispatchIndividualEvent()` e substituiu todas as chamadas diretas por envios via dispatcher → buffer → worker pool.
- `webhook.go` introduziu `sendWebhookSync()` com contexto, timeout, retentativa exponencial e cabeçalho `X-Event-ID`.
- `rabbitmq.go` traz `publishMessageSync()` e `GetUserConfig()` para garantir idempotência (`MessageId`) e carregamento de overrides por usuário.
- `global_dispatcher.go` administra `individualWorkers`, registra/atualiza transportes (`RegisterIndividualTransport`) e garante enqueue com retry exponencial.
- CLI `cmd/loadtest` + binário `bin/loadtest` permitem estressar os buffers (memory, SQLite, Postgres, MySQL) com métricas de enfileiramento e consumo.

#### 🌐 API & Admin
- Novos endpoints:
  - `POST /admin/dlq/prune` — dispara prune imediato no buffer persistente (inclui estatísticas quando disponíveis).
  - `POST /session/echo/api` e `GET /session/echo/api` — habilitam/desabilitam e consultam o eco de mensagens da API.
  - `GET /chat/list`, `POST /sync/app-state`, `POST /sync/history-request`, `POST /sync/full-history` — expõem sincronização de chats, patches e Full History On Demand.
- `/chat/delete-chat` remove conversas via app state com suporte a metadados da última mensagem.
- Eventos enviados pela API passam a gerar eco interno (`api_echo.go`) com envelopes padronizados, respeitando cache de configurações.
- O payload de eco agora carrega o wrapper `apiMessagePayload` com flag `Info.IsFromAPI`, preservando `RawMessage`, `SourceWebMsg`, metadados de newsletter e marcadores de mensagens efêmeras (`IsViewOnce`, `IsDocumentWithCaption`, etc.), permitindo que consumidores diferenciem mensagens originadas pela API de mensagens recebidas normalmente.
- `admin_dlq_handlers.go` ganhou tratamento dedicado para erros `ErrDLQNotFound`, dry-run, exclusão em lote e replay com contagem, reduzindo ambiguidade em diagnósticos.

#### 🎨 Mensagens interativas
- `send_handlers.go` foi ampliado para suportar *carrosséis interativos*, rich cards com múltiplos botões, listas e templates, compartilhando a mesma infraestrutura de eco e buffer.
- Funções utilitárias normalizam botões (`normalizeCarouselButton`) e cards (`normalizeCarouselCard`), garantindo compatibilidade com o cliente e quedas controladas quando o payload estiver fora do formato.
- O fork `whatsmeow` passou a preservar `ContextInfo` e demais campos necessários para flows e carrosséis, evitando perda de experiência no app final.

#### 💬 Mensagens interativas e licenciamento
- Liberação oficial de **botões interativos**, **textos dinâmicos** e **flows** para clientes com licença Enterprise.
- `LICENSE_KEY` agora valida o sufixo `-ENT-` para habilitar recursos avançados – o arquivo `.env.sample` descreve claramente os níveis **BASIC** (default) e **ENTERPRISE**.
- Implementamos o `server.setup` para identificar a licença ativa logo no início da aplicação e disponibilizar os novos handlers (`send_handlers.go`) apenas quando habilitados.
- Novos planos disponíveis:
  - **Assinatura mensal (Premium com botões interativos)**:
  - **Assinatura anual (Premium com botões interativos)**: 
- Documentação atualizada em `README.md` e `CLAUDE.md` ressaltando o processo de upgrade e o contato com o suporte DinastiAPI para ativação imediata.

#### 🔭 Observabilidade e Resiliência
- `setupLogger()` (main) aplica flags + envs e injeta `SentryWriter`, garantindo captura automática de logs `error|fatal|panic`.
- Middleware de tracing (`tracingMiddleware`) e Sentry (`sentryMiddleware`) instrumentam todas as rotas (REST e admin) com spans e breadcrumbs de usuário.
- Hooks de lifecycle: `CaptureApplicationStartup/Shutdown` (monitoring.go) e `TraceApplicationStartup/Shutdown` (tracing.go) produzem spans e eventos em Sentry.
- `helpers.go` ganhou sanitização de URLs/headers antes de logar, evitando exposição de segredos.
- `global_webhook.go`, `global_sqs.go` e `global_redis.go` foram reforçados com retries exponenciais, sanitização de metadados (`SanitizeTransportMetadata`) e cabeçalho `X-Event-ID`.
- `media_processor.go` e `media_helpers.go` compartilham tratamento de mídia (base64 ↔ S3) com geração de chave consistente por evento.
- O ciclo de shutdown passa a aguardar `FlushMonitoring`/`TraceApplicationShutdown`, incluindo timeout controlado e encerramento seguro do tracer provider (inclusive quando tracing estiver desabilitado — fallback no-op agora configurado em `tracing.go`).
- `RecoverWithSentry` e `AddBreadcrumb` estão disponíveis para todos os handlers, garantindo captura de panics e breadcrumbs contextualizados (`category`, `message`, `timestamp`).
- O dispatcher armazena o JSON bruto do evento em `Metadata["_event_json"]`, reidratado antes do envio para transportes, preservando integridade do payload para auditoria/observabilidade.

#### 🗃️ Buffer SQL & Migrations
- `buffer/database.go` introduz buffer relacional com auto-migrations (`buffer/migrations.go`) e pruning configurável.
- Pruner roda em background (auto ou manual via admin) com suporte a partições (Postgres), índices extras e gestão de DLQ (`ReplayDLQEvent`, `DeleteDLQEvent`).
- Novas constantes (`DefaultTransportConfig`) centralizam defaults de timeout, batch, workers e retries para todos os transportes globais.
- O buffer suporta drivers PostgreSQL, MySQL (5.7+/8.0) e SQLite, aplicando `SELECT FOR UPDATE SKIP LOCKED` quando disponível e fallback seguro para cenários legados; colunas ausentes são criadas on-the-fly (`ensureBufferSchemaCompatibility`).
- Métricas internas (`persistentBufferMetrics`) acompanham enfileiramentos, confirmações, DLQ e operações de prune, preparadas para exposição futura.
- A estrutura global de transportes agora é totalmente plugável:
  - `transports/interface.go` aceita clonagem profunda segura, metadados limpos e batch sending.
  - `global_dispatcher.go` registra transports globais (Webhook, SQS, Redis Streams, WebSocket, RabbitMQ) e individuais com `SanitizeTransportMetadata`, restauração de payload (`restoreEventFromMetadata`) e workers dedicados.
  - `global_webhook.go`, `global_sqs.go`, `global_redis.go`, `global_rabbitmq.go` e `global_websocket.go` compartilham o mesmo conjunto de defaults (timeout, retry delay, circuit breaker, batch) via `DefaultTransportConfig`, garantindo comportamento homogêneo.
  - `individual_transports.go` encapsula Webhook/RabbitMQ por usuário, enquanto `global_transports.go` mantém o registro centralizado de cada canal.
  - Circuit breaker, retry exponencial e controle de concorrência foram equiparados para todos os destinos, facilitando futuras integrações (ex.: Kafka, gRPC) com o mesmo contrato.
  - Os novos adaptadores globais permitem fan-out simultâneo: Webhook com idempotência (`X-Event-ID`), RabbitMQ com `MessageId`, SQS com deduplicação FIFO opcional, Redis Streams com `XAdd` resiliente e WebSocket com compressão e reconexão automática.

#### 📊 Ferramentas de teste e monitoramento
- `cmd/loadtest` oferece modo memory/sqlite/postgres/mysql com controle de produtores/consumidores, payload size e TPS alvo, registrando `enq_rate`, `ack_rate`, `failed` e duração total diretamente nos logs (útil para testes de capacidade).
- `BUFFER_MIGRATION_GUIDE.md` documenta toda a jornada de migração, inclusive rollback, diagnóstico de índices/locks e resolução de hotspots de DLQ.

### 🛠️ Configuração e Variáveis de Ambiente
- `.env.sample` recebeu variáveis globais para buffer SQL (`GLOBAL_EVENT_BUFFER_*`), SQS, Redis, WebSocket e eco de API (`ECHO_API_MESSAGES_ENABLED`).
- Logs/Sentry: novos envs (`DINASTIAPI_LOG_LEVEL`, `LOG_TYPE`, `LOG_COLOR`) aplicados automaticamente ao iniciar.
- `go.mod` renomeado para o módulo `dinastiapi` e promoveu `golang.org/x/image` a dependência direta (renderização de miniaturas e processamento de mídia).
- Destaque para `LICENSE_KEY` com exemplos reais (BASIC x ENTERPRISE) e campo `SERVER_IP`, essencial para clientes que expõem rotas públicas em múltiplos ambientes.
- Novo `BUFFER_MIGRATION_GUIDE.md` explica passo a passo a migração entre SQLite, PostgreSQL e MySQL com estratégias de retenção, partições e testes de carga.
- Variáveis relevantes e exemplos práticos:
  ```env
  # Observabilidade
  DINASTIAPI_LOG_LEVEL=debug     # debug|info|warn|error
  LOG_TYPE=json                 # json (default) ou console
  LOG_COLOR=true                # força cores no console
  SENTRY_DSN=https://...@sentry.io/123
  SENTRY_ENVIRONMENT=production
  SENTRY_SAMPLE_RATE=1.0        # 0–1, controla volume de eventos

  # Buffer persistente (usar SQLite local ou banco já existente da API)
  GLOBAL_EVENT_BUFFER_USE_DATABASE=true
  GLOBAL_EVENT_BUFFER_VISIBILITY_TIMEOUT=45s
  GLOBAL_EVENT_BUFFER_RETRY_BASE=5s
  GLOBAL_EVENT_BUFFER_RETRY_MAX=2m
  GLOBAL_EVENT_BUFFER_MAX_ATTEMPTS=12
  GLOBAL_EVENT_BUFFER_ARCHIVE_RETENTION=168h   # 7 dias
  GLOBAL_EVENT_BUFFER_ARCHIVE_SUCCESS=true     # armazena sucesso p/ auditoria

  # SQS (opcional)
  GLOBAL_SQS_ENABLED=true
  GLOBAL_SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123/dinastiapi-global
  GLOBAL_SQS_REGION=us-east-1
  GLOBAL_SQS_DELAY_SECONDS=0
  GLOBAL_SQS_MAX_RETRIES=3

  # Redis Streams (opcional)
  GLOBAL_REDIS_ENABLED=true
  GLOBAL_REDIS_ADDRESS=redis:6379
  GLOBAL_REDIS_STREAM=dinastiapi.events

  # WebSocket Broadcast (opcional)
  GLOBAL_WEBSOCKET_ENABLED=true
  GLOBAL_WEBSOCKET_ENDPOINTS=wss://ws.example.com/broadcast

  # Eco de API
  ECHO_API_MESSAGES_ENABLED=true
  ```
- Orientações de uso:
  - Em ambientes com container/orquestrador, defina `SERVER_IP` ou `PUBLIC_BASE_URL` para que o campo `baseURL` seja calculado corretamente mesmo com múltiplos listeners.
  - Para habilitar o buffer SQL com o mesmo banco da aplicação, basta manter `GLOBAL_EVENT_BUFFER_USE_DATABASE=true` — o wrapper compartilha a conexão principal (Postgres/MySQL) e aplica as migrações automaticamente.
  - Caso prefira SQLite local, deixe `GLOBAL_EVENT_BUFFER_USE_DATABASE=false` e configure `GLOBAL_EVENT_BUFFER_PATH=./data/buffer/global.db`.
  - O eco de API depende tanto da flag global (`ECHO_API_MESSAGES_ENABLED`) quanto da preferência do usuário (`POST /session/echo/api`). Em cenários multi-tenant, recomenda-se deixar o global desabilitado e permitir opt-in individual.
  - Para clientes Enterprise, exponha o `LICENSE_KEY` no container/host e reinicie a aplicação para liberar botões/flows sem necessidade de reconstruir binários.

### 📚 Documentação e Guias
- Guia dos agentes (`AGENTS.md`) e playbook do Claude (`CLAUDE.md`) atualizados com a nova arquitetura de buffer, observabilidade e comandos de load test.
- README reorganizado com fluxos de buffer/unified transport e instruções para eco de API.
- Documentos obsoletos (roadmap, TODO, delivery guarantees legado) removidos em favor do novo guia de migração.

### 📦 Dependências e Protocolos
- `go.mau.fi/whatsmeow` atualizado para `54a1f619e047`, sincronizando protos (`WAWeb`, `WAE2E`, `WASyncAction`, `WAStatusAttributions`) e helpers de envio.
- Buffer SQLite recebeu pragmas adicionais (WAL, cache, mmap) para performance em mono instância.
- Atualizações relevantes do fork `whatsmeow`:
  - Suporte a mensagens interativas/flows com novos campos em `WAWebProtobufsWeb` e `WAWebProtobufsE2E`.
  - Melhorias de reconexão e estado do usuário (`whatsmeow-private/user.go`) para evitar quedas ao ativar eco de API.
  - Ajustes em `send.go`/`sendfb.go` para preservar `ContextInfo` em mensagens com botões e rich cards.
  - Correção definitiva dos *message reactions* em dispositivos que apresentavam inconsistências: o fork agora garante compatibilidade com clientes Android/iOS recentes, devolvendo reações no formato esperado e refletindo corretamente no eco de API.

### 🐛 Correções
- Eventos individuais deixaram de ignorar o buffer (BUG #2 e BUG #3):
  - Retentativas agora seguem política global (até 12 tentativas com backoff 5s → 2min).
  - Processos derrubados não perdem mensagens (WAL + re-enqueue via DLQ).
  - Fim das goroutines órfãs — workers usam pool gerenciado por dispatcher.
- `global_dispatcher` restaura o payload original antes de enviar ao transporte, evitando perda de campos ao consumir metadados.

### ⚠️ Breaking Changes
- **Idempotência obrigatória** para consumidores individuais:
  - Webhooks devem deduplicar via cabeçalho `X-Event-ID`.
  - RabbitMQ deve usar `MessageId` para evitar reprocessamento.
  - Exemplos de handlers idempotentes estão incluídos na documentação interna.

### 📈 Estatísticas da Versão
- 4 commits principais nesta release:
  - `feat(core): overhaul buffer pipeline and observability`
  - `docs: refresh guides for the new event pipeline`
  - `docs(api): regenerate OpenAPI spec and dashboard bundle`
  - `chore(whatsmeow): sync private fork to 54a1f619e047`

## [v1.2.4] - 2025-09-08

### ✨ Destaques da versão
- BaseURL em todos os eventos (Webhook + RabbitMQ) sem poluir o payload do usuário. Cabeçalhos e campos dedicados garantem rastreabilidade/end-to-end.
- S3 Global com modo “Owner enforced”: novo `GLOBAL_S3_DISABLE_ACL` (default: true). Semântica clara de entrega (`base64`, `url` ou `both`).
- Chamadas: rejeição automática com mensagem/tipo globais configuráveis e fallback robusto por usuário.
- Mídia: detecção MIME inteligente, link preview “clean” (og:image, favicon e YouTube), thumbnails de vídeo (ffmpeg) e PDFs (páginas + miniatura).
- LID (Link ID): novos endpoints para converter Phone/JID ↔ LID e listar mapeamentos. Store SQL entende `@lid` e `@s.whatsapp.net` no mesmo lookup.
- Grupos/Comunidades: criação com `context.Context` e flags (announcement/locked/ephemeral/approval); disappearing timer com timestamp.
- Whatsmeow (fork): pareamento híbrido (WhatsApp Business coexistente) e Presence sem PushName no contexto Messenger.

### 🔧 Mudanças de configuração
- Novas variáveis globais
  - `GLOBAL_CALL_REJECT_MESSAGE`: mensagem padrão de rejeição de chamadas.
  - `GLOBAL_CALL_REJECT_TYPE`: `busy` | `decline` | `unavailable` (default: `busy`).
  - `GLOBAL_S3_DISABLE_ACL`: `true` para buckets AWS com “Bucket owner enforced”; `false` para provedores legados (default: `true`).
- `WA_VERSION` atualizado para `2.3000.1026436087`.
- BaseURL passa a ser calculado e cacheado (carregando `.env` automaticamente quando presente). Variáveis úteis: `DINASTIAPI_ADDRESS` e `DINASTIAPI_PORT`.

### 🔌 API e Eventos
- BaseURL incorporado nos eventos
  - Cabeçalhos adicionais nos webhooks: `X-DinastiAPI-BaseURL` (além de usuário/token/jid/eventType).
  - Envelope dos eventos inclui `baseURL` e `source` (p.ex. `dinastiapi-global`).
- Novos endpoints LID
  - `GET/POST /user/lid/get` — Converte Phone/JID → LID.
  - `GET/POST /user/lid/from-lid` — Converte LID → Phone/JID.
  - `GET /user/lid/mappings` — Lista todos os mapeamentos LID ↔ Phone do usuário.
- Exemplo (curl) — obter LID a partir de JID
  ```bash
  curl -H "token: <USER_TOKEN>" \
       "https://<BASE_URL>/user/lid/get?phone=5521971532700@s.whatsapp.net"
  ```
- Exemplo (Webhook payload — campos relevantes)
  ```json
  {
    "userToken":"***",
    "userID":"***",
    "eventType":"message",
    "userName":"Alice",
    "userJID":"55219...@s.whatsapp.net",
    "baseURL":"https://api.seudominio.com",
    "timestamp": 1725750000,
    "source": "dinastiapi-global",
    "data": { "...": "payload do evento sem poluição por metadados de S3" }
  }
  ```

### ☁️ S3 (Global e por usuário)
- Modo delivery global: `GLOBAL_S3_MEDIA_DELIVERY=base64|url|both`.
  - `url`: upload para S3 e remoção do campo `base64` do payload.
  - `both`: upload para S3 mantendo o `base64` no payload.
- `GLOBAL_S3_DISABLE_ACL=true` (AWS moderno) evita aplicar ACL no upload; quando `false`, ACL pública é aplicada (compatibilidade com provedores legados).
- Endpoints de S3 do usuário expostos com `disable_acl` no retorno e nos testes de conexão.

### 📞 Chamadas: rejeição automática
- Fallback global quando usuário não definiu mensagem/tipo:
  - `GLOBAL_CALL_REJECT_MESSAGE` e `GLOBAL_CALL_REJECT_TYPE`.
  - Validação de tipo — valores inválidos caem para `busy` com aviso em log.

### 🖼️ Mídia e Previews
- Detecção MIME inteligente — corrige `application/octet-stream` em áudios/documentos.
- PTT (voice note): força `audio/ogg; codecs=opus` quando necessário.
- Link preview “clean”: coleta metadados (OpenGraph/Twitter), baixa thumbnail e envia como `MediaLinkThumbnail`. Suporte expandido para YouTube via oEmbed e scraping.
- PDF: página inicial renderizada como thumbnail (com largura/altura reais) + `pageCount` no documento.
- Vídeo: thumbnail gerado em memória com fallback automático para imagem padrão quando `ffmpeg` ausente.

### 👥 Grupos/Comunidades
- `CreateGroup(context, req)` com suporte a `announcement`, `locked`, `ephemeral` e `membership_approval_mode`.
- `SetDisappearingTimer(..., settingTS)` grava timestamp de configuração para melhor compatibilidade com o cliente.

### 🔐 Whatsmeow (fork privado)
- Pareamento híbrido (coexistente): fallback de verificação de assinatura com tipo de conta oposto para lidar com inconsistências de detecção (Business/Hosted/regular).
- Presence: envia sem `PushName` quando em contexto Messenger E2EE.

### 🗃️ Migrações de banco
- Migração 15 — cache de avatar: adiciona `avatar_url` e `avatar_updated_at`.
- Migração 16 — S3 sem ACL: adiciona `s3_disable_acl` (default TRUE).
- Compatível com PostgreSQL e MySQL (SQLite auxilia desenvolvimento). Aplicadas automaticamente no startup.

### 📦 Dependências e Tooling
- Go toolchain 1.24.x, bibliotecas atualizadas (protobuf, goquery, unipdf, x/*, etc.).
- CI: matriz Go 1.24/1.25; pre-commit atualizado.
- Protobufs WhatsApp atualizados (E2E/Wa6/SyncAction/HistorySync/StatusAttributions/CompanionReg/Armadillo) e migração de `WAWebProtobufsBotMetadata` → `WABotMetadata`.


## [v1.2.3] - 2025-08-15

### 🚀 Novos Recursos

#### 📚 Swagger/OpenAPI Nativo

- ✅ **Documentação Automática**: Geração automática de specs com UI embutida
  - Endpoint `/api/` para interface interativa
  - Artefatos em `static/api/swagger.json|yaml|docs.go`
  - Anotações nos handlers principais
  - Metadados centralizados em `main.go`
- ✅ **Domains Documentados**: Admin/Global, Session, Chat, Group, Community, Newsletter, Privacy, Business, Device, Webhook
- ✅ **Sem Breaking Changes**: Compatibilidade total com APIs existentes

#### 🗄️ Suporte Completo a MySQL

- ✅ **Novo Provedor MySQL**: Suporte nativo com migrações dedicadas
  - DSN: `mysql://user:pass@host:3306/db?charset=utf8mb4&parseTime=True&loc=Local`
  - Conversão automática de placeholders ($1 → ?) via `DatabaseWrapper`
  - `initialSchemaMySQLSQL` e migrações condicionais por driver
- ✅ **Compatibilidade Mantida**: SQLite e PostgreSQL continuam funcionando
- ✅ **Docker Compose**: Serviço MySQL opcional com tuning e healthcheck

#### 📱 Novos Endpoints de Chat

- ✅ **Envio de PTV**: `POST /chat/send/ptv`
  - Pre-Recorded Transfer Video por link ou base64
  - Suporte a headers de mídia
  ```json
  {
    "Phone": "5511999999999",
    "Video": "https://example.com/video.mp4"
  }
  ```
- ✅ **Retry de Mensagens**: `POST /chat/retry/message`
  - Reprocessamento/recuperação de mensagens recebidas
  - Estratégia: BuildUnavailableMessageRequest + envio ao próprio dispositivo
  ```json
  {
    "MessageID": "ABCD1234...",
    "ChatJID": "5511999999999@s.whatsapp.net",
    "SenderJID": "5511888888888@s.whatsapp.net",
    "RetryType": "incoming",
    "ForceRetry": true
  }
  ```

#### 🌐 Proxy Configurável por Usuário

- ✅ **Endpoint de Proxy**: `POST /session/proxy`
  - Suporte a `http://`, `https://` e `socks5://`
  - Configuração individual por usuário
  - Indicação de necessidade de reconexão
  ```json
  {
    "enable": true,
    "proxy_url": "socks5://user:pass@proxy.example.com:1080"
  }
  ```

#### ⚙️ Configurações Avançadas de Dispositivo WhatsApp (Alpha)

- ✅ **Configurações Globais e por Instância**: Controle total sobre parâmetros do dispositivo
  - Aplicadas ANTES da conexão
  - Configurações por usuário sobrepõem globais
  - Valores inválidos geram warn e usam defaults
- ✅ **Enums Suportados**:
  - **waPlatform**: ANDROID, IOS, WINDOWS_PHONE, WEB, MACOS, etc.
  - **waReleaseChannel**: RELEASE, BETA, ALPHA, DEBUG
  - **waWebSubPlatform**: WEB_BROWSER, APP_STORE, WIN_STORE, DARWIN
  - **waConnectType**: WIFI_UNKNOWN, CELLULAR_LTE, CELLULAR_UMTS, etc.
  - **waPlatformType**: CHROME, FIREFOX, SAFARI, ANDROID_PHONE, IOS_PHONE, etc.
- ✅ **Variáveis de Ambiente**:
  ```bash
  WA_VERSION=2.2413.51
  WA_PLATFORM=WEB
  WA_RELEASE_CHANNEL=RELEASE
  WA_OS_NAME=Mac OS
  WA_DEVICE_NAME=MacBook Pro
  WA_LOCALE_LANGUAGE=pt
  WA_LOCALE_COUNTRY=BR
  ```

### 🛠️ Melhorias Técnicas

#### 🔄 Atualizações do whatsmeow-private

- ✅ **Compatibilidade Recente**: Recursos mais recentes do WhatsApp
- ✅ **Otimizações de Performance**: Melhorias no core da biblioteca
- ✅ **Estabilidade**: Correções e melhorias de conectividade

#### ⚡ Otimizações de Performance

- ✅ **RabbitMQ**: Configurações globais e individuais
- ✅ **Skips Configuráveis**: Otimizações de processamento
- ✅ **Processamento Assíncrono**: Melhor handling de mensagens

#### 🏗️ Refatoração de Tipos

- ✅ **Organização por Domínio**: Tipos reorganizados em `types/*`
- ✅ **Remoção de `types/index.go`**: Estrutura mais limpa
- ✅ **Imports Ajustados**: Melhor organização do código
- ✅ **Payloads Padronizados**: Compatibilidade com Swagger

### 📦 Exemplos de Uso

#### Enviar PTV

```bash
curl -X POST "http://localhost:8080/chat/send/ptv" \
  -H "token: <USER_TOKEN>" -H "Content-Type: application/json" \
  -d '{
    "Phone": "5511999999999",
    "Video": "https://example.com/video.mp4"
  }'
```

#### Configurar Proxy

```bash
curl -X POST "http://localhost:8080/session/proxy" \
  -H "token: <USER_TOKEN>" -H "Content-Type: application/json" \
  -d '{
    "enable": true,
    "proxy_url": "socks5://user:pass@proxy.example.com:1080"
  }'
```

#### Retry de Mensagem

```bash
curl -X POST "http://localhost:8080/chat/retry/message" \
  -H "token: <USER_TOKEN>" -H "Content-Type: application/json" \
  -d '{
    "MessageID": "ABCD1234...",
    "ChatJID": "5511999999999@s.whatsapp.net",
    "SenderJID": "5511888888888@s.whatsapp.net",
    "RetryType": "incoming",
    "ForceRetry": true
  }'
```

### 📈 Estatísticas da Versão

| Categoria            | Quantidade             |
| -------------------- | ---------------------- |
| **Novos Endpoints**  | 3 rotas                |
| **Banco de Dados**   | MySQL + migrações      |
| **Documentação**     | Swagger nativo         |
| **Configurações WA** | 20+ parâmetros         |
| **Otimizações**      | Performance + RabbitMQ |

### 🔄 Compatibilidade

- ✅ **Sem Breaking Changes**: Total compatibilidade com versões anteriores
- ✅ **APIs Existentes**: Todas as funcionalidades anteriores mantidas
- ✅ **Bancos de Dados**: SQLite, PostgreSQL e MySQL suportados
- ✅ **Configurações**: Migração automática e transparente

### 🔧 Migração/Upgrade

- **Banco de Dados**: Drivers mantidos; MySQL plugável; migrações condicionadas por driver
- **Documentação**: Acessar `/api/` para interface Swagger
- **Dispositivo**: Variáveis WA\_\* opcionais; configurações por instância (alpha) requerem reconexão
- **Proxy**: Configuração individual por usuário sem impacto em outros

### 🔒 Segurança e Observabilidade

- ✅ **Logs Estruturados**: Melhor rastreabilidade
- ✅ **Métricas Globais**: Estatísticas expostas por endpoints Admin/Global
- ✅ **Validações**: Mensagens claras para proxy, retry e configurações WA inválidas
- ✅ **Fallbacks**: Configurações inválidas usam defaults seguros

---

## [v1.2.2] - 2025-07-27

### 🚀 Novos Recursos

#### 🎯 Mensagens Interativas

- ✅ **Mensagens de Lista**: Suporte para single select
- ✅ **Novos Endpoints**: `/chat/send/list`

#### 💬 Gerenciamento Avançado de Chat

- ✅ **Pin/Unpin**: Fixar e desfixar conversas importantes
- ✅ **Arquivamento**: Arquivar e desarquivar conversas
- ✅ **Silenciamento**: Silenciar chats por períodos (8h, 1 semana, sempre)
- ✅ **Favoritos**: Marcar/desmarcar mensagens com estrela
- ✅ **Sistema de Labels**: Gerenciamento completo de etiquetas
  - Editar labels existentes
  - Aplicar em chats e mensagens
  - Organização inteligente

#### 🔒 Privacidade e Segurança

- ✅ **Configurações de Privacidade**: Controle total sobre visibilidade
- ✅ **Timer de Mensagens**: Configurar mensagens temporárias
- ✅ **Lista de Bloqueados**: Gerenciar contatos bloqueados
- ✅ **Privacidade de Status**: Controlar quem vê seus status
- ✅ **Configurações Avançadas**: Todas as opções de privacidade do WhatsApp

#### 👥 Comunidades WhatsApp

- ✅ **Criação de Comunidades**: Criar e gerenciar comunidades
- ✅ **Vinculação de Grupos**: Conectar grupos às comunidades
- ✅ **Anúncios**: Enviar anúncios para toda a comunidade
- ✅ **Administração**: Sistema completo de moderação
- ✅ **Solicitações**: Gerenciar pedidos de entrada

#### 💼 Recursos Business

- ✅ **Links Business**: Resolver links de mensagens business
- ✅ **QR Code de Contato**: Gerar QR codes para contatos
- ✅ **Gerenciamento de Bots**: Listar e configurar bots
- ✅ **Perfis de Bots**: Informações detalhadas de bots
- ✅ **Mensagens de Pedido**: Enviar mensagens de pedido (order message)

#### 📱 Gerenciamento de Dispositivos

- ✅ **Listagem de Dispositivos**: Ver todos os dispositivos conectados
- ✅ **Dispositivos Vinculados**: Identificar dispositivos do usuário
- ✅ **Identificação de Plataforma**: Detectar sistema operacional
- ✅ **Consultas Contextuais**: Buscas avançadas com contexto

### 🛠️ Melhorias Técnicas

#### 🔧 Painel Administrativo

- ✅ **Avatares de Usuários**: Exibição de fotos de perfil
- ✅ **Método Interno**: `getAvatarInternal()` para busca eficiente
- ✅ **Informações Completas**: Listagem aprimorada de usuários
- ✅ **Status de Conexão**: Indicadores visuais de conectividade

#### 📊 Constantes e Validações

- ✅ **Tipos de Eventos**: Novos eventos suportados
- ✅ **Mapa de Eventos**: Validação rápida e eficiente
- ✅ **Função de Validação**: `isValidEventType()` para verificações

#### 🔗 Helpers e Utilitários

- ✅ **Processamento de Mídia**: Novos helpers para mídia
- ✅ **Mensagens Interativas**: Funções auxiliares especializadas
- ✅ **Sistema de Callbacks**: Melhorias nos webhooks

#### 🛣️ Rotas e Endpoints

- ✅ **35+ Novas Rotas**: Endpoints RESTful adicionados
- ✅ **Organização por Domínio**: Estrutura clara e lógica
  - `/chat/*` - Operações de chat
  - `/privacy/*` - Configurações de privacidade
  - `/community/*` - Gerenciamento de comunidades
  - `/business/*` - Recursos business
  - `/device/*` - Gerenciamento de dispositivos

#### 📤 Handlers de Envio

- ✅ **SendListMessage()**: Suporte total para listas
- ✅ **Validações Robustas**: Tratamento de erros aprimorado

### 📦 Novos Serviços

#### 🏭 Factory de Mensagens

- ✅ **create_list_message_service.go**
  - Factory para mensagens de lista
  - Múltiplas seções suportadas
  - Validações de tamanho e conteúdo

### 📈 Estatísticas da Versão

| Categoria             | Quantidade   |
| --------------------- | ------------ |
| **Novos Handlers**    | 9 arquivos   |
| **Novos Endpoints**   | 35+ rotas    |
| **Novos Serviços**    | 3 serviços   |
| **Novas Funções**     | 100+ funções |
| **Recursos WhatsApp** | Completo     |

### 🔄 Compatibilidade

- ✅ **Sem Breaking Changes**: Total compatibilidade com versões anteriores
- ✅ **APIs Existentes**: Todas as funcionalidades anteriores mantidas
- ✅ **Configurações**: Compatibilidade total com configurações existentes

### 📚 Documentação

- ✅ **CHANGELOG.md**: Atualizado com todas as mudanças
- ✅ **Dockerfile**: Melhorias na imagem Docker
- ✅ **docker-compose**: Configurações atualizadas
- ✅ **API Spec**: Documentação da API atualizada
- ✅ **Postman**: Coleção atualizada
- ✅ **Dashboard**: Interface HTML melhorada

## 📊 Estatísticas

- **Total de commits**: 64
- **Período**: 2025-06-11 até 2025-07-13

### 👥 Principais Contribuidores

- **Guilherme Jansen**: 52 commit(s)
- **GitHub Action**: 10 commit(s)
- **GitHub Actions Bot**: 2 commit(s)

### 🔗 Links Úteis

- [🚀 GitHub Repository](https://github.com/DinastIA-UK/use-dinastiapi)
- [🐳 Docker Hub](https://hub.docker.com/r/dinastiapi/dinastiapi-private)
- [📖 Documentação](https://github.com/DinastIA-UK/use-dinastiapi/blob/main/README.md)
- [🆘 Suporte](mailto:contato@dinastiapi.com)
