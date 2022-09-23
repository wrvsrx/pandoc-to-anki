import pandoc
import genanki

model_id = 1245741901

my_model = genanki.Model(
    model_id=model_id,
    name="Simple Model",
    fields=[{"name": "Question"}, {"name": "Answer"}],
    templates=[
        {
            "name": "Simple Card",
            "qfmt": '<div class="card"><div class="question">{{Question}}</div></div>',
            "afmt": '<div class="card">'
            + '<div class="question">{{Question}}</div>'
            + "<hr>"
            + '<div class="answer">{{Answer}}</div>'
            + "</div>",
        },
    ],
)
