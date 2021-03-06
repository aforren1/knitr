#' A wrapper for rst2pdf
#'
#' Convert reST to PDF using \command{rst2pdf} (which converts from rst to PDF
#' using the ReportLab open-source library).
#' @param input the input rst file
#' @param command a character string which gives the path of the
#'   \command{rst2pdf} program (if it is not in PATH, the full path has to be
#'   given)
#' @param options extra command line options, e.g. \code{'-v'}
#' @author Alex Zvoleff and Yihui Xie
#' @return An input file \file{*.rst} will produce \file{*.pdf} and this output
#'   filename is returned if the conversion was successful.
#' @export
#' @seealso \code{\link{knit2pdf}}
#' @references \url{https://github.com/rst2pdf/rst2pdf}
rst2pdf = function(input, command = 'rst2pdf', options = '') {
  out = sub_ext(input, 'pdf')
  system2(command, paste(shQuote(input), '-o', shQuote(out), options))
  if (file.exists(out)) out else stop('conversion by rst2pdf failed!')
}

#' Convert Rnw or Rrst files to PDF using knit() and texi2pdf() or rst2pdf()
#'
#' Knit the input Rnw or Rrst document, and compile to PDF using \code{texi2pdf}
#' or \code{rst2pdf}.
#' @inheritParams knit
#' @param compiler a character string which gives the LaTeX program used to
#'   compile the tex document to PDF (by default it uses the default setting of
#'   \code{\link[tools]{texi2pdf}}, which is often PDFLaTeX); this argument will
#'   be used to temporarily set the environmental variable \samp{PDFLATEX}. For
#'   an Rrst file, setting compiler to \code{'rst2pdf'} will use
#'   \code{\link{rst2pdf}} to compiles the rst file to PDF using the ReportLab
#'   open-source library.
#' @param ... options to be passed to \code{\link[tools]{texi2pdf}} or
#'   \code{\link{rst2pdf}}
#' @author Ramnath Vaidyanathan, Alex Zvoleff and Yihui Xie
#' @return The filename of the PDF file.
#' @note The \code{output} argument specifies the output filename to be passed
#'   to the PDF compiler (e.g. a tex document) instead of the PDF filename.
#' @export
#' @seealso \code{\link{knit}}, \code{\link[tools]{texi2pdf}},
#'   \code{\link{rst2pdf}}
#' @examples #' compile with xelatex
#' ## knit2pdf(..., compiler = 'xelatex')
#'
#' #' compile a reST file with rst2pdf
#' ## knit2pdf(..., compiler = 'rst2pdf')
knit2pdf = function(input, output = NULL, compiler = NULL, envir = parent.frame(),
                    quiet = FALSE, encoding = getOption('encoding'), ...) {
  out = knit(input, output = output, envir = envir, quiet = quiet, encoding = encoding)
  owd = setwd(dirname(out)); on.exit(setwd(owd))
  if (is.null(compiler) && grepl('\\.rst$', out)) compiler = 'rst2pdf'
  if (!is.null(compiler)) {
    if (compiler == 'rst2pdf') {
      if (tolower(file_ext(out)) != 'rst')
        stop('for rst2pdf compiler input must be a .rst file')
      rst2pdf(basename(out), ...)
      return(sub_ext(out, 'pdf'))
    } else {
      # use the specified PDFLATEX command
      oc = Sys.getenv('PDFLATEX', NA)
      on.exit(
        if (is.na(oc)) Sys.unsetenv('PDFLATEX') else Sys.setenv(PDFLATEX = oc),
        add = TRUE
      )
      Sys.setenv(PDFLATEX = compiler)
    }
  }
  tools::texi2pdf(basename(out), ...)
  sub_ext(out, 'pdf')
}

#' Convert markdown to HTML using knit() and markdownToHTML()
#'
#' This is a convenience function to knit the input markdown source and call
#' \code{\link[markdown]{markdownToHTML}()} in the \pkg{markdown} package to
#' convert the result to HTML.
#' @inheritParams knit
#' @param ... options passed to \code{\link[markdown]{markdownToHTML}}
#' @param force_v1 whether to force rendering the input document as an R
#'   Markdown v1 document (even if it is for v2)
#' @export
#' @seealso \code{\link{knit}}, \code{\link[markdown]{markdownToHTML}}
#' @return If the argument \code{text} is NULL, a character string (HTML code)
#'   is returned; otherwise the result is written into a file and the filename
#'   is returned.
#' @note The \pkg{markdown} package is for R Markdown v1, which is much less
#'   powerful than R Markdown v2, i.e. the \pkg{rmarkdown} package
#'   (\url{http://rmarkdown.rstudio.com}). To render R Markdown v2 documents to
#'   HTML, please use \code{rmarkdown::render()} instead.
#' @examples # a minimal example
#' writeLines(c("# hello markdown", '```{r hello-random, echo=TRUE}', 'rnorm(5)', '```'), 'test.Rmd')
#' knit2html('test.Rmd')
#' if (interactive()) browseURL('test.html')
knit2html = function(input, output = NULL, ..., envir = parent.frame(), text = NULL,
                     quiet = FALSE, encoding = getOption('encoding'), force_v1 = FALSE) {
  if (!force_v1 && is.null(text)) {
    con = file(input, encoding = encoding)
    on.exit(close(con), add = TRUE)
    signal = if (is_R_CMD_check()) warning else stop
    if (length(grep('^---\\s*$', head(readLines(con), 1)))) signal(
      'It seems you should call rmarkdown::render() instead of knitr::knit2html() ',
      'because ', input, ' appears to be an R Markdown v2 document.', call. = FALSE
    )
  }
  out = knit(input, text = text, envir = envir, encoding = encoding, quiet = quiet)
  if (is.null(text)) {
    output = sub_ext(if (is.null(output) || is.na(output)) out else output, 'html')
    markdown::markdownToHTML(out, output, encoding = encoding, ...)
    invisible(output)
  } else markdown::markdownToHTML(text = out, ...)
}

