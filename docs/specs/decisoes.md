# Registro de decisões

Decisões tomadas para o CatalystHR. Cada spec de módulo segue o que está registrado aqui. Mudou uma decisão? Atualize esta tabela com a data e o motivo.

## Formato das specs

| # | Decisão | Data |
|---|---|---|
| D-001 | Specs funcionais e técnicas (histórias, regras, critérios de aceite, modelo de dados, arquitetura) | 2026-10-12 |
| D-002 | Arquivos Markdown em `specs/`, um por módulo, com este registro de decisões | 2026-10-12 |

## Escopo do MVP

A apresentação (`prototype/CatalystRH_visual_identity/CatalystHR MVP.dc.html`, página 14) deixava estes itens como etapa futura. Eles passam a fazer parte do MVP.

| # | Decisão | Data |
|---|---|---|
| D-010 | Ponto eletrônico completo e legal: REP-P conforme a Portaria MTE 671/2021 | 2026-10-12 |
| D-011 | Folha de pagamento completa (cálculo e eSocial) | 2026-10-12 |
| D-012 | WhatsApp apenas para avisos (pendências, status, holerite publicado), com link para o portal | 2026-10-12 |

## Stack técnica

| # | Decisão | Data |
|---|---|---|
| D-020 | Ruby on Rails, versões estáveis mais recentes de Ruby e Rails | 2026-10-12 |
| D-021 | PostgreSQL | 2026-10-12 |
| D-022 | Views em ERB, **sem Hotwire (Turbo/Stimulus) e sem React** | 2026-10-12 |
| D-023 | JavaScript puro, carregado pelo importmap | 2026-10-12 |
| D-024 | CSS com Tailwind (tailwindcss-rails) | 2026-10-12 |
| D-025 | Sidekiq para jobs em segundo plano | 2026-10-12 |
| D-026 | Amazon SES para envio de e-mails, letter_opener em desenvolvimento | 2026-10-12 |
| D-027 | Amazon S3 para armazenamento de arquivos | 2026-10-12 |
| D-028 | Multi-tenancy com schema compartilhado e `tenant_id` | 2026-10-12 |
| D-029 | Autenticação com Devise | 2026-10-12 |
| D-030 | Autorização com CanCanCan | 2026-10-12 |
| D-031 | Hospedagem no Railway | 2026-10-12 |
| D-032 | Testes com RSpec e FactoryBot | 2026-10-12 |
| D-033 | IA pela API da Anthropic (Claude) | 2026-10-12 |
| D-034 | Avisos por WhatsApp pela Twilio | 2026-10-12 |

## White label e canais

| # | Decisão | Data |
|---|---|---|
| D-040 | E-mails saem do domínio do parceiro, verificado no SES | 2026-10-12 |
| D-041 | WhatsApp: número único da plataforma como padrão, com opção de número próprio por parceiro | 2026-10-12 |
| D-042 | Portal do colaborador: site responsivo instalável como PWA | 2026-10-12 |

## Identidade e acesso

| # | Decisão | Data |
|---|---|---|
| D-050 | Um usuário (pessoa) com memberships. A membership de empresa liga usuário e empresa | 2026-10-12 |
| D-051 | Uma membership pode ter vários perfis (por exemplo, colaborador e gestor) | 2026-10-12 |
| D-052 | A equipe do parceiro tem membership usuário + parceiro, com a lista de empresas atendidas | 2026-10-12 |
| D-053 | Os dados trabalhistas ficam em uma entidade própria ligada à membership. Membership sem vínculo empregatício é permitida (por exemplo, consultor) | 2026-10-12 |
| D-054 | Login por CPF ou e-mail, mais senha | 2026-10-12 |

## Ponto eletrônico (REP-P)

| # | Decisão | Data |
|---|---|---|
| D-060 | Marcação pelo celular (PWA), pelo navegador do computador e por totem compartilhado | 2026-10-12 |
| D-061 | Antifraude: geolocalização registrada, cerca virtual por unidade e selfie. ~~Reconhecimento facial~~ saiu do MVP (revisada por D-311) | 2026-10-12 |
| D-062 | Marcação fora da cerca: o RH configura por unidade ou cargo se sinaliza ou bloqueia | 2026-10-12 |
| D-063 | Identificação no totem: CPF + PIN, QR code pessoal e crachá (código de barras ou NFC). ~~Reconhecimento facial~~ saiu do MVP (revisada por D-311) | 2026-10-12 |
| D-064 | Marcação somente online, sem modo offline | 2026-10-12 |
| D-065 | Cálculos de jornada no MVP: horas extras e banco de horas, adicional noturno, escalas (12x36, 6x1, turnos), faltas, atrasos e DSR | 2026-10-12 |

## Folha de pagamento

| # | Decisão | Data |
|---|---|---|
| D-070 | O RH da empresa cliente processa a folha | 2026-10-12 |
| D-071 | A plataforma transmite os eventos ao eSocial diretamente, assinando com o certificado do empregador | 2026-10-12 |
| D-072 | Cálculos no MVP: folha mensal e adiantamento, férias e 13º, rescisão, pró-labore, estágio e autônomos | 2026-10-12 |
| D-073 | Obrigações e saídas no MVP: FGTS Digital, DCTFWeb e guias de INSS e IRRF, relatórios contábeis. ~~Arquivo bancário CNAB~~ foi substituído pela lista de pagamentos PIX (revisada por D-356) | 2026-10-12 |
| D-074 | Regimes tributários: Simples Nacional, Lucro Presumido, Lucro Real e desoneração (CPRB) | 2026-10-12 |
| D-075 | Certificado A1 do empregador guardado criptografado, com chave no AWS KMS | 2026-10-12 |

## LGPD e segurança

| # | Decisão | Data |
|---|---|---|
| D-080 | Papéis: a empresa cliente é controladora, o parceiro é operador e o CatalystHR é suboperador | 2026-10-12 |
| D-081 | Retenção por categoria de dado, seguindo os prazos legais. Vencido o prazo após o desligamento, um job anonimiza ou exclui | 2026-10-12 |
| D-082 | MFA obrigatório para admin CatalystHR, equipe do parceiro e RH; opcional para gestor e colaborador | 2026-10-12 |
| D-083 | Métodos de MFA: app autenticador (TOTP) e códigos de recuperação | 2026-10-12 |
| D-084 | Alterações de dados registradas com PaperTrail | 2026-10-12 |
| D-085 | Tabela própria de eventos de acesso: leitura de dados sensíveis, logins e eventos de segurança, exportações e downloads | 2026-10-12 |
| D-086 | Campos criptografados no banco: CPF, RG e documentos pessoais; salário e dados bancários; dados de saúde; biometria facial | 2026-10-12 |
| D-087 | Direitos do titular exercidos por um tipo de solicitação "Privacidade/LGPD" no portal, respondido pela empresa | 2026-10-12 |
| D-088 | Biometria facial com base no consentimento. Quem recusar marca o ponto por CPF + PIN, QR code ou crachá | 2026-10-12 |
| D-089 | Tempo de sessão por perfil: 30 minutos sem uso para admin, parceiro, RH e gestor; 14 dias para o colaborador no PWA, pedindo a senha de novo para dados sensíveis | 2026-10-12 |

## Ciclo de vida

| # | Decisão | Data |
|---|---|---|
| D-090 | O desligado mantém acesso somente leitura ao portal (holerites, informe de rendimentos, espelhos de ponto, documentos, TRCT) por um período que a empresa configura | 2026-10-12 |
| D-091 | Modelos de processo são copiados quando o processo começa. Edições valem só para os próximos, e cada processo pode ser ajustado à mão | 2026-10-12 |
| D-092 | Limite de plano não bloqueia nada: o parceiro é avisado com 80% e 100% e o excedente é cobrado | 2026-10-12 |
| D-093 | Importação na implantação: planilha modelo na tela, XMLs do eSocial, layouts de outros sistemas de folha (como conversores, D-094 e D-461) e scripts internos da equipe CatalystHR (como importação assistida, D-468) | 2026-10-12 |
| D-094 | Importadores de layout no MVP: Domínio, Questor e Alterdata, mais outros definidos com os parceiros do piloto | 2026-10-12 |

## Inteligência artificial

| # | Decisão | Data |
|---|---|---|
| D-100 | A IA classifica e extrai campos de: RG, CPF, CNH; CTPS digital e PIS; comprovante de residência e certidões; ASO e atestados médicos | 2026-10-12 |
| D-101 | Custo de IA com cota mensal por plano. Passou da cota, avisa e cobra o excedente, sem bloquear (como D-092) | 2026-10-12 |
| D-102 | O assistente busca nos materiais por similaridade (pgvector), e o Claude responde citando a fonte | 2026-10-12 |
| D-103 | Embeddings pela Voyage AI | 2026-10-12 |
| D-104 | Claude Sonnet 5.5 para todas as funções de IA | 2026-10-12 |
| D-105 | Materiais do assistente: PDFs do RH da empresa, modelos do parceiro que as empresas adotam ou ajustam, e perguntas e respostas escritas pelo RH | 2026-10-12 |
| D-106 | O admin CatalystHR mantém uma base de conhecimento sobre o uso do sistema, consultada pelo assistente para parceiros e gestores | 2026-10-12 |
| D-107 | Resumo operacional gerado diariamente por job, com botão para atualizar quando quiser | 2026-10-12 |
| D-108 | Jobs agendados com sidekiq-cron | 2026-10-12 |

