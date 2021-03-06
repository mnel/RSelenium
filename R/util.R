#' Check for Server binary
#' 
#' \code{checkForServer}
#' A utility function to check if the Selenium Server stanalone binary is present.
#' @param dir A directory in which the binary is to be placed.
#' @param update A boolean indicating whether to update the binary if it is present.
#' @export
#' @import XML
#' @section Detail: The downloads for the Selenium project can be found at http://selenium-release.storage.googleapis.com/index.html. This convience function downloads the standalone server and places it in the RSelenium package directory bin folder by default.
#' @examples
#' \dontrun{
#' checkForServer()
#' }

checkForServer <- function (dir = NULL, update = FALSE) 
{
  selURL <- "http://selenium-release.storage.googleapis.com"
  selXML <- xmlParse(paste0(selURL), "/?delimiter=")
  selJAR <- xpathSApply(selXML, "//s:Key[contains(text(),'selenium-server-standalone')]", namespaces = c(s = "http://doc.s3.amazonaws.com/2006-03-01"), xmlValue)
  # get the most up-to-date jar
  selJAR <- selJAR[order(as.numeric(gsub("(.*)/.*", "\\1",selJAR)), decreasing = TRUE)][1]
  selDIR <- ifelse(is.null(dir), paste0(find.package("RSelenium"), 
                                        "/bin/"), dir)
  selFILE <- paste0(selDIR, "selenium-server-standalone.jar")
  if (update || !file.exists(selFILE)) {
    dir.create(selDIR, showWarnings=FALSE)
    print("DOWNLOADING STANDALONE SELENIUM SERVER. THIS MAY TAKE SEVERAL MINUTES")
    download.file(paste0( selURL, "/", selJAR), selFILE, mode = "wb")
  }
}

#' Start the standalone server.
#' 
#' \code{startServer}
#' A utility function to start the standalone server. 
#' @param dir A directory in which the binary is to be placed.
#' @export
#' @section Detail: By default the binary is assumed to be in
#' the RSelenium package /bin directory. 
#' @examples
#' \dontrun{
#' startServer()
#' }

startServer <- function (dir = NULL) 
{
  selDIR <- ifelse(is.null(dir), paste0(find.package("RSelenium"), 
                                        "/bin/"), dir)
  selFILE <- paste0(selDIR, "selenium-server-standalone.jar")
  logFILE <- paste0(selDIR, "sellog.txt")
  write("", logFILE)
  if (!file.exists(selFILE)) {
    stop("No Selenium Server binary exists. Run checkForServer or start server manually.")
  }
  else {
    if (.Platform$OS.type == "unix") {
      system(paste0("java -jar ", shQuote(selFILE), " -log ", shQuote(logFILE)), wait = FALSE, 
             ignore.stdout = TRUE, ignore.stderr = TRUE)
    }
    else {
      system(paste0("java -jar ", shQuote(selFILE), " -log ", shQuote(logFILE)), wait = FALSE, 
             invisible = FALSE)
    }
  }
}
#' Get Firefox profile.
#' 
#' \code{getFirefoxProfile}
#' A utility function to get a firefox profile. 
#' @param profDir The directory in which the firefox profile resides
#' @param useBase Logical indicating whether to attempt to use zip from utils package. Maybe easier for Windows users.
#' @export
#' @section Detail: A firefox profile directory is zipped and base64 encoded. It can then be passed
#' to the selenium server as a required capability with key firefox_profile 
#' @examples
#' \dontrun{
#' fprof <- getFirefoxProfile("~/.mozilla/firefox/9qlj1ofd.testprofile")
#' remDr <- remoteDriver(extraCapabilities = fprof)
#' remDr$open()
#' }

getFirefoxProfile <- function(profDir, useBase = FALSE){
  
  tmpfile <- tempfile(fileext = '.zip')
  reqFiles <- list.files(profDir, recursive = TRUE)
  if(!useBase){
    Rcompression::zip(tmpfile, paste(profDir, reqFiles, sep ="/"),  altNames = reqFiles)
  }else{
    currWd <- getwd()
    on.exit(setwd(currWd))
    setwd(profDir)
    # break the zip into chunks as windows command line has limit of 8191 characters
    # ignore .sqllite files
    reqFiles <- reqFiles[grep("^.*\\.sqlite$", reqFiles, perl = TRUE, invert = TRUE)]
    chunks <- sum(nchar(reqFiles))%/%8000 + 2
    chunks <- as.integer(seq(1, length(reqFiles), length.out= chunks))
    chunks <- mapply(`:`, head(chunks, -1)
                     , tail(chunks, -1) - c(rep(1, length(chunks) - 2), 0)
                     , SIMPLIFY = FALSE)
    out <- lapply(chunks, function(x){zip(tmpfile, reqFiles[x])})
  }
  zz <- file(tmpfile, "rb")
  ar <- readBin(tmpfile, "raw", file.info(tmpfile)$size)
  fireprof <- base64encode(ar)
  close(zz)
  list("firefox_profile" = fireprof)
}

