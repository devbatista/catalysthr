# Pré-revisão das minutas jurídicas (2026-10-29)

> Feita pela IA antes do envio à advogada, para reduzir as horas da revisão. **Não é parecer jurídico.**
>
> **Escopo:** as minutas de `juridico/` da etapa 1 (termos de uso, política de privacidade e contrato de tratamento de dados) e a política de privacidade e os termos de uso já publicados no site (`catalysthr.com.br`, v0.1, desde 2026-10-27).
>
> **O que foi feito:**
> 1. coerência das minutas com as specs, as decisões e o código;
> 2. conferência com a LGPD, as resoluções da ANPD e as normas trabalhistas, só em fontes oficiais.
>
> Nenhuma minuta foi alterada. As correções sugeridas esperam a aprovação do responsável.

## 1. Lacunas principais

### 1.1 Não existe contrato comercial
- **Fato:**
  - o contrato de tratamento de dados (DPA) completa um "Contrato Principal" que não existe;
  - os termos de uso dizem que planos, cobrança, inadimplência e cancelamento ficam "no contrato comercial, ainda a redigir";
  - a contratação no sistema (cadastro pelo admin e checkout do cliente) não pede aceite de nenhum contrato. A tabela `legal_documents` só tem `terms` e `privacy`.
- **Consequência:** o primeiro cliente entraria sem contrato. Os itens 6.1 a 6.3 do `pacote-juridico.md` (inadimplência do parceiro, teste grátis e cancelamento) não têm onde morar.
- **Decisão pendente:** quem redige a minuta (a IA a partir da spec 19, para a advogada revisar, ou a advogada do zero) e como o cliente aceita (aceite eletrônico no checkout e no cadastro, ou assinatura).

### 1.2 O site já publicou textos sem revisão
- **Fato:** `politica-de-privacidade.html` e `termos-de-uso.html` estão no ar desde 2026-10-27 (v0.1).
- **Consequência:** eles já são a posição pública da DevBatista e precisam entrar no escopo da advogada. Os pontos 2.3 e 2.4 abaixo também aparecem neles.

## 2. Minutas e site comparados com o sistema

| # | O texto diz | O sistema hoje | Fonte | Ajuste sugerido |
|---|---|---|---|---|
| 2.1 | DPA, Anexo III: "Recuperação de desastre com perda máxima de 5 minutos" | Sem PITR. A perda máxima hoje é de 24 horas (pg_dump diário) | D-508; `plano-de-fases.md`, fase de validação | Escrever "até 24 horas" até contratar o PITR |
| 2.2 | Termos 3.3: desbloqueio "por e-mail ou por código no WhatsApp" | Só por e-mail | `config/initializers/devise.rb` (`unlock_strategy = :email`) | Tirar o WhatsApp até a Twilio |
| 2.3 | Política 4.3: os dados "não ficam guardados" pelos fornecedores de IA. Site, item 4: serviços "contratados para não guardar o conteúdo" | Retenção zero pedida, sem confirmação por escrito. Mesmo com ela, a Anthropic pode guardar por até 2 anos o conteúdo sinalizado pelos sistemas de segurança, e guarda o esquema JSON das saídas estruturadas por 24 horas | `pendencias-fornecedores.md` (Anthropic) | Citar as exceções. Não usar IA com dados reais antes da confirmação, como já prevê a D-637 |
| 2.4 | Termos 3.1 e site, item 6: passkeys | Ainda não existem | Spec 16, fase 2 | Tirar do site agora; manter na minuta só se entrar antes do primeiro cliente |
| 2.5 | Política, item 8, e DPA, Anexo III: varredura de vírus | Ainda não existe | Spec 08, D-606 | Manter, se a spec 08 entrar antes do primeiro cliente |
| 2.6 | DPA, Anexo III: MFA da equipe em todas as ferramentas de infraestrutura; acesso ao banco de produção registrado | MFA confirmado na AWS e na Cloudflare. Sentry pendente. Railway e GitHub sem registro. O acesso ao banco (`railway ssh` e console) não tem registro conferido | `contas-infraestrutura.md` | Confirmar ou retirar |
| 2.7 | DPA, Anexo III: certificado A1 no KMS | Fase 3 | Spec 13 | Dizer "quando o módulo de ponto estiver contratado" |
| 2.8 | DPA, nota 4: Mercado Pago e Asaas tratam "os dados do Cliente, sem dados de colaboradores" | Recebem razão social, CNPJ, endereço e o e-mail do contrato, que pode ser o do responsável (uma pessoa) | D-635, D-636 | **Interpretação:** são fornecedores da DevBatista como controladora dos dados de cobrança (assim já diz a política do site), não suboperadores dos dados dos colaboradores. A advogada confirma |
| 2.9 | Política, item 7: tabela de prazos | Faltam o FGTS (5 anos) e a auditoria (5 anos) | Spec 05, seção 4.4 | Completar a tabela |

