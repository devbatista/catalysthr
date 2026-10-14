# 10 — Ponto eletrônico (REP-P)

> Status: aprovado (pontos legais pendentes de validação, seção 11) · Última atualização: 2026-10-12
> Decisões: D-010, D-060 a D-064, D-075, D-088, D-116, D-201, D-216, D-310 a D-324 ([decisoes.md](decisoes.md))
> Os itens **[P-10-nn]** foram todos aprovados sem ajuste (D-324, seção 10).
> **Atenção:** esta spec segue a Portaria MTP 671/2021 e os anexos dela, com base no que conheço. Os layouts oficiais (AFD, AEJ, comprovante), os campos obrigatórios e as vedações **precisam ser conferidos no texto vigente da Portaria** e validados pelo jurídico antes da implementação.

## 1. Objetivo

Oferecer um **ponto eletrônico com validade legal**, do tipo REP-P (registrador eletrônico de ponto via programa, D-010), com:

- marcação pelo celular, pelo navegador e por totem (D-060);
- antifraude por localização e selfie (D-061);
- comprovante de cada marcação;
- AFD e AEJ para a fiscalização;
- tratamento de marcações sem alterar o registro original.

Os cálculos de jornada, horas extras, banco de horas e o espelho de ponto ficam na [spec 11](11-jornada-banco-de-horas.md).

## 2. Conceitos

| Conceito | Descrição |
|---|---|
| **REP-P** | O programa que registra as marcações, rodando em nuvem e registrado no INPI pelo fabricante. A spec assume o CatalystHR como fabricante (D-310) |
| **Programa de tratamento** | A parte que trata as marcações (inclusões, desconsiderações) e gera o espelho e o AEJ. Na plataforma, é o mesmo sistema, mas logicamente separado do registro **[P-10-01]** |
| **Marcação** | Um registro de horário de um trabalhador. É imutável depois de gravada |
| **NSR** | Número sequencial de registro, único e crescente por empregador **[P-10-02]** |
| **Comprovante** | O documento de cada marcação, entregue ao trabalhador por meio eletrônico, assinado (D-314, D-319) |
| **AFD** | Arquivo fonte de dados: todas as marcações originais, no layout oficial, assinado |
| **AEJ** | Arquivo eletrônico de jornada: marcações tratadas e jornada, gerado pelo programa de tratamento |
| **Tratamento** | Inclusão ou desconsideração de marcação, com motivo, sem apagar o original (D-318) |

## 3. Histórias de usuário

1. Como **colaborador**, quero bater o ponto pelo celular em poucos segundos e ver o comprovante na hora.
2. Como **colaborador de fábrica**, quero bater o ponto no tablet da portaria digitando CPF e PIN.
3. Como **colaborador de escritório**, quero bater o ponto pelo computador.
4. Como **vendedor externo**, quero bater o ponto de onde estiver, com minha localização registrada.
5. Como **colaborador**, quero pedir a inclusão de uma marcação que esqueci, com o motivo.
6. Como **gestor**, quero ver quem bateu o ponto fora da unidade e as selfies, para conferir.
7. Como **RH**, quero autorizar o tablet da portaria como totem com um código.
8. Como **RH**, quero gerar o AFD e o AEJ de um período quando a fiscalização pedir.

## 4. Regras de negócio

### 4.1 Requisitos legais (a conferir na Portaria 671)

- **RN-10-001** — **Fabricante:** o CatalystHR registra o programa no INPI e emite o atestado técnico e termo de responsabilidade (D-310, a confirmar). O RH de cada empresa consegue baixar esses documentos na plataforma **[P-10-03]**.
- **RN-10-002** — **Marcação imutável:** a marcação original não pode ser alterada nem excluída por nenhum perfil, nem pela equipe CatalystHR. A tabela de marcações aceita só inclusão. Isso é garantido também no banco, com permissões e um trigger que recusa UPDATE e DELETE **[P-10-04]**.
- **RN-10-003** — **Vedações:** o sistema não pode:
  - restringir os horários em que se marca;
  - marcar automaticamente;
  - exigir autorização prévia para hora extra;
  - permitir alterar os dados registrados.

  Ver a RN-10-022 sobre o conflito com o bloqueio pela cerca.
