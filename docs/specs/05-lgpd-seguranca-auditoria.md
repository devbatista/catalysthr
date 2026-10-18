# 05 — LGPD, segurança e auditoria

> Status: aprovado (prazos da seção 4.4 pendentes de validação jurídica) · Última atualização: 2026-10-18
> Decisões: D-075, D-080 a D-089, D-124, D-183, D-185 a D-187, D-217 a D-227, D-606 ([decisoes.md](decisoes.md))
> Os itens **[P-05-nn]** foram todos aprovados sem ajuste (D-227, seção 10).
> **Atenção:** os prazos de retenção da seção 4.4 são uma proposta técnica e **precisam ser validados pelo jurídico** antes de entrar em produção (D-217).

## 1. Objetivo

Garantir que a plataforma:

- trate os dados de acordo com a LGPD;
- proteja os dados sensíveis;
- registre quem fez e quem viu o quê;
- guarde cada dado só pelo tempo necessário;
- responda bem aos titulares, às controladoras e aos incidentes.

## 2. Papéis (D-080, D-124)

| Modalidade | Controladora | Operador | Suboperador |
|---|---|---|---|
| Via parceiro | Empresa cliente | Parceiro | CatalystHR |
| Direta | Empresa | CatalystHR | — |

**Encarregado (D-224):** cada empresa cadastra nome, e-mail e telefone do encarregado de dados. Essas informações aparecem no portal do colaborador e na política de privacidade.

**Suboperadores da plataforma**, para informar nas políticas e contratos **[P-05-01]**:

| Serviço | Dados que recebe |
|---|---|
| AWS (S3, SES, KMS) | Arquivos, e-mails enviados, chaves |
| Railway | Banco de dados e aplicação |
| Anthropic (Claude) | Documentos e textos enviados à IA |
| Voyage AI | Trechos dos materiais do assistente |
| Twilio | Celular e texto dos avisos |
| Mercado Pago | Dados de cobrança de parceiros e empresas, sem dados de colaboradores |
| Asaas | Dados fiscais de parceiros e empresas diretas (CNPJ, razão social, endereço, e-mail de cobrança) para emitir a NFS-e, sem dados de colaboradores (D-560) |
| Sentry | Erros, desempenho e logs técnicos, sem dados pessoais (spec 20, RN-20-071) |
| Cloudflare | Só DNS, sem tráfego de dados |
| AWS Rekognition | Selfies e fotos de referência, **só quando o reconhecimento facial existir** (fora do MVP, D-311) |

## 3. Dados sensíveis

### 3.1 Classificação (D-086, D-221)

| Categoria | Exemplos |
|---|---|
| Documentos pessoais | RG, CTPS, PIS/NIS, título, CNH, RNE e os arquivos desses documentos |
| Remuneração e banco | Salário, rubricas, holerites, conta, PIX |
| Saúde | ASO, atestados, CID, afastamentos por doença |
| Deficiência | Tipo e observações |
| Biometria | Templates faciais e selfies do ponto |
| Raça/cor | Campo do cadastro |
| Filiação sindical | Sindicato, contribuição autorizada |
| Dependentes | CPF, nascimento e documentos dos dependentes |

O CPF da pessoa é dado pessoal comum, mas fica criptografado (D-086) e é mascarado no impersonate (D-187).

### 3.2 Tratamento

| Tratamento | Regra |
|---|---|
| **Criptografia no banco** | Active Record Encryption em todos os campos das categorias acima. Criptografia determinística só onde há busca (CPF, RG) **[P-05-02]** |
| **Chaves** | As chaves do Active Record Encryption ficam em variáveis de ambiente do Railway, nunca no repositório. O certificado A1 usa o AWS KMS (D-075) **[P-05-03]** |
| **Arquivos** | S3 privado, com bloqueio de acesso público, criptografia SSE-KMS e URL assinada de curta duração (P-01-09) **[P-05-04]** |
| **Confirmação de senha** | Ver ou baixar dado sensível exige senha confirmada nos últimos 5 minutos (D-183) |
| **Evento de acesso** | Cada leitura ou download de dado sensível gera um evento de acesso (D-085) |
| **Impersonate** | Mascarado. Arquivos de saúde, biometria e documentos pessoais não abrem (D-187, P-02-33) |
| **Listagens** | Telas de lista nunca mostram dado sensível. Ele só aparece no detalhe, depois da confirmação de senha **[P-05-05]** |

