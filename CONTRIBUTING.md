# Contributing to DinastiAPI / Contribuindo para a DinastiAPI

Thank you for your interest in contributing to DinastiAPI! This document provides guidelines for contributing to the project.

Obrigado pelo seu interesse em contribuir para a DinastiAPI! Este documento fornece diretrizes para contribuir com o projeto.

## 📋 Table of Contents / Índice

- [Code of Conduct / Código de Conduta](#code-of-conduct--código-de-conduta)
- [How to Contribute / Como Contribuir](#how-to-contribute--como-contribuir)
- [Development Setup / Configuração de Desenvolvimento](#development-setup--configuração-de-desenvolvimento)
- [Pull Request Process / Processo de Pull Request](#pull-request-process--processo-de-pull-request)
- [Coding Standards / Padrões de Código](#coding-standards--padrões-de-código)
- [Testing / Testes](#testing--testes)
- [Documentation / Documentação](#documentation--documentação)

## 🤝 Code of Conduct / Código de Conduta

### English
- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive criticism
- Accept feedback gracefully
- Prioritize the project's best interests

### Português
- Seja respeitoso e inclusivo
- Acolha novatos e ajude-os a começar
- Foque em críticas construtivas
- Aceite feedback com elegância
- Priorize os melhores interesses do projeto

## 🚀 How to Contribute / Como Contribuir

### Types of Contributions / Tipos de Contribuições

1. **Bug Reports / Relatórios de Bug**
   - Use the bug report template / Use o template de relatório de bug
   - Include detailed reproduction steps / Inclua passos detalhados de reprodução
   - Provide system information / Forneça informações do sistema

2. **Feature Requests / Solicitações de Recursos**
   - Use the feature request template / Use o template de solicitação de recurso
   - Explain the use case clearly / Explique o caso de uso claramente
   - Consider backward compatibility / Considere compatibilidade retroativa

3. **Code Contributions / Contribuições de Código**
   - Fix bugs / Corrigir bugs
   - Add new features / Adicionar novos recursos
   - Improve performance / Melhorar performance
   - Enhance documentation / Melhorar documentação

4. **Documentation / Documentação**
   - Fix typos and errors / Corrigir erros de digitação
   - Add examples / Adicionar exemplos
   - Translate content / Traduzir conteúdo
   - Improve clarity / Melhorar clareza

## 🛠️ Development Setup / Configuração de Desenvolvimento

### Prerequisites / Pré-requisitos

```bash
# Required / Necessário
- Go 1.21+ 
- Docker 20.10+
- Git

# Optional / Opcional
- Docker Compose
```

### Setup Steps / Passos de Configuração

1. **Fork the repository / Fork o repositório**
   ```bash
   # Click the 'Fork' button on GitHub
   # Clique no botão 'Fork' no GitHub
   ```

2. **Clone your fork / Clone seu fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/use-dinastiapi.git
   cd use-dinastiapi
   ```

3. **Add upstream remote / Adicione o remote upstream**
   ```bash
   git remote add upstream https://github.com/dinastiapi/use-dinastiapi.git
   ```

4. **Install dependencies / Instale dependências**
   ```bash
   go mod download
   ```

5. **Setup environment / Configure o ambiente**
   ```bash
   cp .env.example .env
   # Edit .env with your configurations
   # Edite .env com suas configurações
   ```

6. **Run locally / Execute localmente**
   ```bash
   # Using Docker / Usando Docker
   docker-compose up -d
   
   # Or directly / Ou diretamente
   go run main.go
   ```

## 🔄 Pull Request Process / Processo de Pull Request

### 1. Before Starting / Antes de Começar

- Check existing issues and PRs / Verifique issues e PRs existentes
- Discuss major changes first / Discuta mudanças importantes primeiro
- Keep PRs focused and small / Mantenha PRs focados e pequenos

### 2. Branch Naming / Nomenclatura de Branch

```bash
# Format / Formato
feature/description    # New features / Novos recursos
fix/description       # Bug fixes / Correções de bugs
docs/description      # Documentation / Documentação
perf/description      # Performance / Performance
refactor/description  # Refactoring / Refatoração

# Examples / Exemplos
feature/add-telegram-integration
fix/webhook-retry-logic
docs/update-api-examples
```

### 3. Commit Messages / Mensagens de Commit

Follow conventional commits / Siga commits convencionais:

```bash
# Format
type(scope): description

# Types
feat:     New feature / Novo recurso
fix:      Bug fix / Correção de bug
docs:     Documentation / Documentação
style:    Formatting / Formatação
refactor: Code restructuring / Reestruturação de código
perf:     Performance improvement / Melhoria de performance
test:     Adding tests / Adicionando testes
chore:    Maintenance / Manutenção

# Examples / Exemplos
feat(api): add message scheduling endpoint
fix(webhook): handle timeout errors properly
docs(readme): update installation instructions
```

### 4. PR Checklist / Checklist do PR

- [ ] Code follows project style / Código segue estilo do projeto
- [ ] Tests added/updated / Testes adicionados/atualizados
- [ ] Documentation updated / Documentação atualizada
- [ ] Changelog entry added / Entrada no changelog adicionada
- [ ] No breaking changes (or discussed) / Sem mudanças incompatíveis (ou discutidas)
- [ ] PR template completed / Template do PR preenchido

### 5. Review Process / Processo de Revisão

1. **Automated checks / Verificações automatizadas**
   - CI/CD pipeline must pass / Pipeline CI/CD deve passar
   - Code quality checks / Verificações de qualidade
   - Security scans / Varreduras de segurança

2. **Manual review / Revisão manual**
   - At least one maintainer approval / Pelo menos uma aprovação de mantenedor
   - Address all feedback / Responda todo feedback
   - Keep discussions professional / Mantenha discussões profissionais

## 📝 Coding Standards / Padrões de Código

### Go Code Style / Estilo de Código Go

1. **Follow Go conventions / Siga convenções Go**
   ```go
   // Good / Bom
   func SendMessage(ctx context.Context, msg *Message) error {
       // implementation
   }
   
   // Bad / Ruim
   func send_message(ctx context.Context, msg *Message) error {
       // implementation
   }
   ```

2. **Error handling / Tratamento de erros**
   ```go
   // Always check errors / Sempre verifique erros
   result, err := someFunction()
   if err != nil {
       return fmt.Errorf("failed to do something: %w", err)
   }
   ```

3. **Comments and documentation / Comentários e documentação**
   ```go
   // SendMessage sends a WhatsApp message to the specified recipient.
   // It returns an error if the message cannot be sent.
   func SendMessage(recipient string, content string) error {
       // Implementation details...
   }
   ```

### Project Structure / Estrutura do Projeto

```
use-dinastiapi/
├── cmd/           # Application entrypoints / Pontos de entrada
├── internal/      # Private application code / Código privado
├── pkg/           # Public libraries / Bibliotecas públicas
├── api/           # API definitions / Definições de API
├── configs/       # Configuration files / Arquivos de configuração
├── docs/          # Documentation / Documentação
├── scripts/       # Build/deploy scripts / Scripts de build/deploy
└── tests/         # Test files / Arquivos de teste
```

## 🧪 Testing / Testes

### Test Requirements / Requisitos de Teste

1. **Unit tests / Testes unitários**
   ```bash
   # Run all tests / Execute todos os testes
   go test ./...
   
   # With coverage / Com cobertura
   go test -cover ./...
   ```

2. **Integration tests / Testes de integração**
   ```bash
   # Run integration tests / Execute testes de integração
   go test -tags=integration ./...
   ```

3. **Test structure / Estrutura de teste**
   ```go
   func TestSendMessage(t *testing.T) {
       // Arrange
       client := NewTestClient()
       message := &Message{Content: "Test"}
       
       // Act
       err := client.SendMessage(message)
       
       // Assert
       assert.NoError(t, err)
   }
   ```

### Coverage Requirements / Requisitos de Cobertura

- New code: minimum 80% / Código novo: mínimo 80%
- Critical paths: 90%+ / Caminhos críticos: 90%+
- Overall project: maintain or improve / Projeto geral: manter ou melhorar

## 📚 Documentation / Documentação

### Documentation Types / Tipos de Documentação

1. **Code documentation / Documentação de código**
   - GoDoc comments / Comentários GoDoc
   - Inline explanations / Explicações inline
   - Example usage / Uso de exemplo

2. **API documentation / Documentação de API**
   - OpenAPI/Swagger specs
   - Request/response examples / Exemplos de requisição/resposta
   - Error codes and meanings / Códigos de erro e significados

3. **User documentation / Documentação do usuário**
   - Installation guides / Guias de instalação
   - Configuration options / Opções de configuração
   - Troubleshooting / Solução de problemas

### Documentation Standards / Padrões de Documentação

- Write in both English and Portuguese / Escreva em inglês e português
- Include practical examples / Inclua exemplos práticos
- Keep it up-to-date / Mantenha atualizado
- Test all code examples / Teste todos os exemplos de código

## 🎯 Getting Help / Obtendo Ajuda

### Resources / Recursos

- **Documentation / Documentação:** [docs.dinastiapi.com](https://docs.dinastiapi.com)
- **Discussions / Discussões:** GitHub Discussions
- **Email:** contato@dinastiapi.com

### Questions? / Dúvidas?

- Check existing issues / Verifique issues existentes
- Search documentation / Pesquise na documentação
- Ask in discussions / Pergunte nas discussões
- Contact maintainers / Contate os mantenedores

---

**Thank you for contributing to DinastiAPI! / Obrigado por contribuir com a DinastiAPI!** 🚀