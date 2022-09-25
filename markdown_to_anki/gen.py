import json
import sys
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

data = json.load(sys.stdin)
deck = genanki.Deck(deck_id=int(data["deckId"]), name=data["deckTitle"])
for note_data in data["notes"]:
    note = genanki.Note(
        model=my_model,
        fields=[note_data["question"], note_data["answer"]],
        guid=note_data["guid"],
    )
    print(note)
    deck.add_note(note)

genanki.Package(deck).write_to_file("test.apkg")
