# 00 — Visão geral

> Status: aprovado · Última atualização: 2026-10-12
> As decisões citadas (D-xxx) estão em [decisoes.md](decisoes.md).

## 1. O que é o CatalystHR

O CatalystHR é uma plataforma de RH com inteligência artificial. Ela reúne admissões, documentos, solicitações, ponto eletrônico e folha de pagamento, sempre com responsáveis, prazos e histórico.

O problema que o produto resolve: hoje o RH operacional depende de e-mails, mensagens e planilhas. Os documentos ficam espalhados, as admissões não têm acompanhamento, os pedidos não têm responsável definido e os dados são redigitados várias vezes.

Existem duas formas de contratar o produto:

| Modalidade | Quem contrata | Marca vista pelo cliente | Quem implanta e atende |
|---|---|---|---|
| **Via parceiro** | Consultoria de RH, BPO de departamento pessoal ou escritório contábil, que revende para as empresas da carteira | A do parceiro (white label) | O parceiro |
| **Direta** (D-120) | A própria empresa | A da empresa, se configurar white label (D-121); senão, a do CatalystHR | A equipe CatalystHR (D-127) |

O admin CatalystHR pode transferir uma empresa de modalidade, levando todo o histórico (D-123).

## 2. Áreas da plataforma

| Área | Quem usa | O que faz |
|---|---|---|
| **Administração CatalystHR** | Equipe CatalystHR | Parceiros, empresas diretas, planos e módulos, cobrança, consumo, biblioteca de modelos padrão, base de conhecimento do sistema, suporte |
| **Painel do parceiro** | Equipe do parceiro | Marca e domínio, equipe, carteira de empresas, modelos de processo, pendências consolidadas |
| **Painel da empresa** | RH e gestores | Cadastros, admissões, documentos, solicitações, ponto, folha, eSocial, painéis |
| **Portal do colaborador** | Colaboradores, no celular (PWA) ou no navegador | Pendências, documentos, solicitações, ponto, holerites, integração, assistente |
| **Acesso da contabilidade** | Contabilidade externa (D-143) | Leitura dos encaminhamentos e relatórios das empresas que atende, confirmação de recebimento |

## 3. Perfis de acesso (D-142, D-143)

Uma pessoa é um único **usuário** (login por CPF ou e-mail, D-054). O acesso dela vem das **memberships**: uma membership liga o usuário a uma empresa (D-050), a um parceiro (D-052) ou a um escritório contábil (D-170). Uma membership pode ter vários perfis (D-051).

| Nível | Perfil | Escopo resumido |
|---|---|---|
| CatalystHR | Superadmin | Tudo |
| CatalystHR | Suporte | Implantação e atendimento das empresas |
| CatalystHR | Financeiro | Planos, cobrança e consumo |
| Parceiro | Administrador | Marca, equipe, modelos, carteira inteira |
| Parceiro | Consultor | Só as empresas atribuídas a ele |
| Empresa | RH administrador | Configurações, usuários e módulos da empresa |
| Empresa | RH analista | Operação de RH no escopo de unidades atribuído |
| Empresa | Gestor | A própria equipe: aprovações, ponto, solicitações |
| Empresa | Colaborador | Os próprios dados, pelo portal |
| Escritório contábil | Administrador | Equipe do escritório (D-172) |
| Escritório contábil | Contador | Leitura dos encaminhamentos e relatórios das empresas atendidas |

A matriz completa de permissões fica em [03-permissoes.md](03-permissoes.md).

## 4. Escopo do MVP

O MVP sai em uma entrega única (D-130). Ponto e folha completos fazem parte dele (D-010, D-011), o que altera a página 14 da apresentação comercial.

