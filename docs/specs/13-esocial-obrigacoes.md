# 13 — eSocial e obrigações

> Status: aprovado (leiaute, MOS e prazos pendentes de conferência na documentação oficial) · Última atualização: 2026-11-11
> Decisões: D-071, D-073, D-075, D-093, D-101, D-201, D-206, D-255, D-257, D-298, D-359, D-370 a D-378, D-673 ([decisoes.md](decisoes.md))
> Os itens **[P-13-nn]** foram todos aprovados sem ajuste (D-378, seção 10).
> **Atenção:** os eventos, campos, prazos e regras de envio seguem o que conheço do eSocial (leiaute S-1.x). **A versão vigente do leiaute, os XSD, o Manual de Orientação (MOS) e as notas técnicas precisam ser conferidos na documentação oficial** antes e durante a implementação. Os prazos ficam numa tabela mantida pela equipe CatalystHR, validada por especialista.

## 1. Objetivo

Transmitir ao eSocial, direto da plataforma (D-071), os eventos gerados por cadastros, admissão, desligamento, afastamentos e folha:

- com revisão do RH (D-375);
- com controle de prazos;
- com tratamento de rejeições, retificação e exclusão.

A spec também cobre o acompanhamento das guias do **FGTS Digital** e da **DCTFWeb** (D-373) e o que vai para a contabilidade (EFD-Reinf da CPRB, D-370).

## 2. Escopo de eventos [P-13-01]

| Grupo | Eventos no MVP | Origem |
|---|---|---|
| **Tabelas** | S-1000 (empregador), S-1005 (estabelecimentos), S-1010 (rubricas), S-1020 (lotações) | Specs 04 e 12 |
| **Não periódicos** | S-2190 (registro preliminar), S-2200 (admissão), S-2205 (alteração cadastral), S-2206 (alteração contratual), S-2230 (afastamento), S-2299 (desligamento), S-2300, S-2306 e S-2399 (trabalhador sem vínculo), S-3000 (exclusão) | Specs 04, 07, 09 |
| **Periódicos** | S-1200 (remuneração), S-1210 (pagamentos), S-1280 (informações complementares, como a desoneração), S-1298 (reabertura), S-1299 (fechamento) | Spec 12 |
| **Fora do MVP** | SST: S-2210, S-2220, S-2240 (D-371). S-1070 (processos), S-2298 (reintegração), S-2500 (processo trabalhista), S-1260 e S-1270 (rural e avulsos) e os demais | — |

- **RN-13-001** — **Autônomos:** pelo que conheço, o S-2300 é facultativo para o contribuinte individual autônomo. A remuneração dele sai no S-1200. A plataforma **não envia** S-2300 para autônomos, salvo se o especialista indicar o contrário **[P-13-02]**.
- **RN-13-002** — **PJ** não vai ao eSocial (spec 04).

## 3. Histórias de usuário

1. Como **RH**, quero ver num painel tudo que precisa ir ao eSocial, com os prazos, e enviar em lote.
2. Como **RH**, quero entender em português simples por que um evento foi rejeitado e onde corrigir.
3. Como **RH**, quero corrigir uma admissão já aceita e enviar a retificação.
4. Como **RH**, quero testar a implantação no ambiente de produção restrita antes de ir para produção.
5. Como **RH de uma empresa que vem de outro sistema**, quero importar o que já foi enviado e continuar a partir de novembro.
6. Como **RH**, quero conferir se a guia do FGTS que emiti bate com a folha.
7. Como **contador**, quero a base da CPRB para enviar o R-2060.

## 4. Regras de negócio

### 4.1 Transmissão (D-372)

