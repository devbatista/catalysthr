# 02 — Identidade e acesso

> Status: aprovado · Última atualização: 2026-10-14
> Decisões: D-029, D-050 a D-054, D-082, D-083, D-088, D-089, D-090, D-127, D-142, D-143, D-158, D-170 a D-189, D-425, D-426, D-570, D-576 a D-582 ([decisoes.md](decisoes.md))
> Os itens **[P-02-01]** a **[P-02-37]** foram aprovados, alguns com ajuste (D-188, seção 10). Os itens **[P-02-38]** a **[P-02-41]** (gestor do cliente, D-570) foram aprovados sem ajuste (D-572).

## 1. Objetivo

Definir quem é cada pessoa na plataforma e a que ela tem acesso:

- como a pessoa entra, prova quem é e recupera o acesso;
- como o acesso dela nasce (convite), muda (perfis, vínculos) e termina (desligamento, remoção);
- como a equipe CatalystHR presta suporte sem alterar dados nem expor dados sensíveis.

O que cada perfil **pode fazer** em cada módulo fica na [spec 03](03-permissoes.md).

## 2. Conceitos

| Conceito | Descrição |
|---|---|
| **Usuário** (`User`) | Uma pessoa. CPF obrigatório e único (D-173), e-mail único e opcional, celular opcional. Login por CPF ou e-mail mais senha (D-054). |
| **Organização** | Onde a pessoa tem acesso: uma empresa (`Company`), um parceiro (`Partner`) ou um escritório contábil (`AccountingFirm`, D-170). |
| **Membership** | A ligação usuário + organização, com um ou mais perfis (D-050, D-051, D-052). |
| **Perfil** | O papel dentro da organização (tabela abaixo). |
| **Equipe CatalystHR** | Superadmin, suporte e financeiro (D-142). Não pertence a nenhuma organização cliente **[P-02-01]**. |
| **Vínculo** (`Employment`) | O contrato de trabalho, ligado à membership da empresa. Tem um tipo: CLT, estágio, PJ, autônomo ou sócio com pró-labore (D-053, D-176). Detalhado na [spec 04](04-cadastros.md). |
| **Escritório contábil** (`AccountingFirm`) | Contabilidade externa, com equipe e administrador próprios, ligada às empresas que atende (D-170 a D-172). |

### Perfis por organização [P-02-02]

| Organização | Perfil | Código |
|---|---|---|
| Plataforma | Superadmin, suporte, financeiro | `superadmin`, `support`, `finance` |
| Parceiro | Administrador, consultor | `partner_admin`, `consultant` |
| Empresa | RH administrador, RH analista, gestor, colaborador, gestor do cliente (D-570) | `hr_admin`, `hr_analyst`, `manager`, `employee`, `client_manager` |
| Escritório contábil | Administrador, contador | `firm_admin`, `accountant` |

Uma membership de empresa pode acumular perfis, por exemplo `manager` + `employee` ou `hr_analyst` + `employee` (D-051). O perfil `employee` exige um vínculo (`Employment`) ativo ou em período de leitura (D-090) **[P-02-03]**.

O perfil `client_manager` (D-570) só existe em empresa que usa clientes de alocação (spec 04, RN-04-090). Ele é dado a uma pessoa do cliente, que não tem vínculo com a empresa. Por isso, **não acumula** com outros perfis da empresa **[P-02-38]**.

## 3. Histórias de usuário

1. Como **RH**, quero convidar um novo colaborador por e-mail, WhatsApp ou link impresso, para que ele acesse o portal mesmo sem e-mail.
2. Como **colaborador**, quero entrar com meu CPF e senha, porque não uso e-mail.
3. Como **colaborador**, quero recuperar minha senha por um código no WhatsApp.
4. Como **RH**, quero ser obrigado a usar MFA, porque acesso dados de muitas pessoas.
5. Como **gestor que também é colaborador**, quero alternar entre o painel e o meu portal sem trocar de login.
6. Como **prestador PJ**, quero usar o portal para enviar minhas notas fiscais e documentos.
7. Como **RH administrador**, quero cadastrar o escritório contábil que atende a empresa, para que os contadores acessem os encaminhamentos.
8. Como **administrador do escritório contábil**, quero convidar e remover os contadores da minha equipe.
9. Como **suporte CatalystHR**, quero ver o sistema como o usuário vê, para reproduzir um problema sem alterar dados.
10. Como **ex-colaborador**, quero continuar consultando meus holerites por um período depois do desligamento.
11. Como **gestor de um cliente da consultoria**, quero entrar com meu CPF e aprovar o que me cabe nas admissões dos colaboradores alocados comigo, sem ser colaborador da consultoria (D-570).

