### Tavsiyeler ###

#HTML&CSS bilgisi (web kazımadan daha yüksek verim almak için)
#HTML: https://www.w3schools.com/html/default.asp
#CSS: https://www.w3schools.com/css/default.asp

#rvest kütüphanesine ait dokümantasyon
#https://cran.r-project.org/web/packages/rvest/rvest.pdf
#read_html(), html_nodes(), html_text(), html_attr()

#Veri düzenleme ile ilgili kütüphalere ait fonksiyonlar hakkında temel bilgiler
#Özellikle string ifadeler ile nasıl çalışır? REGEX bilgisi!
#str_trim(), word(), str_match()
#mutate(), rename(), na.omit()
#gsub(), grepl(), seq(), length(), as.numeric(), paste0(), print(), Sys.sleep(), data.frame(), as.data.frame()

#for() döngüsü, tryCatch(), ifelse() nasıl çalışır?

### Kütüphaneler ###

library(rvest) #Web kazıma kütüphanelerinden bir tanesidir
library(tidyverse) #Veri düzenleme (dplyr, stringi, stringr gibi paketleri içerir)
library(lubridate) #Tarihsel düzenleme paketlerinden bir tanesidir
library(openxlsx) #Excel olarak kaydet
library(readxl) #Excel'i import et

### Basit bir web kazıma örneği ###

#Hedef url
url <- "https://www.hepsiemlak.com/buca-satilik/daire"

#Evin fiyatı
fiyat <- read_html(url) %>% 
  html_nodes("div.list-view-price") %>% #div'e ait bir class
  html_text()

#İlan tarihi
tarih <- read_html(url) %>% 
  html_nodes("div.list-view-date") %>% #div'e ait bir class
  html_text()

#Evin m2'si
m2 <- read_html(url) %>% 
  html_nodes("span.celly.squareMeter") %>% #span'e ait bir class
  html_text()

#Apartmanın yaşı
yas <- read_html(url) %>% 
  html_nodes("span.celly.buildingAge") %>% #span'e ait bir class
  html_text()

#Bulunduğu konum
lokasyon <- read_html(url) %>% 
  html_nodes("div.list-view-location") %>% #div'e ait bir class
  html_text()

### Alınan bilgiler ile veri çerçevesi (dataframe) oluşturma ###

df <- data.frame( #col_ ile sütun olduğunu belirt (şart değil özelleştirilebilir)
  col_fiyat = fiyat,
  col_tarih = tarih,
  col_m2 = m2,
  col_yas = yas,
  col_lokasyon = lokasyon
) %>% 
  mutate(
    #TL, boşluklar ve noktaları kaldır; numeric formata çevir
    col_fiyat = as.numeric(gsub("\\.","",str_trim(gsub(" TL","",col_fiyat), side = "both"))),
    #ymd tarih formatı
    col_tarih = dmy(col_tarih),
    #m2 ve boşlukları kaldır; numeric formata çevir
    col_m2 = as.numeric(str_trim(gsub(" m2","",col_m2), side = "both")),
    #string ifadeleri kaldır; numeric'e çevir
    col_yas = as.numeric(ifelse(grepl("Yaşında",col_yas), word(col_yas,1,1),
                         ifelse(grepl("Sıfır", col_yas), 0, col_yas))),
    #string ve boşlukları kaldır
    col_lokasyon = str_trim(gsub("Buca,","",col_lokasyon), side = "both")
  )

### For döngüsü ile web kazıma ###

#Birden fazla sayfayı kazıma

#İlk 3 sayfayı al
#İstenilen sayıda girilebilir
url2 <- str_c(
  "https://www.hepsiemlak.com/buca-satilik?page=",
  seq(1,3,1)
)

#url'lerin toplanacağı veri çerçevesi
urldf <- data.frame()

for(i in 1:length(url2)){
  
  #Her döngüde bir tbl oluştur
  tbl <- read_html(url2[i]) %>% 
    html_nodes("div.links a") %>% 
    html_attr("href") %>% 
    as.data.frame() %>% 
    rename("colurl"=1)
  
  #Oluşturulan tbl'i urldf veri çerçevesi ile birleştir
  #Döngü her çalıştığında üzerinde kaydedecek
  urldf <- urldf %>% bind_rows(tbl)
  
}

#Tam url oluştur; yani, "https://www.hepsiemlak.com" ile birleştir
urldf$colurl <- paste0("https://www.hepsiemlak.com",urldf$colurl)

#fiyat ve detay adında iki başlık aç; bilgiler buraya gelecek
masterdf <- data.frame(matrix("", nrow = nrow(urldf), ncol = 2)) %>% 
  rename(
    "fiyat" = 1,
    "detay" = 2
  )

for(i in 1:nrow(urldf)){
  
  #FALSE yaz. Nedeni devamında anlatılıyor.
  siradakine_gec <- FALSE
  
  tryCatch( #tryCatch() hataya rağmen devam ettiren bir fonksiyondur
    
    expr = { #kodlar expr içinde yer alır
      
      #Döngü her çalıştığında ilgili url'i okuyacak (HTML)
      icerik <- read_html(as.character(urldf$colurl[i]))
      
      #Fiyat bilgisi
      masterdf[i,1] <- icerik %>% 
        html_nodes("div.right p") %>% 
        html_text()
      #Tüm bilgilerin yer aldığı detay
      masterdf[i,2] <- icerik %>% 
        html_nodes("div.det-adv-info") %>% 
        html_text()
      
    },
    
    error = function(e){
      
      #Hata verirse siradakine_gec TRUE olacak
      siradakine_gec <<- TRUE
      
    }
    
  )
  
  if(siradakine_gec){ #Eğer siradakine_gec TRUE olursa next ile döngü devam edecek
    
    next
    
  }
  
  Sys.sleep(time = 3) #İstekleri 3 saniyede bir gönder
  write.xlsx(masterdf, "buca.xlsx") #Her döngüde excel'e kaydet
  print(paste0(i,". işlem bitti...")) #Her döngüde bilgi ver
  
}

buca <- read_excel("buca.xlsx") #Oluşturulan dosyayı import et

### Import edilen veri çerçevesinin düzenlenmesi ###

buca_daire <- buca %>% 
  na.omit() %>% #NA değerleri kaldır
  mutate(
    #Ör: Isınma tipi verisinin elde edilmesi ya da iki string arasındaki ifadeyi alma
    isinma_tipi = str_match(detay, "Isınma Tipi\\s*(.*?)\\s*Kat Sayısı")[,2]
  ) #REGEX!