- **RN-13-010** — Implementação própria em Ruby **[P-13-03]**:
  - **geração do XML** de cada evento por um construtor versionado por leiaute (por exemplo, `Esocial::Layouts::V_S_1_3::S2200`);
  - **validação** contra os XSD oficiais (Nokogiri) antes de ir para a fila;
  - **assinatura** XMLDSig com o A1 do empregador (D-075), com o algoritmo e a canonicalização exigidos pelo leiaute;
  - **lotes** dentro do limite oficial de eventos por lote, do mesmo empregador e do mesmo grupo (tabela, não periódico ou periódico);
  - **envio e consulta** pelos webservices oficiais (envio do lote e consulta do retorno pelo protocolo), com o certificado na conexão TLS.
- **RN-13-011** — **Ordem e dependências:**
  - tabelas antes dos não periódicos, e não periódicos antes dos periódicos do mesmo trabalhador;
  - S-1299 só depois de S-1200 e S-1210 aceitos.

  O motor segura um evento até as dependências dele serem aceitas **[P-13-04]**.
- **RN-13-012** — **Retorno:** um job consulta os protocolos pendentes com intervalo crescente (por exemplo, 1, 2, 5 e 10 minutos). Aceito: guarda o **recibo** e o XML de retorno. Rejeitado: guarda as ocorrências **[P-13-05]**.
- **RN-13-013** — **Versão do leiaute:** a versão ativa é uma configuração da plataforma. Quando sai uma versão nova, a equipe CatalystHR implementa os construtores e troca a versão na data oficial. Eventos de competências anteriores são retificados na versão exigida pela regra oficial.
- **RN-13-014** — Toda chamada ao eSocial passa pelo **cliente central** de integrações, que respeita o modo simulação do impersonate (P-02-32). No impersonate, nada é enviado.

### 4.2 Certificado (D-075)

- **RN-13-020** — O RH administrador envia o A1 (.pfx e senha). O sistema:
  - valida o certificado;
  - lê o titular e a validade;
  - guarda tudo criptografado com o KMS.
- **RN-13-021** — O certificado pode ser **do próprio empregador** ou de um **procurador** com procuração eletrônica para o eSocial (por exemplo, o escritório contábil). O RH indica qual é o caso, e o sistema confere se o titular é o empregador ou outro CNPJ ou CPF **[P-13-06]**.
- **RN-13-022** — Alertas de vencimento do certificado 30, 15 e 5 dias antes ao RH administrador. O mesmo certificado assina comprovantes e AFD do ponto (D-319), e o alerta lembra disso **[P-13-07]**.

  A validação, o cofre por envelope com o KMS, a troca que apaga o anterior e os avisos estão na D-673. A cadeia ICP-Brasil é conferida com o eSocial.

### 4.3 Ambientes (D-374)

- **RN-13-030** — Cada empresa tem o ambiente **produção restrita** ou **produção**. Toda empresa começa em produção restrita.
- **RN-13-031** — A troca para produção é feita pelo RH administrador ou pelo suporte, com confirmação. Ela não leva os eventos da produção restrita: o que valeu em teste é reenviado em produção, a partir da carga inicial **[P-13-08]**.
- **RN-13-032** — Em produção restrita, telas e documentos mostram a faixa "eSocial em ambiente de testes".

### 4.4 Painel do eSocial (D-375)

- **RN-13-040** — Cada ação que gera evento cria um **evento pendente** com os dados já montados:
  - cadastro da empresa e unidades;
  - rubricas;
  - admissão (D-255, que já exige confirmação);
  - alterações de ficha e de vínculo (P-04-22, RN-04-073);
  - afastamento;
  - desligamento;
  - fechamento da folha.
- **RN-13-041** — O painel lista os pendentes por **prazo** (vencidos, vencem hoje, nesta semana), por tipo e por pessoa. O RH revisa (vê os dados em formato legível e, se quiser, o XML) e **envia** um, vários ou todos.
- **RN-13-042** — **Prazos:** a tabela de prazos por evento fica na plataforma, mantida pela equipe CatalystHR e validada por especialista. Exemplos a confirmar no MOS:
  - S-2200 até o dia anterior ao início;
  - periódicos até o dia 15 do mês seguinte.

  Alertas a partir de 3 dias antes do prazo (como RN-07-052) **[P-13-09]**.