## 4. Regras de negócio

### Usuário e identificação

- **RN-02-001** — O CPF é obrigatório para todos os usuários, inclusive equipe CatalystHR, parceiro e contabilidade (D-173), e é único na plataforma. Ele fica criptografado de forma determinística, para permitir a busca (D-086).
- **RN-02-002** — O e-mail é opcional e, quando existe, é único na plataforma. Todo usuário precisa ter **e-mail ou celular**, para conseguir recuperar o acesso **[P-02-04]**.
- **RN-02-003** — O campo de login aceita CPF (com ou sem máscara) ou e-mail. Se o texto tem só dígitos e pontuação de CPF, a busca é por CPF; senão, por e-mail **[P-02-05]**.
- **RN-02-004** — O login só é aceito se o usuário tiver membership ativa ou em período de leitura na marca do subdomínio (RN-01-002). A equipe CatalystHR entra só por `admin.catalysthr.com.br` **[P-02-06]**. O suporte chega a uma empresa direta a partir do admin, com um token de uso único (D-581).
- **RN-02-005** — Um prestador PJ é um usuário comum, identificado pelo CPF. O CNPJ fica no vínculo do tipo PJ (D-174).

### Convite e primeiro acesso

- **RN-02-010** — Quem pode convidar cada perfil está definido na [spec 03](03-permissoes.md). O convite cria (ou reaproveita, se o CPF já existe) o usuário e a membership com status `invited`.
- **RN-02-011** — Canais do convite (D-177):
  - **e-mail**, pelo domínio da marca (RN-01-040);
  - **WhatsApp**, com link (exige o consentimento descrito na RN-02-016);
  - **link ou QR code** gerado pelo RH para entregar em mãos.

  O RH pode usar mais de um canal no mesmo convite. Todos levam ao mesmo token.
- **RN-02-012** — O token do convite vale **72 horas** (D-178). Reenviar o convite gera um token novo e invalida o anterior **[P-02-07]**.
- **RN-02-013** — Se o CPF convidado já tem usuário na plataforma, o convite só cria a membership nova. Se a pessoa já tem senha, ela não cria outra: entra com a senha atual e passa pelas etapas de primeiro acesso que faltarem naquela organização **[P-02-08]**.
- **RN-02-014** — Primeiro acesso (D-182), nesta ordem, cada etapa obrigatória antes da próxima:
  1. criar a senha (RN-02-030);
  2. aceitar os termos de uso e a política de privacidade da marca;
  3. ativar o MFA, para perfis em que ele é obrigatório (RN-02-040);
  4. consentimento de biometria: só para quem marca ponto em unidade ou cargo com selfie ligada. Se a empresa ligar a selfie depois, o consentimento é pedido no próximo acesso. Pode ser recusado (D-088, D-321). Revisado por D-323, porque o reconhecimento facial saiu do MVP (D-311) **[P-02-09]**;
  5. consentimento de WhatsApp: só para quem tem celular cadastrado. Pode ser recusado.
- **RN-02-015** — Todo aceite e consentimento guarda: tipo, versão do texto, decisão (aceite ou recusa), data e hora, IP e user agent. Consentimentos podem ser revogados depois pelo portal **[P-02-10]**.
- **RN-02-016** — O WhatsApp só envia o convite se a empresa registrar que obteve a autorização do colaborador (por exemplo, na ficha de admissão). Antes do primeiro acesso, não existe consentimento dado pela própria pessoa, e a Meta exige opt-in para mensagens iniciadas pela empresa **[P-02-11]**.
- **RN-02-017** — Termos de uso e política de privacidade têm versão. Quando a marca publica uma versão nova, cada usuário aceita de novo no próximo acesso **[P-02-12]**. As versões ficam em `legal_documents`, com o texto de cada uma mantido (D-577). Sem texto próprio, a marca usa os da CatalystHR (D-578), que o superadmin publica na área administrativa (D-579).

### Senha e bloqueio

