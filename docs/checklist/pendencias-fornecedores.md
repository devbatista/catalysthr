# Pendências com fornecedores (checklist)

> Última atualização: 2026-10-13
> Para uso interno da equipe CatalystHR. Cada item informa o que pedir ou fazer, por que, que fase ele trava (`plano-de-fases.md`) e a referência.

## Mercado Pago — trava a fase 1

- [ ] Confirmar a habilitação da conta para **pagamentos automáticos com cartão salvo, sem pedir o CVV** (cobranças iniciadas pelo vendedor, de valor variável). Há relatos de que é preciso habilitar a conta (recurso "Established Stored Credential") (D-496)
- [ ] Confirmar a cobrança por PIX pela API de pagamentos, com QR e vencimento (D-481)
- [ ] Configurar os webhooks e a assinatura de validação
- [ ] Para uma fase seguinte, perguntar sobre a disponibilidade do **Pix Automático** pela API

## Asaas e contador da CatalystHR — trava a fase 1

- [ ] **Contador:** definir o código do serviço municipal, a alíquota de ISS, as retenções e o momento do fato gerador da NFS-e (D-560 a D-562)
- [ ] **Asaas:** abrir a conta da CatalystHR e configurar a emissão na prefeitura ou no Portal Nacional (`fiscalInfo/municipalOptions`)
- [ ] **Asaas:** confirmar o preço por nota (a página cita R$ 0,49, a confirmar)
- [ ] **Asaas:** criar a chave de API e configurar o webhook de notas
- [ ] **Asaas:** desligar o envio de e-mail das notas pelo Asaas (D-564)

## AWS — trava a fase 1

- [ ] Pedir a saída do **sandbox do SES** em São Paulo (sa-east-1). Sem isso, só é possível mandar e-mail para endereços verificados
- [ ] Verificar o domínio `catalysthr.com.br` no SES (DKIM, SPF, DMARC)
- [ ] Criar as chaves do KMS (A1, arquivos, backups), com rotação anual (P-20-22)
- [ ] Criar os usuários IAM por finalidade: aplicação, backup e restauração (P-20-21)

## WhatsApp pela Twilio — trava a fase 2 (convites por WhatsApp já na fase 1)

> O WhatsApp é enviado pela Twilio (D-034). Mesmo assim, a Meta exige que cada empresa tenha um Gerenciador de Negócios verificado e uma conta do WhatsApp Business (WABA) ligada à Twilio, e aprova cada modelo de mensagem. A Twilio cuida da parte técnica (cadastro do remetente e envio dos modelos). A verificação da empresa é feita por nós, no painel da Meta, e costuma demorar.

- [ ] Criar o Gerenciador de Negócios da Meta da DevBatista e concluir a verificação da empresa e o 2FA
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
- [ ] Configurar o domínio wildcard e acompanhar a emissão do certificado (pode levar até 72 horas)

## Sentry e Cloudflare — fase 0

- [ ] **Sentry:** escolher o plano, com logs e os monitores externos e de jobs da spec 20, na região dos EUA (P-20-03)
- [ ] **Cloudflare:** transferir ou apontar o DNS de `catalysthr.com.br`, sem proxy (D-503)

## Bancos dos clientes do piloto — trava a fase 4

- [ ] Validar o **layout do CSV da lista de pagamentos** com os bancos que o piloto usa (RN-12-071)

## INPI — trava a fase 3

- [ ] Registrar o programa de ponto no INPI, depois da orientação do jurídico (`pacote-juridico.md`, item 4.1)
