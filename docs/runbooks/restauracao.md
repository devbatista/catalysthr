# Restauração do backup: ensaio trimestral e recuperação

> Regras: RN-20-041, RN-20-045, RN-20-046, CA-20-008. Decisão: D-627.
> Para a equipe CatalystHR. O lembrete chega aos superadmins no dia 1 de janeiro, abril, julho e outubro.

## Quando usar

- **Ensaio, a cada 3 meses:** restaurar o último pg_dump num banco temporário, conferir e registrar o tempo (RN-20-046).
- **Perda total do Railway** (RN-20-045): os mesmos passos, num ambiente novo, em vez do banco temporário. Os outros cenários usam o PITR do Railway.

## Antes de começar

- [ ] Fora dos picos do ponto (7h às 9h e 17h às 19h).
- [ ] No IAM, criar uma chave de acesso para o usuário `catalysthr-restore` (`docs/checklist/aws-arquivos.md`, passo 7.2). Ele é o único que lê os backups.

## Passos do ensaio

1. **Banco temporário:** no projeto do Railway, **New → Database → PostgreSQL**, com o nome `restore-drill`. Precisa ser a mesma versão de produção (18) e ter a extensão `vector`: use o mesmo modelo do serviço `Postgres` (pgvector).
2. **Serviço temporário:** **New → Empty Service**, com o nome `restore-drill-runner`, sem cron e sem pre-deploy, publicado da `main` com `railway up --ci --service restore-drill-runner` (sem ligar ao GitHub, D-575). Variáveis:
   - as do `web` para o Rails subir (`DATABASE_URL` de produção, onde o resultado é registrado, `SECRET_KEY_BASE` = `${{web.SECRET_KEY_BASE}}` (D-630), `AWS_REGION` = `sa-east-1`);
   - `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY` do `catalysthr-restore`;
   - `RESTORE_DATABASE_URL`: a URL privada do `restore-drill`.
3. **Rodar:** **Custom Start Command** `bin/rails backup:restore_drill`. A tarefa:
   - baixa o dump mais recente de `daily/`;
   - restaura com o `pg_restore` 18, sem dono nem privilégios;
   - conta as linhas de cada tabela e lê a versão do schema;
   - grava em `backup_runs` (tipo `restore_drill`) o tempo, o tamanho e as conferências.
4. **Conferir:** no console de produção (`railway run bin/rails console`, registrado no controle de acessos, RN-20-053), olhar o resultado com `BackupRun.restore_drill.latest_first.first`.
   - as contagens batem, por amostragem, com as de produção na hora do dump;
   - o `schema_version` é o da última migração publicada antes do dump;
   - o tempo total, incluindo os passos manuais, fica abaixo das 4 horas da RN-20-045.
   - Quando o ponto existir (spec 10), conferir também o último NSR de cada empregador.
5. **Limpar:**
   - [ ] apagar os serviços `restore-drill` e `restore-drill-runner`;
   - [ ] desativar e apagar a chave de acesso do `catalysthr-restore`;
   - [ ] anotar abaixo a data, o tempo total e o que deu errado.

## Recuperação depois da perda total do Railway

Os mesmos passos 1 a 3, num projeto novo, que vira a produção. Depois:

- a `DATABASE_URL` do serviço que roda a tarefa é a do banco novo, e a `RESTORE_DATABASE_URL` também;
- publicar a versão da `main` que corresponde ao `schema_version` restaurado;
- apontar o DNS na Cloudflare para o domínio novo do Railway;
- a perda máxima é de 24 horas (o último pg_dump).

## Registro dos ensaios

| Data | Tempo total | Tamanho | Observações |
|---|---|---|---|