- **RN-13-043** — O fechamento da folha (spec 12) gera S-1200, S-1210 e S-1280 (se aplicável) como pendentes, e o S-1299 fica bloqueado até os anteriores serem aceitos. O RH pode enviar tudo com um clique ("Enviar fechamento") **[P-13-10]**.

### 4.5 Rejeições e correções (D-376)

- **RN-13-050** — Evento rejeitado mostra:
  - o **código e a mensagem oficial**;
  - uma **explicação em linguagem simples** e a **sugestão de correção**, geradas pelo Claude com a documentação oficial das ocorrências e os dados do evento (spec 14), consumindo a cota de IA (D-101);
  - um **link para o campo** a corrigir na tela do sistema, quando é possível identificar.
- **RN-13-051** — A explicação da IA é uma sugestão (a IA sugere, a pessoa decide). O texto oficial sempre aparece junto.
- **RN-13-052** — Depois de corrigir, o evento é **gerado de novo** com os dados atuais e volta para o painel. O histórico guarda todas as tentativas.

### 4.6 Retificação e exclusão

- **RN-13-060** — Alterar dados de um evento **aceito**, quando a regra permite, gera uma **retificação** (com o recibo do original), que vai para o painel.
- **RN-13-061** — Cancelar algo já informado gera o **S-3000** com o recibo do evento. Exemplos: admissão cancelada (D-257) e afastamento lançado por engano.
- **RN-13-062** — Retificar ou excluir periódicos de competência fechada exige a **reabertura** (S-1298, spec 12) e um novo fechamento.

### 4.7 Registro preliminar (S-2190)

- **RN-13-070** — Oferecido na admissão quando faltam dados perto do prazo (RN-07-053). Depois dele, o S-2200 completo segue o prazo da tabela, e o painel acompanha **[P-13-11]**.

### 4.8 Migração de outro sistema (D-093, D-377)

- **RN-13-080** — O RH (ou o suporte, na implantação) importa os XMLs dos eventos já transmitidos (com os recibos). O sistema:
  - cria ou atualiza o cadastro (empresa, unidades, rubricas, vínculos) a partir deles;
  - registra cada evento como **aceito externamente**, com o recibo.
- **RN-13-081** — O RH escolhe a **competência de corte**. Daí em diante, a plataforma transmite. Antes dela, nada é reenviado, mas retificações de competências anteriores são possíveis usando os recibos importados **[P-13-12]**.
- **RN-13-082** — Para quem não tem os XMLs, a plataforma pode pedir o **download** dos eventos ao eSocial pelo webservice oficial de consulta e download, com o certificado da empresa (a confirmar a disponibilidade) **[P-13-13]**.

### 4.9 FGTS Digital (D-373)

- **RN-13-090** — Depois do S-1299 aceito, o sistema mostra o **FGTS esperado** da competência: total e por trabalhador, separado por tipo (mensal, rescisório), a partir da folha.
- **RN-13-091** — O RH emite a guia no **portal do FGTS Digital**. O sistema mostra o link e um passo a passo. O RH anexa a guia (PDF) e, depois, o comprovante de pagamento.
- **RN-13-092** — A IA lê a guia anexada e extrai valor total e vencimento (spec 14). O sistema **confere** com o esperado e aponta divergências **[P-13-14]**.
- **RN-13-093** — **Rescisão:** a guia com o FGTS rescisório e a multa (40% ou 20%) segue o mesmo fluxo, com o prazo de pagamento da rescisão (D-298).
- **RN-13-094** — **Seguro-desemprego:** fora da transmissão. O sistema mostra os dados necessários para o requerimento no portal oficial, e o RH registra o número do requerimento no desligamento **[P-13-15]**.

### 4.10 DCTFWeb (D-373)

