"""Tablas de nombres de mes/día para los idiomas soportados por la dimensión.

Centralizado aquí en vez de delegar en el soporte de localización de cada
motor (el parámetro `culture` de `Date.MonthName`/`Date.DayOfWeekName` en M,
`SET LANGUAGE`/`DATENAME` en T-SQL, el locale de la JVM en `date_format` de
PySpark) porque los tres no coinciden entre sí, y ninguno de los tres trae
euskera, català ni galego como locale nativo garantizado (SQL Server no los
lista en `sys.syslanguages`; un cluster Spark depende del locale del JVM del
nodo). Con tablas explícitas, "Month Name"/"Day Name" salen igual sin
importar el motor de destino o el locale del servidor — coherente con la
promesa de esta skill de que los mismos parámetros siempre generan la misma
salida.

`days` va indexado de domingo=0 a sábado=6, igual que `Date.DayOfWeek` en
Power Query (con `firstDayOfWeek` por defecto) y que `[Day of Week]` en las
plantillas T-SQL/PySpark (`DATEPART(WEEKDAY,...)-1` / `dayofweek(...)-1`).
"""

DEFAULT_LANGUAGE = "es"

LANGUAGES = {
    "es": {
        "label": "Español",
        "months": [
            "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
            "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
        ],
        "days": ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"],
    },
    "en": {
        "label": "English",
        "months": [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ],
        "days": ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],
    },
    "pt": {
        "label": "Português",
        "months": [
            "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
            "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
        ],
        "days": ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"],
    },
    "ca": {
        "label": "Català",
        "months": [
            "Gener", "Febrer", "Març", "Abril", "Maig", "Juny",
            "Juliol", "Agost", "Setembre", "Octubre", "Novembre", "Desembre",
        ],
        "days": ["Diumenge", "Dilluns", "Dimarts", "Dimecres", "Dijous", "Divendres", "Dissabte"],
    },
    "eu": {
        "label": "Euskara",
        "months": [
            "Urtarrila", "Otsaila", "Martxoa", "Apirila", "Maiatza", "Ekaina",
            "Uztaila", "Abuztua", "Iraila", "Urria", "Azaroa", "Abendua",
        ],
        "days": ["Igandea", "Astelehena", "Asteartea", "Asteazkena", "Osteguna", "Ostirala", "Larunbata"],
    },
    "gl": {
        "label": "Galego",
        "months": [
            "Xaneiro", "Febreiro", "Marzo", "Abril", "Maio", "Xuño",
            "Xullo", "Agosto", "Setembro", "Outubro", "Novembro", "Decembro",
        ],
        "days": ["Domingo", "Luns", "Martes", "Mércores", "Xoves", "Venres", "Sábado"],
    },
    "fr": {
        "label": "Français",
        "months": [
            "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
            "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre",
        ],
        "days": ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"],
    },
}


def get_language(code: str) -> dict:
    try:
        return LANGUAGES[code]
    except KeyError:
        supported = ", ".join(sorted(LANGUAGES))
        raise ValueError(f"language={code!r} no soportado; usa uno de: {supported}") from None
