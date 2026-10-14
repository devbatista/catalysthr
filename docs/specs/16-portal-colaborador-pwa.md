# 16 — Portal do colaborador (PWA)

> Status: aprovado · Última atualização: 2026-10-13
> Decisões: D-064, D-086, D-089, D-090, D-175, D-183, D-205, D-210, D-301, D-420 a D-430 ([decisoes.md](decisoes.md))
> Os itens **[P-16-nn]** foram todos aprovados sem ajuste (D-430, seção 10).

## 1. Objetivo

Dar ao colaborador **um lugar só, no celular, para tudo o que ele faz com o RH**. É o que mostra o protótipo `CatalystRH_colaborador`:

- pendências, documentos e ciência;
- ponto e espelho;
- solicitações;
- holerites e informe;
- integração e avaliação;
- assistente, mural e meus dados.

O portal é um **PWA**: abre no navegador e pode ser instalado na tela inicial, com a marca do parceiro ou da empresa direta. As regras de cada assunto ficam nas specs de origem. Esta spec define a casca: navegação, tela inicial, área do gestor, vínculos, instalação, service worker, passkeys e compatibilidade.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Portal | `Portal::` (namespace de controllers) | A área do colaborador e do gestor, dentro do subdomínio da marca |
| Minha equipe | `Portal::Team::` | A área do gestor no portal (D-420) |
| Manifest | `/manifest.webmanifest` | Nome, ícones e cores da marca para instalar o app (RN-01-033) |
| Service worker | `/service-worker.js` | Guarda a casca do app e recebe o push (D-424, spec 15) |
| Passkey | `WebauthnCredential` | Credencial do aparelho para entrar e confirmar dados sensíveis (D-425) |

## 3. Histórias de usuário

1. Como **colaborador**, quero abrir o app e ver logo o botão de marcar o ponto e o que o RH está me pedindo.
2. Como **colaborador**, quero entrar com a digital, sem lembrar a senha.
3. Como **gestora**, quero aprovar as férias da equipe pelo celular, entre uma reunião e outra.
4. Como **colaborador com dois vínculos** na mesma empresa (manhã como auxiliar, noite como porteiro), quero ver tudo junto e escolher o vínculo ao marcar o ponto.
5. Como **prestador PJ**, quero enviar a minha nota fiscal pelo portal e não ver abas de ponto e holerite.
6. Como **desligado**, quero baixar o meu informe de rendimentos no ano seguinte.
7. Como **colaborador num celular simples**, quero que o portal abra rápido no 4G.

## 4. Regras de negócio

### 4.1 Acesso

- **RN-16-001** — O portal fica no subdomínio da marca, no caminho `/portal` (por exemplo, `aurora.painel.catalysthr.com.br/portal`). O painel fica no mesmo subdomínio **[P-16-01]**.
- **RN-16-002** — Depois do login, quem só tem os perfis colaborador ou gestor vai para o portal. Quem tem perfil de RH ou consultor vai para o painel. Se essa pessoa também for colaboradora, o menu do painel mostra "Meu portal", e o portal mostra "Abrir painel" **[P-16-02]**.
- **RN-16-003** — Usam o portal: colaboradores CLT, estagiários, autônomos, sócios com pró-labore e PJ (D-175), além dos desligados em período de leitura (seção 4.6).
- **RN-16-004** — A sessão segue a spec 02: 14 dias para quem é só colaborador, e 30 minutos para quem também é gestor (perfil mais restrito, RN-02-051). Com a passkey, entrar de novo leva um toque (seção 4.8).

### 4.2 Navegação (D-421)

- **RN-16-010** — Barra inferior no celular. No computador, a mesma estrutura vira menu lateral:

  | Aba | Conteúdo | Aparece para |
  |---|---|---|
  | **Início** | Seção 4.3 | Todos |
  | **Docs** | Pasta (spec 08), envios pendentes, ciências | Todos |
  | **Ponto** | Marcar, comprovantes, espelho, banco de horas, ajuste de marcação (specs 10 e 11) | Quem tem vínculo com controle de ponto e a empresa com o módulo ponto |
  | **Pedidos** | Minhas solicitações e nova solicitação (spec 09) | Todos, menos desligados (seção 4.6) |
  | **Mais** | Lista abaixo | Todos |

