# Saída do sandbox do SES: terceiro pedido (checklist)

> Criado em 2026-11-04. A AWS recusou o pedido duas vezes (caso 179201169800267, em 2026-10-27 e em 2026-11-04), sem dizer o motivo. O responsável escolheu, em 2026-11-04, fazer um pedido novo depois de criar algum histórico na conta. Se esse pedido também for recusado, avaliamos a troca de provedor, o que exige uma decisão nova revisando a D-026. Pela D-637, isso trava o primeiro cliente, não o desenvolvimento.
>
> Legenda: **[você]** = feito por você (console, painel, decisão); **[Claude]** = posso fazer pela linha de comando, mostrando o comando antes e só com o seu OK.

## Hipóteses sobre as recusas (não confirmadas)

- A conta `catalysthr` foi criada em 2026-10-14 e nunca enviou um e-mail de verdade, então a AWS não tinha nenhum histórico para avaliar.
- O segundo pedido reabriu o caso recusado, em vez de abrir um caso novo.
- O CatalystHR envia e-mails em nome de outras empresas, pelos domínios das marcas (D-040, D-596). A AWS avalia esse tipo de uso com mais cuidado. O pedido novo explica esse uso e os controles, em vez de omitir.

## Antes do pedido

- [ ] **[você]** Dizer quais endereços da equipe vão receber os e-mails de teste. No sandbox, o SES só entrega para endereços verificados
- [ ] **[Claude]** Verificar esses endereços no SES, em São Paulo. É uma escrita na AWS, então só com o seu OK
- [ ] **[você + Claude]** Rodar o teste de ponta a ponta da fase 1 em produção, que já é uma pendência da D-637, com e-mails reais para esses endereços: convite, recuperação de senha e pelo menos um aviso do motor de notificações. Conferir que a entrega volta pelo SNS e fica marcada como entregue
- [ ] **[Claude]** Na véspera do pedido, conferir pela CLI, só com leituras: envios das últimas semanas, nenhuma devolução, nenhuma reclamação e a conta sem pendência (`aws sesv2 get-account`)
- [ ] **[você]** Conferir que a fatura de outubro da organização (conta `devbatista`) está paga. A ideia de que isso ajuda é só uma hipótese, mas não custa conferir

## Pedido

- [ ] **[você]** A partir de **2026-12-02**, abrir um **pedido novo** no console do SES em São Paulo, em "Request production access", sem reabrir o caso 179201169800267. Se o console não mostrar mais esse botão depois de duas recusas, abrir um caso novo no Support Center, em "Service limit increase", serviço SES. Esse caminho alternativo **não foi conferido**
- [ ] **[você]** Usar o texto abaixo e atualizar os números com os dados da véspera
- [ ] Resposta da AWS
- [ ] Se for recusado: comparar dois ou três provedores (preço, região do processamento por causa da LGPD, API de domínios, webhooks de devolução e reclamação, supressão) e propor a decisão

## Texto do pedido

Mail type: **Transactional**. Website URL: `https://www.catalysthr.com.br`. Contact language: English.

```text
We are requesting production access for Amazon SES in sa-east-1 (São Paulo) for
CatalystHR, an HR platform for Brazilian companies built and operated by
DEVBATISTA DESENVOLVIMENTO DE SISTEMAS E SERVICOS LTDA (www.catalysthr.com.br,
which includes our terms of use and privacy policy).

This is a new request. Our previous request (case 179201169800267) was declined.
Since then we have run our end-to-end tests with real sending to verified
addresses inside the sandbox: [N] emails sent, [N] delivered, 0 bounces,
0 complaints.

WHAT WE SEND
Transactional email only. No marketing, newsletters or promotional content, and
no purchased, rented or uploaded mailing lists.
- Account access: invitations to set up an account, password recovery links,
  unlock codes and security alerts (for example, a changed contact address).
- Work notifications: HR document requests, steps of admission processes and
  reminders the user's own company set up in the system.

WHO RECEIVES IT
Only employees and HR staff of our client companies. Each recipient is
registered by their employer inside the platform, and the account invitation is
the first email they receive. Nobody signs up from a public form.

SENDING DOMAINS
Our own domain, catalysthr.com.br, is verified with DKIM, a custom MAIL FROM
domain (bounce.catalysthr.com.br) with SPF, and DMARC (p=quarantine).
CatalystHR is white label: a client or reseller can send from its own domain,
but only after that domain is verified in SES with DKIM and a custom MAIL FROM.
The sender is always no-reply@<verified domain>. Unverified domains fall back
to no-reply@catalysthr.com.br.

BOUNCES AND COMPLAINTS
- Every message goes through a configuration set that publishes delivery,
  bounce and complaint events to SNS. Our application consumes those events
  and verifies each SNS message signature.
- A permanent bounce marks the address as invalid and stops every email to it,
  including access emails. The user's HR team is notified to correct the
  address.
- A complaint stops all optional notifications to that address.
- The account-level suppression list is enabled for bounces and complaints.
- Users can turn optional email notifications off in their own settings.

VOLUME
We expect fewer than 1,000 emails per month during the first months, growing
with the number of client companies. We do not need a dedicated IP.
```

Antes de enviar, trocar os `[N]` pelos números conferidos na véspera. Se o teste de ponta a ponta não tiver gerado nenhum envio, tirar o segundo parágrafo, em vez de inventar números.