- **RN-10-004** — **Horário oficial:** o horário da marcação é o do **servidor**, sincronizado por NTP, nunca o do aparelho. A marcação guarda o instante em UTC e o fuso da unidade (RN-04-013). O comprovante e o AFD mostram a hora local com o fuso indicado **[P-10-05]**.
- **RN-10-005** — **Assinatura:** comprovantes e AFD são assinados com o certificado A1 do empregador (D-319), guardado no KMS (D-075). **Consequência:** uma empresa que contrata o ponto sem a folha também precisa enviar o certificado A1 antes de ativar o ponto **[P-10-06]**.
- **RN-10-006** — **Inadimplência:** o ponto continua funcionando mesmo com o parceiro ou a empresa em somente leitura (D-116). Marcação, comprovante e AFD nunca são bloqueados por cobrança.

### 4.2 Marcação pelo celular e pelo navegador (D-060)

- **RN-10-010** — Fluxo:
  1. o colaborador toca em "Registrar ponto";
  2. o navegador pede a localização;
  3. se a selfie estiver ligada para ele, abre a câmera frontal;
  4. a marcação é enviada e gravada com a hora do servidor;
  5. o NSR é atribuído;
  6. a tela mostra a confirmação com os dados do comprovante.
- **RN-10-011** — **Somente online** (D-064). Sem conexão, a tela avisa e não guarda nada para depois.
- **RN-10-012** — **Localização:** é pedida em toda marcação pelo celular ou navegador, com a precisão informada pelo aparelho. Se a pessoa negar a localização, a marcação é **registrada** como "localização indisponível" e sinalizada, sem ser recusada (RN-10-003) **[P-10-07]**.
- **RN-10-013** — **Classificação:** o sistema sugere o tipo da marcação (entrada, saída para intervalo, volta, saída) pela sequência do dia, só para exibição. O AFD guarda a marcação sem classificação, como pede o layout **[P-10-08]**.
- **RN-10-014** — **Marcação repetida:** uma segunda marcação em menos de 2 minutos mostra "Você marcou às hh:mm. Registrar outra?". Se confirmar, é registrada. O sistema não recusa (RN-10-003) **[P-10-09]**.
- **RN-10-015** — Quem está com o vínculo `read_only` (desligado), `pending` ou `cancelled` não vê o botão de marcação. Quem está `on_leave` (afastado) pode marcar, mas a marcação é sinalizada **[P-10-10]**.

### 4.3 Cerca virtual, IP e externos (D-062, D-316, D-322)

- **RN-10-020** — Cada unidade tem um ponto central (D-216) e um **raio** em metros, de 200 metros por padrão **[P-10-11]**. Na marcação, o sistema compara a localização com as cercas permitidas para a pessoa e grava o resultado: dentro, fora, sem localização ou não se aplica.
- **RN-10-021** — **Modo da cerca** por unidade ou cargo (D-062):
  - **sinalizar**: registra e marca para revisão;
  - **bloquear**: recusa a marcação fora da cerca.

  A regra mais específica vence: cargo sobre unidade **[P-10-12]**.
- **RN-10-022** — **Atenção legal:** o modo **bloquear** pode ser visto como restrição à marcação (RN-10-003). Até o jurídico confirmar, o bloqueio fica disponível com um aviso na configuração. Toda tentativa bloqueada é guardada num registro à parte (não é marcação nem entra no AFD), para eventual prova **[P-10-13]**.
- **RN-10-023** — **IPs autorizados** (D-316): a unidade pode ter uma lista de IPs ou faixas. Com lista, a marcação **pelo navegador do computador** precisa vir de um IP da lista. Fora da lista, aplica-se o modo da cerca: sinaliza ou bloqueia. Sem lista, vale a cerca pela localização. No celular, vale sempre a cerca **[P-10-14]**.
- **RN-10-024** — **Externos** (D-322): cargos ou pessoas marcados como externos marcam de qualquer lugar, sem cerca. A localização é registrada e aparece no espelho.

### 4.4 Selfie (D-313, D-321, D-323)

- **RN-10-030** — Configuração por unidade ou cargo: **sempre**, **nunca** ou **por amostragem** (percentual das marcações, sorteado no servidor) **[P-10-15]**.
- **RN-10-031** — A selfie só é tirada de quem **consentiu** (D-323). Quem recusou marca só com localização (D-321), e isso não é sinalizado como irregular.
- **RN-10-032** — A selfie é foto **ao vivo** pela câmera, sem opção de escolher da galeria. Fica no S3 como dado biométrico (spec 05: criptografada, retenção de 5 anos, acesso pelo RH e pelo gestor da equipe, P-03-24) **[P-10-16]**.
- **RN-10-033** — Sem comparação automática no MVP (D-311). A conferência é visual, pelo RH ou pelo gestor, nas marcações sinalizadas ou por amostragem **[P-10-17]**.

### 4.5 Totem (D-063, D-315)

