# 01 — Multi-tenancy e white label

> Status: aprovado · Última atualização: 2026-10-12
> Decisões: D-028, D-040, D-041, D-120 a D-123, D-150 a D-168 ([decisoes.md](decisoes.md))
> Os itens marcados **[P-01-nn]** foram aprovados, alguns com ajuste (D-167, seção 10).

## 1. Objetivo

Garantir três coisas:

- **Isolamento:** os dados de cada empresa ficam isolados, e cada usuário só acessa o que as memberships dele permitem.
- **Marca:** cada parceiro, e cada empresa direta que quiser, opera com a própria marca, em um subdomínio da plataforma criado automaticamente.
- **Base única:** tudo isso com uma base de código e um banco compartilhados.

## 2. Conceitos

| Conceito | Descrição |
|---|---|
| **Tenant** | A empresa (`Company`). Os dados operacionais pertencem a uma empresa e ficam isolados por ela (D-151). |
| **Dono do subdomínio** | Um parceiro (`Partner`) ou uma empresa direta (`Company` sem parceiro). |
| **Marca** | A configuração visual e de comunicação, na entidade `Brand`, de dono polimórfico **[P-01-01]**. O dono pode ser um parceiro, uma empresa direta ou uma empresa cliente com marca própria (D-163). |
| **Subdomínio** | `<slug>.painel.catalysthr.com.br`. Identifica a marca em cada requisição (D-153). |
| **Empresa atual** | A empresa escolhida pelo usuário depois do login. É o tenant ativo da sessão. |

### Hierarquia

```
CatalystHR (admin.catalysthr.com.br)
├── Parceiro ── Marca ── aurora.painel.catalysthr.com.br
│   ├── Empresa A ── Unidades ── Departamentos
│   └── Empresa B ── ...
└── Empresa direta ── Marca ── serraazul.painel.catalysthr.com.br
    └── Unidades ── Departamentos
```

- A empresa tem `partner_id` opcional (D-120). Se tem parceiro, usa a marca e o subdomínio do parceiro (D-154). Se é direta, tem marca e subdomínio próprios (D-121).
- Enquanto a equipe CatalystHR não configura a marca de uma empresa direta, o subdomínio dela mostra o nome comercial da empresa em texto, no lugar do logo, com as cores padrão do CatalystHR **[P-01-02]**.

## 3. Histórias de usuário

1. Como **admin CatalystHR**, quero cadastrar um parceiro ou uma empresa direta e definir o subdomínio, para que eles comecem a operar sem configuração técnica.
2. Como **admin CatalystHR**, quero trocar o subdomínio de uma marca sem quebrar o acesso de quem já usa o endereço antigo.
3. Como **administrador do parceiro**, quero configurar logo, cores, tela de login, suporte e textos legais, para que meus clientes vejam só a minha marca.
4. Como **administrador do parceiro**, quero verificar o domínio de e-mail da minha empresa, para que os e-mails saiam com o meu endereço.
5. Como **consultor do parceiro**, quero alternar entre as empresas que atendo sem sair do sistema.
6. Como **colaborador**, quero instalar o portal no celular com o nome e o ícone da marca que conheço.
7. Como **usuário com vínculos em marcas diferentes**, quero entrar em cada uma com o mesmo login.
8. Como **admin CatalystHR**, quero transferir uma empresa entre parceiros ou para a modalidade direta sem perder o histórico.

## 4. Regras de negócio

### Resolução do tenant

- **RN-01-001** — Toda requisição é resolvida pelo host:
  - `admin.catalysthr.com.br` abre a área administrativa CatalystHR (D-156);
  - `<slug>.painel.catalysthr.com.br` abre a marca com aquele slug;
  - um slug antigo ainda dentro dos 90 dias responde com redirecionamento 301 para o mesmo caminho no slug novo (D-157);
  - qualquer outro host recebe uma página 404 neutra, sem marca.