## Administração e cobrança

| # | Decisão | Data |
|---|---|---|
| D-110 | A base de conhecimento de uso do sistema (D-106) atende equipe do parceiro, RH, gestores e colaboradores | 2026-10-12 |
| D-111 | Ponto e folha são módulos opcionais contratados pelo parceiro, que pode usar em todas as empresas da carteira | 2026-10-12 |
| D-112 | Cobrança recorrente por gateway (assinatura mais excedente calculado pelo sistema) | 2026-10-12 |
| D-113 | Gateway: Mercado Pago | 2026-10-12 |
| D-114 | ~~NFS-e emitida fora da plataforma~~ (revisada por D-560: emitida pela plataforma, pelo Asaas) | 2026-10-12 |
| D-115 | Planos e preços de módulos cadastráveis pelo admin CatalystHR | 2026-10-12 |
| D-116 | Pagamento em atraso: avisos escalonados e, com 15 dias, o parceiro e as empresas ficam em somente leitura. O ponto continua funcionando | 2026-10-12 |

## Contratação direta (empresa sem parceiro)

| # | Decisão | Data |
|---|---|---|
| D-120 | Uma empresa pode contratar o CatalystHR diretamente, sem parceiro. Na empresa, o parceiro é opcional | 2026-10-12 |
| D-121 | A empresa direta também pode ter white label, configurando logo, identidade visual e domínio | 2026-10-12 |
| D-122 | A empresa direta tem planos próprios, com preço por colaborador ativo. Ponto e folha são módulos contratados pela própria empresa. Planos cadastráveis pelo admin (D-115) | 2026-10-12 |
| D-123 | O admin CatalystHR pode transferir uma empresa entre modalidades (direta ↔ parceiro, ou de um parceiro para outro), com todo o histórico, mediante autorização da empresa | 2026-10-12 |
| D-124 | LGPD na empresa direta: a empresa é controladora e o CatalystHR é operador | 2026-10-12 |
| D-125 | As regras de limite, excedente e atraso (D-092, D-101, D-116) também valem para a empresa direta | 2026-10-12 |
| D-126 | O admin CatalystHR mantém uma biblioteca de modelos padrão (processos, tipos de solicitação, materiais), que as empresas diretas e os parceiros podem adotar e ajustar | 2026-10-12 |
| D-127 | A equipe CatalystHR faz a implantação e o suporte das empresas diretas, com acesso equivalente ao de um consultor de parceiro | 2026-10-12 |

## Entrega

| # | Decisão | Data |
|---|---|---|
| D-130 | O MVP sai em uma entrega única. O piloto começa com todos os módulos prontos | 2026-10-12 |

## Convenções e perfis

| # | Decisão | Data |
|---|---|---|
| D-140 | O nome oficial do produto é **CatalystHR** | 2026-10-12 |
| D-141 | Nomes no código (models, tabelas, rotas) em inglês | 2026-10-12 |
| D-142 | Perfis: CatalystHR (superadmin, suporte, financeiro); parceiro (administrador, consultor); empresa (RH administrador, RH analista, gestor, colaborador) | 2026-10-12 |
| D-143 | A contabilidade externa tem perfil próprio: lê os encaminhamentos e relatórios das empresas que atende e confirma o recebimento | 2026-10-12 |
| D-144 | Glossário aprovado com nomes em inglês: Partner, Company, Unit, Department, Position, User, Membership, Employment, ProcessTemplate, Admission, Document, Request, TimeEntry, Payroll, PayrollItem, Plan | 2026-10-12 |
| D-145 | Roteiro padrão das specs, com regras numeradas `RN-<spec>-<nº>` e critérios de aceite `CA-<spec>-<nº>` (Dado / Quando / Então) | 2026-10-12 |
| D-146 | Recrutamento e avaliação de experiência e desempenho entram no MVP, nas specs 21 e 22 | 2026-10-12 |
| D-147 | Assinatura digital continua fora do MVP | 2026-10-12 |

## Multi-tenancy e white label (spec 01)

| # | Decisão | Data |
|---|---|---|
| D-150 | Escopo de tenant com a gem acts_as_tenant | 2026-10-12 |
| D-151 | O tenant do acts_as_tenant é a empresa (Company). Dados do parceiro e visões da carteira usam escopo explícito, só com as empresas autorizadas | 2026-10-12 |
| D-152 | Domínio base: catalysthr.com.br | 2026-10-12 |
| D-153 | Endereços: `<cliente>.painel.catalysthr.com.br`, criado automaticamente pelo sistema para cada parceiro e empresa direta. Domínio próprio fica fora do MVP | 2026-10-12 |
| D-154 | A empresa cliente de um parceiro usa o subdomínio do parceiro e é escolhida depois do login | 2026-10-12 |
| D-155 | Painel e portal do colaborador usam o mesmo endereço. O sistema mostra a área conforme o perfil | 2026-10-12 |
| D-156 | Área administrativa do CatalystHR em admin.catalysthr.com.br | 2026-10-12 |
| D-157 | O admin CatalystHR define o subdomínio. Se trocar, o antigo redireciona para o novo por 90 dias | 2026-10-12 |
| D-158 | Cada subdomínio mostra só as memberships daquela marca. Quem tem vínculos em marcas diferentes entra em cada subdomínio com o mesmo login | 2026-10-12 |
| D-159 | White label personaliza: nome comercial, logo, favicon, ícone e nome do PWA; cores; tela de login; canal de suporte e textos legais | 2026-10-12 |
| D-160 | Sem domínio de e-mail verificado (ou empresa direta sem domínio), os e-mails saem do domínio da plataforma com o nome da marca, por exemplo "Aurora RH <nao-responda@catalysthr.com.br>", com o suporte da marca no reply-to | 2026-10-12 |
| D-161 | O número próprio de WhatsApp é um item adicional do plano, com preço definido pelo admin | 2026-10-12 |
| D-162 | A marca da empresa direta é editada só pela equipe CatalystHR | 2026-10-12 |
| D-163 | A empresa cliente de um parceiro pode mostrar a própria marca | 2026-10-12 |
| D-164 | O white label da empresa direta faz parte do plano, sem cobrança à parte | 2026-10-12 |
| D-165 | Para cada empresa cliente, o parceiro escolhe como a marca dela aparece: logo junto da marca do parceiro, ou marca da empresa substituindo a do parceiro depois do login | 2026-10-12 |
| D-166 | A marca da empresa cliente de parceiro é editada pela equipe do parceiro | 2026-10-12 |
| D-167 | Propostas P-01-01 a P-01-20 da spec 01 aprovadas. Ajustes em P-01-02, P-01-11, P-01-14, P-01-17 e P-01-18 (ver spec 01, seção 10) | 2026-10-12 |
| D-168 | Na transferência de empresa, a marca do parceiro antigo não é copiada. A marca própria da empresa, se existir, continua | 2026-10-12 |

## Identidade e acesso (spec 02)

