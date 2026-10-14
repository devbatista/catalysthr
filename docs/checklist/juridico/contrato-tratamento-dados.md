# Contrato de Tratamento de Dados Pessoais (DPA)

> **MINUTA v0.1 — 2026-10-13 — para revisão jurídica. Não usar.**
> Modelo único para duas situações:
> - **Contratação direta:** a DevBatista é **operadora**, e a empresa cliente é a **controladora** (D-124).
> - **Contratação por parceiro:** o parceiro é **operador** da empresa cliente, e a DevBatista é **suboperadora** do parceiro (D-080). O parceiro deve ter, com cada empresa cliente, um contrato com obrigações equivalentes.
>
> Os campos `{{...}}` serão preenchidos. Os prazos marcados "a definir" precisam de decisão. As dúvidas para o jurídico estão no fim.

## Partes

**DevBatista**: {{RAZAO_SOCIAL_DEVBATISTA}}, CNPJ {{CNPJ_DEVBATISTA}}, com sede em {{ENDERECO_DEVBATISTA}}, fornecedora da plataforma CatalystHR ("**DevBatista**").

**Cliente**: {{RAZAO_SOCIAL_CLIENTE}}, CNPJ {{CNPJ_CLIENTE}}, com sede em {{ENDERECO_CLIENTE}}, que é ( ) a empresa controladora, na contratação direta, ou ( ) o parceiro operador, na contratação por parceiro ("**Cliente**").

Este contrato completa o contrato comercial {{REFERENCIA_CONTRATO_COMERCIAL}} (o "**Contrato Principal**").

## Cláusula 1 — Definições

Os termos têm o sentido da Lei 13.709/2018 (LGPD). "Plataforma" é o CatalystHR. "Dados" são os dados pessoais tratados na Plataforma por conta do Contrato Principal.

## Cláusula 2 — Objeto e papéis

2.1. A DevBatista trata os Dados **somente** para prestar o serviço da Plataforma, conforme o Contrato Principal, este contrato e as instruções documentadas do Cliente.

2.2. A descrição do tratamento (titulares, categorias de dados, finalidades, duração) está no **Anexo I**.

2.3. Na contratação por parceiro, o Cliente garante que tem autorização da controladora para contratar a DevBatista como suboperadora e repassa à DevBatista as instruções da controladora.

## Cláusula 3 — Instruções

3.1. A configuração da Plataforma feita pelo Cliente ou pela controladora (módulos, funções de IA, prazos, perfis de acesso) conta como instrução documentada.

3.2. A DevBatista avisa o Cliente se entender que uma instrução viola a LGPD.

## Cláusula 4 — Confidencialidade

As pessoas da DevBatista com acesso aos Dados têm dever de sigilo. O acesso da equipe de suporte é registrado e, na simulação de acesso a uma conta (impersonate), é **somente leitura**, com os dados sensíveis mascarados.

## Cláusula 5 — Segurança

A DevBatista mantém as medidas técnicas e administrativas do **Anexo III** e pode melhorá-las sem reduzir o nível de proteção.

## Cláusula 6 — Suboperadores

6.1. O Cliente autoriza os suboperadores do **Anexo IV**.

6.2. A DevBatista avisa o Cliente com **{{PRAZO_AVISO_SUBOPERADOR}} dias** de antecedência sobre a inclusão ou a troca de um suboperador. O Cliente pode se opor de forma fundamentada. *(Prazo a definir.)*

6.3. A DevBatista impõe aos suboperadores obrigações equivalentes às deste contrato e responde por eles perante o Cliente, nos termos da lei.

## Cláusula 7 — Transferência internacional

7.1. Parte dos suboperadores trata Dados fora do Brasil (Anexo IV).

7.2. A transferência segue o art. 33 da LGPD, por meio das **cláusulas-padrão contratuais** aprovadas pela ANPD (Resolução CD/ANPD nº 19/2024), incorporadas como **Anexo II**. *(Confirmar a norma e a forma de incorporação.)*

## Cláusula 8 — Direitos dos titulares

A Plataforma permite que a controladora atenda os titulares (acesso, correção, portabilidade, eliminação, informação), com o tipo de solicitação "Privacidade/LGPD" e os relatórios de dados. A DevBatista encaminha à controladora, sem responder diretamente, qualquer pedido de titular que receber.

## Cláusula 9 — Incidentes de segurança

9.1. A DevBatista comunica ao Cliente, em até **{{PRAZO_COMUNICACAO_INCIDENTE}} horas** depois de tomar conhecimento, qualquer incidente que possa trazer risco ou dano relevante aos titulares. *(Prazo a definir, compatível com o prazo da controladora junto à ANPD.)* A comunicação informa:

- a descrição e a data do incidente;
- as categorias de dados e os titulares afetados;
- as medidas tomadas;
- um relatório com os afetados por empresa.

9.2. A comunicação à ANPD e aos titulares cabe à **controladora**. A DevBatista colabora com as informações de que ela precisar.

## Cláusula 10 — Fim do contrato: devolução e eliminação

10.1. No fim do Contrato Principal, a controladora:

- recebe a **exportação completa** dos Dados (JSON e CSV por entidade e todos os arquivos, num ZIP protegido por senha);
- mantém o acesso somente leitura por **90 dias**.

