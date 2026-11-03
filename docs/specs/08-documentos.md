# 08 — Documentos

> Status: aprovado · Última atualização: 2026-10-12
> Decisões: D-084 a D-086, D-147, D-183, D-187, D-193, D-204, D-221, D-270 a D-282, D-640, D-642 a D-644 ([decisoes.md](decisoes.md))
> Os itens **[P-08-nn]** foram todos aprovados sem ajuste (D-282, seção 10).

## 1. Objetivo

Manter **cada documento no lugar certo, com revisão rastreável**, como diz a apresentação:

- uma pasta por pessoa em cada empresa;
- tipos e categorias padronizados;
- versões;
- revisão com ajuda da IA;
- vencimentos com aviso;
- pedidos avulsos;
- ciência eletrônica.

A leitura dos documentos pela IA (classificação e extração) fica na [spec 14](14-ia.md). Esta spec define o que acontece antes e depois dela.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Tipo de documento | `DocumentType` | RG, CNH, ASO, comprovante de residência etc. Da plataforma ou da empresa (D-270) |
| Categoria | — | Agrupamento fixo da pasta (tabela abaixo) |
| Documento | `Document` | Um documento da pasta de uma pessoa, de um tipo |
| Versão | `DocumentVersion` | Cada envio do documento. A mais recente aprovada é a vigente |
| Pedido de documento | `DocumentRequest` | Pedido avulso do RH, que vira pendência (D-278) |
| Lote | `DocumentBatch` | Envio de vários arquivos pelo RH, distribuídos com a IA (D-277) |

### Categorias fixas (D-270) [P-08-01]

| Categoria | Exemplos | Sensível (spec 05) |
|---|---|---|
| Pessoais | RG, CPF, CNH, título, comprovante de residência, certidões | Sim (documentos pessoais) |
| Admissão | CTPS, PIS, contrato assinado, termo de estágio, ficha | Sim (documentos pessoais) |
| Saúde | ASO, atestados, laudos | Sim (saúde) |
| Dependentes | Certidões e documentos dos dependentes | Sim (dependentes) |
| Declarações | Declarações escolares, de vínculo, comunicados com ciência | Não |
| Contratos | Contratos e termos gerados (spec 07) | Não, exceto o salário mostrado no contrato **[P-08-02]** |
| Folha | Holerites, informe de rendimentos, TRCT (gerados) | Sim (remuneração) |
| Ponto | Espelhos, comprovantes de marcação (gerados) | Não |
| Outros | Tipos da empresa sem categoria específica | Conforme o tipo |

## 3. Histórias de usuário

1. Como **colaborador**, quero tirar foto do documento pelo celular e enviar direto na pendência.
2. Como **RH**, quero ver o documento ao lado dos campos extraídos e aprovar, ou pedir correção com o motivo.
3. Como **RH**, quero ser avisado 30 dias antes de uma CNH vencer, e que o motorista já receba a pendência de enviar a nova.
4. Como **gestor**, quero saber que a CNH de alguém da equipe vai vencer, mesmo sem ver o documento.
5. Como **RH**, quero subir de uma vez os 40 ASOs que a clínica mandou e deixar a IA distribuir nas pastas.
6. Como **RH**, quero pedir a declaração escolar dos dependentes de todos que recebem salário-família.
7. Como **RH**, quero publicar uma advertência e ter o registro de que o colaborador deu ciência.
8. Como **RH**, quero baixar a pasta inteira de alguém para entregar a um advogado.

## 4. Regras de negócio

### Tipos de documento (D-270)

- **RN-08-001** — **Tipos da plataforma:** mantidos pela equipe CatalystHR, com a configuração de extração da IA (spec 14). Valem para todas as empresas.
- **RN-08-002** — **Tipos da empresa:** criados pelo RH administrador, sem extração pela IA. A IA ainda pode sugerir que um arquivo é desse tipo pelo nome e pela descrição **[P-08-03]**.
- **RN-08-003** — Configurações de cada tipo:
  - nome e categoria;
  - **interno** (o colaborador não vê, D-274);
  - **exige ciência** por padrão (D-279);
  - **regra de vencimento** e antecedência do aviso (D-272, D-275);
  - quantidade de arquivos por versão.
