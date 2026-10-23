# Pendências com fornecedores (checklist)

> Última atualização: 2026-10-22
> Para uso interno da equipe CatalystHR. Cada item informa o que pedir ou fazer, por que, que fase ele trava (`plano-de-fases.md`) e a referência.

## Mercado Pago — trava a fase 1

- [ ] Confirmar a habilitação da conta para **pagamentos automáticos com cartão salvo, sem pedir o CVV** (cobranças iniciadas pelo vendedor, de valor variável) (D-496)
  - A documentação chama a solução de **Pagamentos Automáticos** e exige *"a autorização da equipe Comercial"* ([pré-requisitos](https://www.mercadopago.com.br/developers/pt/docs/automatic-payments/prerequisites)). Ela não confirma o valor variável
  - 2026-10-14: chamado aberto pelo suporte ao desenvolvimento, encaminhado a atendimento humano e ao comercial, na conta da DevBatista (produção e credenciais de teste). Pedidos: habilitar `card_on_file` sem CVV, confirmar o valor diferente a cada mês, tarifas e Pix Automático
  - O primeiro atendimento sugeriu as Assinaturas (preapproval), recusadas: valor fixo, novas tentativas próprias e cancelamento automático depois de 3 recusas, contra a D-496, a D-497 e a RN-19-042
  - 2026-10-14, resposta ao chamado WCS-54705: o suporte técnico não habilita os Pagamentos Automáticos nem encaminhou ao comercial. Disse que o valor de uma assinatura não muda, o que contradiz a documentação do `PUT /preapproval/{id}`. Sem API pública de Pix Automático. O link "Contato comercial" do site (`/quero-usar/`) redireciona para o blog. Respondido no chamado pedindo o canal do comercial
  - 2026-10-15, resposta ao chamado WCS-54705: a habilitação passa por análise comercial, pedida pelo formulário `/quero-usar/`. Chamado fechado com a resolução "Not supported". Em 2026-10-22 o link ainda redireciona para o blog
  - 2026-10-22, chat de atendimento (caso 490500571): os atendentes Misael e Lorena receberam o pedido, com o valor variável, a tarifa e o prazo da análise. Primeiro a Lorena indicou o portal de desenvolvedores, depois responder no WCS-54705 pedindo o encaminhamento ao comercial. Por fim, encaminhou o caso à equipe especializada para abrir um chamado novo, com contato **por e-mail**. Aguardando esse e-mail
  - 2026-10-22, chamado **WCS-55670** aberto pelo assistente do portal de desenvolvedores, com status "Pendente". Pede o encaminhamento ao comercial, e não ao suporte técnico, e o vínculo ao caso 490500571 e ao WCS-54705. Repete o valor variável, a recusa das Assinaturas, produção e teste, a tarifa e o prazo da análise. Nenhum prazo de retorno foi informado
  - 2026-10-22, resposta ao WCS-55670: o fluxo depende de habilitação comercial específica, que não pode ser ativada nem pedida pelo suporte técnico. Não há habilitação ativa na conta. Tarifa, prazo e liberação não são tratados por esse canal. O suporte diz agora que o `/quero-usar/` não é uma referência válida, o que contradiz a resposta ao WCS-54705. Nenhum canal comercial foi indicado
  - 2026-10-22, outra resposta do Mercado Pago, que considera o WCS-54705 e o WCS-55670 (o canal não foi registrado; deve ser o retorno do caso 490500571): a API de Orders aceita pagamentos automáticos e cartão salvo quando o recurso está disponível para o país, a conta e o meio de pagamento. A habilitação depende de análise comercial. O atendimento **não confirmou** que um pedido comercial foi aberto, não achou um consultor e **não tem um canal comercial válido** para indicar. O valor variável, a tarifa e o prazo só seriam confirmados depois da aprovação comercial. Reconheceu que o `/quero-usar/` cai no blog. Falta tentar o SAC por telefone
  - 2026-10-23, nova resposta ao WCS-55670: o modelo (cartão salvo, valor variável, sem CVV) só existe para **contas acompanhadas por um assessor comercial**. O pedido vai pelo [formulário de contato do Checkout](https://www.mercadopago.com.br/landing/ferramentas-para-vender/check-out/form), descrevendo as cobranças variáveis com cartão salvo. O comercial avalia a elegibilidade e as condições. Enviar o formulário não habilita nada
  - Canais: chamados do portal de desenvolvedores em [Central de chamados](https://www.mercadopago.com.br/developers/pt/support/center/tickets?status=all#from=/mp_wcs/list_all_tickets); chat pela conta logada, em "Contato" e depois "Inicie um chat"; SAC por telefone com o código gerado na conta ([canais](https://www.mercadopago.com.br/sac-pin/public-info))
  - O CatalystHR ainda não tem site público. Se o comercial exigir um, perguntar o que aceitam no lugar
  - Se o comercial não liberar: avaliar outro fornecedor para o cartão (começando pelo Asaas), as Assinaturas do Mercado Pago (revisa a D-496 e a D-497) ou o cartão pago a cada fatura. Decisão do responsável
  - Tarifas atuais da conta no Checkout, informadas pelo suporte (não valem necessariamente para os Pagamentos Automáticos): crédito com recebimento na hora 4,98%, em 14 dias 4,49%, em 30 dias 3,98%
- [ ] Confirmar a cobrança por PIX pela API de pagamentos, com QR e vencimento (D-481). A conta já recebe PIX e cartão; falta conferir o vencimento na integração. Documentação conferida em 2026-10-20: o vencimento vai de 30 minutos a 30 dias, e a API de Orders é a recomendada para integrações novas ([`mercado-pago-pix-19e.md`](mercado-pago-pix-19e.md))
- [ ] Configurar os webhooks e a assinatura de validação
- [x] Para uma fase seguinte, perguntar sobre a disponibilidade do **Pix Automático** pela API. Resposta em 2026-10-14: não há API pública nem previsão informada pelo suporte

## Asaas e contador da DevBatista (Contabilizei) — trava a fase 1

- [x] **Contador:** respostas recebidas em 2026-10-14 (D-560 a D-562). Falta registrar como decisão, depois dos pontos abaixo:
  - serviço: item **01.05** da LC 116, código municipal **02798** (São Paulo); CNAE 6202-3/00, que atende segundo o contador
  - ISS: empresa no **Simples Nacional**, ISS recolhido no DAS, alíquota efetiva atual de **2,01%**, devido em São Paulo para qualquer cliente
  - retenções: **nenhuma** (federais não se aplicam ao Simples; ISS não retido no item 01.05)
  - emissão depois da confirmação do pagamento é aceita, **desde que a competência esteja certa**
  - valor: o total cobrado, com os descontos; tarifas do Mercado Pago não são deduzidas; faturas zeradas ficam sem nota
  - sistema: **NFS-e Paulistana** (substituída pelo Portal Nacional em 2026-10-22, D-628); o Asaas emite com o **e-CNPJ** da DevBatista, que já existe
  - descrição: "Licenciamento de software CatalystHR por assinatura - Competência MM/AAAA" e a menção de optante pelo Simples Nacional
  - cancelamento: até 6 meses, desde que o DAS da competência não tenha sido pago
  - reforma tributária: nada muda em 2026 para o Simples
  - o CatalystOps pode ser faturado pelo mesmo CNPJ, com o produto identificado na descrição
  - rotina da Contabilizei: notas e extratos conferidos na plataforma deles até o dia 5 do mês seguinte, como já é feito hoje
- [x] **Contador (especialista Mariana F.):** respostas recebidas em 2026-10-22 e registradas na D-628:
  - uma nota por fatura, com a mensalidade e o excedente discriminados na descrição
  - competência: o mês em que começa o ciclo da fatura, mesmo com pagamento atrasado; o excedente e o proporcional do ciclo anterior entram na mesma nota, com o período da medição
  - a alíquota do Simples não vai na nota (hoje 6,00%: 3,99% federal e 2,01% de ISS; variação mensal no painel da Contabilizei, em "Minhas alíquotas")
  - inscrição municipal (CCM) **18721206**, com o código 02798 (item 01.05) ativo e ligado ao CNAE 6202-3/00
  - sistema: **Portal Nacional da NFS-e**, obrigatório para o Simples desde 2026-11-01 (comunicado da Prefeitura de São Paulo de 2026-08-13). A NFS-e Paulistana fica só para consulta e emissão retroativa
  - regime de apuração pelo Simples Nacional; regime especial "0 - Nenhum"
  - série da DPS: **1**, só para o Asaas (faixa de 00001 a 49999, para API), começando do número 1. A Contabilizei usa outra série, sem conflito. As notas do Asaas entram sozinhas na plataforma da Contabilizei, para a conferência mensal
- [x] **Asaas:** conta da DevBatista aberta, com o cadastro aprovado em 2026-10-13
- [ ] **Contador e Asaas:** a lista de códigos de serviço do Asaas não tem o **02798** (conferido em 2026-10-22). A opção mais próxima é o 02800, "Licenciamento ou cessão de direito de uso de programas de computação, inclusive distribuição" (item 1.05). Confirmar com o contador qual usar, o código de tributação nacional e o código NBS. Não escolher antes da resposta
- [ ] **Asaas:** configurar a emissão no Portal Nacional (`fiscalInfo/municipalOptions` diz o método de autenticação: certificado, usuário e senha do portal ou token). Se for o e-CNPJ, ele vence todo ano: renovar antes, ou as notas param
- [ ] **Asaas:** criar a conta do sandbox, para o desenvolvimento do 19i
- [ ] Antes da primeira nota pelo Asaas: confirmar no Portal Nacional que a série 1 não foi usada por outro canal
- [ ] Risco: o IBS e a CBS passam a valer para o Simples em 2027-01-01. Conferir com o contador e no Asaas o que muda na nota
- [x] **Asaas:** preço por nota confirmado na conta em 2026-10-22: **R$ 0,49 por nota emitida** (Minha conta → Taxas e prazos → Serviços de gestão). As notificações do Asaas por e-mail e SMS custam R$ 0,99 por cobrança paga; como não há cobrança no Asaas (D-561), não deveriam incidir
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