- **RN-02-030** — A senha tem no mínimo 8 caracteres, com pelo menos uma letra maiúscula, um número e um símbolo (D-180). Ela também não pode conter o CPF nem a data de nascimento do usuário **[P-02-13]**.
- **RN-02-031** — Após **5 tentativas erradas**, a conta é bloqueada até o desbloqueio (D-181). O usuário escolhe como desbloquear: link no e-mail ou código no WhatsApp. O contador é por usuário, em todas as marcas **[P-02-14]**, e soma as senhas e os códigos de MFA errados (D-580).
- **RN-02-032** — Além do bloqueio por conta, há limite de tentativas por IP (Rack::Attack), para frear ataques que testam muitos CPFs **[P-02-15]**.
- **RN-02-033** — Recuperação de senha (D-179):
  - por **link no e-mail**, válido por 2 horas **[P-02-16]**;
  - por **código de 6 dígitos no WhatsApp**, válido por 10 minutos, com até 5 tentativas **[P-02-16]**.

  O RH não gera link de redefinição. Se o usuário perdeu o e-mail e o celular, o RH (ou quem administra o perfil dele) corrige o contato no cadastro, com registro na auditoria, e o próprio usuário recupera a senha **[P-02-17]**. Se a pessoa tem acesso a outra organização ou é da equipe CatalystHR, só o suporte corrige, e o e-mail antigo recebe um aviso da mudança (D-582).
- **RN-02-034** — A tela de recuperação responde sempre "se houver cadastro, enviamos as instruções", para não revelar se o CPF ou e-mail existe.

### MFA

- **RN-02-040** — O MFA é obrigatório para quem tem algum dos perfis: equipe CatalystHR, `partner_admin`, `consultant`, `hr_admin` e `hr_analyst` (D-082). Para os demais (`manager`, `employee`, `firm_admin`, `accountant`), o MFA é opcional **[P-02-18]**. O `client_manager` também tem MFA obrigatório, porque é uma pessoa de fora da empresa que vê dados dos colaboradores **[P-02-39]**.
- **RN-02-041** — A obrigatoriedade vale para o usuário, não para a área: quem tem um perfil obrigatório em qualquer organização usa MFA em todo login **[P-02-19]**.
- **RN-02-042** — Métodos: app autenticador (TOTP) e 10 códigos de recuperação de uso único (D-083). Os códigos aparecem uma vez e podem ser gerados de novo, o que invalida os anteriores **[P-02-20]**.
- **RN-02-043** — Depois de passar pelo MFA, o usuário pode marcar "lembrar este dispositivo" por **30 dias** (D-184). Ele vê a lista de dispositivos lembrados e pode revogar cada um. Trocar a senha revoga todos **[P-02-21]**.
- **RN-02-044** — Se o usuário perde o app e os códigos de recuperação, o MFA é redefinido por quem administra o perfil: RH administrador para o RH e para os gestores do cliente (P-02-40), administrador do parceiro para a equipe dele, administrador do escritório para os contadores, e suporte CatalystHR para os demais. A redefinição fica na auditoria e avisa o usuário **[P-02-22]**. Se a pessoa tem acesso a outra organização ou é da equipe CatalystHR, só o suporte redefine (D-582).
- **RN-02-045** — **Passkey** (D-425, D-426): o usuário pode cadastrar passkeys (WebAuthn) e entrar com a digital ou o rosto do aparelho. Entrar com passkey **cumpre o MFA**, inclusive nos perfis obrigatórios. A passkey também substitui a senha na confirmação de dados sensíveis (RN-02-052). Detalhes na [spec 16](16-portal-colaborador-pwa.md), seção 4.8.

### Sessão

- **RN-02-050** — Tempo de inatividade (D-089): **30 minutos** para equipe CatalystHR, parceiro, RH, gestor, gestor do cliente e contabilidade; **14 dias** para o colaborador. A contabilidade não foi citada em D-089 e entra aqui como proposta **[P-02-23]**.
- **RN-02-051** — Quem tem perfis com tempos diferentes na mesma marca (por exemplo, gestor e colaborador) fica com o **mais restrito**, 30 minutos **[P-02-24]**.
- **RN-02-052** — Ver ou baixar dado sensível exige confirmar a senha (ou a passkey, RN-02-045). A confirmação vale **5 minutos** (D-183). Dado sensível segue a lista de D-086 (documentos pessoais, salário e dados bancários, saúde, biometria).
- **RN-02-053** — O usuário vê as sessões abertas e pode encerrar as outras. Trocar a senha encerra todas, menos a atual **[P-02-25]**. As sessões ficam na tabela `user_sessions`, conferida a cada requisição (D-576).

