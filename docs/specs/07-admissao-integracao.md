# 07 — Admissão e integração

> Status: aprovado · Última atualização: 2026-11-05
> Decisões: D-091, D-143, D-176, D-177, D-178, D-204, D-205, D-230 a D-241, D-250 a D-264, D-570, D-648 a D-651 ([decisoes.md](decisoes.md))
> Os itens **[P-07-01]** a **[P-07-18]** foram todos aprovados sem ajuste (D-264, seção 10). Os itens **[P-07-19]** e **[P-07-20]** (clientes de alocação, D-570) foram aprovados sem ajuste (D-572).

## 1. Objetivo

Acompanhar a entrada de uma pessoa na empresa, do cadastro inicial até o primeiro dia de trabalho:

- documentos conferidos com ajuda da IA;
- contrato gerado;
- eSocial enviado no prazo;
- contabilidade informada;
- integração dos primeiros dias organizada.

Funciona para todos os tipos de vínculo (CLT, estágio, autônomo, sócio, PJ), mudando o modelo de checklist e as regras de eSocial.

## 2. Etapas (D-250)

```
1 Cadastro inicial → 2 Envio de documentos → 3 Processamento pela IA → 4 Revisão do RH → 5 Contabilidade* → 6 Conclusão
                                   ↺ correção solicitada volta ao colaborador
* opcional por empresa (D-258)
```

| Etapa | Quem age | O que acontece |
|---|---|---|
| 1. Cadastro inicial | RH | Dados mínimos (D-254), escolha do modelo, liberação do convite (D-252) |
| 2. Envio de documentos | Colaborador | Envia documentos e preenche formulários pelo portal |
| 3. Processamento pela IA | Sistema | Classifica cada documento e extrai os campos (spec 14). Se falhar, a conferência é manual |
| 4. Revisão do RH | RH | Confere documentos e dados, pede correções, gera o contrato, confirma o eSocial (D-255) |
| 5. Contabilidade | RH e contabilidade | Encaminhamento com confirmação de recebimento (P-06-18) |
| 6. Conclusão | RH | Confirma a conclusão (D-260), e a integração começa |

- **RN-07-001** — Cada item do modelo de admissão pertence a uma etapa **[P-07-01]**.
- **RN-07-002** — As etapas **não bloqueiam** os itens. Quem bloqueia são as dependências (D-237). A etapa atual mostrada na barra é a primeira que ainda tem item obrigatório pendente. Na prática, as etapas 2, 3 e 4 andam juntas, documento a documento **[P-07-02]**.
- **RN-07-003** — Na empresa que não usa a etapa 5 (D-258), ela não aparece na barra, e itens de encaminhamento não entram no processo **[P-07-03]**. A etapa nasce desligada na empresa (D-648).
- **RN-07-004** — Até a spec 14, a etapa 3 aparece na barra sem itens e nunca é a etapa atual, e a conferência é manual (D-648).

## 3. Histórias de usuário

1. Como **RH**, quero cadastrar uma admissão só com os dados básicos e completar o resto depois.
2. Como **RH**, quero revisar o cadastro antes de mandar o convite ao novo colaborador.
3. Como **novo colaborador**, quero enviar meus documentos pelo celular e saber o que falta.
4. Como **RH**, quero ver os campos extraídos pela IA ao lado do cadastro, para conferir sem redigitar.
5. Como **RH**, quero gerar o contrato preenchido para imprimir e assinar.
6. Como **RH**, quero ser avisado se o S-2200 estiver perto do prazo sem estar pronto.
7. Como **contador**, quero receber os documentos da admissão e confirmar o recebimento.
8. Como **gestor**, quero ver as tarefas de integração que são minhas, como entregar EPI e apresentar a equipe.
9. Como **RH**, quero ser avisado antes do fim da experiência para decidir se prorrogo, efetivo ou desligo.
10. Como **gestor de um cliente da consultoria**, quero aprovar a admissão de quem vai trabalhar comigo e acompanhar em que etapa ela está (D-570).

## 4. Regras de negócio

