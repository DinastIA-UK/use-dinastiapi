# 🚀 DinastiAPI Private

<p align="center">
  <img src="https://raw.githubusercontent.com/DinastIA-UK/use-dinastiapi/main/favicon.png" alt="DinastiAPI Private" width="120" height="120">
</p>

<p align="center">
  <strong>🚀 WhatsApp API Gateway with Multi-Device Support, Dashboard, Webhooks, RabbitMQ, S3 Storage, N8N Nodes Community and Chatwoot Integration</strong>
</p>

<p align="center">
  <a href="https://hub.docker.com/r/dinastiapi/dinastiapi-private"><img src="https://img.shields.io/docker/pulls/dinastiapi/dinastiapi-private?style=flat-square&logo=docker&color=blue" alt="Docker Pulls"></a>
  <a href="https://hub.docker.com/r/dinastiapi/dinastiapi-private"><img src="https://img.shields.io/docker/image-size/dinastiapi/dinastiapi-private/latest?style=flat-square&logo=docker&color=blue" alt="Docker Image Size"></a>
  <a href="https://github.com/DinastIA-UK/use-dinastiapi"><img src="https://img.shields.io/github/stars/DinastIA-UK/use-dinastiapi?style=flat-square&logo=github&color=yellow" alt="GitHub Stars"></a>
  <a href="https://github.com/DinastIA-UK/use-dinastiapi/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-Commercial-red?style=flat-square" alt="License"></a>
</p>

## 📋 Sobre o Projeto

