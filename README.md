# P002-LAB-PDAD

Acesso à PDAD 2024 por meios públicos, usando R.

---

## O que é isso?

A **PDAD** (Pesquisa Distrital por Amostra de Domicílios) é uma pesquisa que o IPEDF faz para saber como vivem as pessoas no Distrito Federal: quanto ganham, onde moram, quanto estudaram, como é a casa delas.

Só que não dá para perguntar para **todo mundo**. Então a pesquisa visita uma parte dos domicílios (a **amostra**) e, depois, usa matemática para dizer como é a população inteira.

Este repositório tem um script em R que faz o trabalho chato de preparação:

1. abre as duas bases de dados (moradores e domicílios);
2. junta as duas em uma só;
3. ensina o R a "ler" a amostra do jeito certo, para que as contas representem o DF inteiro e não só as pessoas que responderam.

No final, você fica com tudo pronto para analisar.

---

## O que tem em cada pasta

```
P002-LAB-PDAD/
├── Scripts/
│   └── PDAD-acesso.R        <- o script principal
├── bases pdad/
│   ├── Base de moradores.zip   <- a base de pessoas (compactada)
│   ├── domicilios.csv          <- a base de domicílios
│   ├── dicionario_de_variaveis_pdada_2024_público.xlsx
│   └── Questionario_PDAD_A_2024_publico_RblethQ.pdf
├── P002-LAB-PDAD.Rproj      <- abre o projeto no RStudio
└── README.md                <- este arquivo
```

- **`dicionario_de_variaveis...xlsx`** é o "manual" das colunas. Cada coluna tem um nome esquisito (como `E03` ou `I20`), e o dicionário diz o que cada uma significa e o que cada número quer dizer.
- **`Questionario...pdf`** é o formulário que os pesquisadores usaram nas visitas.

---

## Passo a passo

### Passo 0: Abrir o projeto do jeito certo

Abra o arquivo **`P002-LAB-PDAD.Rproj`** no RStudio (e não só o script solto).

Isso faz o R "morar" na pasta certa. Sem isso, ele não acha as bases e dá erro de arquivo não encontrado.

### Passo 1: Instalar e carregar os pacotes

Pacotes são caixas de ferramentas que outras pessoas criaram para o R.

```r
install.packages(c("tidyverse", "srvyr", "dplyr", "readr"))

library(tidyverse)
library(srvyr)
library(dplyr)
library(readr)
```

- `install.packages()` baixa as ferramentas. **Só precisa rodar uma vez** no seu computador.
- `library()` tira a ferramenta da caixa para usar. Isso você faz **toda vez** que abre o R.
- `tidyverse` e `dplyr` ajudam a mexer em tabelas, `readr` lê arquivos e `srvyr` cuida de pesquisas por amostra (é a peça mais importante deste projeto).

### Passo 2: Descompactar a base de moradores

```r
unzip("bases pdad/Base de moradores.zip", exdir = "bases pdad")
```

Por que isso existe? O arquivo de moradores tem uns 40 MB, e o upload pelo site do GitHub não aceita arquivos tão grandes. A solução foi guardar a versão **compactada** (`.zip`) e descompactar no seu computador.

O resultado é o arquivo `moradores.csv`, que aparece na pasta `bases pdad`. Ele fica só na sua máquina e **não vai para o GitHub** (veja a seção de cuidados).

### Passo 3: Ler as bases

```r
moradores  <- read_csv2("bases pdad/moradores.csv")
domicilios <- read_csv2("bases pdad/domicilios.csv")
```

Dois detalhes que fazem diferença:

- Usamos `read_csv2()` (com o **2** no final) porque os arquivos separam as colunas com **ponto e vírgula** (`;`) e usam **vírgula** nos decimais, como no Brasil. O `read_csv()` comum esperaria vírgula entre as colunas e bagunçaria tudo.
- Cada base tem um tamanho diferente porque conta coisas diferentes:

| Base | Cada linha é... | Quantas linhas |
|---|---|---|
| `moradores` | uma **pessoa** | 69.542 |
| `domicilios` | uma **casa** | 24.845 |

