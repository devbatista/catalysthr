# Mercado Pago: PIX, webhook e conferência (bloco 19e)

> Análise da documentação oficial do Mercado Pago antes de implementar o bloco 19e da spec 19: PIX, webhook, conferência diária e contratação pelo cliente durante o teste (RN-19-033, RN-19-042, RN-19-046, CA-19-007, CA-19-008, D-613).
>
> Conferida em 2026-10-20. Nenhum código foi escrito ainda. Os pontos marcados **[resumo]** vieram de páginas longas demais para a ferramenta ler inteiras, que devolveu um resumo no lugar do texto; antes de implementar, eles precisam ser conferidos no navegador.

## Resumo

- **O PIX pela API funciona como a spec prevê:** QR code, código copia e cola e vencimento configurável de 30 minutos a 30 dias (24 horas por padrão).
- **A API citada na spec (`/v1/payments`) agora é chamada de "legacy".** O Mercado Pago recomenda a **API de Orders** (`/v1/orders`) para integrações novas. A de Payments continua funcionando, mas só recebe correções.
- **O webhook só traz o id do recurso.** A aplicação busca o pagamento na API, confere a assinatura `x-signature` (HMAC, com uma chave gerada no painel) e responde em até 22 segundos.
- **Três decisões são suas:** a API de Orders ou a de Payments; a gem oficial ou um cliente HTTP próprio; e o que fazer com o QR code de uma fatura vencida.

## 1. Criação do PIX

### Pela API de Payments (`POST /v1/payments`, "legacy")