### Ciclo de vida da membership

- **RN-02-060** — Status da membership: `invited` → `active` → (`suspended` ↔ `active`) → `read_only` (desligado, D-090) → `revoked`.
- **RN-02-061** — No desligamento, as memberships com perfil `employee` passam a `read_only` pelo período que a empresa configurar (D-090). Nesse estado, o portal só mostra holerites, informe de rendimentos, espelhos de ponto, documentos e TRCT, sem novas ações. Se a pessoa também tinha outros perfis na empresa (gestor, RH), eles são removidos no desligamento **[P-02-26]**.
- **RN-02-062** — Ao fim do período de leitura, a membership vai para `revoked`. O usuário continua existindo se tiver outras memberships. Se não tiver nenhuma, a conta é desativada, e os dados seguem as regras de retenção da [spec 05](05-lgpd-seguranca-auditoria.md) **[P-02-27]**.
- **RN-02-063** — Remover um perfil ou suspender uma membership encerra na hora as sessões que dependiam dela **[P-02-28]**.
- **RN-02-064** — **Gestor do cliente** (D-570): o RH administrador convida a pessoa pelos canais da RN-02-011 e atribui os clientes dela. Se ela fica sem nenhum cliente ativo (atribuição removida ou cliente inativado), ou se a empresa desliga os clientes de alocação, o perfil `client_manager` é removido e as sessões são encerradas (RN-02-063) **[P-02-40, P-02-41]**.

### Escritório contábil

- **RN-02-070** — O RH administrador cadastra o escritório pelo CNPJ e o e-mail de um administrador (D-171), com o nome do escritório e o nome, o CPF e o e-mail ou o celular do administrador (D-588). A empresa tem no máximo um escritório com ligação pendente ou ativa (D-589). Se o CNPJ já existe na plataforma, a ligação com a empresa fica pendente até o administrador do escritório aceitar **[P-02-29]**. Os administradores ativos do escritório são avisados por e-mail e aceitam ou recusam; a recusa ou o cancelamento pelo RHA encerra a ligação (D-590).
- **RN-02-071** — O primeiro administrador do escritório entra por convite. A partir daí, ele convida e remove contadores e outros administradores (D-172). Ninguém altera a própria membership, e o último administrador ativo do escritório não pode ser removido nem rebaixado (D-584).
- **RN-02-072** — O contador acessa as empresas ligadas ao escritório pelo subdomínio da marca de cada empresa, com o mesmo login (D-158). Dentro de uma marca, as empresas e os pedidos de aceite do escritório mostram só os daquela marca. Os convites e os e-mails saem com a marca da empresa que pediu a ligação, ou com a marca em que o administrador do escritório está, ao convidar a equipe (D-586).
- **RN-02-073** — O RH administrador pode desligar o escritório da empresa a qualquer momento. O acesso dos contadores àquela empresa termina na hora.

### Impersonate (suporte)

- **RN-02-080** — Suporte e superadmin podem ver o sistema como um usuário de qualquer organização cliente (D-185). Não é possível fazer impersonate de outro membro da equipe CatalystHR **[P-02-30]**.
- **RN-02-081** — Para iniciar, é obrigatório informar o motivo ou o número do chamado. A sessão dura no máximo **30 minutos** e termina sozinha (D-185).
- **RN-02-082** — O impersonate começa em `admin.catalysthr.com.br` e abre o subdomínio da marca do usuário com um token de uso único, de curta duração **[P-02-31]**.
- **RN-02-083** — Uma faixa fixa em todas as telas mostra: "Você está vendo como <nome>", o tempo restante e o botão "Encerrar".
- **RN-02-084** — Leituras (GET) funcionam normalmente. Escritas (POST, PUT, PATCH, DELETE) rodam em **simulação** (D-186):
  - a ação executa dentro de uma transação, que é desfeita ao final;
  - nada sai do sistema: e-mails, WhatsApp, jobs, uploads ao S3 e chamadas externas (eSocial, IA, Mercado Pago, Twilio) são suprimidos;
  - o resultado aparece com a faixa "Simulação: nada foi salvo".