- **RN-05-001** — A leitura de dado sensível é marcada no código por um ponto único (por exemplo, `reveal_sensitive(record, :salary)`). Esse ponto checa a permissão, pede a confirmação de senha, registra o evento de acesso e aplica a máscara do impersonate. Campo sensível exibido fora dele quebra um teste **[P-05-06]**. O ponto único nasce com a máscara do impersonate; a confirmação de senha e o evento de leitura entram com a spec 04 (D-592).

## 4. Auditoria e retenção

### 4.1 Trilha de alterações (PaperTrail, D-084)

- **RN-05-010** — Todos os models com dados de empresa, parceiro ou escritório usam PaperTrail. Cada versão grava:
  - quem fez a alteração (`whodunnit`);
  - quem estava em impersonate, se for o caso;
  - IP e request id **[P-05-07]**.
- **RN-05-011** — **Campos sensíveis não entram em texto aberto nas versões.** Como o PaperTrail grava os valores já descriptografados, esses campos são excluídos de `object` e `object_changes`. A versão registra só que o campo mudou ("salário alterado"), e o valor anterior fica nas revisões com vigência (spec 04), que são criptografadas **[P-05-08]**.

### 4.2 Eventos de acesso (D-085)

- **RN-05-020** — A tabela de eventos de acesso registra:

  | Tipo | Exemplos |
  |---|---|
  | `sensitive_read` | Ver salário, abrir atestado, ver dados bancários |
  | `download` | Baixar documento, holerite, exportação, AFD, XML do eSocial |
  | `export` | Relatórios, exportação da pasta, exportação de encerramento |
  | `auth` | Login, falha de login, logout, bloqueio, desbloqueio, troca de senha, MFA ativado ou redefinido, dispositivo lembrado ou revogado |
  | `impersonation` | Início, cada requisição, fim (P-02-34) |
  | `admin` | Mudança de perfil, liberação de módulos, retenção por processo, incidentes |

- **RN-05-021** — O evento de acesso é gravado **na própria requisição**, e não em job, para não se perder se a fila falhar. Eventos de leitura de alto volume (cada requisição de impersonate) podem ir em lote **[P-05-09]**.
- **RN-05-022** — Eventos de acesso são só de inclusão. Nenhum perfil edita ou apaga eventos; só o job de retenção os remove depois de 5 anos (D-219) **[P-05-10]**.

### 4.3 Retenção dos registros de auditoria

- **RN-05-030** — Versões do PaperTrail e eventos de acesso ficam 5 anos (D-219). Depois disso, um job os exclui.
- **RN-05-031** — Se uma pessoa é anonimizada antes dos 5 anos, os registros de auditoria sobre ela continuam, mas os dados pessoais dentro deles (nome, valores) são anonimizados junto **[P-05-11]**.

### 4.4 Prazos de retenção por categoria (D-081, D-217)

> **Proposta técnica, a validar com o jurídico.** A contagem começa no desligamento do último vínculo da pessoa na empresa, ou no fim do processo seletivo, no caso de candidatos **[P-05-12]**.