| Spec | Módulo |
|---|---|
| [01](01-multi-tenancy-white-label.md) | Multi-tenancy e white label |
| [02](02-identidade-e-acesso.md) | Identidade e acesso |
| [03](03-permissoes.md) | Permissões |
| [04](04-cadastros.md) | Cadastros |
| [05](05-lgpd-seguranca-auditoria.md) | LGPD, segurança e auditoria |
| [06](06-modelos-de-processo.md) | Modelos de processo |
| [07](07-admissao-integracao.md) | Admissão e integração |
| [08](08-documentos.md) | Documentos |
| [09](09-solicitacoes-aprovacoes.md) | Solicitações e aprovações |
| [10](10-ponto-rep-p.md) | Ponto eletrônico (REP-P) |
| [11](11-jornada-banco-de-horas.md) | Jornada e banco de horas |
| [12](12-folha-de-pagamento.md) | Folha de pagamento |
| [13](13-esocial-obrigacoes.md) | eSocial e obrigações |
| [14](14-ia.md) | Inteligência artificial |
| [15](15-notificacoes.md) | Notificações |
| [16](16-portal-colaborador-pwa.md) | Portal do colaborador (PWA) |
| [17](17-paineis.md) | Painéis |
| [18](18-importacao-exportacao.md) | Importação e exportação |
| [19](19-administracao-cobranca.md) | Administração e cobrança |
| [20](20-infraestrutura.md) | Infraestrutura |
| [21](21-recrutamento.md) | Recrutamento (D-146) |
| [22](22-avaliacao-desempenho.md) | Avaliação de experiência e desempenho (D-146) |

### Fora do MVP

- Assinatura digital (D-147)
- Reconhecimento facial e prova de vida (AWS Rekognition), que entram com o app mobile nativo (D-311)
- Cobrança do parceiro às empresas clientes pela plataforma: em avaliação, ver a seção 8

### Princípios do produto

Estes princípios vêm da apresentação e foram confirmados nas decisões:

- **A IA sugere, a pessoa decide.** Nenhum dado é atualizado e nenhum documento é aceito sem revisão humana. O trabalho manual fica disponível em todas as etapas.
- **Cada perfil vê apenas o que precisa para agir.** Notas internas nunca aparecem para o colaborador.
- **Tudo tem responsável, prazo e histórico.**
- **Uma base de código só.** Todos os parceiros e empresas diretas usam a mesma plataforma, configurável, com os dados isolados. Não existem versões exclusivas.

## 5. Glossário

O código usa nomes em inglês (D-141), e estes nomes foram aprovados (D-144). Cada spec de módulo detalha as entidades dela e acrescenta termos novos aqui.

| Termo | Definição | Nome no código |
|---|---|---|
| Parceiro | Empresa que revende o CatalystHR com a própria marca | `Partner` |
| Empresa | Empregador cliente, via parceiro ou direto | `Company` |
| Unidade | Estabelecimento da empresa (filial, planta) | `Unit` |
| Departamento | Área dentro de uma unidade | `Department` |
| Cargo | Função ocupada pelo colaborador | `Position` |
| Usuário | Pessoa com login na plataforma | `User` |
| Membership | Ligação do usuário com uma empresa ou um parceiro, com um ou mais perfis | `Membership` |
| Vínculo empregatício | Contrato de trabalho do colaborador com a empresa (D-053) | `Employment` |
| Modelo de processo | Checklist ou fluxo reutilizável, copiado quando o processo começa (D-091) | `ProcessTemplate` |
| Admissão | Processo de entrada de um colaborador | `Admission` |
| Documento | Arquivo da pasta do colaborador, com categoria e versões | `Document` |
| Solicitação | Pedido com tipo, status, responsável e histórico | `Request` |
| Marcação de ponto | Registro de entrada ou saída no REP-P | `TimeEntry` |
| Folha | Processamento mensal da remuneração | `Payroll` |
| Rubrica | Provento ou desconto da folha | `PayrollItem` |
| Plano | Pacote comercial com preço, limites e cota de IA (D-115) | `Plan` |
| Marca | Configuração de white label (D-167) | `Brand` |
| Escritório contábil | Contabilidade externa com equipe própria (D-170) | `AccountingFirm` |
| Cliente de alocação | Cliente da empresa onde o colaborador trabalha alocado, quando a empresa usa essa opção (D-570) | `AllocationClient` |

