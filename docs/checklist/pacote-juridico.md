# CatalystHR — Pontos para validação jurídica

> Data: 2026-10-13 · Áreas: trabalhista, LGPD e contratos

## Sobre o produto

O CatalystHR é uma plataforma de RH na nuvem, vendida de duas formas:

- **por parceiros:** consultorias e escritórios de RH revendem com a marca deles (white label) para as empresas clientes;
- **diretamente a empresas.**

O CatalystHR é um produto da **DevBatista**. A plataforma cobre admissão digital, guarda de documentos, solicitações (férias, atestados, desligamento), ponto eletrônico (REP-P, Portaria MTP 671/2021), folha de pagamento com envio ao eSocial, um assistente com inteligência artificial, recrutamento e avaliação de desempenho. Os colaboradores usam um portal no celular.

Papéis definidos na LGPD:

| Contratação | Controladora | Operador | Suboperador |
|---|---|---|---|
| Por parceiro | Empresa cliente | Parceiro | CatalystHR |
| Direta | Empresa | CatalystHR | — |

## Como responder

Para cada item, precisamos de:

- **resposta** (pode, não pode, ou pode com condições);
- **fundamento**;
- **risco** de manter a proposta atual;
- **ajuste recomendado**, se houver.

Os códigos entre parênteses (D-xxx, RN-xx-xxx) são referências internas, só para rastreio.

**Prioridade:**
- **Alta:** precisamos da resposta antes do primeiro cliente.
- **Média:** antes do módulo de ponto.
- **Baixa:** antes do recrutamento e da avaliação.

---

## 1. LGPD — prioridade alta

- [ ] **1.1 Prazos de retenção por categoria de dado.** Proposta técnica (D-217): ao fim do prazo, os dados são anonimizados ou excluídos. A contagem começa no desligamento do último vínculo da pessoa na empresa, ou no fim do processo seletivo para candidatos. O RH pode suspender a exclusão de uma pessoa com processo judicial, informando o número do processo. Confirmar os prazos e a base legal de cada categoria:

  | Categoria | Prazo proposto |
  |---|---|
  | Ficha de registro e dados do vínculo | Indeterminado |
  | Folha, holerites, recibos | 10 anos |
  | FGTS | 5 anos |
  | Ponto (marcações, AFD, AEJ, espelhos, comprovantes) e selfies das marcações | 5 anos |
  | ASO e saúde ocupacional | 20 anos |
  | Atestados, documentos pessoais, dados bancários, dependentes, solicitações, avaliações | 5 anos |
  | Contato de emergência | Excluído no desligamento |
  | Candidatos não contratados | 6 meses; 12 meses, renováveis, no banco de talentos com consentimento |
  | Eventos do eSocial | 10 anos |
  | Conversas com o assistente de IA | 1 ano |
  | Trilha de auditoria e registros de acesso | 5 anos |

- [ ] **1.2 Backups.** Os dados excluídos continuam nos backups até eles expirarem, num ciclo de 35 dias (D-223). Isso é suficiente, se informado na política de privacidade?
- [ ] **1.3 Contrato de tratamento de dados.** Revisar a minuta em `juridico/contrato-tratamento-dados.md`, que serve para o parceiro e para a empresa direta, e validar os papéis da tabela acima.
- [ ] **1.4 Transferência internacional (LGPD, art. 33).** A aplicação e o banco ficam nos EUA (Railway, Virgínia). Também ficam nos EUA a ferramenta de monitoramento de erros (Sentry, sem dados pessoais), a IA (Anthropic e Voyage AI, com retenção zero; mesmo assim, a Anthropic pode guardar por até 2 anos o conteúdo marcado pelos sistemas de segurança dela ou exigido por lei) e o envio de WhatsApp e SMS (Twilio). Os arquivos e os backups ficam na AWS, em São Paulo. A proposta é usar as cláusulas-padrão contratuais da ANPD (D-500). Validar e indicar como incluir isso nos contratos.
- [ ] **1.5 Lista de suboperadores** a informar: AWS, Railway, Anthropic, Voyage AI, Twilio, Mercado Pago, Asaas, Sentry e Cloudflare.
- [ ] **1.6 Termos de uso e política de privacidade.** Revisar as minutas em `juridico/termos-de-uso.md` e `juridico/politica-de-privacidade.md`. Elas seguem um modelo em camadas, que também precisa ser validado:
  - os termos de uso são da DevBatista, fornecedora do CatalystHR, e exibem o nome comercial da marca;
  - a política de privacidade é da empresa controladora, montada a partir do nosso modelo, e cita o parceiro e a DevBatista como operadores.

  O usuário aceita os dois no primeiro acesso, com o registro da versão, da data e do IP (D-182).