**Conferidos e coerentes:**
- bloqueio após 5 tentativas;
- registro do aceite (versão, data, hora, IP e navegador: tabela `consents`);
- horário de silêncio com feriados (RN-15-031);
- 12 meses de leitura para o ex-colaborador (RN-16-050);
- backups apagados em 35 dias (regras `backups-35-dias` e `versoes-antigas-35-dias` no S3);
- Cloudflare sem proxy, sem acesso aos dados (D-503);
- Railway nos EUA, Virgínia (D-500);
- aviso de 30 dias antes de anonimizar (P-05-15);
- exportação em JSON, CSV e ZIP (spec 05);
- impersonate somente leitura e com máscara (D-592).

## 3. Minutas comparadas com as normas

| # | Norma (fato) | O que muda nas minutas |
|---|---|---|
| 3.1 | **Transferência internacional (Res. CD/ANPD 19/2024):** as cláusulas-padrão valem só se adotadas na íntegra, sem alteração; num contrato maior, as Seções I a III vão como anexo (art. 16). O prazo para contratos existentes já venceu (12 meses da publicação). A Opção A exige um controlador entre as partes; a Opção B é para duas operadoras sob instrução de um terceiro controlador (Cláusula 4) | O DPA precisa de **duas variantes**: empresa direta → DevBatista (Opção A) e parceiro → DevBatista (Opção B). Isso responde à nota 1 do DPA (separar em dois). O Anexo II leva o texto integral. Todo contrato novo já nasce com as cláusulas |
| 3.2 | **Transparência da transferência (Res. 19/2024, art. 17):** o controlador publica, em página própria ou com destaque na política, a forma, a duração, a finalidade, o país de destino, a identidade e o contato do controlador, o uso compartilhado, as responsabilidades e as medidas de segurança e os direitos do titular, inclusive o de peticionar à ANPD. Pedidos de acesso às cláusulas são respondidos em 15 dias | A seção 6 da política modelo está curta: falta esse conteúdo mínimo. A política do site (DevBatista como controladora dos dados de cobrança) também precisa dele |
| 3.3 | **Incidentes (Res. CD/ANPD 15/2024):** o controlador comunica a ANPD e os titulares em 3 dias úteis (art. 6º §1º e art. 9º), em dobro para pequeno porte. **Não há prazo regulatório para o operador.** O controlador registra todo incidente por 5 anos (art. 10) | O prazo do DPA (cláusula 9.1) é contratual. Precisa caber nos 3 dias úteis da controladora, ou seja, 24 a 48 horas, como a nota 2 sugere |
| 3.4 | **Encarregado (Res. CD/ANPD 18/2024):** para o operador, é facultativo e conta como boa prática (art. 6º). Quem indica publica o nome e os contatos com destaque (arts. 8º e 9º) | Responde ao item 1.7 do pacote: a DevBatista não é obrigada como operadora. Como o site já indica um encarregado, a publicação está feita |
| 3.5 | **Direitos do titular (LGPD, arts. 18 e 19):** o prazo de 15 dias está no art. 19, II, e vale só para a **declaração completa** de acesso; a confirmação simplificada é imediata (art. 19, I). Para os demais direitos, o art. 18 §5º remete a um regulamento que a ANPD ainda não publicou | A política modelo e o site dizem "15 dias" para tudo, e o site cita o art. 19. Sugestão: manter os 15 dias como compromisso próprio, sem atribuí-los ao art. 19 para todos os pedidos, e citar a resposta imediata da confirmação simplificada |
| 3.6 | **Lista de direitos (LGPD, art. 18):** nove incisos | A política modelo e o site não citam o VI (eliminação dos dados tratados com consentimento) nem o VIII (informação sobre a possibilidade de não consentir e as consequências), relevantes para a selfie e o WhatsApp |
| 3.7 | **Informações ao titular (LGPD, art. 9º):** finalidade, forma e duração, controlador e contato, compartilhamento, responsabilidades dos agentes e direitos | A política modelo cobre o essencial. Falta deixar explícitas as **responsabilidades dos agentes** (inciso VI) |
| 3.8 | **Cookies (Guia da ANPD, 2022, p. 20):** para cookies estritamente necessários, o consentimento não é a base adequada, mas a informação ao titular é devida | Responde à nota 6 da política: basta um parágrafo sobre os cookies essenciais na própria política, sem banner de consentimento |
| 3.9 | **Pequeno porte (Res. CD/ANPD 2/2022):** microempresas e startups têm prazos em dobro e dispensa do encarregado (com canal obrigatório), **exceto** em tratamento de alto risco, que exige um critério geral (larga escala, ou impacto significativo em direitos) e um específico (por exemplo, dados sensíveis) | Não está claro se a DevBatista se enquadra: ela trata dados de saúde. Pergunta para a advogada. Até a resposta, não contar com os prazos em dobro |