- **RN-16-011** — Itens de **Mais** **[P-16-03]**:
  - Minha equipe (só gestores, seção 4.4);
  - Holerites e informe de rendimentos (quem tem folha), ou **Notas fiscais** (PJ, spec 12);
  - Avaliações (spec 22);
  - Assistente (se ligado, spec 14);
  - Mural de comunicados (spec 15);
  - Vagas internas (spec 21, D-533);
  - Meus dados, com o pedido de alteração (D-210);
  - Notificações e preferências (spec 15);
  - Segurança: senha, passkeys, MFA, sessões e dispositivos, consentimentos (spec 02);
  - Privacidade: encarregado de dados e pedidos do titular (spec 05);
  - Ajuda: base de conhecimento do sistema (D-110);
  - Instalar app (seção 4.7) e Sair.
- **RN-16-012** — As abas mostram o número de pendências (por exemplo, Docs com 1 correção pedida), como no protótipo.
- **RN-16-013** — Cada tela tem URL própria, para que o link de um aviso (spec 15) abra direto nela. O botão voltar do celular funciona normalmente, porque a navegação é por páginas comuns (ERB), sem SPA **[P-16-04]**.

### 4.3 Início (D-429)

- **RN-16-020** — Blocos, nesta ordem. Bloco vazio não aparece:

  | # | Bloco | Conteúdo |
  |---|---|---|
  | 1 | **Ponto** | Próxima marcação prevista e o botão **Registrar ponto**. Só para quem marca |
  | 2 | **Minha equipe** | "N aprovações esperando", ausências de hoje e atalho para a área. Só gestores |
  | 3 | **Pendências** | Documentos para enviar ou corrigir, ciências, itens de processo, autoavaliação, espelho para ciência, com o prazo |
  | 4 | **Comunicados** | Fixados e não lidos (spec 15) |
  | 5 | **Integração** | Progresso e itens, durante a admissão (spec 07) |
  | 6 | **Minhas solicitações** | As que estão em andamento, com o status |
  | 7 | **Último holerite** | Competência e o botão abrir. O valor só aparece depois da confirmação (RN-16-021) |

- **RN-16-021** — Nenhum valor de salário ou líquido, nem outro dado sensível, aparece no Início sem a confirmação de senha ou passkey (RN-02-052). Isso vale para quem está olhando por cima do ombro ou para um celular emprestado **[P-16-05]**.
- **RN-16-022** — Convites que aparecem no Início, quando se aplicam: instalar o app (seção 4.7), ativar o push (spec 15), cadastrar uma passkey (seção 4.8). No máximo um convite por vez **[P-16-06]**.

### 4.4 Minha equipe (D-420)

- **RN-16-030** — Para quem tem o perfil gestor, a área mostra **só a equipe** dele (D-190):

  | Item | O que faz no portal |
  |---|---|
  | Aprovações | Ver e aprovar ou reprovar, com justificativa, as solicitações da equipe (spec 09). O atestado mostra só as datas (D-301) |
  | Ausências | Quem está de férias, afastado ou de folga hoje e na semana |
  | Escala | Ver a escala da semana. Montar e publicar a escala fica no painel (RN-11-013) **[P-16-07]** |
  | Itens de processo | Itens atribuídos ao gestor (boas-vindas, avaliação, entrega de EPI), para concluir (spec 06) |
  | Documentos vencendo | Só o texto, sem o arquivo (P-08-11) |
  | Experiência | Fins de experiência próximos, com o link para a decisão no painel (RN-07-101) |

- **RN-16-031** — O resto da gestão (espelhos da equipe, relatórios, painel) fica no **painel**, que funciona no celular. A área tem o link "Abrir no painel".

### 4.5 Vínculos e empresas (D-422)

- **RN-16-040** — **Empresas diferentes** (inclusive da mesma marca): o seletor no topo troca a empresa (RN-01-005). O portal mostra uma empresa por vez. Avisos de outra empresa aparecem no sino com o nome dela e trocam a empresa ao abrir **[P-16-08]**.
- **RN-16-041** — **Vínculos da mesma empresa** (D-205): uma visão única. Pendências, holerites, espelhos e solicitações mostram a etiqueta do vínculo, por exemplo "Matrícula 1042 · Auxiliar de produção".
- **RN-16-042** — No ponto, se mais de um vínculo marca ponto, a pessoa escolhe o vínculo antes de marcar. O sistema sugere o vínculo cuja jornada está mais próxima do horário atual **[P-16-09]**.
- **RN-16-043** — Na nova solicitação, se o tipo depende do vínculo (férias, ajuste de marcação), a pessoa escolhe o vínculo.