| Categoria | Prazo proposto | Referência a confirmar |
|---|---|---|
| Ficha de registro e dados do vínculo | Indeterminado (comprovação de tempo de serviço) | CLT art. 41; previdência |
| Folha, holerites, recibos | 10 anos | Prazos previdenciários e fiscais |
| FGTS (guias, depósitos) | 5 anos | Prescrição quinquenal (STF, ARE 709.212) |
| Ponto (marcações, AFD, AEJ, espelhos, comprovantes) | 5 anos | Prescrição trabalhista; Portaria 671 |
| Selfies das marcações | 5 anos, junto das marcações | Prova da marcação |
| Template facial (biometria) | Excluído no desligamento ou quando o consentimento é revogado | Finalidade encerrada (LGPD art. 15 e 16) |
| ASO e documentos de saúde ocupacional | 20 anos | NR-7 |
| Atestados médicos | 5 anos | Prescrição trabalhista |
| Documentos pessoais (arquivos) | 5 anos | Prescrição trabalhista |
| Dados bancários | 5 anos | Prova de pagamento |
| Dependentes | 5 anos | Prescrição trabalhista |
| Contato de emergência | Excluído no desligamento | Finalidade encerrada |
| Solicitações e comentários | 5 anos | Prescrição trabalhista |
| Avaliações de desempenho | 5 anos | Prescrição trabalhista |
| Candidatos não contratados | 6 meses após o fim do processo; 12 meses, renováveis, no banco de talentos com consentimento (D-526) | Finalidade encerrada; consentimento no banco de talentos |
| Eventos do eSocial e recibos | 10 anos | Prazos fiscais |
| Conversas com o assistente | 1 ano | Finalidade operacional |
| Auditoria e eventos de acesso | 5 anos | D-219 |

- **RN-05-040** — A tabela fica no sistema e é editada pela equipe CatalystHR (D-217), com histórico de mudanças. Uma mudança de prazo vale para todos os dados ainda não anonimizados **[P-05-13]**.

### 4.5 Anonimização (D-218)

- **RN-05-050** — Um job diário (`Retention::SweepJob`) encontra os dados com prazo vencido e **[P-05-14]**:
  - **anonimiza registros:** nome vira "Pessoa anonimizada #<id>"; CPF, documentos, endereço, contatos, dados bancários e dependentes são apagados; datas de nascimento passam a guardar só o ano. Totais, quantidades e valores de folha agregados continuam, para estatísticas e relatórios históricos;
  - **exclui arquivos** do S3 (documentos, selfies, holerites em PDF);
  - **anonimiza também as versões do PaperTrail** desses registros (RN-05-031).
- **RN-05-051** — Trinta dias antes de anonimizar, o RH administrador recebe a lista de pessoas que serão anonimizadas, para aplicar retenção por processo se precisar **[P-05-15]**.
- **RN-05-052** — O usuário (`User`) só é anonimizado se não tiver nenhuma outra membership ativa ou em período de leitura. Senão, só a ficha daquela empresa é anonimizada **[P-05-16]**.
- **RN-05-053** — Dados anonimizados ou excluídos continuam nos backups até eles expirarem, num ciclo de 35 dias (D-223). Isso fica escrito na política de privacidade.

### 4.6 Retenção por processo (D-220)

- **RN-05-060** — O RH administrador ou o RH analista (no escopo dele) marca uma pessoa com **retenção por processo**, informando o número do processo e a justificativa. Enquanto a marca existir, nada da pessoa naquela empresa é anonimizado ou excluído **[P-05-17]**.
- **RN-05-061** — A marca não tem prazo. Ela só sai quando alguém a retira, informando o motivo. Tudo fica nos eventos de acesso, com tipo `admin`.
- **RN-05-062** — Uma vez por ano, o RH administrador recebe a lista das retenções por processo ativas, para revisar **[P-05-18]**.

## 5. Direitos do titular (D-087)

- **RN-05-070** — O colaborador abre uma solicitação do tipo "Privacidade/LGPD" e escolhe o pedido **[P-05-19]**:

  | Pedido | Atendimento |
  |---|---|
  | Confirmação e acesso | Gera um relatório com todos os dados da pessoa na empresa (PDF e JSON) |
  | Correção | Vira uma "Atualização cadastral" (spec 04) |
  | Portabilidade | O mesmo relatório do acesso, em formato estruturado (JSON e CSV) |
  | Eliminação | O RH avalia: elimina o que não está sob obrigação legal e responde o que precisa ficar, e por quê |
  | Informação sobre compartilhamento | Mostra a lista de operadores e suboperadores (seção 2) |
  | Revogação de consentimento | Feita direto no portal (spec 02), sem precisar de solicitação |