**DinastiAPI Private** é uma implementação profissional da biblioteca [@tulir/whatsmeow](https://github.com/tulir/whatsmeow) como um serviço de API RESTful completo com suporte a múltiplos dispositivos, sessões simultâneas e integração com diversas ferramentas empresariais.

### 🎯 Características Principais

- **🔥 Alto Performance**: Desenvolvido em Go para máxima eficiência
- **📱 Multi-Device Support**: Suporte completo a múltiplos dispositivos WhatsApp
- **🔄 Concurrent Sessions**: Múltiplas sessões simultâneas
- **💌 Rich Messages**: Suporte a mensagens de texto, imagens, vídeos, documentos e mais
- **🔗 Webhooks**: Sistema completo de webhooks para eventos em tempo real
- **✅ User Verification**: Verificação avançada de usuários
- **🔐 Authentication**: Sistema de autenticação robusto
- **🐰 RabbitMQ Integration**: Integração completa com RabbitMQ para mensageria
- **☁️ S3 Storage**: Armazenamento de mídia em S3 (AWS, MinIO, etc.)
- **🌐 Proxy Support**: Suporte a proxy para conexões WhatsApp
- **📢 Newsletter/Channels**: Suporte a newsletters e canais WhatsApp
- **📢 Grupos/Comunidads**: Suporte a grupos e comunidades do WhatsApp
- **❤️ System Health**: Monitoramento de saúde do sistema


## 🚀 Quick Start

### Docker (Recomendado)

```yml
# =================== DINASTIAPI STACK PARA PORTAINER ===================
# Stack completa do DinastiAPI com todos os serviços necessários
# Configurada para uso em produção com Docker Swarm via Portainer

services:
  dinastiapi_private:
    image: dinastiapi/dinastiapi-private:latest # CONSULTE AS VERSÕES DISPONÍVEIS NO DOCKER HUB https://hub.docker.com/r/dinastiapi/dinastiapi-private
    networks:
      - network_public
    environment:
      # =================== ADMIN & AUTHENTICATION ===================
      - DINASTIAPI_ADMIN_TOKEN=SEU_TOKEN_AQUI_DO_ADMIN  # SEU TOKEN AQUI DO ADMIN
      - DINASTIAPI_ADDRESS=suaapi.seudominio.com  # SEU DOMINIO AQUI DA API
      - DINASTIAPI_PORT=8080

      - SERVER_IP=  # SEU IP AQUI DA API (EX: 127.0.0.1, 192.168.1.100, etc.)
      - LICENSE_KEY=  # SEU LICENSE KEY AQUI LIBERADO PELO DINASTIAPI
      - INSTANCE_ID=  # SEU IDENTIFICADOR AQUI DO SERVIDOR (EX: SERVIDOR_1, SERVIDOR_2, etc.)

      - LOG_TYPE=console  # TIPO DE LOG (console, json)
      - LOG_COLOR=true  # COR DO LOG (true, false)
      
      # =================== DATABASE CONFIGURATION ===================
      # Option 1: Individual database variables (current method)
      - DB_USER=dinastiapi
      - DB_PASSWORD=SENHA_AQUI_DO_BANCO_DE_DADOS
      - DB_NAME=dinastiapi
      - DB_HOST=postgres_dinastiapi
      - DB_PORT=5432
      - DB_SSLMODE=disable
      - DB_SCHEMA=public

      # Option 2: Single database connection string (production method)
      # Uncomment the line below and comment out the individual variables above
      # - DATABASE_URL=postgres://dinastiapi:SENHA_AQUI_DO_BANCO_DE_DADOS@postgres_dinastiapi:5432/postgres_dinastiapi?sslmode=disable&search_path=public
      # For managed databases: DATABASE_URL=postgres://user:pass@managed-db.example.com:5432/dinastiapi?sslmode=require

      # =================== SESSION & TIMEZONE ===================
      - TZ=America/Sao_Paulo
      - SESSION_DEVICE_NAME=DinastiAPI

      # =================== WEBHOOK INDIVIDUAL POR INSTANICA CONFIGURATIONS ===================
      # "json" or "form" for the default
      - WEBHOOK_FORMAT=json

      # Timeout principal da requisição HTTP
      - WEBHOOK_TIMEOUT=30s

      # Número máximo de tentativas de retry
      - WEBHOOK_MAX_RETRIES=3

      # Delay inicial entre tentativas
      - WEBHOOK_RETRY_DELAY=2s

      # Delay máximo entre tentativas (cap do backoff exponencial)
      - WEBHOOK_MAX_RETRY_DELAY=30s

      # Fator de multiplicação para backoff exponencial
      - WEBHOOK_BACKOFF_FACTOR=2.0

      # Número máximo de requisições simultâneas
      - WEBHOOK_MAX_CONCURRENCY=100

      # =================== GLOBAL SKIP MEDIA DOWNLOAD ===================
      # Enable/disable global skip media download for all users
      - GLOBAL_SKIP_MEDIA_DOWNLOAD=false # ESCOLHA SE VAI ATIVAR O SKIP MEDIA DOWNLOAD GLOBAL
      # Skip events from WhatsApp groups
      - GLOBAL_SKIP_GROUPS=false # ESCOLHA SE VAI ATIVAR O SKIP GROUPS GLOBAL
      # Skip events from WhatsApp newsletters
      - GLOBAL_SKIP_NEWSLETTERS=false # ESCOLHA SE VAI ATIVAR O SKIP NEWSLETTERS GLOBAL
      # Skip events from WhatsApp broadcasts and status updates
      - GLOBAL_SKIP_BROADCASTS=false # ESCOLHA SE VAI ATIVAR O SKIP BROADCASTS GLOBAL
      # Skip user's own messages (sent messages)
      - GLOBAL_SKIP_OWN_MESSAGES=false # ESCOLHA SE VAI ATIVAR O SKIP OWN MESSAGES GLOBAL
      # Skip call events (offers, accepts, terminates)
      - GLOBAL_SKIP_CALLS=false # ESCOLHA SE VAI ATIVAR O SKIP CALLS GLOBAL

      # =================== GLOBAL S3 CONFIGURATION ===================
      # Enable/disable global S3 for media processing
      - GLOBAL_S3_ENABLED=false # ESCOLHA SE VAI ATIVAR O S3 GLOBAL
      # S3 endpoint (leave empty for AWS S3)
      - GLOBAL_S3_ENDPOINT=
      # S3 region
      - GLOBAL_S3_REGION=us-east-1
      # S3 bucket name for global media
      - GLOBAL_S3_BUCKET=
      # S3 access key
      - GLOBAL_S3_ACCESS_KEY=
      # S3 secret key
      - GLOBAL_S3_SECRET_KEY=
      # Use path-style URLs (true for MinIO/compatible)
      - GLOBAL_S3_PATH_STYLE=true
      # Custom public URL for S3 objects (optional)
      - GLOBAL_S3_PUBLIC_URL=
      # Media delivery method: base64, url, or both
      - GLOBAL_S3_MEDIA_DELIVERY=base64
      # Retention days for media (0 = no expiration)
      - GLOBAL_S3_RETENTION_DAYS=0

      # =================== GLOBAL WEBHOOK CONFIGURATION ===================
      # Enable/disable global webhook for all users
      - GLOBAL_WEBHOOK_ENABLED=false # ESCOLHA SE VAI ATIVAR O WEBHOOK GLOBAL
      # URL endpoint to receive all global events
      - GLOBAL_WEBHOOK_URL=https://hook.dinastiapi.com/webhook/global-events # SEU WEBHOOK AQUI
      # Event types to capture (comma-separated or "All")
      - GLOBAL_WEBHOOK_EVENTS=All 
      # HTTP request timeout for webhook calls
      - GLOBAL_WEBHOOK_TIMEOUT=30s
      # Number of retry attempts for failed webhook calls
      - GLOBAL_WEBHOOK_RETRY_COUNT=3
      # Initial delay between retries
      - GLOBAL_WEBHOOK_RETRY_DELAY=2s
      # Maximum delay between retries (exponential backoff cap)
      - GLOBAL_WEBHOOK_MAX_RETRY_DELAY=30s
      # Exponential backoff multiplier for retry delays
      - GLOBAL_WEBHOOK_BACKOFF_FACTOR=2.0
      # Maximum concurrent webhook requests (production ready)
      - GLOBAL_WEBHOOK_CONCURRENCY=100

      # =================== GLOBAL RABBITMQ BASIC CONFIGURATION ===================
      # Enable/disable global RabbitMQ for all users
      - GLOBAL_RABBITMQ_ENABLED=false # ESCOLHA SE VAI ATIVAR O RABBITMQ GLOBAL
      # RabbitMQ connection URL (production cluster)
      - GLOBAL_RABBITMQ_URL=amqp://dinastiapi:SENHA_AQUI_DO_RABBITMQ@rabbitmq_dinastiapi:5672/dinastiapi
      # Event types to publish (comma-separated or "All")
      - GLOBAL_RABBITMQ_EVENTS=All
      # Exchange name for global events
      - GLOBAL_RABBITMQ_EXCHANGE=dinastiapi.global.prod
      - GLOBAL_RABBITMQ_EXCHANGE_TYPE=topic
      # Queue name for global events
      # ===== OPÇÃO 1: FILA ÚNICA (ATUAL) =====
      # GLOBAL_RABBITMQ_QUEUE=dinastiapi.events
      # GLOBAL_RABBITMQ_ROUTING_KEY=events.#
      # ===== OPÇÃO 2: FILAS POR EVENTO (NOVO) =====
      - GLOBAL_RABBITMQ_QUEUE=dinastiapi_{event_type}_events
      - GLOBAL_RABBITMQ_ROUTING_KEY=events.{event_type}.#
      # - GLOBAL_RABBITMQ_QUEUE=dinastiapi.events.prod
      - GLOBAL_RABBITMQ_QUEUE_TYPE=classic
      # Routing key pattern for message routing
      - GLOBAL_RABBITMQ_ROUTING_KEY=events.#
      # Make exchange and queue durable (survive broker restart)
      - GLOBAL_RABBITMQ_DURABLE=true
      # Auto-delete exchange/queue when not in use
      - GLOBAL_RABBITMQ_AUTO_DELETE=false
      # Message delivery mode (2=persistent for production)
      - GLOBAL_RABBITMQ_DELIVERY_MODE=2
      # Exclusive queue for production stability
      - GLOBAL_RABBITMQ_EXCLUSIVE=false
      # No wait for queue creation
      - GLOBAL_RABBITMQ_NO_WAIT=false

      # =================== GLOBAL RABBITMQ PERFORMANCE TUNING (PRODUCTION) ===================
      # High-performance connection pool for production load
      - GLOBAL_RABBITMQ_CONNECTION_POOL_SIZE=50
      # High worker count for concurrent message processing
      - GLOBAL_RABBITMQ_WORKER_COUNT=100
      # Large buffer for high-volume message handling
      - GLOBAL_RABBITMQ_QUEUE_BUFFER_SIZE=100000
      # Enable message batching for maximum throughput
      - GLOBAL_RABBITMQ_ENABLE_BATCHING=true
      # Large batch size for production efficiency
      - GLOBAL_RABBITMQ_BATCH_SIZE=1000
      # Fast batch timeout for low latency
      - GLOBAL_RABBITMQ_BATCH_TIMEOUT_MS=100

      # =================== GLOBAL RABBITMQ RELIABILITY & RESILIENCE ===================
      # Circuit breaker: failures before opening circuit (production settings)
      - GLOBAL_RABBITMQ_CIRCUIT_BREAKER_THRESHOLD=20
      # Circuit breaker: longer timeout for production stability
      - GLOBAL_RABBITMQ_CIRCUIT_BREAKER_TIMEOUT_S=60
      # Extended timeout for individual publish operations
      - GLOBAL_RABBITMQ_PUBLISH_TIMEOUT_MS=10000
      # More retry attempts for production reliability
      - GLOBAL_RABBITMQ_MAX_RETRIES=5
      # Shorter delay between retries for faster recovery
      - GLOBAL_RABBITMQ_RETRY_DELAY_MS=500

      # =================== GLOBAL RABBITMQ MONITORING & LOGGING ===================
      # Frequent metrics collection for production monitoring
      - GLOBAL_RABBITMQ_METRICS_INTERVAL_S=5
      # Enable detailed logging for production troubleshooting
      - GLOBAL_RABBITMQ_ENABLE_DETAILED_LOGS=true
      # Enable metrics logging for production monitoring
      - GLOBAL_RABBITMQ_ENABLE_METRICS_LOG=true

      # =================== GLOBAL RABBITMQ QOS & MESSAGE SETTINGS ===================
      # High QoS prefetch for optimal message distribution
      - GLOBAL_RABBITMQ_QOS_PREFETCH_COUNT=200
      # Mandatory delivery for production reliability
      - GLOBAL_RABBITMQ_MANDATORY=false
      # No immediate flag for production stability
      - GLOBAL_RABBITMQ_IMMEDIATE=false

      # =================== GLOBAL RABBITMQ ADVANCED FEATURES (PRODUCTION) ===================
      # Enable compression for bandwidth optimization in production
      - GLOBAL_RABBITMQ_ENABLE_COMPRESSION=true
      # Enable persistence for production data durability
      - GLOBAL_RABBITMQ_ENABLE_PERSISTENCE=true
      # Enable confirmations for production reliability
      - GLOBAL_RABBITMQ_ENABLE_CONFIRMATION=true

    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: on-failure
      placement:
        constraints: [node.role == manager]
      resources:
        limits:
          cpus: "2"      # Increased for RabbitMQ Global performance
          memory: 2GB    # Increased for high-throughput message processing
        reservations:
          cpus: "1"
          memory: 1GB
      labels:
        - traefik.enable=true
        - traefik.http.routers.dinastiapi_private.rule=Host(`api.dinastiapi.app`)
        - traefik.http.routers.dinastiapi_private.entrypoints=websecure
        - traefik.http.routers.dinastiapi_private.priority=1
        - traefik.http.routers.dinastiapi_private.tls.certresolver=letsencryptresolver
        - traefik.http.routers.dinastiapi_private.service=dinastiapi_private
        - traefik.http.services.dinastiapi_private.loadbalancer.server.port=8080
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s

  # =================== BANCO DE DADOS POSTGRESQL ===================
  postgres_dinastiapi:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=dinastiapi # USUÁRIO DO BANCO DE DADOS
      - POSTGRES_PASSWORD=SENHA_AQUI_DO_BANCO_DE_DADOS # SENHA DO BANCO DE DADOS
      - POSTGRES_DB=dinastiapi # NOME DO BANCO DE DADOS
    volumes:
      - postgres_data_dinastiapi:/var/lib/postgresql/data
    networks: 
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          cpus: '0.5' # CPU DO POSTGRES
          memory: 512MB # MEMÓRIA DO POSTGRES
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-dinastiapi} -d ${POSTGRES_DB:-dinastiapi}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # =================== RABBITMQ (MENSAGERIA) ===================
  rabbitmq_dinastiapi:
    image: rabbitmq:4-management-alpine
    environment:
      - RABBITMQ_DEFAULT_USER=dinastiapi # USUÁRIO DO RABBITMQ
      - RABBITMQ_DEFAULT_PASS=SENHA_AQUI_DO_RABBITMQ # SENHA DO RABBITMQ
      - RABBITMQ_DEFAULT_VHOST=dinastiapi # VHOST DO RABBITMQ
    volumes:
      - rabbitmq_data_dinastiapi:/var/lib/rabbitmq
    networks:
      - network_public
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints: [node.role == manager]
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          cpus: '0.5' # CPU DO RABBITMQ
          memory: 512MB # MEMÓRIA DO RABBITMQ
      labels:
        - traefik.enable=true
        - traefik.http.routers.rabbitmq_dinastiapi.rule=Host(`rabbitmq.dinastiapi.app`) # SEU DOMINIO AQUI DO RABBITMQ
        - traefik.http.routers.rabbitmq_dinastiapi.entrypoints=websecure
        - traefik.http.routers.rabbitmq_dinastiapi.tls.certresolver=letsencryptresolver
        - traefik.http.routers.rabbitmq_dinastiapi.service=rabbitmq_dinastiapi
        - traefik.http.services.rabbitmq_dinastiapi.loadbalancer.server.port=15672
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  postgres_data_dinastiapi:
    name: postgres_data_dinastiapi
    external: true
  rabbitmq_data_dinastiapi:
    name: rabbitmq_data_dinastiapi
    external: true

networks:
  network_public:
    name: network_public
    external: true
```

## 🔧 Integrações

### Chatwoot
Integração completa com Chatwoot para atendimento ao cliente:
- Sincronização bidirecional de mensagens
- Criação automática de conversas
- Suporte a anexos e mídias
- Status de leitura e entrega

### RabbitMQ
Sistema de mensageria assíncrona:
- Eventos em tempo real
- Filas dinâmicas por usuário
- Retry automático
- Dead letter queues

### S3 Compatible Storage
Armazenamento de mídia flexível:
- AWS S3
- MinIO
- DigitalOcean Spaces
- Google Cloud Storage

## 📊 Dashboard

Acesse o dashboard completo em `http://localhost:8080/dashboard` para:
- Monitoramento em tempo real
- Gerenciamento de usuários
- Configuração de webhooks
- Análise de mensagens
- Logs do sistema

## 🔐 Segurança

- Autenticação JWT
- Rate limiting
- Validação de entrada
- Sanitização de dados
- Logs de auditoria
- Criptografia de sessões

## 🌐 Suporte Multi-Arch

Esta imagem suporta múltiplas arquiteturas:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM 64-bit)

## 📋 Requisitos

- **RAM**: Mínimo 512MB, Recomendado 1GB+
- **Storage**: Mínimo 1GB livre
- **Network**: Conexão estável com internet
- **Database**: PostgreSQL 12+

## 🆘 Suporte

Para suporte técnico e comercial:
- **Email**: [contato@dinastiapi.com](mailto:contato@dinastiapi.com)
- **Website**: [https://dinastiapi.com](https://dinastiapi.com)
- **GitHub**: [https://github.com/DinastIA-UK/dinastiAPI](https://github.com/DinastIA-UK/dinastiAPI)

## 📄 Licença

Este projeto está sob licença comercial. Para mais informações sobre licenciamento, entre em contato conosco.

## 🤝 Contribuindo

Este é um projeto privado/comercial. Para contribuições, entre em contato através dos canais de suporte.

---

<p align="center">
  <strong>🚀 Desenvolvido com ❤️ por Setup Automatizado</strong>
</p>

<p align="center">
  <a href="https://dinastiapi.com">Website</a> • 
  <a href="mailto:contato@dinastiapi.com">Email</a> • 
  <a href="https://github.com/DinastIA-UK">GitHub</a>
</p>