### 4.6 Desligado (D-090, D-423)

- **RN-16-050** — O período de leitura padrão é de **12 meses**, ajustável pela empresa (D-423).
- **RN-16-051** — No período, o portal mostra só (RN-02-061): holerites, informe de rendimentos, espelhos e comprovantes de ponto, documentos e TRCT. Não há marcação, solicitações, assistente, mural nem avaliações. A exceção é a solicitação **Privacidade/LGPD**, que continua disponível (direitos do titular, spec 05) **[P-16-10]**.
- **RN-16-052** — O Início mostra um aviso com a data em que o acesso termina e o botão **Baixar meus documentos**, que gera um ZIP com tudo o que a pessoa pode ver (como RN-08-082). Trinta dias antes do fim, ela recebe o aviso `memberships.read_only_ending` (obrigatório, canais S E W P), que entra no catálogo da spec 15 **[P-16-11]**.

### 4.7 PWA (D-424, D-427)

- **RN-16-060** — O manifest é gerado por marca (RN-01-033, RN-01-036), com `display: standalone`, `start_url: /portal` e `scope: /` **[P-16-12]**.
- **RN-16-061** — O **service worker** guarda só a casca (D-424) **[P-16-13]**:
  - ícones, CSS e JS com nome versionado (digest), servidos do cache;
  - a tela "Sem conexão";
  - páginas e dados sempre pela rede, **nunca** guardados no cache;
  - ao sair (logout), os caches são limpos.
- **RN-16-062** — Sem conexão, o portal mostra "Sem conexão. Conecte-se para continuar". O ponto não guarda marcações para depois (D-064).
- **RN-16-063** — Nada de dado pessoal no `localStorage` ou no IndexedDB. Só preferências de interface, como o convite de instalação dispensado **[P-16-14]**.
- **RN-16-064** — **Atualização:** quando há uma versão nova do service worker, ela é ativada na próxima abertura do app. Se a pessoa estiver com o app aberto, aparece a faixa "Nova versão disponível · Atualizar" **[P-16-15]**.
- **RN-16-065** — **Convite de instalação** (D-427): um cartão no Início depois do primeiro acesso:
  - no Android e no computador, usa o evento `beforeinstallprompt` do navegador e o botão **Instalar**;
  - no iPhone, mostra o passo a passo (Compartilhar → Adicionar à Tela de Início), dizendo que isso libera o push;
  - pode ser dispensado e volta depois de 30 dias;
  - não aparece se o app já está instalado (`display-mode: standalone`).
- **RN-16-066** — Permissões do aparelho pedidas **só quando são usadas**, cada uma com uma tela explicando o motivo antes do pedido do navegador **[P-16-16]**:
  - localização, na primeira marcação de ponto (spec 10);
  - câmera, no primeiro envio de documento ou selfie (specs 08 e 10);
  - notificações, pelo convite do push (spec 15).

### 4.8 Passkeys (D-425, D-426)