| # | Decisão | Data |
|---|---|---|
| D-170 | A contabilidade externa é uma entidade própria de escritório contábil, com equipe, ligada às empresas que atende | 2026-10-12 |
| D-171 | O RH administrador da empresa cadastra o escritório contábil ou liga à empresa um escritório já existente | 2026-10-12 |
| D-172 | O escritório contábil tem administrador próprio, que convida e remove os contadores | 2026-10-12 |
| D-173 | CPF obrigatório para todos os usuários | 2026-10-12 |
| D-174 | Prestador PJ é uma pessoa (login por CPF ou e-mail), com o CNPJ no cadastro do vínculo | 2026-10-12 |
| D-175 | O PJ usa portal, documentos e solicitações; envia notas fiscais para conferência e aprovação; participa de integração, avaliação e assistente | 2026-10-12 |
| D-176 | Os vínculos de trabalho ficam em uma única entidade com tipo (CLT, estágio, PJ, autônomo, sócio com pró-labore) | 2026-10-12 |
| D-177 | Convite por e-mail, por WhatsApp ou por link e QR code gerado pelo RH | 2026-10-12 |
| D-178 | Convite e link de primeiro acesso valem 72 horas | 2026-10-12 |
| D-179 | Recuperação de senha por link no e-mail ou código por WhatsApp. O RH não gera link de redefinição | 2026-10-12 |
| D-180 | Senha com no mínimo 8 caracteres, contendo maiúscula, número e símbolo | 2026-10-12 |
| D-181 | 5 tentativas erradas bloqueiam a conta até o desbloqueio por link no e-mail ou código por WhatsApp | 2026-10-12 |
| D-182 | No primeiro acesso: aceite dos termos de uso e da política de privacidade, consentimento de biometria, consentimento de WhatsApp e ativação do MFA (perfis obrigatórios) | 2026-10-12 |
| D-183 | A confirmação de senha para ver dados sensíveis vale 5 minutos | 2026-10-12 |
| D-184 | O MFA pode lembrar o dispositivo por 30 dias | 2026-10-12 |
| D-185 | Suporte e superadmin podem fazer impersonate, informando motivo ou número de chamado, por no máximo 30 minutos | 2026-10-12 |
| D-186 | No impersonate, leituras funcionam normalmente. Escritas rodam em simulação: executam e são desfeitas, sem jobs, e-mails, WhatsApp, uploads nem chamadas externas, com a faixa "Simulação: nada foi salvo" | 2026-10-12 |
| D-187 | No impersonate, dados sensíveis aparecem mascarados, e arquivos de saúde e biometria não abrem | 2026-10-12 |
| D-188 | Propostas P-02-01 a P-02-37 da spec 02 aprovadas. Ajustes em P-02-09, P-02-22 e P-02-37 (ver spec 02, seção 10) | 2026-10-12 |
| D-189 | O fluxo de notas fiscais do prestador PJ fica na spec 12 (folha de pagamento) | 2026-10-12 |
| D-576 | As sessões ficam numa tabela própria (`user_sessions`), e o cookie guarda só o identificador. Cada requisição confere se a sessão continua válida. Motivo: listar e encerrar sessões (RN-02-053) e derrubá-las na hora ao remover um perfil (RN-02-063) exigem o estado no servidor. Sem gem nova | 2026-10-15 |
| D-577 | Os termos de uso e a política de privacidade ficam numa tabela de versões (`legal_documents`), e cada publicação cria uma versão nova. O aceite em `consents` aponta para a versão aceita, e o texto das versões antigas é mantido. Substitui os campos de texto legal da marca (spec 01) | 2026-10-15 |
| D-578 | A marca sem termos ou política próprios usa os da CatalystHR. Até o jurídico revisar as minutas, o primeiro acesso fica atrás de feature flag, sem clientes reais | 2026-10-15 |
| D-579 | O superadmin publica os termos de uso e a política de privacidade da CatalystHR numa tela da área administrativa. Cada publicação cria uma versão nova (D-577), com o autor e a data | 2026-10-15 |
| D-580 | Códigos de MFA errados contam no mesmo contador de tentativas da senha. Com 5 erros, somando os dois, a conta é bloqueada até o desbloqueio (RN-02-031) | 2026-10-15 |
| D-581 | O suporte entra numa empresa direta pela área administrativa: escolhe a empresa, informa o motivo e recebe um token de uso único que abre o subdomínio da empresa, onde age como consultor (P-03-02), com escrita real. A sessão segue a inatividade de 30 minutos da equipe (RN-02-050) e cada acesso entra nos eventos de acesso. O suporte continua sem membership (P-02-01) e só faz login pelo admin (RN-02-004). Usa o mesmo mecanismo de token do impersonate (RN-02-082) | 2026-10-15 |
| D-582 | Quem administra o perfil (RN-02-044, P-02-17) só corrige o e-mail ou o celular e só redefine o MFA de quem não tem acesso a nenhuma outra organização (membership que não esteja revogada) nem papel na equipe CatalystHR. Nos outros casos, quem faz é o suporte CatalystHR. Quando o contato muda, o e-mail antigo recebe um aviso. Motivo: o usuário é único na plataforma, e sem essa regra o RH de uma empresa poderia trocar o e-mail de quem é RH de outra, recuperar a senha e entrar nela | 2026-10-15 |

## Permissões (spec 03)

| # | Decisão | Data |
|---|---|---|
| D-190 | A equipe do gestor são os colaboradores dos departamentos que ele gerencia | 2026-10-12 |
| D-191 | Perfis com permissões fixas. Para RH analista e consultor, o administrador escolhe também quais módulos a pessoa opera | 2026-10-12 |
| D-192 | Dentro de uma empresa, o consultor do parceiro age como RH analista de todas as unidades | 2026-10-12 |
| D-193 | A contabilidade vê: encaminhamentos de admissão, relatórios contábeis da folha, folha, holerites e guias, eventos e retornos do eSocial e a pasta do colaborador | 2026-10-12 |
| D-194 | Propostas P-03-01 a P-03-37 da spec 03 aprovadas. Ajustes em P-03-01 (o administrador do parceiro só tem a visão consolidada), P-03-14, P-03-31 e P-03-35 (ver spec 03, seção 9) | 2026-10-12 |

## Cadastros (spec 04)

| # | Decisão | Data |
|---|---|---|
| D-200 | A empresa (Company) é um empregador: um CNPJ raiz, ou CPF para empregador pessoa física. Matriz e filiais da mesma raiz são uma empresa; raízes diferentes são empresas separadas | 2026-10-12 |
| D-201 | A unidade é um estabelecimento (S-1005), com CNPJ, CNO ou CAEPF próprio opcional. Sem número próprio, usa o da matriz | 2026-10-12 |
| D-202 | Departamentos em árvore dentro de cada unidade (com subdepartamentos) | 2026-10-12 |
| D-203 | Um departamento pode ter vários gestores, e qualquer um deles aprova | 2026-10-12 |
| D-204 | Cargo com nome, CBO, faixa salarial, descrição e requisitos, modelo de admissão e documentos exigidos | 2026-10-12 |
| D-205 | Uma pessoa pode ter vários vínculos na mesma empresa, simultâneos e sucessivos | 2026-10-12 |
| D-206 | Os campos do vínculo seguem os layouts do eSocial (S-2200 para CLT, S-2300 para trabalhador sem vínculo), mais campos próprios para o PJ | 2026-10-12 |
| D-207 | Mudanças de cargo, salário, unidade, departamento e jornada são registros com data de vigência e motivo | 2026-10-12 |
| D-208 | Cadastros pessoais: dependentes, dados bancários e PIX, contato de emergência, escolaridade, raça/cor e deficiência | 2026-10-12 |
| D-209 | Os dados pessoais ficam por empresa. Cada empresa tem a própria ficha da pessoa | 2026-10-12 |
| D-210 | Pelo portal, com validação do RH, o colaborador pede alteração de: endereço e contatos; dados bancários e PIX; dependentes; estado civil, escolaridade e nome social | 2026-10-12 |
| D-211 | A matrícula é sequencial e automática, e o RH pode editar | 2026-10-12 |
| D-212 | Os dados fiscais e previdenciários da empresa (CNAE, FPAS, RAT/FAP, terceiros, regime, desoneração) ficam na spec 12 | 2026-10-12 |
| D-213 | A empresa pode criar campos personalizados simples no cadastro do colaborador | 2026-10-12 |
| D-214 | Propostas P-04-01 a P-04-29 da spec 04 aprovadas sem ajuste | 2026-10-12 |
| D-215 | Consulta de CEP pelo ViaCEP, com a BrasilAPI de reserva | 2026-10-12 |
| D-216 | Coordenadas das unidades: o Nominatim (OpenStreetMap) sugere a posição pelo endereço, e o RH confirma ou ajusta o pino num mapa (Leaflet + OpenStreetMap). Se o endereço não for encontrado, o RH marca no mapa. Substitui a escolha anterior pela Google Geocoding API, para manter custo zero | 2026-10-12 |

## LGPD, segurança e auditoria (spec 05)

| # | Decisão | Data |
|---|---|---|
| D-217 | A tabela de prazos de retenção é única da plataforma, mantida pela equipe CatalystHR e validada pelo jurídico | 2026-10-12 |
| D-218 | Vencido o prazo, os registros são anonimizados e os arquivos são excluídos do S3 | 2026-10-12 |
| D-219 | Trilha de auditoria (PaperTrail) e eventos de acesso guardados por 5 anos | 2026-10-12 |
| D-220 | O RH pode suspender a anonimização de uma pessoa ("retenção por processo"), com número do processo e justificativa, com auditoria | 2026-10-12 |
| D-221 | Também são dados sensíveis: raça/cor, deficiência, filiação sindical e dados dos dependentes (somam-se a D-086) | 2026-10-12 |
| D-222 | No encerramento do contrato, a empresa recebe uma exportação completa, fica 90 dias em somente leitura e depois tudo é excluído | 2026-10-12 |
| D-223 | Dados excluídos ou anonimizados somem de vez quando o último backup que os contém expira, em um ciclo de 35 dias | 2026-10-12 |
| D-224 | Cada empresa cadastra o encarregado de dados (nome e contato), mostrado no portal e na política de privacidade | 2026-10-12 |
| D-225 | Incidente de segurança: a equipe CatalystHR registra o incidente na área admin e avisa as controladoras, que comunicam a ANPD e os titulares | 2026-10-12 |
| D-226 | No incidente, a equipe CatalystHR avisa o parceiro e o RH administrador da empresa (na empresa direta, só o RH administrador) | 2026-10-12 |
| D-227 | Propostas P-05-01 a P-05-33 da spec 05 aprovadas sem ajuste. Os prazos da tabela de retenção (seção 4.4) continuam pendentes de validação jurídica | 2026-10-12 |

## Modelos de processo (spec 06)

| # | Decisão | Data |
|---|---|---|
| D-230 | Têm modelos: admissão, integração (onboarding), desligamento e fluxos de solicitação | 2026-10-12 |
| D-231 | Tipos de item: tarefa, envio de documento, formulário, leitura e aceite, encaminhamento (com confirmação de recebimento) e aprovação | 2026-10-12 |
| D-232 | Adotar um modelo de outro nível (biblioteca → parceiro → empresa) cria uma cópia independente | 2026-10-12 |
| D-233 | Condições opcionais por item: tipo de vínculo, cargo e unidade. Sem condição, o item vale para todos | 2026-10-12 |
| D-234 | O responsável de cada item é definido por papel e vira uma pessoa quando o processo começa | 2026-10-12 |
| D-235 | Prazos relativos a uma data do processo (por exemplo, início ou desligamento), em dias corridos ou úteis | 2026-10-12 |
| D-236 | Dias úteis consideram feriados nacionais mais os da unidade (mesmo calendário do ponto) | 2026-10-12 |
| D-237 | Dependências opcionais entre itens. Sem dependência, o item nasce liberado | 2026-10-12 |
| D-238 | O formulário grava direto na ficha e no vínculo, depois da revisão do RH, e aceita campos livres que ficam só no processo | 2026-10-12 |
| D-239 | A spec 06 define o motor de modelos; a spec 09 define os tipos de solicitação e o fluxo padrão de cada um | 2026-10-12 |
| D-240 | Só o RH administrador cria e edita os modelos da empresa | 2026-10-12 |
| D-241 | Propostas P-06-01 a P-06-20 da spec 06 aprovadas sem ajuste | 2026-10-12 |
| D-242 | Feriados: a equipe CatalystHR carrega os nacionais, os estaduais e os municipais das cidades com unidades de clientes; o RH complementa com feriados e pontos facultativos da unidade | 2026-10-12 |