- **RN-01-002** — Em um subdomínio, o login só considera as memberships daquela marca (D-158):
  - memberships de parceiro desse parceiro;
  - memberships das empresas desse parceiro;
  - ou memberships da empresa direta dona do subdomínio.

  Quem não tem membership na marca vê a mesma mensagem de credencial inválida, sem revelar que a conta existe em outra marca **[P-01-03]**.
- **RN-01-003** — O cookie de sessão vale só para o host atual, sem compartilhar sessão entre subdomínios **[P-01-04]**.
- **RN-01-004** — Depois do login, o sistema define a área inicial:
  - membership em uma única empresa: essa empresa vira a empresa atual;
  - mais de uma empresa, ou membership de parceiro: o usuário escolhe;
  - administrador ou consultor do parceiro: vai para o painel do parceiro, que não tem empresa atual.
- **RN-01-005** — A empresa atual fica na sessão. Trocar de empresa é uma ação explícita, por um seletor no topo, e só lista empresas autorizadas.
- **RN-01-006** — Mudar o perfil ativo (painel de RH ou portal do colaborador) não muda a empresa atual. As duas áreas usam o mesmo endereço (D-155).

### Isolamento

- **RN-01-010** — Todo model com dados de empresa declara `acts_as_tenant :company` (D-150). Consultas sem empresa atual geram erro, em vez de devolver dados de todas as empresas (`require_tenant`) **[P-01-05]**.
- **RN-01-011** — Visões sem empresa atual (painel do parceiro, área admin) só podem consultar dados de empresas por um único ponto de código. Ele desativa o tenant e aplica o filtro das empresas autorizadas **[P-01-06]**:
  - administrador do parceiro: todas as empresas do parceiro;
  - consultor: as empresas atribuídas a ele (D-052);
  - suporte CatalystHR: as empresas que está atendendo (ver a spec 03).
- **RN-01-012** — Jobs do Sidekiq que tratam dados de empresa recebem a empresa como contexto e rodam com o tenant definido (middleware do acts_as_tenant para Sidekiq) **[P-01-07]**.
- **RN-01-013** — Acessar por ID um registro de outra empresa devolve 404, nunca 403, para não revelar que o registro existe **[P-01-08]**.
- **RN-01-014** — Arquivos no S3 ficam sob um prefixo por empresa (`companies/<company_id>/...`) e só são servidos por URL assinada de curta duração, gerada depois da checagem de permissão **[P-01-09]**.

### Subdomínios

- **RN-01-020** — O slug é definido ao criar um parceiro ou uma empresa direta (D-157), por quem pode criá-los (seção 6). Regras **[P-01-10]**:
  - de 3 a 40 caracteres, com letras minúsculas sem acento, números e hífen;
  - não pode começar nem terminar com hífen;
  - é único entre os slugs ativos e os slugs em período de redirecionamento.
- **RN-01-021** — Lista de slugs reservados, que não podem ser usados: `admin`, `www`, `api`, `app`, `painel`, `portal`, `suporte`, `status`, `mail`, `email`, `static`, `assets`, `cdn`, `totem`, `health` (D-573). O superadmin pode ampliar a lista **[P-01-11]**.
- **RN-01-022** — Na troca de slug, o antigo fica 90 dias redirecionando (D-157). Depois disso é liberado.
- **RN-01-023** — O certificado é um wildcard para `*.painel.catalysthr.com.br`, então criar um subdomínio não exige nenhum passo de infraestrutura (D-153).

### Marca (white label)

- **RN-01-030** — O que a marca personaliza (D-159):

  | Grupo | Campos |
  |---|---|
  | Identidade | Nome comercial, logo (versão clara e escura), favicon |
  | PWA | Nome curto do app, ícone (512×512 e 192×192) |
  | Cores | Primária, secundária, destaque |
  | Tela de login | Imagem de fundo ou ilustração, texto de boas-vindas |
  | Suporte | E-mail e telefone de suporte |
  | Textos legais | Termos de uso, política de privacidade |