- **RN-13-100** — Depois do S-1299 aceito, o sistema mostra o **INSS e o IRRF esperados** da competência (empregado, patronal, RAT, terceiros, IRRF por código de receita).
- **RN-13-101** — A DCTFWeb é gerada no e-CAC a partir do eSocial e do EFD-Reinf. O RH (ou a contabilidade) transmite e emite o DARF lá, e anexa o DARF e o comprovante no sistema, que **confere** como no FGTS.
- **RN-13-102** — **Empresas desoneradas** (D-370): o sistema gera para a contabilidade o relatório da **base e do valor da CPRB** por competência e estabelecimento, para ela enviar o **R-2060** do EFD-Reinf. O sistema avisa que a DCTFWeb só fecha com o Reinf enviado.

### 4.11 Crédito do Trabalhador (consignado)

- **RN-13-110** — Como os contratos do consignado chegam ao empregador e como os descontos são informados (spec 12, RN-12-054) **ficam em aberto**, até estudar as regras vigentes do programa.

## 5. Estados

**Evento:** `pending_review` → `queued` → `sent` (protocolo) → `accepted` (recibo) | `rejected` → (`pending_review` após correção) · `blocked` (esperando dependência) · `imported` (aceito externamente) · `superseded` (retificado)

**Guia (FGTS, DARF):** `expected` → `issued` (guia anexada) → `paid` (comprovante) · `divergent`

**Empresa no eSocial:** `restricted_production` → `production`

## 6. Permissões

| Ação | Quem |
|---|---|
| Certificado A1 | RH administrador (spec 03) |
| Painel: revisar e enviar eventos | RH administrador (T), RH analista (U, `esocial`) |
| Trocar o ambiente para produção | RH administrador, suporte (empresa direta) |
| Importar XMLs (migração) | RH administrador, suporte |
| Guias: anexar e conferir | RH administrador, RH analista (U, `folha`) |
| Ver eventos, retornos e guias | Contabilidade em leitura (D-193) |
| Versão do leiaute, tabela de prazos, catálogo de ocorrências | Superadmin, suporte |

## 7. Modelo de dados

```
esocial_settings
  company_id, environment ('restricted_production'|'production'),
  production_since, cutover_competence, certificate_owner ('employer'|'proxy')

employer_certificates                                  -- D-075
  id, company_id, encrypted_pfx (KMS), encrypted_password (KMS), holder_document,
  holder_name, valid_from, valid_to, status

esocial_events
  id, company_id, event_type ('S-2200'...), layout_version, environment,
  subject_type, subject_id, competence, kind ('original'|'rectification'|'exclusion'),
  original_event_id, status, payload (jsonb), xml (S3), signed_xml (S3),
  deadline_on, blocked_by_ids (array), batch_id, receipt_number,
  imported (bool), created_by_id, sent_by_id

esocial_batches
  id, company_id, environment, group ('table'|'non_periodic'|'periodic'),
  protocol, status, sent_at, last_checked_at, response_xml (S3)

esocial_event_occurrences
  id, company_id, esocial_event_id, attempt, code, message, field_path,
  ai_explanation, ai_suggestion

esocial_deadlines                                      -- global, mantida pela plataforma
  event_type, rule (jsonb), legal_reference, valid_from

esocial_occurrence_catalog                             -- global: códigos oficiais
  code, official_message, notes

tax_guides
  id, company_id, competence, kind ('fgts_monthly'|'fgts_termination'|'darf'),
  expected_amount, issued_amount, due_on, guide_file, receipt_file,
  extracted (jsonb), status, employment_id (nullable, rescisória)

cprb_reports
  id, company_id, competence, unit_id, base_amount, rate, amount, file
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Esocial::BuildEventJob` | Quando uma ação gera evento | Monta o payload e o XML e valida no XSD |
| `Esocial::SendBatchJob` | Ao enviar pelo painel | Assina, monta os lotes e envia |
| `Esocial::PollBatchJob` | Intervalo crescente por protocolo | Consulta o retorno e atualiza os eventos |
| `Esocial::ExplainRejectionJob` | Ao rejeitar | Pede a explicação à IA (spec 14) |
| `Esocial::DeadlinesJob` | Diário | Alertas de prazo |
| `Certificates::ExpirationJob` | Diário | Alertas de vencimento do A1 |
| `Esocial::ImportXmlsJob` | Na migração | Lê os XMLs e cria cadastro e eventos importados |

