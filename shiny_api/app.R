deps = c("glue", "Rook", "shiny")
to_install = setdiff(deps, rownames(installed.packages()))
if(length(to_install) > 0){
  install.packages(to_install)
}


library(shiny)

ui = shinyUI(fluidPage(
  singleton(tags$head(HTML(
'
<script type="text/javascript">
  $(document).ready(function() {
    Shiny.addCustomMessageHandler("api_url", function(message) {
      $("#url").text(message.url);
    });
  })
</script>
'
  ))),
  HTML(
'
<div id="url">
</div>
'
  ),
verbatimTextOutput("text"),
plotOutput("plot")
))

server = shinyServer(function(input, output, session) {
  
  quiz_answers = reactiveValues(
    q1 = setNames(numeric(4), letters[1:4])
  )
  
  api_url <- session$registerDataObj( 
    name   = 'api', # an arbitrary but unique name for the data object
    data   = list(), # you can bind some data here, which is the data argument for the
    # filter function below.
    filter = function(data, req) {
      print(ls(req))  # you can inspect what variables are encapsulated in this req
      if (req$REQUEST_METHOD == "GET") {
        query <- parseQueryString(req$QUERY_STRING)
      } 
      
      if (req$REQUEST_METHOD == "POST") {
        reqInput <- req$rook.input
        form = Rook::Multipart$parse(req)
        current = isolate(reactiveValuesToList(quiz_answers)$q1)
        current[form$value] = current[form$value] + 1
        quiz_answers$q1 = current
        shiny:::httpResponse(
          200, 'text/plain'
        )
      }
    }
  )
  
  output$plot = renderPlot({
    barplot(quiz_answers$q1)
  })
  
  text = reactiveVal()
  observe({
    cd = session$clientData
    my_api = glue::glue("{cd$url_protocol}//{cd$url_hostname}:{cd$url_port}/{api_url}")
    try_this = glue::glue(
      "
      Try running this code from a separate R session:
      
      url='{my_api}'
      httr::POST(
       url,
       body = list(value = sample(letters[1:4],1))
      )
      "
    )
    session$sendCustomMessage("api_url", list(url=my_api))
    text(try_this)
    })
  
  output$text = shiny::renderText({
    text()
  })
})

shiny::shinyApp(ui, server)