- **RN-01-031** — As cores viram variáveis CSS (`--brand-primary` etc.), que o Tailwind usa como cores do tema. A cor primária precisa ter contraste mínimo de 4.5:1 com o texto branco (WCAG AA). O sistema recusa a cor e mostra o motivo **[P-01-12]**.
- **RN-01-032** — Campos de marca não preenchidos usam o padrão CatalystHR (cores, textos legais). A exceção é o logo: sem logo, aparece o nome comercial em texto **[P-01-02]**.
- **RN-01-033** — O manifest do PWA (`/manifest.webmanifest`) é gerado por marca, com nome, ícones e cores dela.
- **RN-01-034** — A empresa cliente de parceiro pode ter marca própria (D-163), editada pela equipe do parceiro (D-166). O parceiro escolhe por empresa como ela aparece (D-165):

  | Modo | Depois do login, com a empresa escolhida |
  |---|---|
  | `alongside` | Cores, textos e suporte do parceiro, com o logo da empresa no cabeçalho do painel e do portal |
  | `replace` | Logo e cores da empresa no lugar dos do parceiro |

  A tela de login aparece antes de se saber a empresa, então sempre usa a marca do parceiro. O subdomínio, o domínio de e-mail e o número de WhatsApp continuam sendo os do parceiro. No modo `replace`, os e-mails dessa empresa usam o nome comercial dela como nome do remetente, por exemplo "Metalúrgica Serra Azul <rh@auroragestao.com.br>" **[P-01-18]**.
- **RN-01-035** — No modo `replace`, campos não preenchidos na marca da empresa usam os do parceiro e, na falta deles, os do CatalystHR **[P-01-19]**.
- **RN-01-036** — O manifest do PWA usa a marca do parceiro, porque a instalação acontece no subdomínio antes de se saber a empresa **[P-01-20]**.

### Canais de comunicação

- **RN-01-040** — **E-mail:**
  - o dono da marca pode cadastrar um domínio de e-mail, e o sistema cria a identidade no SES e mostra os registros DKIM e SPF que precisam ir para o DNS (D-040);
  - um job verifica o status periodicamente;
  - enquanto o domínio não estiver verificado, ou se não houver domínio, vale o envio pelo domínio da plataforma (D-160): `"<Nome comercial> <nao-responda@catalysthr.com.br>"`, com o suporte da marca no reply-to.
- **RN-01-041** — **WhatsApp:**
  - por padrão, os avisos saem do número da plataforma, com o nome da marca no texto;
  - o número próprio da marca é um item adicional do plano (D-041, D-161);
  - o detalhe fica na [spec 15](15-notificacoes.md).

### Transferência de empresa (D-123)

- **RN-01-050** — Só o superadmin transfere, e a transferência exige registrar a autorização da empresa (anexo ou aceite do RH administrador).
- **RN-01-051** — Depois da transferência:
  - os dados da empresa não mudam, só o `partner_id`;
  - a empresa passa a ser acessada pelo subdomínio do novo dono;
  - as memberships de parceiro do antigo parceiro deixam de alcançar a empresa;
  - as memberships da própria empresa (RH, gestores, colaboradores) continuam.
- **RN-01-052** — Os usuários da empresa recebem um aviso com o endereço novo. O endereço antigo não redireciona, porque o subdomínio continua sendo de outra marca **[P-01-13]**.
- **RN-01-053** — Na transferência, tudo o que a empresa usava do parceiro antigo é copiado para ela: modelos de processo, materiais do assistente e perguntas e respostas. A partir daí, as cópias pertencem à empresa e não dependem mais do parceiro antigo. A marca do parceiro antigo **não** é copiada. A empresa passa a usar a marca do novo dono, e a marca própria dela, se tinha uma, continua (D-168) **[P-01-14]**.

## 5. Estados

**Domínio de e-mail da marca:** `não configurado` → `pendente de verificação` → `verificado` → (`falhou`, que volta a `pendente` quando o DNS é corrigido)

**Slug:** `ativo` → `redirecionando` (90 dias) → `liberado`

## 6. Permissões

O administrador do parceiro cuida da marca e do domínio, como na apresentação (página 4). O restante foi aprovado em **[P-01-17]**.