**Prazos de retenção (tabela da spec 05, item 1.1 do pacote):**
- **ASO e saúde ocupacional, 20 anos:** confere com a NR-7, item 7.6.1.1 (no mínimo 20 anos após o desligamento).
- **Ponto, 5 anos:** a referência "Portaria 671" da spec 05 não se sustenta, porque a Portaria não fixa prazo em anos (o Anexo IX, item 7, diz "prazo mínimo legal"). A base é a prescrição da CLT, art. 11 (5 anos, até 2 anos após o fim do contrato).
- **FGTS, 5 anos:** confere com o STF (ARE 709.212, Tema 608) e com a Lei 13.932/2019, que tirou a prescrição trintenária do art. 23 §5º da Lei 8.036.
- **Folha e eSocial, 10 anos:** não conferidos em fonte oficial. Ficam para a advogada.

**Contribuição sindical (item 3.5 do pacote, etapa 2):** os arts. 578 e 579 da CLT exigem autorização prévia e expressa (Lei 13.467/2017). A contribuição **assistencial** é outro caso: pelo STF (Tema 935), pode ser cobrada de toda a categoria, com direito de oposição. A spec 12 (RN-12-055) só trata da sindical. Fica para a fase 4.

## 4. Achado fora do escopo: o NSR do ponto

- **Fato:** a Portaria 671, Anexo IX (requisitos do REP-P), item 6, diz: *"Cada estabelecimento terá sua própria sequência de NSR, consistindo em numeração sequencial em incrementos unitários, iniciando-se em 1 na primeira operação do REP em relação ao estabelecimento"*. A fonte é o texto compilado de 21/07/2026.
- **Divergência:** a spec 10 (P-10-02, tabela `nsr_counters` com um contador por empresa) e o `AGENTS.md` dizem "NSR sequencial **por empregador**".
- **Consequência:** se a regra é por estabelecimento, uma empresa com filiais teria o NSR errado no AFD, e a validação do arquivo falharia. É invariante do ponto: muda o banco e o AFD.
- **Mesmo anexo, itens 4 e 5:** o coletor pode, **excepcionalmente**, ficar off-line, com envio posterior. Isso é relevante para a D-064 (marcação só online, item 4.4 do pacote).
- **Mesmo anexo, item 2:** o relógio fica sincronizado com a Hora Legal Brasileira, com variação máxima de 30 segundos.
- **Próximo passo:** decisão antes da fase 3, com a conferência do jurídico (item 4.6 do pacote).

## 5. O que continua com a advogada