## 6. Arquitetura

### Stack (D-020 a D-034)

| Camada | Escolha |
|---|---|
| Aplicação | Ruby on Rails (versões estáveis mais recentes), views em ERB, sem Hotwire e sem React |
| Frontend | Tailwind (tailwindcss-rails), JavaScript puro carregado pelo importmap, PWA para o portal |
| Banco | PostgreSQL com pgvector |
| Jobs | Sidekiq, com agendamentos pelo sidekiq-cron. O Sidekiq precisa de Redis |
| Arquivos | Amazon S3 |
| Chaves | AWS KMS para o certificado A1 (D-075) |
| E-mail | Amazon SES, com letter_opener em desenvolvimento |
| WhatsApp | Twilio |
| IA | Claude Sonnet 5.5 pela API da Anthropic e embeddings pela Voyage AI |
| Cobrança | Mercado Pago; NFS-e pelo Asaas (D-560) |
| PDFs | Prawn (D-263) |
| Endereços | ViaCEP com BrasilAPI de reserva (CEP); Nominatim + mapa Leaflet/OpenStreetMap (coordenadas das unidades) |
| Hospedagem | Railway, região US East (D-500); AWS em São Paulo (D-501); DNS na Cloudflare (D-503) |
| Testes | RSpec e FactoryBot |
| Login | Devise, com MFA TOTP e códigos de recuperação |
| Autorização | CanCanCan |
| Auditoria | PaperTrail, mais a tabela própria de eventos de acesso |
| Observabilidade | Sentry: erros, desempenho, logs e monitores (D-506, D-510, D-512) |
| Antivírus | ClamAV como serviço (D-507) |
| Cache | Solid Cache no Postgres; Redis só para o Sidekiq (D-511) |

### Componentes

```
                   ┌──────────────── Railway ────────────────┐
 Navegador / PWA ──┼─► Rails web (ERB) ──► PostgreSQL+pgvector│
 Totem             │        │                                │
                   │        ▼                                │
                   │     Redis ◄── Sidekiq (jobs + cron)      │
                   └────────┼──────────────┼──────────────────┘
                            │              │
     ┌──────────────┬───────┴──────┬───────┴──────┬──────────────┐
     ▼              ▼              ▼              ▼              ▼
  AWS S3 / KMS   AWS SES       Twilio      Anthropic / Voyage   Mercado Pago
                                                                 
  Webservices do governo: eSocial, FGTS Digital, DCTFWeb (spec 13)
  Reconhecimento facial: AWS Rekognition, fora do MVP (D-311)
```

Os detalhes de ambientes, deploy e CI ficam em [20-infraestrutura.md](20-infraestrutura.md).

## 7. Convenções das specs

Cada spec de módulo segue este roteiro (D-145):

1. **Objetivo:** o problema que o módulo resolve.
2. **Histórias de usuário:** "Como [perfil], quero [ação] para [benefício]".
3. **Regras de negócio:** numeradas como `RN-<spec>-<nº>` (por exemplo, `RN-07-003`).
4. **Estados e transições**, quando houver.
5. **Permissões:** o que cada perfil pode fazer no módulo.
6. **Modelo de dados:** entidades, campos principais e relacionamentos.
7. **Jobs e integrações.**
8. **Critérios de aceite:** no formato Dado / Quando / Então, numerados como `CA-<spec>-<nº>`.
9. **Fora do escopo e em aberto.**

Uma spec só registra o que foi decidido. Pontos ainda não decididos ficam na seção "em aberto" e no [decisoes.md](decisoes.md).

## 8. Em aberto

- **Cobrança do parceiro às empresas clientes:** falta avaliar se e como a plataforma participa dessa cobrança.
