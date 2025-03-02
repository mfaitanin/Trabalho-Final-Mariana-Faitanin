##################################################
#     Atividade Final                             # 
# Disciplina: Ci�ncia colaborativa                #
# Aluna: Mariana Alves Faitanin                   #
# Ano: 2022/1                                     # 
##################################################

#ATIVIDADE 1


#Cada aluno recebeu um conjunto de dados para que pudesse padronizar e no 
#final ter�amos que compartilhar um com os outros para que pudessemos criar 
#uma �nica tabela.
#Para isso, criei um dataset com cada planilha enviada e utilizei a fun��o "rbind" 
#para juntar todas as planilhas em uma s�. 

ana<- read.csv("ana-clara.csv")
let<- read.csv("leticia.csv")
luiza<-read.csv("luiza.csv")
marina<-read.csv("marina.csv")
mari<-read.csv("mariana.csv")
victor<-read.csv("victor.csv")
natalia<-read.csv("natalia.csv")

dados1<-rbind(ana,let,luiza,marina,mari,victor,natalia)
dados1
View(dados1)

#Antes de iniciar a atividade 2, precisei converter o dataset "dados1" em uma
#tabela .xlsx e porteriormente em ".csv". Para isso, utilizei o pacote writexl.

library(writexl)
write_xlsx(dados1,"C:\\ciencia-colab\\Atividade-final\\dadosfinal6.xlsx")

#ATIVIDADE 2
#Nesta atividade, continuamos a utilizar a base de dados da atividade 1. Mas agora
#teremos que checar todos os dados do dataset "dadosT3"

dadosT3<-read.csv("dadosfinal3.csv", header = T, sep=";", dec=".")
dadosT3
lapply(dadosT3, unique)

#com a fun��o lapply, podemos conferir a quantidade total de amostra, o nome das
#esp�cies, �reas e dados de latitude e longitude
#

library(ggplot2)
library(vegan)
library(dplyr)
library(tidyr)
library(validate)
library(taxize)
library(lumberjack)

dadosT3 %>% select(-species, -area, -date) %>% 
  mutate_if(is.character,as.numeric)
bind_cols(dadosT3 %>% select(species, area, date))

#### 
dadosT3 %>% 
  select(species, Sepal.Length:Petal.Width) %>% 
  pivot_longer(cols = -species, names_to = "variavel", values_to = "valores") %>% 
  ggplot(aes(y = valores, fill = species)) +
  geom_histogram() +
  facet_wrap(~ variavel, scales = 'free_y') +
  theme_classic()

#Com a fun��o "validator" podemos checar as coordenadas geogr�ficas, �reas,
#datas das ocorr�ncias e o nome completo das esp�cies.
#aten��o: n�o esquecer de rodar o pacote "validate"  

rules <- validator(in_range(lat, min = -90, max = 90),
                   in_range(lat, min = -180, max = 180),
                   is.character(area),
                   is.numeric(date),
                   all_complete(dadosT3))

out   <- confront(dadosT3, rules)
summary(out)
plot(out)

#A fun��o validator nos fornece um resultado gr�fico com as vari�veis que forma 
#validadas. Note que as vari�veis V3 e V5 est�o OK e a vari�vel V4 apresentou uma falha.
#Provavelmente esse erro vou devido ao formato da data inserido da planilha. As 
#vari�veis V1 e V2 (coordenada geogr�fica) n�o foi encontrada.

#Ap�s checar os dados de ocorr�ncias, precisamos checar os dados dos taxons e se
# todos s�o v�lidos. Para isso, vamos utilizaremos a fun��o "get_tsn" do pacote "taxize".
# ATEN��O: N�o esquecer de rodar o pacote "taxize" antes.

species <- dadosT3 %>% 
  distinct(species) %>% 
  pull() %>% 
  get_tsn() %>% 
  data.frame() %>% 
  bind_cols(dadosT3 %>% 
              distinct(species))

#No resultado dessa fun��o, aparecer� o n�mero total de esp�cie da sua planilha 
#e tamb�m se os nomes est�o corretos, devido a compara��o que  ser� feitoa no 
#Integrated Taxonomic Information System 



#Ap�s toda valida��o, agora vamos renomear as vari�veis da planilha conforme o
#Darwin Core (DwC)


dadosT3_1 <- dadosT3 %>% 
  dplyr::mutate(eventID = paste(area, date, sep = "_"), # create indexing fields 
                occurrenceID = paste(area, date, amostra, sep = "_")) %>% 
  left_join(species %>% 
              select(species, uri)) %>% # add species unique identifier
  dplyr::rename(decimalLongitude = long, # rename fields according to DwC 
                decimalLatitude = lat,
                eventDate = date,
                scientificName = species,
                scientificNameID = uri) %>% 
  mutate(geodeticDatum = "WGS84", # and add complimentary fields
         verbatimCoordinateSystem = "decimal degrees",
         georeferenceProtocol = "Random coordinates obtained from Google Earth",
         locality = "Gaspe Peninsula",
         recordedBy = "Edgar Anderson",
         taxonRank = "Species",
         organismQuantityType = "individuals",
         basisOfRecord = "Human observation")

#Atrav�s das fun��es eventCore e occurrences, podemos selecionar os dados
#relacionadas as caracter�sticas gerais  das amostras e dos dados das ocorr�ncias.
 
## create eventCore
eventCore <- dadosT3_1 %>% 
  select(eventID, eventDate, decimalLongitude, decimalLatitude, locality, area,
         geodeticDatum, verbatimCoordinateSystem, georeferenceProtocol) %>% 
  distinct() 

## create occurrence
occurrences <- dadosT3_1 %>% 
  select(eventID, occurrenceID, scientificName, scientificNameID,
         recordedBy, taxonRank, organismQuantityType, basisOfRecord) %>%
  distinct() 


#Na planilha de atributos, podemos associar os dados morfom�tricos das flores
#com os dados de ocorr�ncias 

##create measurementsOrFacts
eMOF <- dadosT3_1 %>% 
  select(eventID, occurrenceID, recordedBy, Sepal.Length:Petal.Width) %>%  
  pivot_longer(cols = Sepal.Length:Petal.Width,
               names_to = "measurementType",
               values_to = "measurementValue") %>% 
  mutate(measurementUnit = "cm",
         measurementType = plyr::mapvalues(measurementType,
                                           from = c("Sepal.Length", "Sepal.Width", "Petal.Width", "Petal.Length"), 
                                           to = c("sepal length", "sepal width", "petal width", "petal length")))


#Por fim, precisamos fazer um controle de qualidade de todos os dados da planilha
#para vermos se todas as planilhas tem os mesmos valores de eventID.

# check if all eventID matches
setdiff(eventCore$eventID, occurrences$eventID)
setdiff(eventCore$eventID, eMOF$eventID)
setdiff(occurrences$eventID, eMOF$eventID)
setdiff(occurrences$eventID, eMOF$eventID)

# check NA values
eMOF %>%
  filter(is.na(eventID))

occurrences %>%
  filter(is.na(eventID))


#ULTIMO PASSO! Remover todos os arquivos intermedi�rios e salvar os arquivos
# ".csv" no compitador.

rm(list = setdiff(ls(), c("eventCore", "occurrences", "eMOF")))

files <- list(eventCore, occurrences, eMOF) 
data_names <- c("DF_eventCore","DF_occ","DF_eMOF")
dir.create("Dwc_Files")


for(i in 1:length(files)) {
  path <- paste0(getwd(), "/", "DwC_Files")
  write.csv(files[[i]], paste0(path, "/", data_names[i], ".csv"))
}