Itens que dependem de interpretação ou de jurisprudência:
- **IA:** a base legal para a IA ler documentos de saúde e o CID (2.1).
- **Atos eletrônicos:**
  - a validade da ciência eletrônica e da recusa com testemunhas (3.1, 3.2);
  - o pedido de demissão sem assinatura (3.3);
  - os contratos assinados no papel (3.4);
  - a desconexão (3.6);
  - o convite por WhatsApp (3.7).
- **Bases legais "a validar" da política:** localização no ponto, raça e deficiência, e avaliação com teste de balanceamento.
- **Contratos:**
  - limitação de responsabilidade nos termos (11.3, com o CDC) e no DPA (cláusula 13);
  - cláusulas comerciais (6.1 a 6.3) e o contrato comercial (seção 1.1).
- **LGPD:**
  - o enquadramento como pequeno porte (3.9);
  - os prazos de folha e eSocial;
  - o modelo em camadas (política da empresa feita a partir do nosso modelo).
- **Revisão final:** das minutas e dos textos do site.

## 6. Decisões do responsável

1. **Contrato comercial:** quem redige a minuta e como o cliente aceita (seção 1.1).
2. **Site:** corrigir já os pontos 2.3, 2.4 e 3.5, que estão publicados.
3. **Minutas:** aplicar as correções das seções 2 e 3 antes do envio, para a advogada receber textos coerentes.
4. **NSR:** abrir a decisão sobre a sequência por estabelecimento antes da fase 3 (seção 4).

## Fontes oficiais consultadas

- LGPD (Lei 13.709/2018): https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm
- Regulamentos da ANPD (lista vigente): https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd
- Res. CD/ANPD 2/2022: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-2-de-27-de-janeiro-de-2022
- Res. CD/ANPD 15/2024: https://bibliotecadigital.mj.gov.br/bitstream/1/12879/2/RES_ANPD_2024_15.html
- Res. CD/ANPD 18/2024: https://bibliotecadigital.mj.gov.br/bitstream/1/13151/1/RES_ANPD_2024_18.html
- Res. CD/ANPD 19/2024: https://www.gov.br/anpd/pt-br/acesso-a-informacao/institucional/atos-normativos/regulamentacoes_anpd/resolucao-cd-anpd-no-19-de-23-de-agosto-de-2024
- Guia de cookies da ANPD (2022): https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia-orientativo-cookies-e-protecao-de-dados-pessoais.pdf
- NR-7: https://www.gov.br/trabalho-e-emprego/pt-br/acesso-a-informacao/participacao-social/conselhos-e-orgaos-colegiados/comissao-tripartite-partitaria-permanente/normas-regulamentadora/normas-regulamentadoras-vigentes/nr-07-atualizada-2022-1.pdf
- Portaria MTP 671/2021 (compilada em 21/07/2026): https://www.gov.br/trabalho-e-emprego/pt-br/assuntos/legislacao/portarias-1/portarias-vigentes-3/WORDPortarian671de8denovembrode2021compilada21.07.2026.pdf
- CLT: https://www.planalto.gov.br/ccivil_03/decreto-lei/del5452.htm
- Lei 13.467/2017: https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2017/lei/l13467.htm
- Lei 8.036/1990 (FGTS): https://www.planalto.gov.br/ccivil_03/leis/l8036consol.htm
- STF, Tema 608 (ARE 709.212): https://portal.stf.jus.br/jurisprudenciaRepercussao/verAndamentoProcesso.asp?incidente=4294417&numeroProcesso=709212&classeProcesso=ARE&numeroTema=608
- STF, Tema 935 (ARE 1.018.459): https://portal.stf.jus.br/jurisprudenciaRepercussao/verAndamentoProcesso.asp?incidente=5112803&numeroProcesso=1018459&classeProcesso=ARE&numeroTema=935

**Limites da conferência:**
- os arts. 578 e 579 foram lidos na Lei 13.467, não no texto compilado da CLT;
- o Tema 935 foi lido no Informativo 1200 do STF, não no acórdão;
- não foi conferido se há versão mais nova do Guia de cookies.