- **RN-08-004** — A empresa pode desativar tipos da plataforma que não usa. Desativar não afeta os documentos já existentes **[P-08-04]**.

### Envio (D-271)

- **RN-08-010** — Formatos aceitos: **PDF, JPG e PNG**, com até **10 MB por arquivo**. O tipo real do arquivo é conferido pelo conteúdo, e o arquivo passa pela varredura de vírus antes de ficar disponível (P-05-30).
- **RN-08-011** — Uma versão pode ter até 5 imagens (por exemplo, frente e verso), que são juntadas num PDF único pelo Prawn. Um PDF é sempre arquivo único **[P-08-05]**.
- **RN-08-012** — No celular, o botão de envio abre a câmera traseira (`capture="environment"`). Imagens grandes são comprimidas no navegador, com JavaScript puro, antes do envio, para ficarem abaixo de 10 MB e subirem rápido em 4G **[P-08-06]**.
- **RN-08-013** — Quem envia:
  - o **colaborador**, na própria pasta e nas pendências;
  - o **RH**, em qualquer pasta do escopo dele (spec 03).

  O gestor não envia documentos (spec 03).
- **RN-08-014** — Os arquivos ficam no S3 com a chave `companies/<company_id>/documents/<uuid>`, por Active Storage com chave definida pela aplicação (P-01-09) **[P-08-07]**.

### Revisão

- **RN-08-020** — Cada versão enviada segue os estados **[P-08-08]**:

  ```
  submitted → scanning → ai_processing → awaiting_review → approved
                                       ↘ ai_failed → awaiting_review (conferência manual)
  awaiting_review → correction_requested  (o colaborador envia uma nova versão)
  ```

  Tipos sem extração vão direto de `scanning` para `awaiting_review`.
- **RN-08-021** — Na revisão, o RH vê o documento ao lado dos campos extraídos e dos valores do cadastro, com cada campo marcado como "confere", "divergência" ou "campo novo" (spec 14, como no protótipo). Antes de aprovar, o RH pode corrigir os valores e escolher quais aplicar na ficha.
- **RN-08-022** — **Pedir correção** exige escolher um motivo, e o motivo aparece para o colaborador. Motivos padrão: imagem ilegível, documento vencido, tipo errado, documento incompleto (falta frente ou verso), dados divergentes, outro (com texto) **[P-08-09]**.
- **RN-08-023** — Aprovar a versão nova torna a anterior `replaced`. A versão anterior continua visível ao RH, com o motivo da substituição, mas não ao colaborador (D-280).
- **RN-08-024** — A IA nunca aprova sozinha. Ela não confirma a autenticidade do documento, e a tela de revisão mostra esse aviso (apresentação, página 10).

### Vencimentos (D-272, D-275, D-276)

- **RN-08-030** — Regras de vencimento por tipo:

  | Regra | Como calcula | Exemplo |
  |---|---|---|
  | `none` | Não vence | RG |
  | `document_date` | Data de validade do próprio documento, extraída pela IA ou digitada pelo RH | CNH, certificados |
  | `periodicity` | Data do documento mais N meses. N pode variar por cargo | ASO periódico a cada 12 meses (6 em cargos de risco) |
  | `age` | Data de emissão mais N dias, aceito só se recente | Comprovante de residência (90 dias) **[P-08-10]** |

- **RN-08-031** — A antecedência do aviso é configurável por tipo, com 30 dias de padrão (D-275). Na data do aviso, o sistema:
  - cria uma **pendência** para o colaborador enviar o documento novo;
  - avisa o **RH** da unidade;
  - avisa os **gestores** do departamento (D-276). O gestor recebe só o texto ("CNH de Marcos Teles vence em 02/11"), sem acesso ao arquivo (spec 03) **[P-08-11]**.