- **RN-02-085** — Para a supressão das chamadas externas funcionar, toda integração passa por um cliente central que respeita o modo simulação. Chamada externa feita fora desse cliente é proibida por regra de código e por teste **[P-02-32]**.
- **RN-02-086** — Dados sensíveis aparecem mascarados (D-187): CPF parcial (`***.456.789-**`), salário e valores como `R$ ••••`, dados bancários parciais. Arquivos de saúde e biometria não abrem. Arquivos de documentos pessoais (RG, CNH etc.) também não abrem **[P-02-33]**.
- **RN-02-087** — No impersonate, a confirmação de senha (RN-02-052) não é oferecida, porque os sensíveis já estão mascarados. Segredos (senha, MFA, códigos de recuperação) nunca aparecem.
- **RN-02-088** — Início, fim e cada requisição do impersonate entram nos eventos de acesso (D-085), com o usuário do suporte, o usuário visualizado e o motivo **[P-02-34]**.

## 5. Estados

**Membership:** `invited` → `active` ⇄ `suspended` → `read_only` → `revoked`
(`invited` → `revoked` quando o convite é cancelado)

**Usuário:** `active` ⇄ `locked` (bloqueio por tentativas) · `deactivated` (sem nenhuma membership)

**Escritório ↔ empresa:** `pending` (aguardando aceite do escritório) → `active` → `ended` (`pending` → `ended` na recusa ou no cancelamento, D-590)

## 6. Permissões

| Ação | Quem |
|---|---|
| Convidar usuários de empresa | Ver a [spec 03](03-permissoes.md) |
| Cadastrar ou ligar o escritório contábil à empresa | RH administrador (D-171) |
| Convidar e remover contadores | Administrador do escritório (D-172) |
| Convidar e remover gestores do cliente, atribuir clientes | RH administrador (D-570) **[P-02-40]** |
| Redefinir o MFA de outro usuário | Quem administra o perfil (RN-02-044) **[P-02-22]** |
| Corrigir e-mail ou celular de outro usuário | Quem administra o perfil (RN-02-033) **[P-02-17]** |
| Fazer impersonate | Superadmin e suporte (D-185) |

## 7. Modelo de dados

```
users
  id, name, cpf (criptografado determinístico, único), email (único, nullable)
  mobile_phone (nullable), birth_date
  status ('active'|'deactivated')
  platform_role (nullable: 'superadmin'|'support'|'finance')    [P-02-01]
  -- Devise: encrypted_password, reset_password_*, failed_attempts,
  --         unlock_token, locked_at, sign_in_count, current/last_sign_in_*
  -- devise-two-factor: otp_secret (criptografado), consumed_timestep,
  --         otp_required_for_login, otp_backup_codes (hash)       [P-02-35]

memberships                                                       [P-02-36]
  id, user_id, organization_type ('Company'|'Partner'|'AccountingFirm')
  organization_id, roles (array de strings), status
  invited_by_id, invitation_token_digest, invitation_sent_at,
  invitation_expires_at, invitation_channels (array)
  read_only_until (nullable)

partner_membership_companies    -- empresas atribuídas ao consultor (D-052)
  membership_id, company_id

accounting_firms
  id, name, cnpj (único), status

accounting_firm_companies
  id, accounting_firm_id, company_id, status ('pending'|'active'|'ended')
  linked_by_user_id, accepted_at, ended_at

consents                                                          [P-02-10]
  id, user_id, kind ('terms'|'privacy'|'biometrics'|'whatsapp')
  scope_type, scope_id     -- Brand para termos e privacidade; Company para biometria e WhatsApp
  legal_document_id (nullable; a versão aceita dos termos ou da política, D-577)
  document_version, granted (bool), ip, user_agent, decided_at, revoked_at

legal_documents                                                   [D-577, D-578]
  id, brand_id (nullable = textos da CatalystHR), kind ('terms'|'privacy')
  version, body, published_at, published_by_id

user_sessions                                                     [D-576]
  id, user_id, token_digest, area ('admin'|'panel'), brand_id (nullable)
  user_agent, ip, last_seen_at, expires_at, revoked_at, revoked_reason

trusted_devices                                                   [P-02-21]
  id, user_id, token_digest, user_agent, last_used_at, expires_at, revoked_at

impersonation_sessions                                            [P-02-34]
  id, impersonator_id, impersonated_user_id, reason, started_at, ended_at,
  ended_reason ('manual'|'timeout')
```

O vínculo empregatício (`employments`) fica na [spec 04](04-cadastros.md).