## Admissão e integração (spec 07)

| # | Decisão | Data |
|---|---|---|
| D-250 | A admissão tem 6 etapas fixas (cadastro inicial, envio de documentos, processamento pela IA, revisão do RH, contabilidade, conclusão), e os itens do modelo se distribuem nelas | 2026-10-12 |
| D-251 | A admissão começa por cadastro manual do RH, a partir do recrutamento (spec 21) ou por importação em lote (spec 18) | 2026-10-12 |
| D-252 | O convite ao portal só sai quando o RH libera | 2026-10-12 |
| D-253 | O sistema gera contrato e termos para imprimir, a partir de modelos com variáveis cadastrados pelo RH. A versão assinada volta para a pasta | 2026-10-12 |
| D-254 | Cadastro inicial mínimo: nome, CPF, celular ou e-mail, tipo de vínculo, cargo, unidade, departamento e data prevista de início | 2026-10-12 |
| D-255 | O S-2200/S-2300 é enviado quando o RH confirma. Se os dados estão incompletos perto do prazo, o sistema oferece o registro preliminar (S-2190) | 2026-10-12 |
| D-256 | O vínculo passa a ativo na data de início. Sem o eSocial aceito (para quem precisa), ativa assim mesmo, com alerta grave ao RH | 2026-10-12 |
| D-257 | Na desistência: o vínculo é cancelado, o sistema gera o S-3000 se o S-2200 já foi enviado, os dados entram na retenção de candidato não contratado e o acesso é revogado | 2026-10-12 |
| D-258 | A etapa de contabilidade é opcional por empresa | 2026-10-12 |
| D-259 | Para CLT, a admissão só conclui com ASO apto validado. ASO inapto gera alerta, e o RH cancela ou reavalia | 2026-10-12 |
| D-260 | O RH confirma a conclusão da admissão | 2026-10-12 |
| D-261 | A admissão controla o contrato de experiência e a prorrogação, com aviso ao RH e ao gestor antes de cada vencimento | 2026-10-12 |
| D-262 | A antecedência do aviso de vencimento da experiência é configurável pela empresa | 2026-10-12 |
| D-263 | PDFs gerados com Prawn | 2026-10-12 |
| D-264 | Propostas P-07-01 a P-07-18 da spec 07 aprovadas sem ajuste | 2026-10-12 |

## Documentos (spec 08)

| # | Decisão | Data |
|---|---|---|
| D-270 | Tipos de documento: base mantida pela plataforma (com extração da IA) mais tipos próprios da empresa (sem extração). Categorias fixas | 2026-10-12 |
| D-271 | Upload aceita PDF, JPG e PNG, até 10 MB | 2026-10-12 |
| D-272 | Vencimento pela validade do próprio documento ou por periodicidade do tipo (ajustável por cargo), com pendência automática para o colaborador | 2026-10-12 |
| D-273 | Documentos gerados pelo sistema (holerites, espelhos, informe, contratos, comprovantes) aparecem na pasta, em categorias próprias | 2026-10-12 |
| D-274 | O colaborador vê toda a própria pasta, menos os tipos marcados como internos | 2026-10-12 |
| D-275 | Aviso de vencimento com antecedência configurável por tipo, de 30 dias por padrão | 2026-10-12 |
| D-276 | O aviso de vencimento vai ao colaborador, ao RH e ao gestor | 2026-10-12 |
| D-277 | O RH envia documentos em lote para várias pessoas. A IA identifica o tipo e a pessoa, e o RH confirma antes de distribuir | 2026-10-12 |
| D-278 | O RH pode pedir um documento avulso, que vira pendência no portal | 2026-10-12 |
| D-279 | Ciência eletrônica: o RH publica um documento pedindo ciência, e o colaborador confirma no portal (data, hora, IP e versão registrados) | 2026-10-12 |
| D-280 | O colaborador vê só a versão vigente de cada documento | 2026-10-12 |
| D-281 | O RH pode baixar a pasta inteira em ZIP, com confirmação de senha e evento de acesso | 2026-10-12 |
| D-282 | Propostas P-08-01 a P-08-22 da spec 08 aprovadas sem ajuste | 2026-10-12 |

## Solicitações e aprovações (spec 09)

| # | Decisão | Data |
|---|---|---|
| D-290 | Status das solicitações como na apresentação: Aberta → Em análise → Aguardando informação → Aguardando aprovação → Em execução → Concluída; Reprovada ou Cancelada, sempre com justificativa | 2026-10-12 |
| D-291 | Tipos do sistema: férias, atualização cadastral, declarações e documentos, envio de comprovantes, geral, desligamento, Privacidade/LGPD, atestado e afastamento, ajuste de marcação de ponto, abono e compensação, adiantamento e benefícios | 2026-10-12 |
| D-292 | A empresa cria tipos próprios, com campos e fluxo pelo motor da spec 06. Nos tipos do sistema, as regras são fixas e o fluxo é ajustável | 2026-10-12 |
| D-293 | Etapa vencida: avisa o responsável e o RH e, depois de um tempo, escala (gestor → gestor acima → RH) | 2026-10-12 |
| D-294 | O tempo até escalar é configurável por tipo, com 2 dias úteis de padrão | 2026-10-12 |
| D-295 | O pedido de férias mostra o saldo e valida as regras da CLT. Bloqueia o que é ilegal, e o RH pode forçar com justificativa | 2026-10-12 |
| D-296 | Desligamento iniciado pelo RH, pedido pelo gestor ao RH, ou pedido de demissão do colaborador pelo portal | 2026-10-12 |
| D-297 | Desligamento = solicitação (pedido e aprovação) + processo de desligamento (modelo da spec 06). Rescisão na spec 12, eSocial na spec 13 | 2026-10-12 |
| D-298 | O desligamento controla: pagamento em 10 dias, aviso prévio, prazo do eSocial e exame demissional | 2026-10-12 |
| D-299 | Declarações geradas pelo sistema a partir dos modelos de documento, depois da aprovação do RH | 2026-10-12 |
| D-300 | O RH programa férias coletivas e tem um calendário anual de férias com os vencimentos dos períodos concessivos | 2026-10-12 |
| D-301 | No atestado, o gestor vê só as datas de ausência. Arquivo, CID e motivo ficam com o RH | 2026-10-12 |
| D-302 | Propostas P-09-01 a P-09-16 da spec 09 aprovadas sem ajuste. As regras legais citadas (CLT, NR-7) ainda precisam de conferência por especialista em DP | 2026-10-12 |

## Ponto eletrônico, detalhamento (spec 10)

| # | Decisão | Data |
|---|---|---|
| D-310 | A spec assume o CatalystHR como fabricante do REP-P (registro no INPI e atestado técnico), a confirmar com o jurídico | 2026-10-12 |
| D-311 | Reconhecimento facial (AWS Rekognition, com comparação facial e prova de vida em toda marcação, para quem consentiu) fica **fora do MVP** e entra quando houver app mobile nativo. Motivo: a prova de vida da AWS na web exige React (conflito com D-022). Revisa D-061 e D-063 | 2026-10-12 |
| D-312 | Quando existir, o reconhecimento facial é opcional e contratado por empresa: incluído no plano ou como adicional | 2026-10-12 |
| D-313 | Selfie na marcação configurável pela empresa, por unidade ou cargo: sempre, nunca ou por amostragem | 2026-10-12 |
| D-314 | O comprovante de cada marcação aparece no portal, com envio opcional por e-mail | 2026-10-12 |
| D-315 | Totem: tablet ou PC em modo totem, autorizado pelo RH por código de pareamento, preso a uma unidade e sem login de pessoa | 2026-10-12 |
| D-316 | Marcação pelo navegador do computador: lista opcional de IPs autorizados por unidade; sem lista, vale a cerca virtual | 2026-10-12 |
| D-317 | Intervalo de refeição marcado ou pré-assinalado, configurável por jornada (CLT art. 74, § 2º) | 2026-10-12 |
| D-318 | Tratamento de marcações pelo pedido de ajuste (aprovado pelo gestor) ou pelo RH com motivo. A marcação original nunca muda | 2026-10-12 |
| D-319 | Comprovantes e AFD assinados com o certificado A1 de cada empregador | 2026-10-12 |
| D-320 | Quando o facial existir, falha de reconhecimento registra a marcação e a sinaliza para revisão | 2026-10-12 |
| D-321 | Quem recusa a biometria marca só com localização, sem selfie (e, no totem, CPF + PIN, QR code ou crachá) | 2026-10-12 |
| D-322 | Trabalhadores externos marcam de qualquer lugar, com a localização registrada | 2026-10-12 |
| D-323 | O consentimento de biometria é pedido a quem marca ponto em unidade ou cargo com selfie (no primeiro acesso, ou no próximo se a empresa ligar depois). Revisa P-02-09 | 2026-10-12 |
| D-324 | Propostas P-10-01 a P-10-26 da spec 10 aprovadas sem ajuste | 2026-10-12 |