### Início (D-251, D-254)

- **RN-07-010** — Formas de início:
  - **cadastro manual** pelo RH;
  - **a partir do recrutamento**: ao marcar o candidato como contratado, os dados e documentos dele vêm junto ([spec 21](21-recrutamento.md));
  - **importação em lote**: uma admissão por linha da planilha ([spec 18](18-importacao-exportacao.md)).
- **RN-07-011** — Campos obrigatórios para criar (D-254):
  - nome, CPF, e celular ou e-mail;
  - tipo de vínculo, cargo, unidade e departamento;
  - data prevista de início, que é hoje ou futura; quem já começou entra pelo "Novo colaborador" (D-648).

  Salário, jornada e os demais dados podem vir depois, até a revisão do RH. Quem opera a admissão completa o salário da primeira revisão do vínculo `pending`, mesmo sem o módulo `folha`, com a confirmação de senha e o evento de acesso (D-648).

  Na empresa que usa clientes de alocação (D-570), o cadastro inicial também tem o campo **cliente**, opcional ("sem cliente" para a equipe interna). Ele vai para a primeira revisão do vínculo **[P-07-19]**.
- **RN-07-012** — Ao criar a admissão, o sistema:
  1. reaproveita o usuário se o CPF já existe (P-02-08), ou cria um novo, ainda sem acesso;
  2. cria a membership `invited` (o convite ainda não sai);
  3. cria a ficha (`WorkerProfile`) se não existir;
  4. cria o vínculo `pending`, com a primeira revisão (cargo, unidade, departamento e, se houver, cliente);
  5. inicia o processo a partir do modelo (spec 06).
- **RN-07-013** — Escolha do modelo **[P-07-04]**, na ordem:
  1. o modelo de admissão do cargo (D-204);
  2. o modelo padrão da empresa para aquele **tipo de vínculo**: cada modelo de admissão lista os tipos de que é padrão, e cada tipo tem no máximo um modelo (D-648);
  3. o modelo padrão de admissão.

  O RH pode trocar o modelo antes de liberar o convite. O processo antigo fica `cancelled` com o motivo "modelo trocado", o histórico fica e os documentos continuam na pasta. Um item de documento cujo tipo já tem versão aprovada na pasta nasce resolvido, e o resto recomeça. A tela avisa antes de confirmar (D-648).
- **RN-07-014** — Um CPF que já tem vínculo `pending` ou `active` na empresa gera um alerta: "Esta pessoa já tem vínculo". A admissão continua permitida, porque vínculos simultâneos são aceitos (D-205) **[P-07-05]**.

### Convite (D-252)

- **RN-07-020** — O convite só sai quando o RH clica em "Liberar acesso", escolhendo os canais (D-177). Na importação em lote, há "Liberar acesso de todos" **[P-07-06]**.
- **RN-07-021** — Antes de liberar, o colaborador não tem acesso. O RH já pode trabalhar na admissão (enviar documentos em nome dele, preencher dados). O convite em massa da lista de colaboradores deixa de fora quem tem admissão aberta (D-648).
- **RN-07-022** — Até a aprovação da Twilio, os canais são e-mail e link com QR code (D-648).

### Documentos e formulários (etapas 2 a 4)

- **RN-07-030** — Os documentos seguem a [spec 08](08-documentos.md): envio, processamento pela IA (spec 14), revisão, pedido de correção com motivo visível ao colaborador, versões.
- **RN-07-031** — Formulários (dados pessoais, bancários, dependentes) gravam na ficha só depois de o RH aplicar (D-238). Quem opera a admissão revisa o grupo bancário do formulário de uma admissão aberta, mesmo sem o módulo `folha` (D-649).
- **RN-07-032** — Na revisão, o sistema mostra uma **lista do que falta para o eSocial**: campos obrigatórios do S-2200 ou S-2300 ainda vazios ou inválidos (validação na spec 13) **[P-07-07]**.

### Contrato e termos (D-253)

