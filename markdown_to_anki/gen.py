import json
import sys
import genanki

def main():
    output_path = sys.argv[1]

    model_id = 1245741901

    my_model = genanki.Model(
        model_id=model_id,
        name="Simple Model",
        fields=[{"name": "Question"}, {"name": "Answer"}],
        templates=[
            {
                "name": "Simple Card",
                "qfmt": '<div class="question">{{Question}}</div>',
                "afmt": '<div class="question">{{Question}}</div>'
                + "<hr>"
                + '<div class="answer">{{Answer}}</div>',
            },
        ],
        css="""
        .card {
            font-family: arial;
            font-size: 20px;
            color: black;
            background-color: white;
        }
        """,
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

    genanki.Package(deck).write_to_file(output_path)

if __name__ == '__main__':
    main()