## 9. Critérios de aceite

- **CA-13-001** — Dado um S-2200 com um campo obrigatório vazio, quando o evento é montado, então a validação do XSD falha e o evento fica no painel com o campo indicado, sem ir ao eSocial.
- **CA-13-002** — Dado um evento enviado, quando o retorno chega aceito, então o recibo fica gravado e o status vira `accepted`.
- **CA-13-003** — Dado um evento rejeitado, quando o RH abre o detalhe, então vê a mensagem oficial, a explicação da IA e o link para o campo.
- **CA-13-004** — Dado o fechamento da folha, quando o RH clica em "Enviar fechamento", então S-1200 e S-1210 vão primeiro, e o S-1299 só vai depois de os dois serem aceitos.
- **CA-13-005** — Dada uma empresa em produção restrita, quando qualquer tela do eSocial é aberta, então aparece a faixa de ambiente de testes.
- **CA-13-006** — Dada uma admissão cancelada com S-2200 aceito, quando o RH confirma o cancelamento, então um S-3000 com o recibo do S-2200 entra no painel.
- **CA-13-007** — Dado um certificado que vence em 15 dias, quando o job roda, então o RH administrador recebe o alerta mencionando eSocial e ponto.
- **CA-13-008** — Dados XMLs importados até a competência 10/2026 e o corte em 11/2026, quando a folha de 11/2026 fecha, então a plataforma envia os periódicos de 11/2026 e não reenvia nada anterior.
- **CA-13-009** — Dada uma guia do FGTS anexada com valor diferente do esperado, quando a IA lê a guia, então o sistema mostra a divergência ao RH.
- **CA-13-010** — Dada uma empresa desonerada, quando a competência fecha, então o relatório da CPRB fica disponível para a contabilidade.
- **CA-13-011** — Dado um suporte em impersonate, quando ele simula o envio de um evento, então nada sai para o eSocial.

## 10. Propostas aprovadas (D-378)

| # | Proposta |
|---|---|
| P-13-01 | Escopo de eventos do MVP (tabela da seção 2) |
| P-13-02 | Sem S-2300 para autônomos, salvo indicação do especialista |
| P-13-03 | Arquitetura do motor: construtores versionados, XSD, XMLDSig, lotes, webservices |
| P-13-04 | Eventos esperam as dependências serem aceitas |
| P-13-05 | Consulta de retorno com intervalo crescente |
| P-13-06 | Certificado do empregador ou de procurador, com conferência do titular |
| P-13-07 | Alertas de vencimento do certificado com 30, 15 e 5 dias |
| P-13-08 | Troca para produção sem levar eventos de teste |
| P-13-09 | Tabela de prazos da plataforma e alertas a partir de 3 dias antes |
| P-13-10 | "Enviar fechamento" com um clique, respeitando a ordem |
| P-13-11 | S-2200 depois do S-2190 acompanhado pelo prazo da tabela |
| P-13-12 | Retificações anteriores ao corte usando os recibos importados |
| P-13-13 | Download dos eventos pelo webservice oficial, para quem não tem os XMLs |
| P-13-14 | IA lê a guia anexada e confere com o esperado |
| P-13-15 | Seguro-desemprego: dados para o requerimento e registro do número |

## 11. Em aberto

- **Versão vigente do leiaute, XSD, MOS e prazos:** conferir na documentação oficial e com o especialista.
- **Crédito do Trabalhador:** como os contratos chegam e como os descontos são informados.
- **Webservice de download de eventos** (P-13-13): confirmar disponibilidade e regras.
