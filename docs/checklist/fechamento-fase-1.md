# Fechamento da fase 1 (checklist)

> Última atualização: 2026-10-28
> O que falta para fechar a fase 1 (`plano-de-fases.md`). O desenvolvimento que não depende de terceiros está pronto.

## Com você

- [x] **Backup diário (20a):** criar os usuários IAM `catalysthr-backup` e `catalysthr-restore` e o serviço `backup` no Railway (`aws-arquivos.md`, passo 7)
- [x] **Backup diário (20a):** rodar o `backup` uma vez à mão e me avisar, para eu conferir o arquivo no S3 e o monitor `pg-dump-diario` no Sentry (CA-20-003, 2026-10-26)
- [x] **Backup diário (20a):** depois do primeiro sucesso, ligar o alerta do monitor `pg-dump-diario` no Sentry
- [x] **Saúde detalhada (20b):** gerar o `HEALTH_CHECK_TOKEN` no seu terminal e colar no serviço `web` do Railway (2026-10-27, gerado direto no Railway)
- [x] **Alertas (20b):** criar no Sentry a regra de "erros em massa", por e-mail (`contas-infraestrutura.md`, seção 3, 2026-10-27)

## Com fornecedores

- [ ] **Mercado Pago:** liberação dos Pagamentos Automáticos (cartão salvo sem CVV). Libera o 19h. Próximo passo: o SAC por telefone (`pendencias-fornecedores.md`)
- [x] **Asaas:** conta de sandbox. Libera o desenvolvimento do 19i (2026-10-28)
- [x] **Asaas:** emissão configurada no Portal Nacional, conferida pela API em produção (2026-10-29, D-634)
- [ ] **AWS:** saída do sandbox do SES. Recusada em 2026-10-27; caso reaberto no mesmo dia, com o site institucional no ar. Aguardando a resposta (`site-institucional.md`, D-631)
- [x] **Railway:** criptografia em repouso confirmada no relatório SOC 2 do Trust Center (2026-10-29), com ressalvas (`pendencias-fornecedores.md`)

## Depois, comigo

- [ ] 19h: cartão salvo e novas tentativas
- [x] 19i: NFS-e pelo Asaas, atrás da flag `nfse` (2026-10-28). Na produção: chave, webhook e a primeira nota real (`pendencias-fornecedores.md`)
- [ ] Teste de ponta a ponta da fase 1: cadastrar, configurar a marca, convidar o RH com MFA, contratar e pagar por cartão e PIX, e ver a NFS-e na fatura
