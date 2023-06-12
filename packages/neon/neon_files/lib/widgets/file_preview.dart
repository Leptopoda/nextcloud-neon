part of '../neon_files.dart';

class FilePreview extends StatelessWidget {
  const FilePreview({
    required this.details,
    this.size = const Size.square(40),
    this.color,
    this.borderRadius,
    this.withBackground = false,
    super.key,
  }) : assert(
          (borderRadius != null && withBackground) || borderRadius == null,
          'withBackground needs to be true when borderRadius is set',
        );

  final FileDetails details;
  final Size size;
  final Color? color;
  final BorderRadius? borderRadius;
  final bool withBackground;

  int get width => size.width.toInt();
  int get height => size.height.toInt();

  @override
  Widget build(final BuildContext context) {
    final bloc = Provider.of<FilesBloc>(context, listen: false);
    final color = this.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox.fromSize(
      size: size,
      child: StreamBuilder<bool?>(
        stream: bloc.options.showPreviewsOption.stream,
        builder: (final context, final showPreviewsSnapshot) {
          if ((showPreviewsSnapshot.data ?? false) && (details.hasPreview ?? false)) {
            final account = Provider.of<AccountsBloc>(context, listen: false).activeAccount.value!;
            final child = NeonCachedApiImage(
              account: account,
              cacheKey: 'preview-${details.path.join('/')}-$width-$height',
              etag: details.etag,
              download: () async => account.client.core.getPreview(
                file: details.path.join('/'),
                x: width,
                y: height,
              ),
            );
            if (withBackground) {
              return NeonImageWrapper(
                color: Colors.white,
                borderRadius: borderRadius,
                child: child,
              );
            }
            return child;
          }

          if (details.isDirectory) {
            return Icon(
              MdiIcons.folder,
              color: color,
              size: size.shortestSide,
            );
          }

          return FileIcon(
            details.name,
            color: color,
            size: size.shortestSide,
          );
        },
      ),
    );
  }
}
