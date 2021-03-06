library(shiny)
library(shinydashboard)
library(tidyverse)

ui <- dashboardPage(
  dashboardHeader(title = "IMDB"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Informações gerais", tabName = "info"),
      menuItem("Bilheteria", tabName = "bilheteria"),
      menuItem("Filmes", tabName = "filmes")
    )
  ),
  dashboardBody(
    tabItems(
      tabItem(
        tabName = "info",
        h1("Informações gerais dos filmes"),
        br(),
        fluidRow(
          infoBoxOutput(
            outputId = "num_filmes",
            width = 4
          ),
          infoBoxOutput(
            outputId = "num_diretores",
            width = 4
          ),
          infoBoxOutput(
            outputId = "num_atores",
            width = 4
          )
        ),
        h3("Top 10 lucros"),
        br(),
        fluidRow(
          column(
            width = 12,
            reactable::reactableOutput("tabela_info_gerais")
          )
        )
      ),
      tabItem(
        tabName = "bilheteria",
        h1("Analisando os orçamentos"),
        br(),
        box(
          width = 12,
          uiOutput("ui_genero")
        ),
        box(
          width = 6,
          title = "Série do orçamento",
          solidHeader = TRUE,
          status = "primary",
          plotOutput("serie_orcamento")
        ),
        box(
          width = 6,
          title = "Série da receita",
          solidHeader = TRUE,
          status = "primary",
          plotly::plotlyOutput("serie_receita")
        )
      ),
      tabItem(
        tabName = "filmes",
        h1("Informações de cada filme"),
        br(),
        fluidRow(
          box(
            width = 12,
            column(
              width = 4,
              selectInput(
                inputId = "diretor",
                label = "Selecione um diretorr",
                choices = ""
              )
            ),
            column(
              width = 8,
              selectInput( 
                inputId = "filme",
                label = "Selecione um filme",
                choices = "",
                width = "100%"
              )
            )
          )
        ),
        fluidRow(
          valueBoxOutput("filme_orcamento", width = 6),
          valueBoxOutput("filme_receita", width = 6),
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  imdb <- read_rds("../dados/imdb.rds")
  
  output$num_filmes <- renderInfoBox({
    infoBox(
      title = "Número de filmes",
      value = nrow(imdb),
      icon = icon("film"),
      fill = TRUE
    )
  })
  
  output$num_diretores <- renderInfoBox({
    infoBox(
      title = "Número de diretores",
      value = n_distinct(imdb$diretor),
      fill = TRUE,
      icon = icon("hand-point-right")
    )
  })
  
  output$num_atores <- renderInfoBox({
    
    num_atores <- imdb %>% 
      select(starts_with("ator")) %>% 
      pivot_longer(cols = ator_1:ator_3) %>% 
      distinct(value) %>% 
      nrow()
    
    infoBox(
      title = "Número de atores",
      value = num_atores,
      fill = TRUE,
      icon = icon("user-friends")
    )
  })
  
  output$tabela_info_gerais <- reactable::renderReactable({
    imdb %>% 
      mutate(lucro = receita - orcamento) %>% 
      top_n(10, lucro) %>% 
      select(titulo, diretor, ano, lucro) %>% 
      arrange(desc(lucro)) %>% 
      mutate(lucro = scales::dollar(lucro)) %>% 
      reactable::reactable(
        striped = TRUE,
        highlight = TRUE,
        defaultPageSize = 20
      )
  })
  
  output$ui_genero <- renderUI({
    
    generos <- imdb$generos %>% 
      paste(collapse = "|") %>% 
      str_split("\\|", simplify = TRUE) %>% 
      as.character() %>% 
      unique() %>% 
      sort()
    
    selectInput(
      inputId = "genero_orcamento",
      label = "Selecione um genero",
      choices = generos,
      width = "25%"
    )
    
  })
  
  output$serie_orcamento <- renderPlot({
    
    req(input$genero_orcamento)
    
    imdb %>% 
      filter(str_detect(generos, input$genero_orcamento)) %>% 
      group_by(ano) %>% 
      summarise(orcamento_medio = mean(orcamento, na.rm = TRUE)) %>% 
      filter(!is.na(orcamento_medio)) %>% 
      ggplot(aes(x = ano, y = orcamento_medio)) +
      geom_line()
  })
  
  output$serie_receita <- plotly::renderPlotly({
    
    req(input$genero_orcamento)
    
    p <- imdb %>% 
      filter(str_detect(generos, input$genero_orcamento)) %>% 
      group_by(ano) %>% 
      summarise(receita_media = mean(receita, na.rm = TRUE)) %>% 
      filter(!is.na(receita_media)) %>% 
      ggplot(aes(x = ano, y = receita_media)) +
      geom_line()
    
      plotly::ggplotly(p)
  })
  
  output$ui_diretor <- renderUI({
    diretores <- imdb$diretor %>%
      unique() %>% 
      sort()
    
    selectInput(
      inputId = "diretor",
      label = "Selecione um diretorr",
      choices = diretores,
      selected = "Quentin Tarantino"
    )
  })
  
  observe({
    
    diretores <- imdb$diretor %>%
      unique() %>% 
      sort()
    
    updateSelectInput(
      session,
      inputId = "diretor",
      choices = diretores,
      selected = "Quentin Tarantino"
    )
    
  })
  
  observe({
    
    filmes <- imdb %>% 
      filter(diretor == input$diretor) %>% 
      pull(titulo) %>% 
      sort()
    
    updateSelectInput(
      session,
      inputId = "filme",
      choices = filmes
    )
    
  })
  
  output$filme_orcamento <- renderValueBox({
    filme <- imdb %>% 
      filter(titulo == input$filme)
    valueBox(
      value = scales::dollar(filme$orcamento),
      subtitle = "dólares",
      icon = icon("dollar-sign")
    )
  })
  
  
  output$filme_receita <- renderValueBox({
    filme <- imdb %>% 
      filter(titulo == input$filme)
    valueBox(
      value = scales::dollar(filme$receita),
      subtitle = "dólares",
      icon = icon("dollar-sign")
    )
  })
  
}

shinyApp(ui, server)