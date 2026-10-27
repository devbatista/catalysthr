# Riscos aceitos (checklist)

> Riscos que o responsável decidiu aceitar por um tempo, com o motivo, o que reduz o impacto e o que obriga a rever a decisão. Cada risco é reavaliado quando acontece um dos seus gatilhos, ou na data de revisão, o que vier primeiro.
>
> Legenda: **[você]** = feito por você (console, painel, decisão); **[Claude]** = posso fazer pela linha de comando, mostrando o comando antes e só com o seu OK.

## R-001 — Chave da AWS da aplicação possivelmente exposta no incidente do Railway

- **Aberto em:** 2026-10-21
- **Situação:** aceito por enquanto
- **Revisão:** quando os deploys do Railway voltarem, ou em 2026-10-28, o que vier primeiro

### Contexto (fato)

- Em 2026-10-21, o Railway publicou um [comunicado de segurança](https://blog.railway.com/p/security-disclosure-wednesday-october-21st): um terceiro pode ter acessado as variáveis de ambiente dos clientes e, em parte delas, o conteúdo descriptografado.
- O Railway recomenda a todos trocar as variáveis e as chaves guardadas lá. Ele vai avisar por e-mail as contas confirmadas como afetadas. Até 2026-10-21, a nossa não foi confirmada.
- Os deploys estão pausados ([status](https://status.railway.com/incident/QH8L8B3E)), então nenhuma variável nova pode ser publicada.

### O que está em risco

- A chave de acesso `AKIAWYQ2…` do usuário IAM `catalysthr-app`, na conta 464986173446, criada em 2026-10-16.
- Ela tem as políticas `catalysthr-app-email` (SES) e `catalysthr-app-files` (S3).
- **Se vazou, quem tiver o valor pode:**
  - mandar e-mails pelo SES com o domínio `catalysthr.com.br`, o que pode queimar a reputação e atrasar a saída do sandbox;
  - ler e gravar os arquivos que a política de arquivos permite.

### Por que foi aceito por enquanto

Decisão do responsável em 2026-10-21. Conferido na AWS, só leitura, na mesma data:
- **Uso da chave:** a AWS mostra o último uso como "None", ou seja, ela nunca foi usada.
- **CloudTrail:** nenhum evento com essa chave desde 2026-10-16.
- **SES:**
  - continua em sandbox, com o limite de 200 envios por dia, 1 por segundo, e só para endereços verificados;
  - teve 0 envios nas últimas 24 horas.
- **Produção:** ainda não tem clientes nem dados reais (D-610).

### O que obriga a rever na hora (gatilhos)

- O Railway avisa por e-mail que a conta foi afetada.
- Aparece algum uso da chave (`get-access-key-last-used` deixa de ser "None") sem que a produção a tenha usado.
- O SES mostra envios que a aplicação não fez, ou houve devolução ou reclamação de e-mails que não mandamos.
- O SES sai do sandbox, porque o limite e o alcance de um abuso crescem.
- O primeiro cliente real entra.

### Como conferir

Só leitura, com o perfil `catalysthr` do SSO:

```sh
aws iam get-access-key-last-used --access-key-id <chave> --profile catalysthr
aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<chave> --profile catalysthr
aws sesv2 get-account --region sa-east-1 --profile catalysthr
```

### Como fechar

- [x] **[você]** Decidir desativar a chave. Desativar não apaga, e dá para reativar. **[Claude]** pode rodar `aws iam update-access-key --status Inactive` com o seu OK
- [x] **[Claude]** Quando os deploys voltarem: criar uma chave nova para o `catalysthr-app` (2026-10-27)
- [x] **[Claude]** Pôr a chave nova no Railway (`AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`) e publicar: gravada no `web` direto da AWS, sem passar pelo chat, e por referência no `worker` e no `worker-time`
- [x] **[Claude]** Conferir que a produção usa a chave nova: com a antiga já desativada, o `web` e o `worker` acessam o bucket de arquivos (2026-10-27). A antiga nunca foi usada ("None")
- [ ] **[Claude]** Apagar a chave antiga (`AKIAWYQ2…` de 2026-10-16, inativa), depois de alguns dias sem reclamação

### Outras variáveis do Railway no mesmo incidente

Estas ficam abertas, para trocar quando os deploys voltarem. Hoje não são riscos aceitos, só bloqueados pela pausa.

- [x] `RAILS_MASTER_KEY` / `secret_key_base`: **risco alto**, porque permite forjar o cookie de sessão. Gerar um novo e publicar, o que derruba as sessões abertas. Feito em 2026-10-26 (D-630): um `SECRET_KEY_BASE` novo, gerado direto no Railway sem passar pelo chat, no `web` e por referência nos outros serviços; o `RAILS_MASTER_KEY` saiu dos quatro serviços e o `config/credentials.yml.enc`, que só guardava o `secret_key_base` antigo, saiu do repositório. Conferido: o Rails usa a chave nova, o login com MFA funcionou e o backup rodou
- [x] Senhas do Postgres e do Redis (`DATABASE_URL`, `REDIS_URL`): os dois estão só na rede privada. Trocadas em 2026-10-27, geradas direto no Railway. O Redis lê a `REDIS_PASSWORD` no início; no Postgres, um `ALTER ROLE CURRENT_USER` pelo `web` e a `POSTGRES_PASSWORD` gravada em seguida, com volta pronta. Conferido: conexões novas ao banco, os dois Sidekiq no Redis, as filas intactas e o backup com a senha nova
- [x] `ACTIVE_RECORD_ENCRYPTION_*`: trocadas em 2026-10-27, com as três chaves novas. Havia um só registro criptografado (o CPF e o segredo do MFA do único usuário), recifrado num processo só, lendo com as chaves antigas e gravando com as novas, sem a rotação do Rails. Conferido: o CPF e o MFA são lidos e a busca pelo CPF funciona. As chaves antigas e as novas foram salvas num arquivo local, com permissão só do responsável, para ele levar ao cofre de senhas e apagar o arquivo; **as antigas são necessárias para ler os backups até 2026-12-01**, quando o último backup feito com elas expira (D-223)
- [ ] `SENTRY_DSN`: baixo risco. Gerar uma nova chave do projeto no Sentry
- [x] `RAILWAY_TOKEN` no GitHub: gerar um novo e atualizar o secret do workflow de deploy (2026-10-26; o antigo já não valia)