- **RN-05-071** — A resposta é dada pelo RH administrador (P-03-21), com prazo de **15 dias** contado da abertura (LGPD art. 19, II) **[P-05-20]**.
- **RN-05-072** — O relatório de acesso é gerado em job e fica disponível por 7 dias, com download que exige confirmação de senha e gera evento de acesso **[P-05-21]**.

## 6. Encerramento de contrato (D-222)

- **RN-05-080** — Quando o contrato da empresa termina (cancelamento pelo parceiro, pela empresa direta ou pela equipe CatalystHR), a empresa:
  1. passa a `closing`, em somente leitura;
  2. recebe uma **exportação completa**, gerada por job: dados em JSON e CSV por entidade, mais todos os arquivos em ZIP, com índice (formato e senha na spec 18, RN-18-071 e RN-18-075);
  3. fica **90 dias** em somente leitura;
  4. depois de 90 dias, é **excluída por completo**: banco e S3.
- **RN-05-081** — A exportação fica disponível só para o RH administrador, durante os 90 dias. O download gera evento de acesso **[P-05-22]**.
- **RN-05-082** — Antes da exclusão, o RH administrador recebe avisos com 30, 7 e 1 dia de antecedência **[P-05-23]**.
- **RN-05-083** — Os dados sob retenção legal passam a ser responsabilidade da empresa (controladora), que os recebe na exportação. A plataforma não guarda nada depois da exclusão, além dos backups em expiração (D-223) **[P-05-24]**.
- **RN-05-084** — A empresa sai da contagem de limites do plano no dia em que entra em `closing` **[P-05-25]**.

## 7. Incidentes de segurança (D-225, D-226)

- **RN-05-090** — A equipe CatalystHR registra o incidente na área admin com:
  - descrição;
  - data da ocorrência e da descoberta;
  - categorias de dados afetadas;
  - empresas e pessoas afetadas;
  - gravidade;
  - medidas tomadas.
- **RN-05-091** — O sistema ajuda a listar os afetados, cruzando os eventos de acesso e os dados envolvidos, e gera para cada empresa um relatório com quem foi afetado e o que foi exposto **[P-05-26]**.
- **RN-05-092** — Avisos (D-226):
  - empresa de parceiro: o parceiro e o RH administrador;
  - empresa direta: o RH administrador.

  O aviso vai por e-mail e por aviso dentro do sistema, com o relatório anexo. A data e a hora de cada aviso ficam registradas.
- **RN-05-093** — A comunicação à ANPD e aos titulares é feita pela controladora. A plataforma entrega o relatório para isso, mas não comunica em nome dela **[P-05-27]**.

## 8. Segurança técnica

| Tema | Regra |
|---|---|
| Transporte | Somente HTTPS, com HSTS (`config.force_ssl`) **[P-05-28]** |
| Cabeçalhos | CSP restritiva sem script inline, compatível com JS via importmap; `X-Frame-Options: DENY`; `Referrer-Policy` **[P-05-29]**. Entra no fim da fase 1 (D-606) |
| Uploads | Validação do tipo real do arquivo (não só da extensão), tamanho máximo, varredura de vírus (ClamAV ou similar) antes de liberar o arquivo **[P-05-30]**. A varredura entra com a pasta de documentos (spec 08, D-606) |
| Dependências e código | `brakeman` e `bundler-audit` no CI. A build falha com vulnerabilidade alta **[P-05-31]** |
| Segredos | Variáveis de ambiente do Railway. Nenhum segredo no repositório. As chaves são trocadas quando alguém da equipe sai **[P-05-32]** |
| Logs da aplicação | `filter_parameters` cobre CPF, senha, token, salário, conta, PIX e campos de saúde. Logs nunca têm dado sensível **[P-05-33]** |
| Banco em repouso | Confirmar a criptografia em disco do Postgres no Railway (spec 20) |

## 9. Modelo de dados

