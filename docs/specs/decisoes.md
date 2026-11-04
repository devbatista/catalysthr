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
| D-160 | Sem domínio de e-mail verificado (ou empresa direta sem domínio), os e-mails saem do domínio da plataforma com o nome da marca, por exemplo "Aurora RH <~~nao-responda@~~no-reply@catalysthr.com.br>", com o suporte da marca no reply-to (endereço revisado por D-596) | 2026-10-12 |
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
| D-583 | O bloco 4b das specs 02 e 03 sai em dois PRs: 4b-1, o painel do parceiro, e 4b-2, o escritório contábil | 2026-10-15 |
| D-584 | O administrador do parceiro convida administradores e consultores, e o administrador do escritório convida administradores e contadores (RN-02-071). Ninguém altera a própria membership, e o sistema impede remover ou rebaixar o último administrador ativo do parceiro ou do escritório, como a RN-03-013 faz com o RHA | 2026-10-15 |
| D-585 | No painel do parceiro, o administrador do parceiro vê os RHAs de cada empresa cliente, altera os perfis deles ou os remove (P-03-35, com o limite da D-582) e convida um RHA novo para uma empresa que já existe. O cadastro da empresa continua na spec 19 (P-03-14). Motivo: sem o convite, uma empresa que perde o único RHA fica sem saída até a spec 19 | 2026-10-15 |
| D-586 | O login numa marca (RN-01-002) também aceita a membership de escritório contábil, se o escritório tem ligação pendente ou ativa com alguma empresa daquela marca (RN-02-072). Dentro da marca, as empresas e os pedidos de aceite do escritório mostram só os daquela marca, para um parceiro não ver os clientes de outro. Os convites e os e-mails saem com a marca da empresa que pediu a ligação, ou com a marca em que o administrador do escritório está, ao convidar a equipe | 2026-10-15 |
| D-588 | Ao cadastrar o escritório contábil (D-171), o RHA informa o nome e o CNPJ do escritório e o nome, o CPF (D-173) e o e-mail ou o celular do administrador. O convite usa o motor de convites (RN-02-011), com link e QR code | 2026-10-15 |
| D-589 | A empresa tem no máximo um escritório contábil com ligação pendente ou ativa. Para trocar, o RHA desliga o atual (RN-02-073) e liga o novo. Segue a spec 06, que fala do escritório ligado à empresa | 2026-10-15 |
| D-590 | Quando o CNPJ do escritório já existe (P-02-29), os administradores ativos do escritório recebem um e-mail com a marca da empresa e aceitam ou recusam o pedido na área do escritório. A recusa, ou o cancelamento pelo RHA, encerra a ligação (`ended`). Os dados de administrador digitados pelo RHA não geram convite nesse caso | 2026-10-15 |
| D-591 | O bloco 5 das specs 02 e 03 sai em dois PRs: 5a, o impersonate em simulação com a máscara e os eventos de acesso, e 5b, a entrada do suporte nas empresas diretas (D-581) e as telas do suporte para corrigir contato e redefinir MFA (D-582) | 2026-10-15 |
| D-592 | O ponto único de leitura de dado sensível (RN-05-001) entra no bloco 5a só com a máscara do impersonate (RN-02-086). A confirmação de senha por 5 minutos (RN-02-052, D-183) e o evento de leitura (`sensitive_read`) entram com a spec 04, quando houver campo sensível na tela | 2026-10-15 |
| D-593 | Na empresa direta, o suporte opera todos os módulos que a empresa contratou (D-581, P-03-02), porque faz implantação e atendimento (D-127). Não há quem libere módulos para ele, como o administrador do parceiro faz com o consultor (P-03-06) | 2026-10-15 |
| D-594 | A parte 2 da spec 01 sai em quatro PRs: 2a, o ponto único de consulta entre empresas (RN-01-011) e a edição da marca sem imagens, com os modos, a troca de slug e o job que libera slugs; 2b, o S3 com prefixo por empresa e URLs assinadas (RN-01-014) e as imagens da marca; 2c, o domínio de e-mail no SES (RN-01-040); 2d, a transferência de empresa (RN-01-050 a RN-01-053) | 2026-10-16 |
| D-595 | Os recursos da AWS para arquivos (chaves KMS, buckets `catalysthr-files` e `catalysthr-backups` e o usuário IAM da aplicação) são criados no bloco 2b da spec 01, pelo responsável, no console, seguindo um passo a passo, sem chaves no chat. Custo aceito: cerca de US$ 2 por mês nas chaves KMS (até US$ 6 com as rotações anuais), mais o uso do S3. O bucket dos arquivos se chama `catalysthr-files`, e a chave dele `catalysthr-files`, por escolha do responsável em 2026-10-16. O bucket dos arquivos fica no namespace regional da conta, com o sufixo da conta e da região (`catalysthr-files-464986173446-sa-east-1-an`), para que nenhuma outra conta tome o nome; o de backups foi criado no namespace global, como `catalysthr-backups` | 2026-10-16 |
| D-596 | Domínio de e-mail da marca (bloco 2c da spec 01, RN-01-040): o remetente é sempre `no-reply@`, `no-reply@<domínio da marca>` com o domínio verificado e `no-reply@catalysthr.com.br` sem ele, no lugar de `nao-responda@` (revisa D-160). O SPF vem de um MAIL FROM próprio, `bounce.<domínio>`, e a tela mostra os 3 CNAMEs do DKIM, o MX e o TXT do MAIL FROM. O domínio fica verificado quando o DKIM e o MAIL FROM estão confirmados no SES. O envio real pelo SES (gem `aws-actionmailer-ses`, configuration set `catalysthr-padrao`) entra neste bloco; os eventos pelo SNS continuam na spec 15. O aviso de verificado ou de falha vai por e-mail para quem cadastrou o domínio e, na marca do parceiro, também para os admins do parceiro. Quem configura pode remover o domínio, o que apaga a identidade no SES; para trocar ou recomeçar depois de uma falha, remove e cadastra de novo. Um domínio só pode estar em uma marca, e o domínio da plataforma e os subdomínios dele são recusados | 2026-10-16 |
| D-597 | A base visual entra antes da spec 04, num bloco próprio, a partir de `prototype/CatalystRH_visual_identity` e da apresentação do MVP. O bloco traz as cores, as fontes, os componentes, a estrutura do painel (barra lateral e cabeçalho) e o novo visual das telas que já existem: painel da empresa, do parceiro e do escritório, admin e login. A barra lateral usa a cor secundária da marca, como no exemplo de parceiro da apresentação (página 4), e o texto dela fica claro ou escuro conforme o contraste. O menu mostra todos os módulos do protótipo. Os que ainda não existem levam à tela de "em breve", com o selo "Em breve", por escolha do responsável. As fontes (Manrope, JetBrains Mono e Exo 2) ficam nos arquivos da aplicação, sem chamada ao Google. O portal do colaborador continua na spec 16 | 2026-10-16 |
| D-598 | Cada entrega leva o visual junto. Toda tela nova usa a estrutura e os componentes da base visual (D-597). Onde há protótipo, a tela segue o protótipo; onde não há, é montada com os mesmos componentes, sem estilo próprio. O módulo construído sai da lista do "Em breve" (`ComingSoon`) no mesmo PR. Na revisão do PR, as telas novas são conferidas no computador e no celular | 2026-10-16 |
| D-599 | Transferência de empresa (bloco 2d da spec 01, RN-01-050 a RN-01-053). A autorização da empresa é registrada pelo superadmin num texto obrigatório (quem autorizou, quando e como), com anexo opcional; o aceite do RH administrador por e-mail vira esse texto e o anexo. De parceiro para direta, o superadmin informa o slug novo na transferência: a marca própria da empresa passa a ser a da direta e, sem marca, é criada uma com o nome da empresa e as cores do CatalystHR (P-01-02). De direta para parceiro, o endereço antigo responde a 404 neutra e o slug fica reservado por 90 dias, até ser liberado; a identidade de e-mail da marca é apagada do SES, e o logo e as cores continuam como marca própria, no modo `alongside`. A cópia de modelos de processo, materiais do assistente e perguntas e respostas (RN-01-053) entra nas specs 06 e 14, no serviço de transferência e com teste, porque esses dados ainda não existem | 2026-10-16 |
| D-600 | A spec 04 sai em quatro PRs: 4a, empresa e unidades, com o escopo U; 4b, departamentos, gestores e cargos com a tabela da CBO, com o escopo E; 4c, ficha, dependentes, contas, vínculos e revisões com vigência, com a confirmação de senha para dado sensível (D-592); 4d, campos personalizados e clientes de alocação, com o escopo K. Na fase 1, o RH cadastra à mão quem já trabalha na empresa (tela "Novo colaborador"), o que cria a pessoa, a membership de colaborador sem enviar convite, a ficha e o vínculo. O convite do colaborador sai com o portal (spec 16) e o do gestor do cliente com a admissão (spec 07). A empresa passa a ser identificada pelo tipo de empregador e pelo documento, a raiz do CNPJ ou o CPF, únicos na plataforma e com o CPF criptografado (RN-04-001); o CNPJ completo atual vira o número da unidade matriz, e a coluna `cnpj` sai num PR seguinte. A atualização de dados pelo colaborador (RN-04-070 a RN-04-073) fica para as specs 09 e 16, e as pendências de eSocial (RN-04-063, RN-04-073) para a spec 13 | 2026-10-16 |
| D-601 | Telas de configuração da empresa (bloco 4a): Unidades, e depois Departamentos e Cargos, são itens próprios do grupo "Empresa" do menu, porque o RH analista e o gestor também consultam. "Configurações" é só do RH administrador, com os dados da empresa e as regras (período de leitura do desligado, D-090). O tipo de empregador e o documento aparecem só para leitura ao RH; só o superadmin corrige, pelo admin, junto com as telas de empresa da spec 19. A criação de empresas pelo admin e pelo parceiro (P-03-14) continua na spec 19; até lá, toda empresa existente ganha a unidade matriz | 2026-10-16 |
| D-602 | O bloco 4c da D-600 se divide em dois PRs, e a spec 04 passa a sair em cinco. O 4c-1 traz a ficha, os vínculos, as revisões com vigência, a lista de colaboradores, a tela "Novo colaborador" e a confirmação de senha para dado sensível. O 4c-2 traz os contatos de emergência, os dependentes, as contas bancárias e a efetivação de estagiário. A ficha e o vínculo já entram com todos os grupos de RN-04-041 e RN-04-053. Os campos de lista (sexo, raça/cor, estado civil, grau de instrução, categoria e os demais) usam valores próprios do sistema, e a correspondência com os códigos do eSocial entra na spec 13, junto com a conferência do leiaute (P-04-15). No "Novo colaborador", um CPF que já tem conta na plataforma reaproveita a pessoa (D-209, CA-04-007): a ficha nova se liga a ela, sem mostrar nem alterar os dados de outra empresa e sem trocar o e-mail ou o celular de login; o RH só fica sabendo que o CPF já tem conta. O job diário das revisões (P-04-29) entra com as notificações (spec 15), porque a revisão vigente já é escolhida pela data (RN-04-061) e as pendências de eSocial ficam na spec 13 | 2026-10-17 |
| D-603 | Revisões do vínculo são imutáveis depois de entrarem em vigor. Uma revisão futura pode ser editada ou excluída até a data dela. Uma revisão que já vale é corrigida por uma revisão nova, com o motivo "Correção", que pode ter a mesma data da anterior e vale no lugar dela: entre revisões da mesma data, vale a registrada por último. Assim o histórico fica inteiro, também para a retificação no eSocial, e o salário, que não vai para o PaperTrail (D-086), não perde o valor anterior. O alerta de salário fora da faixa do cargo (RN-04-032) só compara salários mensais, porque a faixa do cargo é mensal; salário por hora, dia, semana ou outra unidade não gera alerta, sem conversão | 2026-10-17 |
| D-604 | Bloco 4c-2 da spec 04. A certidão do dependente (RN-04-043) e o comprovante da conta (P-04-17) entram com a pasta de documentos (spec 08); até lá, a titularidade da conta é registrada pela declaração do RH, com quem declarou e quando. Contas bancárias e dependentes nunca são apagados: são encerrados, com data, e ficam na ficha como histórico, porque a folha e o IRRF de períodos passados precisam deles (CA-04-008). Trocar a conta principal encerra a anterior. Na efetivação do estagiário (CA-04-006), o RH informa a data de admissão CLT, e o estágio termina na véspera, com o motivo "Efetivação"; o vínculo CLT novo vem com a unidade, o departamento e a jornada do estágio, e o RH escolhe o cargo e o salário, com a regra da faixa (RN-04-032) | 2026-10-17 |
| D-605 | Bloco 4d da spec 04. O convite do gestor do cliente sai neste bloco, e não com a admissão como previa a D-600: o RH administrador convida a pessoa pela tela do cliente, com o perfil `client_manager` e o MFA obrigatório (RN-02-040, RN-02-064), atribui os clientes, e o gestor vê a lista dos colaboradores alocados com os dados básicos (escopo K, spec 03, seção 4.12). Os itens de admissão do gestor do cliente continuam na spec 07. O campo personalizado obrigatório vale quando o RH salva a ficha; fichas antigas sem o valor continuam válidas e mostram o aviso, e o campo não bloqueia vínculos nem revisões. Campos personalizados não guardam dado sensível (D-086): a tela de criação avisa que saúde, documentos e dados bancários têm lugar próprio na ficha, e os valores ficam no JSONB sem criptografia | 2026-10-17 |
| D-606 | A parte da spec 05 prevista para a fase 1 termina com a CSP e os cabeçalhos de segurança (P-05-29), num PR pequeno antes do próximo bloco, para que toda tela nova já nasça sob a política. A varredura de vírus dos uploads (P-05-30, ClamAV) sai da fase 1 e entra com a pasta de documentos (spec 08), quando colaboradores e candidatos passam a enviar arquivos; até lá, só o RH envia arquivos (as imagens da marca, com o tipo validado), e o serviço `clamav` não sobe no Railway. O próximo bloco da fase 1 é a base da spec 15, antes da spec 19, cuja régua de inadimplência usa os avisos dela | 2026-10-18 |
| D-607 | A base da spec 15 (fase 1) sai em dois PRs. O 15a traz o catálogo no código, as notificações e as entregas, o e-mail com a marca, o sino nos painéis, a regra de duplicidade (RN-15-085), as novas tentativas (RN-15-084), a retenção (RN-15-090) e o job diário das revisões (P-04-29, D-602). O 15b traz as preferências da empresa e da pessoa (RN-15-020 a RN-15-023) e os eventos do SES pelo SNS, com o e-mail inválido e o aviso `contacts.email_invalid` (RN-15-080, RN-15-083, P-15-24). Até o resumo diário (RN-15-040, fase 2), os avisos não urgentes do RH vão por e-mail um a um; quando o resumo entrar, passam para ele. O catálogo e as telas de preferências mostram só os tipos que o sistema já gera, e cada spec acrescenta os seus (RN-15-013). Os avisos de MFA redefinido, de contato alterado e do status do domínio de e-mail da marca passam pelo motor, com o sino e as preferências. O aviso ao e-mail antigo continua direto, porque o destino não é uma pessoa do sistema. A conta bloqueada vai só para o sino, porque o e-mail de desbloqueio já é um aviso de acesso (RN-15-011). A transferência da empresa e o pedido de ligação ao escritório contábil, que não estão no catálogo, continuam como estão | 2026-10-18 |
| D-608 | Detalhes do bloco 15a. O sino segue o catálogo: um tipo sem o canal S (contato alterado, comprovante e lembrete de marcação) não aparece no sino, e o "sempre no sino" da seção 2 e da RN-15-081 vale para os tipos com S. O aviso das revisões que entram em vigor (P-04-29) sai uma vez por dia para cada pessoa do RH, com as revisões do escopo dela, só com nomes e motivos, sem salário (RN-15-005); o link leva à ficha quando há uma revisão e à lista de colaboradores quando há várias, e a revisão de admissão fica de fora. A notificação sai do sino com 90 dias e é apagada com 1 ano, junto com as entregas (RN-15-090) | 2026-10-18 |
| D-609 | Bloco 15b da spec 15. Um e-mail com devolução permanente (RN-15-083) deixa de receber **todo** e-mail do sistema: avisos, convites e recuperação de senha. A lista de supressão da conta no SES já descartaria o envio, então o sistema diz na hora que o e-mail é inválido (por exemplo, no convite: corrigir o contato ou usar o link), em vez de parecer que enviou. A marca sai quando o e-mail é trocado. Para liberar o mesmo endereço, depois que a pessoa corrigiu a caixa, o suporte usa o admin, que tira a marca e tira o endereço da lista de supressão do SES; isso exige a permissão `ses:DeleteSuppressedDestination` no usuário da aplicação. A assinatura das mensagens do SNS (P-15-24) é conferida pelo verificador oficial da AWS, da gem `aws-sdk-sns` | 2026-10-18 |
| D-610 | A spec 19 (fase 1) sai em nove PRs, primeiro o que não depende de fornecedor: 19a, planos, módulos e adicionais, com as versões de preço; 19b, contratos e assinaturas, o cadastro de parceiro e de empresa direta pelo admin e da empresa cliente pelo parceiro (P-03-14), os módulos contratados na `Ability`, o módulo por empresa da carteira e o teste grátis; 19c, o consumo, as cotas e o relatório do parceiro; 19d, as faturas e os ajustes, sem pagamento; 19e, o PIX pelo Mercado Pago, com o webhook e a conferência diária; 19f, a régua de inadimplência, a somente leitura e o cancelamento; 19g, o painel da equipe CatalystHR; 19h, o cartão salvo pelo Mercado Pago, que depende da liberação dos Pagamentos Automáticos; 19i, a NFS-e pelo Asaas, que depende da conta no Asaas e das respostas do contador. O `trial_expired` e o `closing` entram com os status e a somente leitura; a exportação completa (spec 18) e a exclusão do encerramento (spec 05) entram na fase 2, e até lá nenhum dado é apagado automaticamente, então o CA-19-004 fecha na fase 2. Não há dados em produção, então nenhum parceiro ou empresa precisa de migração para um contrato; a cobrança entra desligada pela feature flag `billing` até o lançamento. No painel da equipe CatalystHR (RN-19-090), a fase 1 traz só os blocos Receita e Clientes, sem a adoção (spec 17); Custos contra o cobrado e Operação entram quando as fontes existirem (specs 13, 14 e 15), e o CA-19-011 fecha na fase 2 | 2026-10-19 |
| D-611 | Bloco 19a da spec 19. O plano guarda o tipo, o nome e a situação; os preços, os limites, as cotas e o preço de cada módulo ficam em versões do plano, com a data de início, e a assinatura aponta para a versão. Uma versão nunca é alterada: mudar o preço cria uma versão nova, que vale para contratos novos a partir da data dela, e os contratos existentes continuam na versão antiga até o financeiro migrá-los, com aviso de 30 dias (RN-19-014). Uma versão futura é corrigida por outra com a mesma data, e entre versões da mesma data vale a registrada por último, como nas revisões do vínculo (D-603). O preço dos adicionais segue a mesma regra, com versões próprias. Os planos privados (RN-19-015) entram no 19b, junto com os contratos aos quais pertencem; o 19a traz só os planos públicos. Os módulos usam os códigos que o sistema já tem, `ponto` e `folha` (a folha inclui o eSocial, D-111), e toda versão traz o preço dos dois | 2026-10-19 |
| D-612 | Mensalidade de pré-ativação do parceiro. Depois do teste grátis, que continua (D-485), o parceiro que contrata paga só um valor simbólico enquanto a carteira não tem nenhum colaborador ativo (vínculo ativo ou afastado, a mesma medida da RN-19-020). O valor é único para todos os planos de parceiro, definido pelo superadmin e pelo financeiro, e tem versões como os preços (D-611): o valor novo vale para contratos novos, e os existentes mudam quando o financeiro os migrar, com aviso de 30 dias. A contratação continua cobrando na hora e começando o ciclo (RN-19-033), agora com o valor simbólico. Nesse período, o valor simbólico substitui a faixa e os módulos; os adicionais são cobrados desde a contratação, porque têm custo real; as cotas de IA e WhatsApp são as reduzidas do teste (100 créditos e 100 mensagens, RN-19-031), com o excedente pelos preços do plano. No primeiro dia com um colaborador ativo na carteira, a faixa e os módulos passam a valer na hora, e a diferença proporcional aos dias até o fim do ciclo entra na próxima fatura, como num aumento (RN-19-060). A ativação é única: se depois a carteira ficar sem colaboradores ativos, a cobrança não volta ao valor simbólico. Quem já tem colaborador ativo ao contratar paga a faixa desde o início. Vale só para parceiros; a empresa direta segue a RN-19-033 sem mudança | 2026-10-19 |
| D-613 | O bloco 19b da D-610 se divide em dois PRs. O 19b-1 traz o contrato e a assinatura com os status, o cadastro de parceiro e de empresa direta pelo admin (RN-19-081) e o valor de pré-ativação (D-612). O 19b-2 traz a empresa cliente cadastrada pelo parceiro (P-03-14), o módulo ligado por empresa da carteira (RN-19-012), os módulos contratados na `Ability` e no menu (CA-19-003) e o job do teste, com os avisos. A contratação pelo próprio cliente durante o teste (RN-19-033) entra no 19e, com o PIX, e o cartão no 19h. O teste vencido muda de status no 19b-2, e o bloqueio de escrita em todo o sistema nasce no 19f, para o teste vencido e para o atraso. O teste ou o contrato cadastrado pelo admin começa no dia do cadastro, sem data futura, e o ciclo é esse dia. Os planos privados (RN-19-015) passam para o 19d, porque aplicá-los é uma troca de plano (RN-19-060, RN-19-061); revisa a parte da D-611 que os punha no 19b | 2026-10-19 |
| D-614 | Regra inalterável do sistema: toda tabela tem chave primária UUIDv7, gerada pelo banco (`uuidv7()`, nativo do Postgres 18), e toda coluna que aponta para uma linha (chaves estrangeiras, pares polimórficos, listas de ids) é UUID. Vale para as tabelas do sistema e das bibliotecas: Active Storage, PaperTrail e Flipper. A única exceção é a `solid_cache_entries`, cache descartável que nenhuma tabela referencia, porque o Solid Cache estima o tamanho do cache por `max(id) - min(id)`. As 54 migrações das fases 0 e 1, com ids numéricos, foram substituídas por uma migração base, seguida da carga da CBO; como não havia dado a manter em produção, o banco de produção é recriado, depois de um backup. A regra é conferida por um teste do schema e por uma verificação do `strong_migrations` em toda migração nova | 2026-10-19 |
| D-615 | As telas usam a largura inteira da tela, sem o limite de 1.152 px da área de conteúdo nem os limites menores de cartões, tabelas e formulários. Os campos dos formulários e os detalhes se distribuem em colunas: uma no celular, duas a partir do tablet, três em telas largas e quatro nas muito largas; um campo que precisa de espaço ocupa duas colunas ou a linha toda. O login, as telas do MFA (ativação e códigos de recuperação, centralizadas com cerca de 768 px), as telas de uma coluna só (como "Em breve") e os e-mails continuam centralizados, com largura limitada. Ajusta a base visual (D-597) | 2026-10-19 |
| D-616 | Bloco 19b-2 da spec 19. Os módulos que a empresa usa vêm do contrato (P-03-12): o da empresa direta, ou o do parceiro, desde que o parceiro tenha ligado o módulo para a empresa. Os módulos liberados ao RH analista, ao consultor e ao suporte valem só dentro dos contratados, e o eSocial acompanha a folha. No teste, o ponto e o eSocial não funcionam (RN-19-031). No menu da empresa, o módulo não contratado ou desligado pelo parceiro não aparece; no teste, o ponto aparece com a etiqueta "Após a contratação" e abre uma página que explica (CA-19-003); o contratado continua "Em breve" até ser construído. No cadastro da empresa cliente pelo parceiro (P-03-14), cada módulo contratado tem uma caixa, já marcada, e depois o parceiro liga e desliga cada um na carteira (RN-19-012). Os avisos do teste (`billing.trial_ending` 3 dias e 1 dia antes do fim, e `billing.trial_expired`) vão sem o botão Contratar e pedem para falar com a equipe da CatalystHR; o botão entra no 19e, com a contratação pelo cliente. O teste vence no dia guardado como fim do teste. Tudo isso fica atrás da flag `billing`: desligada, os módulos continuam como antes dos contratos, as telas do parceiro não aparecem e o job não faz nada | 2026-10-19 |
| D-617 | As feature flags (RN-20-030) ganham uma tela própria no admin, só do superadmin, no visual da D-597. A tela lista as flags declaradas no código, com a descrição e a situação de cada uma, avisa quando o banco está diferente do código, e liga e desliga cada flag para todos, guardando quem mudou e quando. Não cria flags: uma flag nasce com a função que a consulta, no deploy, desligada. Também cria, desligadas, as flags do código que faltam no banco e remove as que o código não declara mais. A `sign_in` não é desligada pela tela, porque sem ela nenhuma página abre, nem a própria tela; só pelo console. Ligar por empresa entra quando a primeira função consultar a flag por empresa. Sem a gem de interface do Flipper, que tem visual próprio e não grava a nossa auditoria. Sai num PR próprio, depois do 19b-2; até lá, as flags mudam pelo console, com confirmação | 2026-10-19 |
| D-618 | Bloco 19c da spec 19. Um vínculo conta como colaborador ativo nos dias entre a admissão e o último dia: ativo, afastado, ou desligado até a data do desligamento; pendente e cancelado não contam, e o desligado em período de leitura deixa de contar no dia seguinte ao fim (CA-19-002). Toda madrugada, à 1h de Brasília, o job grava o dia que terminou, para cada empresa dos contratos fora de `closing` e `closed` (RN-05-084), a partir do cadastro da empresa ou do início do contrato, o que vier por último, e grava também os dias do mês que faltarem; um dia gravado não muda. O mês de cada empresa e do contrato é recalculado todo dia a partir dos dias gravados e fecha no dia 1; o job de fechamento roda todo dia, fecha o mês anterior e qualquer mês anterior ainda aberto, e um mês fechado não recebe dias novos. Os créditos de IA e as mensagens de WhatsApp do mês vêm dos lançamentos das specs 14 e 15 quando existirem, e até lá ficam em zero; os avisos de 80% e 100% de IA e de WhatsApp continuam nos jobs dessas specs (RN-14-112, RN-15-064). O 19c avisa só a faixa de colaboradores do parceiro, pelo `billing.usage_threshold`, uma vez por limite em cada mês; a empresa direta não tem faixa, e na pré-ativação a faixa não vale e não há aviso. A pré-ativação termina no primeiro dia gravado com um colaborador ativo na carteira (RN-19-035). Relatório do parceiro (RN-19-024): a coluna CNPJ/CPF traz o CNPJ da matriz da empresa e, para o empregador pessoa física, o CPF mascarado, porque o download não pede senha; os módulos do mês são os ligados em pelo menos um dia; o CSV usa ponto e vírgula, com BOM, para abrir certo nas planilhas em português; o mês corrente é parcial, até o último dia gravado, e o relatório é montado na hora a partir do mês, sem arquivo guardado. A tela Consumo fica no painel do parceiro, só para o administrador, atrás da flag `billing` | 2026-10-20 |
| D-619 | O bloco 19d da spec 19 se divide em dois PRs. O 19d-1 traz as faturas: geração, linhas, numeração, aviso e telas. O 19d-2 traz a troca de plano e de módulos com o proporcional (RN-19-060, RN-19-061), os planos privados (RN-19-015), a migração de preço (RN-19-014) e os ajustes com a aprovação do superadmin (RN-19-070, RN-19-071). A fatura de cada ciclo é gerada 3 dias antes e vence no primeiro dia do ciclo, cobrando o mês que começa; o ciclo tem um mês, do dia do ciclo até a véspera do seguinte. A fatura do primeiro ciclo de um contrato cadastrado pelo admin sai no cadastro e vence no mesmo dia, como na contratação pelo cliente (RN-19-033). O excedente da fatura (colaboradores acima da faixa, créditos de IA e mensagens de WhatsApp) é o do último mês do calendário já fechado, cobrado uma vez só: a fatura emitida em 12/11 traz o de outubro. Na empresa direta, o plano e os módulos por colaborador usam o pico do último mês fechado, e, sem mês fechado (primeira fatura), os colaboradores ativos no dia; o mínimo mensal vale só para a linha do plano, e os módulos somam por colaborador. No parceiro, a faixa e as cotas do plano valem a partir da ativação; antes dela valem as cotas reduzidas (RN-19-031, D-612). Os ajustes acima de 20% (RN-19-071) serão comparados com a prévia da próxima fatura, calculada quando o financeiro lança o ajuste. A numeração das faturas é única na plataforma e sequencial, sem buracos, exibida com seis dígitos (000123). São cobradas as assinaturas ativas, em atraso, em somente leitura ou com cancelamento agendado; o teste, o teste vencido, o encerramento e o encerrado não são. As faturas aparecem no admin (superadmin, financeiro e suporte, só leitura), no painel do parceiro (administrador) e na empresa direta (RH administrador), cada um vendo só o próprio contrato; a empresa de parceiro não tem fatura (RN-19-001). O aviso `billing.invoice_issued` vai ao responsável; a cópia para o e-mail de cobrança adicional (RN-19-044) entra com a tela que o cadastra. Até o 19e, a fatura orienta a falar com a equipe da CatalystHR para pagar | 2026-10-20 |
| D-620 | O bloco 19d da D-619 passa a sair em três PRs: o 19d-2 traz as trocas, os planos privados e a migração de preço, e o 19d-3 traz os ajustes manuais com a aprovação do superadmin (RN-19-070, RN-19-071). No 19d-2, só o superadmin e o financeiro trocam plano, módulos e adicionais, pela página do cliente no admin; a troca pelo próprio cliente entra no 19e. Uma troca de plano é aumento quando o mês ficaria mais caro com os mesmos colaboradores e módulos, e redução quando ficaria igual ou mais barato. O aumento (de plano, módulo ou adicional) vale na hora, e a diferença proporcional aos dias da mudança até o fim dos ciclos já faturados, contando o dia da mudança e cada ciclo pelos seus dias, entra uma vez na próxima fatura, com meio centavo arredondado para cima (CA-19-005). A redução vale depois do último dia já faturado: o plano, no ciclo seguinte; o módulo ou o adicional, saindo nesse dia, com o aviso de que os dados continuam guardados (RN-19-061). Sem fatura ainda (no teste), toda troca vale na hora, sem proporcional. A troca para o mesmo plano não existe: o preço novo do mesmo plano é a migração de preço (RN-19-014). Ela leva o contrato para a versão vigente do plano a partir do primeiro ciclo que começa pelo menos 30 dias depois do aviso, sem proporcional, e o responsável recebe o aviso novo `billing.price_change` (obrigatório, no sino e por e-mail). A redução e a migração ocupam a mesma troca agendada, e a mais recente substitui a anterior; o financeiro pode desfazê-la antes de valer. A migração dos preços dos adicionais fica para depois. Na ativação do parceiro (D-612), a diferença entre a faixa com os módulos e a pré-ativação, pelos dias já faturados a partir do primeiro colaborador ativo, entra na próxima fatura. O plano privado (RN-19-015) pertence a um contrato do mesmo tipo, não aparece no cadastro de clientes e só é oferecido na troca de plano desse contrato | 2026-10-20 |
| D-621 | Bloco 19d-3 da spec 19, os ajustes manuais (RN-19-070, RN-19-071). O financeiro e o superadmin lançam, pela página do cliente no admin, desconto (em valor ou em percentual, numa fatura ou em até 12 seguidas), crédito ou isenção de excedente, sempre com motivo; o motivo fica na auditoria e no admin, e a fatura mostra só o tipo de ajuste. O desconto percentual incide sobre todas as linhas da fatura antes dos ajustes: plano, módulos, adicionais, excedentes e proporcionais. O crédito abate as próximas faturas até acabar, e a sobra passa para a seguinte. A isenção tira da próxima fatura o excedente escolhido pelo financeiro: colaboradores, IA, WhatsApp ou todos. Na fatura, os ajustes aprovados entram como linhas negativas, na ordem isenção, desconto e crédito, e a fatura nunca fica abaixo de zero; o desconto e a isenção usam a fatura mesmo quando não há o que abater, e o crédito só usa o que abate. Lançado pelo financeiro, o ajuste que passa de 20% da prévia da próxima fatura (o percentual direto, ou o valor e o excedente isento sobre o total da prévia, D-619) fica aguardando o superadmin, que recebe o aviso novo `platform.adjustment_pending` (obrigatório, no sino e por e-mail) e aprova na tela Ajustes do admin; o ajuste do superadmin vale direto. Um ajuste só vale depois de aprovado, e o que ainda não entrou numa fatura pode ser cancelado pelo financeiro ou pelo superadmin. O suporte só lê | 2026-10-20 |
| D-622 | Bloco 19e da spec 19, o PIX pelo Mercado Pago (RN-19-042, RN-19-046), em dois PRs: o 19e-1 traz o PIX das faturas, o webhook e a conferência diária; o 19e-2, a contratação pelo cliente durante o teste (RN-19-033). A cobrança usa a **API de Orders** (`/v1/orders`), que o Mercado Pago recomenda para integrações novas, e não a de Payments (`/v1/payments`), que ele marca como legado; revisa a referência da P-19-29. O acesso é por um **cliente HTTP próprio** (Net::HTTP), e não pela gem oficial: a 3.5.0 foi publicada sem arquivos, e a 3.4.0 rebaixaria o json de todo o app para a série 2. A assinatura do webhook segue a lógica dos SDKs oficiais (HMAC-SHA256 de id, request-id e ts). O PIX é gerado quando a fatura é emitida e vale até o fim do dia do vencimento (no mínimo 30 minutos, o limite do Mercado Pago). Depois disso, quem paga a fatura gera um PIX novo ao abri-la, válido até o fim daquele dia; o impersonate não gera PIX. O pagamento ganha o status `cancelled` para o PIX que expirou ou foi trocado: `pending` → `approved` | `rejected` | `refunded` | `cancelled`. Um PIX ainda pendente 31 dias depois de expirar é cancelado pela conferência, e um pagamento que chega depois de cancelado ainda paga a fatura. Pago o PIX (com o valor da fatura), a fatura fica paga e o contrato em `past_due` ou `read_only` volta a `active` na hora, se nenhuma outra fatura estiver vencida (RN-19-053). Na contratação durante o teste por PIX (19e-2), o contrato só passa a valer com o pagamento: o PIX vale até 23h59 do dia, o teste continua enquanto isso, e o ciclo começa no dia do pagamento; não pago, o cliente contrata de novo | 2026-10-21 |
| D-623 | Bloco 19e-2 da spec 19, a contratação pelo cliente (RN-19-033, RN-19-034, D-622). O responsável financeiro (administrador do parceiro ou RH administrador da empresa direta) contrata pelo menu Contratar, durante o teste e também nos 30 dias depois dele (`trial_expired`), escolhendo entre os planos oferecidos ao contrato e os módulos; os adicionais continuam como estão. A escolha já vale para o contrato em teste, e sai na hora a primeira fatura, marcada como da contratação, com vencimento no dia e o PIX válido até 23h59; o ciclo passa a ser esse dia do mês. Pago o PIX, o contrato fica `active` a partir desse dia. Contratar de novo no mesmo dia cancela a fatura anterior (motivo "substituída"), e a fatura não paga é cancelada na conferência da madrugada seguinte (motivo "contratação não paga"), depois de conferir os PIX; o número dela fica na sequência como cancelada. O parceiro sem nenhum colaborador ativo no dia começa na pré-ativação (RN-19-035). Os avisos do fim do teste levam para Contratar. O excedente entra nas faturas a partir do mês em que o contrato começou: os meses só de teste nunca são cobrados, e o mês da contratação entra inteiro, porque o consumo é apurado por mês | 2026-10-21 |
| D-624 | Bloco 19f da spec 19, em dois PRs: o 19f-1 traz a régua de inadimplência, a somente leitura e a reativação; o 19f-2, o cancelamento pelo cliente (RN-19-062, RN-19-063). A régua (RN-19-050) roda todo dia às 3h, depois da conferência dos PIX, e conta do vencimento da fatura mais antiga ainda não paga: no dia 1, as faturas vencidas ficam `overdue`, o contrato `past_due` e sai `billing.overdue`; de novo nos dias 5 e 10; no dia 15, `read_only`, com `billing.overdue` ao responsável e `billing.partner_read_only` (sem valores) ao RH administrador de cada empresa da carteira do parceiro (RN-19-052); no dia 25, `billing.contract_closing`; no dia 30, `closing`. Cada fatura guarda o último passo avisado, então a régua não repete avisos e, depois de dias sem rodar, avisa só o passo mais recente. O status segue a fatura mais antiga não paga, então o pagamento volta o contrato na hora (RN-19-053), menos no `closing`. Em `read_only`, `closing`, `closed` e `trial_expired` (D-613), nada novo é criado ou alterado no painel, no contrato e em todas as suas empresas: a escrita é recusada com mensagem, e uma faixa no topo explica (a empresa da carteira vê só "Acesso limitado por pendência com [parceiro]"; o responsável vê o caminho para pagar ou contratar). Continuam liberados a conta da própria pessoa (sair, senha, MFA, dispositivos, preferências de aviso, aceite dos termos, confirmação de senha), a troca de empresa, o pagamento e a contratação; o ponto e o eSocial seguem a RN-19-051 quando existirem. Na fase 1, o `closing` não tem exportação nem exclusão (D-610): o superadmin reativa pela página do cliente, com motivo, em até 90 dias, desde que nenhuma fatura esteja vencida; o pagamento sozinho não reativa o `closing`. A fatura que os ajustes levam a zero já sai paga, sem PIX e fora da régua; na contratação, ela começa o contrato na hora | 2026-10-21 |
| D-625 | Bloco 19f-2 da spec 19, o cancelamento pedido pelo cliente (RN-19-062, RN-19-063, D-489). O responsável financeiro (administrador do parceiro ou RH administrador da empresa direta) cancela em Faturas → Cancelar contrato, depois de digitar a senha de novo, escolhendo um motivo da lista (preço; faltou alguma funcionalidade; vamos usar outro sistema; dificuldade de uso; a empresa encerrou ou reduziu as atividades; outro motivo), com texto livre opcional e obrigatório em "outro motivo". O cancelamento vale no último dia do ciclo em curso, sem multa; se a fatura do próximo ciclo já saiu e não foi paga, ela é cancelada (motivo "cancelamento do contrato"); se já foi paga, o cancelamento vale no fim desse ciclo. Até lá, o contrato fica `cancel_scheduled` e nenhuma fatura posterior é emitida; uma fatura em atraso segue a régua (D-624) sem perder o cancelamento agendado. Até o último dia, o cliente desfaz com a senha, e o superadmin ou o financeiro desfazem pelo admin, com motivo; desfeito, o ciclo cancelado volta a ser faturado. No dia seguinte ao último, o contrato entra em `closing`, em somente leitura (D-624). O responsável recebe `billing.cancel_scheduled` no pedido; o RH administrador de cada empresa da carteira recebe `billing.partner_cancelled` 30 dias antes do fim, ou no pedido, se faltar menos, uma só vez e sem valores. A transferência das empresas pelo superadmin segue a D-123 e a D-599 | 2026-10-21 |
| D-626 | Bloco 19g da spec 19, o painel da equipe CatalystHR com os blocos Receita e Clientes (RN-19-090, RN-19-091, D-610). Fica em Cobrança → Indicadores (`/dashboard`), atrás da feature flag `billing`; o superadmin e o financeiro veem os dois blocos, e o suporte só Clientes (P-19-28). **Receita:** a receita recorrente mensal soma, nos contratos `active`, `past_due`, `read_only` e `cancel_scheduled`, as linhas de plano (ou a pré-ativação do parceiro), módulos e adicionais da prévia do próximo ciclo, pelo mesmo cálculo das faturas, sem ajustes nem excedentes; na empresa direta, com os colaboradores do último dia gravado. Os excedentes do mês são as linhas de excedente das faturas emitidas no mês, sem as canceladas. A inadimplência é o valor das faturas vencidas e os contratos com fatura vencida por status (`past_due`, `read_only`, `closing`). A conversão de testes conta os testes que terminaram nos últimos 90 dias, sendo o fim a data do teste ou a do pagamento da contratação, se vier antes, e quantos contrataram (fatura de contratação paga). **Clientes:** cada contrato não encerrado, com plano, colaboradores do último dia gravado, uso do mês contra a faixa e as cotas, último acesso e risco. Os acessos são os logins já gravados em `access_events` (`auth`, `sign_in`), pela marca do contrato, sem a equipe CatalystHR: as pessoas distintas com login em cada dia, somadas em cada janela de 30 dias. Os sinais do risco: queda de 30% ou mais nos acessos dos últimos 30 dias contra os 30 anteriores (só com acessos na janela anterior); fatura vencida; módulo retirado ou com retirada agendada nos últimos 30 dias, pelo histórico do PaperTrail, sem as retiradas desfeitas; e nenhum login em 14 dias do RH administrador da empresa direta ou do administrador do parceiro, para contratos com 14 dias ou mais. Risco alto com dois sinais ou mais. O custo da IA e a cotação do dólar (RN-19-092, `Billing::FxRateJob`) entram com o bloco Custos, na spec 14 | 2026-10-22 |
| D-627 | A spec 20 na fase 1 sai em três PRs: 20a, o pg_dump diário com o registro em `backup_runs`, o ensaio de restauração e o lembrete trimestral (RN-20-041, RN-20-046); 20b, o `/up/deep`, o Sidekiq Web no admin e os níveis de alerta (RN-20-074, RN-20-075, RN-20-077); 20c, o cadastro do plantão e o endpoint `/internal/alerts`, com o envio pela Twilio desligado por feature flag até a conta ser aprovada (RN-20-076). O PITR (RN-20-040) espera a revisão do plano do Railway, antes do primeiro cliente. **Monitores do Sentry:** o plano gratuito inclui um monitor de job e um externo, e os adicionais (US$ 0,78 e US$ 1 por mês) só existem nos planos pagos. O único monitor de job fica com o pg_dump; os outros jobs da RN-20-073 e os monitores externos além do `/up` entram ao rever o plano do Sentry, antes do primeiro cliente. Até lá, as falhas dos jobs chegam ao Sentry como erro. **Criptografia do pg_dump:** pelo SSE-KMS do bucket `catalysthr-backups`, com a chave `catalysthr-backups` informada no envio, em vez da criptografia no cliente; ler um backup exige `kms:Decrypt`, que só o usuário de restauração tem. O envio é um `PutObject` único (até 5 GB), que pede só `kms:GenerateDataKey`; o multipart pediria também `kms:Decrypt`. Revisa o texto da RN-20-041. **pg_dump 18:** o Debian 13 traz o cliente 17, que não copia o Postgres 18; a imagem instala o `postgresql-client-18` pelo repositório oficial do PostgreSQL (PGDG), e o serviço `backup` roda uma tarefa Rails. A faixa de incidente (RN-20-078) fica para a fase 2 | 2026-10-22 |
| D-628 | NFS-e do CatalystHR, com as respostas do contador da DevBatista (Contabilizei) de 2026-10-22. Continua uma nota por fatura paga (RN-19-100). A competência é o mês em que começa o ciclo da fatura, mesmo quando o pagamento e a emissão acontecem depois. O excedente e o proporcional do ciclo anterior entram na mesma nota, com o período da medição na descrição. A emissão é pelo Portal Nacional da NFS-e (obrigatório para o Simples desde 2026-11-01), não pela NFS-e Paulistana, com o regime de apuração pelo Simples Nacional, o regime especial "0 - Nenhum" e a série 1 da DPS só para o Asaas, separada da série da Contabilizei (série revista pela D-634: 80000). A alíquota do Simples não vai na nota. Fecha o item em aberto do fato gerador (RN-19-104) | 2026-10-22 |
| D-629 | O bloco 20c da D-627, o reenvio ao plantão (RN-20-076: cadastro dos plantonistas, `/internal/alerts` e `infra_alerts`), sai da fase 1 e entra antes do primeiro cliente, junto com a revisão dos planos do Sentry e do Railway e com a conta da Twilio aprovada. O plano gratuito do Sentry só alerta por e-mail, sem webhooks nem integrações ("Alerts and notifications via integrated tools: No", conferido na página de preços em 2026-10-23), então o alerta não teria como chegar ao endpoint; assim, o endpoint é feito e testado com o formato real do webhook. O plano gratuito também tem um só usuário, e até lá os alertas por e-mail chegam só ao responsável | 2026-10-23 |
| D-630 | O `secret_key_base` de produção passa a vir da variável `SECRET_KEY_BASE` do Railway, com o valor no `web` e referências `${{web.SECRET_KEY_BASE}}` nos outros serviços, e não mais do `config/credentials.yml.enc` com o `RAILS_MASTER_KEY`. O arquivo de credenciais só guardava o `secret_key_base`, e todos os outros segredos já ficavam em variáveis de ambiente; o `RAILS_MASTER_KEY` e o arquivo saem. Motivo: a troca da R-001, depois do incidente do Railway de 2026-10-21; trocar a chave das credenciais exigiria mudar o arquivo no repositório e a variável no Railway ao mesmo tempo, sob risco de o app não subir, e deixaria um segredo a mais. O valor novo foi gerado direto no Railway, sem passar pelo chat. Trocar o `SECRET_KEY_BASE` derruba as sessões, o "lembrar este aparelho" do MFA e os links de redefinição de senha e de desbloqueio em aberto | 2026-10-26 |
| D-631 | O site institucional (`catalysthr.com.br`, RN-20-022) fica num repositório próprio e privado, `devbatista/catalysthr-site` (local em `~/dev/html_css/catalysthr`), fora desta aplicação: o repositório é o próprio site estático (HTML, CSS e JavaScript puro, sem framework e sem etapa de montagem; o CSS foi gerado uma vez com o Tailwind e é editado direto), com fontes hospedadas no próprio site, sem cookies, rastreadores nem formulários, e publicado na hospedagem da HostGator que a DevBatista já tem. O site traz a apresentação do produto com cenas guiadas pela rolagem, os termos de uso (da minuta de `docs/checklist/juridico/`) e uma política de privacidade própria do CatalystHR, que cobre o site e o papel da DevBatista como operadora. As duas são publicadas **antes da revisão jurídica**, por decisão do responsável, com o risco aceito. Motivo: a AWS recusou a saída do sandbox do SES em 2026-10-27 (caso 179201169800267), e o site informado no pedido só mostrava a tela de login, sem site público nem política de privacidade | 2026-10-27 |
| D-632 | Códigos da NFS-e do CatalystHR no Portal Nacional, pelo Asaas, com as respostas da Contabilizei de 2026-10-27 (pelo assistente "Contador Inteligente" do chat, não por um especialista humano, com o risco aceito pelo responsável): código de tributação nacional **010501** (item 01.05, licenciamento ou cessão de direito de uso de programas de computação), NBS **115062100** (hospedagem de aplicativos e programas, software como serviço), que segundo a Contabilizei é a combinação padrão com o item 01.05 na tabela de correlação da NFS-e Nacional (a alternativa de licenciamento puro, 111032200, fica de reserva se o Portal recusar), e indicador de operação (cIndOp) **100501**. No Asaas, o código municipal de São Paulo é o **02800** (item 01.05), porque a lista do Asaas não tem o 02798 de D-628; não é preciso ativá-lo no CCM, que já tem o item 01.05. Em 2026, os campos de IBS, CBS e cClassTrib ficam fora da nota do Simples. A combinação é conferida na primeira nota real: uma recusa do Portal aparece na fatura, sem nota silenciosa. Os campos de 2027 e a escolha do regime ficam em aberto | 2026-10-27 |
| D-633 | NFS-e pelo Asaas (bloco 19i), com as escolhas do responsável de 2026-10-28. **Competência:** a API do Asaas não tem campo de competência, só a data de emissão (`effectiveDate`); a nota é agendada para o maior entre o dia da confirmação do pagamento e o primeiro dia do ciclo. Paga antes do ciclo, ela sai no primeiro dia do ciclo, com a competência da D-628; paga depois do mês do ciclo, sai na hora e a competência diverge, caso a levar ao contador. Revisa a "emissão imediata" da RN-19-104 para os pagamentos antecipados. **Configuração fiscal:** a conta do Asaas (Portal Nacional, credenciais de acesso, série e número da DPS, regime e inscrição municipal) é configurada no painel do Asaas, e nenhuma credencial passa pela plataforma; o admin guarda o que vai em cada nota (código e nome do serviço, NBS, indicador de operação, descrição, observações e retenções) e mostra a situação da conta do Asaas só para leitura. Revisa o primeiro item da RN-19-102. **Cliente no Asaas:** vai sem e-mail e com `notificationDisabled`, para o Asaas não ter a quem escrever (D-564), e o aviso sai só pela plataforma; o parceiro vai sem endereço, que o cadastro não tem, e a empresa direta, com o endereço da sede. Revisa a RN-19-103. **Integração:** cliente HTTP próprio com `Net::HTTP`, como o do Mercado Pago, sem gem nova; o prefixo da chave (`$aact_hmlg_` ou `$aact_prod_`) escolhe o sandbox ou a produção. Revisa a P-19-37, que citava o Faraday. A emissão tem a flag própria `nfse`, separada da `billing`. **Achados no sandbox (2026-10-28):** o NBS só é aceito com os pontos (`1.1506.21.00`); o Portal Nacional é ligado à parte, e ligá-lo apaga a série, o número, o regime e as credenciais; em São Paulo, no Portal Nacional, o acesso é por usuário e senha, e a documentação do Asaas põe a série desse acesso entre 80000 e 89999, contra a série 1 da D-628. O código de tributação nacional (010501) não vai na nota: é um atributo do serviço no Asaas. A nota de teste não foi emitida, porque o sandbox exige as credenciais do portal e a conta usa o CNPJ real; a competência e o valor do código do serviço são conferidos na primeira nota real | 2026-10-28 |
| D-634 | Conta do Asaas de produção para a NFS-e (RN-19-102, D-633), configurada pelo responsável em 2026-10-29, com as respostas da Contabilizei de 2026-10-28 (pelo assistente "Contador Inteligente", com o risco aceito pelo responsável). **Acesso ao Portal Nacional:** por **usuário e senha** do Emissor Nacional, criados no primeiro acesso da DevBatista, e não pelo e-CNPJ A1. O Asaas diz que esse acesso "tem apresentado instabilidade" e recomenda o certificado; a escolha é do responsável, com esse risco aceito; o certificado, que assina tudo em nome da empresa, fica fora do Asaas. Uma recusa aparece na fatura (RN-19-108); se a instabilidade se confirmar, a troca pelo certificado é uma decisão nova. **Série da DPS:** **80000**, começando do número 1, porque o acesso por usuário e senha exige a faixa 80000 a 89999. Revisa a série 1 da D-628. **Conta:** Portal Nacional ligado, regime de apuração "1 - Regime de apuração dos tributos federais e municipal pelo SN", regime especial "0 - Nenhum", Simples Nacional, CNAE 6202300, inscrição municipal 18721206 e município da prestação "sempre do prestador", conferidos pela API em produção. **Serviço no Asaas:** tributação nacional 01.05.01, código municipal 02800, NBS 1.1506.21.00 (D-632), sem ISS destacado, PIS/COFINS "00 - Nenhum" e sem tributos aproximados. **Retenções:** nenhuma (PIS, COFINS, CSLL, IR, INSS e ISS). **Chave de API:** sem permissão de saque e sem data de expiração; o Asaas desabilita chave sem uso por 3 meses, então a tela Notas fiscais do admin, que lê a conta no Asaas, é aberta ao menos uma vez por mês enquanto não houver notas. **Webhook:** os oito eventos `INVOICE_*`, envio não sequencial e fila ligada, porque a plataforma relê a nota na API a cada aviso. Ficam para a primeira nota real: o valor do código do serviço que a plataforma envia, o PIS/COFINS "00 - Nenhum" e os tributos aproximados, a conferir com a Contabilizei | 2026-10-29 |
| D-635 | Endereço de cobrança do contrato, para o cliente da NFS-e no Asaas (RN-19-081, RN-19-103), com as escolhas do responsável de 2026-10-29. O Asaas não emite a nota com o cliente sem endereço, sem CEP válido ou sem e-mail ("E-mail do cliente incompleto", "Endereço do cliente incompleto", "CEP do cliente é inválido", visto no sandbox em 2026-10-29), e o cadastro do parceiro não tinha endereço. O contrato (`billing_accounts`) passa a ter o endereço de cobrança (CEP, logradouro, número, complemento opcional, bairro, município e UF), que vai ao Asaas para o parceiro e para a empresa direta, no lugar do endereço da sede. Revisa a D-633 no endereço. **Onde é obrigatório:** no cadastro do cliente pela equipe e, para quem ainda não tem, antes do primeiro pagamento, no checkout (bloco 19j-2). **Quem edita:** o administrador do cliente, na área do contrato (19j-2), e o superadmin e o financeiro, no admin. **Empresa direta:** o endereço de cobrança é separado do da matriz; o formulário vem preenchido com o da matriz quando ele existe, e mudar a matriz não muda a cobrança. Sem o endereço completo, a nota cai em erro com o motivo, sem chamar o Asaas (RN-19-108). **E-mail do cliente:** segue sem ir ao Asaas até o suporte confirmar se `notificationDisabled` também impede o e-mail da NFS-e ao tomador; se impedir, vai o e-mail de cobrança do contrato, como no PIX; se não, um e-mail da CatalystHR, para o Asaas não escrever ao cliente com a sua marca (D-564). **Serviço no Asaas:** com o Portal Nacional, a nota aponta o serviço cadastrado no painel pelo `municipalServiceCode`, igual ao "Código de serviço" do cadastro (02800), com o mesmo nome; o código de tributação nacional e o NBS são atributos desse serviço, não da nota (suporte do Asaas e documentação de `/fiscalInfo/federalServiceCodes`, 2026-10-29). Um código ou nome diferente faz o Asaas criar outro serviço, sem o código nacional | 2026-10-29 |
| D-636 | E-mail do cliente da NFS-e no Asaas (RN-19-103), completando a D-635. O suporte do Asaas respondeu em 2026-10-29 que o `notificationDisabled` **não** impede o e-mail da nota fiscal ao tomador, e, a pedido do responsável, desligou esse e-mail na conta de produção ("apenas para nota fiscal, não afeta mais nada"). Com isso, o cliente vai ao Asaas com o e-mail de cobrança do contrato, ou o do responsável, ou o do primeiro destinatário dos avisos, o mesmo critério do PIX (RN-19-044), e não com um e-mail da CatalystHR. O `notificationDisabled` continua ligado para as demais notificações. O aviso da nota ao cliente continua saindo só pela plataforma (D-564). Se o Asaas voltar a enviar a nota por e-mail, o cliente recebe a própria nota em duplicidade, sem vazamento. A configuração vale só para a conta de produção; no sandbox, o e-mail da nota continua ligado | 2026-10-29 |
| D-637 | Fase de validação antes do primeiro cliente, com a escolha do responsável de 2026-10-29. O desenvolvimento segue para a fase 2 sem esperar os terceiros, e as pendências (Mercado Pago e o bloco 19h, a saída do sandbox do SES, a primeira NFS-e real, o teste de ponta a ponta da fase 1, o PITR e os planos do Sentry e do Railway, a retenção zero da Anthropic, o jurídico, o especialista em DP, a Twilio e o piloto) passam para uma fase de validação que trava o primeiro cliente, e não o desenvolvimento. A fase 1 fica encerrada para o desenvolvimento. **Condição:** o que muda o desenho do código só é construído depois da resposta. A fase 2 se divide em duas levas: a 1 (specs 06, 07, 08, 16, 15 sem o WhatsApp, 17 e 18) não depende de ninguém; a 2 vem com as respostas: spec 09 depois do especialista em DP, spec 14 depois da retenção zero confirmada e da base legal do jurídico (antes disso, só com dados fictícios), spec 05 (resto) depois dos prazos de retenção e do encerramento validados, e o WhatsApp da spec 15 depois da Twilio e do jurídico. O primeiro cliente, antes no fim da fase 2, passa para o fim da validação (`plano-de-fases.md`) | 2026-10-29 |
| D-638 | Leva 1 da fase 2 (D-637), com as escolhas do responsável de 2026-10-29. **Ordem:** specs 06, 08, 16 e 07; depois, a 15 sem o WhatsApp, a 17 e a 18. A admissão (07) vem depois do que ela usa: o motor (06), os documentos (08) e o portal (16). **Spec 06 em três PRs:** 06a, os feriados e o cálculo de dias úteis (RN-06-026, RN-06-029, RN-11-020, P-06-20); 06b, os modelos nos três níveis, o editor, a adoção, o padrão por tipo, as condições, as dependências sem ciclo e a cópia na transferência (RN-01-053, D-599); 06c, o processo (RN-06-050 a RN-06-053), com os responsáveis, os prazos, o bloqueio, os ajustes com histórico, a dispensa, a conclusão, o recálculo, a troca de cliente, os jobs e os avisos, e uma tela genérica do processo que a 07 reaproveita. **Feriados nacionais:** segue a P-11-06 (BrasilAPI, com revisão manual da equipe antes de valerem). Em 2026-10-29, a BrasilAPI devolvia como `national` também o Carnaval, a Páscoa e o Corpus Christi, que não são feriados de lei federal; por isso o job só importa para revisão, nada vale sem a equipe publicar. Na revisão, a equipe publica os feriados de lei federal (1/1, 21/4, 1/5, 7/9, 12/10, 2/11, 15/11, 20/11 e 25/12) e a Sexta-feira da Paixão, que é feriado religioso declarado por lei municipal (Lei 9.093/1995), mas vale em quase todo o país; o RH pode desmarcá-la na unidade onde ela não for feriado. Carnaval e Corpus Christi ficam fora, por serem ponto facultativo federal; a empresa que dispensa o trabalho marca o ponto facultativo (RN-11-022). A lista vai para a conferência do especialista em DP (`pacote-especialista-dp.md`, item 3.8). **Tabelas:** duas, no lugar da tabela única do rascunho das specs 06 e 11: `holidays`, com os nacionais, estaduais e municipais, sem empresa, mantidos pela equipe; e `unit_holidays`, com `acts_as_tenant`, com os feriados e pontos facultativos da unidade e o feriado nacional desmarcado nela, para o isolamento entre empresas seguir o padrão de todos os models. Os municipais se ligam à unidade pelo código IBGE do município; unidade sem o código só recebe os nacionais e os estaduais, com aviso na tela. **Telas:** no admin, em Conteúdo → Feriados, para o superadmin e o suporte (RN-19-080), com a revisão dos nacionais, o cadastro dos estaduais e municipais e a busca de um ano na BrasilAPI; no painel, numa seção da página da unidade, onde o RH administrador inclui e exclui os dias da unidade e desmarca a Sexta-feira da Paixão, e o RH analista só vê. **Antivírus:** a varredura dos uploads (P-05-30) sai da spec 08 (D-606) e entra no 06b, com os materiais do item de leitura e aceite; a 08 reaproveita. O código e o clamav no Docker Compose entram no 06b, e os testes usam uma resposta simulada. O serviço `clamav` no Railway só é criado na fase de validação, antes de ligar a flag para um cliente, porque a documentação do ClamAV pede de 1,2 a 2,4 GiB de RAM só para as assinaturas, de US$ 12 a 24 por mês no Railway (US$ 10 por GB, preço de 2026-10-29). Sem o serviço, o arquivo fica em varredura e não é liberado (RN-20-015) | 2026-10-29 |
| D-639 | Bloco 06b da spec 06 (D-638), com as escolhas do responsável de 2026-10-30. **Dois PRs:** 06b-1, os modelos na biblioteca, no parceiro e na empresa, o editor, a adoção, o padrão por tipo, o modelo de admissão do cargo (D-204), o modelo de integração ligado à admissão (RN-06-004), as condições, as dependências sem ciclo e o teste da transferência; 06b-2, o material em PDF do item de leitura e aceite, com a varredura de vírus. **Editor:** sem Hotwire (D-022), a página do modelo lista os itens em ordem, com subir, descer, editar e remover, e cada item abre num formulário próprio, com as dependências em caixas de seleção. **Menu:** os modelos da empresa ficam em Empresa → Modelos de processo, só para o RH administrador (D-240); os do parceiro, no painel do parceiro; os da biblioteca, no admin, em Conteúdo. **Envio de documento:** o tipo de item entra com a spec 08, que cria os tipos de documento; até lá, o editor oferece os outros cinco tipos, sem nada provisório para migrar. **Transferência (RN-01-053):** como a adoção já cria uma cópia da empresa (P-06-01, D-232), não há modelo a copiar; os adotados continuam da empresa, com a origem só como informação, e os do parceiro antigo que ela não adotou ficam com ele. O serviço de transferência ganha um teste que garante isso. **Antivírus:** cliente próprio do protocolo INSTREAM do clamd por TCP, sem gem, como os clientes do Mercado Pago e do Asaas (D-633). A gem `clamav-client` citada na P-20-36 e na RN-20-015 não tem versão nova desde 2020-02-14, nem compatibilidade confirmada com o Ruby 4.0. Revisa a P-20-36 e a RN-20-015 no nome da gem. **Isolamento:** uma tabela de modelos e uma de itens, com `company_id` preenchido só nos da empresa, como no modelo de dados da spec, e dois models para cada uma: `ProcessTemplate` e `ProcessTemplateItem`, com `acts_as_tenant`, só alcançam a empresa atual; `SharedProcessTemplate` e `SharedProcessTemplateItem` só alcançam as linhas sem empresa (biblioteca e parceiro, P-06-19). Nenhum dos quatro alcança outra empresa, e adotar copia de um par para o outro. **Formulário (RN-06-030):** o item escolhe grupos inteiros da ficha (dados pessoais, endereço, documentos, conta bancária, dependentes, contato de emergência), os campos personalizados e os campos livres; no 06c, o formulário reaproveita as telas da spec 04, com as validações delas e a confirmação de senha nos dados sensíveis | 2026-10-30 |
| D-640 | Bloco 06b-2 (D-639): o material do item de leitura e aceite e a varredura de vírus, com as escolhas do responsável de 2026-10-30. **Versões (P-06-17):** tabela `process_template_materials`, com uma linha por versão do PDF e `company_id` preenchido só nas da empresa, lida por dois models, como os modelos e os itens: `ProcessTemplateMaterial` e `SharedProcessTemplateMaterial`. Enviar um PDF novo cria a versão seguinte. O editor nunca apaga versões, e remover o item também não as apaga, para o aceite do 06c apontar para a versão lida. A versão em uso é a mais nova já liberada: enquanto a nova está em varredura, vale a anterior. Um modelo só é ativado se todo item de leitura e aceite tiver uma versão liberada. O material do assistente (spec 14) fica para a spec 14. **Arquivo:** só PDF, conferido pelo conteúdo e não pela extensão, com até 10 MB, como os documentos (RN-08-010). A aplicação serve o arquivo a quem pode ler o modelo, como as imagens da marca, sem expor o endereço do bucket. **Adoção:** copia só a versão em uso, que vira a versão 1 da cópia, num arquivo novo do dono da cópia, com o resultado da varredura, porque o conteúdo é o mesmo. **Varredura (P-05-30):** tabela `file_scans`, com uma linha por arquivo do Active Storage, sem empresa, e os estados `scanning`, `clean` e `infected`. As specs 08 e 21 reaproveitam a tabela. Com o ClamAV fora do ar, o job tenta de novo depois de 1, 5, 15 e 30 minutos, e um job de hora em hora devolve à fila o que continua em varredura (RN-20-015, CA-20-005). **Com vírus:** o arquivo é apagado do storage na hora, a versão aparece como recusada na tela, e o Sentry recebe só o nome da assinatura, sem o nome do arquivo. **Docker Compose:** o `clamav` sobe junto com os outros serviços, com a imagem `clamav/clamav-debian:1.5`, que tem versões para arm64 e amd64 (a `clamav/clamav` só tem amd64). A documentação do ClamAV pede no mínimo 3 GiB de RAM para o contêiner. A saúde detalhada (RN-20-074) passa a conferir o ClamAV quando o `CLAMAV_HOST` estiver definido, para não acusar falha em produção antes de o serviço ser criado (D-638) | 2026-10-30 |
| D-641 | Bloco 06c da spec 06 (D-638): o motor dos processos, com as escolhas do responsável de 2026-10-30. **Início:** o 06c entrega o serviço que inicia um processo a partir de um modelo ativo da empresa e de um vínculo (RN-06-050) e a tela genérica do processo, sem botão de iniciar. A admissão (07), as solicitações (09) e o desligamento ligam o início; até lá, a conferência usa processos criados no dev. A troca de cliente (RN-06-036, CA-06-010) já fica ligada às alterações do vínculo da spec 04. A mudança de data de referência (RN-06-027) fica num serviço, que a 07 chama ao adiar o início. **Tipos com ação no painel:** tarefa (feito, com comentário opcional), aprovação (aprovar, ou reprovar com justificativa) e encaminhamento registrado pelo RH (data e anexo, RN-06-066). O anexo é PDF, JPG ou PNG, conferido pelo conteúdo, com até 10 MB e com varredura de vírus (P-05-30, D-640). A leitura e aceite e o formulário entram no processo, com a versão do material em uso no início (P-06-17), mas são concluídos pelo colaborador no portal (16) e na admissão (07); o encaminhamento ao escritório contábil (RN-06-065) vem com a 07. Até lá, esses itens só podem ser dispensados. O RH conclui qualquer item de tarefa, aprovação ou encaminhamento em nome do responsável (seção 6). A reprovação não conta como item resolvido: a spec que usa o processo diz o que acontece depois. **Histórico (RN-06-051):** tabela `process_events`, com quem, o quê, quando e o motivo, mostrada como linha do tempo só para o RH; o PaperTrail continua auditando. **Conclusão (RN-06-053):** o motor aceita os dois modos; até a spec de cada processo decidir, todos pedem a confirmação do RH: com os obrigatórios resolvidos, o processo fica pronto para concluir. **Permissões (spec 03, seções 4.4, 4.6 e 4.12):** o RH administrador vê e age em todos; o RH analista e o consultor, nos processos das unidades deles, com o módulo do tipo (`admissao` para admissão e integração, `solicitacoes` para fluxo de solicitação e desligamento); o gestor e o gestor do cliente veem só os itens atribuídos a eles, sem o histórico, e concluem esses itens (RN-03-014, P-03-39). **Responsáveis (RN-06-020, RN-06-022):** o papel `hr` vira quem iniciou, se for do RH da empresa; senão, o RH com acesso à unidade da pessoa (administradores, analistas da unidade e consultores atribuídos). Papel sem ninguém vai para esse RH, com alerta no processo. **Avisos (spec 15):** `processes.task_assigned` ao gestor do cliente e `processes.task_overdue` ao gestor, ao gestor do cliente e ao RH, como no catálogo; o aviso ao colaborador vem com o portal (16), porque o link dele leva ao portal. O job diário de atraso avisa uma vez por item. **Mudança de cargo, unidade ou cliente depois do início (RN-06-036):** o processo guarda os dados do vínculo no início e mostra um alerta ao RH quando eles mudam | 2026-10-30 |
| D-642 | Spec 08 (D-638), com as escolhas do responsável de 2026-11-03. **Três PRs:** 08a, os tipos de documento (os da plataforma no admin, os da empresa, a desativação e a periodicidade por cargo), a pasta da pessoa, o envio pelo RH (PDF, JPG e PNG até 10 MB, até 5 imagens juntadas num PDF pelo Prawn), a varredura de vírus pela `file_scans` (D-640), a revisão sem a IA com os motivos de correção, as versões, o documento sensível com a confirmação de senha e o evento de acesso, o item de envio de documento no editor de modelos (spec 06) e a certidão do dependente e o comprovante da conta (D-604); 08b, os vencimentos com o job diário e os avisos, o pedido avulso com o painel e a ciência eletrônica, com a recusa, as testemunhas e o comprovante em PDF; 08c, o lote, o ZIP da pasta e a exclusão recuperável com a purga. **Colaborador:** a 08 entrega os serviços, as pendências e o registro da ciência, com os testes. As telas do colaborador, a câmera traseira e a compressão no navegador (RN-08-012) entram no portal (spec 16), porque o colaborador só ganha acesso com a 07 e a 16. **Lote:** sai na 08 sem a IA. O RH escolhe o tipo e a pessoa de cada arquivo, só do escopo dele, e confirma ou descarta antes de distribuir. As colunas de sugestão e de confiança ficam vazias até a spec 14 preenchê-las. **ZIP da pasta:** sem senha. A aplicação serve o arquivo só a quem pediu, logado e com a permissão, por 24 horas, sem expor o bucket. **Tipos da plataforma:** a base começa com uma lista enxuta semeada, sem extração pela IA até a spec 14, que a equipe edita no admin. **Menu "Documentos":** a fila de versões aguardando revisão no escopo do RH, com filtros e o link para a pasta, que fica na ficha da pessoa. O 08b acrescenta os vencimentos e os pedidos, e o 08c, os lotes. **Item de envio de documento:** um tipo por item, resolvido quando o RH aprova a versão. Os documentos exigidos pelo cargo (RN-06-037) entram um por item. **Contabilidade:** a 08 entrega a permissão de leitura sem a categoria Saúde (D-193, CA-08-009), com teste. A tela da pasta para a contabilidade entra com o encaminhamento da admissão (spec 07) | 2026-11-03 |
| D-643 | Bloco 08b da spec 08 (D-642), com as escolhas do responsável de 2026-11-03. **Aviso ao RH do vencimento (RN-08-031):** o catálogo da spec 15 ganha o código `documents.hr_expiring`, "Documento vencendo na unidade", não obrigatório e não urgente, com os canais sistema e e-mail, para o RH administrador, o RH analista da unidade e o consultor, com o módulo `documentos`. O gestor continua recebendo `documents.team_expiring`, só com o texto e sem link para o arquivo (P-08-11). **Regra `age` (RN-08-033):** só confere o envio. Na revisão, um documento emitido há mais tempo do que o tipo aceita mostra a sugestão "documento vencido". Depois de aprovado, ele não vence, não gera aviso e não cria pendência. **Ciência (RN-08-050):** o RH publica um PDF, com o tipo, as pessoas e o prazo da ciência. Cada pessoa recebe o documento na pasta, com o mesmo arquivo, varrido uma vez. O documento já entra aprovado, sem passar pela fila de revisão, porque quem publica é o RH. A ciência fica aguardando até o colaborador confirmar (portal, spec 16) ou até o RH registrar a recusa depois do prazo (RN-08-053). **Grupo do pedido avulso e da publicação (RN-08-040, RN-08-050):** unidade, departamento, cargo e tipo de vínculo, mais os critérios "com dependente para salário-família" e "com dependente para IRRF". Entram só as pessoas com vínculo aberto e no escopo de quem pede. O filtro fica gravado (`audience_filter`). **Texto da ciência:** segue a RN-08-052 (confirma o recebimento, não a concordância nem a assinatura) até a resposta do jurídico aos itens 3.1 e 3.2 | 2026-11-03 |
| D-644 | Bloco 08c da spec 08 (D-642), com as escolhas do responsável de 2026-11-03. **Envio do lote (RN-08-060):** o RH cria o lote e acrescenta arquivos em rodadas de até 20 por envio, até somar 100. Cada envio fica abaixo de 200 MB. Cada arquivo vira um documento com uma versão de arquivo único, e só é distribuído depois de a varredura liberá-lo. **Exclusão (RN-08-083):** não é permitida enquanto o documento responde a um item de processo em aberto ou a uma ciência aguardando, e a tela diz o que fazer antes: dispensar o item ou registrar a recusa. O documento de um pedido pode ser excluído, e o pedido volta a ficar pendente para a pessoa, com um documento pendente novo. Recuperar devolve o documento à pasta como estava. **ZIP da pasta (RN-08-082):** traz a versão em vigor de cada documento que quem pede pode ler, numa pasta por categoria, mais um índice em texto com o tipo, a data, a situação e o hash. É gerado pelo 7-Zip do contêiner, sem gem nova, e sem senha (D-642). **Aviso do lote (RN-08-062):** um aviso `documents.batch_expiring` a quem criou o lote, 7 dias antes de ele expirar, se ainda houver arquivos sem distribuir. Ao expirar, esses arquivos são apagados | 2026-11-03 |
| D-645 | Spec 16 (D-638), com as escolhas do responsável de 2026-11-04. **Três PRs:** 16a, o portal em `/portal` (destino por perfil depois do login, barra inferior e menu lateral, Início, Docs e Mais), o convite do colaborador, as telas do colaborador da spec 08 (pasta, envio com a câmera e a compressão no navegador, correções, pedidos e "Li e estou ciente"), os itens de processo dele, os avisos dele e "Minha equipe" com o que já existe (itens de processo e documentos vencendo); 16b, o PWA (manifest em `/portal`, service worker só com a casca, "Sem conexão", faixa de nova versão, convite de instalação e aviso de navegador antigo); 16c, as passkeys (cadastro, login, MFA, confirmação de dado sensível, gestão e admin). As abas e os blocos de ponto (10 e 11), solicitações (09), folha, mural e push (15), avaliação (22) e assistente (14) entram com as specs deles. **Convite do colaborador (D-600):** o botão "Convidar para o portal" na ficha, com e-mail ou link e QR code para entregar em mãos, e "Convidar todos sem acesso" na lista de colaboradores, só por e-mail para quem tem e-mail válido; os outros ficam listados para o link. Reaproveita o convite de 72 horas da spec 02. **Itens de processo no portal:** o colaborador conclui a tarefa, a leitura e aceite do PDF (data, hora, IP e a versão lida, RN-06-060) e o envio de documento. O formulário, que o RH revisa e aplica na ficha (RN-06-030), entra com a admissão (spec 07). **Desligado em período de leitura (RN-16-050 a RN-16-052):** entra com o desligamento (spec 09), que cria esse estado | 2026-11-04 |

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
| D-587 | O desenvolvimento local roda inteiro no Docker Compose: web, Tailwind (watch) e Sidekiq em containers com uma imagem de desenvolvimento (`Dockerfile.dev`) e o código montado como volume, junto com o Postgres e o Redis. A imagem de produção (`Dockerfile`) não muda. Revisa a RN-20-034, que previa o `bin/dev` na máquina | 2026-10-15 |

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

