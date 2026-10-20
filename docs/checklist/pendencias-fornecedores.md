# Pendências com fornecedores (checklist)

> Última atualização: 2026-10-14
> Para uso interno da equipe CatalystHR. Cada item informa o que pedir ou fazer, por que, que fase ele trava (`plano-de-fases.md`) e a referência.

## Mercado Pago — trava a fase 1

- [ ] Confirmar a habilitação da conta para **pagamentos automáticos com cartão salvo, sem pedir o CVV** (cobranças iniciadas pelo vendedor, de valor variável) (D-496)
  - A documentação chama a solução de **Pagamentos Automáticos** e exige *"a autorização da equipe Comercial"* ([pré-requisitos](https://www.mercadopago.com.br/developers/pt/docs/automatic-payments/prerequisites)). Ela não confirma o valor variável
  - 2026-10-14: chamado aberto pelo suporte ao desenvolvimento, encaminhado a atendimento humano e ao comercial, na conta da DevBatista (produção e credenciais de teste). Pedidos: habilitar `card_on_file` sem CVV, confirmar o valor diferente a cada mês, tarifas e Pix Automático
  - O primeiro atendimento sugeriu as Assinaturas (preapproval), recusadas: valor fixo, novas tentativas próprias e cancelamento automático depois de 3 recusas, contra a D-496, a D-497 e a RN-19-042
  - 2026-10-14, resposta ao chamado WCS-54705: o suporte técnico não habilita os Pagamentos Automáticos nem encaminhou ao comercial. Disse que o valor de uma assinatura não muda, o que contradiz a documentação do `PUT /preapproval/{id}`. Sem API pública de Pix Automático. O link "Contato comercial" do site (`/quero-usar/`) redireciona para o blog. Respondido no chamado pedindo o canal do comercial
  - Se o comercial não liberar: avaliar outro fornecedor para o cartão (começando pelo Asaas), as Assinaturas do Mercado Pago (revisa a D-496 e a D-497) ou o cartão pago a cada fatura. Decisão do responsável
  - Tarifas atuais da conta no Checkout, informadas pelo suporte (não valem necessariamente para os Pagamentos Automáticos): crédito com recebimento na hora 4,98%, em 14 dias 4,49%, em 30 dias 3,98%
- [ ] Confirmar a cobrança por PIX pela API de pagamentos, com QR e vencimento (D-481). A conta já recebe PIX e cartão; falta conferir o vencimento na integração
- [ ] Configurar os webhooks e a assinatura de validação
- [x] Para uma fase seguinte, perguntar sobre a disponibilidade do **Pix Automático** pela API. Resposta em 2026-10-14: não há API pública nem previsão informada pelo suporte

## Asaas e contador da CatalystHR (Contabilizei) — trava a fase 1

- [x] **Contador:** respostas recebidas em 2026-10-14 (D-560 a D-562). Falta registrar como decisão, depois dos pontos abaixo:
  - serviço: item **01.05** da LC 116, código municipal **02798** (São Paulo); CNAE 6202-3/00, que atende segundo o contador
  - ISS: empresa no **Simples Nacional**, ISS recolhido no DAS, alíquota efetiva atual de **2,01%**, devido em São Paulo para qualquer cliente
  - retenções: **nenhuma** (federais não se aplicam ao Simples; ISS não retido no item 01.05)
  - emissão depois da confirmação do pagamento é aceita, **desde que a competência esteja certa**
  - valor: o total cobrado, com os descontos; tarifas do Mercado Pago não são deduzidas; faturas zeradas ficam sem nota
  - sistema: **NFS-e Paulistana**; o Asaas emite com o **e-CNPJ** da DevBatista, que já existe
  - descrição: "Licenciamento de software CatalystHR por assinatura - Competência MM/AAAA" e a menção de optante pelo Simples Nacional
  - cancelamento: até 6 meses, desde que o DAS da competência não tenha sido pago
  - reforma tributária: nada muda em 2026 para o Simples
  - o CatalystOps pode ser faturado pelo mesmo CNPJ, com o produto identificado na descrição
  - rotina da Contabilizei: notas e extratos conferidos na plataforma deles até o dia 5 do mês seguinte, como já é feito hoje
- [ ] **Contador (com um especialista):** qual competência usar numa fatura que junta a mensalidade do ciclo que começa e o excedente do ciclo anterior, com ciclo que não começa no dia 1 (RN-19-040). Pode mudar a regra de uma nota por fatura (RN-19-100)
- [ ] **Contador (com um especialista):** se a alíquota efetiva do Simples, que muda todo mês, precisa aparecer na nota, e quem informa o valor de cada mês
- [ ] **Contador (com um especialista):** confirmar que o código 02798 está habilitado no CCM da empresa
- [ ] **Asaas:** abrir a conta da DevBatista e configurar a emissão na NFS-e Paulistana com o e-CNPJ (`fiscalInfo/municipalOptions`). O certificado vence todo ano: renovar antes, ou as notas param
- [ ] **Asaas:** confirmar o preço por nota (a página cita R$ 0,49, a confirmar)
- [ ] **Asaas:** criar a chave de API e configurar o webhook de notas
- [ ] **Asaas:** desligar o envio de e-mail das notas pelo Asaas (D-564)

## AWS — trava a fase 1 (conta `catalysthr`, D-574)

- [x] Pedir a saída do **sandbox do SES** em São Paulo (sa-east-1). Sem isso, só é possível mandar e-mail para endereços verificados. Enviado em 2026-10-14, em análise
- [x] Verificar o domínio `catalysthr.com.br` no SES (DKIM, SPF, DMARC) (2026-10-14)
- [ ] Resposta da AWS ao pedido de saída do sandbox
- [ ] Na fase 1: chaves do KMS dos arquivos e dos backups, com rotação anual, e usuários IAM por finalidade (P-20-21, P-20-22). A chave do A1 fica para a fase 3

## WhatsApp pela Twilio — trava a fase 2 (convites por WhatsApp já na fase 1)

> O WhatsApp é enviado pela Twilio (D-034). Mesmo assim, a Meta exige que cada empresa tenha um Gerenciador de Negócios verificado e uma conta do WhatsApp Business (WABA) ligada à Twilio, e aprova cada modelo de mensagem. A Twilio cuida da parte técnica (cadastro do remetente e envio dos modelos). A verificação da empresa é feita por nós, no painel da Meta, e costuma demorar.

- [x] Portfólio empresarial da Meta (antigo Gerenciador de Negócios) da DevBatista, com a empresa **verificada**: DEVBATISTA DESENVOLVIMENTO DE SISTEMAS E SERVICOS LTDA, verificada em 2026-05-18 (conferido em 2026-10-14)
- [ ] Exigir a autenticação de dois fatores de todos no portfólio (estava em "Ninguém"). Conferir depois se o Instagram `@_devbatista`, que entra no portfólio como um usuário de acesso total, continua funcionando
- [ ] Antes de registrar o número, incluir o CatalystHR nos produtos de `https://www.devbatista.com`, para o nome de exibição "CatalystHR" ser aprovado
- [ ] Escolher o número da plataforma: chip dedicado (+55, em plano que não seja cancelado por falta de recarga) ou número da Twilio (conferir se há +55, documentos e preço). O número não pode estar em uso no app do WhatsApp
- [ ] Conectar a WABA à conta da Twilio (Self Sign-up)
- [ ] Registrar o número da plataforma como remetente pela Twilio (Senders API) e confirmar o código da Meta
- [ ] Enviar os modelos de mensagem pela Content API da Twilio (categorias utilidade e autenticação) e acompanhar a aprovação (P-15-18)
- [ ] Para parceiros com número próprio (D-161): ver se é preciso entrar no programa Tech Provider da Twilio
- [ ] Configurar o SMS para o plantão (D-512)

## Anthropic — trava a fase 2 (pedir na metade da fase 1)

> Fatos de [API and data retention](https://platform.claude.com/docs/en/manage-claude/api-and-data-retention), conferidos em 2026-10-14: a retenção zero é pedida ao [comercial](https://claude.com/contact-sales) e ligada por organização. Cobre a Messages API e a contagem de tokens com os recursos elegíveis: PDF e imagem no corpo da requisição, citações, cache de prompt e saídas estruturadas (estas com ressalva: só o esquema JSON fica guardado por até 24 horas). Não cobre a Batch API nem a Files API (D-385). O Claude Sonnet 5.5 (RN-14-002) é compatível; os modelos Fable 5 e 5.1 não funcionam com retenção zero. Mesmo com ela, a Anthropic pode guardar por até 2 anos o conteúdo marcado pelos sistemas de segurança ou exigido por lei. Vale também para o Claude Code quando ele usa uma chave da organização; não vale para contas pessoais do Claude.

> Conferido em 2026-10-20 ([conta Claude e conta do Console](https://support.claude.com/en/articles/8987223-can-i-have-a-claude-account-and-a-console-account), [créditos da API](https://support.claude.com/en/articles/8977456-how-do-i-pay-for-my-claude-api-usage)):
> - a organização do Console é uma conta separada dos planos do Claude.ai (Free, Pro, Max), mesmo com o mesmo e-mail;
> - os planos de consumidor do Claude.ai não têm retenção zero, nem o playground do Console;
> - a API só funciona com créditos pré-pagos, que não são reembolsáveis e vencem em 1 ano;
> - a documentação não cita custo para criar a organização nem gasto mínimo para a retenção zero.

- [x] **Anthropic:** criar a organização **DevBatista** no Console, com `rafael@devbatista.com` como dona. Não usar a API com dados reais antes da retenção zero ativa (criada em 2026-10-20, sem créditos, com o workspace Default e o limite inicial de US$ 500 por mês)
- [x] **Anthropic:** pedir a **retenção zero** ao comercial (D-380). Enviado em 2026-10-20 pelo formulário de Contact sales, na opção "Zero data retention", com o ID da organização, o caso de uso e as perguntas sobre contrato, gasto mínimo e DPA; sem número de protocolo na confirmação. Pedido original:, com o texto preparado em 2026-10-14: uso só da Messages API com o Sonnet 5.5, sem Batch, Files, execução de código, conector MCP ou Managed Agents. Perguntar se exige contrato ou consumo mínimo e qual DPA se aplica (com a transferência internacional). Não aceitar custo antes de avaliar
- [ ] **Anthropic:** confirmar por escrito que a retenção zero está ativa e cobre os recursos usados

## Voyage AI — trava a fase 5

> Fatos do [FAQ](https://docs.voyageai.com/docs/faq) e dos [Termos](https://www.voyageai.com/tos), conferidos em 2026-10-14: a retenção zero é um opt-out no painel, que exige cartão cadastrado e administrador da organização. O conteúdo enviado depois do opt-out é apagado logo após o processamento. **O opt-out não vale para o passado**, e não dá para desfazer pelo painel. A Voyage é da MongoDB: se o cadastro levar ao MongoDB Atlas, a configuração fica nas configurações da organização do Atlas.

- [ ] **Voyage AI:** criar a conta da organização DevBatista, cadastrar o cartão e fazer o opt-out **antes de gerar a chave ou fazer qualquer chamada** (D-380)

## Railway — antes do primeiro cliente

- [ ] Ler no Trust Center o relatório SOC 2 e confirmar a **criptografia em repouso** do banco e dos volumes
- [ ] Confirmar o plano que permite PITR, réplicas e os tamanhos da spec 20
- [x] Configurar o domínio wildcard e acompanhar a emissão do certificado (2026-10-14)
- [ ] Plano Hobby: só 2 domínios próprios por serviço, já usados por `*.painel` e `admin` (D-573)

## Sentry e Cloudflare — fase 0

- [x] **Sentry:** plano gratuito (Developer), na região dos EUA (P-20-03). Rever o plano quando precisar de mais monitores
- [x] **Cloudflare:** DNS de `catalysthr.com.br`, sem proxy (D-503)

## Bancos dos clientes do piloto — trava a fase 4

- [ ] Validar o **layout do CSV da lista de pagamentos** com os bancos que o piloto usa (RN-12-071)

## INPI — trava a fase 3

- [ ] Registrar o programa de ponto no INPI, depois da orientação do jurídico (`pacote-juridico.md`, item 4.1)
