# 18 — Importação e exportação

> Status: aprovado · Última atualização: 2026-11-10
> Decisões: D-085, D-087, D-093, D-094, D-186, D-207, D-222, D-377, D-460 a D-469, D-661 a D-668 ([decisoes.md](decisoes.md))
> Os itens **[P-18-nn]** foram todos aprovados sem ajuste (D-469, seção 10).

## 1. Objetivo

Colocar a empresa para funcionar **sem redigitar nada** e garantir que **os dados são dela**:

- implantação pela planilha modelo, pelos XMLs do eSocial e pelos conversores de Domínio, Questor e Alterdata (D-094, D-460, D-461);
- importações do dia a dia (D-463);
- prévia com erros linha a linha, confirmação e desfazer (D-462, D-465);
- importação assistida pela equipe CatalystHR (D-468);
- exportação completa da empresa a qualquer momento (D-466).

Os relatórios e suas exportações ficam na spec 17. A portabilidade do titular e a exportação de encerramento ficam na spec 05. Esta spec define o motor comum de importação e o formato da exportação completa.

## 2. Conceitos

| Conceito | Código | Descrição |
|---|---|---|
| Tipo de importação | `ImportKind` | Cada importação possível (seção 4.2), com o modelo, as colunas e as validações |
| Importação | `DataImport` | Um envio de arquivo, com o status e o resultado |
| Linha | `DataImportRow` | Cada linha do arquivo, com os dados lidos, os erros e o registro criado |
| Exportação completa | `CompanyExport` | Todos os dados e arquivos da empresa (D-466, RN-05-080) |

## 3. Histórias de usuário

1. Como **RH na implantação**, quero baixar a planilha modelo, preencher com os 300 colaboradores e importar tudo de uma vez.
2. Como **RH**, quero ver os erros linha a linha antes de gravar, como "CPF inválido" ou "cargo não cadastrado".
3. Como **RH**, quero trazer o saldo de banco de horas e os períodos de férias de cada pessoa, para não perder o histórico.
4. Como **RH**, quero importar as comissões do mês pela planilha do comercial, em vez de digitar uma a uma.
5. Como **RH**, quero aplicar um reajuste coletivo de 5% a partir de 01/05 para todos os operadores.
6. Como **RH administrador**, quero desfazer uma importação que subi na empresa errada.
7. Como **suporte CatalystHR**, quero subir a base de um cliente que veio de outro sistema, com a autorização dele registrada.
8. Como **RH administrador**, quero baixar todos os dados da empresa para guardar uma cópia.

## 4. Regras de negócio

### 4.1 Fluxo comum (D-462, D-464)

- **RN-18-001** — Toda importação segue o mesmo fluxo:
  1. **escolher o tipo** e baixar o **modelo XLSX**, com uma aba de instruções, as colunas obrigatórias destacadas, exemplos e listas de opções (unidades, cargos, tipos de vínculo, rubricas) já preenchidas com os cadastros da empresa;
  2. **enviar** o arquivo em XLSX ou CSV;
  3. **validar** em segundo plano;
  4. ver a **prévia**;
  5. **confirmar**, escolhendo entre importar tudo (se não houver erro) ou só as linhas válidas;
  6. ver o **resultado**, com o relatório para baixar.
