part of '../neon_files.dart';

class FilesBrowserView extends StatefulWidget {
  const FilesBrowserView({
    this.onPickFile,
    this.enableFileActions = true,
    this.onlyShowDirectories = false,
    super.key,
    // ignore: prefer_asserts_with_message
  }) : assert((onPickFile == null) == onlyShowDirectories);

  final Function(FileDetails)? onPickFile;
  final bool enableFileActions;
  final bool onlyShowDirectories;

  @override
  State<FilesBrowserView> createState() => _FilesBrowserViewState();
}

class _FilesBrowserViewState extends State<FilesBrowserView> {
  late FilesBrowserBloc bloc;
  late FilesBloc filesBloc;

  @override
  void initState() {
    super.initState();

    filesBloc = Provider.of<FilesBloc>(context, listen: false);
    bloc = filesBloc.browser;

    bloc.errors.listen((final error) {
      NeonException.showSnackbar(context, error);
    });
  }

  @override
  Widget build(final BuildContext context) => ResultBuilder<List<WebDavFile>>(
        stream: bloc.files,
        builder: (final context, final files) => StreamBuilder<List<String>>(
          stream: bloc.path,
          builder: (final context, final pathSnapshot) => StreamBuilder<List<UploadTask>>(
            stream: filesBloc.uploadTasks,
            builder: (final context, final uploadTasksSnapshot) => StreamBuilder<List<DownloadTask>>(
              stream: filesBloc.downloadTasks,
              builder: (final context, final downloadTasksSnapshot) => !pathSnapshot.hasData ||
                      !uploadTasksSnapshot.hasData ||
                      !downloadTasksSnapshot.hasData
                  ? Container()
                  : BackButtonListener(
                      onBackButtonPressed: () async {
                        final path = pathSnapshot.data!;
                        if (path.isNotEmpty) {
                          bloc.setPath(path.sublist(0, path.length - 1));
                          return true;
                        }
                        return false;
                      },
                      child: SortBoxBuilder<FilesSortProperty, WebDavFile>(
                        sortBox: filesSortBox,
                        sortPropertyOption: bloc.options.filesSortPropertyOption,
                        sortBoxOrderOption: bloc.options.filesSortBoxOrderOption,
                        input: files.data,
                        builder: (final context, final sorted) => NeonListView<Widget>(
                          scrollKey: 'files-${pathSnapshot.data!.join('/')}',
                          withFloatingActionButton: true,
                          items: [
                            for (final uploadTask in sorted == null
                                ? <UploadTask>[]
                                : uploadTasksSnapshot.data!.where(
                                    (final task) =>
                                        sorted.where((final file) => _pathMatchesFile(task.path, file.name)).isEmpty,
                                  )) ...[
                              StreamBuilder<int>(
                                stream: uploadTask.progress,
                                builder: (final context, final uploadTaskProgressSnapshot) =>
                                    !uploadTaskProgressSnapshot.hasData
                                        ? Container()
                                        : _buildFile(
                                            context: context,
                                            details: FileDetails(
                                              path: uploadTask.path,
                                              isDirectory: false,
                                              size: uploadTask.size,
                                              etag: null,
                                              mimeType: null,
                                              lastModified: uploadTask.lastModified,
                                              hasPreview: null,
                                              isFavorite: null,
                                            ),
                                            uploadProgress: uploadTaskProgressSnapshot.data,
                                            downloadProgress: null,
                                          ),
                              ),
                            ],
                            if (sorted != null) ...[
                              for (final file in sorted) ...[
                                if (!widget.onlyShowDirectories || file.isDirectory) ...[
                                  Builder(
                                    builder: (final context) {
                                      final matchingUploadTasks = uploadTasksSnapshot.data!
                                          .where((final task) => _pathMatchesFile(task.path, file.name));
                                      final matchingDownloadTasks = downloadTasksSnapshot.data!
                                          .where((final task) => _pathMatchesFile(task.path, file.name));

                                      return StreamBuilder<int?>(
                                        stream: matchingUploadTasks.isNotEmpty
                                            ? matchingUploadTasks.first.progress
                                            : Stream.value(null),
                                        builder: (final context, final uploadTaskProgressSnapshot) =>
                                            StreamBuilder<int?>(
                                          stream: matchingDownloadTasks.isNotEmpty
                                              ? matchingDownloadTasks.first.progress
                                              : Stream.value(null),
                                          builder: (final context, final downloadTaskProgressSnapshot) => _buildFile(
                                            context: context,
                                            details: FileDetails(
                                              path: [...bloc.path.value, file.name],
                                              isDirectory: matchingUploadTasks.isEmpty && file.isDirectory,
                                              size: matchingUploadTasks.isNotEmpty
                                                  ? matchingUploadTasks.first.size
                                                  : file.size!,
                                              etag: matchingUploadTasks.isNotEmpty ? null : file.etag,
                                              mimeType: matchingUploadTasks.isNotEmpty ? null : file.mimeType,
                                              lastModified: matchingUploadTasks.isNotEmpty
                                                  ? matchingUploadTasks.first.lastModified
                                                  : file.lastModified!,
                                              hasPreview: matchingUploadTasks.isNotEmpty ? null : file.hasPreview,
                                              isFavorite: matchingUploadTasks.isNotEmpty ? null : file.favorite,
                                            ),
                                            uploadProgress: uploadTaskProgressSnapshot.data,
                                            downloadProgress: downloadTaskProgressSnapshot.data,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ],
                          ],
                          isLoading: files.loading,
                          error: files.error,
                          onRefresh: bloc.refresh,
                          builder: (final context, final widget) => widget,
                          topScrollingChildren: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      visualDensity: const VisualDensity(
                                        horizontal: VisualDensity.minimumDensity,
                                        vertical: VisualDensity.minimumDensity,
                                      ),
                                      tooltip: AppLocalizations.of(context).goToPath(''),
                                      icon: const Icon(
                                        Icons.house,
                                        size: 30,
                                      ),
                                      onPressed: () {
                                        bloc.setPath([]);
                                      },
                                    ),
                                    for (var i = 0; i < pathSnapshot.data!.length; i++) ...[
                                      Builder(
                                        builder: (final context) {
                                          final path = pathSnapshot.data!.sublist(0, i + 1);
                                          return Tooltip(
                                            message: AppLocalizations.of(context).goToPath(path.join('/')),
                                            excludeFromSemantics: true,
                                            child: TextButton(
                                              onPressed: () {
                                                bloc.setPath(path);
                                              },
                                              child: Text(
                                                pathSnapshot.data![i],
                                                semanticsLabel: AppLocalizations.of(context).goToPath(path.join('/')),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ]
                                      .intersperse(
                                        const Icon(
                                          Icons.keyboard_arrow_right,
                                          size: 30,
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      );

  bool _pathMatchesFile(final List<String> path, final String name) => const ListEquality().equals(
        [...bloc.path.value, name],
        path,
      );

  Widget _buildFile({
    required final BuildContext context,
    required final FileDetails details,
    required final int? uploadProgress,
    required final int? downloadProgress,
  }) =>
      ListTile(
        // When the ETag is null it means we are uploading this file right now
        onTap: details.isDirectory || details.etag != null
            ? () async {
                if (details.isDirectory) {
                  bloc.setPath(details.path);
                } else {
                  if (widget.onPickFile != null) {
                    widget.onPickFile!.call(details);
                  }
                }
              }
            : null,
        title: Text(
          details.name,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            RelativeTime(
              date: details.lastModified,
            ),
            if (details.size > 0) ...[
              const SizedBox(
                width: 10,
              ),
              Text(
                filesize(details.size, 1),
                style: DefaultTextStyle.of(context).style.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ],
        ),
        leading: SizedBox.square(
          dimension: 40,
          child: Stack(
            children: [
              Center(
                child: uploadProgress != null || downloadProgress != null
                    ? Column(
                        children: [
                          Icon(
                            uploadProgress != null ? MdiIcons.upload : MdiIcons.download,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          LinearProgressIndicator(
                            value: (uploadProgress ?? downloadProgress)! / 100,
                          ),
                        ],
                      )
                    : FilePreview(
                        details: details,
                        withBackground: true,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
              ),
              if (details.isFavorite ?? false) ...[
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.star,
                    size: 14,
                    color: Colors.yellow,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: uploadProgress == null && downloadProgress == null && widget.enableFileActions
            ? PopupMenuButton<FilesFileAction>(
                itemBuilder: (final context) => [
                  if (details.isFavorite != null) ...[
                    PopupMenuItem(
                      value: FilesFileAction.toggleFavorite,
                      child: Text(
                        details.isFavorite!
                            ? AppLocalizations.of(context).removeFromFavorites
                            : AppLocalizations.of(context).addToFavorites,
                      ),
                    ),
                  ],
                  PopupMenuItem(
                    value: FilesFileAction.details,
                    child: Text(AppLocalizations.of(context).details),
                  ),
                  PopupMenuItem(
                    value: FilesFileAction.rename,
                    child: Text(AppLocalizations.of(context).actionRename),
                  ),
                  PopupMenuItem(
                    value: FilesFileAction.move,
                    child: Text(AppLocalizations.of(context).actionMove),
                  ),
                  PopupMenuItem(
                    value: FilesFileAction.copy,
                    child: Text(AppLocalizations.of(context).actionCopy),
                  ),
                  // TODO: https://github.com/provokateurin/nextcloud-neon/issues/4
                  if (!details.isDirectory) ...[
                    PopupMenuItem(
                      value: FilesFileAction.sync,
                      child: Text(AppLocalizations.of(context).actionSync),
                    ),
                  ],
                  PopupMenuItem(
                    value: FilesFileAction.delete,
                    child: Text(AppLocalizations.of(context).actionDelete),
                  ),
                ],
                onSelected: (final action) async {
                  switch (action) {
                    case FilesFileAction.toggleFavorite:
                      if (details.isFavorite ?? false) {
                        filesBloc.removeFavorite(details.path);
                      } else {
                        filesBloc.addFavorite(details.path);
                      }
                      break;
                    case FilesFileAction.details:
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (final context) => FilesDetailsPage(
                            details: details,
                          ),
                        ),
                      );
                      break;
                    case FilesFileAction.rename:
                      final result = await showRenameDialog(
                        context: context,
                        title: details.isDirectory
                            ? AppLocalizations.of(context).folderRename
                            : AppLocalizations.of(context).fileRename,
                        value: details.name,
                      );
                      if (result != null) {
                        filesBloc.rename(details.path, result);
                      }
                      break;
                    case FilesFileAction.move:
                      final b = filesBloc.getNewFilesBrowserBloc();
                      final originalPath = details.path.sublist(0, details.path.length - 1);
                      b.setPath(originalPath);
                      final result = await showDialog<List<String>?>(
                        context: context,
                        builder: (final context) => FilesChooseFolderDialog(
                          originalPath: originalPath,
                        ),
                      );
                      b.dispose();
                      if (result != null) {
                        filesBloc.move(details.path, result..add(details.name));
                      }
                      break;
                    case FilesFileAction.copy:
                      final b = filesBloc.getNewFilesBrowserBloc();
                      final originalPath = details.path.sublist(0, details.path.length - 1);
                      b.setPath(originalPath);
                      final result = await showDialog<List<String>?>(
                        context: context,
                        builder: (final context) => FilesChooseFolderDialog(
                          originalPath: originalPath,
                        ),
                      );
                      b.dispose();
                      if (result != null) {
                        filesBloc.copy(details.path, result..add(details.name));
                      }
                      break;
                    case FilesFileAction.sync:
                      final sizeWarning = bloc.options.downloadSizeWarning.value;
                      if (sizeWarning != null && details.size > sizeWarning) {
                        // ignore: use_build_context_synchronously
                        if (!(await showConfirmationDialog(
                          context,
                          // ignore: use_build_context_synchronously
                          AppLocalizations.of(context).downloadConfirmSizeWarning(
                            filesize(sizeWarning),
                            filesize(details.size),
                          ),
                        ))) {
                          return;
                        }
                      }
                      filesBloc.syncFile(details.path);
                      break;
                    case FilesFileAction.delete:
                      // ignore: use_build_context_synchronously
                      if (await showConfirmationDialog(
                        context,
                        details.isDirectory
                            // ignore: use_build_context_synchronously
                            ? AppLocalizations.of(context).folderDeleteConfirm(details.name)
                            // ignore: use_build_context_synchronously
                            : AppLocalizations.of(context).fileDeleteConfirm(details.name),
                      )) {
                        filesBloc.delete(details.path);
                      }
                      break;
                  }
                },
              )
            : const SizedBox.square(
                dimension: 48,
              ),
      );
}

enum FilesFileAction {
  toggleFavorite,
  details,
  rename,
  move,
  copy,
  sync,
  delete,
}
