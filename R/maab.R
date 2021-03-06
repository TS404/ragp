#' MAAB classification of Hydroxyproline‐rich Glycoproteins
#'
#' Perform Motif and amino acid bias classification of Hydroxyproline‐rich Glycoproteins according to Johnson et al. (2017)
#' 
#' @param data A data frame with protein amino acid sequences as strings in one column and corresponding id's in another. Alternatively a path to a .fasta file with protein sequences. Alternatively a list with elements of class "SeqFastaAA" resulting from seqinr::read.fasta call.
#' @param sequence A vector of strings representing protein amino acid sequences, or the appropriate column name if a data.frame is supplied to data argument. If .fasta file path, or list with elements of class "SeqFastaAA" provided to data, this should be left blank.
#' @param id A vector of strings representing protein identifiers, or the appropriate column name if a data.frame is supplied to data argument. If .fasta file path, or list with elements of class "SeqFastaAA" provided to data, this should be left blank.
#' @param order Order of motif counting, the default is as in Johnson et al. (2017).
#' @param gpi A Boolean vector indicating if the corresponding id contains a GPI or not. Can be the 'is.bigpi' column from the output of get_big_pi.
#'    
#' @return A data frame with columns:
#' \enumerate{
#' \item{id} {protein identifiers as from input}
#' \item{ext_sp} {number of extensin SPn motifs, counted using SP{3,5}}
#' \item{ext_tyr} {number of extensin TYR motifs, sum of matches for: [FY].Y, KHY, VY[HKDE], V.Y, YY}
#' \item{prp} {number of proline rich protein motifs, sum of matches for: PPV.[KT], PPV[QK], KKPCPP}
#' \item{agp} {number of arabinogalactan motifs, sum of matches for: [AVTG]P{1,3}, [ASVTG]P{1,2}}
#' \item{past_percent} {summed percent of "P", "A", "S" and "T" amino acids}
#' \item{pvyk_percent} {summed percent of "P", "V", "Y" and "K" amino acids}
#' \item{psky_percent} {summed percent of "P", "S", "K" and "Y" amino acids}
#' \item{p_percent} {percent of "P"}
#' \item{coverage} {the coverage of sequence by the identified motifs}
#' \item{maab_class} {determined maab class}
#'}
#' 
#' @details The function provides motif and amino acid bias descriptors used for classification of HRGP's by the MAAB pipeline (Johnson et al. 2017) as well as the determined HRGP classes. The motifs are counted in a specific order ext > tyr > prp > agp, and overlapping motifs are not counted. Hence the classification depends on the order of counting, this is most noticeable for tyr and prp, we recommend using both the default order and  'order = c("ext", "prp","tyr", "agp")'. 
#' 
#' @references Johnson KL, Cassin AM, Lonsdale A, Bacic A, Doblin MS, Schultz CJ. (2017) Pipeline to Identify Hydroxyproline-Rich Glycoproteins. Plant Physiol 174(2): 886-903.
#'
#' @seealso \code{\link[ragp]{scan_ag}}
#'
#' @examples
#'
#' library(ragp)
#' data(at_nsp)
#'
#' maab_class <- maab(sequence = at_nsp$sequence,
#'                    id = at_nsp$Transcript.id)
#'                   
#' @export                  