- **RN-18-002** — Limites: **20 MB** e **10.000 linhas** por arquivo. Acima disso, o arquivo deve ser dividido **[P-18-01]**.
- **RN-18-003** — **Leitura:** gem `roo` para XLSX e a biblioteca CSV do Ruby, aceitando separador vírgula ou ponto e vírgula e codificação UTF-8 ou Windows-1252, detectados sozinhos. As colunas são reconhecidas pelo **nome do cabeçalho**, e não pela posição **[P-18-02]**.
- **RN-18-004** — **Normalização** antes de validar: CPF, CNPJ, CEP e telefone com ou sem máscara; datas em `dd/mm/aaaa` ou `aaaa-mm-dd`; valores com vírgula ou ponto decimal; espaços extras removidos; textos de lista comparados sem acento e sem diferenciar maiúsculas **[P-18-03]**.
- **RN-18-005** — **Validação:** as mesmas regras do cadastro manual (modelos do Rails), mais as regras de cada tipo. Também confere **repetição dentro do arquivo** (o mesmo CPF duas vezes) e **referências** (cargo, unidade e departamento existentes, ou criados na mesma importação de estrutura).
- **RN-18-006** — **Prévia:** total de linhas, quantas serão criadas, atualizadas, ignoradas (iguais ao que já existe) e com erro. Para cada erro: linha, coluna, valor e mensagem em português, por exemplo "Linha 42, coluna CPF: dígito verificador inválido (123.456.789-00)". O RH baixa o arquivo original com uma coluna "Erros" para corrigir e reenviar **[P-18-04]**.
- **RN-18-007** — **Criar ou atualizar:** cada tipo tem uma chave (por exemplo, CPF para pessoas, código para cargos). Se a chave já existe, a linha **atualiza** o registro, e a prévia mostra o antes e o depois dos campos que mudam. Campos vazios na planilha **não apagam** o que existe **[P-18-05]**. Nos colaboradores, uma matrícula que já existe atualiza só a ficha: as condições do vínculo mudam por revisão com vigência (D-207, D-663).
- **RN-18-008** — **Gravação:** só depois da confirmação, em lotes com transação por linha. Uma linha com erro inesperado na gravação não desfaz as outras e aparece no resultado **[P-18-06]**.
- **RN-18-009** — Toda alteração feita pela importação fica no PaperTrail com a origem `import:<id>`, e a importação gera um evento de acesso (D-085).
- **RN-18-010** — O arquivo enviado fica guardado por **90 dias** e depois é excluído. O resultado (contagens e erros, sem os dados) fica no histórico de importações **[P-18-07]**.

### 4.2 Tipos de importação

**Implantação (D-460)**, na ordem recomendada pelo assistente de implantação **[P-18-08]**:

| # | Tipo | Chave | O que traz |
|---|---|---|---|
| 1 | Estrutura | Código | Unidades (CNPJ do estabelecimento), departamentos com o departamento pai, cargos com CBO |
| 2 | Colaboradores e vínculos | CPF + matrícula | Ficha (spec 04), vínculo com tipo, cargo, unidade, departamento, salário, jornada, data de admissão |
| 3 | Dependentes | CPF do titular + CPF ou nome do dependente | Dependentes com parentesco, IRRF e salário-família |
| 4 | Dados bancários e PIX | CPF | Banco, agência, conta, chave PIX |
| 5 | Gestores dos departamentos | Código do departamento + CPF | Gestores (vários por departamento), só os já ativos com o perfil de gestor; a importação não remove nenhum (D-664) |
| 6 | Histórico salarial e de cargos | CPF + matrícula + data (D-664) | Revisões do vínculo com vigência e motivo (D-207). Na data de uma revisão existente, com outras condições, vira "Correção" (D-603, D-664) |
| 7 | Férias | CPF + início do período aquisitivo | Períodos aquisitivos, dias gozados, vendidos e o saldo |
| 8 | Banco de horas | CPF | Saldo inicial na data de corte, com o vencimento de cada parcela |
| 9 | Acumulados da folha | CPF + competência + rubrica | Valores por rubrica no ano em curso, para médias, 13º, informe e IR |

- **RN-18-020** — A importação de colaboradores **não envia convites** nem eventos ao eSocial. Pessoas já admitidas entram como vínculos **ativos**, com o eSocial marcado como "já enviado por outro sistema" quando a empresa migra pelo corte de competência (D-377). Os convites saem pelo botão "Liberar acesso de todos" **[P-18-09]**. A marca do eSocial entra com a spec 13, e o botão é o "Convidar todos sem acesso" da lista de colaboradores (D-663).
- **RN-18-021** — Saldos (férias, banco de horas, acumulados) entram com uma **data de corte**, a partir da qual a plataforma calcula. Antes dela, só valem os saldos importados **[P-18-10]**.
- **RN-18-022** — **XMLs do eSocial** (D-377): seguem a spec 13 (RN-13-080). Os XMLs podem criar a estrutura, as pessoas e os vínculos, e a planilha completa o que o eSocial não traz (e-mail, celular, gestor, PIX). Quando há conflito, a prévia mostra os dois valores, e o RH escolhe **[P-18-11]**.