- **RN-10-040** — **Pareamento:** o RH gera um código de 8 caracteres, válido por 15 minutos, numa unidade. No tablet ou PC, abre-se `<slug>.painel.catalysthr.com.br/totem` e digita-se o código. O aparelho recebe um token próprio e fica preso àquela unidade **[P-10-18]**.
- **RN-10-041** — O totem não tem login de pessoa. Ele mostra a tela de marcação em tela cheia, com a marca da empresa. O RH pode desautorizar o aparelho a qualquer momento, e o token deixa de funcionar na hora.
- **RN-10-042** — **Identificação** (D-063):

  | Forma | Como |
  |---|---|
  | **CPF + PIN** | O colaborador cria um PIN de 4 a 6 dígitos no portal. Depois de 5 PINs errados, o totem bloqueia aquele CPF por 15 minutos **[P-10-19]** |
  | **QR code pessoal** | Gerado no portal, renovado a cada 30 segundos (token assinado, de uso único). O totem lê pela câmera **[P-10-20]** |
  | **Crachá** | Código de barras lido pela câmera ou por leitor USB (que funciona como teclado). NFC só onde o navegador suporta Web NFC (Chrome no Android) **[P-10-21]** |

- **RN-10-043** — A localização da marcação no totem é a da unidade, sem cerca. A selfie no totem segue a configuração da unidade e o consentimento (RN-10-030, RN-10-031).
- **RN-10-044** — O totem mostra o nome da pessoa e o comprovante na tela por alguns segundos, e o comprovante fica no portal dela (RN-10-050).
- **RN-10-045** — Se o totem ficar sem conexão, mostra "Sem conexão: marque pelo celular" e não guarda nada (D-064).

### 4.6 Comprovante (D-314, D-319)

- **RN-10-050** — Cada marcação gera um comprovante com os campos exigidos pela Portaria (a conferir no anexo):
  - título;
  - NSR;
  - identificação do empregador (CNPJ ou CPF, razão social);
  - local da prestação de serviço;
  - nome e CPF do trabalhador;
  - data e hora da marcação, com o fuso;
  - identificação do REP-P;
  - assinatura eletrônica.
- **RN-10-051** — A confirmação aparece na hora. O PDF assinado é gerado por job em segundos e fica no portal (tela do ponto e pasta do mês corrente, P-08-19) **[P-10-22]**.
- **RN-10-052** — O colaborador pode optar, no portal, por receber cada comprovante também por e-mail (D-314).

### 4.7 Intervalo (D-317)

- **RN-10-060** — A jornada (spec 11) define se o intervalo é **marcado** (4 marcações por dia) ou **pré-assinalado** (2 marcações, com o intervalo previsto no espelho). A marcação continua livre: quem tem intervalo pré-assinalado e marca o intervalo tem as marcações registradas normalmente.

### 4.8 Tratamento (D-318)

- **RN-10-070** — Tipos de tratamento:
  - **inclusão** de uma marcação faltante (data, hora e motivo);
  - **desconsideração** de uma marcação existente (motivo).

  Não existe "alterar horário": isso é feito com uma desconsideração e uma inclusão.
- **RN-10-071** — Origens:
  - **pedido de ajuste** do colaborador (spec 09), aprovado pelo gestor (P-03-23);
  - **lançamento direto** pelo RH, com motivo.
- **RN-10-072** — Tratamentos aparecem no espelho e no AEJ **identificados como tratados**, ao lado da marcação original. O AFD nunca muda.
- **RN-10-073** — Prazo para pedir ajuste: até o fechamento do período (spec 11). Depois do fechamento, só o RH trata, com motivo **[P-10-23]**.

### 4.9 AFD e AEJ

- **RN-10-080** — O RH (RH administrador; RH analista com o módulo `ponto`) gera, a qualquer momento:
  - o **AFD** de um empregador e período, com todas as marcações originais, assinado;
  - o **AEJ** de um período, com as marcações tratadas e a jornada.

  Os layouts são os oficiais da Portaria.
- **RN-10-081** — A geração roda em job, o download gera evento de acesso (D-085) e o arquivo fica disponível por 7 dias **[P-10-24]**.
- **RN-10-082** — Os dados do ponto ficam guardados por 5 anos (spec 05). A geração de AFD e AEJ funciona para todo esse período, inclusive para desligados.

### 4.10 Reconhecimento facial (fora do MVP)

- **RN-10-090** — Quando houver app mobile nativo (D-311):
  - AWS Rekognition, com comparação facial e prova de vida em toda marcação, para quem consentiu;
  - contratado por empresa, incluído no plano ou como adicional (D-312);
  - falha registra a marcação e a sinaliza (D-320).

  O modelo de dados desta spec já prevê o resultado da biometria por marcação, vazio no MVP **[P-10-25]**.

