# Site institucional (checklist)

> Última atualização: 2026-10-27
> D-631. Código em `devbatista/catalysthr-site` (privado), local em `~/dev/html_css/catalysthr`. Destrava o novo pedido de saída do sandbox do SES.
>
> Legenda: **[você]** = feito por você (painel, decisão); **[Claude]** = posso fazer pela linha de comando, com o seu OK.

## 1. Conteúdo

- [x] **[Claude]** Página inicial com as cenas guiadas pela rolagem, termos de uso, política de privacidade e 404, conferidas no computador (1440 px) e no celular (390 px) (2026-10-27)
- [x] **[Claude]** Repositório privado `devbatista/catalysthr-site` criado
- [ ] **[você]** Endereço da sede da DevBatista, para os termos de uso (item 1.1)
- [ ] **[você]** Foro dos termos de uso (item 13)
- [ ] **[você]** Nome do encarregado de dados, para a política de privacidade (item 9)
- [ ] **[Claude]** Preencher os três campos e montar sem o aviso `⟦A PREENCHER⟧`

Os termos saem sem a cláusula de limitação de responsabilidade (11.3 da minuta), que depende do jurídico.

## 2. Publicação

- [ ] **[você]** HostGator: cadastrar `catalysthr.com.br` no cPanel (domínio adicional) e anotar a pasta e o IP do servidor
- [ ] **[você]** Cloudflare: registros `A` de `catalysthr.com.br` e de `www` para o IP da HostGator, **sem proxy** (D-503). Não mexer nos registros do SES (DKIM, `bounce`, DMARC) nem no `admin` e no `*.painel`
- [ ] **[você]** HostGator: SSL (AutoSSL) emitido para `catalysthr.com.br` e `www`
- [ ] **[você]** Enviar o conteúdo de `dist/` (com o `.htaccess`) para a pasta do domínio
- [ ] **[Claude]** Conferir no ar: HTTPS, redirecionamento para `www`, URLs sem `.html`, 404, cabeçalhos de segurança e as páginas legais

## 3. SES

- [ ] **[Claude]** Novo pedido de saída do sandbox (resposta ao caso 179201169800267 ou pedido novo), com o site, a política de privacidade, um exemplo de e-mail (o convite) e o volume previsto
- [ ] Resposta da AWS
