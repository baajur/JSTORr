#' Make a Document Term Matrix containing only nouns
#' 
#' @description This function does part-of-speech tagging and removes all parts of speech that are not non-name nouns. It also removes punctuation, numbers, words with less than three characters, stopwords and unusual characters (characters not in ISO-8859-1, ie non-latin1-ASCII). For use with JSTOR's Data for Research datasets (http://dfr.jstor.org/). This function uses the stoplist in the tm package. The location of tm's English stopwords list can be found by entering this at the R prompt: paste0(.libPaths()[1], "/tm/stopwords/english.dat") Note that the part-of-speech tagging can result in the removal of words of interest. Currently I'm not sure how to keep those words.
#' @param unpack1grams object returned by the function JSTOR_unpack1grams.
#' @param word Optional word or vector of words to subset the documents by, ie. make a document term matrix containing only documents in which this word (or words) appears at least once.
#' @param sparse A numeric for the maximal allowed sparsity, default is one (ie. no sparsing applied). Removes sparse terms from a term-document matrix, see help(removeSparseTerms) for more details. Values close to 1 result in a sparse matrix, values close to zero result in a dense matrix. It may be useful to reduce sparseness if the matrix is too big to manipulate in memory or if processing times are long.
#' @param POStag logical Do part-of-speech tagging to identify and remove non-nouns. Default is True, but the option is here to speed things up when working interactively with large numbers of documents. 
#' @return Returns a Document Term Matrix containing documents, ready for more advanced text mining and topic modelling.  
#' @examples 
#' ## nouns <- JSTOR_dtmofnouns(unpack1grams) 
#' @import tm NLP data.table openNLP 


JSTOR_dtmofnouns <- function(unpack1grams, word=NULL, sparse=1, POStag=TRUE){

y <- unpack1grams$wordcounts

if (length(word) == 1) {
  
# if we are subsetting for documents that contain a specific word...
  
# get dtm that only has the word of interest (to minimize memory burden)
y1 <- y[,y$dimnames$Terms == word]
# get matrix of frequencies of that word over all docs
y2 <- as.matrix(y1[,dimnames(y1)$Terms %in% word])
# subset full dtm to keep only docs with the word of interest
# plus all the other words in those docs
y3 <- y[ y$dimnames$Docs %in% names(y2[ y2 >= 1, ]), ]
y <- y3
# clean up
rm(y1, y2, y3)

} else {
  # just return the full set if no word is specified for subsetting
  y <- unpack1grams$wordcounts
}


# somehow docs got to be a factor... fix this
# and why do I have to subset the Docs like this?
# something to do with how the DTM is made? I bet
# the CSV file is dodgy... 
y$dimnames$Docs <- as.character(y$dimnames$Docs)
y <- y[unique(as.character(y$dimnames$Docs[1:nrow(y)])), ]

# reduce size of DTM in case of memory or speed issues
if (sparse == 1){
  # don't reduce the size
} else {
  # do reduce the size
  y <- removeSparseTerms(y, sparse)
}


# reduce the size of the dtm... select the dtm directly
# https://stat.ethz.ch/pipermail/r-help/2011-May/278202.html


message("removing stopwords...")
y <- y[, !(y$dimnames$Terms %in% stopwords(kind = "en")) ]
message("done")

message("discarding words with <3 characters (probably OCR errors)...")
y <- y[,nchar(y$dimnames$Terms) > 3]
message("done")

message("discarding words with >2 consecutive characters (probably OCR errors)...")
y <- y[,!grepl("(.)\\1{2,}", y$dimnames$Terms)]
message("done")

message("discarding non-ASCII characters...")
y <- y[,(y$dimnames$Terms %in% iconv(y$dimnames$Terms, "latin1", "ASCII", sub=""))]
message("done")

# message("discarding common first names...")
# # remove common human names http://www.fakenamegenerator.com/ http://www.census.gov/genealogy/www/data/2000surnames/index.html
# babynames <- tolower(data.table::fread("http://raw.github.com/hadley/data-baby-names/master/baby-names.csv"))
# bn <-   gsub("[[:punct:]]", "", unlist(unlist((strsplit(babynames[2], split=", ")))) )
# y <- y[,!(y$dimnames$Terms %in% bn)]
# message("done")
if (POStag == TRUE) {

# openNLP changed, so we need this replacement for tagPOS...

tagPOS <-  function(x) {
  
  s <- NLP::as.String(x)
  ## Need sentence and word token annotations.
  
  a1 <- NLP::Annotation(1L, "sentence", 1L, nchar(s))
  a2 <- NLP::annotate(s, openNLP::Maxent_Word_Token_Annotator(), a1)
  a3 <- NLP::annotate(s,  openNLP::Maxent_POS_Tag_Annotator(), a2)
  
  ## Determine the distribution of POS tags for word tokens.
  a3w <- a3[a3$type == "word"]
  POStags <- unlist(lapply(a3w$features, `[[`, "POS"))
  
  ## Extract token/POS pairs (all of them): easy - not needed
  # POStagged <- paste(sprintf("%s/%s", s[a3w], POStags), collapse = " ")
  return(unlist(POStags))
} 

   yt <- y$dimnames$Terms
   
   # divide Terms into chunks of 1000 terms each because more than that can cause
   # memory problems
   ytl <- split(yt, ceiling(seq_along(yt)/1000))
   
   # loop over each chunk of 1000 terms to do POStagging, I found that trying to
   # do 10,000 terms or more causes Java memory problems, so this is a very safe
   # method to try not to fill memory
   message("keeping only non-name nouns, this may take some time...")
   ytlp <- plyr::llply(ytl, function(i){
     tmp <- paste(gsub("[^[:alnum:]]", "", i), collapse = " ")
     tagPOS(tmp)
   }, .progress = "text")
   
   # get all the tags in a vector
   ytlput <- unname(c(unlist(ytlp)))
   
   # subset document term matrix terms to keep only nouns
   y <- y[ , y$dimnames$Terms[ytlput == "NN"], ]

} else { 
  # don't do POS tagging 
}

# clean up
invisible(gc())
message("all done")
return(y)
}