Quando rodar, confira se os números batem. Se baterem, a leitura deu certo.

### Passo 4: Juntar as duas bases

```r
pdad2024 <- moradores %>% 
  dplyr::left_join(domicilios %>% 
                     select(-c(A01uf, localidade, setor_distrito, infla_ipcadf)),
                   by = "A01nficha")
```

Imagine que a base de moradores é uma lista de pessoas e a de domicílios é uma lista de casas. Cada casa tem um **número de ficha**, a coluna `A01nficha`, que funciona como um CEP: ele aparece nas duas listas e liga cada pessoa à casa onde mora.

O `left_join` faz exatamente isso: para cada morador, ele cola do lado as informações da casa dele (tipo de moradia, classe social do domicílio, número de cômodos...).

- `by = "A01nficha"` diz qual é a coluna que liga as duas listas.
- O `select(-c(...))` tira da base de domicílios 4 colunas que já existem na de moradores com o mesmo conteúdo. Se não tirasse, elas apareceriam duplicadas.

Resultado: a base **`pdad2024`**, com **uma linha por morador** (69.542), e com os dados da casa grudados em cada um.

### Passo 5: Ensinar o R sobre a amostra

Este é o passo mais importante. Para entender, imagine que você quer descobrir qual é o lanche favorito da escola inteira, mas só pode perguntar para algumas pessoas.

Se você só calcular a média das respostas, vai errar, porque algumas pessoas **representam mais gente que outras**. A pesquisa resolve isso com três informações:

| Ideia | O que significa | Nome na base |
|---|---|---|
| **Peso** | Quantas pessoas (ou casas) do DF aquela resposta representa. Quem tem peso 150 "fala por" 150 pessoas | `peso_mor`, `peso_dom` |
| **Estrato** | O grupo da região onde a casa fica. A pesquisa sorteia casas dentro de cada grupo, para garantir que todas as regiões entrem | `setor_distrito` |
| **Conglomerado** | A casa. Pessoas que moram juntas costumam ser parecidas (mesma renda, mesmo bairro), então não contam como respostas totalmente independentes | `A01nficha` |

Com isso, declaramos o plano amostral:

```r
amostra_mor <- 
  survey::svydesign(id = ~A01nficha,
                    strata = ~setor_distrito,
                    weights = ~peso_mor,
                    nest = TRUE,
                    data = pdad2024)

amostra_mor <- srvyr::as_survey(amostra_mor)
```

Lendo linha por linha:

- `id = ~A01nficha` é o conglomerado (a casa).
- `strata = ~setor_distrito` é o estrato (o grupo de região).
- `weights = ~peso_mor` é o peso de cada morador.
- `nest = TRUE` avisa que a numeração das casas se repete de um grupo para o outro, então o R deve olhar a casa **dentro** do seu grupo.
- `as_survey()` transforma o resultado em algo que funciona com o `%>%` do tidyverse. Assim você usa `filter()`, `group_by()` e `summarise()` normalmente.

**Por que dois desenhos?** Porque as perguntas são de dois tipos:

- *"Quantas **pessoas** têm tal característica?"* → use **`amostra_mor`** (pessoas, base `pdad2024`).
- *"Quantas **casas** têm tal característica?"* → use **`amostra_dom`** (casas, base `domicilios`).

```r
amostra_dom <- 
  survey::svydesign(id = ~A01nficha,
                    strata = ~setor_distrito,
                    weights = ~peso_dom,
                    nest = TRUE,
                    data = domicilios)

amostra_dom <- srvyr::as_survey(amostra_dom)
```

O `amostra_dom` usa a base `domicilios` (uma linha por casa). Se usasse a `pdad2024`, cada casa entraria **uma vez para cada morador**, e a contagem de domicílios ficaria inflada: no teste, o total sem tratamento deu 5,08 milhões de domicílios, contra 1,81 milhão do jeito certo.

### Passo 6: Um último ajuste