10.2. Depois disso, a DevBatista **elimina** os Dados da Plataforma. As cópias de segurança expiram em até **35 dias**.

10.3. Os dados que a lei obriga a guardar passam a ser responsabilidade da controladora, que os recebe na exportação.

## Cláusula 11 — Retenção durante o contrato

A Plataforma aplica a tabela de prazos de retenção (Anexo I, item 6) e anonimiza ou exclui os Dados vencidos, com aviso prévio de 30 dias à controladora. A controladora pode suspender a exclusão em caso de processo judicial.

## Cláusula 12 — Auditoria e informações

A DevBatista fornece as informações necessárias para demonstrar o cumprimento deste contrato, incluindo as certificações dos principais suboperadores, em até **{{PRAZO_RESPOSTA_AUDITORIA}} dias** do pedido. Auditorias presenciais seguem as condições do Contrato Principal. *(A definir.)*

## Cláusula 13 — Responsabilidade

{{CLAUSULA_RESPONSABILIDADE}} *(A redigir pelo jurídico, alinhada ao Contrato Principal e aos arts. 42 a 45 da LGPD.)*

## Cláusula 14 — Vigência e foro

Este contrato vale enquanto houver tratamento de Dados por conta do Contrato Principal. Fica eleito o foro de {{FORO}}.

---

## Anexo I — Descrição do tratamento

1. **Titulares:** colaboradores, estagiários, prestadores (PJ e autônomos), sócios, dependentes, candidatos e usuários da Plataforma.
2. **Categorias de dados:** identificação e contato; vínculo e remuneração; documentos; dados bancários; dependentes; ponto (marcações, localização, IP, selfie com consentimento); uso da Plataforma; avaliações. **Sensíveis:** saúde, deficiência, raça e cor, filiação sindical.
3. **Finalidades:** gestão de RH, admissão, documentos, solicitações, ponto eletrônico, folha, eSocial, recrutamento, avaliação, assistente com IA, comunicações e suporte.
4. **Operações:** coleta, armazenamento, consulta, processamento, transmissão ao eSocial, exportação, anonimização e eliminação.
5. **Duração:** a do Contrato Principal, mais o período de encerramento (Cláusula 10).
6. **Retenção:** tabela da spec 05, seção 4.4 *(a validar pelo jurídico)*.

## Anexo II — Cláusulas-padrão contratuais da ANPD

*(Incorporar o texto aprovado pela ANPD.)*

## Anexo III — Medidas de segurança

- Conexões somente por HTTPS, com HSTS e cabeçalhos de segurança.
- Dados sensíveis criptografados no banco. Arquivos em armazenamento privado com criptografia (AWS S3 em São Paulo, SSE-KMS). Certificado digital do empregador guardado com chave no AWS KMS.
- Isolamento lógico entre empresas, com controles na aplicação.
- Controle de acesso por perfil e escopo. MFA obrigatório para perfis de acesso amplo. Confirmação de senha para ver dados sensíveis.
- Trilha de auditoria e registro de acessos a dados sensíveis, guardados por 5 anos.
- Varredura de vírus nos arquivos enviados.
- Dados pessoais fora dos logs e das ferramentas de monitoramento.
- Backups diários criptografados, guardados por 35 dias, com ensaio de restauração a cada 3 meses. Recuperação de desastre com perda máxima de 5 minutos.
- MFA obrigatório para a equipe nas ferramentas de infraestrutura; acesso ao banco de produção registrado.
- Análise automática de vulnerabilidades no código e nas dependências.
- IA com fornecedores em retenção zero.

## Anexo IV — Suboperadores

| Suboperador | Serviço | Local |
|---|---|---|
| Amazon Web Services | Armazenamento de arquivos e backups, chaves, envio de e-mails | Brasil (São Paulo) |
| Railway | Hospedagem da aplicação e do banco de dados | EUA |
| Anthropic | Inteligência artificial, com retenção zero | EUA |
| Voyage AI | Inteligência artificial (embeddings), com retenção zero | EUA |
| Twilio | WhatsApp e SMS | EUA |
| Sentry | Monitoramento de erros, sem dados pessoais | EUA |
| Cloudflare | DNS, sem acesso aos dados | Global |
| Mercado Pago e Asaas | Cobrança e nota fiscal do **Cliente**, sem dados de colaboradores | Brasil |

---

## Notas para o jurídico (remover antes de usar)

1. **Modelo único** para a contratação direta e para a contratação por parceiro: é melhor separar em dois documentos?
2. **Prazos a definir:** aviso de novo suboperador (6.2), comunicação de incidente (9.1) e resposta a auditoria (12). Sugestão para avaliar: o prazo de comunicação de incidente da controladora à ANPD (pelo que sabemos, 3 dias úteis pela Resolução CD/ANPD nº 15/2024, a confirmar) pede um prazo curto da DevBatista, por exemplo 24 a 48 horas.
3. **Cláusulas-padrão da ANPD:** confirmar a norma vigente e se é preciso incorporar o texto integral.
4. **Mercado Pago e Asaas** tratam os dados do Cliente como contratante, e não os dados dos colaboradores. Devem constar como suboperadores aqui?
5. **Responsabilidade (cláusula 13):** limites e solidariedade na cadeia controladora, parceiro e DevBatista.
