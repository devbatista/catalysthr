# Site institucional (checklist)

> Última atualização: 2026-10-27
> D-631. Código em `devbatista/catalysthr-site` (privado), local em `~/dev/html_css/catalysthr`. Destrava o novo pedido de saída do sandbox do SES.
>
> Legenda: **[você]** = feito por você (painel, decisão); **[Claude]** = posso fazer pela linha de comando, com o seu OK.

## 1. Conteúdo

- [x] **[Claude]** Página inicial com as cenas guiadas pela rolagem, termos de uso, política de privacidade e 404, conferidas no computador (1440 px) e no celular (390 px) (2026-10-27)
- [x] **[Claude]** Repositório privado `devbatista/catalysthr-site` criado
- [x] **[você]** Endereço da sede da DevBatista, para os termos de uso (item 1.1): Rua Padre Fernando Pedreira de Castro, 30, Jurubatuba, São Paulo/SP, CEP 04696-180 (2026-10-27)
- [x] **[você]** Foro dos termos de uso (item 13): Comarca de São Paulo/SP (2026-10-27)
- [x] **[você]** Nome do encarregado de dados, para a política de privacidade (item 9): Rafael Batista (2026-10-27)
- [x] **[Claude]** Preencher os três campos nas páginas legais (2026-10-27)

Os termos saem sem a cláusula de limitação de responsabilidade (11.3 da minuta), que depende do jurídico.

## 2. Publicação

- [x] **[você]** HostGator: `catalysthr.com.br` cadastrado no cPanel (domínio adicional), pasta `/home1/raf32916/catalysthr.com.br`, IP 69.6.212.238 (2026-10-27)
- [x] **[você]** Cloudflare: registros `A` de `catalysthr.com.br` e de `www` para o IP da HostGator, **sem proxy** (D-503). Não mexer nos registros do SES (DKIM, `bounce`, DMARC) nem no `admin` e no `*.painel` (2026-10-27)
- [x] **[você]** HostGator: SSL (AutoSSL, Let's Encrypt) emitido para `catalysthr.com.br` e `www`, válido até 2027-01-25 e renovado pela HostGator (2026-10-27)
- [x] **[você]** Publicação por FTP a cada push na `main` do `catalysthr-site` (GitHub Actions, `FTP-Deploy-Action`, sem `ferramentas/` e `README.md`) (2026-10-27)
- [x] **[Claude]** Conferido no ar: HTTPS válido, `http` e domínio sem `www` redirecionam para `https://www.catalysthr.com.br`, URLs sem `.html`, 404, cabeçalhos de segurança (CSP, HSTS, `X-Frame-Options`), cache, páginas legais preenchidas e arquivos internos com 404 (2026-10-27)

## 3. SES

- [ ] **[Claude]** Novo pedido de saída do sandbox (resposta ao caso 179201169800267 ou pedido novo), com o site, a política de privacidade, um exemplo de e-mail (o convite) e o volume previsto
- [ ] Resposta da AWS
