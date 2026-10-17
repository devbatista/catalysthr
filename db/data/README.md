# Dados oficiais carregados no sistema

## `cbo2002_ocupacao.csv`

Tabela de ocupações da Classificação Brasileira de Ocupações (CBO 2002), usada para validar o CBO dos cargos (spec 04, RN-04-031, P-04-13).

- **Origem:** Ministério do Trabalho e Emprego, https://cbo.mte.gov.br/cbosite/pages/downloads.jsf, item "Estrutura CBO (CSV)", arquivo `CBO2002 - Ocupacao.csv`
- **Arquivo de:** 10/07/2026. Baixado em 17/10/2026 pelo responsável
- **Conversão:** só a codificação, de ISO-8859-1 para UTF-8, e as quebras de linha. O conteúdo não foi alterado
- **Conteúdo:** 2.725 ocupações, com código de 6 dígitos e título

Para atualizar: baixe o arquivo novo no mesmo endereço, converta da mesma forma, substitua este e rode `bin/rails cbo:import`. A carga é idempotente: inclui os códigos novos, atualiza os títulos e marca como inativos os códigos que saíram, sem apagá-los, porque cargos antigos podem usá-los.
