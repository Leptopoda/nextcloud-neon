part of '../neon_notes.dart';

class NotesCategoriesView extends StatelessWidget {
  const NotesCategoriesView({
    super.key,
  });

  @override
  Widget build(final BuildContext context) {
    final bloc = Provider.of<NotesBloc>(context, listen: false);

    return ResultBuilder<List<NextcloudNotesNote>>(
      stream: bloc.notes,
      builder: (final context, final notes) => SortBoxBuilder<CategoriesSortProperty, NoteCategory>(
        sortBox: categoriesSortBox,
        sortPropertyOption: bloc.options.categoriesSortPropertyOption,
        sortBoxOrderOption: bloc.options.categoriesSortBoxOrderOption,
        input: notes.data
            ?.map((final note) => note.category)
            .toSet()
            .map(
              (final category) => NoteCategory(
                category,
                notes.data!.where((final note) => note.category == category).length,
              ),
            )
            .toList(),
        builder: (final context, final sorted) => NeonListView<NoteCategory>(
          scrollKey: 'notes-categories',
          items: sorted,
          isLoading: notes.loading,
          error: notes.error,
          onRefresh: bloc.refresh,
          builder: _buildCategory,
        ),
      ),
    );
  }

  Widget _buildCategory(
    final BuildContext context,
    final NoteCategory category,
  ) =>
      ListTile(
        title: Text(category.name != '' ? category.name : AppLocalizations.of(context).categoryUncategorized),
        subtitle: Text(AppLocalizations.of(context).categoryNotesCount(category.count)),
        leading: category.name != ''
            ? Icon(
                MdiIcons.tag,
                size: 40,
                color: NotesCategoryColor.compute(category.name),
              )
            : const SizedBox.square(dimension: 40),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (final context) => NotesCategoryPage(
                category: category,
              ),
            ),
          );
        },
      );
}