## Jornada e banco de horas (spec 11)

| # | Decisão | Data |
|---|---|---|
| D-330 | Período de apuração configurável pela empresa (mês cheio ou deslocado, por exemplo 21 a 20) | 2026-10-12 |
| D-331 | Tolerância padrão da CLT (5 minutos por marcação, 10 por dia), configurável na regra de ponto | 2026-10-12 |
| D-332 | Regras de ponto reutilizáveis (percentuais por faixa e tipo de dia, tolerâncias, noturno, banco de horas); cada jornada aponta uma regra | 2026-10-12 |
| D-333 | Banco de horas configurável na regra: tipo de acordo e prazo, o que vai para o banco e o que acontece no vencimento | 2026-10-12 |
| D-334 | Adicional noturno urbano e rural (lavoura e pecuária), com prorrogação configurável | 2026-10-12 |
| D-335 | O RH fecha o período; o sistema gera os espelhos, pede ciência e envia os totais para a folha automaticamente | 2026-10-12 |
| D-336 | Feriados estaduais e municipais cadastrados manualmente pela equipe CatalystHR | 2026-10-12 |
| D-337 | Tipos de jornada: fixa semanal, escala cíclica, flexível por carga e escala montada pelo gestor | 2026-10-12 |
| D-338 | Interjornada e intrajornada: o sistema sinaliza a violação e calcula o valor devido conforme a regra de ponto | 2026-10-12 |
| D-339 | O RH administrador reabre um período fechado, com motivo, enquanto a folha do mês não fechou | 2026-10-12 |
| D-340 | O colaborador pode contestar o espelho com comentário, o que abre uma solicitação para o RH | 2026-10-12 |
| D-341 | Propostas P-11-01 a P-11-16 da spec 11 aprovadas sem ajuste. Inclui o novo tipo de solicitação do sistema "Contestação de espelho" (amplia D-291) | 2026-10-12 |

## Folha de pagamento, detalhamento (spec 12)

| # | Decisão | Data |
|---|---|---|
| D-350 | Rubricas: catálogo padrão mantido pela plataforma, com as incidências, mais rubricas próprias da empresa | 2026-10-12 |
| D-351 | Tabelas legais (INSS, IRRF, salário mínimo, salário-família, teto, dedução por dependente) globais, com vigência, mantidas pela equipe CatalystHR | 2026-10-12 |
| D-352 | Convenções coletivas tratadas por rubricas e regras configuráveis por empresa, sem cadastro de CCT | 2026-10-12 |
| D-353 | Rubricas da empresa por tipos prontos e fórmulas numa linguagem segura (sem executar Ruby) | 2026-10-12 |
| D-354 | Ciclo da competência: aberta → calculada → conferida → fechada. Reabrir exige o RH administrador | 2026-10-12 |
| D-355 | Folhas: mensal, adiantamento quinzenal, complementares, 13º em 2 parcelas e PLR | 2026-10-12 |
| D-356 | Pagamento padrão por PIX. No MVP, o sistema gera a lista de pagamentos (PIX, ou conta bancária para quem não tem PIX), e o RH paga pelo banco e marca como pago. CNAB e integração bancária ficam para depois. Revisa D-073 | 2026-10-12 |
| D-357 | Benefícios e descontos: VT, VR/VA, planos de saúde e odontológico, seguro de vida, pensão alimentícia, consignado, contribuições sindicais e outros descontos | 2026-10-12 |
| D-358 | Benefícios só com cálculo e relatórios para o RH pedir nas operadoras, sem integração | 2026-10-12 |
| D-359 | NF do PJ: conferência de CNPJ e valor contra o contrato e aprovação do RH, sem retenções nem EFD-Reinf | 2026-10-12 |
| D-360 | Holerite publicado no portal quando a folha fecha, com aviso e registro de leitura | 2026-10-12 |
| D-361 | Informe de rendimentos anual gerado para todos (inclusive desligados em leitura) até o fim de fevereiro | 2026-10-12 |
| D-362 | Propostas P-12-01 a P-12-21 da spec 12 aprovadas sem ajuste | 2026-10-12 |
| D-363 | Prévia do holerite no portal só quando a competência está conferida e ainda não fechada | 2026-10-12 |

## eSocial e obrigações (spec 13)

| # | Decisão | Data |
|---|---|---|
| D-370 | O EFD-Reinf R-2060 das empresas desoneradas é enviado pela contabilidade, com base e valor fornecidos pela plataforma. D-359 continua valendo | 2026-10-12 |
| D-371 | Eventos de SST (S-2210, S-2220, S-2240) ficam fora: são enviados pela clínica ou pelo SESMT. A plataforma guarda os documentos | 2026-10-12 |
| D-372 | Comunicação com o eSocial por implementação própria em Ruby (XML, XSD, assinatura, lotes, consulta) | 2026-10-12 |
| D-373 | Guias do FGTS Digital e da DCTFWeb: a plataforma mostra os valores esperados, o RH emite no portal oficial, anexa a guia e o comprovante, e o sistema confere | 2026-10-12 |
| D-374 | Ambiente do eSocial por empresa, começando em produção restrita na implantação | 2026-10-12 |
| D-375 | Painel do eSocial: todo evento gerado espera a revisão e o envio pelo RH (um a um ou em lote) | 2026-10-12 |
| D-376 | Rejeições do eSocial com explicação em linguagem simples e sugestão de correção pela IA | 2026-10-12 |
| D-377 | Migração por corte de competência: os XMLs já transmitidos são importados como existentes, e a plataforma assume a partir da competência escolhida | 2026-10-12 |
| D-378 | Propostas P-13-01 a P-13-15 da spec 13 aprovadas sem ajuste. Inclui o certificado de procurador com procuração eletrônica (P-13-06) | 2026-10-12 |

## IA (spec 14)

| # | Decisão | Data |
|---|---|---|
| D-380 | Retenção zero de dados com a Anthropic e com a Voyage AI (acordo a contratar com cada uma) | 2026-10-12 |
| D-381 | No MVP, o assistente responde só com base nos materiais, sem consultar dados pessoais de quem pergunta | 2026-10-12 |
| D-382 | O resumo operacional cobre admissões e documentos, solicitações, ponto e jornada, folha e eSocial | 2026-10-12 |
| D-383 | Falha da IA: novas tentativas com intervalo crescente. Se não der certo, o item vai para a conferência manual, e o RH pode pedir para processar de novo | 2026-10-12 |
| D-384 | A cota de IA é medida em créditos por operação, com pesos cadastrados pelo admin CatalystHR. O custo real em tokens fica registrado internamente | 2026-10-12 |
| D-385 | A Batch API da Anthropic não é usada, porque não tem retenção zero (guarda os dados por 29 dias). O resumo diário vai pela API normal | 2026-10-12 |
| D-386 | O resumo operacional aparece só na tela inicial, sem e-mail nem WhatsApp | 2026-10-12 |
| D-387 | Sem resposta nos materiais, o assistente diz que não sabe e oferece abrir uma solicitação ao RH com a pergunta. As perguntas sem resposta viram sugestões para o RH | 2026-10-12 |
| D-388 | Na leitura de documentos, a IA aponta indícios: divergência com o cadastro, documento vencido ou ilegível, tipo errado e sinais de adulteração (sempre como alerta) | 2026-10-12 |
| D-389 | O RH administrador liga ou desliga cada função de IA da empresa. Desligada, tudo segue no manual | 2026-10-12 |
| D-390 | Funções de IA também no MVP: redação para o RH, recrutamento (spec 21) e avaliação de desempenho (spec 22) | 2026-10-12 |
| D-391 | A redação para o RH cobre comunicados e avisos, descrições de cargo, perguntas e respostas e modelos de documento | 2026-10-12 |
| D-392 | As respostas do assistente têm avaliação (útil / não útil), com relatório para o RH | 2026-10-12 |
| D-393 | Materiais do assistente com público restrito por perfil, unidade e tipo de vínculo. O assistente só usa o que a pessoa pode ver | 2026-10-12 |
| D-394 | Formatos dos materiais do assistente: PDF, Word (DOCX) e texto escrito na tela | 2026-10-12 |
| D-395 | Teto diário de segurança por empresa contra uso anormal: pausa a IA da empresa até o dia seguinte ou até a equipe CatalystHR liberar. Valor configurável pelo admin | 2026-10-12 |
| D-396 | O botão "Atualizar" do resumo operacional tem intervalo mínimo de 15 minutos | 2026-10-12 |
| D-397 | Propostas P-14-01 a P-14-41 da spec 14 aprovadas sem ajuste. Inclui o relatório anônimo de perguntas, sem acesso do RH às conversas (P-14-22), e a cota compartilhada pela carteira do parceiro (P-14-25) | 2026-10-12 |

## Notificações (spec 15)