- Cobrança e encerramento: a fatura do ciclo que começa no dia em que o contrato entra em `closing` sai 3 dias antes, ainda em `read_only` (RN-19-041). Como a régua para em `closing` (D-624), ela fica `open` mesmo vencida, fora do valor de inadimplência do painel da equipe (D-626), e continua aberta se o cliente não voltar. A reativação exige pagá-la (RN-19-053). Decidir com o encerramento da spec 05 (fase 2): cancelar as faturas abertas ao entrar em `closing`, marcá-las como vencidas também em `closing` ou não emitir o ciclo que começa no `closing` (achado do teste de ponta a ponta da régua, 2026-10-23)
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
- Roadmap: API pública e webhooks (D-467); layouts de importação além de Domínio, Questor e Alterdata, e AFD de outro REP, conforme os clientes do piloto (D-461)
- NFS-e: na primeira nota real, conferir a competência, a série 80000 aceita pelo Portal, o valor que a plataforma envia como código do serviço (o código municipal 02800 ou o nacional 01.05.01; pergunta feita ao suporte do Asaas em 2026-10-29), o PIS/COFINS "00 - Nenhum" e os tributos aproximados (D-633, D-634)
- NFS-e e reforma tributária, para 2027: escolher o regime de IBS e CBS da DevBatista (Simples tradicional ou IBS e CBS no regime regular) com a Contabilizei, que recomendou o Simples tradicional num estudo prévio; conferir no Portal do Simples Nacional o prazo da opção (2026-10-30, pela Resolução CGSN 194, lida em fontes secundárias; quem não opta continua no Simples tradicional) e o cClassTrib (o assistente indicou 000001); e conferir no Asaas como mandar o destaque de IBS e CBS e o cClassTrib, obrigatórios na nota a partir de 2027-01-01 (D-632)
- IA: contratar a retenção zero com a Anthropic e confirmar se a Voyage AI oferece o mesmo (D-380), antes de entrar em produção
- Jurídico: base legal e cláusulas para mostrar dados dos colaboradores aos gestores dos clientes de alocação (D-570), que são terceiros em relação à empresa empregadora
- DP e eSocial: verificar se a alocação em cliente exige informar o tomador em algum evento ou obrigação (por exemplo, trabalho temporário ou cessão de mão de obra), na spec 13 (D-570)
- Clientes de alocação: decidir se o gestor do cliente participa das solicitações (spec 09) e do ponto (specs 10 e 11), como aprovar ajustes de marcação e dar visto no espelho. Fica fora da primeira versão (D-570)