**Dia a dia (D-463)**

| Tipo | Chave | Regras |
|---|---|---|
| Lançamentos da folha | CPF ou matrícula + rubrica | Só para competência **aberta** (spec 12). Cria variáveis (`PayrollInput`) com a origem "importação". Reimportar a mesma planilha **substitui** os lançamentos daquela importação, sem duplicar **[P-18-12]** |
| Coparticipação e benefícios | CPF (titular ou dependente) | Planilha da operadora do plano ou do fornecedor de VR/VA. O RH mapeia as colunas na primeira vez, e o mapa fica salvo por fornecedor (P-12-12) **[P-18-13]** |
| Admissões em lote | CPF | Uma admissão por linha, com o cadastro inicial mínimo (D-254). Cria as admissões na etapa 1, sem convite (P-07-06). O CPF com uma admissão aberta vira erro, e o resultado tem "Liberar acesso de todos", por e-mail (D-668) |
| Atualizações em massa | CPF ou matrícula | Revisões do vínculo com data de vigência e motivo (D-207): salário (valor novo ou percentual), cargo, departamento, unidade e jornada; o gestor é o do departamento (D-664, D-668). Data passada segue a regra de revisão retroativa (RN-04-062) **[P-18-14]** |

- **RN-18-030** — As atualizações em massa também podem ser feitas **sem planilha**, por uma tela que filtra as pessoas (unidade, departamento, cargo) e aplica a mesma mudança, com o mesmo fluxo de prévia e confirmação **[P-18-15]**. O percentual vale sobre o salário em vigor na data, arredondado para o centavo com o meio para cima; o RH analista sem o módulo folha não muda salário (D-669).

### 4.3 Escopo e permissões (P-03-31)

- **RN-18-040** — O RH administrador importa para a empresa toda. O RH analista importa só nas unidades dele: linhas de outras unidades viram erro "fora do seu escopo". O analista vê só as próprias importações (D-668).
- **RN-18-041** — Lançamentos da folha exigem o módulo folha liberado (spec 03). Importações que mexem em salário pedem a confirmação de senha ou passkey (RN-02-052).
- **RN-18-042** — Estrutura, histórico salarial, acumulados e XMLs do eSocial só pelo RH administrador (e pelo suporte, na importação assistida) **[P-18-16]**.

### 4.4 Desfazer (D-465)

- **RN-18-050** — O RH administrador desfaz a importação **inteira** enquanto **nenhum registro dela tiver sido usado** **[P-18-17]**:
  - evento do eSocial enviado;
  - folha calculada com os lançamentos;
  - marcação de ponto registrada no vínculo criado;
  - admissão que passou da etapa 1;
  - convite aceito;
  - documento enviado.
- **RN-18-051** — Se algum registro foi usado, o botão mostra o motivo e quais registros impedem. A saída é corrigir com uma nova importação de atualização.
- **RN-18-052** — Desfazer volta cada registro ao estado anterior pela versão do PaperTrail (atualizados) ou o exclui (criados), e fica na auditoria. Como os campos sensíveis ficam fora do PaperTrail (D-086), cada linha guarda os valores anteriores e o que criou, criptografados, até os 90 dias da RN-18-010; a exclusão vale também para os vínculos e as revisões em vigor criados pela importação (D-665).

### 4.5 Importação assistida (D-468)