- **RN-08-032** — Quando a data passa, o documento fica `expired`, e o painel mostra o vencido. O vencimento não bloqueia nada no sistema **[P-08-12]**.
- **RN-08-033** — O tipo `age` é conferido no envio: um comprovante de residência com mais de 90 dias gera a sugestão de correção "documento vencido" na revisão. É a regra do protótipo **[P-08-10]**.

### Pedido avulso (D-278)

- **RN-08-040** — O RH pede um documento escolhendo:
  - o tipo;
  - as pessoas: uma pessoa, ou um grupo filtrado por unidade, departamento, cargo ou critério (por exemplo, "com dependente para salário-família");
  - o prazo;
  - uma mensagem.
- **RN-08-041** — Cada pessoa recebe uma pendência no portal e um aviso (spec 15). O pedido é atendido quando o documento é **aprovado**. O RH acompanha um painel do pedido: quantos enviaram, quantos estão pendentes e quantos atrasados.

### Ciência eletrônica (D-279)

- **RN-08-050** — O RH publica um documento pedindo ciência (advertência, aviso de férias, comunicado). Pode ser para uma pessoa ou para um grupo, como no pedido avulso.
- **RN-08-051** — O colaborador vê a pendência, abre o documento e confirma "Li e estou ciente", podendo escrever um comentário. Ficam registrados a data, a hora, o IP, o user agent e a versão (hash do arquivo).
- **RN-08-052** — O texto da tela deixa claro que a ciência confirma **o recebimento**, e não concordância nem assinatura (D-147) **[P-08-13]**.
- **RN-08-053** — Sem ciência no prazo, o RH pode registrar **"ciência recusada"**, com observação e até duas testemunhas (nome e CPF), como se faz no papel **[P-08-14]**.
- **RN-08-054** — O RH pode gerar um comprovante em PDF com todos os registros de ciência de um documento **[P-08-15]**.

### Envio em lote (D-277)

- **RN-08-060** — O RH envia até 100 arquivos por lote **[P-08-16]**. Para cada arquivo, a IA sugere:
  - o **tipo**;
  - a **pessoa**, pelo CPF ou pelo nome encontrado no documento, só entre as pessoas do escopo de quem enviou.
- **RN-08-061** — O RH vê uma tabela "arquivo → tipo → pessoa → confiança" e confirma, corrige ou descarta cada linha antes de distribuir. Nada entra numa pasta sem confirmação.
- **RN-08-062** — Arquivos sem pessoa identificada ficam no lote até o RH escolher a pessoa ou descartar o arquivo. Lotes não concluídos expiram em 30 dias, com aviso, e os arquivos são excluídos **[P-08-17]**.
- **RN-08-063** — Depois de distribuídos, os documentos seguem o fluxo normal de revisão (RN-08-020).

### Documentos gerados (D-273)

- **RN-08-070** — Holerites, informe de rendimentos, TRCT, espelhos de ponto, comprovantes de marcação e contratos são gerados pelos módulos de origem e **registrados na pasta** na categoria deles. Na pasta, são **somente leitura**: não podem ser substituídos nem excluídos por ali **[P-08-18]**.
- **RN-08-071** — Os comprovantes de marcação do ponto são muitos. Por isso, a pasta mostra só os do mês corrente, e os demais são vistos na tela do ponto **[P-08-19]**.

### Visibilidade, download e exclusão

- **RN-08-080** — O colaborador vê a própria pasta, menos os tipos internos (D-274), e só a versão vigente (D-280).
- **RN-08-081** — Abrir documento de categoria sensível exige a confirmação de senha dos últimos 5 minutos (D-183) e gera evento de acesso (D-085). Isso vale também para o próprio colaborador na pasta dele **[P-08-20]**.
- **RN-08-082** — **Baixar a pasta em ZIP** (D-281):
  - é gerado em job, com confirmação de senha e evento de acesso;
  - o ZIP só traz as categorias que quem pede pode ver (por exemplo, sem saúde para quem não tem acesso);
  - o link expira em 24 horas **[P-08-21]**.