| # | Decisão | Data |
|---|---|---|
| D-400 | Canais de aviso: notificações no sistema, e-mail (SES), WhatsApp (Twilio) e push do PWA | 2026-10-13 |
| D-401 | O RH administrador define os canais padrão de cada tipo de aviso. Cada pessoa ajusta os avisos opcionais. Os obrigatórios (segurança, holerite, ciência, prazos legais) sempre chegam em pelo menos um canal | 2026-10-13 |
| D-402 | WhatsApp e push respeitam o horário de silêncio (20h às 8h e fins de semana): o aviso espera até as 8h do próximo dia útil. Códigos de acesso e avisos de segurança saem na hora | 2026-10-13 |
| D-403 | Para quem tem jornada cadastrada, o silêncio é fora do turno e nas folgas. Para quem não tem, vale a regra fixa (D-402) | 2026-10-13 |
| D-404 | E-mails ao RH e aos gestores chegam num resumo diário, com os urgentes na hora. No sistema e no push, tudo chega na hora | 2026-10-13 |
| D-405 | Lembrete de marcação esquecida, configurável pela empresa (liga ou desliga, tolerância, canal). É só lembrete e nunca marca o ponto | 2026-10-13 |
| D-406 | Os modelos de WhatsApp são mantidos pela equipe CatalystHR e aprovados na Meta, com variáveis (marca, nome, link). As empresas não editam. Com número próprio, os mesmos modelos são aprovados na conta do parceiro | 2026-10-13 |
| D-407 | WhatsApp com cota mensal de mensagens no plano: aviso com 80% e 100%, sem bloqueio, excedente cobrado (como D-092 e D-101) | 2026-10-13 |
| D-408 | Mural de comunicados do RH, para a empresa ou um grupo. Chega pelo sistema, pelo push e por e-mail com o texto; no WhatsApp, um aviso padrão com o link | 2026-10-13 |
| D-409 | Aviso não entregue: os obrigatórios tentam o próximo canal disponível; os opcionais ficam só no sistema. E-mail que volta marca o endereço como inválido e avisa o RH | 2026-10-13 |
| D-410 | Propostas P-15-01 a P-15-34 da spec 15 aprovadas sem ajuste. Inclui o catálogo inicial de avisos (P-15-07), a margem de 30 minutos no silêncio pela jornada (P-15-11) e o "SAIR" no WhatsApp (P-15-19) | 2026-10-13 |

## Portal do colaborador (spec 16)

| # | Decisão | Data |
|---|---|---|
| D-420 | O portal tem a área "Minha equipe" para gestores: aprovações, ausências e escala, itens de processo e documentos vencendo da equipe. O resto da gestão fica no painel, que também funciona no celular | 2026-10-13 |
| D-421 | Navegação do protótipo: barra inferior com Início, Docs, Ponto, Pedidos e Mais. Abas que não se aplicam à pessoa somem. No computador, vira menu lateral | 2026-10-13 |
| D-422 | Empresas diferentes pelo seletor (RN-01-005). Vínculos da mesma empresa numa visão única, marcados pelo vínculo. No ponto, se mais de um vínculo marca, a pessoa escolhe o vínculo | 2026-10-13 |
| D-423 | Período padrão de leitura do desligado: 12 meses, ajustável pela empresa (completa D-090) | 2026-10-13 |
| D-424 | O service worker guarda só a casca do app (ícones, CSS, JS e a tela "Sem conexão"). Nenhum dado pessoal fica no aparelho | 2026-10-13 |
| D-425 | Passkey (WebAuthn) opcional para entrar e para confirmar dados sensíveis, com a digital ou o rosto do aparelho. A biometria fica no aparelho. A senha continua valendo | 2026-10-13 |
| D-426 | Entrar com passkey cumpre o MFA, inclusive nos perfis com MFA obrigatório, no portal e no painel. Senha e código do app continuam como alternativa. Amplia D-083 | 2026-10-13 |
| D-427 | Convite para instalar o app no Início depois do primeiro acesso, com o passo a passo no iPhone. Pode ser dispensado e volta depois de 30 dias | 2026-10-13 |
| D-428 | Navegadores suportados: Chrome, Safari (iOS 16.4+), Edge, Firefox e Samsung Internet dos últimos 2 anos. Navegador mais antigo vê um aviso, mas usa o básico | 2026-10-13 |
| D-429 | Ordem do Início: ponto; "Minha equipe" (gestores); pendências; comunicados; integração (na admissão); solicitações em andamento; último holerite | 2026-10-13 |
| D-430 | Propostas P-16-01 a P-16-26 da spec 16 aprovadas sem ajuste. Inclui a passkey presa ao subdomínio da marca, que precisa ser cadastrada de novo depois de uma transferência (P-16-19), e o aviso `memberships.read_only_ending` no catálogo da spec 15 (P-16-11) | 2026-10-13 |

## Painéis (spec 17)

| # | Decisão | Data |
|---|---|---|
| D-440 | Painel do RH: os blocos do protótipo mais os blocos dos módulos contratados (ponto, folha, eSocial), conforme o acesso da pessoa | 2026-10-13 |
| D-441 | Relatórios gerenciais no MVP: quadro e movimentação; absenteísmo e jornada; custo de pessoal; diversidade | 2026-10-13 |
| D-442 | Visão consolidada do parceiro, por empresa e sem dados de pessoas: carteira e consumo; saúde operacional; folha e eSocial; adoção | 2026-10-13 |
| D-443 | O painel é consultado em tempo real. Os relatórios gerenciais usam uma foto diária, feita de madrugada, que guarda o histórico mês a mês | 2026-10-13 |
| D-444 | Custo de pessoal: RH administrador (empresa toda) e RH analista com o módulo folha (unidades dele). O gestor não vê | 2026-10-13 |
| D-445 | Gráficos com Chart.js pelo importmap | 2026-10-13 |
| D-446 | Painéis e relatórios exportam em CSV, Excel (XLSX) e PDF | 2026-10-13 |
| D-447 | O painel da equipe CatalystHR (empresas, receita, custos, filas e falhas) fica na spec 19 | 2026-10-13 |
| D-448 | Diversidade só para o RH administrador, com números agregados. Grupos com menos de 5 pessoas aparecem como "< 5" | 2026-10-13 |
| D-449 | Relatórios agendados só para usuários do sistema com permissão: chega um aviso com o link, sem anexo | 2026-10-13 |
| D-450 | O parceiro compara as empresas da carteira entre si com indicadores agregados (turnover, absenteísmo, horas extras, tempo de admissão) | 2026-10-13 |
| D-451 | Propostas P-17-01 a P-17-24 da spec 17 aprovadas sem ajuste. As fórmulas de turnover e absenteísmo (P-17-11, P-17-12) entram na conferência do especialista em DP | 2026-10-13 |

## Importação e exportação (spec 18)

| # | Decisão | Data |
|---|---|---|
| D-460 | A planilha modelo da implantação importa: estrutura e pessoas; saldos e histórico de férias e ponto; histórico salarial e de cargos; acumulados da folha | 2026-10-13 |
| D-461 | No MVP, a importação de outros sistemas é pelos XMLs do eSocial, pela planilha modelo e pelos conversores de Domínio, Questor e Alterdata (D-094), que geram a planilha modelo. Outros layouts (TOTVS, Senior) e o AFD de outro REP entram conforme os clientes do piloto. Corrigida em 2026-10-13: a primeira versão contradizia D-094, que continua valendo | 2026-10-13 |
| D-462 | A importação mostra uma prévia com os erros linha a linha. O RH corrige e reenvia, ou importa só as linhas válidas. Nada é gravado antes da confirmação | 2026-10-13 |
| D-463 | Importações do dia a dia: lançamentos da folha, coparticipação e benefícios, admissões em lote e atualizações em massa com data de vigência | 2026-10-13 |
| D-464 | A planilha modelo é baixada em XLSX, com abas, instruções e listas de opções. O sistema aceita XLSX ou CSV | 2026-10-13 |
| D-465 | O RH administrador pode desfazer uma importação inteira enquanto nada depender dela, com registro na auditoria | 2026-10-13 |
| D-466 | O RH administrador exporta todos os dados da empresa quando quiser, no mesmo formato da exportação de encerramento | 2026-10-13 |
| D-467 | Sem API pública nem webhooks no MVP. As integrações são por arquivo | 2026-10-13 |
| D-468 | Os scripts internos de implantação viram importação assistida na área admin: o suporte sobe os arquivos em nome da empresa, com autorização do RH administrador e auditoria. Conversores específicos geram a planilha modelo | 2026-10-13 |
| D-469 | Propostas P-18-01 a P-18-26 da spec 18 aprovadas sem ajuste. Inclui o ZIP de exportação com senha AES-256, também no encerramento e na portabilidade (P-18-24) | 2026-10-13 |

## Administração e cobrança (spec 19)