| Ação | Superadmin | Financeiro | Suporte | Admin parceiro | Consultor | RH admin |
|---|---|---|---|---|---|---|
| Criar parceiro ou empresa direta, definir slug | ✓ | ✓ | — | — | — | — |
| Trocar slug | ✓ | — | — | — | — | — |
| Editar marca do parceiro | ✓ | — | ✓ | ✓ | — | — |
| Editar marca da empresa cliente e escolher o modo (D-165, D-166) | ✓ | — | ✓ | ✓ | — | — |
| Editar marca da empresa direta (D-162) | ✓ | — | ✓ | — | — | — |
| Configurar domínio de e-mail | ✓ | — | ✓ | ✓ | — | — |
| Transferir empresa | ✓ | — | — | — | — | — |

Toda edição feita pelo suporte CatalystHR fica registrada na auditoria (spec 05).

A matriz completa fica na [spec 03](03-permissoes.md).

## 7. Modelo de dados

Proposta de entidades e campos principais. Os tipos e índices finais ficam para a implementação.

```
partners
  id, name, legal_name, cnpj, status, created_at...

companies
  id, partner_id (nullable, FK partners), name, legal_name, cnpj, status...
  brand_display_mode ('alongside'|'replace', só para empresa com parceiro)

brands                                   [P-01-01]
  id, owner_type ('Partner'|'Company'), owner_id
  commercial_name, short_name (PWA)
  primary_color, secondary_color, accent_color
  login_welcome_text
  support_email, support_phone
  terms_url_or_text, privacy_policy_text
  email_domain, email_domain_status, ses_identity_arn, email_domain_checked_at
  whatsapp_sender_id (nullable; número próprio)
  Active Storage: logo_light, logo_dark, favicon, pwa_icon, login_image

brand_subdomains                         [P-01-15]
  id, brand_id, slug (único), status ('active'|'redirecting'|'released')
  redirect_until (nullable)

company_transfers
  id, company_id, from_partner_id (nullable), to_partner_id (nullable)
  authorized_by_text, authorization_document (Active Storage)
  performed_by_user_id, performed_at
```

