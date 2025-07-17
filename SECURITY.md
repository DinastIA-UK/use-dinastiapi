# Security Policy / Política de Segurança

## 🔐 Reporting Security Vulnerabilities / Reportando Vulnerabilidades de Segurança

**English:**
The DinastiAPI team takes security seriously. We appreciate your efforts to responsibly disclose your findings and will make every effort to acknowledge your contributions.

**Português:**
A equipe DinastiAPI leva a segurança a sério. Agradecemos seus esforços para divulgar responsavelmente suas descobertas e faremos todos os esforços para reconhecer suas contribuições.

## 📧 How to Report / Como Reportar

**DO NOT create a public GitHub issue for security vulnerabilities.**
**NÃO crie uma issue pública no GitHub para vulnerabilidades de segurança.**

Instead, please report them via email to:
Em vez disso, por favor, reporte por email para:

📧 **security@dinastiapi.com**

### What to Include / O que Incluir

Please include the following information:
Por favor, inclua as seguintes informações:

1. **Type of vulnerability / Tipo de vulnerabilidade**
2. **Full paths of source file(s) / Caminhos completos dos arquivos**
3. **Location of the affected code / Localização do código afetado**
4. **Step-by-step instructions to reproduce / Instruções passo a passo para reproduzir**
5. **Proof-of-concept or exploit code / Código de prova de conceito**
6. **Impact assessment / Avaliação de impacto**
7. **Potential fixes (if any) / Correções potenciais (se houver)**

## ⏱️ Response Timeline / Linha do Tempo de Resposta

- **Initial Response / Resposta Inicial:** Within 48 hours / Em até 48 horas
- **Vulnerability Assessment / Avaliação:** Within 7 days / Em até 7 dias
- **Fix Development / Desenvolvimento da Correção:** Depends on severity / Depende da severidade
- **Public Disclosure / Divulgação Pública:** After fix is released / Após a correção ser lançada

## 🎯 Severity Levels / Níveis de Severidade

### Critical / Crítico
- Remote code execution / Execução remota de código
- Authentication bypass / Bypass de autenticação
- Data exposure of multiple accounts / Exposição de dados de múltiplas contas
- Complete system compromise / Comprometimento completo do sistema

### High / Alto
- Privilege escalation / Escalação de privilégios
- Significant data leakage / Vazamento significativo de dados
- Account takeover / Sequestro de conta
- SQL injection / Injeção SQL

### Medium / Médio
- Cross-site scripting (XSS)
- Information disclosure / Divulgação de informações
- Session fixation / Fixação de sessão
- Rate limiting bypass / Bypass de limite de taxa

### Low / Baixo
- Denial of service / Negação de serviço
- Minor information leaks / Pequenos vazamentos de informação
- Non-sensitive data exposure / Exposição de dados não sensíveis

## 🛡️ Security Best Practices / Melhores Práticas de Segurança

### For Users / Para Usuários

1. **Keep DinastiAPI Updated / Mantenha a DinastiAPI Atualizada**
   - Always use the latest version / Sempre use a versão mais recente
   - Apply security patches immediately / Aplique patches de segurança imediatamente

2. **Secure Your Environment / Proteja seu Ambiente**
   - Use strong authentication / Use autenticação forte
   - Enable HTTPS/TLS / Habilite HTTPS/TLS
   - Restrict API access / Restrinja o acesso à API
   - Monitor logs regularly / Monitore logs regularmente

3. **API Keys & Secrets / Chaves de API e Segredos**
   - Never commit secrets to repositories / Nunca commite segredos em repositórios
   - Use environment variables / Use variáveis de ambiente
   - Rotate keys regularly / Rotacione chaves regularmente
   - Limit key permissions / Limite permissões de chaves

### For Contributors / Para Contribuidores

1. **Code Security / Segurança do Código**
   - Validate all inputs / Valide todas as entradas
   - Use parameterized queries / Use consultas parametrizadas
   - Implement proper error handling / Implemente tratamento de erros adequado
   - Follow OWASP guidelines / Siga as diretrizes OWASP

2. **Dependencies / Dependências**
   - Keep dependencies updated / Mantenha dependências atualizadas
   - Review dependency licenses / Revise licenças de dependências
   - Check for known vulnerabilities / Verifique vulnerabilidades conhecidas

## 🏆 Recognition / Reconhecimento

We maintain a Security Hall of Fame to recognize security researchers who have responsibly disclosed vulnerabilities.

Mantemos um Hall da Fama de Segurança para reconhecer pesquisadores de segurança que divulgaram vulnerabilidades de forma responsável.

### Hall of Fame / Hall da Fama

*To be listed here, security researchers must:*
*Para ser listado aqui, pesquisadores de segurança devem:*

- Follow responsible disclosure practices / Seguir práticas de divulgação responsável
- Not exploit vulnerabilities beyond POC / Não explorar vulnerabilidades além do POC
- Not access user data / Não acessar dados de usuários
- Provide clear reproduction steps / Fornecer passos claros de reprodução

## 📋 Supported Versions / Versões Suportadas

| Version / Versão | Supported / Suportada | Security Updates / Atualizações |
|------------------|----------------------|--------------------------------|
| Latest / Última  | ✅ Yes / Sim         | Immediate / Imediata           |
| Latest - 1      | ✅ Yes / Sim         | High & Critical only           |
| Latest - 2      | ⚠️ Limited / Limitada | Critical only / Apenas críticas |
| Older / Antigas  | ❌ No / Não          | Not supported / Não suportada   |

## 🔍 Security Checklist / Checklist de Segurança

### Before Deployment / Antes da Implantação

- [ ] All dependencies updated / Todas as dependências atualizadas
- [ ] Security scan completed / Varredura de segurança concluída
- [ ] Environment variables configured / Variáveis de ambiente configuradas
- [ ] Access controls implemented / Controles de acesso implementados
- [ ] SSL/TLS configured / SSL/TLS configurado
- [ ] Logs properly configured / Logs configurados adequadamente
- [ ] Backup strategy in place / Estratégia de backup definida
- [ ] Rate limiting enabled / Limitação de taxa habilitada
- [ ] Input validation active / Validação de entrada ativa
- [ ] Error messages sanitized / Mensagens de erro sanitizadas

## 📞 Contact / Contato

- **Security Issues / Problemas de Segurança:** security@dinastiapi.com
- **General Support / Suporte Geral:** contato@dinastiapi.com
- **Emergency / Emergência:** Include "URGENT" in subject / Inclua "URGENTE" no assunto

---

*This security policy is subject to change. Please check regularly for updates.*
*Esta política de segurança está sujeita a alterações. Verifique regularmente por atualizações.*

Last updated / Última atualização: 2025-07-17