# Textos dos gráficos e das tabelas do caso TCC e formato dos números, em
# português, espanhol e inglês. Os termos seguem _rascunhos/glossario_pt_es_en.md.
#
# Uso: tx <- rotulos("pt")  (ou "es", "en")

## ---- rotulos ----
rotulos <- function(idioma = c("pt", "es", "en")) {
  idioma <- match.arg(idioma)
  ingles <- idioma == "en"

  # Números: vírgula decimal em PT e ES, ponto em EN. Em EN, o sinal de menos
  # é o tipográfico (U+2212), como na APA.
  num <- function(x, d = 2) {
    s <- formatC(x, format = "f", digits = d,
                 decimal.mark = if (ingles) "." else ",", big.mark = if (ingles) "," else ".")
    if (ingles) sub("^-", "−", s) else s
  }
  # Estatísticas que não passam de 1 (p, r, rho, alfa, R²...): em EN, a APA tira o zero à esquerda.
  num1 <- function(x, d = 2) {
    s <- num(x, d)
    if (ingles) sub("^(−?)0\\.", "\\1.", s) else s
  }
  zero_p <- if (ingles) ".001" else "0,001"
  # Espaço inseparável ( ) para "< 0,001" e o intervalo de confiança não quebrarem de linha.
  p_tab <- function(p) ifelse(p < 0.001, paste0("< ", zero_p), num1(p, 3))
  p_txt <- function(p) ifelse(p < 0.001, paste0("p < ", zero_p), paste0("p = ", num1(p, 3)))
  ic <- function(li, ls) paste0("[", num(li), "; ", num(ls), "]")
  pct <- function(x) paste0(round(100 * x), "%")

  t <- switch(idioma,
    pt = list(
      blocos = c(LID = "Liderança", REC = "Reconhecimento", REM = "Remuneração percebida",
                 EQU = "Equilíbrio trabalho e vida", INT = "Intenção de rotatividade"),
      abrev = c(LID = "Lid.", REC = "Rec.", REM = "Rem.", EQU = "Equ.", INT = "Int."),
      rem_sem4 = "Remuneração percebida, sem REM4",
      likert = c("Discordo totalmente", "Discordo", "Nem concordo nem discordo", "Concordo", "Concordo totalmente"),
      invertido = "invertido",
      enunciados = NULL,
      sexo = c("Feminino" = "Feminino", "Masculino" = "Masculino", "Prefiro não informar" = "Prefiro não informar"),
      faixa = c("18 a 24" = "18 a 24", "25 a 34" = "25 a 34", "35 a 44" = "35 a 44", "45 ou mais" = "45 ou mais"),
      escolaridade = c("Ensino fundamental" = "Ensino fundamental", "Ensino médio" = "Ensino médio",
                       "Superior incompleto" = "Superior incompleto", "Superior completo" = "Superior completo"),
      funcao = c("Operador(a) de caixa" = "Operador(a) de caixa", "Repositor(a)" = "Repositor(a)",
                 "Açougue e padaria" = "Açougue e padaria", "Atendimento" = "Atendimento", "Depósito" = "Depósito"),
      turno = c("Manhã" = "Manhã", "Tarde" = "Tarde", "Noite" = "Noite"),
      turno_grupo = c("Diurno" = "Diurno", "Noturno" = "Noturno"),
      tempo = c("Até 1 ano" = "Até 1 ano", "De 1 a 3 anos" = "De 1 a 3 anos",
                "De 3 a 5 anos" = "De 3 a 5 anos", "Mais de 5 anos" = "Mais de 5 anos"),
      termos = c(LID = "Liderança", REC = "Reconhecimento", REM = "Remuneração percebida",
                 EQU = "Equilíbrio trabalho e vida", noturno = "Turno noturno",
                 novato = "Até 1 ano de casa", feminino = "Sexo feminino"),
      hipoteses = c(LID = "H1. Liderança reduz a intenção", REC = "H2. Reconhecimento reduz a intenção",
                    REM = "H3. Remuneração reduz, com efeito menor", EQU = "H4. Equilíbrio reduz a intenção"),
      decisao = c(sim = "Suportada", parcial = "Parcialmente suportada", nao = "Não suportada"),
      fluxo = c("Etapa", "Excluídas", "Restam"),
      etapas = c("Respostas recebidas", "Sem aceite do termo de consentimento",
                 "Mais de 20% dos itens em branco", "Mesma resposta em todos os itens", "Respostas válidas"),
      grafias = c("Padronizada", "Como foi escrita", "Pessoas"),
      perfil = c(titulo = "**Característica**", n = "**n (%)**", sexo = "Sexo", faixa = "Faixa etária",
                 escolaridade = "Escolaridade", funcao = "Função", turno = "Turno", tempo = "Tempo de casa"),
      conf = c("Bloco", "Itens", "Alfa", "Ômega"),
      grupos = c("Grupo", "n", "Mediana", "Intervalo interquartil"), ate = "a",
      bloco = "Bloco", item = "Item",
      hip = c("Hipótese", "β", "IC 95%", "p", "Resultado"),
      apa = c("Preditor", "β", "EP", "IC 95%", "p"),
      g_turno = "Turno", g_tempo = "Tempo de casa", g_eixo_int = "Intenção de sair (1 a 5)",
      g_detectado = "Efeito detectado (p < 0,05)", g_sem_efeito = "Sem efeito detectado",
      g_eixo_coef = "Efeito na intenção de sair (em desvios-padrão)",
      gtsummary = "pt"
    ),
    es = list(
      blocos = c(LID = "Liderazgo", REC = "Reconocimiento", REM = "Remuneración percibida",
                 EQU = "Equilibrio entre trabajo y vida", INT = "Intención de rotación"),
      abrev = c(LID = "Lid.", REC = "Rec.", REM = "Rem.", EQU = "Equ.", INT = "Int."),
      rem_sem4 = "Remuneración percibida, sin REM4",
      likert = c("Totalmente en desacuerdo", "En desacuerdo", "Ni de acuerdo ni en desacuerdo",
                 "De acuerdo", "Totalmente de acuerdo"),
      invertido = "invertido",
      enunciados = c(
        LID1 = "Mi supervisor me trata con respeto.",
        LID2 = "Mi supervisor explica con claridad lo que espera de mí.",
        LID3 = "Mi supervisor rara vez me da retroalimentación sobre mi trabajo.",
        LID4 = "Puedo contar con mi supervisor cuando tengo un problema en el trabajo.",
        LID5 = "Mi supervisor distribuye las tareas de forma justa.",
        REC1 = "Cuando hago un buen trabajo, alguien lo nota.",
        REC2 = "Recibo elogios por mi trabajo.",
        REC3 = "Siento que la empresa valora mi esfuerzo.",
        REC4 = "La empresa reconoce a quien más se dedica.",
        REM1 = "Mi salario es justo por el trabajo que hago.",
        REM2 = "Mi salario es comparable al de otros supermercados de la región.",
        REM3 = "Estoy satisfecho con mi remuneración.",
        REM4 = "Recibo el subsidio de transporte a tiempo.",
        EQU1 = "Mi horario me permite atender mi vida personal.",
        EQU2 = "Puedo planificar mis días libres con anticipación.",
        EQU3 = "El trabajo rara vez interfiere con mis compromisos familiares.",
        EQU4 = "Salgo del trabajo a la hora prevista.",
        INT1 = "Pienso con frecuencia en dejar esta empresa.",
        INT2 = "Tengo la intención de buscar otro empleo en los próximos 12 meses.",
        INT3 = "Si surge una oferta similar en otro lugar, me voy."),
      sexo = c("Feminino" = "Femenino", "Masculino" = "Masculino", "Prefiro não informar" = "Prefiero no informar"),
      faixa = c("18 a 24" = "18 a 24", "25 a 34" = "25 a 34", "35 a 44" = "35 a 44", "45 ou mais" = "45 o más"),
      escolaridade = c("Ensino fundamental" = "Educación básica", "Ensino médio" = "Educación media",
                       "Superior incompleto" = "Universitaria incompleta", "Superior completo" = "Universitaria completa"),
      funcao = c("Operador(a) de caixa" = "Cajero(a)", "Repositor(a)" = "Reponedor(a)",
                 "Açougue e padaria" = "Carnicería y panadería", "Atendimento" = "Atención al cliente",
                 "Depósito" = "Almacén"),
      turno = c("Manhã" = "Mañana", "Tarde" = "Tarde", "Noite" = "Noche"),
      turno_grupo = c("Diurno" = "Diurno", "Noturno" = "Nocturno"),
      tempo = c("Até 1 ano" = "Hasta 1 año", "De 1 a 3 anos" = "De 1 a 3 años",
                "De 3 a 5 anos" = "De 3 a 5 años", "Mais de 5 anos" = "Más de 5 años"),
      termos = c(LID = "Liderazgo", REC = "Reconocimiento", REM = "Remuneración percibida",
                 EQU = "Equilibrio entre trabajo y vida", noturno = "Turno nocturno",
                 novato = "Hasta 1 año en la empresa", feminino = "Sexo femenino"),
      hipoteses = c(LID = "H1. El liderazgo reduce la intención", REC = "H2. El reconocimiento reduce la intención",
                    REM = "H3. La remuneración la reduce, con un efecto menor",
                    EQU = "H4. El equilibrio reduce la intención"),
      decisao = c(sim = "Respaldada", parcial = "Parcialmente respaldada", nao = "No respaldada"),
      fluxo = c("Etapa", "Excluidas", "Quedan"),
      etapas = c("Respuestas recibidas", "Sin aceptación del consentimiento informado",
                 "Más del 20% de los ítems en blanco", "La misma respuesta en todos los ítems",
                 "Respuestas válidas"),
      grafias = c("Categoría final", "Cómo se escribió", "Personas"),
      perfil = c(titulo = "**Característica**", n = "**n (%)**", sexo = "Sexo", faixa = "Rango de edad",
                 escolaridade = "Escolaridad", funcao = "Función", turno = "Turno", tempo = "Antigüedad"),
      conf = c("Bloque", "Ítems", "Alfa", "Omega"),
      grupos = c("Grupo", "n", "Mediana", "Rango intercuartílico"), ate = "a",
      bloco = "Bloque", item = "Ítem",
      hip = c("Hipótesis", "β", "IC 95%", "p", "Resultado"),
      apa = c("Predictor", "β", "EE", "IC 95%", "p"),
      g_turno = "Turno", g_tempo = "Antigüedad", g_eixo_int = "Intención de irse (1 a 5)",
      g_detectado = "Efecto detectado (p < 0,05)", g_sem_efeito = "Sin efecto detectado",
      g_eixo_coef = "Efecto en la intención de irse (en desviaciones estándar)",
      gtsummary = "es"
    ),
    en = list(
      blocos = c(LID = "Leadership", REC = "Recognition", REM = "Perceived pay",
                 EQU = "Work-life balance", INT = "Turnover intention"),
      abrev = c(LID = "Lead.", REC = "Recog.", REM = "Pay", EQU = "Bal.", INT = "Int."),
      rem_sem4 = "Perceived pay, without REM4",
      likert = c("Strongly disagree", "Disagree", "Neither agree nor disagree", "Agree", "Strongly agree"),
      invertido = "reversed",
      enunciados = c(
        LID1 = "My supervisor treats me with respect.",
        LID2 = "My supervisor clearly explains what they expect from me.",
        LID3 = "My supervisor rarely gives me feedback on my work.",
        LID4 = "I can count on my supervisor when I have a problem at work.",
        LID5 = "My supervisor assigns tasks fairly.",
        REC1 = "When I do a good job, someone notices.",
        REC2 = "I get praise for my work.",
        REC3 = "I feel that the company values my effort.",
        REC4 = "The company recognizes those who work hardest.",
        REM1 = "My pay is fair for the work I do.",
        REM2 = "My pay is in line with other supermarkets in the region.",
        REM3 = "I am satisfied with my pay.",
        REM4 = "I receive my transportation allowance on time.",
        EQU1 = "My schedule lets me take care of my personal life.",
        EQU2 = "I can plan my days off in advance.",
        EQU3 = "Work rarely gets in the way of my family commitments.",
        EQU4 = "I leave work at the scheduled time.",
        INT1 = "I often think about leaving this company.",
        INT2 = "I plan to look for another job in the next 12 months.",
        INT3 = "If a similar offer comes up somewhere else, I'll leave."),
      sexo = c("Feminino" = "Female", "Masculino" = "Male", "Prefiro não informar" = "Prefer not to say"),
      faixa = c("18 a 24" = "18 to 24", "25 a 34" = "25 to 34", "35 a 44" = "35 to 44", "45 ou mais" = "45 or older"),
      escolaridade = c("Ensino fundamental" = "Elementary school", "Ensino médio" = "High school",
                       "Superior incompleto" = "Some college", "Superior completo" = "College degree"),
      funcao = c("Operador(a) de caixa" = "Cashier", "Repositor(a)" = "Stock clerk",
                 "Açougue e padaria" = "Butcher and bakery", "Atendimento" = "Customer service",
                 "Depósito" = "Warehouse"),
      turno = c("Manhã" = "Morning", "Tarde" = "Afternoon", "Noite" = "Night"),
      turno_grupo = c("Diurno" = "Day", "Noturno" = "Night"),
      tempo = c("Até 1 ano" = "Up to 1 year", "De 1 a 3 anos" = "1 to 3 years",
                "De 3 a 5 anos" = "3 to 5 years", "Mais de 5 anos" = "More than 5 years"),
      termos = c(LID = "Leadership", REC = "Recognition", REM = "Perceived pay",
                 EQU = "Work-life balance", noturno = "Night shift",
                 novato = "Up to 1 year of tenure", feminino = "Female"),
      hipoteses = c(LID = "H1. Leadership reduces intention", REC = "H2. Recognition reduces intention",
                    REM = "H3. Pay reduces it, with a smaller effect", EQU = "H4. Work-life balance reduces intention"),
      decisao = c(sim = "Supported", parcial = "Partially supported", nao = "Not supported"),
      fluxo = c("Step", "Excluded", "Remaining"),
      etapas = c("Responses received", "No consent to participate", "More than 20% of items blank",
                 "Same answer on every item", "Valid responses"),
      grafias = c("Final category", "As written", "People"),
      perfil = c(titulo = "**Characteristic**", n = "**n (%)**", sexo = "Sex", faixa = "Age group",
                 escolaridade = "Education", funcao = "Role", turno = "Shift", tempo = "Tenure"),
      conf = c("Block", "Items", "Alpha", "Omega"),
      grupos = c("Group", "n", "Median", "Interquartile range"), ate = "to",
      bloco = "Block", item = "Item",
      hip = c("Hypothesis", "β", "95% CI", "p", "Result"),
      apa = c("Predictor", "β", "SE", "95% CI", "p"),
      g_turno = "Shift", g_tempo = "Tenure", g_eixo_int = "Intention to leave (1 to 5)",
      g_detectado = "Effect detected (p < .05)", g_sem_efeito = "No effect detected",
      g_eixo_coef = "Effect on intention to leave (in standard deviations)",
      gtsummary = "en"
    )
  )
  c(t, list(idioma = idioma, num = num, num1 = num1, p_tab = p_tab, p_txt = p_txt, ic = ic, pct = pct))
}