- [ ] **1.7 Encarregado de dados.** Cada empresa cadastra o encarregado dela, que aparece no portal (D-224). O CatalystHR precisa de um encarregado próprio, como operador?
- [ ] **1.8 Incidentes de segurança.** A plataforma registra o incidente, avisa a controladora (o parceiro e o RH da empresa), entrega um relatório, e a controladora comunica a ANPD e os titulares (D-225, D-226). Validar o fluxo e os prazos.
- [ ] **1.9 Encerramento de contrato.** A empresa recebe a exportação completa dos dados, fica 90 dias só com leitura, e depois tudo é excluído (D-222). Os dados que a lei manda guardar passam a ser responsabilidade da empresa. Isso está adequado?
- [ ] **1.10 Pedidos dos titulares.** O colaborador faz o pedido pelo portal (acesso, correção, portabilidade, eliminação) e a empresa responde em até 15 dias (D-087). Confirmar o prazo.

## 2. Inteligência artificial — prioridade alta

- [ ] **2.1 Documentos pessoais e de saúde enviados à IA.** A IA lê RG, CNH, comprovantes, ASO e atestados (inclusive o CID) para preencher o cadastro. Há retenção zero no fornecedor, e uma pessoa sempre confere antes de usar (D-100, D-380). Qual é a base legal, e que transparência é necessária no aviso ao colaborador?
- [ ] **2.2 A empresa pode desligar a IA.** Cada função de IA pode ser desligada pela empresa (D-389). Isso deve constar no contrato?

## 3. Atos trabalhistas por meio eletrônico — prioridade alta

- [ ] **3.1 Ciência eletrônica.** O colaborador confirma "Li e estou ciente" no portal, com data, hora, IP e o hash do documento (D-279). O texto diz que é confirmação de **recebimento**, e não concordância nem assinatura. Usos: aviso de férias, advertências, comunicados, resultado de avaliação. Isso vale como prova de entrega?
- [ ] **3.2 Recusa de ciência.** Sem ciência no prazo, o RH registra "ciência recusada", com observação e até duas testemunhas (nome e CPF), como se faz no papel. Isso tem validade?
- [ ] **3.3 Pedido de demissão pelo portal.** O colaborador pede demissão no portal. O sistema gera a carta com os dados informados, e ele dá ciência eletrônica, sem assinatura (RN-09-080; a assinatura digital está fora do MVP, D-147). Isso tem validade, ou é preciso assinar também no papel?
- [ ] **3.4 Contratos.** Os contratos de trabalho e de estágio são gerados por modelo e assinados no papel, e a versão assinada é anexada (D-147). Há alguma ressalva?
- [ ] **3.5 Contribuição sindical.** A autorização prévia e expressa do colaborador (CLT, art. 578) é registrada como um documento com ciência eletrônica (RN-12-055). Isso é suficiente?
- [ ] **3.6 Avisos fora do expediente.** WhatsApp e notificações não são enviados das 20h às 8h, nos fins de semana e nos feriados, ou fora do turno de quem tem escala (D-402, D-403). Os avisos de segurança saem a qualquer hora. Isso basta para evitar questionamentos sobre o direito à desconexão?
- [ ] **3.7 Convite por WhatsApp antes do primeiro acesso.** A empresa declara que obteve a autorização do colaborador (por exemplo, na ficha de admissão), e só então o convite sai por WhatsApp (RN-02-016). Isso é suficiente para a LGPD e para as regras da Meta?

