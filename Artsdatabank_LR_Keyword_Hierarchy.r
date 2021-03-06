### LR KEYWORDS ###
LRkeywords = function(TopLevel = "Taksonomi",Name = "Bokmål",
                      Clade = NULL,
                      Riker = c("Fungi", "Plantae", "Animalia"), 
                      Cols = c("Rike", "Rekke", "Klasse", "Orden", "Familie", "Slekt", "Art","Underart"), 
                      InputFil = NULL,Synonyms = c("Latin", "Nynorsk"),
                      FinnesINorge = TRUE, UtFil = "LR_keywords.txt"){
  # TopLevel = "Taksonomi", # Taksonomien vil legges under dette nøkkelordet
  # Clade: Hvis en kun vil jobbe med et gitt nivå, f.eks. fugl 'Aves'. Må oppgis med 
  # Name = "Bokmål", # Taksonomi skal prioriteres ut fra bokmål, men latin vil brukes i mangel på populærnavn på bokmål
  # Riker = c("Fungi", "Plantae", "Animalia"), # Rike man har lyst å bruke, må være latin
  # Cols = c("Rike", "Rekke", "Klasse", "Orden", "Familie", "Slekt", "Art","Underart"),
  # InputFil,# Hvis man allerede har lastet ned tekst-fil med artsnavnebase fra http://eksport.artsdatabanken.no/Artsnavnebase/
  # Synonyms = c("Latin", "Nynorsk") # Disse nivåene vil bli følge med som synonym i Lightroom
  # UtFil = "LR_keywords.txt" # (filbane og )navn på fil som skal eksporteres. 
  # FinnesINorge: Bruker kun arter som er registrert som at finnes i Norge
  require(data.table)
  require(stringr)
  require(Hmisc)
  
  # Laster inn fil med artsnavn fra Artsdatabanken
  if(is.null(InputFil)){
    if(!file.exists("Artsnavnebase.csv")){download.file(url = "http://eksport.artsdatabanken.no/Artsnavnebase/Artsnavnebase.csv", destfile = "Artsnavnebase.csv", method = "curl")}
    Reference = fread("Artsnavnebase.csv", na.strings = "")
    # There is an error with the first colum
    names(Reference) = c(names(Reference)[-1], "NA")
  }else{
    Reference = fread(InputFil)}
  
  Norge = Reference$FinnesINorge
  Reference = Reference[,c("Rike", "Rekke", "Klasse", "Orden", "Familie", "Slekt", "Art", "Underart", "PopulærnavnBokmål", "PopulærnavnNynorsk"),with = F]
  
  # Add nivå
  Reference[,Nivå:=apply(Reference, 1, function(ii){
    names(Reference)[min(which(is.na(ii)))-1]
  })]
  
  # Fjern arter som ikke finnes in Norge
  if(FinnesINorge){Reference = Reference[!(Reference$Nivå %in% c("Art", "UnderArt") & Norge=="Nei")]}
  
  # Latinsk navn
  Reference[,Latin:=apply(Reference, 1, function(ii){
    unlist(ii[which(is.na(ii))-1])[1]
  })]
  Reference[,LatinskNavn := ifelse(Nivå=="Underart",(paste(Slekt, Art, Underart)),
                                   ifelse(Nivå=="Art",(paste(Slekt, Art)),
                                          Latin))][,Latin:=NULL]
  # Subset to relevant kingdoms
  Reference = Reference[which(Rike %in% Riker)]
  #Reference
  
  # Subsette til relevante nivå
  if(!is.null(Clade)){
    IDX = apply(Reference, 1, function(ii) any(ii==Clade))
    Reference = Reference[IDX]
  }

  #fjerner taxa som ikke inneholder arter
  setorder(Reference, Rike, Rekke, Klasse, Orden, Familie, Slekt, Art)
  
  Reference[,InneholderArter:=any(Nivå=="Art"),"Rike"]
  Reference=Reference[!(Nivå=="Rike"& InneholderArter==FALSE)]
  
  Reference[,InneholderArter:=any(Nivå=="Art"),"Rekke"]
  Reference=Reference[!(Nivå=="Rekke"& InneholderArter==FALSE)]
  
  Reference[,InneholderArter:=any(Nivå=="Art"),"Klasse"]
  Reference=Reference[!(Nivå=="Klasse"&InneholderArter==FALSE)]
  
  Reference[,InneholderArter:=any(Nivå=="Art"),"Orden"]
  Reference=Reference[!(Nivå=="Orden"&InneholderArter==FALSE)]
  
  Reference[,InneholderArter:=any(Nivå=="Art"),"Familie"]
  Reference=Reference[!(Nivå=="Familie"&InneholderArter==FALSE)]
  
  Reference[,InneholderArter:=any(Nivå=="Art"),"Slekt"]
  Reference=Reference[!(Nivå=="Slekt"&InneholderArter==FALSE)]
  Reference[,InneholderArter:=NULL]
  
  setnames(Reference, c("PopulærnavnBokmål", "PopulærnavnNynorsk", "LatinskNavn"), c("Bokmål", "Nynorsk", "Latin"))
  
  Levels = length(Cols)
  if(!is.null(Synonyms)){
    Levels = Levels + 1
  }
  Hierarchy = as.data.frame(sapply(1:Levels,function(II)rep(NA,nrow(Reference))))
  Hierarchy$idx=seq(1, by = length(Synonyms)+1, length.out = nrow(Hierarchy))
  if(!is.null(Synonyms)){
    HierarchyS = lapply(1:length(Synonyms),function(ii) Hierarchy)
  }
  
 Reference[,Nynorsk:=Hmisc::capitalize(Reference$Nynorsk)]
 Reference[,Bokmål:=Hmisc::capitalize(Reference$Bokmål)]
  
  # Add nivå
  Reference[,Nivå:=apply(Reference, 1, function(ii){
    names(Reference)[min(c(9,which(is.na(ii))))-1]
  })]
  Reference[,nNivå:=as.numeric(factor(Nivå, levels = Cols))]
  
  Reference[,Mål:=with(Reference, ifelse(is.na(eval(parse(text = Name))), Latin, eval(parse(text = Name))))]
  
  print("Nå vil ting ta litt tid")
  if(is.null(Synonyms)){
    sapply(1:nrow(Reference), function(ii){
      print(ii)
      #a = Reference[ii,which(names(Reference)==Name),with=F]
      Hierarchy[ii, Reference$nNivå[ii]]<<-Reference$Mål[ii]
      HierarchyTot = data.table(Hierarchy)
    })
  }else{
    sapply(1:nrow(Reference), function(ii){
      #print(ii)
      #a = Reference[ii,which(names(Reference)==Name),with=F]
      Hierarchy[ii, Reference$nNivå[ii]]<<-Reference$Mål[ii]
      
      for(iii in seq_along(Synonyms)){
        HierarchyS[[iii]][ii, (Reference$nNivå[ii]+1)]<<-paste0("{",Reference[,eval(parse(text = Synonyms[iii]))][ii],"}")
        HierarchyS[[iii]]$idx[[ii]] <<- HierarchyS[[iii]]$idx[[ii]]+iii
        
      }
      
      
    })
  }
  #20.49
  print("Den tidkrevende delen er nå over :). Tar ca 10 min hvis man bruker dyre-, plante- og soppriket.")
  if(!is.null(Synonyms)){
    #Hierarchy$IDX=1
    HierarchyTot = rbind(Hierarchy, do.call("rbind",HierarchyS))
    HierarchyTot = data.table(HierarchyTot)
    
    setorder(HierarchyTot, idx)#,IDX)
  }
  
  HierarchyTot$idx=NULL
  #HierarchyTot$IDX=NULL
  HierarchyTot = rbind(data.table(TopLevel),HierarchyTot, fill = T)
  
  HierarchyTot = apply(HierarchyTot, c(1,2), function(x)ifelse(is.na(x), "",x))
  
  HierarchyTot = (apply(HierarchyTot, c(1,2), function(x)ifelse(x=="{NA}", "",x)))
  HierarchyTot = HierarchyTot[apply(HierarchyTot,1,function(ii)any(str_count(ii)>1)),]
  HierarchyTot = HierarchyTot[,apply(HierarchyTot,2,function(ii)any(str_count(ii)>1))]
  HierarchyTot = data.table(HierarchyTot)
  #output
  write.table(HierarchyTot, file = UtFil, sep="\t", row.names = F, quote = F, col.names = F, fileEncoding = "UTF-8")
}

# Example
LRkeywords(UtFil = "LR_Keywords.txt")