- **RN-07-040** — O RH administrador cadastra modelos de documento (contrato CLT, contrato de experiência, termo de compromisso de estágio, contrato PJ, termos diversos). Cada modelo vale para tipos de vínculo escolhidos.
- **RN-07-041** — O modelo é escrito num editor de texto simples (títulos, negrito, itálico, listas, tabelas simples), com **variáveis** como `{{colaborador.nome}}`, `{{cargo.nome}}`, `{{vinculo.salario}}`, `{{empresa.razao_social}}` e `{{unidade.endereco}}`. O PDF é gerado com Prawn (D-263) **[P-07-08]**. As variáveis são um catálogo fixo, e o modelo não aceita variável desconhecida nem caractere fora da fonte do PDF (D-650).
- **RN-07-042** — Ao gerar, o sistema avisa se alguma variável está vazia e não gera até que ela seja preenchida ou o RH confirme "gerar com campo em branco" **[P-07-09]**.
- **RN-07-043** — O PDF gerado fica no processo, fora da pasta. Abre para quem opera a admissão aberta, com a confirmação de senha e o evento de acesso, e gerar de novo substitui o PDF não assinado (D-650). Depois da assinatura no papel, o RH envia a versão assinada, que entra na pasta como documento do tipo "Contrato assinado" (spec 08). Um item do modelo pode exigir esse envio.

### eSocial (D-255)

- **RN-07-050** — O PJ (`contractor`) não vai ao eSocial. Os outros tipos geram S-2200 (CLT) ou S-2300 (estágio, autônomo, sócio), conforme a spec 13.
- **RN-07-051** — Quando a lista do que falta está vazia, o RH clica em "Enviar ao eSocial" e confirma. O evento entra na fila da spec 13, e o status aparece na admissão: `não enviado`, `enviado`, `aceito`, `rejeitado` (com o erro).
- **RN-07-052** — O prazo do evento é **o dia anterior à data de início**. A partir de 3 dias antes do prazo, se o evento não foi enviado, o RH recebe alertas diários **[P-07-10]**.
- **RN-07-053** — Se faltam dados no último dia útil antes do prazo, o sistema oferece o **registro preliminar (S-2190)**, que exige poucos dados, como CPF, nascimento e data de admissão. A lista exata fica na spec 13. Depois, o S-2200 completo segue o prazo da spec 13 (D-255).
- **RN-07-054** — Mudar a data de início depois do envio gera a retificação conforme a spec 13.

### ASO (D-259)

- **RN-07-060** — Para CLT, a conclusão exige um ASO admissional **apto** validado. O item de ASO é obrigatório e não pode ser dispensado no vínculo CLT **[P-07-11]**. Se o processo não tem item do tipo `aso_admission`, o sistema acrescenta um (D-648).
- **RN-07-061** — Se a IA ou o RH registra o ASO como **inapto**, a admissão mostra um alerta grave, e o RH escolhe entre **cancelar** (RN-07-090) e **reavaliar** (pede um novo ASO, e o inapto fica no histórico). Ao revisar o ASO, o RH escolhe apto ou inapto, com a data do exame, o que preenche `aso_status` (D-648). O ASO inapto continua válido na pasta, mas o item não resolve. Exame depois do início gera um aviso, sem bloquear (D-651).

### Contabilidade (D-258)

- **RN-07-070** — Na empresa que usa a etapa, o item de encaminhamento junta a ficha e os documentos validados, com dependência de todos os documentos obrigatórios (P-06-13). O RH encaminha ao escritório, e o contador confirma o recebimento (D-143), ou o RH registra o envio manual (P-06-18). O escritório lê a ficha sem dados de saúde e os documentos aprovados nos itens da admissão, sem a categoria Saúde, com a senha e o evento de acesso (D-651, D-652).

### Conclusão (D-260)

- **RN-07-080** — O botão "Concluir admissão" fica disponível quando:
  - todos os itens obrigatórios estão concluídos ou dispensados;
  - o ASO apto está validado (CLT);
  - o eSocial foi **enviado**, ou não se aplica;
  - o salário está preenchido (D-648).

  O aceite do eSocial não é exigido para concluir, mas a falta dele aparece no resumo **[P-07-12]**. Até a spec 13, a exigência de envio fica desligada (flag `esocial`), e o resumo diz que o envio é feito fora do sistema nesta fase (D-648).