- **RN-08-083** — **Excluir** (só o RH administrador, P-03-19):
  - exige motivo, por exemplo "enviado na pasta errada";
  - o documento some da pasta na hora;
  - o arquivo fica 30 dias recuperável e depois é excluído do S3;
  - tudo fica na auditoria **[P-08-22]**.

## 5. Estados

**Versão:** `submitted` → `scanning` → (`ai_processing` → `ai_failed`)? → `awaiting_review` → `approved` | `correction_requested` → `replaced`
(`rejected_by_scan` quando a varredura acha vírus ou o tipo é inválido)

**Documento:** `pending` (pedido sem envio) → `valid` → `expiring` → `expired` · `deleted`

**Ciência:** `awaiting` → `acknowledged` | `refused`

**Lote:** `processing` → `awaiting_confirmation` → `distributed` | `expired`

## 6. Permissões

Spec 03, seção 4.5, com o detalhe:

| Ação | Quem |
|---|---|
| Ver e enviar na própria pasta | Colaborador (sem tipos internos) |
| Ver, enviar, revisar, pedir documento, publicar com ciência, lote, ZIP | RH administrador (T), RH analista (U, módulo `documentos`) |
| Documentos de saúde | RH administrador, RH analista das unidades. Gestor e contabilidade não |
| Pasta em leitura | Contabilidade (sem saúde, P-03-18) |
| Excluir | RH administrador |
| Tipos da empresa | RH administrador |
| Tipos da plataforma | Superadmin, suporte |

## 7. Modelo de dados

```
document_types
  id, company_id (nullable = plataforma), code, name, category, internal,
  requires_acknowledgment, expiration_rule ('none'|'document_date'|'periodicity'|'age'),
  expiration_months, max_age_days, alert_days (padrão 30), max_files,
  ai_extraction_profile (só plataforma, spec 14), status

company_document_type_settings                         -- desativar ou ajustar tipos da plataforma
  company_id, document_type_id, enabled, alert_days

position_document_expirations                          -- periodicidade por cargo (D-272)
  company_id, position_id, document_type_id, expiration_months

documents
  id, company_id, worker_profile_id, document_type_id, status,
  current_version_id, expires_on, source ('employee'|'hr'|'process'|'batch'|'generated'),
  source_ref_type, source_ref_id, deleted_at, deleted_by_id, delete_reason

document_versions
  id, company_id, document_id, status, files (Active Storage, 1..5),
  pdf (arquivo único consolidado), sha256, uploaded_by_id, uploaded_at,
  ai_extraction_id (spec 14), reviewed_by_id, reviewed_at, correction_reason,
  correction_note, issued_on, valid_until

document_requests
  id, company_id, document_type_id, requested_by_id, message, due_on,
  audience_filter (jsonb)

document_request_targets
  id, company_id, document_request_id, worker_profile_id, document_id, status

acknowledgments
  id, company_id, document_id, document_version_id, worker_profile_id,
  status, acknowledged_at, ip, user_agent, comment,
  refused_note, witnesses (jsonb), recorded_by_id

document_batches
  id, company_id, uploaded_by_id, status, expires_at

document_batch_items
  id, company_id, document_batch_id, file, suggested_type_id,
  suggested_worker_profile_id, confidence, confirmed_type_id,
  confirmed_worker_profile_id, status ('pending'|'confirmed'|'discarded'|'distributed')
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Documents::ScanJob` | A cada upload | Confere o tipo real e faz a varredura de vírus (P-05-30) |
| `Documents::ConsolidatePdfJob` | Após a varredura | Junta as imagens num PDF (Prawn) |
| `Documents::AiProcessJob` | Após a consolidação | Chama a extração da IA (spec 14) |
| `Documents::ExpirationsJob` | Diário | Avisos, pendências e mudança para `expired` |
| `Documents::BatchClassifyJob` | Por lote | Classificação e identificação da pessoa pela IA |
| `Documents::ZipFolderJob` | Sob demanda | Monta o ZIP da pasta |
| `Documents::PurgeDeletedJob` | Diário | Exclui do S3 os arquivos excluídos há mais de 30 dias |