#' Get Chrome profile.
#' 
#' \code{getChromeProfile}
#' A utility function to get a Chrome profile. 
#' @param dataDir Specifies the user data directory, which is where the browser will look for all of its state.
#' @param profileDir Selects directory of profile to associate with the first browser launched.
#' @export
#' @section Detail: A chrome profile directory is passed as an extraCapability.
#' The data dir has a number of default locations
#' \describe{
#' \item{Windows XP}{
#' Google Chrome: C:/Documents and Settings/\%USERNAME\%/Local Settings/Application Data/Google/Chrome/User Data
#' }
#' \item{Windows 8 or 7 or Vista}{
#' Google Chrome: C:/Users/\%USERNAME\%/AppData/Local/Google/Chrome/User Data
#' }
#' \item{Mac OS X}{
#' Google Chrome: ~/Library/Application Support/Google/Chrome
#' }
#' \item{Linux}{
#' Google Chrome: ~/.config/google-chrome
#' }
#' }
#' The profile directory is contained in the user directory and by default is named "Default" 
#' @examples
#' \dontrun{
#' # example from windows using a profile directory "Profile 1"
#' cprof <- getChromeProfile("C:\\Users\\john\\AppData\\Local\\Google\\Chrome\\User Data", "Profile 1")
#' remDr <- remoteDriver(browserName = "chrome", extraCapabilities = cprof)
#' }
getChromeProfile <- function(dataDir, profileDir){
  # see
  # http://peter.sh/experiments/chromium-command-line-switches/#user-data-dir
  # http://peter.sh/experiments/chromium-command-line-switches/#profile-directory
  cprof <- list(chromeOptions = list(args = list(paste0('--user-data-dir=',dataDir)
                                                 , paste0('--profile-directory=',profileDir))))
  cprof
}

#' Start a phantomjs binary in webdriver mode.
#' 
#' \code{phantom}
#' A utility function to control a phantomjs binary in webdriver mode. 
#' @param pjs_cmd The name, full or partial path of a phantomjs executable. This is optional only state if the executable is not in your path.
#' @param port An integer giving the port on which phantomjs will listen. Defaults to 4444. format [[<IP>:]<PORT>]
#' @param extras An optional character vector: see 'Details'.
#' @param ... Arguments to pass to \code{\link{system2}}
#' @export
#' @importFrom tools pskill
#' @section Detail: phantom() is used to start a phantomjs binary in webdriver mode. This can be used to drive
#' a phantomjs binary on a machine without selenium server. 
#' Argument extras can be used to specify optional extra command line arguments see \link{http://phantomjs.org/api/command-line.html}
#' @section Value: phantom() returns a list with two functions:
#' \describe{
#' \item{getPID}{returns the process id of the phantomjs binary running in webdriver mode.}
#' \item{stop}{terminates the phantomjs binary running in webdriver mode using \code{\link{pskill}}}
#' }
#' @examples
#' \dontrun{
#' pJS <- phantom()
#' # note we are running here without a selenium server phantomjs is listening on port 4444
#' # in webdriver mode
#' remDr <- remoteDriver(browserName = "phantomjs")
#' remDr$open()
#' remDr$navigate("http://www.google.com/ncr")
#' remDr$screenshot(display = TRUE)
#' webElem <- remDr$findElement("name", "q")
#' webElem$sendKeysToElement(list("HELLO WORLD"))
#' remDr$screenshot(display = TRUE)
#' remDr$close()
#' # note remDr$closeServer() is not called here. We stop the phantomjs binary using
#' pJS$stop()
#' }

phantom <- function (pjs_cmd = "", port = 4444L, extras = "", ...){
  if (!nzchar(pjs_cmd)) {
    pjsPath <- Sys.which("phantomjs")
  }else{
    pjsPath <- Sys.which(gs_cmd)    
  }
  if(nchar(pjsPath) == 0){stop("PhantomJS binary not located.")}
  pjsargs <- c(paste0("--webdriver=", port), extras)
  if (.Platform$OS.type == "windows"){
    system2(pjsPath, pjsargs, invisible = TRUE, wait = FALSE, ...)
    pjsPID <- read.csv(text = system("tasklist /v /fo csv", intern = TRUE))
    # support for MS-DOS-compatible (short) file name
    pjsPID <- pjsPID$PID[grepl("phantomjs.exe|PHANTO~1.EXE", pjsPID$Image.Name)]
  }else{
    system2(pjsPath, pjsargs, wait = FALSE, ...)
    # pjsPID <- system('pgrep -f phantomjs', intern = TRUE)[1] # pgrep not on MAC?
    pjsPID <- read.csv(text = system('ps -Ao"%p,%a"', intern = TRUE), stringsAsFactors = FALSE)
    pjsPID <- as.integer(pjsPID$PID[grepl("phantomjs", pjsPID$COMMAND)])
  }
  
  list(
    stop = function(){
      tools::pskill(pjsPID)
    },
    getPID = function(){
      return(pjsPID)
    }
  )
}

#' @export .DollarNames.remoteDriver
#' @export .DollarNames.webElement
#' @export .DollarNames.errorHandler
#' @import methods
#' 

matchSelKeys <- function(x){
  if(any(names(x) =='key')){
    x[names(x) =='key']<-selKeys[match(x[names(x) == 'key'],names(selKeys))]
  }
  unname(x)      
}

.DollarNames.remoteDriver <- function(x, pattern){
  grep(pattern, getRefClass(class(x))$methods(), value=TRUE)
}

.DollarNames.webElement <- function(x, pattern){
  grep(pattern, getRefClass(class(x))$methods(), value=TRUE)
}

.DollarNames.errorHandler <- function(x, pattern){
  grep(pattern, getRefClass(class(x))$methods(), value=TRUE)
}