- **RN-07-083** — Um item de aprovação reprovado trava a conclusão. A admissão mostra um alerta com a justificativa, e o RH cancela a admissão (RN-07-090), reabre o item ou o dispensa com motivo (D-648).
- **RN-07-081** — O RH confirma vendo um resumo: dados principais, documentos, contrato assinado, status do eSocial e status da contabilidade.
- **RN-07-082** — Ao concluir, começa o processo de **integração** indicado no modelo (P-06-04).

### Ativação do vínculo (D-256)

- **RN-07-085** — Um job diário ativa, na data de início, os vínculos `pending` daquele dia:
  - **com o eSocial aceito**, ou se não se aplica: ativa normalmente;
  - **sem o eSocial aceito**: ativa assim mesmo e cria um **alerta grave** para o RH, que fica no painel até o evento ser aceito;
  - **com a admissão ainda não concluída**: ativa assim mesmo, porque a pessoa já está trabalhando, e o alerta mostra os itens pendentes **[P-07-13]**.

  O job vale para datas até hoje, para cobrir um dia em que não rodou. Até a spec 13, o alerta por eSocial não aceito fica desligado (flag `esocial`) (D-648).
- **RN-07-086** — A partir da ativação, o colaborador aparece no ponto, na folha e nos painéis.

### Desistência e cancelamento (D-257)

- **RN-07-090** — O RH cancela a admissão informando o motivo:
  - candidato desistiu;
  - ASO inapto;
  - empresa desistiu;
  - outro motivo.
- **RN-07-091** — Ao cancelar:
  - o vínculo passa a `cancelled` e o processo a `cancelled`;
  - se o S-2200 ou S-2300 já tinha sido enviado, o sistema gera a exclusão (S-3000) na spec 13;
  - a membership é revogada, exceto se a pessoa tiver outros vínculos ou perfis na empresa;
  - dados e documentos ficam na retenção de candidato não contratado (6 meses, spec 05).
- **RN-07-092** — Não é possível cancelar depois da ativação do vínculo. A partir daí, a saída é por desligamento (spec 09) **[P-07-14]**. Até a ativação, a admissão concluída ainda pode ser cancelada (D-651).

### Contrato de experiência (D-261, D-262)

- **RN-07-100** — No vínculo CLT com contrato de experiência, o RH informa os dias do primeiro período e, se houver, da prorrogação. A soma não pode passar de **90 dias**, e só é permitida **uma prorrogação** (CLT art. 445, parágrafo único, e art. 451).
- **RN-07-101** — Antes do fim de cada período, o RH e os gestores recebem um aviso com antecedência configurável pela empresa, de 10 dias por padrão **[P-07-15]**. As ações são:
  - **prorrogar**, se ainda não houve prorrogação;
  - **efetivar**: o contrato segue por prazo indeterminado;
  - **desligar**: inicia o desligamento (spec 09). Até a spec 09, aparece desabilitado, com o motivo (D-648).
- **RN-07-102** — Se nada for registrado até o fim do período, o contrato passa a prazo indeterminado, que é o efeito legal. O sistema registra isso e avisa o RH. Exceção: com a prorrogação já informada, o fim do primeiro período passa o contrato a `extended` sozinho, com aviso ao RH, porque ela já consta do contrato (D-648, a conferir pelo especialista em DP).
- **RN-07-103** — A avaliação de experiência ([spec 22](22-avaliacao-desempenho.md)) abre junto com o aviso (D-540), e a recomendação do gestor aparece na tela da decisão, que continua manual (RN-22-012).

### Integração

- **RN-07-110** — A integração é um processo do tipo `onboarding` (spec 06). Os itens podem ser do colaborador (leitura e aceite, treinamentos), do gestor (boas-vindas, entrega de EPI) e do RH.
- **RN-07-111** — No portal, o colaborador vê o checklist de integração com o progresso ("Integração · 2 de 5"), como no protótipo.
- **RN-07-112** — A integração conclui sozinha quando todos os itens obrigatórios terminam **[P-07-16]**.