## 8. Jobs e integrações

| Item | Detalhe |
|---|---|
| Gems | `devise`, `devise-two-factor` (MFA), `pretender` (impersonate), `rack-attack` (limite por IP). O convite é próprio, sobre a membership, sem `devise_invitable` **[P-02-35, P-02-37]** |
| `Memberships::ExpireReadOnlyJob` | Diário: passa para `revoked` as memberships cujo `read_only_until` passou |
| `Invitations::DeliverJob` | Envia o convite por e-mail (SES) ou WhatsApp (Twilio) |
| `Auth::SendWhatsappCodeJob` | Envia códigos de recuperação e desbloqueio pela Twilio |
| `TrustedDevices::PurgeExpiredJob` | Diário: limpa dispositivos expirados |

## 9. Critérios de aceite

- **CA-02-001** — Dado um colaborador sem e-mail, com CPF e celular, quando o RH o convida por WhatsApp e link impresso, então os dois levam ao mesmo cadastro de senha, e o link expira em 72 horas.
- **CA-02-002** — Dado um convite reenviado, quando a pessoa usa o link antigo, então vê "convite expirado".
- **CA-02-003** — Dado um usuário que digita `123.456.789-09` ou `12345678909`, quando a senha está certa, então ele entra nos dois casos.
- **CA-02-004** — Dada a senha `catalyst1`, quando o usuário tenta salvá-la, então o sistema recusa por faltar maiúscula e símbolo.
- **CA-02-005** — Dadas 5 tentativas erradas, quando o usuário tenta de novo com a senha certa, então a conta continua bloqueada até ele usar o link no e-mail ou o código no WhatsApp.
- **CA-02-006** — Dado um RH analista no primeiro acesso, quando ele termina de criar a senha e aceitar os termos, então não consegue seguir sem configurar o app autenticador.
- **CA-02-007** — Dado um usuário que marcou "lembrar este dispositivo", quando ele entra de novo no mesmo navegador em até 30 dias, então o código TOTP não é pedido. Depois que ele troca a senha, o código volta a ser pedido.
- **CA-02-008** — Dado um gestor que também é colaborador, quando fica 31 minutos sem usar o sistema, então precisa entrar de novo, inclusive no portal.
- **CA-02-009** — Dado um colaborador logado no PWA há 10 dias, quando ele abre o holerite, então o sistema pede a senha. Se ele abrir outro holerite 3 minutos depois, a senha não é pedida de novo.
- **CA-02-010** — Dado um colaborador desligado com 90 dias de leitura configurados, quando ele entra no dia 30, então vê holerites e documentos, mas não tem botões de ação. No dia 91, o login é recusado.
- **CA-02-011** — Dado um escritório já cadastrado (mesmo CNPJ), quando outro RH administrador o liga à empresa dele, então a ligação fica pendente até o administrador do escritório aceitar.
- **CA-02-012** — Dado um suporte em impersonate de um RH, quando ele salva a edição de um colaborador, então vê o resultado com "Simulação: nada foi salvo", o registro no banco não muda e nenhum e-mail ou job sai.
- **CA-02-013** — Dado um suporte em impersonate, quando ele abre a ficha de um colaborador, então o salário aparece como `R$ ••••`, e o atestado de saúde não abre.
- **CA-02-014** — Dado um impersonate iniciado há 30 minutos, quando o suporte faz a próxima requisição, então a sessão é encerrada e ele volta ao admin.
- **CA-02-015** — Dado um suporte, quando ele tenta iniciar o impersonate sem motivo, então o sistema não permite.
- **CA-02-016** — Dada a recuperação de senha com um CPF inexistente, quando a pessoa envia o formulário, então vê a mesma mensagem de quando o CPF existe.
- **CA-02-017** — Dado um gestor do cliente no primeiro acesso, quando ele termina de criar a senha e aceitar os termos, então não consegue seguir sem configurar o MFA.
- **CA-02-018** — Dado um gestor do cliente com um único cliente, quando o RH inativa esse cliente, então o perfil dele é removido, e a próxima requisição da sessão aberta é recusada.

## 10. Propostas aprovadas (D-188)

Todas aprovadas. Três tiveram ajuste:

- **P-02-09:** se a empresa ativar o reconhecimento facial depois, o consentimento é pedido no próximo acesso.
- **P-02-22:** o administrador do escritório redefine o MFA dos contadores.
- **P-02-37:** convite próprio, sem devise_invitable.