## 5. Estados

**Marcação:** gravada uma vez, imutável. Sinalizações (fora da cerca, sem localização, IP fora da lista, afastado) são atributos, não estados.

**Comprovante:** `pending_signature` → `signed` → (`emailed`)

**Tratamento:** `requested` → `approved` | `rejected` (pedido) · `applied` (RH direto)

**Totem:** `pairing` → `active` → `revoked`

## 6. Permissões

Spec 03, seção 4.7, com o detalhe:

| Ação | Quem |
|---|---|
| Marcar | Colaborador (vínculo ativo ou afastado) |
| Ver as próprias marcações e comprovantes | Colaborador |
| Ver marcações, sinalizações e selfies | RH administrador (T), RH analista (U, `ponto`), gestor (E) |
| Aprovar ajuste | Gestor (E), RH |
| Tratar direto | RH administrador, RH analista (U, `ponto`) |
| Configurar cercas, IPs, selfie, externos, totens | RH administrador, RH analista (U, `ponto`) |
| Gerar AFD e AEJ | RH administrador, RH analista (U, `ponto`) |

## 7. Modelo de dados

```
time_entries                                           -- só inclusão (trigger bloqueia UPDATE e DELETE)
  id, company_id, employer_document (CNPJ ou CPF), nsr, employment_id,
  worker_profile_id, recorded_at (UTC, hora do servidor), time_zone,
  channel ('mobile'|'browser'|'kiosk'), kiosk_id, kiosk_identification
  ('cpf_pin'|'qr'|'badge'), ip, user_agent,
  latitude, longitude, accuracy_m, geofence_result
  ('inside'|'outside'|'no_location'|'not_applicable'),
  ip_result ('allowed'|'not_allowed'|'not_applicable'),
  selfie (Active Storage, cript.), selfie_skipped_reason
  ('not_required'|'not_sampled'|'no_consent'),
  biometric_result (nullable, futuro), flags (array), created_at

nsr_counters                                           -- um por empregador, com lock na linha
  company_id, last_nsr

time_entry_receipts
  id, company_id, time_entry_id, pdf (S3), signed_at, signature_info (jsonb),
  emailed_at

time_entry_treatments
  id, company_id, employment_id, kind ('include'|'disregard'), time_entry_id
  (desconsideração), included_at (inclusão, UTC), time_zone, reason,
  request_id (ajuste, spec 09), created_by_id, approved_by_id, created_at

blocked_attempts                                       -- tentativas bloqueadas (RN-10-022)
  id, company_id, employment_id, attempted_at, channel, latitude, longitude,
  ip, reason

geofence_settings
  id, company_id, unit_id, radius_m, mode ('flag'|'block'),
  position_id (nullable: regra por cargo)

unit_ip_allowlists
  id, company_id, unit_id, cidr

external_workers                                       -- por cargo ou por pessoa
  id, company_id, position_id (nullable), employment_id (nullable)

selfie_settings
  id, company_id, unit_id (nullable), position_id (nullable),
  mode ('always'|'never'|'sampling'), sampling_percent

kiosks
  id, company_id, unit_id, name, token_digest, status, paired_at,
  paired_by_id, last_seen_at, revoked_at

kiosk_pairing_codes
  id, company_id, unit_id, code_digest, expires_at, used_at

time_credentials                                       -- PIN e crachá por pessoa
  id, company_id, worker_profile_id, pin_digest, badge_code_digest,
  failed_pin_attempts, locked_until

time_exports
  id, company_id, kind ('afd'|'aej'), employer_document, period_start,
  period_end, file (S3), requested_by_id, expires_at
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `TimeEntries::SignReceiptJob` | A cada marcação, prioridade alta | Gera o PDF (Prawn) e assina com o A1 do empregador |
| `TimeEntries::EmailReceiptJob` | Depois da assinatura, se o colaborador optou | Envia o comprovante por e-mail |
| `TimeExports::GenerateAfdJob` / `GenerateAejJob` | Sob demanda | Gera, assina e disponibiliza |
| `Kiosks::ExpirePairingCodesJob` | A cada 15 minutos | Invalida códigos de pareamento vencidos |

O Sidekiq tem uma fila dedicada e prioritária para o ponto, para que comprovantes não esperem atrás de jobs pesados, como IA e relatórios **[P-10-26]**.

## 9. Critérios de aceite

- **CA-10-001** — Dado um celular com a hora adiantada 10 minutos, quando o colaborador marca, então a marcação e o comprovante usam a hora do servidor.
- **CA-10-002** — Dada uma marcação gravada, quando qualquer código, perfil ou comando SQL tenta alterá-la ou apagá-la, então o banco recusa.
- **CA-10-003** — Dada uma unidade com cerca de 200 m no modo sinalizar, quando alguém marca a 800 m, então a marcação é registrada como "fora da cerca" e aparece para o gestor revisar.
- **CA-10-004** — Dado um cargo externo, quando o vendedor marca em outra cidade, então a marcação é registrada sem sinalização de cerca, com a localização.
- **CA-10-005** — Dada uma unidade com lista de IPs, quando alguém marca pelo navegador de um IP fora da lista, com a unidade no modo sinalizar, então a marcação é registrada e sinalizada.
- **CA-10-006** — Dado um colaborador que recusou a biometria, numa unidade com selfie "sempre", quando ele marca, então a câmera não abre e a marcação não é sinalizada por falta de selfie.
- **CA-10-007** — Dado um totem pareado na unidade Caxias, quando o RH o desautoriza, então a próxima tentativa de marcação no totem é recusada com "aparelho não autorizado".
- **CA-10-008** — Dado um QR code gerado há 40 segundos, quando o totem o lê, então ele é recusado por expirado.
- **CA-10-009** — Dado um pedido de inclusão de marcação aprovado pelo gestor, quando o RH gera o AEJ, então a marcação incluída aparece como tratada, e o AFD do mesmo período não a contém.
- **CA-10-010** — Dada uma empresa em somente leitura por inadimplência, quando o colaborador marca, então a marcação e o comprovante funcionam normalmente.
- **CA-10-011** — Dada uma empresa com ponto e sem certificado A1, quando o RH tenta ativar o ponto, então o sistema exige o envio do certificado.

## 10. Propostas aprovadas (D-324)

| # | Proposta |
|---|---|
| P-10-01 | Programa de tratamento logicamente separado do registro |
| P-10-02 | NSR único e crescente por empregador |
| P-10-03 | RH baixa o registro do INPI e o atestado técnico na plataforma |
| P-10-04 | Marcações imutáveis também no banco (permissões e trigger) |
| P-10-05 | Hora do servidor por NTP, em UTC, com o fuso da unidade |
| P-10-06 | Ponto sem folha também exige o certificado A1 |
| P-10-07 | Localização negada registra e sinaliza, sem recusar |
| P-10-08 | Tipo da marcação só sugerido para exibição; o AFD não classifica |
| P-10-09 | Marcação repetida em menos de 2 minutos pede confirmação, sem recusar |
| P-10-10 | Afastado pode marcar, com sinalização; desligado e pendente não |
| P-10-11 | Raio padrão de 200 m |
| P-10-12 | Regra da cerca: cargo vence unidade |
| P-10-13 | Bloqueio pela cerca com aviso legal e registro das tentativas bloqueadas |
| P-10-14 | IPs autorizados só para o navegador do computador; celular usa sempre a cerca |
| P-10-15 | Selfie por amostragem com sorteio no servidor |
| P-10-16 | Selfie só ao vivo, sem galeria |
| P-10-17 | Conferência visual das selfies no MVP |
| P-10-18 | Pareamento do totem com código de 8 caracteres válido por 15 minutos |
| P-10-19 | PIN de 4 a 6 dígitos com bloqueio após 5 erros por 15 minutos |
| P-10-20 | QR code renovado a cada 30 segundos, de uso único |
| P-10-21 | Crachá por código de barras (câmera ou leitor USB); NFC só com Web NFC |
| P-10-22 | Confirmação na hora; PDF assinado em segundos por job |
| P-10-23 | Ajuste até o fechamento do período; depois, só o RH |
| P-10-24 | AFD e AEJ gerados em job e disponíveis por 7 dias |
| P-10-25 | Modelo de dados já prevê o resultado da biometria (vazio no MVP) |
| P-10-26 | Fila dedicada e prioritária do Sidekiq para o ponto |

## 11. Em aberto

- **Fabricante (D-310) e certificado (D-319):** confirmar com o jurídico.
- **Bloqueio pela cerca × vedações da Portaria (RN-10-022):** confirmar com o jurídico se o modo "bloquear" é permitido.
- **Layouts e campos oficiais** do AFD, AEJ e comprovante: conferir no texto vigente da Portaria 671 e dos anexos.
- **App mobile nativo:** quando entra no roadmap (pré-requisito do reconhecimento facial, D-311).