## 5. Estados

**Admissão (processo):** `open` → `completed` · `open` → `cancelled`

**Vínculo:** `pending` → `active` (job na data de início) · `pending` → `cancelled`

**Status do eSocial na admissão:** `not_applicable` · `not_sent` → `sent` → `accepted` | `rejected` → `sent`…

**Experiência:** `first_period` → `extended` → `indefinite` · ou → desligamento

## 6. Permissões

Spec 03, seção 4.4:

| Ação | Quem |
|---|---|
| Criar, liberar convite, revisar, gerar contrato, enviar eSocial, concluir, cancelar | RH administrador (T); RH analista (U, com o módulo `admissao`); consultor |
| Modelos de contrato e termos | RH administrador **[P-07-17]** |
| Itens próprios | Colaborador (portal), gestor (itens do papel `manager`), gestor do cliente (itens do papel `client_manager`) |
| Ver a etapa, o status e os itens próprios da admissão, sem documentos | Gestor do cliente, nos clientes dele (spec 03, seção 4.12) **[P-07-20]** |
| Confirmar recebimento | Contabilidade |

## 7. Modelo de dados

```
admissions                                             [P-07-18]
  id, company_id, employment_id, process_instance_id,
  source ('manual'|'recruitment'|'import'), source_ref,
  invite_released_at, invite_released_by_id,
  esocial_status, esocial_event_id (spec 13),
  aso_status ('missing'|'fit'|'unfit', criptografado, D-651), aso_exam_on,
  completed_at, completed_by_id, cancelled_at, cancel_reason, cancel_note (criptografados, D-651)

process_template_items + stage, process_items + stage  -- etapa do item (D-648)
  'registration'|'documents'|'hr_review'|'accounting'|'conclusion'

process_templates + default_employment_kinds (array)   -- padrão por tipo de vínculo (D-648)

position_required_document_types                       -- documentos exigidos pelo cargo (D-648)
  id, company_id, position_id, document_type_id

document_templates                                     -- contratos e termos (D-253)
  id, company_id, name, employment_kinds (array), body (texto com marcação simples
  e variáveis), status

generated_documents
  id, company_id, employment_id, document_template_id, status, file (S3),
  generated_by_id, generated_at, missing_variables (array),
  signed_document_id (spec 08, nullable)

employments.details (jsonb, spec 04) — para CLT com experiência:
  experience_first_days, experience_extension_days, experience_status,
  experience_ends_on

companies (configurações)
  uses_accounting_step (bool, D-258), experience_alert_days (int, padrão 10)
```

## 8. Jobs e integrações

| Job | Quando | O que faz |
|---|---|---|
| `Employments::ActivateStartingJob` | Diário, de madrugada, no fuso de cada unidade | Ativa os vínculos do dia e gera os alertas (RN-07-085) |
| `Admissions::EsocialDeadlineJob` | Diário | Alertas de prazo do S-2200 e oferta do S-2190 (RN-07-052, RN-07-053) |
| `Employments::ExperienceAlertsJob` | Diário | Avisos de fim de experiência e passagem automática para prazo indeterminado |
| `Documents::GenerateFromTemplateJob` | Sob demanda | Gera o PDF com Prawn |

## 9. Critérios de aceite

