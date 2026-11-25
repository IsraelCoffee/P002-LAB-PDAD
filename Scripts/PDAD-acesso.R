## Pacotes ----

install.packages(c("tidyverse", "srvyr", "dplyr","readr"))

## Lendo os Pacotes ----

library(tidyverse)
library(srvyr)
library(dplyr)
library(readr)

## Preparando as bases ----

# Descompactua o arquivo base de moradores.zip
unzip("bases pdad/Base de moradores.zip", exdir = "bases pdad")

## Importando as bases ----

moradores <- read_csv2("bases pdad/moradores.csv")
domicilios <- read_csv2("bases pdad/domicilios.csv")

# Juntando domicílios e moradores ----
pdad2024 <- moradores %>% 
  dplyr::left_join(domicilios %>% 
                     select(-c(A01uf,localidade,setor_distrito,infla_ipcadf)),
                   by="A01nficha")


# Declaração do plano amostral ----

amostra_mor <- 
  survey::svydesign(id = ~A01nficha,
                    strata = ~setor_distrito,
                    weights = ~peso_mor,
                    nest = TRUE,
                    data = pdad2024)

amostra_mor <- srvyr::as_survey(amostra_mor)

amostra_dom <- 
  survey::svydesign(id = ~A01nficha,
                    strata = ~setor_distrito,
                    weights = ~peso_dom,
                    nest = TRUE,
                    data = pdad2024)

amostra_dom <- srvyr::as_survey(amostra_dom)

options(survey.lonely.psu = "adjust")