- **RN-18-060** — O suporte e o superadmin importam pela área admin, **em nome da empresa**, com o mesmo fluxo e os mesmos tipos.
- **RN-18-061** — Antes da primeira importação assistida, o RH administrador da empresa **autoriza** pelo sistema (aceite com data e validade, por exemplo, 30 dias da implantação). Sem autorização válida, a área admin não deixa importar **[P-18-18]**. A autorização vale 30 dias a partir do aceite, pode ser revogada e inclui a declaração de titularidade das contas dos arquivos enviados (D-666).
- **RN-18-062** — A auditoria registra o nome do suporte, e o histórico de importações da empresa mostra "Importado pelo suporte CatalystHR". O RH administrador recebe um aviso a cada importação confirmada.
- **RN-18-063** — Os **conversores** de outros sistemas são scripts mantidos pela equipe CatalystHR fora da aplicação, que transformam os arquivos do cliente na planilha modelo. Assim, tudo passa pela mesma validação. No MVP, há conversores para **Domínio, Questor e Alterdata** (D-094) **[P-18-19]**.

### 4.6 Exportação completa (D-466, D-222, D-087)

- **RN-18-070** — Três exportações usam o **mesmo formato**:

  | Exportação | Quem pede | Conteúdo |
  |---|---|---|
  | Completa da empresa (D-466) | RH administrador, quando quiser | Tudo da empresa |
  | Encerramento (RN-05-080) | Automática ao entrar em `closing` | Tudo da empresa |
  | Portabilidade (RN-05-070) | Titular, por solicitação | Só os dados da pessoa |

- **RN-18-071** — **Formato** **[P-18-20]**:

  ```
  catalysthr-export-<empresa>-<aaaammdd>.zip
    LEIAME.txt            -- o que é cada pasta, a data, os filtros, a versão do formato
    indice.json           -- lista das entidades, quantidade de registros e arquivos com SHA-256
    dados/json/<entidade>.json
    dados/csv/<entidade>.csv          -- UTF-8 com BOM, separador ';'
    arquivos/<cpf>/<categoria>/<documento>-v<versão>.pdf
    esocial/<competência>/<evento>-<recibo>.xml
    ponto/afd/<unidade>-<período>.txt  -- AFD e AEJ oficiais (spec 10)
  ```

- **RN-18-072** — Entram cadastros, vínculos e revisões, documentos e versões, solicitações, processos, marcações e espelhos, folhas e holerites, eventos e recibos do eSocial, e a trilha de auditoria. **Não entram**: segredos (senhas, MFA, passkeys), embeddings da IA e registros internos da plataforma **[P-18-21]**. A cobrança do CatalystHR (contrato, faturas, pagamentos e NFS-e) fica de fora, e os documentos excluídos que esperam a recuperação também (D-667).
- **RN-18-073** — Gerada em segundo plano. Exportações grandes são divididas em partes de até **5 GB**. Ao terminar, o RH administrador recebe o aviso `exports.company_ready`, e o link vale **7 dias**. Pedir exige confirmação de senha ou passkey, e cada download gera evento de acesso **[P-18-22]**. As partes são volumes do 7-Zip (`.zip.001`, `.zip.002`...), e só quem pediu recebe o aviso, vê a senha e baixa (D-667).
- **RN-18-074** — No máximo **uma exportação completa por semana** por empresa, para não pesar no sistema. O encerramento não conta nesse limite **[P-18-23]**. A semana conta do pedido da última exportação que não falhou (D-667).
- **RN-18-075** — Os campos criptografados (D-086) saem **legíveis** na exportação, porque ela é a cópia da empresa. Por isso o ZIP é protegido com uma **senha gerada pelo sistema**, mostrada uma única vez a quem pediu ou, no encerramento, ao RH administrador no primeiro download (AES-256) **[P-18-24]**. A senha fica criptografada até quem pediu abrir a exportação pronta e é apagada depois de mostrada (D-667).

### 4.7 Fora do MVP (D-461, D-467)

- Layouts além de Domínio, Questor e Alterdata (por exemplo, TOTVS e Senior) e o AFD de outro REP: entram conforme os clientes do piloto, como conversores (RN-18-063).
- API pública e webhooks: roadmap.

