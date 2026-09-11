# Desafio Projeto Azure - DIO

Projeto de integração entre **Azure Database for MySQL** e **Power BI**, cobrindo desde o provisionamento da infraestrutura na nuvem até a modelagem e transformação dos dados no Power Query.

## Índice

- [Etapas do desafio](#etapas-do-desafio)
- [Modelagem do banco de dados](#modelagem-do-banco-de-dados)
- [Transformações no Power Query](#transformações-no-power-query)
- [Decisões de design e justificativas](#decisões-de-design-e-justificativas)
- [Desafios encontrados e soluções](#desafios-encontrados-e-soluções)

---

## Etapas do desafio

1. Criação de uma instância do MySQL na Azure (Azure Database for MySQL Flexible Server)
2. Exploração do recurso no Portal do Azure
3. Conexão ao banco de dados via Cloud Shell
4. Criação de regra de firewall na Azure para liberar acesso externo ao banco
5. Conexão ao MySQL na Azure utilizando o MySQL Workbench
6. Modelagem e povoamento do schema `azure_company`
7. Integração do Power BI com o MySQL na Azure
8. Transformação dos dados no Power Query

---

## Modelagem do banco de dados

Schema: **`azure_company`**

| Tabela | Chave Primária | Chaves Estrangeiras |
|---|---|---|
| `employee` | `Ssn` | `Super_ssn` → `employee.Ssn` (auto-referência, gerente) |
| `departament` | `Dnumber` | `Mgr_ssn` → `employee.Ssn` |
| `dept_locations` | `Dnumber, Dlocation` | `Dnumber` → `departament.Dnumber` (`ON DELETE CASCADE`, `ON UPDATE CASCADE`) |
| `project` | `Pnumber` | `Dnum` → `departament.Dnumber` |
| `works_on` | `Essn, Pno` | `Essn` → `employee.Ssn`; `Pno` → `project.Pnumber` |
| `dependent` | `Essn, Dependent_name` | `Essn` → `employee.Ssn` |

**Constraints relevantes:**
- `chk_date_dept`: data de criação do departamento deve ser anterior à data de início do gerente
- `unique_name_dept`: nome do departamento é único
- `unique_project`: nome do projeto é único

**Tratamento de exclusão/atualização:**
- `employee.Super_ssn`: `ON DELETE SET NULL`, `ON UPDATE CASCADE` — se um gerente for removido, os subordinados ficam sem gerente (não são excluídos)
- `dept_locations.Dnumber`: `ON DELETE CASCADE`, `ON UPDATE CASCADE` — se um departamento for removido, suas localizações são removidas junto

---

## Transformações no Power Query

O modelo final é composto por **tabelas de resultado** (visíveis no relatório) e **tabelas auxiliares/staging** (usadas só como fonte intermediária para merges, com `Enable Load = false`).

### 🔹 Tabela: `azure_company employee` *(resultado)*

Tabela principal de colaboradores, enriquecida com dados de departamento e hierarquia.

| Passo | O que foi feito |
|---|---|
| Renomear coluna | `Bdate` → `Date` |
| Separar coluna | `Address` dividido em número da casa e o restante do endereço |
| Alterar tipos | Número do endereço convertido para inteiro; `Ssn` convertido para número |
| Separar coluna (2ª vez) | Restante do endereço dividido novamente, isolando o `State` (UF) |
| **Merge** | Junção com a tabela `departament` (versão staging, sem localizações) via `Dno` = `Dnumber`, trazendo o nome do departamento (`Departamento`) |
| **Merge** | Junção com a tabela staging `employee_gerentes` via `Ssn` = `Ssn`, e depois via `Super_ssn` = `Ssn`, trazendo o nome do gerente (`Manager's_Name`) |
| Unir colunas | `Fname` + `Lname` combinados em `Full_name` |
| Reordenar/renomear | Organização final das colunas para leitura |

**Tratamento de nulos:** a coluna `Super_ssn` aparece nula apenas para o colaborador **James Borg**, o presidente da empresa — o único que não possui um gerente acima dele. Não foi necessário preencher ou remover esse dado, pois reflete corretamente a hierarquia real da organização.

### 🔹 Tabela auxiliar: `employee_gerentes` *(staging — Enable Load = false)*

Cópia simplificada de `employee`, contendo apenas `Ssn` e o nome completo do colaborador. Existe exclusivamente para permitir a auto-referência (mesclar `employee` com ela mesma), já que o Power Query não permite selecionar a mesma query duas vezes na tela de Merge.

### 🔹 Tabela auxiliar: `azure_company departament` *(staging — Enable Load = false)*

Versão "limpa" da tabela de departamentos, **sem** a junção com localizações — contém 1 linha por departamento. É usada como fonte para o merge com `employee`. Essa separação foi necessária para evitar duplicação de linhas (ver seção de desafios, abaixo).

### 🔹 Tabela: `departament_com_localizacao` *(resultado)*

| Passo | O que foi feito |
|---|---|
| Alterar tipo | `Mgr_ssn` convertido para número |
| **Merge** | Junção com `dept_locations` via `Dnumber` = `Dnumber` (Left Outer), trazendo `Dlocation` |
| Renomear | Coluna resultante renomeada para `locations` |

Como um departamento pode ter várias localizações, essa tabela tem **granularidade de departamento + localização**: departamentos com mais de um local aparecem em múltiplas linhas (ex: "Research" aparece 3 vezes: Bellaire, Houston, Sugarland).

### 🔹 Tabela: `Colaboradores_por_Gerente` *(resultado)*

Duplicata da query `employee` (com todas as suas transformações), finalizada com um agrupamento:

| Passo | O que foi feito |
|---|---|
| **Group By** | Agrupado por `Manager's_Name`, contando o número de linhas (colaboradores) por grupo |

**Resultado:**

| Gerente | Total de Colaboradores |
|---|---|
| Franklin Wong | 3 |
| James Borg | 2 |
| Jennifer Wallace | 2 |
| *(sem gerente — o próprio presidente)* | 1 |

### 🔹 Tabela: `Alocacao_Projetos` *(resultado — extra)*

Tabela adicional, não obrigatória no desafio, criada para enriquecer a análise: mostra quem trabalha em qual projeto e quantas horas.

| Passo | O que foi feito |
|---|---|
| Alterar tipo | `Essn` convertido para número |
| **Merge** | Junção com `employee` via `Essn` = `Ssn`, trazendo `Full_name` → renomeado para `Nome_Colaborador` |
| **Merge** | Junção com `project` via `Pno` = `Pnumber`, trazendo `Pname` → renomeado para `Nome_Projeto` |
| Remover colunas | Colunas técnicas (`Essn`, `Pno`) removidas, mantendo só os nomes |

### 🔹 Tabelas sem transformação: `dependent`, `dept_locations`, `project`, `works_on`

Carregadas diretamente da fonte, com apenas ajuste de tipo quando necessário (ex: `Essn` convertido para número em `dependent`).

---

## Decisões de design e justificativas

**Por que usar Merge em vez de preencher os dados manualmente (departamento + localização)?**
A relação entre departamento e localização é **um-para-muitos** (um departamento pode ter várias localizações), e os dados já existem em uma tabela separada (`dept_locations`), ligada por chave estrangeira no banco. Usar Merge traz os dados dinamicamente a partir da fonte real, respeitando essa relação — se um novo local for cadastrado no banco, ele aparece automaticamente na próxima atualização. Preencher manualmente seria propenso a erros, não escalável, e quebraria a integridade referencial que já existe no modelo relacional.

**Por que criar tabelas de staging (auxiliares) em vez de mesclar direto?**
Duas situações exigiram esse padrão:
1. **Auto-referência** (nome do gerente): o Power Query não permite mesclar uma query com ela mesma diretamente na interface, então uma cópia simplificada (`employee_gerentes`) foi necessária como "ponte".
2. **Granularidades diferentes**: a tabela `departament` precisava alimentar dois resultados diferentes — uma versão com 1 linha por departamento (para enriquecer `employee`) e outra com múltiplas linhas por localização (para o relatório de departamentos). Manter essas versões separadas evita que uma transformação "vaze" para a outra query de forma não intencional.

---

## Desafios encontrados e soluções

Durante o desenvolvimento, alguns problemas técnicos surgiram e foram resolvidos — documentados aqui por servirem de aprendizado:

- **Erro ao inserir dados auto-referenciados (`employee.Super_ssn`)**: como um colaborador pode referenciar outro que ainda não foi inserido (ex: John Smith referenciando Franklin Wong antes dele existir), foi necessário desabilitar temporariamente a checagem de chaves estrangeiras durante a carga inicial (`SET FOREIGN_KEY_CHECKS = 0`, seguido de `= 1` após os inserts).
- **Duplicação inesperada de linhas em `employee`**: ao mesclar `departament` com `dept_locations` diretamente na mesma query usada por `employee`, a granularidade da tabela de departamentos mudou de 1 para N linhas por departamento — e essa mudança "propagou" para `employee` através da dependência entre as queries, multiplicando as linhas de colaboradores do mesmo departamento. Resolvido separando as responsabilidades em queries distintas (ver seção de staging acima).
- **Erro de firewall/autenticação no Azure**: o acesso ao servidor MySQL exigiu a criação de uma regra de firewall liberando o IP de origem, tanto para conexão via Workbench quanto via Power BI.

---

## Ferramentas utilizadas

- Azure Database for MySQL (Flexible Server)
- MySQL Workbench
- Power BI Desktop / Power Query
