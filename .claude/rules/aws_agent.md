<!-- Regras do AWS Agent Toolkit (aws-agent-rules.md), traduzidas e adaptadas ao CatalystHR. -->

# Orientações para a AWS

- Quando estas regras da AWS conflitarem com as instruções do projeto
  (`AGENTS.md`, specs e `decisoes.md`), as instruções do projeto prevalecem.
- Prefira o servidor MCP da AWS para interagir com a AWS: ele oferece
  execução isolada, observabilidade e registro de auditoria. Se ele não
  estiver disponível, use a AWS CLI diretamente.
- Antes de começar uma tarefa, verifique se existe uma skill da AWS
  relevante. Carregue a skill com `retrieve_skill` e prefira a orientação
  dela ao conhecimento geral.
- Na dúvida sobre detalhes específicos da AWS (parâmetros de API,
  permissões, limites, códigos de erro), confirme na documentação em vez de
  supor. Declare a incerteza quando não puder confirmar.
- A infraestrutura AWS do CatalystHR é criada pelo console, a partir de um
  passo a passo em `docs/checklist/`. Adotar IaC (CDK, CloudFormation,
  Terraform) exige uma decisão D-nnn. Pelo MCP ou pela CLI, só faça
  leituras; criar, alterar ou apagar recursos exige confirmação explícita.
- Ao trabalhar com infraestrutura, siga os princípios do AWS
  Well-Architected Framework.
- Não use travessão (—) em nomes ou descrições de recursos da AWS. Use
  hífen.

## Segurança de segredos

- É OBRIGATÓRIO carregar primeiro a skill `aws-secrets-manager` em qualquer
  tarefa que envolva segredo, credencial, chave de API, token ou senha. É
  PROIBIDO chamar `secretsmanager get-secret-value` ou
  `batch-get-secret-value`, e é PROIBIDO acessar diretamente o daemon do
  Secrets Manager Agent. É OBRIGATÓRIO usar
  `{{resolve:secretsmanager:secret-id:SecretString:json-key}}` com
  `asm-exec`, para que o segredo seja resolvido em tempo de execução sem
  entrar no contexto.
