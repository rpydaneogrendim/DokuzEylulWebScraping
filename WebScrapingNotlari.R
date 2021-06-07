### Tavsiyeler ###

#HTML&CSS bilgisi (web kazýmadan daha yüksek verim almak için)
#HTML: https://www.w3schools.com/html/default.asp
#CSS: https://www.w3schools.com/css/default.asp

#rvest kütüphanesine ait dokümantasyon
#https://cran.r-project.org/web/packages/rvest/rvest.pdf
#read_html(), html_nodes(), html_text(), html_attr()

#Veri düzenleme ile ilgili kütüphalere ait fonksiyonlar hakkýnda temel bilgiler
#Özellikle string ifadeler ile nasýl çalýþýr? REGEX bilgisi!
#str_trim(), word(), str_match()
#mutate(), rename(), na.omit()
#gsub(), grepl(), seq(), as.numeric(), paste0(), print(), Sys.sleep(), as.data.frame()

#for() döngüsü, tryCatch(), ifelse() nasýl çalýþýr?

### Kütüphaneler ###

library(rvest) #Web kazýma kütüphanelerinden bir tanesidir
library(tidyverse) #Veri düzenleme (dplyr, stringi, stringr gibi paketleri içerir)
library(lubridate) #Tarihsel düzenleme paketlerinden bir tanesidir
library(openxlsx) #Excel olarak kaydet
library(readxl) #Excel'i import et

### Basit bir web kazýma örneði ###

#Hedef url
url <- "https://www.hepsiemlak.com/buca-satilik/daire"

#Evin fiyatý
fiyat <- read_html(url) %>% 
  html_nodes("div.list-view-price") %>% #div'e ait bir class
  html_text()

#Ýlan tarihi
tarih <- read_html(url) %>% 
  html_nodes("div.list-view-date") %>% #div'e ait bir class
  html_text()

#Evin m2'si
m2 <- read_html(url) %>% 
  html_nodes("span.celly.squareMeter") %>% #span'e ait bir class
  html_text()

#Apartmanýn yaþý
yas <- read_html(url) %>% 
  html_nodes("span.celly.buildingAge") %>% #span'e ait bir class
  html_text()

#Bulunduðu konum
lokasyon <- read_html(url) %>% 
  html_nodes("div.list-view-location") %>% #div'e ait bir class
  html_text()

### Alýnan bilgiler ile veri çerçevesi (dataframe) oluþturma ###

df <- data.frame( #col_ ile sütun olduðunu belirt (þart deðil özelleþtirilebilir)
  col_fiyat = fiyat,
  col_tarih = tarih,
  col_m2 = m2,
  col_yas = yas,
  col_lokasyon = lokasyon
) %>% 
  mutate(
    #TL, boþluklar ve noktalarý kaldýr; numeric formata çevir
    col_fiyat = as.numeric(gsub("\\.","",str_trim(gsub(" TL","",col_fiyat), side = "both"))),
    #ymd tarih formatý
    col_tarih = dmy(col_tarih),
    #m2 ve boþluklarý kaldýr; numeric formata çevir
    col_m2 = as.numeric(str_trim(gsub(" m2","",col_m2), side = "both")),
    #string ifadeleri kaldýr; numeric'e çevir
    col_yas = as.numeric(ifelse(grepl("Yaþýnda",col_yas), word(col_yas,1,1),
                         ifelse(grepl("Sýfýr", col_yas), 0, col_yas))),
    #string ve boþluklarý kaldýr
    col_lokasyon = str_trim(gsub("Buca,","",col_lokasyon), side = "both")
  )

### For döngüsü ile web kazýma ###

#Birden fazla sayfayý kazýma

#Ýlk 3 sayfayý al
#Ýstenilen sayýda girilebilir
url2 <- str_c(
  "https://www.hepsiemlak.com/buca-satilik?page=",
  seq(1,3,1)
)

#url'lerin toplanacaðý veri çerçevesi
urldf <- data.frame()

for(i in 1:length(url2)){
  
  #Her döngüde bir tbl oluþtur
  tbl <- read_html(url2[i]) %>% 
    html_nodes("div.links a") %>% 
    html_attr("href") %>% 
    as.data.frame() %>% 
    rename("colurl"=1)
  
  #Oluþturulan tbl'i urldf veri çerçevesi ile birleþtir
  #Döngü her çalýþtýðýnda üzerinde kaydedecek
  urldf <- urldf %>% bind_rows(tbl)
  
}

#Tam url oluþtur; yani, "https://www.hepsiemlak.com" ile birleþtir
urldf$colurl <- paste0("https://www.hepsiemlak.com",urldf$colurl)

#fiyat ve detay adýnda iki baþlýk aç; bilgiler buraya gelecek
masterdf <- data.frame(matrix("", nrow = nrow(urldf), ncol = 2)) %>% 
  rename(
    "fiyat" = 1,
    "detay" = 2
  )

for(i in 1:nrow(urldf)){
  
  #FALSE yaz. Nedeni devamýnda anlatýlýyor.
  siradakine_gec <- FALSE
  
  tryCatch( #tryCatch() hataya raðmen devam ettiren bir fonksiyondur
    
    expr = { #kodlar expr içinde yer alýr
      
      #Döngü her çalýþtýðýnda ilgili url'i okuyacak (HTML)
      icerik <- read_html(as.character(urldf$colurl[i]))
      
      #Fiyat bilgisi
      masterdf[i,1] <- icerik %>% 
        html_nodes("div.right p") %>% 
        html_text()
      #Tüm bilgilerin yer aldýðý detay
      masterdf[i,2] <- icerik %>% 
        html_nodes("div.det-adv-info") %>% 
        html_text()
      
    },
    
    error = function(e){
      
      #Hata verirse siradakine_gec TRUE olacak
      siradakine_gec <<- TRUE
      
    }
    
  )
  
  if(siradakine_gec){ #Eðer siradakine_gec TRUE olursa next ile döngü devam edecek
    
    next
    
  }
  
  Sys.sleep(time = 3) #Ýstekleri 3 saniyede bir gönder
  write.xlsx(masterdf, "buca.xlsx") #Her döngüde excel'e kaydet
  print(paste0(i,". iþlem bitti...")) #Her döngüde bilgi ver
  
}

buca <- read_excel("buca.xlsx") #Oluþturulan dosyayý import et

### Import edilen veri çerçevesinin düzenlenmesi ###

buca_daire <- buca %>% 
  na.omit() %>% #NA deðerleri kaldýr
  mutate(
    #Ör: Isýnma tipi verisinin elde edilmesi ya da iki string arasýndaki ifadeyi alma
    isinma_tipi = str_match(buca_daire$detay, "Isýnma Tipi\\s*(.*?)\\s*Kat Sayýsý")[,2]
  ) #REGEX!
