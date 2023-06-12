part of '../neon_notes.dart';

class NotesCreateNoteDialog extends StatefulWidget {
  const NotesCreateNoteDialog({
    this.category,
    super.key,
  });

  final String? category;

  @override
  State<NotesCreateNoteDialog> createState() => _NotesCreateNoteDialogState();
}

class _NotesCreateNoteDialogState extends State<NotesCreateNoteDialog> {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  late NotesBloc bloc;

  String? selectedCategory;

  @override
  void initState() {
    bloc = Provider.of<NotesBloc>(context, listen: false);

    super.initState();
  }

  void submit() {
    if (formKey.currentState!.validate()) {
      Navigator.of(context).pop([controller.text, widget.category ?? selectedCategory]);
    }
  }

  @override
  Widget build(final BuildContext context) => ResultBuilder<List<NextcloudNotesNote>>(
        stream: bloc.notes,
        builder: (final context, final notes) => NeonDialog(
          title: Text(AppLocalizations.of(context).noteCreate),
          children: [
            Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextFormField(
                    autofocus: true,
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).noteTitle,
                    ),
                    validator: (final input) => validateNotEmpty(context, input),
                    onFieldSubmitted: (final _) {
                      submit();
                    },
                  ),
                  if (widget.category == null) ...[
                    Center(
                      child: NeonException(
                        notes.error,
                        onRetry: bloc.refresh,
                      ),
                    ),
                    Center(
                      child: NeonLinearProgressIndicator(
                        visible: notes.loading,
                      ),
                    ),
                    if (notes.data != null) ...[
                      NotesCategorySelect(
                        categories: notes.data!.map((final note) => note.category).toSet().toList(),
                        onChanged: (final category) {
                          selectedCategory = category;
                        },
                        onSubmitted: submit,
                      ),
                    ],
                  ],
                  ElevatedButton(
                    onPressed: submit,
                    child: Text(AppLocalizations.of(context).noteCreate),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