## 5. Estados

**Importação:** `uploaded` → `validating` → `preview` → `importing` → `completed` | `completed_with_errors` | `failed` · `cancelled` (desistiu na prévia) · `undone`

**Linha:** `valid` | `invalid` | `unchanged` → `imported` | `failed`

**Exportação completa:** `queued` → `generating` → `ready` → `expired` | `failed`

## 6. Permissões

| Ação | Quem |
|---|---|
| Importações de implantação: estrutura, colaboradores e vínculos, dependentes, bancários, gestores, histórico salarial, acumulados, XMLs do eSocial | RH administrador, suporte (assistida) **[P-18-16]**, D-661 |
| Férias, banco de horas, admissões em lote, atualizações em massa | RH administrador (T), RH analista (U) |
| Lançamentos da folha, coparticipação e benefícios | RH administrador (T), RH analista com o módulo folha (U) |
| Desfazer importação | RH administrador |
| Autorizar importação assistida | RH administrador |
| Importação assistida | Superadmin, suporte |
| Exportação completa | RH administrador |

## 7. Modelo de dados

```
data_imports
  id, company_id, kind, status, file (Active Storage, apagado em 90 dias),
  original_filename, row_count, created_count, updated_count, unchanged_count,
  error_count, cutoff_date, options (jsonb: só válidas, mapa de colunas),
  created_by_id, assisted (bool), confirmed_at, undone_at, undone_by_id

data_import_rows
  id, data_import_id, line_number, status, payload, errors,   -- criptografados (D-086, D-661)
  record_type, record_id, action ('create'|'update'|'none'), version_id (PaperTrail)
  -- payload apagado junto com o arquivo, em 90 dias

import_column_maps                                   -- mapas salvos por fornecedor (P-18-13)
  id, company_id, kind, supplier_name, mapping (jsonb)

assisted_import_authorizations
  id, company_id, authorized_by_id, authorized_at, valid_until, revoked_at

company_exports
  id, company_id, kind ('full'; 'closing' e 'portability' com a spec 05), status,
  parts (Active Storage, 1..n), password (criptografada, apagada ao mostrar),
  password_shown_at, requested_by_id, started_at, ready_at, expires_at, failed_at,
  records_count, files_count, size_bytes                -- D-667
  -- subject_worker_profile_id entra com a portabilidade (spec 05)
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Imports::ValidateJob` | Ao enviar | Lê, normaliza e valida, gerando a prévia |
| `Imports::ApplyJob` | Ao confirmar | Grava em lotes e gera o resultado |
| `Imports::UndoJob` | Ao desfazer | Confere o uso e volta os registros |
| `Imports::PurgeJob` | Diário | Apaga arquivos e payloads com mais de 90 dias |
| `Exports::CompanyJob` | Sob demanda e no encerramento | Monta o ZIP por partes, com índice e hashes |
| `Exports::PurgeJob` | Diário | Apaga exportações vencidas |

- **Gems:** `roo` (leitura de XLSX), `caxlsx` (modelos e relatórios em XLSX), `rubyzip` (ZIP com senha AES) **[P-18-25]**. O `rubyzip` não grava AES, então o ZIP com senha é gerado pelo **7-Zip** instalado no container (D-514, spec 20).
- **Fila:** `imports`, com concorrência baixa, para não disputar com o ponto e a folha **[P-18-26]**.
- **Aviso novo** no catálogo da spec 15: `exports.company_ready` (obrigatório, sino e e-mail) e `imports.assisted_completed` (não obrigatório, sino e e-mail).

## 9. Critérios de aceite