maab <- function(data = NULL, sequence, id, order = c("ext", "tyr", "prp", "agp"), gpi = NULL){
  if(missing(order)) order <- c("ext", "tyr", "prp", "agp")
  if(!is.character(order)){
    stop("order should be a character vector containing four elements:
         'ext', 'tyr', 'prp', 'agp'")
  }
  if(length(order) != 4){
    stop("order should be a character vector containing four elements:
         'ext', 'tyr', 'prp', 'agp'")
  }
  if(sum(order %in% c("ext", "tyr", "prp", "agp")) != 4){
    stop("order should contain only elements:
         'ext', 'tyr', 'prp', 'agp'")
  }
  if(missing(data)){
    if (missing(sequence)){
      stop("protein sequence must be provided to obtain predictions")
    }
    if (missing(id)){
      stop("protein id must be provided to obtain predictions")
    }
    id <- as.character(id)
    sequence <- toupper(as.character(sequence))
    if (length(sequence) != length(id)){
      stop("id and sequence vectors are not of same length")
    }
  }
  if(class(data[[1]]) ==  "SeqFastaAA"){
    dat <- lapply(data, paste0, collapse ="")
    id <- names(dat)
    sequence <- toupper(as.character(unlist(dat)))
  }
  if(class(data) == "data.frame"){
    if(missing(sequence)){
      stop("the column name with the sequences must be specified")
    }
    if(missing(id)){
      stop("the column name with the sequence id's must be specified")
    }
    id <- as.character(substitute(id))
    sequence <- as.character(substitute(sequence))
    if (length(id) != 1L){
      stop("only one column name for 'id' must be specifed")
    }
    if (length(sequence) != 1L){
      stop("only one column name for 'sequence' must be specifed")
    }
    id <- if(id %in% colnames(data)){
      data[[id]]
    } else {
      stop("specified 'id' not found in data")
    }
    id <- as.character(id)  
    sequence  <- if(sequence %in% colnames(data)){
      data[[sequence]]
    } else {
      stop("specified 'sequence' not found in data")
    }
    sequence <- toupper(as.character(sequence))
  }
  if(class(data) == "character"){
    if (file.exists(data)){
      dat <- seqinr::read.fasta(file = data,
                                seqtype = "AA",
                                as.string = FALSE)
      dat <- lapply(dat, paste0, collapse ="")
      id <- names(dat)
      sequence <- toupper(as.character(unlist(dat)))
    } else {
      stop("cannot find file in the specified path")
    }
  }
  sequence <- sub("\\*$", "", sequence)
  seq_len <- nchar(sequence)
  amino_acids = c("A", "R", "N", "D", "C",
                  "Q", "E", "G", "H", "I",
                  "L", "K", "M", "F", "P",
                  "S", "T", "W", "Y", "V")
  hrgp_aa_name <- c("past_count",
                    "pvyk_count",
                    "psky_count",
                    "p_count")
  
  hrgp_aa <- c("P|A|S|T",
               "P|V|Y|K",
               "P|S|K|Y",
               "P")
  
  HGRP <- list(ext = "SP{3,5}",
               tyr = c("[FY].Y",
                       "KHY",
                       "VY[HKDE]",
                       "V.Y",
                       "YY"),
               prp = c("PPV.[KT]",
                       "PPV[QK]",
                       "KKPCPP"),
               agp = c("[AVTG]P{1,3}",
                       "[ASVTG]P{1,2}"))
  
  
  HGRP_names <- list(ext = "ext_sp",
                     tyr = c("ext_fyxy_count",
                             "ext_khy_count",
                             "ext_vyhkde_count",
                             "ext_vxy_count",
                             "ext_yy_count"),
                     prp = c("prp_ppvqk_count",
                             "prp_ppvxkt_count",
                             "ppr_kkpcpp"),
                     agp = c("agp_atgvppp_count",
                             "agp_astgvp_count"))
  
  hrgp_m_name <- as.vector(unlist(HGRP_names[order]))

  hrgp_motif <- as.vector(unlist(HGRP[order]))
  
  out_count <-  lapply(hrgp_aa, function(x){
    stringr::str_count(sequence, x)
  })           
  out_percent <- lapply(1:4, function(x){
    out_count[[x]] / seq_len * 100
  })
  names(out_percent) <- paste0(c("past",
                                 "pvyk",
                                 "psky",
                                 "p"), "_percent")
  
  sequencei <- sequence
  counts <- vector("list", length(hrgp_motif))
  lens <- vector("list", length(hrgp_motif))
  for(i in seq_along(hrgp_motif)){
    counts[[i]] <- stringr::str_count(sequencei, hrgp_motif[i])
    stringr::str_extract_all(sequencei, hrgp_motif[i])
    lens[[i]] <- unlist(lapply(stringr::str_extract_all(sequencei,
                                                        hrgp_motif[i]),
                               function(x){
      return(nchar(paste(x, collapse = "")))
    }))
    sequencei <- stringr::str_replace_all(sequencei,
                                          hrgp_motif[i], "XX")
  }
  
  lens <- do.call(cbind, lens)
  coverage <- rowSums(lens)/seq_len
  names(counts) <- hrgp_m_name
  counts <- do.call(cbind, counts)
  out_percent <- do.call(cbind, out_percent)
  counts2 <- data.frame(ext_sp = counts[,"ext_sp"],
                        ext_tyr = rowSums(counts[,c("ext_fyxy_count",
                                                    "ext_khy_count",
                                                    "ext_vyhkde_count",
                                                    "ext_vxy_count",
                                                    "ext_yy_count")]),
                        prp = rowSums(counts[,c("prp_ppvqk_count",
                                                "prp_ppvxkt_count",
                                                "ppr_kkpcpp")]),
                        agp = rowSums(counts[,c("agp_atgvppp_count",
                                                "agp_astgvp_count")]),
                        out_percent,
                        coverage = coverage)
  predict_maab <- function(maab){
    past_percent <- maab$past_percent
    pvyk_percent <- maab$pvyk_percent
    psky_percent <- maab$psky_percent
    p_percent <- maab$p_percent
    ext_sp_count <- maab$ext_sp
    tyr <- maab$ext_tyr
    agp <- maab$agp
    prp <- maab$prp
    ext <- tyr + ext_sp_count
    coverage <- maab$coverage
    categorisation <- ifelse((past_percent >= 45 |
                                pvyk_percent >= 45 |
                                psky_percent >= 45) &
                               p_percent >= 10, 1, 0)
    
    ext_rat <- ext_sp_count / tyr
    
    groups <- ifelse(categorisation == 1 &
                       past_percent >= 45 &
                       past_percent - pvyk_percent >= 2 &
                       past_percent - psky_percent >= 2,  "1/4", "0")
    
    groups <- ifelse(categorisation == 1 &
                       psky_percent >= 45 &
                       psky_percent - past_percent >= 2 &
                       psky_percent - pvyk_percent >= 2,  "2/9", groups)
    
    groups <- ifelse(categorisation == 1 &
                       pvyk_percent >= 45 &
                       pvyk_percent - past_percent >= 2 &
                       pvyk_percent - psky_percent >= 2,  "3/14", groups)
    
    groups <- ifelse(categorisation == 1 &
                       groups == "0", "Shared", groups)
    
    groups <- ifelse(groups == "1/4" &
                       agp/2 <= ext &
                       prp <= ext, "5", groups)
    groups <- ifelse(groups == "5" &
                       ext_rat > 4, "6", groups)
    groups <- ifelse(groups == "5" &
                       ext_rat < 0.25, "7", groups)
    groups <- ifelse(groups == "1/4" &
                       agp/2 < prp &
                       ext < prp, "8", groups)
    
    groups <- ifelse(groups == "2/9" &
                       agp/2 > ext &
                       agp/2 > prp, "10", groups)
    groups <- ifelse(groups == "2/9" &
                       prp > ext &
                       prp > agp/2, "13", groups)
    groups <- ifelse(groups == "2/9" &
                       ext_rat > 4, "11", groups)
    groups <- ifelse(groups == "2/9" &
                       ext_rat < 0.25, "12", groups)
    
    groups <- ifelse(groups == "3/14" &
                       agp/2 > prp &
                       agp/2 > ext,
                     "15", groups)
    groups <- ifelse(groups == "3/14" &
                       ext >= prp &
                       ext >= agp/2,
                     "16", groups)
    groups <- ifelse(groups == "16"&
                       ext_rat > 4, "17", groups)
    groups <- ifelse(groups == "16"&
                       ext_rat < 0.25, "18", groups)
    
    groups <- ifelse(groups == "Shared" &
                       agp/2 > ext &
                       agp/2 > prp, "19", groups)
    
    groups <- ifelse(groups == "Shared" &
                       prp > ext &
                       prp > agp/2, "23", groups)
    
    groups <- ifelse(groups == "Shared" &
                       ext >= prp &
                       ext >= agp/2, "20", groups)
    groups <- ifelse(groups == "20" &
                       ext_rat > 4, "21", groups)
    groups <- ifelse(groups == "20" &
                       ext_rat < 0.25, "22", groups)
    
    groups <- ifelse(coverage < 0.15 &
                       categorisation == 1 , 24, groups)
    groups
  }
  maab_class <- predict_maab(counts2)
  if(!missing(gpi)){
    if(!is.logical(gpi)){
      stop("gpi must be a logical vector")
    }
    if(length(gpi) != length(sequence)){
      stop("gpi must be the same length as the provided sequences")
    }
    maab_class <- ifelse(maab_class == "1/4" & gpi, "1", maab_class)
    maab_class <- ifelse(maab_class == "1/4" & !gpi, "4", maab_class)
    maab_class <- ifelse(maab_class == "2/9" & gpi, "9", maab_class)
    maab_class <- ifelse(maab_class == "2/9" & !gpi, "2", maab_class)
    maab_class <- ifelse(maab_class == "3/14" & gpi, "14", maab_class)
    maab_class <- ifelse(maab_class == "3/14" & !gpi, "3", maab_class)
  }

  out <- data.frame(id = id, 
                    counts2,
                    maab_class = as.factor(maab_class),
                    stringsAsFactors = FALSE)
  return(out)
}