```
versions (PaperTrail)
  item_type, item_id, event, whodunnit, object, object_changes,
  impersonator_id, ip, request_id, company_id, created_at

access_events                                          -- D-085, sem update/delete
  id, company_id (nullable), user_id, impersonator_id (nullable),
  kind, action, subject_type, subject_id, field, ip, user_agent,
  request_id, metadata (jsonb), created_at

retention_policies                                     -- D-217, global
  id, category, period_months (nullable = indeterminado), trigger
  ('termination'|'process_end'|'consent_revoked'), action ('anonymize'|'delete'),
  legal_reference, updated_by_id

legal_holds                                            -- D-220
  id, company_id, worker_profile_id, case_number, justification,
  placed_by_id, placed_at, released_by_id, released_at, release_reason

data_protection_officers                               -- D-224 (ou colunas em companies)
  company_id, name, email, phone

privacy_requests                                       -- spec 09, tipo "Privacidade/LGPD"
  request_id, kind, report_file, report_expires_at

security_incidents                                     -- D-225
  id, title, description, occurred_at, discovered_at, severity,
  data_categories (array), measures, status

security_incident_companies
  incident_id, company_id, affected_count, report_file, notified_at

company_closures                                       -- D-222
  company_id, requested_at, export_file, export_ready_at, deletion_scheduled_on,
  deleted_at
```

## 10. Propostas aprovadas (D-227)

| # | Proposta |
|---|---|
| P-05-01 | Lista de suboperadores para políticas e contratos |
| P-05-02 | Active Record Encryption, determinística só onde há busca |
| P-05-03 | Chaves de criptografia em variáveis de ambiente do Railway |
| P-05-04 | S3 privado, com bloqueio público, SSE-KMS e URL assinada |
| P-05-05 | Listagens nunca mostram dado sensível |
| P-05-06 | Ponto único `reveal_sensitive`, com teste que impede exibir sensível fora dele |
| P-05-07 | Versões do PaperTrail com impersonador, IP e request id |
| P-05-08 | Campos sensíveis fora das versões do PaperTrail |
| P-05-09 | Evento de acesso gravado na requisição; alto volume em lote |
| P-05-10 | Eventos de acesso só de inclusão |
| P-05-11 | Registros de auditoria anonimizados junto com a pessoa |
| P-05-12 | Contagem do prazo a partir do último desligamento ou do fim do processo seletivo |
| P-05-13 | Mudança de prazo vale para os dados ainda não anonimizados |
| P-05-14 | Regras de anonimização (o que é apagado e o que fica) |
| P-05-15 | Aviso ao RH 30 dias antes de anonimizar |
| P-05-16 | O usuário só é anonimizado sem outras memberships |
| P-05-17 | O RH administrador e o RH analista (escopo dele) aplicam retenção por processo |
| P-05-18 | Revisão anual das retenções por processo |
| P-05-19 | Tipos de pedido LGPD e como cada um é atendido |
| P-05-20 | Prazo de 15 dias para responder |
| P-05-21 | Relatório do titular disponível por 7 dias |
| P-05-22 | A exportação de encerramento é só para o RH administrador |
| P-05-23 | Avisos 30, 7 e 1 dia antes da exclusão |
| P-05-24 | Depois da exclusão, a retenção legal é da empresa |
| P-05-25 | A empresa em encerramento sai da contagem do plano |
| P-05-26 | Relatório de afetados por empresa no incidente |
| P-05-27 | A controladora comunica a ANPD e os titulares |
| P-05-28 | HTTPS obrigatório com HSTS |
| P-05-29 | CSP sem script inline e cabeçalhos de segurança |
| P-05-30 | Validação de tipo e varredura de vírus nos uploads |
| P-05-31 | brakeman e bundler-audit no CI |
| P-05-32 | Segredos em variáveis de ambiente e rotação quando alguém sai |
| P-05-33 | Filtro de parâmetros sensíveis nos logs |

## 11. Em aberto

- **Validação jurídica** da tabela de prazos (seção 4.4) e da base legal de cada categoria.
- **Retenção nos provedores de IA:** decidida a retenção zero na Anthropic e na Voyage (D-380). Falta contratar os acordos (spec 14).
- **Criptografia em repouso no Railway:** confirmar no Trust Center. Os backups de 35 dias foram resolvidos com o pg_dump no S3 (D-502, spec 20).
- **Antivírus nos uploads (P-05-30):** resolvido: ClamAV como serviço no Railway (D-507, spec 20).