- **CA-18-001** — Dada uma planilha com 300 linhas, 3 com CPF inválido, quando o RH envia, então a prévia mostra 297 válidas e 3 erros com linha, coluna e motivo, e nada foi gravado.
- **CA-18-002** — Dada a prévia do caso anterior, quando o RH escolhe "importar só as válidas", então 297 pessoas são criadas, e o relatório lista as 3 rejeitadas.
- **CA-18-003** — Dado um CPF que já existe, quando a planilha traz um celular novo e o e-mail vazio, então a prévia mostra a troca do celular, e o e-mail atual continua. São o telefone e o e-mail pessoais da ficha: os de login de quem já tem conta não mudam pela importação (D-602, D-663).
- **CA-18-004** — Dada uma importação de colaboradores, quando é confirmada, então nenhum convite e nenhum evento do eSocial são enviados.
- **CA-18-005** — Dado um RH analista da unidade Caxias, quando importa uma linha da unidade Bento Gonçalves, então ela vira erro "fora do seu escopo".
- **CA-18-006** — Dada uma planilha de comissões importada duas vezes na mesma competência aberta, quando a segunda é confirmada, então os lançamentos da primeira são substituídos, sem duplicar.
- **CA-18-007** — Dada a competência de outubro fechada, quando o RH importa lançamentos para outubro, então a importação é recusada.
- **CA-18-008** — Dado um reajuste de 5% para os operadores a partir de 01/05, quando o RH confirma, então cada vínculo ganha uma revisão de salário com vigência em 01/05 e motivo "reajuste coletivo".
- **CA-18-009** — Dada uma importação de colaboradores em que um vínculo já marcou ponto, quando o RH administrador tenta desfazer, então o sistema recusa e mostra o vínculo que impede.
- **CA-18-010** — Dado o suporte sem autorização válida da empresa, quando tenta uma importação assistida, então a área admin bloqueia.
- **CA-18-011** — Dada uma exportação completa pedida pelo RH administrador, quando fica pronta, então o ZIP tem `LEIAME.txt`, `indice.json` com os hashes, os dados em JSON e CSV e os arquivos, protegido pela senha mostrada uma vez.
- **CA-18-012** — Dada uma exportação completa feita há 3 dias, quando o RH administrador pede outra, então o sistema informa a data em que poderá pedir de novo.

## 10. Propostas aprovadas (D-469)

| # | Proposta |
|---|---|
| P-18-01 | Limite de 20 MB e 10.000 linhas por arquivo |
| P-18-02 | Leitura com `roo` e CSV, colunas reconhecidas pelo cabeçalho |
| P-18-03 | Normalização de máscaras, datas, decimais e acentos |
| P-18-04 | Prévia com contagens e arquivo de erros para corrigir |
| P-18-05 | Chave por tipo; atualiza sem apagar campos vazios |
| P-18-06 | Gravação em lotes com transação por linha |
| P-18-07 | Arquivo guardado por 90 dias; resultado sem dados no histórico |
| P-18-08 | Ordem e chaves dos 9 tipos de implantação |
| P-18-09 | Importação de colaboradores sem convite nem eSocial |
| P-18-10 | Saldos com data de corte |
| P-18-11 | XMLs do eSocial completados pela planilha, com escolha nos conflitos |
| P-18-12 | Lançamentos só na competência aberta; reimportar substitui |
| P-18-13 | Mapa de colunas salvo por fornecedor |
| P-18-14 | Atualizações em massa como revisões com vigência |
| P-18-15 | Atualização em massa também por tela, sem planilha |
| P-18-16 | Estrutura, histórico salarial, acumulados e XMLs só pelo RH administrador |
| P-18-17 | Lista do que impede desfazer |
| P-18-18 | Autorização da importação assistida com validade |
| P-18-19 | Conversores fora da aplicação, gerando a planilha modelo |
| P-18-20 | Formato do ZIP de exportação |
| P-18-21 | O que entra e o que não entra na exportação |
| P-18-22 | Partes de 5 GB, link de 7 dias, confirmação e eventos de acesso |
| P-18-23 | Uma exportação completa por semana |
| P-18-24 | ZIP protegido por senha AES-256 mostrada uma vez |
| P-18-25 | Gems `roo`, `caxlsx` e `rubyzip` |
| P-18-26 | Fila `imports` com concorrência baixa |