## 4. Ponto eletrônico (REP-P) — prioridade média

- [ ] **4.1 CatalystHR como fabricante.** A proposta é o CatalystHR registrar o programa no INPI e emitir o atestado técnico e o termo de responsabilidade (D-310). Confirmar:
  - as exigências da Portaria 671;
  - quem assina;
  - se o parceiro que revende com a própria marca precisa constar em algum documento ou na identificação do REP-P.
- [ ] **4.2 Assinatura dos comprovantes e do AFD.** A proposta é assinar com o certificado digital A1 **de cada empregador** (D-319), guardado criptografado na plataforma. Isso atende à Portaria, ou a assinatura deve ser do fabricante?
- [ ] **4.3 Bloqueio por localização.** A empresa pode configurar uma cerca virtual por unidade. Fora dela, a marcação é **sinalizada** ou **bloqueada** (D-062). A Portaria proíbe restringir a marcação. O modo "bloquear" é permitido? Hoje ele aparece com um aviso, e cada tentativa bloqueada fica registrada (RN-10-022).
- [ ] **4.4 Marcação só online.** Não há marcação sem internet (D-064). Isso é compatível com a obrigação de permitir a marcação?
- [ ] **4.5 Selfie e localização.** A localização é registrada em cada marcação. A selfie só é tirada de quem consentiu, e quem recusa marca só com a localização (D-321, D-323). Qual é a base legal da localização, e que aviso é necessário? A retenção da selfie por 5 anos está adequada?
- [ ] **4.6 Layouts oficiais.** Confirmar a versão vigente dos anexos da Portaria 671 para o AFD, o AEJ e o comprovante.

## 5. Recrutamento e avaliação — prioridade baixa

- [ ] **5.1 IA no recrutamento.** A IA lê o currículo, faz um resumo e indica, para cada requisito da vaga, se o currículo mostra ou não a experiência, citando o trecho. Ela **não dá nota, não ordena e não reprova** ninguém (D-522, D-523). O candidato pode pedir revisão humana (art. 20). Isso está adequado?
- [ ] **5.2 Dados de diversidade de candidatos.** A autodeclaração de gênero, raça e PcD é opcional, fica separada da avaliação e só aparece de forma agregada. A exceção são as vagas afirmativas PcD, em que o RH vê a condição (D-529). Validar.
- [ ] **5.3 Banco de talentos.** O consentimento vale por 12 meses, com pedido de renovação. Sem consentimento, os dados ficam 6 meses (D-526). Validar.
- [ ] **5.4 Aviso de privacidade do recrutamento.** Revisar a minuta em `juridico/aviso-privacidade-recrutamento.md`. A inscrição não pede CPF.
- [ ] **5.5 Avaliação anônima.** Avaliações de colegas e da equipe sobre o gestor são anônimas, só aparecem agregadas e só com pelo menos 3 respostas (D-544, D-545). Há algum risco?

## 6. Contratos comerciais — prioridade alta

- [ ] **6.1 Inadimplência do parceiro.** Com 15 dias de atraso, o parceiro e todas as empresas dele ficam só em leitura, mas o ponto e o envio ao eSocial dos eventos já gerados continuam. Com 30 dias, o contrato é encerrado (D-116, D-493, D-494). As empresas clientes são afetadas pela dívida do parceiro. Que cláusulas protegem a plataforma e informam a empresa cliente?
- [ ] **6.2 Teste grátis.** São 14 dias, sem ponto e sem eSocial. Sem contratação, a conta fica 30 dias em leitura, com exportação, e depois é excluída (D-485 a D-487). Validar.
- [ ] **6.3 Cancelamento.** Vale no fim do período pago, sem multa (D-489). Validar.

---

## Contato

Responsável pelo CatalystHR: _preencher_ · Prazo desejado para as respostas de prioridade alta: _preencher_