```r
options(survey.lonely.psu = "adjust")
```

Às vezes, um grupo de região tem **uma única casa** na amostra. Com só uma, o R não consegue medir o quanto as respostas variam e daria erro. O `"adjust"` diz ao R para contornar isso e seguir em frente.

---

## Como usar depois do script

Com `amostra_mor` e `amostra_dom` prontos, as contas funcionam assim:

```r
# Quantos moradores existem em cada classe do Critério Brasil (só no DF)?
amostra_mor %>%
  filter(A01uf == 53) %>%
  group_by(criterio_brasil) %>%
  summarise(moradores = survey_total(),
            prop = survey_mean(vartype = "ci"))
```

- `survey_total()` conta quantas pessoas (ou casas) aquilo representa na população.
- `survey_mean()` calcula a proporção ou a média, e `vartype = "ci"` acrescenta o intervalo de confiança, que mostra a margem de incerteza.

Para filtrar um grupo, use `filter()` **no objeto da amostra** (como acima), nunca na base antes de declarar o plano. Assim o plano amostral continua valendo.

---

## Cuidados importantes

**1. A base não tem só o DF.**
Ela inclui também o entorno em Goiás. A coluna `A01uf` diz onde fica a casa: `53` é o Distrito Federal e `52` é Goiás. Para analisar só o DF, use `filter(A01uf == 53)`. Se esquecer, a conta soma mais de 4 milhões de moradores em vez dos cerca de 3 milhões do DF.

**2. Números que não são números.**
Em muitas colunas, valores como `99999` não são respostas de verdade, são códigos:

| Código | Significa |
|---|---|
| `77777` | Recusa |
| `88888` | Não sabe |
| `99999` | Não se aplica |

Se você calcular uma média de renda sem tratar isso, o R vai achar que alguém ganha R$ 99.999. Antes de somar ou tirar médias, transforme esses códigos em `NA` (valor ausente). Mas atenção: o **`0`** muitas vezes é uma resposta válida (por exemplo, "tem trabalho, mas não recebeu no mês passado"), e não deve ser apagado. Na dúvida, consulte o dicionário de variáveis.

**3. Pessoas ou casas?**
Use `amostra_mor` para perguntas sobre pessoas e `amostra_dom` para perguntas sobre casas. Misturar os dois dá resultados errados (veja o passo 5).

**4. Erro-padrão zero no total de domicílios.**
O total geral de domicílios (e por setor ou UF) sai com erro-padrão igual a **0**. Isso não é bug: o peso é o mesmo dentro de cada setor, então o total de casas de cada setor já está definido pelo plano. Quando você separa por uma característica (como a classe social), o erro-padrão volta ao normal.

**5. Nomes de colunas esquisitos.**
Colunas como `B13_3_1_88888` têm "88888" **no nome**. É uma categoria de resposta ("não sabe"), e não um erro.

---

## Cuidados com o Git

- **O `moradores.csv` não vai para o GitHub.** Ele é grande demais e está no arquivo `.gitignore`. Quem baixar o repositório precisa rodar o passo 2 para descompactá-lo.
- **Não faça commit do `moradores.csv`.** Se ele aparecer na aba Git do RStudio, confira se a linha `bases pdad/moradores.csv` está no `.gitignore`.
- **Dê Pull antes de dar Push.** Se o GitHub tiver mudanças que o seu computador não tem (por exemplo, um arquivo editado direto no site), o Push dá erro de "rejected". Clique em Pull (seta azul) primeiro e depois em Push (seta verde).
- **Não use `git push --force`** para resolver isso, porque você apagaria trabalho que está no GitHub.

---

## Resumindo

```
.zip  ->  .csv  ->  moradores + domicílios  ->  plano amostral  ->  análises
(passo 2) (passo 3)      (passo 4)               (passos 5 e 6)
```

O resultado é uma base que o R entende como uma **pesquisa por amostra de verdade**, e não como uma planilha qualquer. É isso que faz uma conta feita com 69 mil pessoas poder falar do Distrito Federal inteiro.