Fontes:
- [Pix na Payments API](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-payments/integration-configuration/integrate-pix)
- [Referência: criar pagamento](https://www.mercadopago.com.br/developers/pt/reference/online-payments/checkout-api-payments/create-payment/post)
- [Visão geral da Payments API](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-payments/overview)

- **Dados a enviar:** "é preciso enviar o e-mail do comprador, tipo e número de documento, o meio de pagamento utilizado (pix) e o detalhe do valor".
  - O exemplo envia `transaction_amount`, `description`, `payment_method_id: "pix"`, `payer.email`, `payer.first_name`, `payer.last_name`, `payer.identification` (tipo e número) e `payer.address`.
- **Campos obrigatórios:** a referência não marca nenhum campo do corpo como obrigatório **[resumo]**. Os erros mostram que `payment_method_id`, `transaction_amount` e `payer.email` são exigidos (erros 4001, 4002 e 4050).
- **`notification_url`:** precisa começar com `https://` e ter menos de 500 caracteres (erros 4020 e 4021).
- **Sucesso:** a API responde com o status 201.
- **Cabeçalho `X-Idempotency-Key`:** obrigatório (erro 4292 sem ele **[resumo]**). A Payments API não diz o formato; a página de Orders recomenda um UUID v4 **[resumo]**.

### Vencimento

- "Por padrão, a data de vencimento para pagamentos com Pix é de **24 horas**, mas você pode alterá-la enviando o campo `date_of_expiration`."
- "A data configurada deve estar entre **30 minutos até 30 dias** a partir da data de emissão do pagamento."
- **Formato:** `yyyy-MM-dd'T'HH:mm:ssz` (erro 23 da referência).
- **Na API de Orders:** o campo é `transactions.payments[].expiration_time`, uma duração ISO 8601, com o mesmo padrão e os mesmos limites **[resumo]**.

### Resposta

- **Dados do QR code:** ficam em `point_of_interaction.transaction_data`:
  - `qr_code`: o código copia e cola;
  - `qr_code_base64`: a imagem;
  - `ticket_url`: uma página do Mercado Pago com o QR e as instruções;
  - `transaction_id`.
- **Situação inicial:** `"status": "pending"`, `"status_detail": "pending_waiting_transfer"`.
- "O QR code deverá ser utilizado somente uma vez."

### Situações do pagamento

Fonte: [tabela de situações](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-payments/response-handling/query-results)

| `status` / `status_detail` | Significado |
|---|---|
| `pending` / `pending_waiting_transfer` | Aguardando o pagamento no banco |
| `approved` / `accredited` | Pago |
| `cancelled` / `expired` | "Cancelado após ficar com status pendente por 30 dias" |
| `cancelled` / `by_collector`, `by_payer` | Cancelado pelo vendedor ou pelo comprador |
| `refunded` / `refunded`, `by_admin` | Estornado |
| `approved` / `partially_refunded` | Estornado em parte |

**Lacuna:** a documentação não diz que situação o PIX ganha logo depois de passar o `date_of_expiration`. A página de Orders recomenda cancelar por conta própria os pagamentos não pagos depois do vencimento **[resumo]**.

### Exigência da conta

- "Caso queira oferecer pagamentos via Pix, é necessário ter as chaves Pix cadastradas" ([visão geral](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-payments/overview)).
- A conta DevBatista já recebe PIX, segundo o [`pendencias-fornecedores.md`](pendencias-fornecedores.md). **Falta confirmar** que a chave está cadastrada na conta usada pela API.

## 2. API de Orders contra API de Payments

Fontes:
- [Visão geral da Payments API](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-payments/overview)
- [Pix na API de Orders](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/payment-integration/websites/pix)
- [Migração de Payments para Orders](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/resources/migrate-payments-to-orders)

- **Recomendação do Mercado Pago:** "Se você está começando uma nova integração, recomendamos utilizar a API de Orders".
- **Situação da Payments API:** quem já usa a Payments API "continua funcionando normalmente", mas ela "não receberá novas funcionalidades, apenas correções de segurança e estabilidade". O menu chama essa parte de "Integração via Payments API (legacy)".
- **Desativação:** "O Mercado Pago não desativou essa API" **[resumo]**. Não há data de fim.
- **PIX pela API de Orders [resumo]:**
  - a chamada é `POST /v1/orders`, com `total_amount` (texto), `external_reference`, `processing_mode` (`automatic` ou `manual`), `payer.email` e `transactions.payments[].payment_method` (`id: "pix"`, `type: "bank_transfer"`);
  - o QR code volta em `transactions.payments[].payment_method.qr_code`, `qr_code_base64` e `ticket_url`;
  - as situações são `action_required` / `waiting_transfer`;
  - o `pending` da Payments corresponde ao `action_required` da Orders, e o `approved`, ao `processed`.
- **Lacuna:** a busca específica sobre a API de Orders falhou, porque os endereços tentados deram 404. Ainda faltam:
  - a busca de pedidos para a conferência diária;
  - a lista completa de situações;
  - a confirmação de que a API de Orders aceita o **cartão salvo sem CVV**, que o 19h vai precisar.

**Por que importa:** a spec cita `/v1/payments` (seção 8, P-19-29), e o [`plano-de-fases.md`](plano-de-fases.md) já pedia para conferir o `/v1/orders`. Escolher a API de Orders muda o desenho do 19e e, provavelmente, o do 19h (cartão). É uma decisão sua (ver a seção 6).

## 3. Webhook

Fonte: [Webhooks](https://www.mercadopago.com.br/developers/pt/docs/your-integrations/notifications/webhooks)

### Configuração

- **Dois jeitos de configurar:**
  - pelo painel, em **Suas integrações → Webhooks → Configurar notificações**, com uma URL de teste e uma de produção;
  - pela URL enviada em cada pagamento.
- **Prioridade:** "As URLs configuradas durante a criação do pagamento terão prioridade sobre aquelas configuradas através de Suas integrações."
- **Assinatura:** só a configuração pelo painel gera a **assinatura secreta** que permite validar a origem.
- **Tópicos:** `payment` serve para o Checkout Transparente "(legacy)", e `orders`, para o Checkout Transparente pela API de Orders.

### Assinatura (`x-signature`)

- **Exemplo do cabeçalho:** `ts=1704908010,v1=618c85345248dd820d5fd456117c2ab2ef8eda45a0282ff693eac24131a5e839`.
- **A chave:** "Ao clicar em Salvar, será gerada uma assinatura secreta exclusiva para a sua aplicação". Ela "não tem prazo de validade", e a renovação periódica é "altamente recomendável".
- **A validação:** é feita por HMAC com o `x-signature`, o `x-request-id`, o `data.id` (parâmetro da URL) e a chave. Válida, a aplicação responde 200; inválida, 401.
- **Lacuna:** a montagem exata do texto assinado (`id:...;request-id:...;ts:...;`), o algoritmo (SHA-256) e se o `data.id` vai em minúsculas ficam na aba "Sem SDKs", que não abriu na ferramenta. **Conferir no navegador antes de implementar.**
- **Guia da gem oficial ([webhooks.md](https://github.com/mercadopago/sdk-ruby/blob/master/docs/guides/webhooks.md)):** "Pass `x-signature`, `x-request-id`, and `data.id` exactly as received". O exemplo usa uma tolerância de 300 segundos para o `ts`.
- **Notificações de QR Code:** não são assinadas.

### Entrega

- **Resposta esperada:** `HTTP 200` ou `201`, em até **22 segundos**.
- **Novas tentativas:** "a cada 15 minutos, até receber uma resposta. Após a terceira tentativa, o prazo será prorrogado, mas os envios continuarão acontecendo."
- **Corpo da notificação:** traz só o tipo e o id, por exemplo `"type": "payment"`, `"action": "payment.created"`, `"data": {"id": "999999999"}`. A aplicação busca o recurso em `GET /v1/payments/{id}` ou `GET /v1/orders/{id}`.
- **Do guia da gem:** "Treat the notification as a signal rather than the authoritative resource state". A entrega "can repeat or arrive out of order". Ou seja, o processamento precisa ser idempotente.
- **Teste:** existe uma URL de teste usada com as credenciais de teste. A página tem o passo "Simular o recebimento da notificação", mas o conteúdo dele não abriu.

## 4. Conferência diária (RN-19-046, CA-19-008)

- **`GET /v1/payments/{id}`** ([referência](https://www.mercadopago.com.br/developers/pt/reference/online-payments/checkout-api-payments/get-payment/get)): devolve `status`, `status_detail`, `external_reference`, `transaction_amount`, `date_approved` e `transaction_details`.
- **`GET /v1/payments/search`** ([referência](https://www.mercadopago.com.br/developers/pt/reference/online-payments/checkout-api-payments/search-payments/get)):
  - busca os pagamentos dos últimos 12 meses, filtrando por `external_reference`, `sort`, `criteria` e `range`, com `begin_date` e `end_date`;
  - a resposta é paginada (`paging.total`, `limit: 30`, `offset`);
  - o intervalo precisa ser menor que 365 dias.
- **Proposta:** a conferência consulta cada fatura em aberto pelo id do pagamento guardado. Se não houver id, busca pelo `external_reference`, que seria o id da fatura.
- **Lacuna:** a busca equivalente na API de Orders não foi conferida.

## 5. Gem oficial (`mercadopago-sdk`)

Fontes:
- [RubyGems](https://rubygems.org/gems/mercadopago-sdk)
- [repositório](https://github.com/mercadopago/sdk-ruby)
- [CHANGELOG](https://github.com/mercadopago/sdk-ruby/blob/master/CHANGELOG.md)

- **Última versão:** 3.5.0, de 2026-08-28. Exige Ruby 3.3 ou mais novo, tem licença MIT e depende de `faraday ~> 2.0` e `json ~> 2.5`.
- **Manutenção:** ativa, com commits até 2026-10-14.
- **Recursos:** `sdk.order` (o caminho recomendado pelos guias) e `sdk.payment`, busca com paginação automática, novas tentativas configuráveis, exceções tipadas e o validador de webhook `Mercadopago::Webhook::Validator`.
- **Atenção:** a versão 3.5.0 aparece com **4,5 KB**, contra 367 KB da 3.4.0. O pacote pode ter sido publicado sem o código. É preciso conferir o conteúdo antes de fixar a versão.
- **Spec:** a spec prevê a gem oficial (P-19-29). Para o Asaas, a escolha foi um cliente HTTP próprio com Faraday (P-19-37).

## 5a. Conferência de 2026-10-21

Esta seção fecha as lacunas das seções 2 a 5. Onde ela diverge delas, vale esta seção.

### Gem: a 3.5.0 saiu vazia

- **Fato:** o pacote 3.5.0 (`gem fetch mercadopago-sdk -v 3.5.0`) não traz nenhum arquivo, porque os metadados dizem `files: []`.
- **Fato:** a 3.4.0 traz `sdk.order` (`create`, `get`, `search`, `cancel`, `refund`, `capture`, `process`), `sdk.payment` e o `Mercadopago::Webhook::Validator`.
- **Conclusão:** se for a gem, ela fica fixada em `3.4.0`.

### Assinatura do webhook

A aba "Sem SDKs" continua sem abrir, porque é montada no navegador. O que segue vem do código dos SDKs oficiais de Ruby (3.4.0), Python e Node, que coincidem:

- **Texto assinado:** `id:<data.id>;request-id:<x-request-id>;ts:<ts>;`, nessa ordem e com `;` no fim.
  - Se o `data.id` ou o `x-request-id` vier vazio, o par sai do texto.
  - Sem o `ts`, a notificação é recusada.
- **Algoritmo:** HMAC-SHA256 com a assinatura secreta, em hexadecimal, comparado ao `v1` em tempo constante.
- **Minúsculas:** nenhum SDK converte o `data.id`. O comentário da gem Ruby diz que converte, mas o código não faz isso, e o teste `test_uppercase_dataid_is_preserved` confirma. O guia Ruby manda passar os valores "exactly as received".
- **Origem do `data.id`:** é o parâmetro `data.id` da URL da notificação, não o corpo.
- **Tolerância do `ts`:** a documentação não recomenda nenhuma, e nos SDKs a conferência é opcional. Os exemplos usam 300 segundos.

### API de Orders

Fontes:
- [Situações da order](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/payment-management/status/order-status)
- [Buscar orders](https://www.mercadopago.com.br/developers/pt/reference/online-payments/checkout-api/search-order/get)
- [Cancelar order](https://www.mercadopago.com.br/developers/pt/reference/online-payments/checkout-api/cancel-order/post)
- [Cartões salvos](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/payment-management/improve-payment-approval/saved-cards)

**Situações:**

| `status` | `status_detail` |
|---|---|
| `created` | `created` |
| `action_required` | `waiting_payment`, `waiting_capture`, `waiting_transfer`, `waiting_retry` |
| `processing` | `in_process` |
| `processed` | `accredited`, `partially_refunded` |
| `canceled` | `canceled`, `expired` ("A order expirou e foi cancelada.") |
| `failed` | `expired` ("A order expirou e falhou."), `failed` |
| `refunded` | `refunded` |
| `charged_back` | `in_process`, `settled`, `reimbursed` |

- **PIX pendente:** fica em `action_required` / `waiting_transfer`.
- **PIX que venceu:** a documentação não diz se vira `canceled` / `expired` ou `failed` / `expired`. A conferência precisa tratar os dois casos como "não pago".

**Busca:**
- A chamada é `GET /v1/orders`, com `begin_date` e `end_date` obrigatórios (data de criação, RFC 3339).
- Os filtros incluem `external_reference`, `status` e paginação (`page_size` até 100).
- Isso basta para a conferência diária.

**Cancelamento:**
- A chamada é `POST /v1/orders/{id}/cancel`, com `X-Idempotency-Key`.
- Só cancela uma order em `created` ou `action_required`. Depois de 30 dias, não é mais possível cancelar à mão.

**Vencimento do PIX:**
- O campo é `transactions.payments[].expiration_time`, em duração ISO 8601.
- Vai de 30 minutos a 30 dias, com 24 horas por padrão.

**Cartão salvo sem CVV, para o 19h. Não está resolvido em nenhuma das duas APIs:**
- **A documentação pública** das duas APIs manda capturar o CVV de novo a cada cobrança com cartão salvo: "O Mercado Pago não armazena o código de segurança em nenhuma das duas APIs".
- **A gem 3.4.0** traz um exemplo de cobrança recorrente pela API de Orders sem CVV (`examples/order/create_automatic_payment.rb`):
  - a 1ª cobrança é feita pelo cliente, com CVV, e registra o cartão (`stored_credential.first_payment: true`);
  - as seguintes são feitas por nós (`payment_initiator: "merchant"`), por um `payment_profile_id` criado em `POST /v1/customers/{id}/payment-profiles`.
- **Esse recurso ("Automatic Payments") não aparece na documentação pública.** Não está confirmado se ele vale no Brasil nem se precisa ser habilitado na conta.
- **Alternativa:** o produto separado "Assinaturas" (preapproval). Ainda não foi lido.

## 6. Decisões que são suas

> **Decididas em 2026-10-21 (D-622):** API de Orders; cliente HTTP próprio, não a gem (a 3.4.0 rebaixaria o `json` do app para a série 2); PIX novo quando a fatura vencida é aberta.

1. **A API do PIX:**
   - **(a) API de Orders:** é a recomendada para integrações novas e terá funcionalidades novas. Muda a referência da spec (seção 8, P-19-29) e exige conferir se ela atende o cartão salvo sem CVV do 19h.
   - **(b) API de Payments:** é a da spec e funciona hoje, mas está congelada ("legacy").
   - **Recomendação (revista em 2026-10-21):** (a). A conferência mostrou que a Payments API também não documenta o cartão salvo sem CVV. A única pista de cobrança recorrente sem CVV está na API de Orders (seção 5a). O cartão deixa de ser um motivo para ficar na (b).
2. **A gem oficial ou um cliente HTTP próprio:**
   - **Recomendação:** a gem oficial fixada na 3.4.0, como a spec prevê. Ela já traz o validador de webhook. A 3.5.0 está vazia (seção 5a).
   - **Alternativa:** um cliente com Faraday, como no Asaas, que dá mais controle e não depende de uma gem com problema de publicação.
3. **O QR code da fatura vencida:** o QR vence de 30 minutos a 30 dias, e a fatura sai 3 dias antes do vencimento (RN-19-041). Mas a régua de inadimplência vai até 30 dias depois do vencimento (RN-19-050), e o cliente pode pagar uma fatura atrasada (CA-19-007).
   - **Recomendação:** gerar o PIX na emissão da fatura, vencendo no dia do vencimento da fatura. Depois do vencimento, gerar um PIX novo quando o cliente abrir a fatura vencida, cancelando o anterior.

## 7. Próximos passos

- [x] **[você]** Decidir os itens da seção 6 (D-622)
- [ ] **[você]** Confirmar no Mercado Pago que a chave Pix está cadastrada na conta DevBatista usada pela API
- [ ] **[você]** Configurar o webhook no painel (Suas integrações → Webhooks), evento **Order (Mercado Pago)**, com a URL `https://admin.catalysthr.com.br/webhooks/mercado-pago`, e guardar a assinatura secreta em `MERCADO_PAGO_WEBHOOK_SECRET` no Railway
- [ ] **[você]** Guardar o access token de produção em `MERCADO_PAGO_ACCESS_TOKEN` no Railway. Sem ele, nenhum PIX é gerado
- [ ] **[você]** Conferir em "Tarifas" no painel do Mercado Pago a tarifa por PIX recebido
- [x] **[Claude]** Conferir a assinatura do webhook (pelo código dos SDKs oficiais), a API de Orders (situações, busca e cancelamento) e o conteúdo da gem 3.5.0 (seção 5a)
- [ ] **[você, antes do 19h]** Perguntar ao Mercado Pago se o "Automatic Payments" da API de Orders (cobrança recorrente sem CVV por `payment_profile_id`) está disponível para a conta no Brasil e se precisa ser habilitado
- [x] **[Claude]** 19e-1: PIX das faturas, webhook e conferência diária, com WebMock
- [x] **[Claude]** 19e-2: contratação durante o teste ou depois dele (D-623)