## 9. Critérios de aceite

- **CA-08-001** — Dado um arquivo `.docx`, quando o colaborador tenta enviar, então o sistema recusa e lista os formatos aceitos.
- **CA-08-002** — Dadas duas fotos (frente e verso do RG), quando o colaborador envia, então a versão fica com um PDF único de duas páginas.
- **CA-08-003** — Dado um comprovante de residência emitido há 120 dias, quando o RH abre a revisão, então vê a sugestão "documento vencido (mais de 90 dias)".
- **CA-08-004** — Dada uma CNH que vence em 02/11, com aviso de 30 dias, quando chega 03/10, então o colaborador recebe a pendência, o RH recebe o aviso, e o gestor recebe só o texto, sem link para o arquivo.
- **CA-08-005** — Dado um pedido de declaração escolar para 12 pessoas, quando 8 enviam e 6 são aprovadas, então o painel do pedido mostra 6 atendidos, 2 em revisão e 4 pendentes.
- **CA-08-006** — Dado um lote de 40 ASOs, quando a IA identifica 37, então os 3 restantes ficam no lote aguardando o RH, e nenhum dos 40 entra em pasta antes da confirmação.
- **CA-08-007** — Dada uma advertência publicada com ciência, quando o colaborador confirma, então o registro guarda data, hora, IP e o hash do arquivo, e o RH pode gerar o comprovante.
- **CA-08-008** — Dado um tipo marcado como interno, quando o colaborador abre a pasta, então não vê documentos desse tipo.
- **CA-08-009** — Dado um contador, quando ele abre a pasta de um colaborador, então não vê a categoria Saúde.
- **CA-08-010** — Dado um documento excluído pelo RH administrador há 10 dias, quando ele pede a recuperação, então o documento volta. Depois de 30 dias, não há recuperação.

## 10. Propostas aprovadas (D-282)

| # | Proposta |
|---|---|
| P-08-01 | Lista de categorias fixas e quais são sensíveis |
| P-08-02 | Contratos gerados não são categoria sensível |
| P-08-03 | A IA pode sugerir tipos da empresa pelo nome e descrição |
| P-08-04 | A empresa pode desativar tipos da plataforma |
| P-08-05 | Até 5 imagens por versão, juntadas num PDF |
| P-08-06 | Câmera traseira no celular e compressão no navegador |
| P-08-07 | Chave do S3 com prefixo da empresa via Active Storage |
| P-08-08 | Estados da versão, com varredura antes da IA |
| P-08-09 | Lista de motivos de correção |
| P-08-10 | Regra de vencimento `age` (comprovante de residência com 90 dias) |
| P-08-11 | O gestor recebe só o texto do vencimento, sem o arquivo |
| P-08-12 | Vencimento não bloqueia nada |
| P-08-13 | O texto da ciência deixa claro que é recebimento, não assinatura |
| P-08-14 | "Ciência recusada" com observação e testemunhas |
| P-08-15 | Comprovante em PDF dos registros de ciência |
| P-08-16 | Até 100 arquivos por lote |
| P-08-17 | Arquivos sem pessoa ficam no lote; lote expira em 30 dias |
| P-08-18 | Documentos gerados são somente leitura na pasta |
| P-08-19 | Comprovantes de marcação na pasta só do mês corrente |
| P-08-20 | Confirmação de senha também para o colaborador nos próprios documentos sensíveis |
| P-08-21 | ZIP só com as categorias permitidas e link válido por 24 horas |
| P-08-22 | Exclusão recuperável por 30 dias |