| # | Decisão | Data |
|---|---|---|
| D-480 | Plano do parceiro: mensalidade por faixa de colaboradores ativos na carteira, com as cotas de IA e WhatsApp. Acima da faixa, excedente por colaborador (D-092). Ponto e folha somam um valor à mensalidade | 2026-10-13 |
| D-481 | Formas de pagamento: cartão de crédito recorrente e PIX. Sem boleto no MVP | 2026-10-13 |
| D-482 | A plataforma não cobra as empresas clientes em nome do parceiro. Ela fornece o relatório mensal de consumo por empresa (colaboradores, módulos, IA, WhatsApp) em CSV, para o parceiro faturar | 2026-10-13 |
| D-483 | Colaborador ativo, para limite e cobrança: a maior quantidade de vínculos ativos ou afastados em um dia do mês. Desligados em período de leitura não contam | 2026-10-13 |
| D-484 | A empresa direta entra pela equipe comercial: o admin cadastra a empresa, o plano e o primeiro RH administrador. A forma de pagamento é cadastrada no primeiro acesso do RH administrador (ajustada por D-496: a assinatura é da plataforma) | 2026-10-13 |
| D-485 | Teste grátis fixo de 14 dias, sem cartão, para empresas diretas e parceiros. As empresas cadastradas pelo parceiro em teste também ficam em teste | 2026-10-13 |
| D-486 | No teste, ponto e eSocial não funcionam | 2026-10-13 |
| D-487 | Fim do teste sem contratação: somente leitura por 30 dias, com a exportação completa disponível. Contratando nesse período, tudo volta. Depois de 30 dias, tudo é excluído | 2026-10-13 |
| D-488 | Ciclo só mensal: a mensalidade e o excedente do mês anterior numa única cobrança | 2026-10-13 |
| D-489 | O cancelamento pedido pelo cliente vale no fim do período pago, sem multa nem aviso prévio. Depois, começa o encerramento (D-222) | 2026-10-13 |
| D-490 | Painel da equipe CatalystHR: receita, custos contra o cobrado, operação e clientes | 2026-10-13 |
| D-491 | O financeiro e o superadmin podem lançar ajustes manuais na cobrança (desconto, crédito, isenção de excedente), sempre com justificativa e auditoria | 2026-10-13 |
| D-492 | Aumento de plano ou contratação de módulo vale na hora, com cobrança proporcional. Redução vale no próximo ciclo | 2026-10-13 |
| D-493 | Com 30 dias de atraso, o contrato é encerrado e começa o fluxo da spec 05. O ponto continua funcionando até o encerramento. Completa D-116 | 2026-10-13 |
| D-494 | Na somente leitura por atraso, além do ponto, o RH pode transmitir ao eSocial os eventos já gerados e consultar os retornos. Nada novo é criado. Completa D-116 | 2026-10-13 |
| D-495 | As empresas clientes de um parceiro em atraso só são avisadas quando a conta entra em somente leitura: o RH administrador vê uma faixa "Acesso limitado por pendência com [parceiro]", sem valores | 2026-10-13 |
| D-496 | A gestão de assinaturas e faturas é 100% da plataforma (tabela `subscriptions`): a cada ciclo, a fatura sai com o valor do mês, e a cobrança é executada pelo Mercado Pago, no cartão salvo (pagamentos automáticos) ou por QR PIX. As assinaturas do Mercado Pago (preapproval) não são usadas, porque não aceitam valor variável nem adicionais de forma confirmada | 2026-10-13 |
| D-497 | Cartão recusado: a plataforma pede uma nova cobrança ao Mercado Pago 1, 3 e 5 dias depois, com aviso ao cliente a cada recusa e o link para pagar por PIX ou trocar o cartão | 2026-10-13 |
| D-498 | Propostas P-19-01 a P-19-29 da spec 19 aprovadas, com o modelo de cobrança ajustado por D-496 e D-497 (P-19-13 e P-19-29 reescritas) | 2026-10-13 |

## Infraestrutura (spec 20)

| # | Decisão | Data |
|---|---|---|
| D-500 | Railway na região US East (Virgínia), que não tem equivalente no Brasil. A transferência internacional (LGPD, art. 33) entra nos contratos e na política de privacidade, com validação do jurídico | 2026-10-13 |
| D-501 | Serviços da AWS (S3, KMS, SES, SNS) na região São Paulo (sa-east-1) | 2026-10-13 |
| D-502 | Backups: pg_dump diário criptografado no S3 São Paulo, apagado aos 35 dias (D-223). O PITR do Railway serve para recuperações rápidas. Os backups mensais do Railway ficam desligados | 2026-10-13 |
| D-503 | DNS na Cloudflare, sem proxy. O certificado wildcard é emitido pelo Railway | 2026-10-13 |
| D-504 | Só o ambiente de produção por enquanto, sem homologação nem ambientes por pull request | 2026-10-13 |
| D-505 | Código no GitHub, com CI/CD pelo GitHub Actions | 2026-10-13 |
| D-506 | Sentry para erros e desempenho | 2026-10-13 |
| D-507 | Antivírus dos uploads: ClamAV como serviço no Railway | 2026-10-13 |
| D-508 | Recuperação de desastre: perda máxima de 5 minutos (PITR) e volta em 4 horas. O pg_dump no S3 cobre a perda total do Railway, com perda máxima de 24 horas. Ensaio de restauração a cada 3 meses | 2026-10-13 |
| D-509 | Alertas: e-mail da equipe para todos; WhatsApp ou SMS de plantão para os críticos; monitor externo | 2026-10-13 |
| D-510 | Logs no Sentry Logs, enviados pela aplicação, com retenção de 30 dias, que é o limite fixo do Sentry (90 dias foi a primeira escolha) | 2026-10-13 |
| D-511 | Redis só para o Sidekiq. O cache do Rails fica no Postgres (Solid Cache) | 2026-10-13 |
| D-512 | Monitores externos e de jobs agendados no Sentry. Os alertas críticos do Sentry são reenviados ao plantão por WhatsApp ou SMS pela Twilio da plataforma | 2026-10-13 |
| D-513 | Sem página pública de status no MVP | 2026-10-13 |
| D-514 | ZIP com senha AES-256 gerado pelo 7-Zip instalado no container da aplicação, porque o rubyzip não grava AES | 2026-10-13 |
| D-515 | Propostas P-20-01 a P-20-36 da spec 20 aprovadas sem ajuste. Inclui o worker separado para o ponto (P-20-04), a empresa de demonstração em produção e as feature flags (P-20-11) | 2026-10-13 |
| D-516 | Enquanto houver um desenvolvedor só, o merge na `main` exige só o CI verde. A revisão aprovada (P-20-12) passa a ser obrigatória quando entrar a segunda pessoa | 2026-10-14 |
| D-517 | A configuração dos serviços do Railway (início, pre-deploy, health check, réplicas, região) é feita pelo painel e pela API e documentada no README, sem arquivo no repositório. Motivo: o `railway.json` (Config as Code) foi descontinuado pelo Railway, serviços novos não podem usá-lo, e o substituto (`.railway/railway.ts`) não foi adotado | 2026-10-14 |
| D-573 | O monitor externo do Sentry confere o `/up` em `health.painel.catalysthr.com.br`, e o slug `health` passa a ser reservado (RN-01-021). Motivo: o endereço do Railway (`*.up.railway.app`) não serve, porque o Sentry limita a 1.000 monitores por domínio e o `railway.app` já atingiu o limite; e um domínio próprio como `health.catalysthr.com.br` não cabe no plano Hobby, que permite 2 domínios por serviço, já usados por `*.painel` e `admin` | 2026-10-14 |
| D-574 | O CatalystHR usa uma conta própria da AWS (`catalysthr`), membro da organização da conta `devbatista`, que fica só como gestora. A equipe acessa pelo IAM Identity Center em São Paulo, com MFA em todo login, e a conta-membro não tem credenciais raiz. Motivo: a `devbatista` tem usuários IAM de outros sistemas, que alcançariam os dados do CatalystHR, e a reputação do SES é por conta. Complementa a D-501 e a RN-20-053 | 2026-10-14 |
| D-575 | O deploy em produção passa a ser automático: quando o CI de um push na `main` termina verde, o workflow Deploy publica a `main`. Nunca começa nos picos do ponto (7h às 9h e 17h às 19h); o que ficar pendente sai às 9h05 e às 19h05. O disparo manual continua, e só ele pode forçar um deploy no pico. Revisa a aprovação manual da RN-20-032 (P-20-13). Rever antes de o primeiro cliente usar o ponto (fase 3) | 2026-10-15 |

## Recrutamento (spec 21)

| # | Decisão | Data |
|---|---|---|
| D-520 | Página pública de vagas por empresa, com a marca, e link por vaga. O candidato se inscreve sem criar conta. O RH também cadastra candidatos à mão | 2026-10-13 |
| D-521 | Funil configurável: a empresa tem um funil padrão (Inscritos, Triagem, Entrevista com RH, Entrevista com gestor, Proposta, Contratado), ajustável por vaga, num quadro | 2026-10-13 |
| D-522 | A IA lê o currículo e preenche a ficha, faz o resumo do candidato, mostra a aderência a cada requisito com o trecho do currículo e sugere perguntas de entrevista | 2026-10-13 |
| D-523 | A IA não dá nota nem ordena candidatos, e nunca move ou reprova ninguém. Quem decide é sempre uma pessoa | 2026-10-13 |
| D-524 | O candidato recebe: confirmação da inscrição, convite de entrevista e devolutiva de reprovação (texto padrão editável, sem o motivo interno), por e-mail e, se autorizar, por WhatsApp | 2026-10-13 |
| D-525 | Página de acompanhamento por link pessoal, sem conta: etapa em termos gerais, atualizar o currículo e pedir a exclusão dos dados | 2026-10-13 |
| D-526 | Banco de talentos com consentimento do candidato, por 12 meses. Sem consentimento, vale a retenção de 6 meses e só a vaga da inscrição | 2026-10-13 |
| D-527 | O gestor pede a vaga (cargo, justificativa, faixa salarial), e o RH administrador ou o RH analista da unidade aprova e publica. Vagas abertas pelo RH não precisam de aprovação | 2026-10-13 |
| D-528 | Perguntas de triagem só sinalizam. Ninguém é reprovado automaticamente | 2026-10-13 |
| D-529 | Dados de diversidade opcionais (autodeclaração), separados da avaliação e só agregados. Exceção: PcD em vagas afirmativas, que o RH vê | 2026-10-13 |
| D-530 | Entrevistas agendadas no sistema, com convite .ics por e-mail. Sem integração com calendários no MVP | 2026-10-13 |
| D-531 | Ficha de avaliação por etapa: critérios da vaga com nota de 1 a 5, parecer e recomendação. Cada entrevistador só vê as fichas dos outros depois de enviar a sua | 2026-10-13 |
| D-532 | Carta-proposta por modelo, com aceite ou recusa pelo link de acompanhamento (data, hora e IP). Ao aceitar, a admissão é criada | 2026-10-13 |
| D-533 | Recrutamento interno pelo portal: a vaga pode ser interna, externa ou as duas. O gestor atual fica sabendo na etapa de proposta, conforme a configuração da empresa | 2026-10-13 |
| D-534 | Propostas P-21-01 a P-21-28 da spec 21 aprovadas sem ajuste. Inclui a inscrição sem CPF (P-21-04) e a contratação interna como revisão do vínculo (P-21-25) | 2026-10-13 |