#' Knit an R Markdown document and post it to WordPress
#'
#' This function is a wrapper around the \pkg{RWordPress} package. It compiles
#' an R Markdown document to HTML and post the results to WordPress.
#' @param input the filename of the Rmd document
#' @param title the post title
#' @param ... other meta information of the post, e.g. \code{categories = c('R',
#'   'Stats')} and \code{mt_keywords = c('knitr', 'wordpress')}, etc
#' @param shortcode a logical vector of length 2: whether to use the shortcode
#'   \samp{[sourcecode lang='lang']} which can be useful to WordPress.com users
#'   for syntax highlighting of source code and output; the first element
#'   applies to source code, and the second applies to text output (by default,
#'   both are \code{FALSE})
#' @param action to create a new post, update an existing post, or create a new
#'   page
#' @param postid if action is \code{editPost}, the post id \code{postid} must be
#'   specified
#' @param publish whether to publish the post immediately
#' @inheritParams knit
#' @export
#' @references \url{http://yihui.name/knitr/demo/wordpress/}
#' @author William K. Morris, Yihui Xie, and Jared Lander
#' @note This function will convert the encoding of the post and the title to
#'   UTF-8 internally. If you have additional data to send to WordPress (e.g.
#'   keywords and categories), you may have to manually convert them to the
#'   UTF-8 encoding with the \code{\link{iconv}(x, to = 'UTF-8')} function
#'   (especially when using Windows).
#' @examples # see the reference
knit2wp = function(
  input, title = 'A post from knitr', ..., envir = parent.frame(), shortcode = FALSE,
  action = c('newPost', 'editPost', 'newPage'), postid,
  encoding = getOption('encoding'), publish = TRUE
) {
  out = knit(input, encoding = encoding, envir = envir); on.exit(unlink(out))
  con = file(out, encoding = encoding); on.exit(close(con), add = TRUE)
  content = native_encode(readLines(con, warn = FALSE))
  content = paste(content, collapse = '\n')
  content = markdown::markdownToHTML(text = content, fragment.only = TRUE)
  shortcode = rep(shortcode, length.out = 2L)
  if (shortcode[1]) content = gsub(
    '<pre><code class="([[:alpha:]]+)">(.+?)</code></pre>',
    '[sourcecode language="\\1"]\\2[/sourcecode]', content
  )
  content = gsub(
    '<pre><code( class="no-highlight"|)>(.+?)</code></pre>',
    if (shortcode[2]) '[sourcecode]\\2[/sourcecode]' else '<pre>\\2</pre>', content
  )

  content = native_encode(content, 'UTF-8')
  title = native_encode(title, 'UTF-8')

  # figure out if we are making a newPost or overwriting an existing post
  action = match.arg(action)

  # build a list of arguments to be fed into either newPost or editPost
  # the first argument is the content, which itself is a list containing
  #     description
  #     title
  #     ...
  # then there is the publish argument
  WPargs = list(content = list(description = content, title = title, ...), publish = publish)

  # if we are editing the post, also include the argument for postid
  if (action == "editPost") WPargs = c(postid = postid, WPargs)

  do.call('library', list(package = 'RWordPress', character.only = TRUE))
  do.call(action, args = WPargs)
}

#' Watch an input file continuously and knit it when it is updated
#'
#' Check the modification time of an input file continously in an infinite loop.
#' Whenever the time indicates the file has been modified, call a function to
#' recompile the input file.
#'
#' This is actually a general function not necessarily restricted to
#' applications in \pkg{knitr}. You may specify any \code{compile} function to
#' process the \code{input} file. To stop the infinite loop, press the
#' \samp{Escape} key or \samp{Ctrl + C} (depending on your editing environment
#' and operating system).
#' @param input an input file path (or a character vector of mutiple paths of
#'   input files)
#' @param compile a function to compile the \code{input} file, e.g. it can be
#'   \code{\link{knit}} or \code{\link{knit2pdf}} depending on the input file
#'   and the output you want
#' @param interval a time interval to pause in each cycle of the infinite loop
#' @param ... other arguments to be passed to the \code{compile} function
#' @export
#' @examples # knit_watch('foo.Rnw', knit2pdf)
#'
#' # knit_watch('foo.Rmd', rmarkdown::render)
knit_watch = function(input, compile = knit, interval = 1, ...) {
  mtime = function(...) file.info(...)[, 'mtime']
  last_time = mtime(input)
  updated = function() {
    this_time = mtime(input)
    on.exit(last_time <<- this_time, add = TRUE)
    this_time > last_time
  }
  for (f in input) compile(f, ...)
  while (TRUE) {
    for (f in input[updated()]) compile(f, ...)
    Sys.sleep(interval)
  }
}