- **RN-16-070** — **Cadastro:** em Segurança, ou pelo convite do Início, depois de entrar com senha (e MFA, se exigido) e confirmar a senha. A pessoa dá um nome para cada passkey ("iPhone", "Notebook"). Até **10 passkeys** por usuário **[P-16-17]**.
- **RN-16-071** — **Login:** o botão **"Entrar com digital ou rosto"** na tela de login, e o preenchimento automático do navegador no campo de login (*conditional UI*), quando suportado. A verificação do usuário no aparelho é **obrigatória** (`userVerification: required`) **[P-16-18]**.
- **RN-16-072** — Entrar com passkey **cumpre o MFA** (D-426) e não pede o código do app.
- **RN-16-073** — **Confirmação de dados sensíveis:** a passkey substitui a senha (RN-02-052) e vale pelos mesmos 5 minutos (D-183).
- **RN-16-074** — **Domínio da passkey:** o *RP ID* é o **subdomínio da marca** (por exemplo, `aurora.painel.catalysthr.com.br`), e o nome mostrado pelo aparelho é o nome comercial da marca. Assim, a passkey não mostra "CatalystHR" (white label). A consequência: se a empresa mudar de marca (transferência, D-123), as passkeys antigas deixam de funcionar, e a pessoa entra com a senha e cadastra de novo **[P-16-19]**.
- **RN-16-075** — A equipe CatalystHR (`admin.catalysthr.com.br`) também pode usar passkey, com o RP ID `admin.catalysthr.com.br`.
- **RN-16-076** — **Gestão:** a lista mostra nome, data de cadastro e último uso. Cada passkey pode ser removida. A redefinição de MFA por quem administra o perfil (RN-02-044) também remove todas as passkeys. Trocar a senha **não** remove as passkeys **[P-16-20]**.
- **RN-16-077** — O servidor guarda só a **chave pública** e o contador. A biometria nunca sai do aparelho e não é dado biométrico tratado pela plataforma (spec 05).

### 4.9 Compatibilidade, desempenho e acessibilidade (D-428)

- **RN-16-080** — Navegadores dos últimos 2 anos (D-428). Navegador mais antigo vê o aviso "Seu navegador está desatualizado. Algumas funções podem não funcionar", e o básico funciona: páginas ERB comuns, com o JavaScript só para melhorar a experiência **[P-16-21]**.
- **RN-16-081** — **Desempenho** em um celular intermediário com 4G **[P-16-22]**:
  - primeira abertura em até 3 segundos;
  - aberturas seguintes em até 1,5 segundo (casca no cache);
  - CSS do Tailwind compilado só com as classes usadas, e imagens comprimidas.
- **RN-16-082** — **Acessibilidade:** WCAG 2.1 nível AA. Alvos de toque com pelo menos 44 × 44 px, respeito ao tamanho de fonte do aparelho, rótulos em todos os campos e navegação por teclado no computador **[P-16-23]**.
- **RN-16-083** — **Cores da marca:** se a cor principal da marca não tiver contraste suficiente com o texto (4,5:1), o sistema escolhe o texto em branco ou preto para manter a leitura. O cadastro da marca mostra o aviso (spec 01) **[P-16-24]**.
- **RN-16-084** — Sem tema escuro no MVP **[P-16-25]**.
- **RN-16-085** — Só português do Brasil.

## 5. Estados

**Passkey:** `active` → `removed`

**Convite de instalação (no aparelho):** `eligible` → `shown` → `dismissed` (volta em 30 dias) | `installed`

## 6. Permissões

| Ação | Quem |
|---|---|
| Portal (abas e Início) | Perfil colaborador, com vínculo ativo, afastado ou em período de leitura |
| Minha equipe | Perfil gestor, só a equipe (spec 03) |
| Cadastrar e remover as próprias passkeys | O próprio usuário |
| Remover as passkeys de outro usuário | Quem redefine o MFA dele (RN-02-044) |
| Período de leitura do desligado | RH administrador (spec 03) |

## 7. Modelo de dados

```
webauthn_credentials
  id, user_id, rp_id, external_id (credential id), public_key, sign_count,
  nickname, transports (text[]), aaguid, created_at, last_used_at, removed_at

users (acréscimo)
  webauthn_handle                              -- identificador aleatório do usuário para o WebAuthn

companies (já existe, spec 04)
  read_only_period_days (padrão 365, D-423)
```

O convite de instalação dispensado fica no `localStorage` do aparelho (RN-16-063), sem tabela.

## 8. Jobs e integrações

| Item | O que é |
|---|---|
| Gem `webauthn` (webauthn-ruby) | Geração e verificação das cerimônias de cadastro e login **[P-16-26]** |
| JavaScript puro | `navigator.credentials.create` e `get`, `beforeinstallprompt`, registro do service worker, sem framework (D-022) |
| `Memberships::ReadOnlyEndingJob` | Diário: aviso 30 dias antes do fim do período de leitura (RN-16-052) |
| `Portal::ExportMyDocumentsJob` | Sob demanda: ZIP dos documentos do desligado (RN-16-052) |