- **CA-07-001** — Dado o RH criando uma admissão só com nome, CPF, celular, tipo, cargo, unidade, departamento e data de início, quando salva, então a admissão é criada e o colaborador ainda não recebe convite.
- **CA-07-002** — Dado um cargo "Motorista" com modelo próprio e CNH exigida, quando o RH cria a admissão para esse cargo, então o processo usa o modelo do cargo e inclui o item de CNH.
- **CA-07-003** — Dado o RH clicando em "Liberar acesso" com WhatsApp e link impresso, quando confirma, então o convite sai pelos dois canais, com validade de 72 horas.
- **CA-07-004** — Dado um contrato com a variável `{{vinculo.salario}}` vazia, quando o RH gera o PDF, então o sistema avisa e só gera com a confirmação de "campo em branco".
- **CA-07-005** — Dado um início em 03/11 e o S-2200 não enviado em 30/10, quando o job roda, então o RH recebe o alerta de prazo.
- **CA-07-006** — Dado um vínculo CLT sem ASO apto, quando o RH tenta concluir, então o botão fica indisponível, com o motivo.
- **CA-07-007** — Dado um ASO registrado como inapto, quando o RH escolhe "cancelar", então o vínculo fica `cancelled`, o S-3000 é gerado (se o S-2200 foi enviado) e o acesso é revogado.
- **CA-07-008** — Dado um vínculo `pending` com início hoje e eSocial rejeitado, quando o job de ativação roda, então o vínculo fica `active` e o painel do RH mostra o alerta grave.
- **CA-07-009** — Dado um contrato de experiência de 45 dias sem prorrogação e alerta configurado para 10 dias, quando faltam 10 dias, então o RH e o gestor recebem o aviso com as opções prorrogar, efetivar e desligar.
- **CA-07-010** — Dado um contrato de experiência de 60 + 45 dias, quando o RH tenta salvar, então o sistema recusa por passar de 90 dias.
- **CA-07-011** — Dada uma empresa que não usa a etapa de contabilidade, quando uma admissão é criada, então a barra de progresso mostra 5 etapas.
- **CA-07-012** — Dada uma admissão concluída, quando o RH confirma, então o processo de integração começa e aparece no portal do colaborador.
- **CA-07-013** — Dada uma empresa que usa clientes de alocação, quando o RH cria uma admissão para o cliente X, então a primeira revisão do vínculo fica com o cliente X, e os gestores de X veem a admissão.
- **CA-07-014** — Dado um modelo com "Aprovação do gestor do cliente" e uma admissão "sem cliente", quando o processo começa, então o item vai para o RH, com alerta (RN-06-022).

## 10. Propostas aprovadas (D-264)

| # | Proposta |
|---|---|
| P-07-01 | Cada item do modelo de admissão pertence a uma etapa |
| P-07-02 | Etapas não bloqueiam itens; a etapa atual é a primeira com item obrigatório pendente |
| P-07-03 | Sem a etapa de contabilidade, ela some da barra e os encaminhamentos não entram |
| P-07-04 | Ordem de escolha do modelo: cargo → padrão por tipo de vínculo → padrão de admissão |
| P-07-05 | Alerta, sem bloqueio, quando o CPF já tem vínculo na empresa |
| P-07-06 | "Liberar acesso de todos" na importação em lote |
| P-07-07 | Lista do que falta para o eSocial na revisão |
| P-07-08 | Modelos de documento num editor simples, com variáveis, em PDF pelo Prawn |
| P-07-09 | Aviso de variável vazia antes de gerar o PDF |
| P-07-10 | Alertas diários a partir de 3 dias antes do prazo do eSocial |
| P-07-11 | ASO obrigatório e não dispensável no vínculo CLT |
| P-07-12 | Concluir exige o eSocial enviado, não aceito |
| P-07-13 | Vínculo ativa na data de início mesmo com a admissão não concluída, com alerta |
| P-07-14 | Não é possível cancelar depois da ativação; a saída é por desligamento |
| P-07-15 | Aviso da experiência com 10 dias de padrão |
| P-07-16 | A integração conclui sozinha |
| P-07-17 | Só o RH administrador cadastra modelos de contrato e termos |
| P-07-18 | Entidade `Admission` ligando vínculo, processo, eSocial e ASO |

### Propostas aprovadas (D-572), clientes de alocação

| # | Proposta |
|---|---|
| P-07-19 | Cliente opcional no cadastro inicial, gravado na primeira revisão do vínculo |
| P-07-20 | O gestor do cliente vê a etapa, o status e os itens dele na admissão, sem documentos |

## 11. Em aberto

- **Prazo do S-2200 completo depois do S-2190** e regras de retificação: na spec 13.