| # | Proposta |
|---|---|
| P-02-01 | A equipe CatalystHR é marcada por `platform_role` no usuário, sem membership |
| P-02-02 | Códigos dos perfis em inglês (tabela da seção 2) |
| P-02-03 | O perfil `employee` exige um vínculo ativo ou em período de leitura |
| P-02-04 | Todo usuário precisa ter e-mail ou celular |
| P-02-05 | Um único campo de login, que detecta se o texto é CPF ou e-mail |
| P-02-06 | A equipe CatalystHR entra só por admin.catalysthr.com.br |
| P-02-07 | Reenviar o convite invalida o token anterior |
| P-02-08 | Quem já tem usuário só ganha a membership nova e faz as etapas de primeiro acesso que faltarem |
| P-02-09 | O consentimento de biometria só é pedido se a empresa usa ponto com reconhecimento facial |
| P-02-10 | Tabela `consents` com versão, decisão, IP e revogação |
| P-02-11 | O convite por WhatsApp exige que a empresa registre a autorização prévia do colaborador |
| P-02-12 | Nova versão dos termos exige novo aceite |
| P-02-13 | A senha não pode conter o CPF nem a data de nascimento |
| P-02-14 | O contador de tentativas é por usuário, em todas as marcas |
| P-02-15 | Limite de tentativas por IP com Rack::Attack |
| P-02-16 | Link de recuperação válido por 2 horas; código de WhatsApp com 6 dígitos, válido por 10 minutos, até 5 tentativas |
| P-02-17 | Quem perdeu e-mail e celular pede ao RH para corrigir o contato e depois recupera sozinho |
| P-02-18 | Lista de perfis com MFA obrigatório (inclui `consultant` e `hr_analyst`) e opcional (inclui a contabilidade) |
| P-02-19 | O MFA obrigatório vale para o usuário em todo login |
| P-02-20 | 10 códigos de recuperação, que podem ser gerados de novo |
| P-02-21 | Lista de dispositivos lembrados, com revogação. Trocar a senha revoga todos |
| P-02-22 | Quem redefine o MFA de outro usuário |
| P-02-23 | A contabilidade tem 30 minutos de inatividade |
| P-02-24 | Com perfis de tempos diferentes, vale o mais restrito |
| P-02-25 | Lista de sessões abertas, com encerramento. Trocar a senha encerra as outras |
| P-02-26 | No desligamento, os perfis de gestor e RH da pessoa na empresa são removidos |
| P-02-27 | Sem nenhuma membership, a conta é desativada |
| P-02-28 | Remover perfil ou suspender membership encerra as sessões na hora |
| P-02-29 | Ligar um escritório já existente exige o aceite do administrador dele |
| P-02-30 | Não existe impersonate de membros da equipe CatalystHR |
| P-02-31 | O impersonate abre o subdomínio da marca com um token de uso único |
| P-02-32 | Toda integração externa passa por um cliente central que respeita o modo simulação |
| P-02-33 | No impersonate, arquivos de documentos pessoais também não abrem |
| P-02-34 | Tabela `impersonation_sessions` e registro de cada requisição nos eventos de acesso |
| P-02-35 | MFA com a gem devise-two-factor |
| P-02-36 | Uma tabela `memberships` polimórfica (empresa, parceiro, escritório), com os perfis em array |
| P-02-37 | Gems: pretender e rack-attack; convite próprio, sem devise_invitable |

### Propostas aprovadas (D-572), clientes de alocação

| # | Proposta |
|---|---|
| P-02-38 | Perfil `client_manager`, sem vínculo com a empresa e sem acumular outros perfis dela |
| P-02-39 | MFA obrigatório para o gestor do cliente |
| P-02-40 | O RH administrador convida e remove gestores do cliente, atribui os clientes e redefine o MFA deles |
| P-02-41 | Sem cliente ativo, ou com os clientes de alocação desligados, o perfil é removido e as sessões são encerradas |

## 11. Em aberto

- **Notas fiscais do PJ (D-175):** o fluxo de envio, conferência e aprovação fica na [spec 12](12-folha-de-pagamento.md) (D-189).
- **Lista completa de "dados sensíveis"** para a confirmação de senha e o mascaramento. Será fechada na [spec 05](05-lgpd-seguranca-auditoria.md).