O fim do período de leitura continua no `Memberships::ExpireReadOnlyJob` (spec 02).

## 9. Critérios de aceite

- **CA-16-001** — Dado um prestador PJ, quando abre o portal, então não vê as abas Ponto nem Holerites, e vê Notas fiscais em Mais.
- **CA-16-002** — Dado um colaborador sem controle de ponto, quando abre o Início, então o bloco Ponto não aparece.
- **CA-16-003** — Dada uma gestora com 3 pedidos de férias da equipe, quando abre o Início, então vê "3 aprovações esperando" logo após o ponto e consegue aprovar pelo portal.
- **CA-16-004** — Dado um colaborador com dois vínculos que marcam ponto, quando toca em Registrar ponto às 19h, então escolhe o vínculo, com o vínculo noturno sugerido.
- **CA-16-005** — Dado um aviso de holerite aberto pelo link do WhatsApp, quando a sessão está ativa, então a tela do holerite abre direto, e o valor só aparece depois da confirmação por senha ou passkey.
- **CA-16-006** — Dado um iPhone com o portal no Safari, quando o colaborador vê o convite de instalação, então ele mostra o passo a passo de Compartilhar → Adicionar à Tela de Início.
- **CA-16-007** — Dado o app aberto sem internet, quando a pessoa toca em Registrar ponto, então vê "Sem conexão", e nada é guardado para depois.
- **CA-16-008** — Dado um logout, quando a pessoa abre o app de novo sem internet, então nenhum dado da sessão anterior aparece.
- **CA-16-009** — Dado um RH com MFA obrigatório e uma passkey cadastrada, quando entra com a passkey, então acessa o painel sem digitar senha nem código.
- **CA-16-010** — Dada uma passkey cadastrada em `aurora.painel.catalysthr.com.br`, quando o aparelho mostra a passkey, então aparece o nome comercial da marca, e não "CatalystHR".
- **CA-16-011** — Dado um desligado em período de leitura, quando abre o portal, então vê holerites, informe, espelhos, documentos e TRCT, a data do fim do acesso e o botão de baixar os documentos, mas não a aba Pedidos, exceto pela solicitação Privacidade/LGPD.
- **CA-16-012** — Dada uma marca com cor principal amarelo-claro, quando o portal mostra um botão com essa cor, então o texto do botão é preto.

## 10. Propostas aprovadas (D-430)

| # | Proposta |
|---|---|
| P-16-01 | Portal em `/portal`, no mesmo subdomínio do painel |
| P-16-02 | Destino depois do login por perfil, com os links "Meu portal" e "Abrir painel" |
| P-16-03 | Itens de "Mais" |
| P-16-04 | URL própria por tela, sem SPA |
| P-16-05 | Nenhum valor sensível no Início sem confirmação |
| P-16-06 | Um convite por vez no Início (instalar, push, passkey) |
| P-16-07 | Escala só em leitura no portal; montar e publicar no painel |
| P-16-08 | Aviso de outra empresa troca a empresa ao abrir |
| P-16-09 | Sugestão do vínculo pela jornada mais próxima |
| P-16-10 | Desligado só com leitura e a solicitação Privacidade/LGPD |
| P-16-11 | Aviso do fim do acesso e ZIP dos documentos para o desligado |
| P-16-12 | Configuração do manifest |
| P-16-13 | Service worker só com a casca e caches limpos no logout |
| P-16-14 | Nada de dado pessoal no armazenamento do navegador |
| P-16-15 | Atualização na próxima abertura, com faixa "Nova versão" |
| P-16-16 | Permissões pedidas só no uso, com explicação |
| P-16-17 | Até 10 passkeys, com nome |
| P-16-18 | Botão de passkey e preenchimento automático, com verificação obrigatória |
| P-16-19 | Passkey no subdomínio da marca, com o nome comercial |
| P-16-20 | Redefinir MFA remove as passkeys; trocar a senha não remove |
| P-16-21 | Aviso para navegador antigo, com o básico funcionando |
| P-16-22 | Metas de desempenho no 4G |
| P-16-23 | WCAG 2.1 AA |
| P-16-24 | Contraste automático das cores da marca |
| P-16-25 | Sem tema escuro no MVP |
| P-16-26 | Gem `webauthn` |