- Todo model operacional tem `company_id NOT NULL` com índice e declara `acts_as_tenant :company`.
- Os dados do parceiro (equipe, modelos, materiais) têm `partner_id` e não usam acts_as_tenant (D-151).
- A identificação da marca pelo host passa por um cache, para evitar uma consulta ao banco por requisição **[P-01-16]**.

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Brands::VerifyEmailDomainJob` | A cada hora, para domínios pendentes (sidekiq-cron) | Consulta o SES e atualiza o status. Avisa o admin do parceiro quando o domínio é verificado ou quando falha |
| `Brands::ReleaseExpiredSubdomainsJob` | Diário | Libera os slugs cujo período de redirecionamento acabou |
| `Companies::TransferNotificationJob` | Depois de uma transferência | Avisa os usuários da empresa sobre o endereço novo |

Integrações: SES (identidades de domínio), Twilio (remetentes), DNS e certificado wildcard (spec 20).

## 9. Critérios de aceite

- **CA-01-001** — Dado um parceiro com o slug `aurora`, quando alguém acessa `aurora.painel.catalysthr.com.br`, então a tela de login mostra o logo, as cores e o texto de boas-vindas da Aurora.
- **CA-01-002** — Dado um usuário com membership só na empresa direta `serraazul`, quando ele tenta logar em `aurora.painel...`, então vê "credenciais inválidas", sem indicação de que a conta existe.
- **CA-01-003** — Dado um consultor atribuído às empresas A e B do parceiro, quando ele abre o seletor de empresas, então vê só A e B.
- **CA-01-004** — Dado um usuário com a empresa A como atual, quando ele acessa a URL de um colaborador da empresa B, então recebe 404.
- **CA-01-005** — Dado um job enfileirado para a empresa A, quando ele roda, então só lê e grava dados da empresa A, e consultas sem tenant geram erro.
- **CA-01-006** — Dado que o slug `aurora` foi trocado para `auroragp` há 10 dias, quando alguém acessa `aurora.painel.../colaboradores`, então é redirecionado com 301 para `auroragp.painel.../colaboradores`.
- **CA-01-007** — Dado que já se passaram 91 dias da troca, quando alguém acessa o slug antigo, então recebe a 404 neutra.
- **CA-01-008** — Dado um domínio de e-mail ainda pendente, quando um convite é enviado, então ele sai de `nao-responda@catalysthr.com.br` com o nome comercial da marca e o reply-to de suporte.
- **CA-01-009** — Dado um domínio verificado no SES, quando um convite é enviado, então ele sai do domínio da marca.
- **CA-01-010** — Dada uma cor primária com contraste menor que 4.5:1 com branco, quando o admin do parceiro tenta salvar, então o sistema recusa e explica o motivo.
- **CA-01-011** — Dado um colaborador no subdomínio da marca, quando ele instala o PWA, então o app aparece com o nome curto e o ícone da marca.
- **CA-01-012** — Dada uma empresa transferida do parceiro X para o Y, quando um consultor de X tenta acessá-la, então não a encontra. Os colaboradores da empresa acessam pelo subdomínio de Y com o mesmo login.
- **CA-01-013** — Dado o slug `admin`, quando o admin tenta usá-lo para um parceiro, então o sistema recusa por ser um nome reservado.

## 10. Propostas aprovadas (D-167)

| # | Como ficou | |
|---|---|---|
| P-01-01 | Entidade `Brand` polimórfica (dono: `Partner` ou `Company`) | aprovada |
| P-01-02 | Empresa direta ainda sem marca configurada mostra o nome comercial em texto, com as cores padrão do CatalystHR | **ajustada** |
| P-01-03 | Login em marca errada devolve a mesma mensagem de credencial inválida | aprovada |
| P-01-04 | Cookie de sessão restrito ao host | aprovada |
| P-01-05 | `require_tenant` ligado no acts_as_tenant | aprovada |
| P-01-06 | Ponto único de código para consultas entre empresas | aprovada |
| P-01-07 | Middleware do acts_as_tenant para Sidekiq | aprovada |
| P-01-08 | Registro de outra empresa devolve 404 | aprovada |
| P-01-09 | S3 com prefixo por empresa e URL assinada de curta duração | aprovada |
| P-01-10 | Slug com 3–40 caracteres, minúsculas, números e hífen | aprovada |
| P-01-11 | Lista de slugs reservados, que o superadmin pode ampliar | **ajustada** |
| P-01-12 | Recusa de cor primária com contraste abaixo de 4.5:1 | aprovada |
| P-01-13 | Na transferência, o endereço antigo não redireciona e os usuários são avisados | aprovada |
| P-01-14 | Na transferência, tudo o que a empresa usava do parceiro antigo é copiado para ela | **ajustada** |
| P-01-15 | Entidade `BrandSubdomain` | aprovada |
| P-01-16 | Cache da identificação da marca com Rails.cache, invalidado ao salvar a marca ou trocar o slug | aprovada |
| P-01-17 | Permissões da seção 6: superadmin e financeiro criam; só o superadmin troca slug e transfere; o suporte edita marcas e domínio de e-mail | **ajustada** |
| P-01-18 | Empresa com marca própria usa o subdomínio, o domínio de e-mail e o WhatsApp do parceiro. No modo `replace`, o nome do remetente é o da empresa | **ajustada** |
| P-01-19 | No modo `replace`, campos vazios usam os do parceiro e depois os do CatalystHR | aprovada |
| P-01-20 | O manifest do PWA usa a marca do dono do subdomínio | aprovada |

## 11. Em aberto
- **Wildcard no Railway:** o Railway aceita o domínio wildcard com certificado automático (Let's Encrypt), com DNS na Cloudflare sem proxy (D-503, spec 20).
- **Totem:** endereço e marca do totem compartilhado. Será tratado na spec 10.