## Avaliação de experiência e desempenho (spec 22)

| # | Decisão | Data |
|---|---|---|
| D-540 | Avaliação de experiência antes do fim de cada período do contrato de experiência, aberta junto com o aviso de vencimento (RN-07-101). A decisão continua na admissão | 2026-10-13 |
| D-541 | Avaliadores no ciclo de desempenho: autoavaliação, gestor, pares e a equipe avaliando o gestor (ascendente) | 2026-10-13 |
| D-542 | O ciclo avalia competências (1 a 5) e metas individuais, e termina com um plano de desenvolvimento (PDI) simples | 2026-10-13 |
| D-543 | Calibração: o RH e os gestores ajustam a nota final por área, com justificativa. A nota original fica no histórico | 2026-10-13 |
| D-544 | Pares: o colaborador indica de 2 a 5 colegas, e o gestor aprova ou troca. Respostas anônimas, só agregadas e com pelo menos 3 respostas. O RH vê quem respondeu, sem ligar a resposta à pessoa | 2026-10-13 |
| D-545 | Avaliação ascendente anônima: o gestor e o RH veem só o agregado e os comentários sem autor, e só com pelo menos 3 respostas | 2026-10-13 |
| D-546 | Nota final com pesos configuráveis por ciclo (competências e metas, e cada avaliador). A ascendente não entra na nota | 2026-10-13 |
| D-547 | Devolutiva: o gestor registra a reunião de feedback. Depois, o colaborador vê no portal a nota final calibrada, a avaliação do gestor, o resumo dos pares e o PDI, e dá ciência, podendo comentar | 2026-10-13 |
| D-548 | Feedbacks contínuos de qualquer pessoa para um colega (reconhecimento ou ponto de melhoria), privados entre quem dá e quem recebe, com o gestor de quem recebe vendo também. Eles aparecem ao gestor na avaliação | 2026-10-13 |
| D-549 | A IA resume os comentários (respeitando o anonimato), sugere o PDI e ajuda a escrever, alertando para linguagem vaga ou enviesada. A IA nunca sugere nem calcula notas | 2026-10-13 |
| D-550 | Competências: biblioteca padrão da plataforma (D-126) e competências da empresa, em modelos por cargo ou grupo de cargos. A experiência tem um modelo próprio | 2026-10-13 |
| D-551 | Propostas P-22-01 a P-22-27 da spec 22 aprovadas sem ajuste. Inclui a gravação das respostas anônimas sem o avaliador (P-22-13) e os pesos padrão da nota final (P-22-11) | 2026-10-13 |

## Nota fiscal de serviço pelo Asaas (spec 19)

| # | Decisão | Data |
|---|---|---|
| D-560 | A plataforma emite pelo Asaas as NFS-e do CatalystHR para parceiros e empresas diretas. Revisa D-114 | 2026-10-13 |
| D-561 | A cobrança continua no Mercado Pago (D-481, D-496). O Asaas é usado só para as notas, como nota avulsa ligada ao cliente | 2026-10-13 |
| D-562 | A nota é emitida automaticamente quando o pagamento da fatura é confirmado | 2026-10-13 |
| D-563 | Nota recusada pela prefeitura: alerta ao financeiro e ao superadmin, mensagem na fatura e reemissão manual depois da correção. Falhas temporárias têm novas tentativas automáticas | 2026-10-13 |
| D-564 | A nota autorizada (PDF e XML) fica na fatura, e o responsável financeiro recebe o aviso da plataforma. O e-mail do Asaas fica desligado | 2026-10-13 |
| D-565 | O estorno de uma fatura paga cancela a nota no Asaas automaticamente | 2026-10-13 |
| D-566 | Propostas P-19-30 a P-19-38 (NFS-e pelo Asaas) aprovadas sem ajuste | 2026-10-13 |

## Clientes de alocação (specs 00, 02, 03, 04, 06, 07, 15 e 17)

| # | Decisão | Data |
|---|---|---|
| D-570 | Uma empresa pode usar **clientes de alocação**: ela é a empregadora e aloca colaboradores em clientes dela. É uma configuração da empresa, desligada por padrão. Ligada, o vínculo indica o cliente, e os gestores do cliente participam do processo com um perfil próprio, sem ser colaboradores da empresa | 2026-10-14 |
| D-571 | Quando a consultoria opera o RH de empresas clientes, que são as empregadoras, vale o modelo de parceiro já existente: a consultoria é o parceiro, a equipe dela são consultores, e cada cliente é uma empresa com os próprios gestores. Não há mudança nas specs | 2026-10-14 |
| D-572 | Propostas de clientes de alocação aprovadas sem ajuste: P-02-38 a P-02-41, P-03-38 a P-03-41, P-04-30 a P-04-36, P-06-21 e P-06-22, P-07-19 e P-07-20, P-15-35, P-17-25 e P-17-26. Inclui o MFA obrigatório do gestor do cliente (P-02-39), a proibição de acumular perfis (P-02-38), a ausência dele nas solicitações e no ponto na primeira versão (P-03-41) e a tela inicial com os itens atribuídos, sem painel (P-17-26) | 2026-10-14 |

## Em aberto

Itens que ainda precisam de decisão. Nenhuma spec deve assumir uma resposta para eles.

- REP-P: confirmar com o jurídico o CatalystHR como fabricante (D-310), a assinatura com o certificado do empregador (D-319), se o bloqueio pela cerca é permitido (spec 10, RN-10-022) e os layouts oficiais de AFD, AEJ e comprovante
- Roadmap: quando entra o app mobile nativo (pré-requisito do reconhecimento facial, D-311)
- Roadmap: CNAB e integração bancária para pagamento (D-356)
- eSocial: conferir na documentação oficial a versão do leiaute, os XSD, o MOS, a tabela de prazos, a obrigatoriedade do S-2300 para autônomos e o webservice de download (spec 13)
- Folha e eSocial: regras do Crédito do Trabalhador (consignado) — como os contratos chegam e como os descontos são informados
- LGPD: validação jurídica dos prazos de retenção propostos na spec 05, seção 4.4
- Folha: anexo de rubricas e incidências, a produzir com especialista em DP e contabilidade antes da implementação (spec 12)
- Folha: layout CSV da lista de pagamentos, a validar com os bancos dos clientes do piloto
- DP: conferência por especialista das regras legais citadas nas specs 12 (cálculos de folha) e 09 (férias, férias coletivas, afastamento, aviso prévio, prazos de rescisão, exame demissional) e 11 (tolerância, extras, noturno urbano e rural, DSR, intervalos, banco de horas, 12x36), além das fórmulas de turnover, absenteísmo e custo da spec 17
- Mercado Pago: confirmar a habilitação da conta para pagamentos automáticos com cartão salvo, sem pedir o CVV (D-496), e avaliar o Pix Automático para uma fase seguinte
- Jurídico: validar a transferência internacional de dados (Railway, Sentry, Anthropic, Voyage e Twilio nos EUA) e as cláusulas contratuais (D-500)
- Railway: confirmar no Trust Center (relatório SOC 2) a criptografia em repouso do banco e dos volumes
- Roadmap: API pública e webhooks (D-467); layouts de importação além de Domínio, Questor e Alterdata, e AFD de outro REP, conforme os clientes do piloto (D-461)
- NFS-e: definir com o contador da CatalystHR o código do serviço municipal, a alíquota de ISS, as retenções e o momento do fato gerador; configurar a conta do Asaas na prefeitura (ou no Portal Nacional) e confirmar o preço por nota (D-560 a D-562)
- IA: contratar a retenção zero com a Anthropic e confirmar se a Voyage AI oferece o mesmo (D-380), antes de entrar em produção
- Jurídico: base legal e cláusulas para mostrar dados dos colaboradores aos gestores dos clientes de alocação (D-570), que são terceiros em relação à empresa empregadora
- DP e eSocial: verificar se a alocação em cliente exige informar o tomador em algum evento ou obrigação (por exemplo, trabalho temporário ou cessão de mão de obra), na spec 13 (D-570)
- Clientes de alocação: decidir se o gestor do cliente participa das solicitações (spec 09) e do ponto (specs 10 e 11), como aprovar ajustes de marcação e dar visto no espelho. Fica fora da primeira versão (D-570)
