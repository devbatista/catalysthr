# Pendências com fornecedores (checklist)

> Última atualização: 2026-10-14
> Para uso interno da equipe CatalystHR. Cada item informa o que pedir ou fazer, por que, que fase ele trava (`plano-de-fases.md`) e a referência.

## Mercado Pago — trava a fase 1

- [ ] Confirmar a habilitação da conta para **pagamentos automáticos com cartão salvo, sem pedir o CVV** (cobranças iniciadas pelo vendedor, de valor variável) (D-496)
  - A documentação chama a solução de **Pagamentos Automáticos** e exige *"a autorização da equipe Comercial"* ([pré-requisitos](https://www.mercadopago.com.br/developers/pt/docs/automatic-payments/prerequisites)). Ela não confirma o valor variável
  - 2026-10-14: chamado aberto pelo suporte ao desenvolvimento, encaminhado a atendimento humano e ao comercial, na conta da DevBatista (produção e credenciais de teste). Pedidos: habilitar `card_on_file` sem CVV, confirmar o valor diferente a cada mês, tarifas e Pix Automático
  - O primeiro atendimento sugeriu as Assinaturas (preapproval), recusadas: valor fixo, novas tentativas próprias e cancelamento automático depois de 3 recusas, contra a D-496, a D-497 e a RN-19-042
  - Tarifas atuais da conta no Checkout, informadas pelo suporte (não valem necessariamente para os Pagamentos Automáticos): crédito com recebimento na hora 4,98%, em 14 dias 4,49%, em 30 dias 3,98%
- [ ] Confirmar a cobrança por PIX pela API de pagamentos, com QR e vencimento (D-481). A conta já recebe PIX e cartão; falta conferir o vencimento na integração
- [ ] Configurar os webhooks e a assinatura de validação
- [ ] Para uma fase seguinte, perguntar sobre a disponibilidade do **Pix Automático** pela API

## Asaas e contador da CatalystHR — trava a fase 1

- [ ] **Contador:** definir o código do serviço municipal, a alíquota de ISS, as retenções e o momento do fato gerador da NFS-e (D-560 a D-562)
- [ ] **Asaas:** abrir a conta da CatalystHR e configurar a emissão na prefeitura ou no Portal Nacional (`fiscalInfo/municipalOptions`)
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

## Anthropic e Voyage AI — trava a fase 2

- [ ] **Anthropic:** contratar a **retenção zero** e confirmar que ela está ativa na conta (D-380)
- [ ] **Anthropic:** confirmar quais recursos usados estão cobertos pela retenção zero: Messages API, saídas estruturadas, citações e cache de prompt. Batch API e Files API não serão usadas (D-385)
- [ ] **Voyage AI:** confirmar se oferece retenção zero. Se não oferecer, levar a decisão ao responsável (os trechos enviados são só dos materiais do assistente, sem dados de colaboradores)

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
